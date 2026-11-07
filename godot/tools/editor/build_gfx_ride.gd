extends RefCounted
## The new look of the five cars (flying cars: a glowing anti-gravity field under them, real
## thrusters, clear-coated paint, glass canopies, light strips) and of the note ring, saved as scenes in
## scenes/gfx_ride/. Build with the runner:
##   godot --headless --path godot res://tools/editor/runner.tscn -- build_gfx_ride
## The run swaps them in (scripts/gfx_ride.gd). As the old cars (build_cars.gd): nose to
## -Z, origin in the middle, about 2.1 m long and 1 m wide; the paint, light strip and engine glow are surfaces named
## "paint", "strip" and "pods" for the era's colours, and the canopy is the surface "~paint", which the rescue plane
## swings open.

const DIR := "res://scenes/gfx_ride"
const MESH := "res://assets/meshes/gfx_ride/%s.res"
const MAT := "res://materials/gfx_ride/%s"


func build(_host: Node) -> void:
	for d in [DIR + "/cars", "res://assets/meshes/gfx_ride"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(d))
	_materials()
	arrow()
	bubble()
	retro()
	spinner()
	manta()
	ring()


# ------------------------------------------------------------------ materials

func _std(c: Color, metal: float, rough: float, emit := 0.0, coat := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	if coat:
		m.clearcoat_enabled = true
		m.clearcoat_roughness = 0.1
	# kept as its own surface (MeshKit folds plain colours together)
	m.set_meta("keep", true)
	return m


func _shader(file: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(MAT % file)
	return m


func _materials() -> void:
	ResourceSaver.save(_shader("ride_paint.gdshader"), MAT % "paint.tres")
	ResourceSaver.save(_shader("ride_glass.gdshader"), MAT % "glass.tres")
	ResourceSaver.save(_std(Color("17191e"), 0.35, 0.32, 0.0, true), MAT % "carbon.tres")
	ResourceSaver.save(_std(Color("d8dade"), 1.0, 0.14), MAT % "chrome.tres")
	ResourceSaver.save(_std(Color("ffc46b"), 0.0, 0.4, 3.0), MAT % "strip.tres")
	ResourceSaver.save(_std(Color(1, 0.8, 0.5), 0.0, 0.4, 4.0), MAT % "pods.tres")
	ResourceSaver.save(_std(Color("ff2a3a"), 0.0, 0.4, 4.0), MAT % "tail.tres")
	ResourceSaver.save(_std(Color("fff6e8"), 0.0, 0.3, 3.0), MAT % "head.tres")
	ResourceSaver.save(_std(Color("ff2030"), 0.0, 0.4, 5.0), MAT % "red.tres")
	ResourceSaver.save(_std(Color("2a6bff"), 0.0, 0.4, 5.0), MAT % "blue.tres")
	ResourceSaver.save(_std(Color("35e6ff"), 0.0, 0.4, 4.0), MAT % "cyan.tres")
	ResourceSaver.save(_shader("ride_outline.gdshader"), MAT % "outline.tres")


func kit() -> MeshKit:
	var k := MeshKit.new()
	for n in ["paint", "glass", "carbon", "chrome", "strip", "pods", "tail", "head", "red", "blue", "cyan"]:
		k.use(n, load(MAT % (n + ".tres")))
	return k


# ------------------------------------------------------------------ parts

static func _sec(z: float, w: float, h: float, y0: float, n := 16, sq := 2.4, top := 1.0) -> Dictionary:
	return MeshKit.section(z, w, h, y0, n, sq, top)


func _ccw(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(p[0], p[1]))
	if Geometry2D.is_polygon_clockwise(out):
		out.reverse()
	return out


func _plate(k: MeshKit, mat: String, xz: Array, y0: float, y1: float) -> void:
	## a flat plate from y0 to y1 drawn as a top view [(x, z), ...]
	var pts := []
	for p in xz:
		pts.append([p[0], -p[1]])
	var old := k.at(Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)), Vector3.ZERO))
	k.prism(mat, _ccw(pts), y0, y1)
	k.xform = old


