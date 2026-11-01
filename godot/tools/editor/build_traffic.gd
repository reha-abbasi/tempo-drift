extends RefCounted
## The traffic, as in the web game's KINDS: 1930s cars, double-decker buses and biplanes in the Past; taxis, trucks,
## buses, hover-cabs and drones later; and the hovering roadblock to hop over. Sizes are the web game's x 1.4 (world
## metres). Each vehicle's body paint is a surface named "paint" that the city recolours (scripts/traffic.gd).
## Vehicles face -Z; their origin is the middle of their cell in the flight grid.

const K := 1.4
const M := "res://materials/%s.tres"


func build(_host: Node) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/traffic"))
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.1, 0.1, 0.1)
	paint.metallic = 0.5
	paint.roughness = 0.3
	paint.clearcoat_enabled = true
	ResourceSaver.save(paint, M % "traffic_paint")
	oldcar()
	dbus()
	biplane()
	taxi()
	truck()
	bus()
	hovercab()
	drone()
	barrier()


func m(name: String) -> Material:
	return load(M % name)


func kit() -> MeshKit:
	var k := MeshKit.new()
	k.use("paint", m("traffic_paint"))
	k.use("chrome", m("chrome"))
	k.use("tire", m("rubber"))
	k.use("glass", m("glass_dark"))
	k.use("lit", m("window_warm"))
	k.use("tail", m("tail_glow"))
	k.use("head", m("lens"))
	k.use("white", m("paint_white"))
	k.use("dark", m("paint_graphite"))
	k.use("yellow", m("lane_yellow"))
	k.use("cyan", m("led_cyan"))
	k.use("amber", m("led_gold"))
	k.use("warn", m("tail_glow"))
	k.use("wood", m("wood_dark"))
	k.use("cream", m("paint_cream"))
	return k


func wheel(k: MeshKit, at: Vector3, r: float, w: float) -> void:
	var old := k.at(Transform3D(Basis(Vector3.FORWARD, PI / 2), at))
	k.cylinder("tire", Vector3.ZERO, r, w, 16)
	k.cylinder("chrome", Vector3(0, w / 2 + 0.005, 0), r * 0.55, 0.02, 12)
	k.cylinder("chrome", Vector3(0, -w / 2 - 0.005, 0), r * 0.55, 0.02, 12)
	k.xform = old


func save(k: MeshKit, key: String, ground: float, extra := func(_root: Node3D): pass) -> void:
	## ground: how far below the cell's middle the road is (street vehicles stand on it; fliers don't)
	var path := "res://assets/meshes/traffic/%s.res" % key
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/meshes/traffic"))
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
	Kit.save(root, "res://scenes/traffic/%s.tscn" % key)


## the street row's middle is 0.6 x 1.4 = 0.84 m above the road
const STREET := 0.84


func oldcar() -> void:
	## a 1930s motor car: long bonnet, upright cabin, sweeping mudguards, spare wheel on the back
	var k := kit()
	var s := K * 0.72
	k.bevel_box("paint", Vector3(0, 0.42, 0.0) * s, Vector3(0.8, 0.3, 1.9) * s, 0.06)
	k.bevel_box("paint", Vector3(0, 0.78, 0.3) * s, Vector3(0.76, 0.42, 0.9) * s, 0.06)
	k.box("glass", Vector3(0, 0.82, 0.3) * s, Vector3(0.78, 0.2, 0.84) * s)
	k.box("chrome", Vector3(0, 0.45, -0.97) * s, Vector3(0.5, 0.26, 0.04) * s)
	for z: float in [-0.68, 0.72]:
		for sx: int in [-1, 1]:
			wheel(k, Vector3(sx * 0.44, 0.27, z) * s, 0.25 * s, 0.16 * s)
			k.bevel_box("paint", Vector3(sx * 0.44, 0.52, z) * s, Vector3(0.22, 0.08, 0.56) * s, 0.03)
	for sx: int in [-1, 1]:
		k.sphere("head", Vector3(sx * 0.28, 0.6, -0.98) * s, Vector3(0.08, 0.08, 0.08) * s, 10, 6)
		k.box("tail", Vector3(sx * 0.3, 0.48, 0.97) * s, Vector3(0.1, 0.06, 0.03) * s)
	var o := k.at(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0.56, 1.0) * s))
	k.cylinder("tire", Vector3.ZERO, 0.17 * s, 0.1 * s, 14)
	k.xform = o
	save(k, "oldcar", STREET)


