class_name WorldKit
extends RefCounted

## Builds every placeholder object in the world (obstacles, coins, power-ups,
## scenery) out of primitive shapes. Swap these for real 3D models later:
## gameplay only reads the Obstacle collision data, not the meshes.

const TRAIN_COLORS := [
	Color("e8504a"), Color("3d8fd6"), Color("f2b33d"), Color("4cb07a"), Color("9b6bd6"), Color("eeeeee"),
]
const BUILDING_COLORS := [
	Color("f4a259"), Color("f6d39a"), Color("8cc7c2"), Color("e98a8a"), Color("b7a6e0"),
	Color("f1e4c6"), Color("9fd08f"), Color("7fb2e5"),
]

static var _building_mats := {}


static func clear_cache() -> void:
	_building_mats.clear()


# ---------------------------------------------------------------- obstacles

static func hurdle(lane: int) -> Obstacle:
	var o := Obstacle.new()
	o.name = "Hurdle"
	o.kind = Obstacle.Kind.HURDLE
	o.lane = lane
	o.boxes.append(AABB(Vector3(-1.1, 0.0, -0.2), Vector3(2.2, 1.0, 0.4)))
	var post := MeshKit.mat(Color("d9d9d9"), 0.5, 0.0, 0.6)
	for sx in [-1.0, 1.0]:
		MeshKit.box(o, Vector3(0.12, 1.0, 0.12), post, Vector3(sx, 0.5, 0))
		MeshKit.box(o, Vector3(0.14, 0.06, 0.6), post, Vector3(sx, 0.03, 0))
	var red := MeshKit.mat(Color("e23b2e"), 0.6)
	var white := MeshKit.mat(Color("f7f7f7"), 0.6)
	for row in [0.85, 0.5]:
		for i in 5:
			MeshKit.box(o, Vector3(0.4, 0.26, 0.1), red if i % 2 == 0 else white,
				Vector3(-0.8 + i * 0.4, row, 0))
	return o


static func bar(lane: int) -> Obstacle:
	var o := Obstacle.new()
	o.name = "Bar"
	o.kind = Obstacle.Kind.BAR
	o.lane = lane
	o.boxes.append(AABB(Vector3(-1.1, 1.05, -0.15), Vector3(2.2, 2.3, 0.3)))
	var post := MeshKit.mat(Color("3a3f47"), 0.5, 0.0, 0.5)
	for sx in [-1.12, 1.12]:
		MeshKit.box(o, Vector3(0.12, 3.3, 0.12), post, Vector3(sx, 1.65, 0))
	MeshKit.box(o, Vector3(2.2, 1.2, 0.16), MeshKit.mat(Color("ffcc1f"), 0.5), Vector3(0, 1.75, 0))
	var black := MeshKit.mat(Color("222222"), 0.5)
	for i in 4:
		MeshKit.box(o, Vector3(0.22, 1.22, 0.17), black, Vector3(-0.75 + i * 0.5, 1.75, 0), Vector3(0, 0, 0.6))
	MeshKit.box(o, Vector3(2.3, 0.12, 0.2), post, Vector3(0, 3.2, 0))
	return o


