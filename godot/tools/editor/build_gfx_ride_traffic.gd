extends RefCounted
## New traffic, era by era, saved in scenes/gfx_ride/traffic/ (the run swaps them in, scripts/gfx_ride.gd). The same sizes as the old vehicles (build_traffic.gd), so they fill the
## same cells the rules test hits in; more shape, glowing lamps and lit windows, and the body paint is still the
## surface with traffic_paint.tres that the city recolours. London: a 1930s motor car, a double-decker bus, a
## biplane. Rio: a saloon taxi, a box truck, a city bus, a hover-cab. Berlin 2075 gets hovering versions of the taxi,
## the truck and the bus ("_2075") and a new cargo drone.
##   godot --headless --path godot res://tools/editor/runner.tscn -- build_gfx_ride_traffic

const K := 1.4
const STREET := 0.84
const M := "res://materials/%s.tres"
const R := "res://materials/gfx_ride/%s"
const DIR := "res://scenes/gfx_ride/traffic"


func build(_host: Node) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color("ffd890")
	lamp.emission_enabled = true
	lamp.emission = Color("ffd890")
	lamp.emission_energy_multiplier = 5.0
	ResourceSaver.save(lamp, R % "lamp.tres")
	var neon := StandardMaterial3D.new()
	neon.albedo_color = Color("ff3fb4")
	neon.emission_enabled = true
	neon.emission = Color("ff3fb4")
	neon.emission_energy_multiplier = 5.0
	ResourceSaver.save(neon, R % "neon.tres")
	oldcar()
	dbus()
	biplane()
	taxi()
	truck()
	bus()
	hovercab()
	taxi_2075()
	truck_2075()
	bus_2075()
	drone()


func kit() -> MeshKit:
	var k := MeshKit.new()
	for n in [["paint", "traffic_paint"], ["chrome", "chrome"], ["tire", "rubber"], ["glass", "glass_dark"], ["lit", "window_warm"],
			["tail", "tail_glow"], ["head", "lens"], ["white", "paint_white"], ["dark", "paint_graphite"], ["black", "paint_black_gloss"],
			["yellow", "lane_yellow"], ["cyan", "led_cyan"], ["amber", "led_gold"], ["wood", "wood_dark"], ["cream", "paint_cream"]]:
		k.use(n[0], load(M % n[1]))
	k.use("lamp", load(R % "lamp.tres"))
	k.use("neon", load(R % "neon.tres"))
	k.use("pods", load(R % "pods.tres"))
	return k


static func sec(z: float, w: float, h: float, y0: float, n := 16, sq := 3.0, top := 1.0) -> Dictionary:
	return MeshKit.section(z, w, h, y0, n, sq, top)


func wheel(k: MeshKit, at: Vector3, r: float, w: float, rim := "chrome", wall := "") -> void:
	var old := k.at(Transform3D(Basis(Vector3.FORWARD, PI / 2), at))
	k.cylinder("tire", Vector3.ZERO, r, w, 18)
	for s: int in [-1, 1]:
		if wall != "":
			k.cylinder(wall, Vector3(0, s * (w / 2 + 0.003), 0), r * 0.8, 0.01, 18)
		k.cylinder(rim, Vector3(0, s * (w / 2 + 0.008), 0), r * 0.55, 0.012, 14)
	k.xform = old


func bar(k: MeshKit, mat: String, a: Vector3, b: Vector3, t: float) -> void:
	var dir := (b - a).normalized()
	var side := dir.cross(Vector3.UP)
	if side.length() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized()
	var old := k.at(Transform3D(Basis(side, side.cross(dir).normalized(), -dir), (a + b) / 2.0))
	k.box(mat, Vector3.ZERO, Vector3(t, t, a.distance_to(b)))
	k.xform = old


func pad(k: MeshKit, at: Vector3, r: float) -> void:
	## a hover pad: a dark housing with a glowing face underneath
	k.cylinder("dark", at, r, 0.06, 18)
	k.cylinder("cyan", at - Vector3(0, 0.035, 0), r * 0.8, 0.01, 18)


func save(k: MeshKit, key: String, ground: float, extra := func(_root: Node3D): pass) -> void:
	var path := "res://assets/meshes/gfx_ride/traffic_%s.res" % key
	ResourceSaver.save(k.bake(), path)
	print("   %s: %d triangles" % [key, k.triangles()])
	var root := Node3D.new()
	root.name = key.to_pascal_case()
	root.set_script(load("res://scripts/traffic.gd"))
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = load(path)
	body.position.y = -ground
	root.add_child(body)
	extra.call(root)
	Kit.save(root, "%s/%s.tscn" % [DIR, key])