func _fin(k: MeshKit, mat: String, zy: Array, x: float, half: float) -> void:
	## an upright fin centred at x, drawn as a side view [(z, y), ...]
	var pts := []
	for p in zy:
		pts.append([-p[0], p[1]])
	var old := k.at(Transform3D(Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(1, 0, 0)), Vector3.ZERO))
	k.prism(mat, _ccw(pts), x - half, x + half)
	k.xform = old


func _pod(k: MeshKit, mat: String, x: float, secs: Array, n := 14, sq := 2.2) -> void:
	## a round pod along the car at x: secs [[z, half-width, half-height, y], ...] from front to back
	var lofts := []
	for s in secs:
		lofts.append(_sec(s[0], s[1], s[2], s[3], n, sq))
	var old := k.at(Transform3D(Basis(), Vector3(x, 0, 0)))
	k.loft(mat, lofts)
	k.xform = old


func _nozzle(k: MeshKit, at: Vector3, r: float) -> void:
	## an engine's back: a chrome lip round a glowing face (seen from the chase camera)
	var old := k.at(Transform3D(Basis(Vector3.RIGHT, PI / 2), at))
	k.lathe("chrome", PackedVector2Array([Vector2(r * 1.02, -0.06), Vector2(r * 1.12, 0.0), Vector2(r * 1.05, 0.03), Vector2(r * 0.86, 0.03)]), Vector3.ZERO, 20)
	k.lathe("carbon", PackedVector2Array([Vector2(r * 0.86, 0.03), Vector2(r * 0.8, -0.02)]), Vector3.ZERO, 20)
	k.cylinder("pods", Vector3(0, -0.015, 0), r * 0.8, 0.01, 20)
	k.xform = old


func _bar(k: MeshKit, mat: String, a: Vector3, b: Vector3, t: float) -> void:
	## a thin square bar from a to b (light strips along slanted edges)
	var mid := (a + b) / 2.0
	var dir := (b - a).normalized()
	var side := dir.cross(Vector3.UP)
	if side.length() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized()
	var up := side.cross(dir).normalized()
	var old := k.at(Transform3D(Basis(side, up, -dir), mid))
	k.box(mat, Vector3.ZERO, Vector3(t, t, a.distance_to(b)))
	k.xform = old


# ------------------------------------------------------------------ the car scene

func _save_car(k: MeshKit, key: String, engines: Array, hover: Vector2, fans := [], look := {}) -> void:
	## engines: [[position, radius], ...]; hover: the size of the glowing field under the car; look: its livery
	## {body, stripe, stripes: the racing stripes' distance out from the middle and width}
	var path := MESH % ("car_" + key)
	var mesh := k.bake()
	for i in mesh.get_surface_count():
		if mesh.surface_get_name(i) == "glass":
			mesh.surface_set_name(i, "~paint")
	ResourceSaver.save(mesh, path)
	print("   car %s: %d triangles" % [key, k.triangles()])
	var root := Node3D.new()
	root.name = key.capitalize()
	root.set_script(load("res://scripts/gfx_ride_car.gd"))
	root.set("livery", look.get("body", Color(0, 0, 0, 0)))
	root.set("stripe_color", look.get("stripe", Color(0, 0, 0, 0)))
	root.set("stripe_x", look.get("stripes", Vector2.ZERO).x)
	root.set("stripe_w", look.get("stripes", Vector2.ZERO).y)
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = load(path)
	root.add_child(body)
	for i in engines.size():
		exhaust(root, "Flame%d" % i, engines[i][0], engines[i][1], 7.0)
	var hv := MeshInstance3D.new()
	hv.name = "Hover"
	var q := QuadMesh.new()
	q.size = hover
	q.material = _shader("ride_hover.gdshader")
	hv.mesh = q
	hv.rotation.x = -PI / 2
	hv.position.y = -0.06
	hv.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(hv)
	for i in fans.size():
		var f := MeshInstance3D.new()
		f.name = "Fan%d" % i
		var cm := CylinderMesh.new()
		cm.top_radius = fans[i][1]
		cm.bottom_radius = fans[i][1]
		cm.height = 0.01
		cm.radial_segments = 20
		var fm := StandardMaterial3D.new()
		fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fm.albedo_color = Color(0.08, 0.08, 0.1, 0.55)
		fm.metallic = 0.6
		fm.roughness = 0.3
		cm.material = fm
		f.mesh = cm
		f.position = fans[i][0]
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
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
	under.light_energy = 1.6
	under.omni_range = 4.0
	root.add_child(under)
	var key_l := OmniLight3D.new()
	key_l.name = "KeyLight"
	key_l.position = Vector3(0, 1.4, 2.2)
	key_l.light_energy = 1.0
	key_l.omni_range = 4.5
	root.add_child(key_l)
	Kit.save(root, "%s/cars/%s.tscn" % [DIR, key])