func dbus() -> void:
	## a red double-decker bus
	var k := kit()
	var s := K
	k.bevel_box("paint", Vector3(0, 0.6, 0) * s, Vector3(1.05, 0.9, 4.0) * s, 0.08)
	k.bevel_box("paint", Vector3(0, 1.48, 0.05) * s, Vector3(1.05, 0.78, 3.9) * s, 0.1)
	k.color = Color(0.7, 0.5, 0)
	k.box("lit", Vector3(0, 0.74, -0.1) * s, Vector3(1.07, 0.3, 3.4) * s)
	k.box("lit", Vector3(0, 1.54, 0) * s, Vector3(1.07, 0.3, 3.5) * s)
	k.color = Color.WHITE
	k.box("cream", Vector3(0, 1.09, 0.02) * s, Vector3(1.07, 0.08, 3.95) * s)
	k.box("glass", Vector3(0, 1.54, 2.0) * s, Vector3(0.9, 0.3, 0.03) * s)
	for z: float in [-1.3, 1.3]:
		for sx: int in [-1, 1]:
			wheel(k, Vector3(sx * 0.5, 0.25, z) * s, 0.25 * s, 0.18 * s)
	for sx: int in [-1, 1]:
		k.box("tail", Vector3(sx * 0.4, 0.34, 2.01) * s, Vector3(0.12, 0.08, 0.02) * s)
		k.sphere("head", Vector3(sx * 0.38, 0.4, -2.01) * s, Vector3(0.07, 0.07, 0.03) * s, 10, 6)
	save(k, "dbus", STREET)


func biplane() -> void:
	## a biplane: two wings, struts, a round cowl and a spinning propeller
	var k := kit()
	var s := K * 0.85
	k.loft("cream", [MeshKit.section(-0.95 * s, 0.17 * s, 0.17 * s, 0, 12, 2.0), MeshKit.section(-0.4 * s, 0.2 * s, 0.2 * s, 0, 12, 2.0), MeshKit.section(0.85 * s, 0.06 * s, 0.1 * s, 0.05 * s, 12, 2.0)])
	k.bevel_box("paint", Vector3(0, 0.3, -0.25) * s, Vector3(2.3, 0.04, 0.44) * s, 0.015)
	k.bevel_box("paint", Vector3(0, -0.14, -0.22) * s, Vector3(2.1, 0.04, 0.42) * s, 0.015)
	for sx: float in [-0.75, 0.75]:
		k.box("wood", Vector3(sx, 0.08, -0.25) * s, Vector3(0.03, 0.44, 0.03) * s)
	k.bevel_box("paint", Vector3(0, 0.05, 0.75) * s, Vector3(0.8, 0.03, 0.26) * s, 0.01)
	k.bevel_box("paint", Vector3(0, 0.2, 0.78) * s, Vector3(0.03, 0.32, 0.28) * s, 0.01)
	var o := k.at(Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0, -0.95) * s))
	k.cylinder("dark", Vector3.ZERO, 0.19 * s, 0.2 * s, 14)
	k.xform = o
	save(k, "biplane", 0.0, func(root: Node3D):
		var p := MeshInstance3D.new()
		p.name = "Propeller"
		var cm := CylinderMesh.new()
		cm.top_radius = 0.5 * s
		cm.bottom_radius = 0.5 * s
		cm.height = 0.01
		var pm := StandardMaterial3D.new()
		pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pm.albedo_color = Color(0.2, 0.2, 0.2, 0.3)
		cm.material = pm
		p.mesh = cm
		p.rotation.x = PI / 2
		p.position.z = -1.06 * s
		p.add_to_group("spin", true)
		root.add_child(p))


func taxi() -> void:
	var k := kit()
	var s := K
	k.bevel_box("paint", Vector3(0, 0.38, 0) * s, Vector3(0.95, 0.38, 2.1) * s, 0.08)
	k.bevel_box("glass", Vector3(0, 0.66, 0.1) * s, Vector3(0.8, 0.3, 1.0) * s, 0.08)
	k.bevel_box("amber", Vector3(0, 0.85, 0.1) * s, Vector3(0.3, 0.08, 0.15) * s, 0.02)
	for z: float in [-0.7, 0.7]:
		for sx: int in [-1, 1]:
			wheel(k, Vector3(sx * 0.45, 0.2, z) * s, 0.2 * s, 0.14 * s)
	for sx: int in [-1, 1]:
		k.box("tail", Vector3(sx * 0.32, 0.4, 1.06) * s, Vector3(0.2, 0.07, 0.03) * s)
		k.box("head", Vector3(sx * 0.32, 0.38, -1.06) * s, Vector3(0.18, 0.06, 0.03) * s)
	save(k, "taxi", STREET)


func truck() -> void:
	var k := kit()
	var s := K
	k.bevel_box("white", Vector3(0, 0.55, -1.4) * s, Vector3(1.0, 0.85, 1.2) * s, 0.08)
	k.box("glass", Vector3(0, 0.72, -2.0) * s, Vector3(0.92, 0.3, 0.05) * s)
	k.bevel_box("white", Vector3(0, 0.75, 0.55) * s, Vector3(1.1, 1.25, 2.6) * s, 0.05)
	k.box("paint", Vector3(0, 0.6, 0.55) * s, Vector3(1.12, 0.32, 2.55) * s)
	for z: float in [-1.4, 0.2, 1.4]:
		for sx: int in [-1, 1]:
			wheel(k, Vector3(sx * 0.5, 0.22, z) * s, 0.22 * s, 0.16 * s)
	for sx: int in [-1, 1]:
		k.box("tail", Vector3(sx * 0.42, 0.3, 1.87) * s, Vector3(0.12, 0.08, 0.02) * s)
	save(k, "truck", STREET)