func spinner(root: Node3D, name: String, at: Vector3, r: float, axis_z := false, c := Color(0.2, 0.2, 0.2, 0.3)) -> void:
	var p := MeshInstance3D.new()
	p.name = name
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = 0.01
	var pm := StandardMaterial3D.new()
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.albedo_color = c
	if c.r > 0.5:
		pm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.material = pm
	p.mesh = cm
	if axis_z:
		p.rotation.x = PI / 2
	p.position = at
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_to_group("spin", true)
	root.add_child(p)


# ------------------------------------------------------------------ London

func oldcar() -> void:
	## a 1930s motor car: a long bonnet behind a chrome grille, an upright cabin under a black roof, sweeping
	## mudguards, whitewall wheels, a spare wheel on the back and glowing lamps
	var k := kit()
	var s := K * 0.72
	k.box("black", Vector3(0, 0.3, 0.05) * s, Vector3(0.9, 0.04, 1.3) * s)
	k.loft("paint", [sec(-0.95 * s, 0.24 * s, 0.15 * s, 0.52 * s, 16, 3.0, 0.9), sec(-0.25 * s, 0.28 * s, 0.17 * s, 0.53 * s, 16, 3.0, 0.9)])
	k.bevel_box("chrome", Vector3(0, 0.52, -0.965) * s, Vector3(0.42, 0.36, 0.04) * s, 0.015)
	k.box("black", Vector3(0, 0.52, -0.99) * s, Vector3(0.34, 0.28, 0.02) * s)
	k.bevel_box("paint", Vector3(0, 0.74, 0.28) * s, Vector3(0.78, 0.5, 0.95) * s, 0.05)
	k.box("glass", Vector3(0, 0.88, 0.25) * s, Vector3(0.8, 0.22, 0.78) * s)
	k.box("glass", Vector3(0, 0.88, 0.75) * s, Vector3(0.62, 0.2, 0.02) * s)
	k.bevel_box("black", Vector3(0, 1.02, 0.3) * s, Vector3(0.8, 0.05, 1.0) * s, 0.02)
	k.bevel_box("paint", Vector3(0, 0.5, 0.86) * s, Vector3(0.76, 0.34, 0.3) * s, 0.06)
	for z: float in [-0.66, 0.72]:
		for sx: int in [-1, 1]:
			wheel(k, Vector3(sx * 0.43, 0.27, z) * s, 0.25 * s, 0.13 * s, "chrome", "cream")
			k.sphere("paint", Vector3(sx * 0.43, 0.44, z) * s, Vector3(0.12, 0.13, 0.32) * s, 14, 7)
	for sx: int in [-1, 1]:
		k.box("black", Vector3(sx * 0.47, 0.34, 0.03) * s, Vector3(0.12, 0.03, 0.9) * s)
		k.sphere("chrome", Vector3(sx * 0.3, 0.68, -0.95) * s, Vector3(0.09, 0.09, 0.07) * s, 12, 6)
		k.sphere("lamp", Vector3(sx * 0.3, 0.68, -1.0) * s, Vector3(0.07, 0.07, 0.02) * s, 12, 6)
		k.sphere("tail", Vector3(sx * 0.33, 0.52, 1.02) * s, Vector3(0.05, 0.05, 0.03) * s, 10, 6)
	var o := k.at(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0.58, 1.05) * s))
	k.cylinder("tire", Vector3.ZERO, 0.18 * s, 0.1 * s, 18)
	k.cylinder("chrome", Vector3(0, 0.055 * s, 0), 0.1 * s, 0.01, 14)
	k.xform = o
	k.box("cream", Vector3(0, 0.34, 1.03) * s, Vector3(0.3, 0.08, 0.02) * s)
	save(k, "oldcar", STREET)


