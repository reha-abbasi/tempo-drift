extends Node3D
## Edge bounce: a swipe past an outer lane bounces the ride off a soft wall.
## The car presses out toward the wall, squashes flat against it, leans away and springs back into its lane
## stretching and wobbling; the jetpack pilot twirls round instead, arms and legs flailing. A few little stars pop
## where it touched, the wall along the road's edge shimmers, a soft "boing" plays and the phone ticks.
## Only the drawing moves: the rules' x, which plays the notes and meets the traffic, never leaves the lane, and the
## next swipe is never held up (a swipe back in lets go of the bounce at once).

const PUSH := 0.42             # how far past its lane the ride presses into the wall (rules units)
const WALL := 0.65             # where the wall stands, past the outer lane's centre (rules units)
const OUT_T := 0.085           # the press out (s)
const BACK_W := TAU / 0.3      # the spring back: one wobble every 0.3 s ...
const BACK_DAMP := 8.0         # ... dying away (1/s)
const JIGGLE_W := TAU * 5.0    # squash, stretch, a smaller squash, settled
const JIGGLE_DAMP := 6.0
const SQUASH := Vector3(-0.38, 0.3, 0.15)   # the car's size change when flat against the wall (stretched: the opposite)
const ROLL := 0.19             # how far it leans away from the wall (radians) ...
const YAW := 0.07              # ... and how far its nose glances off
const HOP := 0.1               # it lifts a little as it springs off (rules units) ...
const HOP_T := 0.24            # ... and is back down this soon (s)
const SPIN_T := 0.42           # the pilot's twirl (s)
const DONE := 0.5              # the whole bounce (s)
const LET_GO := 0.12           # a swipe during the bounce fades it out this fast (s)
const ROW_GAP := 0.7           # touches closer than this count as a row: each boing a step higher (s)
const FIELD_T := 0.3           # the wall's shimmer (s)
const FIELD_SIZE := Vector2(1.75, 0.95)
const FIELD_TURN := 10.0       # the wall panel runs along the street, turned this little toward the camera (degrees)
const WARM := Color(1.0, 0.92, 0.78)
const STAR := Color(1.0, 0.86, 0.45)
const BOING_DB := -4.0
const LIMBS := ["Hip/Torso/ShoulderL", "Hip/Torso/ShoulderR", "Hip/LegL", "Hip/LegR"]

var _run: Node3D
var _dir := 0                  # the wall touched: -1 left, 1 right
var _age := 9.0                # since the touch (s)
var _let := -1.0               # since a swipe let go of the bounce (s); below 0 when none did
var _row := 0                  # touches in a row
var _now := Vector4.ZERO       # as drawn now: offset toward the wall, lift (rules units), squash, lean
var _from := Vector4.ZERO      # as drawn at the touch: a touch during a bounce carries on from there
var _spin_age := 9.0           # the pilot's twirl runs to the end even when touched again
var _spin_dir := 0
var _flail := Vector4.ZERO     # what was added to the pilot's limbs last frame
var _fields := {}              # -1 / 1: the wall's two shimmers (a quick second touch gets the other one)
var _field_age := {-1: [9.0, 9.0], 1: [9.0, 9.0]}
var _next := {-1: 0, 1: 0}
var _stars := {}               # -1 / 1: little stars where it touched
var _boing: AudioStream
var _low := false             # Reduce effects: no shimmer on the wall, fewer stars


func setup(run: Node3D) -> void:
	_run = run
	run.rules.edge_bump.connect(bump)
	run.rules.moved.connect(_on_moved)
	_boing = load("res://audio/sfx/boing.res")
	_low = Save.data.settings.get("fx_low", false)
	var pods: Array = Catalog.theme(run.info.map).pods
	var tint := WARM.lerp(Color(pods[0], pods[1], pods[2]), 0.3)
	var shader: Shader = load("res://materials/edge_wall.gdshader")
	var m := QuadMesh.new()
	m.size = FIELD_SIZE
	var star := _star_mesh()
	for d in [-1, 1]:
		_fields[d] = []
		for i in 2:
			var q := MeshInstance3D.new()
			q.mesh = m
			var sm := ShaderMaterial.new()
			sm.shader = shader
			sm.set_shader_parameter("color", tint)
			sm.set_shader_parameter("size", FIELD_SIZE)
			q.material_override = sm
			q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			q.visible = false
			add_child(q)
			_fields[d].append(q)
		_stars[d] = _star_burst(d, star)


