extends RefCounted
## Puts the sculpted pilots together: reads what tools/pilots/*.py baked (tools/pilots/out/<key>/) and saves their meshes
## in assets/meshes/pilots/ and each pilot as scenes/pilots/<key>.tscn, with the same joints as the other pilots
## (so every pose in the game works). Build with the runner:
##   godot --headless --path godot res://tools/editor/runner.tscn -- build_pilots

const OUT := "res://tools/pilots/out/"
const MESH := "res://assets/meshes/pilots/%s_%s.res"
const FLAME := "res://materials/shaders/flame.gdshader"


func build(_host: Node) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/meshes/pilots"))
	for key in DirAccess.get_directories_at(OUT):
		_pilot(key)


func _xf(a: Array) -> Transform3D:
	return Transform3D(Vector3(a[0], a[1], a[2]), Vector3(a[3], a[4], a[5]), Vector3(a[6], a[7], a[8]), Vector3(a[9], a[10], a[11]))


func _material(d: Dictionary) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = d.get("rough", 0.7)
	m.metallic = d.get("metal", 0.0)
	m.metallic_specular = d.get("spec", 0.5)
	if d.has("albedo"):
		m.albedo_color = Color(d.albedo[0], d.albedo[1], d.albedo[2])
	if d.has("emit"):
		m.emission_enabled = true
		m.emission = Color(d.emit[0], d.emit[1], d.emit[2])
		m.emission_energy_multiplier = d.get("energy", 1.0)
	if d.has("rim"):
		m.rim_enabled = true
		m.rim = d.rim
		m.rim_tint = d.get("rim_tint", 0.5)
	if d.has("coat"):
		m.clearcoat_enabled = true
		m.clearcoat = d.coat
		m.clearcoat_roughness = d.get("coat_rough", 0.15)
	return m


func _pilot(key: String) -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT + key + "/meta.json"))
	var root := Node3D.new()
	root.name = key.capitalize()
	root.set_script(load("res://scripts/pilot_pose.gd"))
	# the joints the game poses, at their resting places (arms and legs straight down)
	var joints := {}
	var sx: float = meta.shoulder_x
	var lx: float = meta.leg_x
	var rest := {"Hip": Vector3(0, 0.5, 0), "Torso": Vector3.ZERO, "Head": Vector3(0, 0.58, 0), "ShoulderL": Vector3(-sx, 0.42, 0),
		"ShoulderR": Vector3(sx, 0.42, 0), "ElbowL": Vector3(0, -0.25, 0), "ElbowR": Vector3(0, -0.25, 0),
		"LegL": Vector3(-lx, -0.02, 0), "LegR": Vector3(lx, -0.02, 0), "KneeL": Vector3(0, -0.3, 0), "KneeR": Vector3(0, -0.3, 0)}
	for b: Dictionary in meta.bones:
		var n := Node3D.new()
		n.name = "Elbow" if b.name.begins_with("Elbow") else ("Knee" if b.name.begins_with("Knee") else b.name)
		n.position = rest[b.name]
		(joints[b.parent] if b.parent != "" else root).add_child(n)
		joints[b.name] = n
	# the body's skeleton, following the joints
	var sk := Skeleton3D.new()
	sk.name = "Skin"
	root.add_child(sk)
	var skin := Skin.new()
	var paths := PackedStringArray()
	for b: Dictionary in meta.bones:
		var i := sk.add_bone(b.name)
		if b.parent != "":
			sk.set_bone_parent(i, sk.find_bone(b.parent))
		sk.set_bone_rest(i, Transform3D(Basis.IDENTITY, rest[b.name]))
		skin.add_named_bind(b.name, _xf(b.model).affine_inverse())
		paths.append(b.path)
	sk.set_script(load("res://scripts/pilot_skin.gd"))
	sk.set("paths", paths)
	# the jetpack: rigid on the torso; the flames as the old pilots have them
	var pack := Node3D.new()
	pack.name = "Jetpack"
	pack.position = Vector3(meta.jetpack[0], meta.jetpack[1], meta.jetpack[2])
	joints.Torso.add_child(pack)
	var flames: Array = meta.flames
	for i in flames.size():
		var f := Node3D.new()
		f.name = "Flame%d" % i
		f.position = Vector3(flames[i][0], flames[i][1], flames[i][2])
		f.rotation.x = PI / 2
		f.add_to_group("flame", true)
		pack.add_child(f)
		_flame(f, 0.06)
	for i in meta.bone_flames.size():
		var bf: Array = meta.bone_flames[i]
		var f := Node3D.new()
		f.name = "FlameB%d" % i
		f.position = Vector3(bf[1], bf[2], bf[3])
		f.rotation.x = PI / 2
		f.add_to_group("flame", true)
		joints[bf[0]].add_child(f)
		_flame(f, 0.04)
	var mats := {}
	for k: String in meta.materials:
		mats[k] = _material(meta.materials[k])
	for l: Dictionary in meta.layers:
		var mi := MeshInstance3D.new()
		mi.name = String(l.name).capitalize().replace(" ", "")
		mi.mesh = _mesh(key, l, mats[l.mat])
		mi.set_meta("dressed", true)   # (scripts/gfx_ride.gd leaves its finish alone)
		if l.skinned:
			mi.skeleton = NodePath("..")
			mi.skin = skin
			mi.extra_cull_margin = 2.0
			sk.add_child(mi)
		elif String(l.bone).begins_with("Hand"):
			mi.name = "Hand"
			mi.position = Vector3(0, -0.25, 0)
			joints["Elbow" + String(l.bone).right(1)].add_child(mi)
		elif l.bone == "Jetpack":
			pack.add_child(mi)
		else:
			joints[l.bone].add_child(mi)
	Kit.save(root, "res://scenes/pilots/%s.tscn" % key)


