extends RefCounted
## The note ring and its pieces: the band of light, the closing cue ring, the swipe chevrons and the power-up badges.
## Sizes are in world metres (the rules' units x 1.4).

const K := 1.4


func build(_host: Node) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/meshes/track"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/track"))
	chevron()
	badges()
	ring()


func glow_mat(col: Color, energy := 2.6) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://materials/shaders/ring.gdshader")
	m.set_shader_parameter("color", col)
	m.set_shader_parameter("energy", energy)
	return m


func chevron() -> void:
	## a double chevron pointing +X (turned to point the swipe's way)
	var k := MeshKit.new()
	k.use("c", StandardMaterial3D.new())
	for i in 2:
		var o := 0.17 * i - 0.08
		k.prism("c", PackedVector2Array([Vector2(o - 0.1, 0.2), Vector2(o, 0.2), Vector2(o + 0.16, 0.0), Vector2(o, -0.2), Vector2(o - 0.1, -0.2), Vector2(o + 0.06, 0.0)]), -0.015, 0.015)
	ResourceSaver.save(k.bake(), "res://assets/meshes/track/chevron.res")


func badges() -> void:
	## power-up badges: a magnet, a shield and "2x"
	var mag := MeshKit.new()
	mag.use("c", StandardMaterial3D.new())
	var u := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		u.append(Vector2(cos(a), sin(a)) * 0.2)
	for i in 13:
		var a := TAU - PI * i / 12.0
		u.append(Vector2(cos(a), sin(a)) * 0.1)
	var arc := PackedVector2Array()
	for p in u:
		arc.append(p + Vector2(0, 0.05))
	mag.prism("c", PackedVector2Array([Vector2(-0.2, 0.05), Vector2(-0.1, 0.05), Vector2(-0.1, 0.22), Vector2(-0.2, 0.22)]), -0.02, 0.02)
	mag.prism("c", PackedVector2Array([Vector2(0.1, 0.05), Vector2(0.2, 0.05), Vector2(0.2, 0.22), Vector2(0.1, 0.22)]), -0.02, 0.02)
	for i in 12:
		var a0 := PI + PI * i / 12.0
		var a1 := PI + PI * (i + 1) / 12.0
		mag.prism("c", PackedVector2Array([Vector2(cos(a0), sin(a0)) * 0.2 + Vector2(0, 0.05), Vector2(cos(a1), sin(a1)) * 0.2 + Vector2(0, 0.05),
			Vector2(cos(a1), sin(a1)) * 0.1 + Vector2(0, 0.05), Vector2(cos(a0), sin(a0)) * 0.1 + Vector2(0, 0.05)]), -0.02, 0.02)
	ResourceSaver.save(mag.bake(), "res://assets/meshes/track/badge_magnet.res")
	var sh := MeshKit.new()
	sh.use("c", StandardMaterial3D.new())
	var pts := PackedVector2Array()
	for i in 9:
		var a := lerpf(-0.5, PI + 0.5, i / 8.0)
		pts.append(Vector2(cos(a) * 0.18, 0.06 + sin(a) * 0.12))
	pts.append(Vector2(0, -0.24))
	pts.reverse()
	sh.prism("c", pts, -0.02, 0.02)
	ResourceSaver.save(sh.bake(), "res://assets/meshes/track/badge_shield.res")


func ring() -> void:
	var root := Node3D.new()
	root.name = "NoteRing"
	root.set_script(load("res://scripts/note_ring.gd"))
	var band := MeshInstance3D.new()
	band.name = "Band"
	var tm := TorusMesh.new()
	tm.inner_radius = 0.56 * K
	tm.outer_radius = 0.66 * K
	tm.rings = 48
	tm.ring_segments = 8
	tm.material = glow_mat(Color(1.0, 0.89, 0.72))
	band.mesh = tm
	band.rotation.x = PI / 2
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(band)
	var disc := MeshInstance3D.new()
	disc.name = "Fill"
	var dm := CylinderMesh.new()
	dm.top_radius = 0.56 * K
	dm.bottom_radius = 0.56 * K
	dm.height = 0.002
	dm.radial_segments = 40
	dm.material = glow_mat(Color(1.0, 0.89, 0.72), 0.35)
	disc.mesh = dm
	disc.rotation.x = PI / 2
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(disc)
	# the cue ring closes in on the band and lands on it at the EXCELLENT moment
	var cue := MeshInstance3D.new()
	cue.name = "Cue"
	var cm := TorusMesh.new()
	cm.inner_radius = 0.6 * K
	cm.outer_radius = 0.635 * K
	cm.rings = 48
	cm.ring_segments = 6
	cm.material = glow_mat(Color(1, 1, 1), 1.8)
	cue.mesh = cm
	cue.rotation.x = PI / 2
	cue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(cue)
	var chev := MeshInstance3D.new()
	chev.name = "Chevron"
	chev.mesh = load("res://assets/meshes/track/chevron.res")
	chev.material_override = glow_mat(Color(1, 1, 1), 2.0)
	chev.scale = Vector3.ONE * K
	chev.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(chev)
	for b in [["Magnet", "badge_magnet", Color(1.0, 0.35, 0.3)], ["Shield", "badge_shield", Color(0.45, 0.95, 1.0)]]:
		var mi := MeshInstance3D.new()
		mi.name = b[0]
		mi.mesh = load("res://assets/meshes/track/%s.res" % b[1])
		mi.material_override = glow_mat(b[2], 2.4)
		mi.scale = Vector3.ONE * K
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	var x2 := Label3D.new()
	x2.name = "Double"
	x2.text = "2×"
	x2.font = load("res://fonts/Syncopate-Bold.ttf")
	x2.font_size = 96
	x2.pixel_size = 0.004
	x2.modulate = Color(1.0, 0.82, 0.3)
	x2.outline_size = 0
	x2.visible = false
	x2.shaded = false
	root.add_child(x2)
	var light := OmniLight3D.new()
	light.name = "Glow"
	light.light_color = Color(1.0, 0.89, 0.72)
	light.light_energy = 0.8
	light.omni_range = 3.0
	light.shadow_enabled = false
	root.add_child(light)
	Kit.save(root, "res://scenes/track/note_ring.tscn")