func bump(dir: int) -> void:
	## the rules' edge_bump: a swipe past the outer lane on side dir
	_row = _row + 1 if _age < ROW_GAP and dir == _dir else 0
	var side := float(_dir * dir)
	_from = Vector4(clampf(_now.x * side, -PUSH, PUSH), _now.y, _now.z, _now.w * side)
	_dir = dir
	_age = 0.0
	_let = -1.0
	if _spin_age >= SPIN_T:
		_spin_age = 0.0
		_spin_dir = dir
	_field_age[dir][_next[dir]] = 0.0
	_next[dir] = 1 - _next[dir]
	(_stars[dir] as GPUParticles3D).restart()
	var p := AudioStreamPlayer.new()
	p.stream = _boing
	p.volume_db = BOING_DB + 1.5 * mini(_row, 3)
	p.pitch_scale = pow(2.0, 2.0 * mini(_row, 3) / 12.0)
	p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	if Save.data.settings.get("haptics", true):
		Input.vibrate_handheld(18, 0.45)


func _on_moved(dc: int, _dr: int) -> void:
	# a swipe to another lane lets go of the bounce: the ride goes where it was sent, with no tug the other way
	if dc != 0 and _age < DONE:
		_let = 0.0


func apply(ride: Node3D, delta: float) -> void:
	## run.gd's _place: draw the bounce on the ride (after the rules have placed it) and the wall's shimmer
	_age += delta
	_spin_age += delta
	if _let >= 0.0:
		_let += delta
	var hold := 1.0 if _let < 0.0 else 1.0 - smoothstep(0.0, LET_GO, _let)
	_now = _shape(_age) * hold
	var K: float = _run.K
	var y := ride.position.y
	var car: bool = _run.rules.form == 2
	ride.position += Vector3(_dir * _now.x * K, _now.y * K, 0.0)
	# it leans away from the wall, the nose glancing off; the pilot twirls round instead
	var spin := 0.0
	if not car and _spin_age < SPIN_T:
		spin = _spin_dir * TAU * (1.0 - pow(1.0 - _spin_age / SPIN_T, 3.0))
	ride.rotation += Vector3(0.0, _dir * _now.w * YAW + spin, _dir * _now.w * ROLL)
	ride.scale = Vector3.ONE + SQUASH * _now.z * (1.0 if car else 0.3)
	if not car:
		_flail_limbs()
	for d in [-1, 1]:
		var at := Vector3(d * (Rules.LX[2] + WALL) * K, y + 0.35, ride.position.z + 0.25)
		_stars[d].position = at - Vector3(d * 0.1, 0.0, 0.0)
		for i in 2:
			_field_age[d][i] += delta
			var q: MeshInstance3D = _fields[d][i]
			q.visible = _field_age[d][i] < FIELD_T and not _low
			if q.visible:
				q.transform = Transform3D(Basis(Vector3.UP, deg_to_rad(-d * (90.0 - FIELD_TURN))), at + Vector3(d * 0.01 * i, 0.0, 0.0))
				var sm := q.material_override as ShaderMaterial
				sm.set_shader_parameter("age", _field_age[d][i] / FIELD_T)
				sm.set_shader_parameter("power", 1.0 + 0.15 * mini(_row, 3))


