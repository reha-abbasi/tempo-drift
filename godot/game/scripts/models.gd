class_name Models
extends RefCounted
## Everything that moves, built from simple shapes with good materials: the flying car, the pilot on a jetpack,
## the traffic of 1890 (motor cars, a double-decker bus, biplanes), the hop-over barrier and the finish arch.
## Forward is -Z everywhere.

static func mat(col: Color, rough := 0.5, metal := 0.0, emit := Color.BLACK, emit_e := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	if emit_e > 0.0:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = emit_e
	return m

static func paint(col: Color) -> StandardMaterial3D:
	var m := mat(col, 0.28, 0.45)
	m.clearcoat_enabled = true
	m.clearcoat = 1.0
	m.clearcoat_roughness = 0.08
	return m

static func glow(col: Color, e := 3.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col * e
	return m

static func add_glow_sprite(parent: Node3D, pos: Vector3, size: float, col: Color, energy := 1.0) -> MeshInstance3D:
	var q := QuadMesh.new()
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/halo.gdshader")
	m.set_shader_parameter("tint", col)
	m.set_shader_parameter("energy", energy)
	m.set_shader_parameter("fade", 0.0)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.position = pos
	mi.scale = Vector3.ONE * size
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static func part(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3, scl := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi

static func box(w: float, h: float, d: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(w, h, d)
	return b

static func sphere(r: float, seg := 20) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = seg / 2
	return s

static func cyl(r_top: float, r_bot: float, h: float, seg := 16) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = seg
	return c

static func capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 20
	c.rings = 8
	return c

# ---------------------------------------------------------------- the player's car

## a cream-and-chrome flying roadster with a glass bubble, two thruster pods at the back and hover pads below.
## Returns the car; its pods, flames and lights are kept in meta for the animation
static func car() -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var cream := paint(Color(0.9, 0.84, 0.72))
	var maroon := paint(Color(0.38, 0.07, 0.09))
	var chrome := mat(Color(0.92, 0.92, 0.95), 0.1, 1.0)
	var dark := mat(Color(0.05, 0.05, 0.06), 0.45, 0.3)
	var glass := mat(Color(0.18, 0.22, 0.28), 0.04, 0.6)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color.a = 0.55
	# the long body: a stretched capsule, a lower skirt in maroon, a chrome waistline
	part(body, capsule(0.34, 2.15), cream, Vector3(0, 0.0, 0), Vector3(1.62, 0.78, 1.0), Vector3(PI * 0.5, 0, 0))
	part(body, capsule(0.3, 2.0), maroon, Vector3(0, -0.12, 0.02), Vector3(1.78, 0.55, 1.0), Vector3(PI * 0.5, 0, 0))
	part(body, box(1.16, 0.035, 1.9), chrome, Vector3(0, 0.03, 0.02))
	# four teardrop fenders
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			part(body, sphere(0.26), cream, Vector3(sx * 0.5, -0.1, sz * 0.62), Vector3(0.75, 0.62, 1.55))
	# the cockpit: a glass bubble with the pilot's head inside
	part(body, sphere(0.36, 24), glass, Vector3(0, 0.26, 0.12), Vector3(1.05, 0.72, 1.45))
	pilot_head(body, Vector3(0, 0.3, 0.2))
	# grille, bumpers and the stripe that glows along each side
	part(body, box(0.5, 0.16, 0.06), chrome, Vector3(0, -0.04, -1.08))
	part(body, capsule(0.035, 1.1), chrome, Vector3(0, -0.2, -1.1), Vector3.ONE, Vector3(0, 0, PI * 0.5))
	part(body, capsule(0.035, 1.1), chrome, Vector3(0, -0.2, 1.1), Vector3.ONE, Vector3(0, 0, PI * 0.5))
	var stripe := glow(Color(1.0, 0.76, 0.42), 1.6)
	for sx in [-1.0, 1.0]:
		part(body, box(0.02, 0.025, 1.4), stripe, Vector3(sx * 0.555, 0.0, 0.0))
	# headlamps and tail lamps
	var head := glow(Color(1.0, 0.92, 0.75), 4.0)
	var tail := glow(Color(1.0, 0.12, 0.08), 3.0)
	for sx in [-1.0, 1.0]:
		part(body, sphere(0.075), head, Vector3(sx * 0.34, -0.02, -1.08))
		part(body, capsule(0.04, 0.18), tail, Vector3(sx * 0.42, 0.02, 1.06), Vector3.ONE, Vector3(0, 0, PI * 0.5))
	# the thruster pods with a glowing core, a flame and a halo
	var pods := []
	var flames := []
	var pod_glow := glow(Color(1.0, 0.72, 0.42), 3.5)
	var flame_mat := ShaderMaterial.new()
	flame_mat.shader = load("res://shaders/ring.gdshader")
	for sx in [-1.0, 1.0]:
		var pod := Node3D.new()
		pod.position = Vector3(sx * 0.38, -0.12, 0.95)
		body.add_child(pod)
		part(pod, cyl(0.15, 0.13, 0.42), chrome, Vector3.ZERO, Vector3.ONE, Vector3(PI * 0.5, 0, 0))
		part(pod, cyl(0.11, 0.11, 0.02), pod_glow, Vector3(0, 0, 0.215), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
		var fl := part(pod, cyl(0.1, 0.0, 0.6, 12), flame_mat, Vector3(0, 0, 0.52), Vector3.ONE, Vector3(-PI * 0.5, 0, 0))
		fl.set_instance_shader_parameter("tint", Color(1.0, 0.55, 0.22, 1.0))
		fl.set_instance_shader_parameter("glow", 1.6)
		fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flames.append(fl)
		add_glow_sprite(pod, Vector3(0, 0, 0.3), 0.9, Color(1.0, 0.6, 0.3), 0.9)
		pods.append(pod)
	# hover pads underneath, and the glow they throw on the road
	var pad_glow := glow(Color(1.0, 0.8, 0.5), 2.5)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			part(body, cyl(0.12, 0.12, 0.03), pad_glow, Vector3(sx * 0.48, -0.26, sz * 0.6))
	# the headlamp beam that lights the cobbles ahead
	var beam := SpotLight3D.new()
	beam.light_color = Color(1.0, 0.88, 0.7)
	beam.light_energy = 2.2
	beam.spot_range = 16.0
	beam.spot_angle = 24.0
	beam.spot_attenuation = 0.8
	beam.position = Vector3(0, 0.0, -1.0)
	beam.rotation = Vector3(-0.3, 0, 0)
	body.add_child(beam)
	var under := OmniLight3D.new()
	under.light_color = Color(1.0, 0.7, 0.42)
	under.light_energy = 1.3
	under.omni_range = 4.8
	under.position = Vector3(0, -0.8, 0.3)
	body.add_child(under)
	root.set_meta("body", body)
	root.set_meta("pods", pods)
	root.set_meta("flames", flames)
	root.set_meta("under", under)
	root.set_meta("beam", beam)
	return root

# ---------------------------------------------------------------- the pilot on a jetpack

## a 1920s daredevil aviator: leather flying jacket with a shearling collar, a leather cap with brass goggles pushed up,
## a white silk scarf streaming behind, riding boots, and a jetpack of two brass tanks with copper bands and a gauge.
## Leaning into the flight, hands on the pack's control grips. The scarf's pieces are kept in meta to ripple in the wind
static func pilot() -> Node3D:
	var root := Node3D.new()
	var rig := Node3D.new()
	rig.name = "Rig"
	root.add_child(rig)
	var body := Node3D.new()
	body.rotation.x = -0.32
	rig.add_child(body)
	var leather := mat(Color(0.34, 0.19, 0.1), 0.48)
	leather.clearcoat_enabled = true
	leather.clearcoat = 0.4
	leather.clearcoat_roughness = 0.35
	var cap_l := mat(Color(0.22, 0.13, 0.07), 0.42)
	var fleece := mat(Color(0.9, 0.84, 0.72), 0.95)
	var skin := mat(Color(0.86, 0.63, 0.5), 0.6)
	var khaki := mat(Color(0.5, 0.45, 0.33), 0.8)
	var boot := mat(Color(0.12, 0.07, 0.05), 0.28)
	boot.clearcoat_enabled = true
	boot.clearcoat = 0.7
	var brass := mat(Color(0.88, 0.68, 0.32), 0.22, 1.0)
	var copper := mat(Color(0.78, 0.42, 0.26), 0.28, 1.0)
	var steel := mat(Color(0.2, 0.2, 0.22), 0.35, 0.8)
	var amber := mat(Color(1.0, 0.65, 0.2), 0.05, 0.3, Color(1.0, 0.55, 0.2), 0.6)
	var silk := mat(Color(0.97, 0.95, 0.9), 0.55)
	# jacket, belt and collar
	part(body, capsule(0.2, 0.6), leather, Vector3(0, 0.02, 0), Vector3(1.12, 1.0, 0.82))
	part(body, box(0.44, 0.07, 0.34), mat(Color(0.08, 0.05, 0.03), 0.4), Vector3(0, -0.2, 0))
	part(body, box(0.08, 0.06, 0.04), brass, Vector3(0, -0.2, -0.17))
	var collar := TorusMesh.new()
	collar.inner_radius = 0.09; collar.outer_radius = 0.17; collar.rings = 16; collar.ring_segments = 10
	part(body, collar, fleece, Vector3(0, 0.29, 0.0))
	# head, cap with ear flaps and a strap, goggles pushed up on the forehead
	part(body, sphere(0.135, 18), skin, Vector3(0, 0.47, -0.02))
	part(body, sphere(0.148, 18), cap_l, Vector3(0, 0.5, 0.01), Vector3(1.0, 0.92, 1.05))
	for sx in [-1.0, 1.0]:
		part(body, box(0.04, 0.12, 0.09), cap_l, Vector3(sx * 0.14, 0.42, 0.0))
		part(body, cyl(0.05, 0.05, 0.04, 14), brass, Vector3(sx * 0.055, 0.56, -0.12), Vector3.ONE, Vector3(PI * 0.5 - 0.5, 0, 0))
		part(body, cyl(0.036, 0.036, 0.045, 14), amber, Vector3(sx * 0.055, 0.56, -0.125), Vector3.ONE, Vector3(PI * 0.5 - 0.5, 0, 0))
	var strap := TorusMesh.new()
	strap.inner_radius = 0.145; strap.outer_radius = 0.162; strap.rings = 24; strap.ring_segments = 4
	part(body, strap, mat(Color(0.1, 0.06, 0.04), 0.5), Vector3(0, 0.55, 0.0), Vector3.ONE, Vector3(-0.5, 0, 0))
	# arms reaching down to the pack's grips, in gloves
	for sx in [-1.0, 1.0]:
		part(body, capsule(0.07, 0.34), leather, Vector3(sx * 0.25, 0.12, -0.02), Vector3.ONE, Vector3(0.5, 0, sx * 0.35))
		part(body, capsule(0.06, 0.3), leather, Vector3(sx * 0.3, -0.08, -0.12), Vector3.ONE, Vector3(1.1, 0, sx * 0.1))
		part(body, sphere(0.065), mat(Color(0.15, 0.09, 0.05), 0.5), Vector3(sx * 0.3, -0.18, -0.24))
		part(body, cyl(0.025, 0.025, 0.16, 8), steel, Vector3(sx * 0.3, -0.2, -0.22), Vector3.ONE, Vector3(0, 0, PI * 0.5))
	# legs trailing back a little, in breeches and tall boots
	for sx in [-1.0, 1.0]:
		part(body, capsule(0.085, 0.36), khaki, Vector3(sx * 0.1, -0.38, 0.06), Vector3.ONE, Vector3(0.55, 0, 0))
		part(body, capsule(0.075, 0.38), boot, Vector3(sx * 0.1, -0.62, 0.26), Vector3.ONE, Vector3(0.85, 0, 0))
	# the jetpack: a copper back plate, two brass tanks with copper bands and domed tops, a gauge between them, nozzles
	part(body, box(0.36, 0.5, 0.06), copper, Vector3(0, 0.04, 0.18))
	var flames := []
	var flame_mat := ShaderMaterial.new()
	flame_mat.shader = load("res://shaders/ring.gdshader")
	for sx in [-1.0, 1.0]:
		var tx: float = sx * 0.115
		part(body, capsule(0.09, 0.54), brass, Vector3(tx, 0.04, 0.27))
		for by in [-0.12, 0.18]:
			part(body, cyl(0.094, 0.094, 0.035, 18), copper, Vector3(tx, by, 0.27))
		part(body, cyl(0.06, 0.085, 0.09, 14), steel, Vector3(tx, -0.27, 0.27))
		part(body, box(0.02, 0.16, 0.12), copper, Vector3(tx + sx * 0.09, -0.12, 0.31))
		var fl := part(body, cyl(0.065, 0.0, 0.6, 12), flame_mat, Vector3(tx, -0.6, 0.27))
		fl.set_instance_shader_parameter("tint", Color(1.0, 0.58, 0.24, 1.0))
		fl.set_instance_shader_parameter("glow", 1.8)
		fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flames.append(fl)
		add_glow_sprite(body, Vector3(tx, -0.42, 0.27), 0.75, Color(1.0, 0.6, 0.3), 0.9)
	part(body, cyl(0.045, 0.045, 0.03, 16), brass, Vector3(0, 0.22, 0.34), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
	part(body, cyl(0.035, 0.035, 0.032, 16), glow(Color(1.0, 0.85, 0.55), 1.6), Vector3(0, 0.22, 0.345), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
	# the scarf: a chain of silk pieces from the collar, streaming back
	var scarf := []
	var anchor := Node3D.new()
	anchor.position = Vector3(0.06, 0.3, 0.12)
	body.add_child(anchor)
	var prev := anchor
	for k in 6:
		var seg := Node3D.new()
		seg.position = Vector3(0, 0, 0.0 if k == 0 else 0.11)
		prev.add_child(seg)
		part(seg, box(0.09 - k * 0.006, 0.012, 0.12), silk, Vector3(0, 0, 0.055))
		scarf.append(seg)
		prev = seg
	var under := OmniLight3D.new()
	under.light_color = Color(1.0, 0.62, 0.32)
	under.light_energy = 1.4
	under.omni_range = 3.6
	under.position = Vector3(0, -0.9, 0.2)
	rig.add_child(under)
	root.set_meta("rig", rig)
	root.set_meta("flames", flames)
	root.set_meta("scarf", scarf)
	return root

## the pilot's head in the car's glass bubble: the same leather cap and brass goggles
static func pilot_head(parent: Node3D, pos: Vector3) -> void:
	part(parent, sphere(0.11, 16), mat(Color(0.86, 0.63, 0.5), 0.6), pos)
	part(parent, sphere(0.12, 16), mat(Color(0.22, 0.13, 0.07), 0.42), pos + Vector3(0, 0.025, 0.01), Vector3(1.0, 0.9, 1.05))
	for sx in [-1.0, 1.0]:
		part(parent, cyl(0.04, 0.04, 0.03, 12), mat(Color(0.88, 0.68, 0.32), 0.22, 1.0), pos + Vector3(sx * 0.045, 0.07, -0.09), Vector3.ONE, Vector3(PI * 0.5 - 0.5, 0, 0))
	part(parent, box(0.06, 0.012, 0.16), mat(Color(0.97, 0.95, 0.9), 0.55), pos + Vector3(0.04, -0.1, 0.12))

# ---------------------------------------------------------------- traffic

static func oldcar(col: Color) -> Node3D:
	var root := Node3D.new()
	var p := paint(col)
	var black := mat(Color(0.03, 0.03, 0.03), 0.6)
	var brass := mat(Color(0.85, 0.66, 0.3), 0.2, 1.0)
	part(root, box(1.25, 0.5, 2.1), p, Vector3(0, 0.75, 0))
	part(root, box(1.15, 0.55, 1.05), p, Vector3(0, 1.27, 0.3))
	part(root, box(1.17, 0.36, 0.95), mat(Color(0.15, 0.17, 0.2), 0.05, 0.5), Vector3(0, 1.3, 0.3))
	part(root, box(0.8, 0.45, 0.08), brass, Vector3(0, 0.8, -1.07))
	for sx in [-1.0, 1.0]:
		for sz in [-0.72, 0.72]:
			part(root, cyl(0.33, 0.33, 0.2), black, Vector3(sx * 0.62, 0.34, sz), Vector3.ONE, Vector3(0, 0, PI * 0.5))
		part(root, capsule(0.18, 0.95), p, Vector3(sx * 0.64, 0.55, -0.6), Vector3(1, 1, 1), Vector3(PI * 0.5, 0, 0))
		part(root, sphere(0.09), glow(Color(1, 0.85, 0.6), 3.0), Vector3(sx * 0.45, 0.92, -1.1))
		part(root, sphere(0.06), glow(Color(1, 0.15, 0.1), 2.5), Vector3(sx * 0.5, 0.75, 1.07))
	return root

static func dbus() -> Node3D:
	var root := Node3D.new()
	var red := paint(Color(0.62, 0.08, 0.06))
	var cream := mat(Color(0.86, 0.8, 0.66), 0.5)
	var win := mat(Color(0.95, 0.78, 0.5), 0.2, 0.0, Color(1.0, 0.72, 0.38), 1.6)
	var black := mat(Color(0.03, 0.03, 0.03), 0.6)
	part(root, box(1.45, 1.0, 3.6), red, Vector3(0, 0.95, 0))
	part(root, box(1.45, 0.85, 3.4), red, Vector3(0, 1.95, 0.05))
	part(root, box(1.47, 0.12, 3.62), cream, Vector3(0, 1.5, 0))
	part(root, box(1.48, 0.35, 3.3), win, Vector3(0, 1.1, 0.05))
	part(root, box(1.48, 0.32, 3.1), win, Vector3(0, 2.05, 0.05))
	part(root, box(1.3, 0.06, 3.3), cream, Vector3(0, 2.4, 0.05))
	for sx in [-1.0, 1.0]:
		for sz in [-1.2, 1.2]:
			part(root, cyl(0.36, 0.36, 0.22), black, Vector3(sx * 0.66, 0.36, sz), Vector3.ONE, Vector3(0, 0, PI * 0.5))
		part(root, sphere(0.06), glow(Color(1, 0.15, 0.1), 2.5), Vector3(sx * 0.55, 0.7, 1.81))
	return root

static func biplane(col: Color) -> Node3D:
	var root := Node3D.new()
	var p := paint(col)
	var wing := paint(col.lightened(0.25))
	var canvas := mat(Color(0.9, 0.86, 0.72), 0.6)
	var wood := mat(Color(0.35, 0.22, 0.12), 0.6)
	var metal := mat(Color(0.75, 0.75, 0.78), 0.25, 1.0)
	# fuselage, cowling and the pilot in his open cockpit
	part(root, capsule(0.24, 2.2), p, Vector3(0, 0, 0.05), Vector3(1, 1, 1), Vector3(PI * 0.5, 0, 0))
	part(root, cyl(0.26, 0.26, 0.3), metal, Vector3(0, 0, -0.95), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
	part(root, sphere(0.12), mat(Color(0.3, 0.2, 0.12), 0.7), Vector3(0, 0.27, 0.15))
	# two wings with white tips and roundels, struts between them
	for wy in [0.4, -0.2]:
		part(root, box(2.7, 0.05, 0.6), wing, Vector3(0, wy, -0.25))
		for sx in [-1.0, 1.0]:
			part(root, box(0.3, 0.055, 0.61), canvas, Vector3(sx * 1.22, wy, -0.25))
			part(root, cyl(0.15, 0.15, 0.06, 16), mat(Color(0.12, 0.2, 0.5), 0.5), Vector3(sx * 0.85, wy + 0.03, -0.25))
			part(root, cyl(0.07, 0.07, 0.07, 12), mat(Color(0.8, 0.1, 0.1), 0.5), Vector3(sx * 0.85, wy + 0.035, -0.25))
	for sx in [-0.95, 0.95]:
		part(root, cyl(0.02, 0.02, 0.6, 6), wood, Vector3(sx, 0.1, -0.25))
	# tailplane, fin with stripes, and a lamp on the tail so you can see it in the rain
	part(root, box(1.0, 0.04, 0.32), wing, Vector3(0, 0.04, 1.12))
	part(root, box(0.04, 0.45, 0.36), canvas, Vector3(0, 0.26, 1.12))
	part(root, box(0.05, 0.14, 0.37), p, Vector3(0, 0.3, 1.12))
	part(root, sphere(0.05), glow(Color(1.0, 0.3, 0.15), 3.0), Vector3(0, 0.5, 1.22))
	add_glow_sprite(root, Vector3(0, 0.5, 1.22), 0.6, Color(1.0, 0.35, 0.2), 0.8)
	# undercarriage
	for sx in [-0.3, 0.3]:
		part(root, cyl(0.02, 0.02, 0.45, 6), wood, Vector3(sx, -0.42, -0.45), Vector3.ONE, Vector3(0, 0, sx * 0.6))
		part(root, cyl(0.13, 0.13, 0.06, 14), mat(Color(0.05, 0.05, 0.05), 0.6), Vector3(sx * 1.4, -0.62, -0.45), Vector3.ONE, Vector3(0, 0, PI * 0.5))
	var prop := Node3D.new()
	prop.position = Vector3(0, 0, -1.12)
	root.add_child(prop)
	part(prop, box(0.08, 1.0, 0.03), wood, Vector3.ZERO)
	var disc_m := StandardMaterial3D.new()
	disc_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc_m.albedo_color = Color(0.8, 0.8, 0.8, 0.12)
	disc_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	part(prop, cyl(0.5, 0.5, 0.01, 20), disc_m, Vector3.ZERO, Vector3.ONE, Vector3(PI * 0.5, 0, 0))
	root.set_meta("prop", prop)
	return root

## a small Victorian airship: a striped envelope, a wooden gondola with a lamp, and a pusher propeller at the back
static func airship(col: Color) -> Node3D:
	var root := Node3D.new()
	var env := paint(col)
	env.clearcoat = 0.3
	var band := mat(Color(0.9, 0.86, 0.74), 0.5)
	var wood := mat(Color(0.4, 0.25, 0.14), 0.6)
	var brass := mat(Color(0.85, 0.66, 0.3), 0.2, 1.0)
	part(root, capsule(0.42, 2.5), env, Vector3(0, 0.25, 0), Vector3(1, 0.9, 1), Vector3(PI * 0.5, 0, 0))
	for z in [-0.6, 0.0, 0.6]:
		part(root, cyl(0.39, 0.39, 0.08, 24), band, Vector3(0, 0.25, z), Vector3(1.08, 1.0, 0.97), Vector3(PI * 0.5, 0, 0))
	# tail fins in a cross
	for r in [0.0, PI * 0.5]:
		part(root, box(0.9, 0.04, 0.4), env, Vector3(0, 0.25, 1.15), Vector3.ONE, Vector3(0, 0, r))
	part(root, box(0.36, 0.26, 0.9), wood, Vector3(0, -0.42, 0.05))
	part(root, box(0.4, 0.05, 0.95), brass, Vector3(0, -0.28, 0.05))
	for sx in [-0.14, 0.14]:
		part(root, cyl(0.01, 0.01, 0.5, 4), brass, Vector3(sx, -0.1, -0.25))
		part(root, cyl(0.01, 0.01, 0.5, 4), brass, Vector3(sx, -0.1, 0.35))
	part(root, sphere(0.06), glow(Color(1.0, 0.75, 0.4), 3.0), Vector3(0, -0.5, 0.52))
	add_glow_sprite(root, Vector3(0, -0.5, 0.55), 0.9, Color(1.0, 0.7, 0.35), 0.9)
	part(root, sphere(0.05), glow(Color(1.0, 0.25, 0.15), 3.0), Vector3(0, 0.25, 1.36))
	var prop := Node3D.new()
	prop.position = Vector3(0, -0.42, 0.6)
	root.add_child(prop)
	part(prop, box(0.04, 0.55, 0.02), wood, Vector3.ZERO)
	root.set_meta("prop", prop)
	return root

## a roadworks barrier across the lane at skyway height: two posts from the road, a striped beam and red lamps
static func barrier() -> Node3D:
	var root := Node3D.new()
	var white := mat(Color(0.9, 0.88, 0.82), 0.5)
	var red := mat(Color(0.7, 0.1, 0.08), 0.5)
	var wood := mat(Color(0.32, 0.22, 0.14), 0.7)
	var post := -World.ROAD_Y + 0.3
	for sx in [-0.72, 0.72]:
		part(root, box(0.12, post, 0.12), wood, Vector3(sx, 0.3 - post * 0.5, 0))
	for i in 6:
		part(root, box(0.25, 0.32, 0.14), white if i % 2 == 0 else red, Vector3(-0.625 + i * 0.25, 0.1, 0))
	for sx in [-0.6, 0.6]:
		part(root, sphere(0.07), glow(Color(1, 0.2, 0.1), 3.5), Vector3(sx, 0.36, 0))
		add_glow_sprite(root, Vector3(sx, 0.36, 0), 0.7, Color(1, 0.25, 0.12), 0.8)
	return root

## the finish: an iron arch across the street with lanterns, and a banner
static func finish_arch() -> Node3D:
	var root := Node3D.new()
	var iron := mat(Color(0.06, 0.08, 0.07), 0.35, 0.7)
	var gold := mat(Color(0.95, 0.75, 0.32), 0.25, 1.0)
	for sx in [-5.0, 5.0]:
		part(root, box(0.35, 8.0, 0.35), iron, Vector3(sx, 1.7, 0))
		part(root, sphere(0.22), glow(Color(1, 0.75, 0.42), 3.0), Vector3(sx, 5.9, 0))
		add_glow_sprite(root, Vector3(sx, 5.9, 0), 2.2, Color(1, 0.7, 0.38), 1.0)
	part(root, box(10.4, 0.3, 0.3), iron, Vector3(0, 5.6, 0))
	part(root, box(6.0, 0.9, 0.08), gold, Vector3(0, 4.9, 0))
	var label := Label3D.new()
	label.text = "FINISH"
	label.font_size = 96
	label.pixel_size = 0.006
	label.modulate = Color(0.12, 0.08, 0.04)
	label.position = Vector3(0, 4.9, 0.06)
	label.rotation = Vector3(0, PI, 0)
	label.outline_size = 0
	root.add_child(label)
	var label2 := label.duplicate()
	label2.position = Vector3(0, 4.9, -0.06)
	label2.rotation = Vector3.ZERO
	root.add_child(label2)
	return root