func _mesh(key: String, l: Dictionary, m: Material) -> ArrayMesh:
	var f := FileAccess.open(OUT + key + "/" + l.name + ".bin", FileAccess.READ)
	var nv := f.get_32()
	var nt := f.get_32()
	var pos := f.get_buffer(nv * 12).to_float32_array()
	var nor := f.get_buffer(nv * 12).to_float32_array()
	var col := f.get_buffer(nv * 16).to_float32_array()
	var a := []
	a.resize(Mesh.ARRAY_MAX)
	var vv := PackedVector3Array()
	var nn := PackedVector3Array()
	var cc := PackedColorArray()
	vv.resize(nv)
	nn.resize(nv)
	cc.resize(nv)
	for i in nv:
		vv[i] = Vector3(pos[i * 3], pos[i * 3 + 1], pos[i * 3 + 2])
		nn[i] = Vector3(nor[i * 3], nor[i * 3 + 1], nor[i * 3 + 2])
		cc[i] = Color(col[i * 4], col[i * 4 + 1], col[i * 4 + 2], 1.0)
	a[Mesh.ARRAY_VERTEX] = vv
	a[Mesh.ARRAY_NORMAL] = nn
	a[Mesh.ARRAY_COLOR] = cc
	if l.skinned:
		a[Mesh.ARRAY_BONES] = f.get_buffer(nv * 16).to_int32_array()
		a[Mesh.ARRAY_WEIGHTS] = f.get_buffer(nv * 16).to_float32_array()
	a[Mesh.ARRAY_INDEX] = f.get_buffer(nt * 12).to_int32_array()
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	mesh.surface_set_material(0, m)
	var path := MESH % [key, l.name]
	ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
	return load(path)


func _flame(holder: Node3D, r: float) -> void:
	var cone := MeshInstance3D.new()
	cone.name = "Cone"
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = 0.0
	cm.height = r * 7.0
	var mat := ShaderMaterial.new()
	mat.shader = load(FLAME)
	cm.material = mat
	cone.mesh = cm
	cone.rotation.x = -PI / 2
	cone.position.z = r * 3.5
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(cone)