func _shape(a: float) -> Vector4:
	## the bounce a seconds after the touch: offset toward the wall and lift (rules units), squash (1 flat against the
	## wall, below 0 stretched), lean away from the wall (1 = ROLL). Out fast, slowing as the wall gives, then a
	## springy way back that swings a little past the lane and settles
	if a >= DONE:
		return Vector4.ZERO
	if a < OUT_T:
		var u := a / OUT_T
		var touch := smoothstep(0.4, 1.0, u)
		return Vector4(lerpf(_from.x, PUSH, 1.0 - (1.0 - u) * (1.0 - u)), _from.y * (1.0 - u), lerpf(_from.z, 1.0, touch), lerpf(_from.w, 1.0, touch))
	var b := a - OUT_T
	var fade := clampf((DONE - a) / 0.08, 0.0, 1.0)
	return Vector4(PUSH * exp(-BACK_DAMP * b) * cos(BACK_W * b) * fade,
		HOP * sin(PI * b / HOP_T) if b < HOP_T else 0.0,
		exp(-JIGGLE_DAMP * b) * cos(JIGGLE_W * b) * fade,
		exp(-7.0 * b) * cos(TAU * 3.3 * b) * fade)


func _flail_limbs() -> void:
	# arms flap and legs kick during the twirl, added on top of the pilot's own pose (which eases back by itself)
	var pilot: Node3D = _run.pilot
	var f := Vector4.ZERO
	if _spin_age < DONE:
		var e := exp(-5.0 * _spin_age) * sin(TAU * 6.0 * _spin_age)
		var k := exp(-5.0 * _spin_age) * sin(TAU * 6.0 * _spin_age + 1.6)
		f = Vector4(0.9 * e, -0.9 * e, 0.6 * k, -0.6 * k)
	for i in 4:
		var n := pilot.get_node_or_null(LIMBS[i]) as Node3D
		if n:
			if i < 2:
				n.rotation.z += f[i] - _flail[i]
			else:
				n.rotation.x += f[i] - _flail[i]
	_flail = f


func _star_burst(d: int, mesh: QuadMesh) -> GPUParticles3D:
	## a pop of a few little stars, flying back toward the road and up a little
	var g := GPUParticles3D.new()
	g.emitting = false
	g.one_shot = true
	g.explosiveness = 1.0
	g.amount = 4 if _low else 7
	g.lifetime = 0.34
	g.local_coords = true
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.visibility_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(-d, 0.7, 0.0)
	pm.spread = 55.0
	pm.initial_velocity_min = 1.6
	pm.initial_velocity_max = 3.2
	pm.gravity = Vector3(0, -3.0, 0)
	pm.damping_min = 3.0
	pm.damping_max = 5.0
	pm.angle_min = -45.0
	pm.angle_max = 45.0
	pm.scale_min = 0.7
	pm.scale_max = 1.3
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.6))
	c.add_point(Vector2(0.25, 1.0))
	c.add_point(Vector2(1.0, 0.0))
	var ct := CurveTexture.new()
	ct.curve = c
	pm.scale_curve = ct
	g.process_material = pm
	g.draw_pass_1 = mesh
	add_child(g)
	return g


func _star_mesh() -> QuadMesh:
	## a small four-pointed star, drawn once
	var n := 32
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for j in n:
		for i in n:
			var u := (i + 0.5) / n * 2.0 - 1.0
			var v := (j + 0.5) / n * 2.0 - 1.0
			var arms := exp(-absf(u) * 14.0) * exp(-absf(v) * 2.4) + exp(-absf(v) * 14.0) * exp(-absf(u) * 2.4)
			var a := clampf(arms + exp(-(u * u + v * v) * 16.0), 0.0, 1.0) * (1.0 - smoothstep(0.8, 1.0, maxf(absf(u), absf(v))))
			img.set_pixel(i, j, Color(1, 1, 1, a))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.disable_fog = true
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.albedo_color = Color(STAR * 1.6, 1.0)
	var q := QuadMesh.new()
	q.size = Vector2(0.26, 0.26)
	q.material = mat
	return q