func exhaust(root: Node3D, name: String, pos: Vector3, r: float, length: float) -> Node3D:
	## a thruster's flame: a cone running back along +Z from the nozzle and a glow on the nozzle
	var holder := Node3D.new()
	holder.name = name
	holder.position = pos
	holder.add_to_group("flame", true)
	root.add_child(holder)
	var cone := MeshInstance3D.new()
	cone.name = "Cone"
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r * 0.15
	cm.height = r * length
	cm.radial_segments = 16
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	cm.material = _shader("ride_exhaust.gdshader")
	cone.mesh = cm
	cone.rotation.x = -PI / 2
	cone.position.z = r * length / 2.0
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(cone)
	var glow := MeshInstance3D.new()
	glow.name = "Glow"
	var q := QuadMesh.new()
	q.size = Vector2(r * 5.0, r * 5.0)
	var gm := ShaderMaterial.new()
	gm.shader = load("res://materials/shaders/glow.gdshader")
	gm.set_shader_parameter("intensity", 1.8)
	q.material = gm
	glow.mesh = q
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(glow)
	return holder


# ------------------------------------------------------------------ the five cars
# Each has its own livery in every era (the era shows in its light lines and engine glow): a strong colour or a
# dark one with bright lines, so it reads at about 60 px wide from the chase camera.

