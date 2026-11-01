extends RefCounted
## Street furniture for every city: gas lamps (the Past), modern streetlights (the Present), neon poles (the Future),
## palms, plane trees, the sea railing, paper lanterns, and the three road surfaces. Saved under scenes/props/.

const M := "res://materials/%s.tres"
const LEN := 48.0
const ROAD := 4.4
const FRONT := 7.2


func build(_host: Node) -> void:
	for d in ["res://scenes/props", "res://assets/meshes/props"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(d))
	streets()
	gas_lamp()
	modern_lamp()
	neon_pole()
	palm()
	plane_tree()
	railing()
	lanterns()


func m(name: String) -> Material:
	return load(M % name)


func save_mesh(k: MeshKit, name: String) -> Mesh:
	var path := "res://assets/meshes/props/%s.res" % name
	ResourceSaver.save(k.bake(), path)
	return load(path)


func mesh_node(mesh: Mesh, name: String, vis := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	if vis > 0.0:
		mi.visibility_range_end = vis
	return mi


func streets() -> void:
	## one 48 m street per road surface: cobbles, asphalt with lane lines, and wet black asphalt with glowing guides
	for kind in ["cobble", "asphalt", "wet"]:
		var k := MeshKit.new()
		k.use("road", m({"cobble": "cobblestone", "asphalt": "asphalt", "wet": "asphalt_wet"}[kind]), 2.4 if kind == "cobble" else 3.0)
		k.use("curb", m("granite"), 0.8)
		k.use("walk", m({"cobble": "pavement", "asphalt": "pavement_concrete", "wet": "concrete_panels"}[kind]), 2.2)
		k.use("line", m("lane_white" if kind == "asphalt" else "lane_glow"))
		k.quad("road", Vector3(-ROAD, 0, 0), Vector3(ROAD, 0, 0), Vector3(ROAD, 0, -LEN), Vector3(-ROAD, 0, -LEN))
		if kind != "cobble":
			# dashes between the flight lanes (the lanes are 2.24 m apart)
			for x: float in [-1.12, 1.12]:
				for i in 8:
					var z0 := -i * 6.0 - 1.0
					k.quad("line", Vector3(x - 0.06, 0.01, z0), Vector3(x + 0.06, 0.01, z0), Vector3(x + 0.06, 0.01, z0 - 2.6), Vector3(x - 0.06, 0.01, z0 - 2.6))
		for s: int in [-1, 1]:
			k.box("curb", Vector3(s * (ROAD + 0.15), 0.08, -LEN / 2), Vector3(0.3, 0.16, LEN), ["-y", "+z", "-z"])
			var a := minf(s * (ROAD + 0.3), s * (FRONT + 0.5))
			var b := maxf(s * (ROAD + 0.3), s * (FRONT + 0.5))
			k.quad("walk", Vector3(a, 0.16, 0), Vector3(b, 0.16, 0), Vector3(b, 0.16, -LEN), Vector3(a, 0.16, -LEN))
		save_mesh(k, "street_" + kind)


func gas_lamp() -> void:
	## a Victorian gas lamp: fluted iron column, ladder bar, glazed lantern with a warm mantle glow
	var k := MeshKit.new()
	k.use("iron", m("paint_bottle_green"))
	k.use("glow", m("lamp_glow"))
	k.lathe("iron", PackedVector2Array([Vector2(0.18, 0), Vector2(0.18, 0.22), Vector2(0.12, 0.32), Vector2(0.1, 0.8), Vector2(0.07, 0.9),
		Vector2(0.055, 2.6), Vector2(0.08, 2.7), Vector2(0.045, 2.78)]), Vector3.ZERO, 12)
	k.box("iron", Vector3(0, 2.48, 0), Vector3(0.62, 0.045, 0.045))
	k.lathe("glow", PackedVector2Array([Vector2(0.09, 2.8), Vector2(0.18, 3.26), Vector2(0.0, 3.26)]), Vector3.ZERO, 4, false)
	k.lathe("iron", PackedVector2Array([Vector2(0.23, 3.26), Vector2(0.21, 3.3), Vector2(0.05, 3.44), Vector2(0.03, 3.52), Vector2(0.0, 3.57)]), Vector3.ZERO, 4, false)
	var root := Node3D.new()
	root.name = "GasLamp"
	root.add_child(mesh_node(save_mesh(k, "gas_lamp"), "Post", 220.0))
	_glow(root, Vector3(0, 3.0, 0), Color(1.0, 0.72, 0.38), 1.4)
	_light(root, Vector3(0, 3.0, 0), Color(1.0, 0.7, 0.4), 1.6, 7.0)
	Kit.save(root, "res://scenes/props/gas_lamp.tscn")


func modern_lamp() -> void:
	var k := MeshKit.new()
	k.use("pole", m("paint_graphite"))
	k.use("led", m("led_white"))
	k.lathe("pole", PackedVector2Array([Vector2(0.14, 0), Vector2(0.1, 0.5), Vector2(0.07, 7.0), Vector2(0.0, 7.05)]), Vector3.ZERO, 10)
	k.bevel_box("pole", Vector3(0, 7.0, 1.0), Vector3(0.12, 0.1, 2.1), 0.03)
	k.box("led", Vector3(0, 6.94, 1.7), Vector3(0.09, 0.02, 0.7))
	var root := Node3D.new()
	root.name = "Streetlight"
	root.add_child(mesh_node(save_mesh(k, "modern_lamp"), "Pole", 260.0))
	var l := SpotLight3D.new()
	l.name = "Light"
	l.position = Vector3(0, 6.8, 1.7)
	l.rotation = Vector3(-PI / 2, 0, 0)
	l.light_color = Color(0.98, 0.92, 0.82)
	l.light_energy = 2.0
	l.spot_range = 11.0
	l.spot_angle = 50.0
	l.distance_fade_enabled = true
	l.distance_fade_begin = 70.0
	l.distance_fade_length = 20.0
	root.add_child(l)
	Kit.save(root, "res://scenes/props/modern_lamp.tscn")


func neon_pole() -> void:
	var k := MeshKit.new()
	k.use("pole", m("paint_black_gloss"))
	k.use("ring", m("led_magenta"))
	k.use("ring2", m("led_cyan"))
	k.lathe("pole", PackedVector2Array([Vector2(0.12, 0), Vector2(0.08, 0.5), Vector2(0.05, 6.2), Vector2(0.0, 6.25)]), Vector3.ZERO, 8)
	for i in 3:
		var r := 0.28 - i * 0.05
		var y := 5.4 + i * 0.32
		k.lathe("ring" if i % 2 == 0 else "ring2", PackedVector2Array([Vector2(r, y), Vector2(r + 0.03, y), Vector2(r + 0.03, y + 0.05), Vector2(r, y + 0.05), Vector2(r, y)]), Vector3.ZERO, 16)
	var root := Node3D.new()
	root.name = "NeonPole"
	root.add_child(mesh_node(save_mesh(k, "neon_pole"), "Pole", 240.0))
	_light(root, Vector3(0, 5.6, 0), Color(1.0, 0.35, 0.85), 2.0, 8.0)
	Kit.save(root, "res://scenes/props/neon_pole.tscn")


func palm() -> void:
	var k := MeshKit.new()
	k.use("trunk", m("palm_trunk"))
	k.use("frond", m("palm_frond"))
	var h := 7.5
	var prev := Vector3.ZERO
	var r := 0.24
	for i in 12:
		var t := float(i + 1) / 12.0
		var p := Vector3(sin(t * 1.4) * 0.5, t * h, 0)
		var basis := Basis.looking_at(p - prev, Vector3.FORWARD) * Basis(Vector3.RIGHT, PI / 2)
		var old := k.at(Transform3D(basis, (p + prev) / 2))
		k.lathe("trunk", PackedVector2Array([Vector2(r, -prev.distance_to(p) / 2), Vector2(r * 0.88, prev.distance_to(p) / 2)]), Vector3.ZERO, 8)
		k.xform = old
		r *= 0.96
		prev = p
	for i in 13:
		var a := TAU * i / 13.0 + 0.2
		var dir := Vector3(cos(a), 0, sin(a))
		var droop := 0.6 + 0.4 * float(i % 3) / 2.0
		var pts := []
		for j in 7:
			var t := float(j) / 6.0
			pts.append(prev + dir * t * 3.0 + Vector3.UP * (sin(t * PI * 0.9) * 1.0 - t * t * 2.0 * droop))
		for j in 6:
			var a0: Vector3 = pts[j]
			var a1: Vector3 = pts[j + 1]
			var side := dir.cross(Vector3.UP).normalized() * 0.42 * sin(PI * (j + 0.5) / 6.0)
			k.tri("frond", a0, a1 + side, a1)
			k.tri("frond", a0, a1, a1 - side)
			k.tri("frond", a0, a1, a1 + side)
			k.tri("frond", a0, a1 - side, a1)
	var root := Node3D.new()
	root.name = "Palm"
	root.add_child(mesh_node(save_mesh(k, "palm"), "Palm", 260.0))
	Kit.save(root, "res://scenes/props/palm.tscn")


func plane_tree() -> void:
	var k := MeshKit.new()
	k.use("bark", m("bark"))
	k.use("leaves", m("leaves"))
	k.use("leaves2", m("leaves_light"))
	k.lathe("bark", PackedVector2Array([Vector2(0.2, 0), Vector2(0.16, 1.0), Vector2(0.13, 3.0), Vector2(0.08, 4.4)]), Vector3.ZERO, 10)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 10:
		var p := Vector3(rng.randf_range(-1.4, 1.4), rng.randf_range(3.8, 6.2), rng.randf_range(-1.4, 1.4))
		var r := rng.randf_range(0.9, 1.4)
		k.sphere("leaves" if i % 3 else "leaves2", p, Vector3(r, r * 0.8, r), 9, 6)
	var root := Node3D.new()
	root.name = "PlaneTree"
	root.add_child(mesh_node(save_mesh(k, "plane_tree"), "Tree", 240.0))
	Kit.save(root, "res://scenes/props/plane_tree.tscn")


func railing() -> void:
	## the sea front: a stone parapet with a rail, 48 m long, and the sea beyond (its colour is set by the city)
	var k := MeshKit.new()
	k.use("stone", m("stone_trim_warm"))
	k.use("iron", m("paint_white"))
	k.box("stone", Vector3(0, 0.45, -LEN / 2), Vector3(0.5, 0.9, LEN))
	for i in 24:
		k.box("iron", Vector3(0, 1.05, -i * 2.0 - 1.0), Vector3(0.05, 0.3, 0.05))
	k.box("iron", Vector3(0, 1.2, -LEN / 2), Vector3(0.06, 0.05, LEN))
	var root := Node3D.new()
	root.name = "SeaFront"
	root.set_script(load("res://scripts/sea_front.gd"))
	root.add_child(mesh_node(save_mesh(k, "sea_rail"), "Rail"))
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, LEN)
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.16, 0.35, 0.54)
	sm.metallic = 0.3
	sm.roughness = 0.12
	pm.material = sm
	sea.mesh = pm
	sea.position = Vector3(200.5, -1.2, -LEN / 2)
	root.add_child(sea)
	Kit.save(root, "res://scenes/props/sea_front.tscn")