static func train(lane: int, length: float, with_ramp: bool, rng: RandomNumberGenerator) -> Obstacle:
	var o := Obstacle.new()
	o.name = "Train"
	o.kind = Obstacle.Kind.TRAIN
	o.lane = lane
	o.has_ramp = with_ramp
	var h := GameConfig.TRAIN_HEIGHT
	var w := GameConfig.TRAIN_WIDTH
	# Origin = front face of the wagon; the body extends away from the player (-Z).
	o.boxes.append(AABB(Vector3(-w * 0.5, 0.0, -length), Vector3(w, h, length)))
	o.add_walk(-length, 0.0, h, h)

	var body_color: Color = TRAIN_COLORS[rng.randi() % TRAIN_COLORS.size()]
	var body := MeshKit.mat(body_color, 0.45)
	var dark := MeshKit.mat(Color("2b2f36"), 0.7)
	var glass := MeshKit.mat(Color("1b2a3a"), 0.15, 0.0, 0.3)
	MeshKit.box(o, Vector3(w, h - 0.4, length), body, Vector3(0, 0.4 + (h - 0.4) * 0.5, -length * 0.5))
	MeshKit.box(o, Vector3(w - 0.3, 0.4, length - 0.6), dark, Vector3(0, 0.2, -length * 0.5))
	# roof: grey with a few vents so it reads as a roof when you run on it
	MeshKit.box(o, Vector3(w + 0.04, 0.12, length), MeshKit.mat(Color("8f969e"), 0.6),
		Vector3(0, h - 0.06, -length * 0.5))
	var vent := MeshKit.mat(Color("6c737b"), 0.6)
	var vz := -2.5
	while vz > -length + 1.5:
		MeshKit.box(o, Vector3(1.0, 0.1, 1.2), vent, Vector3(0, h + 0.03, vz))
		vz -= 5.0
	# stripe along the sides
	MeshKit.box(o, Vector3(w + 0.03, 0.18, length), MeshKit.mat(body_color.lightened(0.5), 0.4),
		Vector3(0, 1.05, -length * 0.5))
	# window band on both sides
	MeshKit.box(o, Vector3(w + 0.02, 0.55, length - 1.2), glass, Vector3(0, 1.65, -length * 0.5))
	# front: windshield + headlights
	MeshKit.box(o, Vector3(w - 0.4, 0.6, 0.05), glass, Vector3(0, 1.75, 0.0))
	var lamp := MeshKit.mat(Color("fff3b0"), 0.3, 2.0)
	for sx in [-0.65, 0.65]:
		MeshKit.box(o, Vector3(0.3, 0.18, 0.05), lamp, Vector3(sx, 0.85, 0.01))

	if with_ramp:
		var r := GameConfig.RAMP_LENGTH
		o.add_walk(0.0, r, 0.0, h, true)
		var slope := atan2(h, r)
		var ramp_mat := MeshKit.mat(Color("8d6e4c"), 0.9)
		MeshKit.box(o, Vector3(w, 0.15, sqrt(r * r + h * h)), ramp_mat,
			Vector3(0, h * 0.5 - 0.05, r * 0.5), Vector3(slope, 0, 0))
		# side rails so it reads as a ramp
		var rail := MeshKit.mat(Color("5b4632"), 0.9)
		for sx in [-w * 0.5, w * 0.5]:
			MeshKit.box(o, Vector3(0.08, 0.25, sqrt(r * r + h * h)), rail,
				Vector3(sx, h * 0.5 + 0.08, r * 0.5), Vector3(slope, 0, 0))
		MeshKit.box(o, Vector3(w - 0.2, h * 0.5, 0.2), rail, Vector3(0, h * 0.25, 1.0))
	return o


# ---------------------------------------------------------------- pickups

static func coin() -> Node3D:
	var c := Node3D.new()
	c.name = "Coin"
	var gold := MeshKit.mat(Color("ffcf33"), 0.25, 0.35, 0.8)
	MeshKit.cylinder(c, 0.42, 0.42, 0.1, gold, Vector3.ZERO, Vector3(PI * 0.5, 0, 0), 18)
	MeshKit.cylinder(c, 0.24, 0.24, 0.12, MeshKit.mat(Color("f2a900"), 0.3, 0.2, 0.8),
		Vector3.ZERO, Vector3(PI * 0.5, 0, 0), 12)
	return c


static func power_up(kind: String) -> Node3D:
	var p := Node3D.new()
	p.name = "PowerUp"
	p.set_meta("kind", kind)
	var spin := Node3D.new()
	spin.name = "Spin"
	p.add_child(spin)
	if kind == "magnet":
		var red := MeshKit.mat(Color("e8313a"), 0.3, 0.4)
		MeshKit.torus(spin, 0.22, 0.42, red, Vector3.ZERO, Vector3(PI * 0.5, 0, 0))
		var tip := MeshKit.mat(Color("eeeeee"), 0.3, 0.3)
		for sx in [-0.32, 0.32]:
			MeshKit.box(spin, Vector3(0.2, 0.22, 0.2), tip, Vector3(sx, -0.32, 0))
	else:
		var green := MeshKit.mat(Color("37d67a"), 0.3, 0.5)
		MeshKit.box(spin, Vector3(0.5, 0.5, 0.5), green, Vector3.ZERO, Vector3(0.6, 0, 0.6))
		MeshKit.torus(spin, 0.45, 0.55, MeshKit.mat(Color("ffffff"), 0.3, 0.6), Vector3.ZERO, Vector3(PI * 0.5, 0, 0))
	return p