func bus() -> void:
	var k := kit()
	var s := K
	k.bevel_box("white", Vector3(0, 0.71, 0) * s, Vector3(1.05, 1.15, 4.0) * s, 0.1)
	k.box("paint", Vector3(0, 0.93, -0.1) * s, Vector3(1.07, 0.34, 3.6) * s)
	k.color = Color(0.6, 0.5, 0)
	k.box("lit", Vector3(0, 0.95, -0.1) * s, Vector3(1.09, 0.26, 3.4) * s)
	k.color = Color.WHITE
	for z: float in [-1.3, 1.3]:
		for sx: int in [-1, 1]:
			wheel(k, Vector3(sx * 0.5, 0.22, z) * s, 0.22 * s, 0.16 * s)
	for sx: int in [-1, 1]:
		k.box("tail", Vector3(sx * 0.4, 0.3, 2.02) * s, Vector3(0.12, 0.08, 0.02) * s)
	save(k, "bus", STREET)


func hovercab() -> void:
	## a yellow hover-cab on four glowing pads (the skyway's traffic in the Present)
	var k := kit()
	var s := K
	k.bevel_box("yellow", Vector3(0, 0, 0) * s, Vector3(0.95, 0.36, 1.9) * s, 0.08)
	k.bevel_box("glass", Vector3(0, 0.3, 0.1) * s, Vector3(0.8, 0.28, 0.9) * s, 0.08)
	k.bevel_box("white", Vector3(0, 0.48, 0.1) * s, Vector3(0.3, 0.07, 0.14) * s, 0.02)
	for p in [[-0.42, -0.6], [0.42, -0.6], [-0.42, 0.6], [0.42, 0.6]]:
		k.cylinder("cyan", Vector3(p[0], -0.19, p[1]) * s, 0.15 * s, 0.02 * s, 16)
	for sx: int in [-1, 1]:
		k.box("tail", Vector3(sx * 0.32, 0.02, 0.96) * s, Vector3(0.2, 0.06, 0.02) * s)
	save(k, "hovercab", 0.0)


func drone() -> void:
	## a cargo drone (the Future's skyway): a metal box, a warning stripe and four red rotors
	var k := kit()
	var s := K
	k.bevel_box("dark", Vector3.ZERO, Vector3(0.95, 0.42, 1.15) * s, 0.06)
	k.box("warn", Vector3(0, 0.02, 0.585) * s, Vector3(0.82, 0.07, 0.02) * s)
	for rx: float in [-0.62, 0.62]:
		for rz: float in [-0.42, 0.42]:
			k.box("dark", Vector3(rx * 0.75, 0.18, rz) * s, Vector3(0.32, 0.05, 0.06) * s)
	save(k, "drone", 0.0, func(root: Node3D):
		for rx: float in [-0.62, 0.62]:
			for rz: float in [-0.42, 0.42]:
				var r := MeshInstance3D.new()
				r.name = "Rotor"
				var cm := CylinderMesh.new()
				cm.top_radius = 0.34 * s
				cm.bottom_radius = 0.34 * s
				cm.height = 0.01
				var rm := StandardMaterial3D.new()
				rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				rm.albedo_color = Color(1.0, 0.31, 0.38, 0.35)
				cm.material = rm
				r.mesh = cm
				r.position = Vector3(rx, 0.22, rz) * s
				r.add_to_group("spin", true)
				root.add_child(r))


func barrier() -> void:
	## the hovering roadblock: a striped bar on posts with blinking amber lamps and a hover glow underneath
	var k := kit()
	var s := K
	var stripe := StandardMaterial3D.new()
	stripe.albedo_color = Color(0.95, 0.95, 0.92)
	ResourceSaver.save(stripe, M % "barrier_white")
	k.use("bw", load(M % "barrier_white"))
	for i in 7:
		var x := -0.675 + (i + 0.5) * 1.35 / 7.0
		k.box("warn" if i % 2 == 0 else "bw", Vector3(x, 0.05, 0) * s, Vector3(1.35 / 7.0, 0.4, 0.16) * s)
	for sx: int in [-1, 1]:
		k.box("dark", Vector3(sx * 0.55, -0.3, 0) * s, Vector3(0.07, 0.55, 0.07) * s)
		k.box("amber", Vector3(sx * 0.52, 0.3, 0) * s, Vector3(0.14, 0.08, 0.1) * s)
	k.cylinder("cyan", Vector3(0, -0.58, 0) * s, 0.22 * s, 0.01, 16)
	save(k, "barrier", 0.0)
