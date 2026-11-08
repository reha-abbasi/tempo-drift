extends RefCounted
## The garage: five cars, as in the web game's garage, modelled once and saved as
## scenes in scenes/cars/ and scenes/pilots/. A car's nose points to -Z; its origin is its middle. The paint, the light
## strip and the engine glow are separate surfaces named "paint", "strip" and "pods", so each era can recolour them
## (scripts/car_look.gd), as the web game paints the car per era.

const M := "res://materials/%s.tres"


func build(_host: Node) -> void:
	for d in ["res://scenes/cars", "res://assets/meshes/cars"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(d))
	_car_materials()
	arrow()
	bubble()
	retro()
	spinner()
	manta()


func m(name: String) -> Material:
	return load(M % name)


func _car_materials() -> void:
	## the recolourable parts: kept out of the merged painted surface (meta "keep")
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color("e8dcc6")
	paint.metallic = 0.5
	paint.roughness = 0.3
	paint.clearcoat_enabled = true
	paint.clearcoat_roughness = 0.08
	ResourceSaver.save(paint, M % "car_paint")
	var strip := StandardMaterial3D.new()
	strip.albedo_color = Color("ffc46b")
	strip.emission_enabled = true
	strip.emission = Color("ffc46b")
	strip.emission_energy_multiplier = 2.4
	strip.set_meta("keep", true)
	ResourceSaver.save(strip, M % "car_strip")
	var pods := StandardMaterial3D.new()
	pods.albedo_color = Color(1, 0.8, 0.5)
	pods.emission_enabled = true
	pods.emission = Color(1, 0.8, 0.5)
	pods.emission_energy_multiplier = 3.0
	pods.set_meta("keep", true)
	ResourceSaver.save(pods, M % "car_pods")


func kit() -> MeshKit:
	var k := MeshKit.new()
	k.use("paint", m("car_paint"))
	k.use("strip", m("car_strip"))
	k.use("pods", m("car_pods"))
	k.use("dark", m("paint_graphite"))
	k.use("black", m("paint_black_gloss"))
	k.use("glass", m("glass_dark"))
	k.use("chrome", m("chrome"))
	k.use("tail", m("tail_glow"))
	k.use("head", m("led_white"))
	k.use("red", m("tail_glow"))
	k.use("blue", m("led_cyan"))
	return k


func _save_car(k: MeshKit, key: String, engines: Array, fans := []) -> void:
	var path := "res://assets/meshes/cars/car_%s.res" % key
	ResourceSaver.save(k.bake(), path)
	print("   car %s: %d triangles" % [key, k.triangles()])
	var root := Node3D.new()
	root.name = key.capitalize()
	root.set_script(load("res://scripts/car_look.gd"))
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = load(path)
	root.add_child(body)
	for i in engines.size():
		_flame(root, "Flame%d" % i, engines[i][0], engines[i][1])
	for i in fans.size():
		var f := MeshInstance3D.new()
		f.name = "Fan%d" % i
		var cm := CylinderMesh.new()
		cm.top_radius = fans[i][1]
		cm.bottom_radius = fans[i][1]
		cm.height = 0.01
		var fm := StandardMaterial3D.new()
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fm.albedo_color = Color(0.1, 0.1, 0.12, 0.45)
		cm.material = fm
		f.mesh = cm
		f.position = fans[i][0]
		f.add_to_group("spin", true)
		root.add_child(f)
	var head := SpotLight3D.new()
	head.name = "Headlamps"
	head.position = Vector3(0, 0.1, -1.0)
	head.rotation = Vector3(-0.22, 0, 0)
	head.light_color = Color(1.0, 0.9, 0.75)
	head.light_energy = 2.5
	head.spot_range = 18.0
	head.spot_angle = 26.0
	root.add_child(head)
	var under := OmniLight3D.new()
	under.name = "Underglow"
	under.position = Vector3(0, -0.7, 0.3)
	under.light_energy = 1.4
	under.omni_range = 4.0
	root.add_child(under)
	var key_l := OmniLight3D.new()
	key_l.name = "KeyLight"
	key_l.position = Vector3(0, 1.4, 2.2)
	key_l.light_energy = 1.0
	key_l.omni_range = 4.5
	root.add_child(key_l)
	Kit.save(root, "res://scenes/cars/%s.tscn" % key)