# ---------------------------------------------------------------- scenery

## side: -1 = left of the track, 1 = right (awnings face the track)
static func building(rng: RandomNumberGenerator, w: float, d: float, h: float, side: float) -> Node3D:
	var b := Node3D.new()
	b.name = "Building"
	var color: Color = BUILDING_COLORS[rng.randi() % BUILDING_COLORS.size()]
	MeshKit.box(b, Vector3(w, h, d), _building_mat(color), Vector3(0, h * 0.5, 0))
	MeshKit.box(b, Vector3(w + 0.3, 0.3, d + 0.3), MeshKit.mat(color.darkened(0.25), 0.8), Vector3(0, h + 0.15, 0))
	if rng.randf() < 0.4:
		# awning at street level
		MeshKit.box(b, Vector3(0.9, 0.12, d * 0.7), MeshKit.mat(Color("e74c3c") if rng.randf() < 0.5 else Color("2e86de"), 0.7),
			Vector3(-side * (w * 0.5 + 0.45), 2.6, 0))
	return b


static func _building_mat(color: Color) -> ShaderMaterial:
	var key := color.to_html()
	if not _building_mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/building.gdshader")
		m.set_shader_parameter("wall", color)
		_building_mats[key] = m
	return _building_mats[key]


static func palm(rng: RandomNumberGenerator) -> Node3D:
	var p := Node3D.new()
	p.name = "Palm"
	var trunk := MeshKit.mat(Color("9a7650"), 0.9)
	var h := rng.randf_range(4.5, 7.0)
	var lean := rng.randf_range(-0.12, 0.12)
	var segs := 5
	for i in segs:
		var y := (i + 0.5) * h / segs
		MeshKit.cylinder(p, 0.16, 0.2, h / segs + 0.05, trunk, Vector3(lean * y, y, 0), Vector3(0, 0, -lean))
	var leaf := MeshKit.mat(Color("2f9e4f"), 0.8)
	var top := Vector3(lean * h, h, 0)
	for i in 7:
		var ang := TAU * i / 7.0 + rng.randf() * 0.3
		var dir := Vector3(cos(ang), 0, sin(ang))
		var frond := MeshKit.box(p, Vector3(0.5, 0.06, 2.4), leaf, top + dir * 1.0 + Vector3(0, -0.25, 0))
		frond.look_at_from_position(frond.position, top + dir * 2.2 + Vector3(0, -1.0, 0), Vector3.UP)
	MeshKit.sphere(p, 0.25, MeshKit.mat(Color("6b4a2b"), 0.8), top + Vector3(0, -0.1, 0))
	return p


static func lamp_post(side: float) -> Node3D:
	var l := Node3D.new()
	l.name = "Lamp"
	var metal := MeshKit.mat(Color("40464f"), 0.4, 0.0, 0.6)
	MeshKit.cylinder(l, 0.07, 0.1, 4.2, metal, Vector3(0, 2.1, 0))
	MeshKit.box(l, Vector3(1.0, 0.08, 0.08), metal, Vector3(-side * 0.45, 4.15, 0))
	MeshKit.box(l, Vector3(0.4, 0.12, 0.25), MeshKit.mat(Color("fff1c1"), 0.3, 1.5), Vector3(-side * 0.85, 4.07, 0))
	return l


static func bench() -> Node3D:
	var b := Node3D.new()
	b.name = "Bench"
	var wood := MeshKit.mat(Color("b07a45"), 0.8)
	var metal := MeshKit.mat(Color("40464f"), 0.4, 0.0, 0.6)
	MeshKit.box(b, Vector3(0.5, 0.08, 1.8), wood, Vector3(0, 0.5, 0))
	MeshKit.box(b, Vector3(0.08, 0.4, 1.8), wood, Vector3(0.24, 0.75, 0))
	for sz in [-0.75, 0.75]:
		MeshKit.box(b, Vector3(0.45, 0.5, 0.08), metal, Vector3(0, 0.25, sz))
	return b