func arrow() -> void:
	## Arrow: an anti-gravity racer in racing red with white stripes: a needle nose, swept wings out to two
	## separate engine pods, and a high rear wing on canted fins (an upturned U from behind)
	var k := kit()
	var fus := []
	for s in [[-1.1, 0.015, 0.015, 0.1], [-0.85, 0.07, 0.045, 0.1], [-0.5, 0.14, 0.08, 0.11], [-0.1, 0.19, 0.1, 0.12], [0.35, 0.2, 0.1, 0.13], [0.8, 0.17, 0.085, 0.14], [1.0, 0.13, 0.07, 0.14]]:
		fus.append(_sec(s[0], s[1], s[2], s[3], 16, 2.4, 0.8))
	k.loft("paint", fus)
	var can := []
	for s in [[-0.58, 0.02, 0.012, 0.17], [-0.4, 0.09, 0.055, 0.18], [-0.14, 0.12, 0.08, 0.19], [0.1, 0.11, 0.07, 0.19], [0.3, 0.06, 0.035, 0.18], [0.4, 0.015, 0.01, 0.17]]:
		can.append(_sec(s[0], s[1], s[2], s[3], 16, 2.0))
	k.loft("glass", can)
	k.box("strip", Vector3(0, 0.215, 0.72), Vector3(0.025, 0.012, 0.5))
	k.box("tail", Vector3(0, 0.14, 1.005), Vector3(0.18, 0.04, 0.02))
	for s: int in [-1, 1]:
		# the swept wing, its glowing leading edge, and the pod at its tip
		_plate(k, "paint", [[s * 0.12, -0.42], [s * 0.5, 0.12], [s * 0.5, 0.62], [s * 0.12, 0.7]], 0.085, 0.115)
		_bar(k, "strip", Vector3(s * 0.13, 0.115, -0.43), Vector3(s * 0.49, 0.115, 0.1), 0.018)
		_pod(k, "paint", s * 0.5, [[-0.58, 0.02, 0.02, 0.1], [-0.36, 0.085, 0.07, 0.1], [0.0, 0.115, 0.095, 0.105], [0.6, 0.125, 0.105, 0.11], [0.95, 0.12, 0.1, 0.11]])
		k.cylinder("carbon", Vector3(s * 0.5, 0.1, -0.5), 0.05, 0.03, 12)
		_nozzle(k, Vector3(s * 0.5, 0.11, 0.95), 0.108)
		k.box("head", Vector3(s * 0.5, 0.1, -0.56), Vector3(0.06, 0.02, 0.02))
		# a canted fin up to the rear wing, its trailing edge lit
		_fin(k, "carbon", [[0.45, 0.2], [0.92, 0.2], [1.03, 0.52], [0.84, 0.52]], s * 0.5, 0.013)
		_bar(k, "strip", Vector3(s * 0.5, 0.21, 0.93), Vector3(s * 0.5, 0.51, 1.035), 0.016)
		k.box("carbon", Vector3(s * 0.6, 0.52, 0.92), Vector3(0.022, 0.1, 0.26))
	k.bevel_box("paint", Vector3(0, 0.535, 0.92), Vector3(1.18, 0.032, 0.24), 0.012)
	k.box("strip", Vector3(0, 0.535, 1.045), Vector3(1.14, 0.02, 0.016))
	_save_car(k, "arrow", [[Vector3(-0.5, 0.11, 0.96), 0.09], [Vector3(0.5, 0.11, 0.96), 0.09]], Vector2(1.7, 2.6), [],
		{"body": Color("c8102e"), "stripe": Color("f6f2ea"), "stripes": Vector2(0.5, 0.03)})


func bubble() -> void:
	## Bubble: a city pod in teal: a teardrop body under a big glass dome, ringed by a wide glowing thruster
	## (a halo round it from above), two little fins and one round engine
	var k := kit()
	var body := []
	for s in [[-0.98, 0.08, 0.05, 0.07], [-0.75, 0.33, 0.15, 0.07], [-0.35, 0.47, 0.21, 0.08], [0.15, 0.5, 0.22, 0.08], [0.6, 0.43, 0.19, 0.09], [0.92, 0.25, 0.13, 0.1], [1.0, 0.1, 0.06, 0.1]]:
		body.append(_sec(s[0], s[1], s[2], s[3], 20, 2.0))
	k.loft("paint", body)
	k.sphere("glass", Vector3(0, 0.25, -0.12), Vector3(0.38, 0.28, 0.55), 20, 12)
	var old := k.at(Transform3D(Basis().scaled(Vector3(1.0, 1.0, 1.75)), Vector3(0, 0.06, 0.02)))
	k.lathe("carbon", PackedVector2Array([Vector2(0.48, -0.05), Vector2(0.6, -0.04), Vector2(0.61, 0.03), Vector2(0.48, 0.05)]), Vector3.ZERO, 40)
	k.lathe("strip", PackedVector2Array([Vector2(0.612, -0.03), Vector2(0.625, -0.03), Vector2(0.625, 0.035), Vector2(0.6, 0.035)]), Vector3.ZERO, 40)
	k.xform = old
	_nozzle(k, Vector3(0, 0.1, 0.96), 0.13)
	for s: int in [-1, 1]:
		_fin(k, "paint", [[0.45, 0.22], [0.85, 0.18], [0.95, 0.38], [0.82, 0.4]], s * 0.2, 0.014)
		k.sphere("strip", Vector3(s * 0.2, 0.39, 0.9), Vector3(0.025, 0.025, 0.025), 8, 5)
		k.sphere("tail", Vector3(s * 0.24, 0.12, 0.92), Vector3(0.05, 0.035, 0.03), 10, 6)
		k.sphere("head", Vector3(s * 0.2, 0.08, -0.9), Vector3(0.07, 0.03, 0.03), 10, 6)
	_save_car(k, "bubble", [[Vector3(0, 0.1, 0.98), 0.1]], Vector2(1.8, 2.6), [],
		{"body": Color("10a596"), "stripe": Color("f4f1e8"), "stripes": Vector2(0.001, 0.05)})