func _flame(root: Node3D, name: String, pos: Vector3, r: float) -> void:
	var holder := Node3D.new()
	holder.name = name
	holder.position = pos
	holder.add_to_group("flame", true)
	root.add_child(holder)
	var cone := MeshInstance3D.new()
	cone.name = "Cone"
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = 0.0
	cm.height = r * 6.0
	cm.radial_segments = 16
	cm.rings = 1
	var mat := ShaderMaterial.new()
	mat.shader = load("res://materials/shaders/flame.gdshader")
	cm.material = mat
	cone.mesh = cm
	cone.rotation.x = -PI / 2
	cone.position.z = r * 3.0
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(cone)
	var glow := MeshInstance3D.new()
	glow.name = "Glow"
	var q := QuadMesh.new()
	q.size = Vector2(r * 4.0, r * 4.0)
	var gm := ShaderMaterial.new()
	gm.shader = load("res://materials/shaders/glow.gdshader")
	gm.set_shader_parameter("intensity", 1.6)
	q.material = gm
	glow.mesh = q
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(glow)


func _side(k: MeshKit, mat: String, profile: Array, half_w: float, z_flip := true) -> void:
	## a body drawn as a side profile (x = along the car, nose at +x like the web game; y = up), given width and
	## rounded off: a loft through cross-sections whose width follows the profile
	var secs := []
	var n := profile.size()
	for i in n:
		var p: Vector2 = profile[i]
		secs.append(p)
	var lofts := []
	# sample along the length: top and bottom heights from the profile's upper and lower edges
	for s in 13:
		var xx := lerpf(-1.0, 1.05, s / 12.0)
		var top := _profile_y(profile, xx, true)
		var bot := _profile_y(profile, xx, false)
		var h := maxf(0.02, (top - bot) / 2.0)
		var w := half_w * (0.35 + 0.65 * sin(PI * clampf((xx + 1.0) / 2.05, 0.03, 0.97)))
		lofts.append(MeshKit.section(-xx, w, h, (top + bot) / 2.0, 16, 3.0, 0.75))
	lofts.reverse()
	k.loft(mat, lofts)


static func _profile_y(profile: Array, xx: float, upper: bool) -> float:
	## the profile is a closed outline; take its highest (or lowest) point above this x
	var best := -INF if upper else INF
	for i in profile.size():
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[(i + 1) % profile.size()]
		if (a.x - xx) * (b.x - xx) <= 0.0 and absf(a.x - b.x) > 0.0001:
			var y := lerpf(a.y, b.y, (xx - a.x) / (b.x - a.x))
			best = maxf(best, y) if upper else minf(best, y)
	if best == INF or best == -INF:
		return 0.0
	return best


# ------------------------------------------------------------------ the five cars

func arrow() -> void:
	## Arrow: an anti-gravity racer with twin engines and a rear wing
	var k := kit()
	var prof := [Vector2(1.05, 0.05), Vector2(-0.95, 0.06), Vector2(-1.0, 0.3), Vector2(-0.45, 0.36), Vector2(0.2, 0.26), Vector2(1.05, 0.12)]
	_side(k, "paint", prof, 0.48)
	# canopy and cockpit
	k.sphere("glass", Vector3(0, 0.33, -0.05), Vector3(0.24, 0.13, 0.42), 16, 8)
	# light strip down each flank
	for s: int in [-1, 1]:
		k.box("strip", Vector3(s * 0.43, 0.14, 0.0), Vector3(0.015, 0.025, 1.5))
	# twin engines and a wing on struts
	for s: int in [-1, 1]:
		var old := k.at(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(s * 0.32, 0.12, 0.72)))
		k.lathe("dark", PackedVector2Array([Vector2(0.0, -0.36), Vector2(0.12, -0.3), Vector2(0.14, 0.2), Vector2(0.12, 0.34), Vector2(0.09, 0.34)]), Vector3.ZERO, 14)
		k.cylinder("pods", Vector3(0, 0.345, 0), 0.085, 0.01, 14)
		k.xform = old
		k.box("dark", Vector3(s * 0.22, 0.42, 0.85), Vector3(0.03, 0.18, 0.12))
	k.bevel_box("paint", Vector3(0, 0.52, 0.92), Vector3(0.95, 0.03, 0.24), 0.012)
	k.box("strip", Vector3(0, 0.535, 1.04), Vector3(0.9, 0.012, 0.012))
	for s: int in [-1, 1]:
		k.box("tail", Vector3(s * 0.2, 0.2, 1.04), Vector3(0.14, 0.04, 0.02))
		k.box("head", Vector3(s * 0.22, 0.1, -1.02), Vector3(0.14, 0.03, 0.02))
	_save_car(k, "arrow", [[Vector3(-0.32, 0.12, 1.08), 0.08], [Vector3(0.32, 0.12, 1.08), 0.08]])


