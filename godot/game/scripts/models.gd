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

# ---------------------------------------------------------------- the player's cars

## the garage: name, price, a line about it, and its perk (the rules read the perk; Game applies it)
const CARS := {
	"roadster": {"name": "Roadster", "price": 0, "about": "Cream-and-chrome flyer with a glass bubble", "perk": "", "say": "No perk · the all-rounder"},
	"bubble": {"name": "Bubble", "price": 250, "about": "City pod · glass dome and a ring thruster", "perk": "rescue", "say": "Perk: the rescue meter fills 30% faster"},
	"starliner": {"name": "Starliner", "price": 600, "about": "Fifties cruiser · tail fins and twin rockets", "perk": "reach", "say": "Perk: rings are easier to reach"},
	"spinner": {"name": "Spinner", "price": 1200, "about": "Police flyer · four turbo fans and a light bar", "perk": "shield", "say": "Perk: every run starts with a shield"},
	"manta": {"name": "Manta", "price": 2000, "about": "Flying wing · low, wide and fast", "perk": "coins", "say": "Perk: +25% coins from every run"},
}

## a car by its key, with the chosen pilot's head in the cockpit. Its pods, flames and lights are kept in meta
static func car(kind := "roadster", pilot_kind := "aviator") -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	var pods := []
	var flames := []
	match kind:
		"bubble":
			_bubble(body, pods, flames, pilot_kind)
		"starliner":
			_starliner(body, pods, flames, pilot_kind)
		"spinner":
			_spinner(body, pods, flames, pilot_kind)
		"manta":
			_manta(body, pods, flames, pilot_kind)
		_:
			_roadster(body, pods, flames, pilot_kind)
	# the headlamp beam that lights the road ahead, and the glow the car throws on the road below it
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

static func _glass() -> StandardMaterial3D:
	var g := mat(Color(0.18, 0.22, 0.28), 0.04, 0.6)
	g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	g.albedo_color.a = 0.55
	return g