func lanterns() -> void:
	## a string of red paper lanterns hung high across the street (Tokyo)
	var k := MeshKit.new()
	k.use("paper", m("tail_glow"))
	k.use("cord", m("iron"))
	var span := FRONT * 2.0
	for i in 9:
		var x := -span / 2 + span * (i + 0.5) / 9.0
		var y := -0.9 * (1.0 - pow(2.0 * x / span, 2.0))
		k.sphere("paper", Vector3(x, y - 0.4, 0), Vector3(0.28, 0.36, 0.28), 10, 6)
	k.box("cord", Vector3(0, -0.4, 0), Vector3(span, 0.02, 0.02))
	var root := Node3D.new()
	root.name = "Lanterns"
	root.add_child(mesh_node(save_mesh(k, "lanterns"), "Lanterns"))
	Kit.save(root, "res://scenes/props/lanterns.tscn")


func _glow(root: Node3D, pos: Vector3, col: Color, intensity: float) -> void:
	var glow := MeshInstance3D.new()
	glow.name = "Glow"
	var q := QuadMesh.new()
	q.size = Vector2(1.5, 1.5)
	var gm := ShaderMaterial.new()
	gm.shader = load("res://materials/shaders/glow.gdshader")
	gm.set_shader_parameter("color", col)
	gm.set_shader_parameter("intensity", intensity)
	gm.set_shader_parameter("softness", 2.6)
	q.material = gm
	glow.mesh = q
	glow.position = pos
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.visibility_range_end = 160.0
	root.add_child(glow)


func _light(root: Node3D, pos: Vector3, col: Color, energy: float, rng: float) -> void:
	var l := OmniLight3D.new()
	l.name = "Light"
	l.position = pos
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	l.distance_fade_enabled = true
	l.distance_fade_begin = 70.0
	l.distance_fade_length = 20.0
	root.add_child(l)