func dbus() -> void:
	## a double-decker bus: lit windows on both decks between slim pillars, a cream band and roof, the open platform
	## at the back with its pole, a lit route board
	var k := kit()
	var s := K
	k.bevel_box("paint", Vector3(0, 0.6, 0) * s, Vector3(1.05, 0.9, 4.0) * s, 0.08)
	k.bevel_box("paint", Vector3(0, 1.5, 0.05) * s, Vector3(1.05, 0.74, 3.9) * s, 0.1)
	k.color = Color(0.75, 0.55, 0.1)
	k.box("lit", Vector3(0, 0.8, -0.2) * s, Vector3(1.07, 0.32, 3.2) * s)
	k.box("lit", Vector3(0, 1.56, 0.05) * s, Vector3(1.07, 0.3, 3.6) * s)
	k.color = Color.WHITE
	for i in 7:
		var z := -1.7 + i * 0.5
		k.box("paint", Vector3(0, 0.8, z) * s, Vector3(1.09, 0.34, 0.06) * s)
		k.box("paint", Vector3(0, 1.56, z + 0.2) * s, Vector3(1.09, 0.32, 0.06) * s)
	k.box("cream", Vector3(0, 1.1, 0.02) * s, Vector3(1.08, 0.12, 3.96) * s)
	k.box("cream", Vector3(0, 0.36, 0.0) * s, Vector3(1.07, 0.05, 3.98) * s)
	k.bevel_box("cream", Vector3(0, 1.88, 0.05) * s, Vector3(1.0, 0.06, 3.86) * s, 0.03)
	# the back: the platform, its pole, the stair window and the route board
	k.box("dark", Vector3(-0.27, 0.66, 1.9) * s, Vector3(0.46, 0.66, 0.24) * s)
	k.cylinder("chrome", Vector3(-0.05, 0.66, 2.01) * s, 0.02 * s, 0.66 * s, 8)
	k.box("lit", Vector3(0.25, 0.8, 2.01) * s, Vector3(0.36, 0.3, 0.02) * s)
	k.box("glass", Vector3(0, 1.56, 2.0) * s, Vector3(0.86, 0.3, 0.03) * s)
	k.box("lamp", Vector3(0, 1.8, 2.0) * s, Vector3(0.5, 0.09, 0.02) * s)
	for z: float in [-1.3, 1.3]:
		for sx: int in [-1, 1]:
			wheel(k, Vector3(sx * 0.5, 0.25, z) * s, 0.25 * s, 0.18 * s, "paint")
	for sx: int in [-1, 1]:
		k.sphere("tail", Vector3(sx * 0.42, 0.34, 2.01) * s, Vector3(0.06, 0.06, 0.02) * s, 10, 6)
		k.sphere("lamp", Vector3(sx * 0.38, 0.4, -2.01) * s, Vector3(0.07, 0.07, 0.03) * s, 10, 6)
	save(k, "dbus", STREET)


func biplane() -> void:
	## a biplane: a cream fuselage with a pilot in the open cockpit, wings braced with struts and wires, wheels, a
	## tail, a spinning propeller, and red and green lamps at the wing tips
	var k := kit()
	var s := K * 0.85
	k.loft("cream", [sec(-0.95 * s, 0.17 * s, 0.17 * s, 0, 14, 2.0), sec(-0.4 * s, 0.2 * s, 0.2 * s, 0, 14, 2.0), sec(0.4 * s, 0.13 * s, 0.15 * s, 0.03 * s, 14, 2.0), sec(0.9 * s, 0.04 * s, 0.07 * s, 0.07 * s, 14, 2.0)])
	k.bevel_box("paint", Vector3(0, 0.3, -0.25) * s, Vector3(2.3, 0.045, 0.44) * s, 0.02)
	k.bevel_box("paint", Vector3(0, -0.14, -0.22) * s, Vector3(2.1, 0.045, 0.42) * s, 0.02)
	for sx: float in [-0.75, 0.75]:
		for dz: float in [-0.15, 0.12]:
			k.box("wood", Vector3(sx, 0.08, -0.25 + dz) * s, Vector3(0.03, 0.44, 0.03) * s)
		bar(k, "dark", Vector3(sx * 0.98, 0.3, -0.25) * s, Vector3(sx * 0.35, -0.14, -0.22) * s, 0.008)
	for sx: int in [-1, 1]:
		k.box("wood", Vector3(sx * 0.14, 0.16, -0.32) * s, Vector3(0.025, 0.3, 0.025) * s)
		k.sphere("tail" if sx < 0 else "cyan", Vector3(sx * 1.15, 0.3, -0.25) * s, Vector3(0.04, 0.04, 0.04) * s, 8, 5)
		bar(k, "dark", Vector3(sx * 0.12, -0.2, -0.45) * s, Vector3(sx * 0.2, -0.42, -0.4) * s, 0.025 * s)
		wheel(k, Vector3(sx * 0.22, -0.45, -0.4) * s, 0.1 * s, 0.05 * s, "dark")
	# the cockpit and the pilot's leather helmet and goggles
	k.cylinder("black", Vector3(0, 0.18, 0.1) * s, 0.14 * s, 0.03 * s, 14)
	k.sphere("wood", Vector3(0, 0.27, 0.1) * s, Vector3(0.09, 0.1, 0.09) * s, 10, 6)
	k.box("chrome", Vector3(0, 0.29, 0.02) * s, Vector3(0.14, 0.035, 0.03) * s)
	# the tail
	k.bevel_box("paint", Vector3(0, 0.08, 0.8) * s, Vector3(0.8, 0.03, 0.24) * s, 0.01)
	k.bevel_box("paint", Vector3(0, 0.24, 0.84) * s, Vector3(0.03, 0.34, 0.26) * s, 0.01)
	k.box("lamp", Vector3(0, 0.08, 0.93) * s, Vector3(0.04, 0.03, 0.02) * s)
	var o := k.at(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0, -0.95) * s))
	k.cylinder("dark", Vector3.ZERO, 0.19 * s, 0.2 * s, 16)
	k.cylinder("chrome", Vector3(0, -0.12 * s, 0), 0.05 * s, 0.06 * s, 10)
	k.xform = o
	save(k, "biplane", 0.0, func(root: Node3D): spinner(root, "Propeller", Vector3(0, 0, -1.06 * s), 0.5 * s, true))