func retro() -> void:
	## Retro: an 80s wedge in gloss black traced with neon (the era's colour on the shoulders, cyan on the sills
	## and the spoiler), a slatted tail-light panel and four hover pads glowing at its corners
	var k := kit()
	var body := []
	for s in [[-1.06, 0.43, 0.025, 0.03], [-0.65, 0.47, 0.07, 0.06], [-0.15, 0.48, 0.12, 0.1], [0.5, 0.5, 0.145, 0.12], [1.0, 0.5, 0.14, 0.12], [1.06, 0.47, 0.12, 0.12]]:
		body.append(_sec(s[0], s[1], s[2], s[3], 16, 5.0, 0.86))
	k.loft("paint", body, true, false)
	var cab := []
	for s in [[-0.48, 0.3, 0.012, 0.21], [-0.12, 0.34, 0.11, 0.24], [0.32, 0.33, 0.11, 0.25], [0.6, 0.27, 0.02, 0.25]]:
		cab.append(_sec(s[0], s[1], s[2], s[3], 16, 3.0, 0.62))
	k.loft("glass", cab, true, false)
	for i in 5:
		k.box("carbon", Vector3(0, 0.272, 0.66 + i * 0.07), Vector3(0.62, 0.012, 0.035))
	k.bevel_box("paint", Vector3(0, 0.4, 0.98), Vector3(1.0, 0.025, 0.18), 0.008)
	k.box("cyan", Vector3(0, 0.4, 1.072), Vector3(0.98, 0.018, 0.012))
	for s: int in [-1, 1]:
		k.box("carbon", Vector3(s * 0.38, 0.33, 0.98), Vector3(0.03, 0.12, 0.1))
		k.box("strip", Vector3(s * 0.49, 0.2, 0.02), Vector3(0.016, 0.016, 2.04))
		k.box("cyan", Vector3(s * 0.505, 0.035, 0.02), Vector3(0.014, 0.014, 1.9))
		_bar(k, "strip", Vector3(s * 0.43, 0.04, -1.065), Vector3(0.0, 0.04, -1.065), 0.016)
		_bar(k, "cyan", Vector3(s * 0.3, 0.255, -0.47), Vector3(s * 0.33, 0.33, -0.1), 0.012)
		for z: float in [-0.62, 0.66]:
			var c := Vector3(s * 0.48, -0.01, z)
			k.cylinder("carbon", c, 0.16, 0.07, 20)
			k.cylinder("pods", c - Vector3(0, 0.04, 0), 0.13, 0.01, 20)
			k.lathe("cyan", PackedVector2Array([Vector2(0.163, -0.015), Vector2(0.163, 0.02)]), c, 20)
	k.box("carbon", Vector3(0, 0.13, 1.065), Vector3(0.9, 0.15, 0.02))
	for i in 4:
		k.box("tail", Vector3(0, 0.075 + i * 0.035, 1.077), Vector3(0.86, 0.016, 0.01))
	_save_car(k, "retro", [[Vector3(-0.24, 0.06, 1.08), 0.05], [Vector3(0.24, 0.06, 1.08), 0.05]], Vector2(1.7, 2.6), [],
		{"body": Color("141418"), "stripe": Color("ff3fa4"), "stripes": Vector2(0.1, 0.03)})