## a thruster facing back: a nozzle with a glowing core, a flame and a halo
static func _thruster(parent: Node3D, pos: Vector3, r: float, shell: Material, col: Color, pods: Array, flames: Array, length := 0.42) -> void:
	var pod := Node3D.new()
	pod.position = pos
	parent.add_child(pod)
	part(pod, cyl(r, r * 0.87, length), shell, Vector3.ZERO, Vector3.ONE, Vector3(PI * 0.5, 0, 0))
	part(pod, cyl(r * 0.73, r * 0.73, 0.02), glow(col.lightened(0.3), 3.5), Vector3(0, 0, length * 0.5 + 0.005), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
	var fm := ShaderMaterial.new()
	fm.shader = load("res://shaders/ring.gdshader")
	var fl := part(pod, cyl(r * 0.67, 0.0, 0.6, 12), fm, Vector3(0, 0, length * 0.5 + 0.31), Vector3.ONE, Vector3(-PI * 0.5, 0, 0))
	fl.set_instance_shader_parameter("tint", Color(col.r, col.g, col.b, 1.0))
	fl.set_instance_shader_parameter("glow", 1.6)
	fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flames.append(fl)
	add_glow_sprite(pod, Vector3(0, 0, length * 0.5 + 0.1), r * 6.0, col, 0.9)
	pods.append(pod)

static func _lamps(body: Node3D, front: Array, back: Array) -> void:
	for p in front:
		part(body, sphere(0.07), glow(Color(1.0, 0.92, 0.75), 4.0), p)
	for p in back:
		part(body, capsule(0.04, 0.18), glow(Color(1.0, 0.12, 0.08), 3.0), p, Vector3.ONE, Vector3(0, 0, PI * 0.5))

## the Roadster: a long cream body with a maroon skirt, teardrop fenders, a glass bubble, two pods
static func _roadster(body: Node3D, pods: Array, flames: Array, pk: String) -> void:
	var cream := paint(Color(0.9, 0.84, 0.72))
	var maroon := paint(Color(0.38, 0.07, 0.09))
	var chrome := mat(Color(0.92, 0.92, 0.95), 0.1, 1.0)
	part(body, capsule(0.34, 2.15), cream, Vector3(0, 0.0, 0), Vector3(1.62, 0.78, 1.0), Vector3(PI * 0.5, 0, 0))
	part(body, capsule(0.3, 2.0), maroon, Vector3(0, -0.12, 0.02), Vector3(1.78, 0.55, 1.0), Vector3(PI * 0.5, 0, 0))
	part(body, box(1.16, 0.035, 1.9), chrome, Vector3(0, 0.03, 0.02))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			part(body, sphere(0.26), cream, Vector3(sx * 0.5, -0.1, sz * 0.62), Vector3(0.75, 0.62, 1.55))
	part(body, sphere(0.36, 24), _glass(), Vector3(0, 0.26, 0.12), Vector3(1.05, 0.72, 1.45))
	head(body, pk, Vector3(0, 0.3, 0.2), 0.8)
	part(body, box(0.5, 0.16, 0.06), chrome, Vector3(0, -0.04, -1.08))
	part(body, capsule(0.035, 1.1), chrome, Vector3(0, -0.2, -1.1), Vector3.ONE, Vector3(0, 0, PI * 0.5))
	part(body, capsule(0.035, 1.1), chrome, Vector3(0, -0.2, 1.1), Vector3.ONE, Vector3(0, 0, PI * 0.5))
	for sx in [-1.0, 1.0]:
		part(body, box(0.02, 0.025, 1.4), glow(Color(1.0, 0.76, 0.42), 1.6), Vector3(sx * 0.555, 0.0, 0.0))
		for sz in [-1.0, 1.0]:
			part(body, cyl(0.12, 0.12, 0.03), glow(Color(1.0, 0.8, 0.5), 2.5), Vector3(sx * 0.48, -0.26, sz * 0.6))
	_lamps(body, [Vector3(-0.34, -0.02, -1.08), Vector3(0.34, -0.02, -1.08)], [Vector3(-0.42, 0.02, 1.06), Vector3(0.42, 0.02, 1.06)])
	for sx in [-1.0, 1.0]:
		_thruster(body, Vector3(sx * 0.38, -0.12, 0.95), 0.15, chrome, Color(1.0, 0.58, 0.28), pods, flames)

## the Bubble: a round mint pod with a big glass dome, a glowing ring thruster around its waist and one pod at the back
static func _bubble(body: Node3D, pods: Array, flames: Array, pk: String) -> void:
	var mint := paint(Color(0.55, 0.86, 0.78))
	var white := paint(Color(0.95, 0.95, 0.93))
	var chrome := mat(Color(0.92, 0.92, 0.95), 0.1, 1.0)
	part(body, sphere(0.5, 32), mint, Vector3(0, 0.0, 0.02), Vector3(1.3, 0.72, 2.3))
	part(body, sphere(0.5, 28), white, Vector3(0, -0.1, 0.02), Vector3(1.34, 0.45, 2.34))
	var dome := SphereMesh.new()
	dome.radius = 0.5; dome.height = 1.0; dome.is_hemisphere = true; dome.radial_segments = 28; dome.rings = 12
	part(body, dome, _glass(), Vector3(0, 0.12, -0.08), Vector3(0.9, 0.8, 1.25))
	head(body, pk, Vector3(0, 0.24, 0.0), 0.75)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.47; ring.outer_radius = 0.53; ring.rings = 48; ring.ring_segments = 10
	part(body, ring, glow(Color(0.45, 0.95, 1.0), 2.4), Vector3(0, -0.04, 0.02), Vector3(1.34, 1.0, 2.36))
	for sx in [-1.0, 1.0]:
		part(body, box(0.04, 0.2, 0.28), mint, Vector3(sx * 0.22, 0.22, 0.5), Vector3.ONE, Vector3(0, 0, -sx * 0.4))
	_lamps(body, [Vector3(-0.22, 0.02, -1.08), Vector3(0.22, 0.02, -1.08)], [Vector3(-0.28, 0.05, 1.08), Vector3(0.28, 0.05, 1.08)])
	_thruster(body, Vector3(0, -0.04, 1.18), 0.17, chrome, Color(0.45, 0.9, 1.0), pods, flames, 0.3)

## the Starliner: a long two-tone fifties cruiser with tall tail fins, chrome everywhere and twin rockets
static func _starliner(body: Node3D, pods: Array, flames: Array, pk: String) -> void:
	var teal := paint(Color(0.24, 0.66, 0.68))
	var white := paint(Color(0.96, 0.94, 0.9))
	var chrome := mat(Color(0.94, 0.94, 0.96), 0.08, 1.0)
	part(body, box(1.2, 0.3, 2.3), teal, Vector3(0, -0.06, 0))
	part(body, box(1.22, 0.06, 2.34), chrome, Vector3(0, 0.1, 0))
	part(body, box(1.16, 0.18, 2.2), white, Vector3(0, 0.18, 0.02))
	part(body, sphere(0.36, 24), _glass(), Vector3(0, 0.36, 0.0), Vector3(1.4, 0.6, 1.8))
	head(body, pk, Vector3(0, 0.38, 0.1), 0.8)
	for sx in [-1.0, 1.0]:
		# the fins rise toward the back and carry the tail lamps
		part(body, box(0.05, 0.42, 0.7), teal, Vector3(sx * 0.56, 0.3, 0.86), Vector3.ONE, Vector3(-0.5, 0, sx * 0.12))
		part(body, capsule(0.05, 0.3), glow(Color(1.0, 0.15, 0.1), 3.0), Vector3(sx * 0.58, 0.3, 1.15), Vector3.ONE, Vector3(-0.4, 0, 0))
		part(body, capsule(0.08, 2.2), chrome, Vector3(sx * 0.6, -0.18, 0), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
	part(body, box(0.9, 0.12, 0.08), chrome, Vector3(0, -0.06, -1.16))
	_lamps(body, [Vector3(-0.45, 0.02, -1.15), Vector3(0.45, 0.02, -1.15)], [])
	for sx in [-1.0, 1.0]:
		_thruster(body, Vector3(sx * 0.3, -0.08, 1.2), 0.13, chrome, Color(1.0, 0.45, 0.3), pods, flames, 0.36)

## the Spinner: a navy-and-white police flyer, four ducted fans spinning at the corners, a flashing light bar
static func _spinner(body: Node3D, pods: Array, flames: Array, pk: String) -> void:
	var navy := paint(Color(0.1, 0.16, 0.32))
	var white := paint(Color(0.95, 0.95, 0.95))
	var dark := mat(Color(0.06, 0.06, 0.07), 0.4, 0.4)
	part(body, box(0.95, 0.34, 1.9), navy, Vector3(0, -0.02, 0))
	part(body, box(0.97, 0.12, 1.2), white, Vector3(0, -0.02, 0.1))
	part(body, box(0.8, 0.28, 0.9), _glass(), Vector3(0, 0.26, -0.05))
	head(body, pk, Vector3(0, 0.26, 0.05), 0.8)
	part(body, box(0.5, 0.08, 0.14), glow(Color(1.0, 0.15, 0.15), 3.0), Vector3(-0.15, 0.45, 0.2))
	part(body, box(0.5, 0.08, 0.14), glow(Color(0.2, 0.4, 1.0), 3.0), Vector3(0.15, 0.45, 0.2))
	var duct := TorusMesh.new()
	duct.inner_radius = 0.24; duct.outer_radius = 0.32; duct.rings = 28; duct.ring_segments = 8
	var fans := []
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var c := Vector3(sx * 0.72, -0.05, sz * 0.62)
			part(body, duct, white, c)
			part(body, box(0.3, 0.06, 0.08), navy, c - Vector3(sx * 0.2, 0, 0))
			var fan := Node3D.new()
			fan.position = c
			body.add_child(fan)
			part(fan, box(0.46, 0.02, 0.06), dark, Vector3.ZERO)
			part(fan, box(0.06, 0.02, 0.46), dark, Vector3.ZERO)
			part(fan, cyl(0.24, 0.24, 0.01, 20), glow(Color(0.4, 0.75, 1.0), 1.2), Vector3(0, -0.05, 0))
			fans.append(fan)
	body.set_meta("fans", fans)
	_lamps(body, [Vector3(-0.3, 0.0, -0.96), Vector3(0.3, 0.0, -0.96)], [Vector3(-0.3, 0.05, 0.96), Vector3(0.3, 0.05, 0.96)])
	for sx in [-1.0, 1.0]:
		_thruster(body, Vector3(sx * 0.22, -0.04, 1.0), 0.1, dark, Color(0.4, 0.7, 1.0), pods, flames, 0.25)

## the Manta: a wide violet flying wing with gold edges that glow, the cockpit a bubble at its centre
static func _manta(body: Node3D, pods: Array, flames: Array, pk: String) -> void:
	var violet := paint(Color(0.3, 0.12, 0.42))
	var gold := mat(Color(0.95, 0.75, 0.32), 0.2, 1.0)
	# the wing: a flattened diamond, swept back
	var wing := MeshInstance3D.new()
	wing.mesh = box(1.0, 0.1, 1.0)
	wing.material_override = violet
	wing.basis = Basis(Vector3.UP, PI * 0.25).scaled_local(Vector3(1.5, 1.0, 1.5))
	wing.position = Vector3(0, -0.05, 0.2)
	body.add_child(wing)
	part(body, capsule(0.28, 1.9), violet, Vector3(0, 0.0, 0.0), Vector3(1.2, 0.7, 1.0), Vector3(PI * 0.5, 0, 0))
	part(body, sphere(0.3, 24), _glass(), Vector3(0, 0.18, -0.15), Vector3(1.0, 0.65, 1.5))
	head(body, pk, Vector3(0, 0.22, -0.08), 0.8)
	for sx in [-1.0, 1.0]:
		# the glowing leading edges
		part(body, box(0.03, 0.03, 1.5), glow(Color(1.0, 0.75, 0.35), 2.2), Vector3(sx * 0.53, -0.02, -0.33), Vector3.ONE, Vector3(0, sx * PI * 0.25, 0))
		part(body, box(0.06, 0.3, 0.3), gold, Vector3(sx * 1.0, 0.08, 0.82), Vector3.ONE, Vector3(-0.3, 0, 0))
	_lamps(body, [Vector3(0, -0.02, -1.05)], [Vector3(-0.6, 0.0, 0.95), Vector3(0.6, 0.0, 0.95)])
	for sx in [-1.0, 1.0]:
		_thruster(body, Vector3(sx * 0.3, -0.02, 0.95), 0.12, gold, Color(1.0, 0.55, 0.85), pods, flames, 0.3)

# ---------------------------------------------------------------- the pilots

const PILOTS := {
	"aviator": {"name": "Aviator", "price": 0, "about": "1920s daredevil · leather, goggles and a silk scarf"},
	"racer": {"name": "Racer", "price": 300, "about": "Grand prix driver · white helmet, red overalls"},
	"automaton": {"name": "Automaton", "price": 600, "about": "Clockwork brass robot with glowing eyes"},
	"fox": {"name": "Fox", "price": 900, "about": "A fox in a flying jacket, goggles on"},
	"diver": {"name": "Diver", "price": 1200, "about": "Deep-sea diver · brass helmet and portholes"},
	"mech": {"name": "Mech", "price": 2000, "about": "Armoured mech suit with a glowing visor"},
}

## a pilot's head (in the cockpit, or on the pilot), scaled by s
static func head(parent: Node3D, kind: String, pos: Vector3, s := 1.0) -> void:
	var brass := mat(Color(0.88, 0.68, 0.32), 0.22, 1.0)
	var skin := mat(Color(0.86, 0.63, 0.5), 0.6)
	match kind:
		"racer":
			part(parent, sphere(0.15 * s, 18), paint(Color(0.96, 0.96, 0.96)), pos)
			# a blue racing stripe over the crown, front to back
			part(parent, sphere(0.153 * s, 18), paint(Color(0.1, 0.3, 0.8)), pos, Vector3(0.28, 1.0, 1.0))
			part(parent, sphere(0.11 * s, 16), mat(Color(0.05, 0.05, 0.08), 0.05, 0.5), pos + Vector3(0, 0.0, -0.07 * s), Vector3(1.2, 0.55, 0.7))
		"automaton":
			part(parent, cyl(0.12 * s, 0.13 * s, 0.24 * s, 16), brass, pos)
			part(parent, sphere(0.12 * s, 16), brass, pos + Vector3(0, 0.12 * s, 0), Vector3(1, 0.5, 1))
			for sx in [-1.0, 1.0]:
				part(parent, sphere(0.03 * s), glow(Color(0.4, 0.95, 1.0), 3.0), pos + Vector3(sx * 0.05 * s, 0.02 * s, -0.12 * s))
			part(parent, cyl(0.012 * s, 0.012 * s, 0.14 * s, 6), brass, pos + Vector3(0, 0.25 * s, 0))
			part(parent, sphere(0.025 * s), glow(Color(1.0, 0.4, 0.2), 3.0), pos + Vector3(0, 0.33 * s, 0))
		"fox":
			var fur := mat(Color(0.86, 0.42, 0.14), 0.8)
			part(parent, sphere(0.13 * s, 18), fur, pos)
			part(parent, cyl(0.0, 0.07 * s, 0.15 * s, 10), fur, pos + Vector3(0, -0.02 * s, -0.14 * s), Vector3.ONE, Vector3(-PI * 0.5, 0, 0))
			part(parent, sphere(0.022 * s), mat(Color(0.05, 0.04, 0.04), 0.3), pos + Vector3(0, -0.02 * s, -0.22 * s))
			part(parent, sphere(0.08 * s), mat(Color(0.95, 0.92, 0.86), 0.8), pos + Vector3(0, -0.06 * s, -0.06 * s), Vector3(1.3, 0.8, 1.0))
			for sx in [-1.0, 1.0]:
				part(parent, cyl(0.0, 0.05 * s, 0.12 * s, 6), fur, pos + Vector3(sx * 0.08 * s, 0.14 * s, 0), Vector3.ONE, Vector3(0, 0, -sx * 0.3))
				part(parent, cyl(0.035 * s, 0.035 * s, 0.03 * s, 12), brass, pos + Vector3(sx * 0.05 * s, 0.07 * s, -0.11 * s), Vector3.ONE, Vector3(PI * 0.5 - 0.5, 0, 0))
		"diver":
			part(parent, sphere(0.17 * s, 22), brass, pos)
			part(parent, cyl(0.15 * s, 0.17 * s, 0.06 * s, 18), brass, pos + Vector3(0, -0.15 * s, 0))
			for d in [Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(1, 0, 0)]:
				var p: Vector3 = pos + d * 0.155 * s
				var b := Basis.looking_at(d, Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
				var rim := MeshInstance3D.new()
				rim.mesh = cyl(0.065 * s, 0.065 * s, 0.03 * s, 16)
				rim.material_override = brass
				rim.position = p
				rim.basis = b
				parent.add_child(rim)
				var gl := MeshInstance3D.new()
				gl.mesh = cyl(0.05 * s, 0.05 * s, 0.035 * s, 16)
				gl.material_override = mat(Color(0.12, 0.3, 0.32), 0.05, 0.5, Color(0.3, 0.9, 0.85), 0.4)
				gl.position = p
				gl.basis = b
				parent.add_child(gl)
		"mech":
			part(parent, box(0.26 * s, 0.24 * s, 0.26 * s), paint(Color(0.22, 0.24, 0.27)), pos)
			part(parent, box(0.2 * s, 0.05 * s, 0.03 * s), glow(Color(1.0, 0.55, 0.15), 3.0), pos + Vector3(0, 0.02 * s, -0.13 * s))
			part(parent, box(0.28 * s, 0.05 * s, 0.2 * s), paint(Color(0.95, 0.55, 0.15)), pos + Vector3(0, 0.13 * s, 0.02 * s))
		_:
			# the aviator: a leather cap with ear flaps, brass goggles pushed up
			var cap := mat(Color(0.22, 0.13, 0.07), 0.42)
			part(parent, sphere(0.135 * s, 18), skin, pos)
			part(parent, sphere(0.148 * s, 18), cap, pos + Vector3(0, 0.03 * s, 0.03 * s), Vector3(1.0, 0.92, 1.05))
			for sx in [-1.0, 1.0]:
				part(parent, box(0.04 * s, 0.12 * s, 0.09 * s), cap, pos + Vector3(sx * 0.14 * s, -0.05 * s, 0.02 * s))
				part(parent, cyl(0.05 * s, 0.05 * s, 0.04 * s, 14), brass, pos + Vector3(sx * 0.055 * s, 0.09 * s, -0.1 * s), Vector3.ONE, Vector3(PI * 0.5 - 0.5, 0, 0))
				part(parent, cyl(0.036 * s, 0.036 * s, 0.045 * s, 14), mat(Color(1.0, 0.65, 0.2), 0.05, 0.3, Color(1.0, 0.55, 0.2), 0.6), pos + Vector3(sx * 0.055 * s, 0.09 * s, -0.105 * s), Vector3.ONE, Vector3(PI * 0.5 - 0.5, 0, 0))

## the pilot on a jetpack: every pilot has the same build and pose (leaning into the flight, hands on the pack's grips,
## the pack's flames below), in their own outfit and jetpack. The aviator's silk scarf streams in the wind
static func pilot(kind := "aviator") -> Node3D:
	var root := Node3D.new()
	var rig := Node3D.new()
	rig.name = "Rig"
	root.add_child(rig)
	var body := Node3D.new()
	body.rotation.x = -0.32
	rig.add_child(body)
	var brass := mat(Color(0.88, 0.68, 0.32), 0.22, 1.0)
	var copper := mat(Color(0.78, 0.42, 0.26), 0.28, 1.0)
	var steel := mat(Color(0.2, 0.2, 0.22), 0.35, 0.8)
	# the outfit: jacket, sleeves, legs, boots, the pack's plate and tanks
	var o: Array = {
		"aviator": [mat(Color(0.34, 0.19, 0.1), 0.48), mat(Color(0.5, 0.45, 0.33), 0.8), mat(Color(0.12, 0.07, 0.05), 0.28), copper, brass],
		"racer": [paint(Color(0.78, 0.1, 0.08)), paint(Color(0.78, 0.1, 0.08)), mat(Color(0.06, 0.06, 0.06), 0.3), paint(Color(0.95, 0.95, 0.95)), paint(Color(0.78, 0.1, 0.08))],
		"automaton": [brass, brass, copper, copper, brass],
		"fox": [mat(Color(0.2, 0.26, 0.18), 0.6), mat(Color(0.5, 0.45, 0.33), 0.8), mat(Color(0.12, 0.07, 0.05), 0.28), copper, brass],
		"diver": [mat(Color(0.72, 0.66, 0.52), 0.85), mat(Color(0.72, 0.66, 0.52), 0.85), mat(Color(0.1, 0.1, 0.1), 0.5), brass, copper],
		"mech": [paint(Color(0.22, 0.24, 0.27)), paint(Color(0.3, 0.32, 0.35)), paint(Color(0.95, 0.55, 0.15)), paint(Color(0.22, 0.24, 0.27)), paint(Color(0.95, 0.55, 0.15))],
	}.get(kind, [])
	if o.is_empty():
		kind = "aviator"
		return pilot("aviator")
	var jacket: Material = o[0]
	var legs: Material = o[1]
	var boots: Material = o[2]
	var plate: Material = o[3]
	var tank: Material = o[4]
	var bulk := 1.25 if kind == "mech" else 1.0
	part(body, capsule(0.2 * bulk, 0.6), jacket, Vector3(0, 0.02, 0), Vector3(1.12, 1.0, 0.82))
	part(body, box(0.44 * bulk, 0.07, 0.34), mat(Color(0.08, 0.05, 0.03), 0.4), Vector3(0, -0.2, 0))
	if kind == "aviator" or kind == "fox":
		var collar := TorusMesh.new()
		collar.inner_radius = 0.09; collar.outer_radius = 0.17; collar.rings = 16; collar.ring_segments = 10
		part(body, collar, mat(Color(0.9, 0.84, 0.72), 0.95), Vector3(0, 0.29, 0.0))
	head(body, kind, Vector3(0, 0.47, -0.02), 1.0)
	for sx in [-1.0, 1.0]:
		part(body, capsule(0.07 * bulk, 0.34), jacket, Vector3(sx * 0.25 * bulk, 0.12, -0.02), Vector3.ONE, Vector3(0.5, 0, sx * 0.35))
		part(body, capsule(0.06 * bulk, 0.3), jacket, Vector3(sx * 0.3 * bulk, -0.08, -0.12), Vector3.ONE, Vector3(1.1, 0, sx * 0.1))
		part(body, sphere(0.065 * bulk), boots, Vector3(sx * 0.3 * bulk, -0.18, -0.24))
		part(body, cyl(0.025, 0.025, 0.16, 8), steel, Vector3(sx * 0.3 * bulk, -0.2, -0.22), Vector3.ONE, Vector3(0, 0, PI * 0.5))
		part(body, capsule(0.085 * bulk, 0.36), legs, Vector3(sx * 0.1 * bulk, -0.38, 0.06), Vector3.ONE, Vector3(0.55, 0, 0))
		part(body, capsule(0.075 * bulk, 0.38), boots, Vector3(sx * 0.1 * bulk, -0.62, 0.26), Vector3.ONE, Vector3(0.85, 0, 0))
	# the jetpack
	part(body, box(0.36 * bulk, 0.5, 0.06), plate, Vector3(0, 0.04, 0.18))
	var flames := []
	var flame_mat := ShaderMaterial.new()
	flame_mat.shader = load("res://shaders/ring.gdshader")
	var fcol := Color(0.45, 0.8, 1.0) if kind == "mech" or kind == "automaton" else Color(1.0, 0.58, 0.24)
	for sx in [-1.0, 1.0]:
		var tx: float = sx * 0.115 * bulk
		part(body, capsule(0.09, 0.54), tank, Vector3(tx, 0.04, 0.27))
		for by in [-0.12, 0.18]:
			part(body, cyl(0.094, 0.094, 0.035, 18), plate, Vector3(tx, by, 0.27))
		part(body, cyl(0.06, 0.085, 0.09, 14), steel, Vector3(tx, -0.27, 0.27))
		part(body, box(0.02, 0.16, 0.12), plate, Vector3(tx + sx * 0.09, -0.12, 0.31))
		var fl := part(body, cyl(0.065, 0.0, 0.6, 12), flame_mat, Vector3(tx, -0.6, 0.27))
		fl.set_instance_shader_parameter("tint", Color(fcol.r, fcol.g, fcol.b, 1.0))
		fl.set_instance_shader_parameter("glow", 1.8)
		fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flames.append(fl)
		add_glow_sprite(body, Vector3(tx, -0.42, 0.27), 0.75, fcol, 0.9)
	part(body, cyl(0.045, 0.045, 0.03, 16), brass, Vector3(0, 0.22, 0.34), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
	part(body, cyl(0.035, 0.035, 0.032, 16), glow(Color(1.0, 0.85, 0.55), 1.6), Vector3(0, 0.22, 0.345), Vector3.ONE, Vector3(PI * 0.5, 0, 0))
	# the aviator's and the fox's scarf: a chain of silk pieces from the collar, streaming back
	var scarf := []
	if kind == "aviator" or kind == "fox" or kind == "racer":
		var silk := mat(Color(0.97, 0.95, 0.9) if kind != "racer" else Color(0.1, 0.3, 0.8), 0.55)
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
	under.light_color = fcol
	under.light_energy = 1.4
	under.omni_range = 3.6
	under.position = Vector3(0, -0.9, 0.2)
	rig.add_child(under)
	root.set_meta("rig", rig)
	root.set_meta("flames", flames)
	root.set_meta("scarf", scarf)
	return root

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

# ---------------------------------------------------------------- modern traffic (the Present and the Future)

## a glowing strip under a Future vehicle, in neon
static func _underglow(root: Node3D, w: float, l: float, col: Color) -> void:
	part(root, box(w, 0.02, l), glow(col, 2.2), Vector3(0, 0.12, 0))
	add_glow_sprite(root, Vector3(0, 0.15, 0), maxf(w, l) * 1.2, col, 0.5)

static func taxi(col: Color, future := false) -> Node3D:
	var root := Node3D.new()
	var p := paint(col)
	var black := mat(Color(0.03, 0.03, 0.03), 0.6)
	var glass := mat(Color(0.08, 0.1, 0.12), 0.05, 0.6)
	part(root, box(1.3, 0.48, 2.2), p, Vector3(0, 0.62, 0))
	part(root, box(1.16, 0.42, 1.2), glass, Vector3(0, 1.06, 0.1))
	part(root, box(1.18, 0.06, 1.16), p, Vector3(0, 1.29, 0.1))
	part(root, box(0.36, 0.12, 0.16), glow(Color(1.0, 0.9, 0.5), 2.0), Vector3(0, 1.38, 0.1))
	for sx in [-1.0, 1.0]:
		for sz in [-0.72, 0.72]:
			part(root, cyl(0.3, 0.3, 0.2), black, Vector3(sx * 0.62, 0.3, sz), Vector3.ONE, Vector3(0, 0, PI * 0.5))
		part(root, box(0.3, 0.07, 0.04), glow(Color(1.0, 0.15, 0.1), 2.8), Vector3(sx * 0.42, 0.72, 1.11))
		part(root, box(0.26, 0.07, 0.04), glow(Color(1.0, 0.95, 0.85), 3.0), Vector3(sx * 0.42, 0.66, -1.11))
	if future:
		_underglow(root, 1.1, 2.0, Color(1.0, 0.25, 0.7))
	return root

static func truck(col: Color, future := false) -> Node3D:
	var root := Node3D.new()
	var cab := paint(col)
	var boxm := mat(Color(0.88, 0.88, 0.86), 0.6)
	var black := mat(Color(0.03, 0.03, 0.03), 0.6)
	part(root, box(1.45, 2.0, 2.9), boxm, Vector3(0, 1.45, 0.45))
	part(root, box(1.45, 1.4, 1.1), cab, Vector3(0, 1.1, -1.5))
	part(root, box(1.3, 0.5, 0.05), mat(Color(0.1, 0.12, 0.14), 0.05, 0.6), Vector3(0, 1.45, -2.06))
	for sx in [-1.0, 1.0]:
		for sz in [-1.5, 0.3, 1.4]:
			part(root, cyl(0.38, 0.38, 0.26), black, Vector3(sx * 0.66, 0.38, sz), Vector3.ONE, Vector3(0, 0, PI * 0.5))
		part(root, box(0.12, 0.25, 0.04), glow(Color(1.0, 0.15, 0.1), 2.8), Vector3(sx * 0.6, 0.6, 1.92))
	if future:
		part(root, box(1.47, 0.08, 2.92), glow(Color(0.2, 0.95, 1.0), 2.2), Vector3(0, 2.2, 0.45))
	return root

static func city_bus(col: Color, future := false) -> Node3D:
	var root := Node3D.new()
	var p := paint(col)
	var win := mat(Color(0.95, 0.9, 0.75), 0.2, 0.0, Color(0.9, 0.95, 1.0) if future else Color(1.0, 0.85, 0.6), 1.4)
	var black := mat(Color(0.03, 0.03, 0.03), 0.6)
	part(root, box(1.5, 2.1, 4.2), p, Vector3(0, 1.35, 0))
	part(root, box(1.52, 0.7, 3.9), win, Vector3(0, 1.7, 0.05))
	part(root, box(1.4, 0.9, 0.05), mat(Color(0.1, 0.12, 0.14), 0.05, 0.6), Vector3(0, 1.6, -2.11))
	for sx in [-1.0, 1.0]:
		for sz in [-1.4, 1.4]:
			part(root, cyl(0.36, 0.36, 0.24), black, Vector3(sx * 0.66, 0.36, sz), Vector3.ONE, Vector3(0, 0, PI * 0.5))
		part(root, box(0.12, 0.3, 0.04), glow(Color(1.0, 0.15, 0.1), 2.8), Vector3(sx * 0.62, 0.8, 2.11))
	if future:
		_underglow(root, 1.3, 4.0, Color(0.2, 0.95, 1.0))
	return root

## a flying cab: a rounded pod with four ducted fans
static func hovercab(col: Color) -> Node3D:
	var root := Node3D.new()
	var p := paint(col)
	part(root, sphere(0.5, 24), p, Vector3.ZERO, Vector3(1.4, 0.8, 2.6))
	part(root, sphere(0.42, 20), mat(Color(0.08, 0.1, 0.14), 0.04, 0.6), Vector3(0, 0.18, -0.25), Vector3(1.3, 0.7, 1.4))
	var duct := TorusMesh.new()
	duct.inner_radius = 0.2; duct.outer_radius = 0.27; duct.rings = 20; duct.ring_segments = 6
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			part(root, duct, mat(Color(0.85, 0.85, 0.88), 0.3, 0.6), Vector3(sx * 0.82, -0.05, sz * 0.75))
			part(root, cyl(0.2, 0.2, 0.01, 16), glow(Color(0.5, 0.85, 1.0), 1.5), Vector3(sx * 0.82, -0.1, sz * 0.75))
		part(root, box(0.2, 0.06, 0.04), glow(Color(1.0, 0.15, 0.1), 2.8), Vector3(sx * 0.3, 0.05, 1.3))
	part(root, box(0.3, 0.1, 0.12), glow(Color(1.0, 0.9, 0.4), 2.0), Vector3(0, 0.42, 0.2))
	return root

## a delivery drone: four rotors on arms, a parcel underneath, blinking lights
static func drone(col: Color) -> Node3D:
	var root := Node3D.new()
	var p := paint(col)
	var dark := mat(Color(0.06, 0.06, 0.07), 0.4, 0.4)
	part(root, box(0.55, 0.18, 0.55), p, Vector3.ZERO)
	part(root, box(0.42, 0.34, 0.42), mat(Color(0.62, 0.48, 0.32), 0.8), Vector3(0, -0.3, 0))
	var rotors := []
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			part(root, box(0.5, 0.05, 0.06), dark, Vector3(sx * 0.35, 0.06, sz * 0.35), Vector3.ONE, Vector3(0, sx * sz * PI * 0.25, 0))
			var r := Node3D.new()
			r.position = Vector3(sx * 0.55, 0.12, sz * 0.55)
			root.add_child(r)
			part(r, box(0.5, 0.01, 0.05), dark, Vector3.ZERO)
			var dm := StandardMaterial3D.new()
			dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			dm.albedo_color = Color(0.8, 0.8, 0.85, 0.15)
			dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			part(r, cyl(0.26, 0.26, 0.005, 16), dm, Vector3.ZERO)
			rotors.append(r)
	part(root, sphere(0.04), glow(Color(1.0, 0.2, 0.2), 4.0), Vector3(-0.3, 0.12, 0.3))
	part(root, sphere(0.04), glow(Color(0.2, 1.0, 0.4), 4.0), Vector3(0.3, 0.12, 0.3))
	root.set_meta("rotors", rotors)
	root.scale = Vector3.ONE * 1.5
	return root

## a concrete barrier across the lane with LED chevrons, on posts from the road
static func barrier_modern(future := false) -> Node3D:
	var root := Node3D.new()
	var conc := mat(Color(0.72, 0.7, 0.66), 0.8)
	var post := -World.ROAD_Y + 0.3
	for sx in [-0.72, 0.72]:
		part(root, box(0.14, post, 0.14), mat(Color(0.3, 0.3, 0.32), 0.5, 0.6), Vector3(sx, 0.3 - post * 0.5, 0))
	part(root, box(1.6, 0.36, 0.18), conc, Vector3(0, 0.1, 0))
	var c := Color(1.0, 0.3, 0.75) if future else Color(1.0, 0.55, 0.1)
	for i in 4:
		part(root, box(0.16, 0.18, 0.02), glow(c, 2.6), Vector3(-0.54 + i * 0.36, 0.1, 0.1), Vector3.ONE, Vector3(0, 0, 0.6))
	add_glow_sprite(root, Vector3(0, 0.1, 0.15), 1.6, c, 0.6)
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