func bubble() -> void:
	## Bubble: a city pod with a glass dome and a ring thruster round its waist
	var k := kit()
	k.sphere("paint", Vector3(0, 0.1, 0.05), Vector3(0.5, 0.24, 0.95), 18, 10)
	k.sphere("glass", Vector3(0, 0.3, -0.05), Vector3(0.36, 0.26, 0.5), 18, 10)
	# the ring thruster: a flat torus round the body with a glowing band
	var old := k.at(Transform3D(Basis().scaled(Vector3(1.0, 1.0, 2.05)), Vector3(0, 0.03, 0.02)))
	k.lathe("dark", PackedVector2Array([Vector2(0.43, -0.04), Vector2(0.51, -0.04), Vector2(0.51, 0.04), Vector2(0.43, 0.04), Vector2(0.43, -0.04)]), Vector3.ZERO, 32)
	k.lathe("strip", PackedVector2Array([Vector2(0.515, -0.012), Vector2(0.515, 0.012)]), Vector3(0, 0.18, 0), 32)
	k.xform = old
	for s: int in [-1, 1]:
		k.box("tail", Vector3(s * 0.15, 0.12, 0.98), Vector3(0.12, 0.05, 0.02))
		k.box("head", Vector3(s * 0.16, 0.06, -0.97), Vector3(0.12, 0.04, 0.02))
	k.cylinder("pods", Vector3(0, -0.15, 0.05), 0.22, 0.02, 20)
	_save_car(k, "bubble", [[Vector3(0, 0.05, 1.0), 0.11]])


func retro() -> void:
	## Retro: an 80s wedge supercar with neon edges, hover pads and a slatted tail-light panel
	var k := kit()
	var secs := []
	for p in [[-1.05, 0.5, 0.03, 0.04], [-0.3, 0.92, 0.14, 0.13], [0.02, 0.92, 0.22, 0.2], [0.42, 0.92, 0.22, 0.2], [0.95, 0.9, 0.17, 0.17], [1.05, 0.88, 0.04, 0.06]]:
		secs.append(MeshKit.section(p[0], p[1] / 2.0 * 1.0, p[2], p[3], 8, 1.2, 0.7))
	k.loft("paint", secs, true, false)
	var can := []
	for p in [[-0.35, 0.05, 0.02], [-0.05, 0.36, 0.12], [0.35, 0.34, 0.12], [0.6, 0.1, 0.02]]:
		can.append(MeshKit.section(p[0], p[1], p[2], 0.36 + p[2], 8, 1.4, 0.7))
	k.loft("glass", can, true, false)
	# neon edges along the sills and across the nose
	for s: int in [-1, 1]:
		k.box("strip", Vector3(s * 0.465, 0.02, 0.0), Vector3(0.02, 0.02, 2.0))
	k.box("strip", Vector3(0, 0.06, -1.04), Vector3(0.5, 0.02, 0.02))
	# the slatted tail-light panel
	k.box("black", Vector3(0, 0.15, 1.05), Vector3(0.84, 0.16, 0.02))
	for i in 5:
		k.box("tail", Vector3(0, 0.09 + i * 0.03, 1.062), Vector3(0.8, 0.014, 0.01))
	# four hover pads
	for sx: int in [-1, 1]:
		for sz: int in [-1, 1]:
			k.cylinder("dark", Vector3(sx * 0.33, -0.05, sz * 0.62), 0.14, 0.06, 16)
			k.cylinder("pods", Vector3(sx * 0.33, -0.085, sz * 0.62), 0.11, 0.01, 16)
	_save_car(k, "retro", [[Vector3(0, 0.12, 1.08), 0.07]])