func spinner() -> void:
	## Spinner: a police-style flyer in black and white: a white top over a black hull, a big red and blue light bar
	## that flashes, and four ducted fans far out on outriggers with glowing rims (an X from above)
	var k := kit()
	var body := []
	for s in [[-0.92, 0.22, 0.07, 0.1], [-0.72, 0.3, 0.12, 0.12], [-0.25, 0.33, 0.14, 0.14], [0.5, 0.33, 0.14, 0.15], [0.9, 0.28, 0.12, 0.15]]:
		body.append(_sec(s[0], s[1], s[2], s[3], 16, 3.2, 0.85))
	k.loft("paint", body)
	var hull := []
	for s in [[-0.95, 0.24, 0.05, 0.03], [-0.7, 0.33, 0.08, 0.02], [0.6, 0.34, 0.08, 0.02], [0.95, 0.3, 0.06, 0.03]]:
		hull.append(_sec(s[0], s[1], s[2], s[3], 16, 3.0))
	k.loft("carbon", hull)
	var cab := []
	for s in [[-0.5, 0.04, 0.02, 0.29], [-0.32, 0.25, 0.1, 0.3], [0.12, 0.27, 0.13, 0.31], [0.48, 0.2, 0.08, 0.3], [0.56, 0.04, 0.02, 0.29]]:
		cab.append(_sec(s[0], s[1], s[2], s[3], 16, 2.6, 0.8))
	k.loft("glass", cab)
	k.box("carbon", Vector3(0, 0.45, 0.05), Vector3(0.58, 0.03, 0.14))
	k.bevel_box("red", Vector3(-0.15, 0.49, 0.05), Vector3(0.27, 0.06, 0.12), 0.012)
	k.bevel_box("blue", Vector3(0.15, 0.49, 0.05), Vector3(0.27, 0.06, 0.12), 0.012)
	var fans := []
	for sx: int in [-1, 1]:
		k.box("strip", Vector3(sx * 0.335, 0.14, 0.0), Vector3(0.012, 0.025, 1.5))
		for z: float in [-0.62, 0.62]:
			var c := Vector3(sx * 0.72, 0.12, z)
			_bar(k, "carbon", Vector3(sx * 0.3, 0.12, z * 0.8), c - Vector3(sx * 0.22, 0, 0), 0.07)
			k.lathe("carbon", PackedVector2Array([Vector2(0.21, -0.06), Vector2(0.255, -0.05), Vector2(0.26, 0.05), Vector2(0.215, 0.06), Vector2(0.21, -0.06)]), c, 24)
			k.lathe("strip", PackedVector2Array([Vector2(0.262, 0.03), Vector2(0.262, 0.06), Vector2(0.235, 0.062)]), c, 24)
			k.cylinder("pods", c + Vector3(0, -0.05, 0), 0.2, 0.01, 20)
			k.cylinder("chrome", c + Vector3(0, 0.01, 0), 0.04, 0.05, 12)
			fans.append([c + Vector3(0, 0.02, 0), 0.2])
	for s: int in [-1, 1]:
		k.box("tail", Vector3(s * 0.2, 0.16, 0.905), Vector3(0.14, 0.05, 0.02))
		k.box("head", Vector3(s * 0.18, 0.12, -0.905), Vector3(0.14, 0.04, 0.02))
	_nozzle(k, Vector3(0, 0.09, 0.92), 0.07)
	_save_car(k, "spinner", [[Vector3(0, 0.09, 0.93), 0.06]], Vector2(2.1, 2.4), fans,
		{"body": Color("f1f1ee"), "stripe": Color("101114"), "stripes": Vector2(0.17, 0.05)})