# ------------------------------------------------------------------ Rio, today

func taxi() -> void:
	## a saloon taxi: bonnet, glass cabin and boot shaped as one body, a lit TAXI sign on the roof, a red light bar
	## across the back
	var k := kit()
	var s := K
	var body := []
	for p in [[-1.05, 0.45, 0.12, 0.34], [-0.75, 0.47, 0.16, 0.36], [-0.3, 0.475, 0.19, 0.38], [0.55, 0.475, 0.19, 0.38], [0.9, 0.465, 0.16, 0.4], [1.05, 0.44, 0.13, 0.4]]:
		body.append(sec(p[0] * s, p[1] * s, p[2] * s, p[3] * s, 16, 4.0, 0.92))
	k.loft("paint", body)
	var cab := []
	for p in [[-0.4, 0.4, 0.01, 0.56], [-0.12, 0.4, 0.14, 0.6], [0.42, 0.4, 0.14, 0.6], [0.72, 0.38, 0.01, 0.58]]:
		cab.append(sec(p[0] * s, p[1] * s, p[2] * s, p[3] * s, 16, 3.0, 0.78))
	k.loft("glass", cab)
	k.bevel_box("paint", Vector3(0, 0.745, 0.15) * s, Vector3(0.66, 0.03, 0.52) * s, 0.01)
	k.bevel_box("amber", Vector3(0, 0.8, 0.12) * s, Vector3(0.32, 0.08, 0.14) * s, 0.02)
	for z: float in [-0.68, 0.68]:
		for sx: int in [-1, 1]:
			wheel(k, Vector3(sx * 0.45, 0.2, z) * s, 0.2 * s, 0.14 * s, "dark")
	k.box("tail", Vector3(0, 0.46, 1.06) * s, Vector3(0.8, 0.05, 0.02) * s)
	k.box("cream", Vector3(0, 0.32, 1.07) * s, Vector3(0.26, 0.08, 0.02) * s)
	for sx: int in [-1, 1]:
		k.box("head", Vector3(sx * 0.32, 0.4, -1.06) * s, Vector3(0.2, 0.06, 0.03) * s)
	save(k, "taxi", STREET)