func spinner() -> void:
	## Spinner: a police-style flyer, four turbo fans and a light bar
	var k := kit()
	k.bevel_box("paint", Vector3(0, 0.12, 0.0), Vector3(0.62, 0.28, 1.8), 0.12)
	k.bevel_box("paint", Vector3(0, 0.34, 0.1), Vector3(0.52, 0.22, 0.9), 0.1)
	k.bevel_box("glass", Vector3(0, 0.36, 0.1), Vector3(0.54, 0.14, 0.8), 0.06)
	k.box("red", Vector3(-0.14, 0.48, 0.1), Vector3(0.22, 0.05, 0.1))
	k.box("blue", Vector3(0.14, 0.48, 0.1), Vector3(0.22, 0.05, 0.1))
	k.box("strip", Vector3(0, 0.12, 0.0), Vector3(0.64, 0.03, 1.6))
	var fans := []
	for sx: int in [-1, 1]:
		for z: float in [-0.62, 0.62]:
			k.box("dark", Vector3(sx * 0.42, 0.12, z), Vector3(0.24, 0.06, 0.12))
			k.lathe("dark", PackedVector2Array([Vector2(0.18, -0.05), Vector2(0.21, -0.05), Vector2(0.21, 0.05), Vector2(0.18, 0.05), Vector2(0.18, -0.05)]), Vector3(sx * 0.66, 0.12, z), 18)
			fans.append([Vector3(sx * 0.66, 0.12, z), 0.17])
	for s: int in [-1, 1]:
		k.box("tail", Vector3(s * 0.2, 0.14, 0.91), Vector3(0.14, 0.05, 0.02))
		k.box("head", Vector3(s * 0.2, 0.1, -0.91), Vector3(0.14, 0.04, 0.02))
	_save_car(k, "spinner", [[Vector3(0, 0.1, 0.95), 0.07]], fans)


func manta() -> void:
	## Manta: a flying wing, low, wide and fast
	var k := kit()
	var outline := PackedVector2Array()
	for p in [[0, -1.05], [0.32, -0.5], [0.92, 0.42], [0.82, 0.62], [0.42, 0.52], [0.2, 0.78], [-0.2, 0.78], [-0.42, 0.52], [-0.82, 0.62], [-0.92, 0.42], [-0.32, -0.5]]:
		outline.append(Vector2(p[0], p[1]))
	# drawn in the XZ plane (top view), extruded a little in height
	var flat := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	var reversed := outline.duplicate()
	reversed.reverse()
	var old := k.at(Transform3D(flat, Vector3(0, 0.12, 0)))
	k.prism("paint", reversed, -0.06, 0.06)
	k.xform = old
	k.sphere("glass", Vector3(0, 0.2, -0.1), Vector3(0.18, 0.1, 0.4), 14, 8)
	for s: int in [-1, 1]:
		k.box("strip", Vector3(s * 0.62, 0.13, 0.14), Vector3(0.6, 0.02, 0.03).rotated(Vector3.UP, 0.0))
		k.box("tail", Vector3(s * 0.85, 0.14, 0.55), Vector3(0.12, 0.03, 0.04))
		k.box("head", Vector3(s * 0.14, 0.12, -0.8), Vector3(0.12, 0.03, 0.02))
	_save_car(k, "manta", [[Vector3(-0.15, 0.1, 0.8), 0.07], [Vector3(0.15, 0.1, 0.8), 0.07]])


func _mat(c: Color, rough: float, metal: float, emit := Color.BLACK) -> StandardMaterial3D:
	var mm := StandardMaterial3D.new()
	mm.albedo_color = c
	mm.roughness = rough
	mm.metallic = metal
	if emit != Color.BLACK:
		mm.emission_enabled = true
		mm.emission = emit
		mm.emission_energy_multiplier = 2.5
	return mm


func _part(parent: Node3D, name: String, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _cap(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0)
	c.radial_segments = 14
	c.rings = 6
	return c


func _sph(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 18
	s.rings = 10
	return s


func _cyl(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 14
	return c


func _cone(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 8
	return c


func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b