func manta() -> void:
	## Manta: a stealthy flying wing in deep indigo: a wide swept wing with cyan leading edges, upturned tip fins
	## with red lamps, a bubble canopy and twin engines
	var k := kit()
	var wing := [[0.0, -1.05], [0.3, -0.55], [0.95, 0.33], [0.92, 0.55], [0.45, 0.46], [0.22, 0.74], [-0.22, 0.74], [-0.45, 0.46], [-0.92, 0.55], [-0.95, 0.33], [-0.3, -0.55]]
	_plate(k, "paint", wing, 0.07, 0.12)
	_pod(k, "paint", 0.0, [[-0.98, 0.03, 0.02, 0.1], [-0.6, 0.17, 0.06, 0.12], [-0.05, 0.27, 0.09, 0.13], [0.5, 0.25, 0.085, 0.13], [0.74, 0.2, 0.065, 0.12]], 16, 2.4)
	var can := []
	for s in [[-0.6, 0.02, 0.012, 0.18], [-0.45, 0.1, 0.05, 0.185], [-0.15, 0.13, 0.075, 0.2], [0.12, 0.1, 0.06, 0.2], [0.24, 0.02, 0.012, 0.19]]:
		can.append(_sec(s[0], s[1], s[2], s[3], 16, 2.0))
	k.loft("glass", can)
	for s: int in [-1, 1]:
		_bar(k, "cyan", Vector3(s * 0.03, 0.12, -1.03), Vector3(s * 0.3, 0.12, -0.55), 0.022)
		_bar(k, "cyan", Vector3(s * 0.3, 0.12, -0.55), Vector3(s * 0.955, 0.12, 0.33), 0.022)
		_bar(k, "strip", Vector3(s * 0.92, 0.12, 0.55), Vector3(s * 0.45, 0.12, 0.46), 0.016)
		_fin(k, "paint", [[0.22, 0.12], [0.58, 0.12], [0.62, 0.42], [0.48, 0.42]], s * 0.935, 0.014)
		_bar(k, "cyan", Vector3(s * 0.935, 0.13, 0.22), Vector3(s * 0.935, 0.42, 0.48), 0.014)
		k.box("tail", Vector3(s * 0.935, 0.42, 0.55), Vector3(0.035, 0.03, 0.12))
		_pod(k, "carbon", s * 0.17, [[0.2, 0.04, 0.03, 0.12], [0.45, 0.085, 0.065, 0.12], [0.76, 0.09, 0.07, 0.12]], 14, 2.0)
		_nozzle(k, Vector3(s * 0.17, 0.12, 0.76), 0.085)
		k.box("head", Vector3(s * 0.2, 0.1, -0.62), Vector3(0.12, 0.02, 0.02))
	_save_car(k, "manta", [[Vector3(-0.17, 0.12, 0.77), 0.07], [Vector3(0.17, 0.12, 0.77), 0.07]], Vector2(2.2, 2.4), [],
		{"body": Color("2a1b78"), "stripe": Color("35e6ff"), "stripes": Vector2(0.001, 0.03)})


# ------------------------------------------------------------------ the note ring

func ring() -> void:
	## the note ring: one quad drawn by ride_ring.gdshader, the cue ring (ride_cue.gdshader), the old ring's power-up
	## badges and its light
	var old := (load("res://scenes/track/note_ring.tscn") as PackedScene).instantiate()
	var root := Node3D.new()
	root.name = "NoteRing"
	root.set_script(load("res://scripts/gfx_ride_ring.gd"))
	var disc := MeshInstance3D.new()
	disc.name = "Disc"
	var q := QuadMesh.new()
	q.size = Vector2(2.7, 2.7)
	var dm := _shader("ride_ring.gdshader")
	dm.render_priority = -1
	q.material = dm
	disc.mesh = q
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(disc)
	var cue := MeshInstance3D.new()
	cue.name = "Cue"
	var cq := QuadMesh.new()
	cq.size = Vector2(1.9, 1.9)
	cq.material = _shader("ride_cue.gdshader")
	cue.mesh = cq
	cue.visible = false
	cue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(cue)
	for n in ["Magnet", "Shield"]:
		var src := old.get_node(n) as MeshInstance3D
		var mi := MeshInstance3D.new()
		mi.name = n
		mi.mesh = src.mesh
		mi.material_override = src.material_override.duplicate()
		mi.transform = src.transform
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	var lab := (old.get_node("Double") as Label3D).duplicate() as Label3D
	lab.font = (old.get_node("Double") as Label3D).font
	root.add_child(lab)
	var gl := (old.get_node("Glow") as OmniLight3D).duplicate() as OmniLight3D
	root.add_child(gl)
	old.free()
	Kit.save(root, DIR + "/note_ring.tscn")