func truck() -> void:
	## a box truck: a cab with a big windscreen and a chrome grille, a ribbed cargo box with a band of paint, a
	## roller door with an underrun bar, and lamps
	var k := kit()
	var s := K
	k.bevel_box("white", Vector3(0, 0.55, -1.4) * s, Vector3(1.0, 0.85, 1.2) * s, 0.1)
	k.box("glass", Vector3(0, 0.78, -1.98) * s, Vector3(0.9, 0.34, 0.05) * s)
	k.box("glass", Vector3(0, 0.78, -1.5) * s, Vector3(1.02, 0.3, 0.6) * s)
	k.box("chrome", Vector3(0, 0.36, -2.0) * s, Vector3(0.7, 0.18, 0.03) * s)
	k.box("dark", Vector3(0, 0.18, -2.0) * s, Vector3(1.0, 0.1, 0.06) * s)
	k.bevel_box("white", Vector3(0, 0.78, 0.55) * s, Vector3(1.1, 1.3, 2.6) * s, 0.04)
	k.box("paint", Vector3(0, 0.62, 0.55) * s, Vector3(1.12, 0.34, 2.56) * s)
	for i in 9:
		k.box("white", Vector3(0, 0.78, -0.65 + i * 0.3) * s, Vector3(1.13, 1.24, 0.03) * s)
	for i in 8:
		k.box("dark", Vector3(0, 0.3 + i * 0.14, 1.86) * s, Vector3(0.96, 0.015, 0.01) * s)
	k.box("dark", Vector3(0, 0.12, 1.84) * s, Vector3(1.0, 0.06, 0.05) * s)
	for i in 6:
		k.box("tail" if i % 2 == 0 else "white", Vector3(-0.42 + i * 0.17, 0.12, 1.87) * s, Vector3(0.16, 0.05, 0.01) * s)
	for z: float in [-1.4, 0.2, 1.4]:
		for sx: int in [-1, 1]:
			wheel(k, Vector3(sx * 0.5, 0.22, z) * s, 0.22 * s, 0.16 * s, "dark")
	for sx: int in [-1, 1]:
		k.box("tail", Vector3(sx * 0.46, 0.28, 1.87) * s, Vector3(0.1, 0.14, 0.02) * s)
		k.box("amber", Vector3(sx * 0.53, 1.42, 1.86) * s, Vector3(0.04, 0.04, 0.02) * s)
		k.box("head", Vector3(sx * 0.36, 0.42, -2.01) * s, Vector3(0.16, 0.07, 0.02) * s)
		k.box("dark", Vector3(sx * 0.56, 0.86, -1.9) * s, Vector3(0.04, 0.16, 0.08) * s)
	save(k, "truck", STREET)


func bus() -> void:
	## a city bus: a long body with big tinted windows, some lit, a band of the city's bus colour, lit route
	## displays at both ends and a rear engine grille
	var k := kit()
	var s := K
	k.bevel_box("white", Vector3(0, 0.71, 0) * s, Vector3(1.05, 1.15, 4.0) * s, 0.12)
	k.box("glass", Vector3(0, 0.95, -0.05) * s, Vector3(1.07, 0.46, 3.7) * s)
	k.color = Color(0.6, 0.48, 0.15)
	for i in 6:
		k.box("lit", Vector3(0, 0.95, -1.5 + i * 0.6) * s, Vector3(1.075, 0.38, 0.42) * s)
	k.color = Color.WHITE
	k.box("paint", Vector3(0, 0.4, 0) * s, Vector3(1.07, 0.24, 3.96) * s)
	k.box("paint", Vector3(0, 1.24, 0) * s, Vector3(1.07, 0.06, 3.96) * s)
	k.box("glass", Vector3(0, 0.9, -2.0) * s, Vector3(0.95, 0.6, 0.03) * s)
	k.box("amber", Vector3(0, 1.2, -2.01) * s, Vector3(0.7, 0.1, 0.02) * s)
	k.box("amber", Vector3(0, 1.2, 2.01) * s, Vector3(0.5, 0.09, 0.02) * s)
	for i in 5:
		k.box("dark", Vector3(0, 0.45 + i * 0.07, 2.01) * s, Vector3(0.7, 0.025, 0.01) * s)
	for z: float in [-1.3, 1.3]:
		for sx: int in [-1, 1]:
			wheel(k, Vector3(sx * 0.5, 0.22, z) * s, 0.22 * s, 0.16 * s, "dark")
	for sx: int in [-1, 1]:
		k.box("tail", Vector3(sx * 0.44, 0.38, 2.02) * s, Vector3(0.1, 0.22, 0.02) * s)
		k.box("head", Vector3(sx * 0.38, 0.36, -2.02) * s, Vector3(0.18, 0.07, 0.02) * s)
	save(k, "bus", STREET)


func hovercab() -> void:
	## a yellow hover-cab: a rounded body under a glass bubble, four glowing pads, a light bar at the back
	var k := kit()
	var s := K
	var body := []
	for p in [[-0.95, 0.3, 0.1, 0.0], [-0.65, 0.46, 0.16, 0.0], [0.2, 0.48, 0.18, 0.0], [0.8, 0.44, 0.16, 0.02], [0.95, 0.36, 0.12, 0.02]]:
		body.append(sec(p[0] * s, p[1] * s, p[2] * s, p[3] * s, 16, 3.0, 0.85))
	k.loft("yellow", body)
	k.sphere("glass", Vector3(0, 0.2, 0.05) * s, Vector3(0.38, 0.2, 0.55) * s, 16, 8)
	k.bevel_box("white", Vector3(0, 0.41, 0.1) * s, Vector3(0.28, 0.07, 0.14) * s, 0.02)
	k.box("black", Vector3(0, 0.0, 0.0) * s, Vector3(0.99, 0.05, 1.8) * s)
	for p in [[-0.42, -0.6], [0.42, -0.6], [-0.42, 0.6], [0.42, 0.6]]:
		pad(k, Vector3(p[0], -0.2, p[1]) * s, 0.15 * s)
	k.box("tail", Vector3(0, 0.05, 0.96) * s, Vector3(0.7, 0.05, 0.02) * s)
	save(k, "hovercab", 0.0)


# ------------------------------------------------------------------ Berlin 2075

func taxi_2075() -> void:
	## a hover-taxi of 2075: a low teardrop body on pads, a wraparound canopy, neon lines along its sides and a lit
	## sign on the roof
	var k := kit()
	var s := K
	var body := []
	for p in [[-1.05, 0.2, 0.07, 0.3], [-0.8, 0.42, 0.13, 0.32], [-0.2, 0.48, 0.17, 0.35], [0.6, 0.47, 0.17, 0.36], [1.05, 0.38, 0.12, 0.38]]:
		body.append(sec(p[0] * s, p[1] * s, p[2] * s, p[3] * s, 16, 2.8, 0.88))
	k.loft("paint", body)
	var cab := []
	for p in [[-0.55, 0.3, 0.01, 0.5], [-0.25, 0.38, 0.14, 0.52], [0.4, 0.37, 0.13, 0.53], [0.75, 0.3, 0.01, 0.52]]:
		cab.append(sec(p[0] * s, p[1] * s, p[2] * s, p[3] * s, 16, 2.4, 0.8))
	k.loft("glass", cab)
	for sx: int in [-1, 1]:
		k.box("neon", Vector3(sx * 0.48, 0.36, 0.0) * s, Vector3(0.012, 0.02, 1.6) * s)
		for z: float in [-0.6, 0.6]:
			pad(k, Vector3(sx * 0.36, 0.17, z) * s, 0.13 * s)
	k.bevel_box("amber", Vector3(0, 0.68, 0.1) * s, Vector3(0.3, 0.06, 0.12) * s, 0.02)
	k.box("tail", Vector3(0, 0.4, 1.06) * s, Vector3(0.7, 0.03, 0.02) * s)
	save(k, "taxi_2075", STREET)


func truck_2075() -> void:
	## a hover freighter of 2075: a sloped cab and a long cargo pod with glowing seams, riding on pads with a
	## thruster ring at the back
	var k := kit()
	var s := K
	var cab := []
	for p in [[-2.0, 0.4, 0.2, 0.55], [-1.75, 0.5, 0.38, 0.65], [-0.95, 0.52, 0.42, 0.72]]:
		cab.append(sec(p[0] * s, p[1] * s, p[2] * s, p[3] * s, 16, 3.2, 0.8))
	k.loft("white", cab)
	k.box("glass", Vector3(0, 0.88, -1.72) * s, Vector3(0.84, 0.22, 0.36) * s)
	k.bevel_box("dark", Vector3(0, 0.78, 0.55) * s, Vector3(1.1, 1.24, 2.6) * s, 0.12)
	k.box("paint", Vector3(0, 0.78, 0.55) * s, Vector3(1.12, 0.5, 2.5) * s)
	for i in 4:
		k.box("cyan", Vector3(0, 0.78, -0.55 + i * 0.73) * s, Vector3(1.13, 1.1, 0.012) * s)
	k.box("cyan", Vector3(0, 1.41, 0.55) * s, Vector3(0.9, 0.012, 2.4) * s)
	for z: float in [-1.4, 0.0, 1.3]:
		for sx: int in [-1, 1]:
			pad(k, Vector3(sx * 0.38, 0.14, z) * s, 0.16 * s)
	var o := k.at(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0.78, 1.86) * s))
	k.lathe("chrome", PackedVector2Array([Vector2(0.3 * s, 0.0), Vector2(0.34 * s, 0.04 * s), Vector2(0.28 * s, 0.05 * s)]), Vector3.ZERO, 20)
	k.cylinder("pods", Vector3(0, 0.02 * s, 0), 0.27 * s, 0.01, 20)
	k.xform = o
	for sx: int in [-1, 1]:
		k.box("tail", Vector3(sx * 0.5, 0.3, 1.86) * s, Vector3(0.06, 0.3, 0.02) * s)
	save(k, "truck_2075", STREET)


func bus_2075() -> void:
	## a hover bus of 2075: a long rounded body with a band of lit windows, a neon line round the roof and a lit
	## display at the back, on six pads
	var k := kit()
	var s := K
	var body := []
	for p in [[-2.0, 0.42, 0.5, 0.76], [-1.85, 0.52, 0.56, 0.76], [1.85, 0.52, 0.56, 0.76], [2.0, 0.46, 0.52, 0.76]]:
		body.append(sec(p[0] * s, p[1] * s, p[2] * s, p[3] * s, 16, 3.5, 0.9))
	k.loft("white", body)
	k.box("glass", Vector3(0, 0.98, 0) * s, Vector3(1.06, 0.4, 3.6) * s)
	k.color = Color(0.5, 0.55, 0.6)
	for i in 6:
		k.box("lit", Vector3(0, 0.98, -1.5 + i * 0.6) * s, Vector3(1.065, 0.34, 0.45) * s)
	k.color = Color.WHITE
	k.box("paint", Vector3(0, 0.5, 0) * s, Vector3(1.06, 0.2, 3.7) * s)
	k.box("neon", Vector3(0, 1.3, 0) * s, Vector3(1.0, 0.02, 3.7) * s)
	k.box("cyan", Vector3(0, 1.15, 2.02) * s, Vector3(0.6, 0.1, 0.02) * s)
	k.box("tail", Vector3(0, 0.45, 2.02) * s, Vector3(0.9, 0.04, 0.02) * s)
	for z: float in [-1.4, 0.0, 1.4]:
		for sx: int in [-1, 1]:
			pad(k, Vector3(sx * 0.36, 0.17, z) * s, 0.17 * s)
	save(k, "bus_2075", STREET)


func drone() -> void:
	## a cargo drone: a container slung under a frame with four ducted rotors with glowing rims, warning stripes and
	## blinking-red corner lamps
	var k := kit()
	var s := K
	k.bevel_box("paint", Vector3(0, -0.05, 0) * s, Vector3(0.7, 0.32, 0.95) * s, 0.04)
	k.bevel_box("dark", Vector3(0, 0.15, 0) * s, Vector3(0.95, 0.08, 1.15) * s, 0.03)
	for i in 5:
		k.box("amber" if i % 2 == 0 else "black", Vector3(-0.3 + i * 0.15, -0.05, 0.48) * s, Vector3(0.15, 0.1, 0.01) * s)
	for rx: float in [-0.62, 0.62]:
		for rz: float in [-0.42, 0.42]:
			var c := Vector3(rx * 0.75, 0.2, rz) * s
			k.lathe("dark", PackedVector2Array([Vector2(0.3 * s, -0.04), Vector2(0.34 * s, -0.03), Vector2(0.34 * s, 0.04), Vector2(0.3 * s, 0.05)]), c, 22)
			k.lathe("neon", PackedVector2Array([Vector2(0.345 * s, 0.02), Vector2(0.345 * s, 0.045)]), c, 22)
			k.sphere("tail", c + Vector3(signf(rx) * 0.36 * s, 0, 0), Vector3(0.04, 0.04, 0.04) * s, 8, 5)
	save(k, "drone", 0.0, func(root: Node3D):
		for rx: float in [-0.62, 0.62]:
			for rz: float in [-0.42, 0.42]:
				spinner(root, "Rotor", Vector3(rx * 0.75, 0.22, rz) * s, 0.29 * s, false, Color(1.0, 0.31, 0.38, 0.3)))
