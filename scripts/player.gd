class_name Player
extends Node3D

## The runner. Handles lanes, jumping, sliding and a procedural run cycle.
## Collision is done by hand in game.gd using hit_box().

var lane := 1
var grounded := true
var vy := 0.0
var slide_left := 0.0
var dead := false

var _prev_lane := 1
var _lane_from_x := 0.0
var _lane_t := 1.0
var _reverting := false
var _run_phase := 0.0
var _land_squash := 0.0
var _ground := 0.0

var _model: Node3D
var _body: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _shadow: MeshInstance3D


func _ready() -> void:
	_build_model()
	reset()


func reset() -> void:
	lane = 1
	_prev_lane = 1
	_lane_t = 1.0
	_reverting = false
	position = Vector3.ZERO
	_ground = 0.0
	vy = 0.0
	grounded = true
	slide_left = 0.0
	dead = false
	_model.rotation = Vector3.ZERO
	_model.position = Vector3.ZERO


# ------------------------------------------------------------------ actions

func move_lane(dir: int) -> bool:
	var target := clampi(lane + dir, 0, 2)
	if target == lane or dead:
		return false
	_prev_lane = lane
	_lane_from_x = position.x
	lane = target
	_lane_t = 0.0
	_reverting = false
	return true


## Bounce back to the lane we came from (after bumping into something sideways).
func revert_lane() -> void:
	var back := _prev_lane
	_prev_lane = lane
	_lane_from_x = position.x
	lane = back
	_lane_t = 0.0
	_reverting = true


func jump() -> bool:
	if not grounded or dead:
		return false
	slide_left = 0.0
	vy = GameConfig.JUMP_VELOCITY
	grounded = false
	return true


func slide() -> bool:
	if dead:
		return false
	if not grounded:
		vy = minf(vy, GameConfig.FAST_FALL_VELOCITY)  # slam down, then slide on landing
	slide_left = GameConfig.SLIDE_TIME
	return true


func is_sliding() -> bool:
	return slide_left > 0.0 and grounded


func is_changing_lane() -> bool:
	return _lane_t < 1.0


func is_reverting() -> bool:
	return _reverting and _lane_t < 1.0


## Collision box in world space (the player is always at z = 0).
func hit_box() -> AABB:
	var h := GameConfig.PLAYER_SLIDE_HEIGHT if is_sliding() else GameConfig.PLAYER_HEIGHT
	var hw := GameConfig.PLAYER_HALF_WIDTH
	var hd := GameConfig.PLAYER_HALF_DEPTH
	# feet raised a little so standing exactly on a roof never counts as a hit
	return AABB(Vector3(position.x - hw, position.y + 0.15, -hd), Vector3(hw * 2.0, h - 0.15, hd * 2.0))


## Centre of the body, for coin pickup.
func center() -> Vector3:
	return position + Vector3(0, 0.5 if is_sliding() else 0.9, 0)


# ------------------------------------------------------------------ update

## Returns "land" when touching down this frame (for sounds), else "".
func step(delta: float, track: Track, speed: float) -> String:
	var event := ""
	if _lane_t < 1.0:
		_lane_t = minf(1.0, _lane_t + delta / GameConfig.LANE_CHANGE_TIME)
	position.x = lerpf(_lane_from_x, GameConfig.lane_x(lane), smoothstep(0.0, 1.0, _lane_t))

	vy -= GameConfig.GRAVITY * delta
	position.y += vy * delta
	var g := track.ground_height(position.x, 0.0, position.y)
	_ground = g
	if position.y <= g:
		if not grounded and vy < -4.0:
			event = "land"
			_land_squash = 1.0
		position.y = g
		vy = 0.0
		grounded = true
	else:
		grounded = false

	if grounded and slide_left > 0.0:
		slide_left -= delta

	_animate(delta, speed)
	return event


## Idle loop for the menu.
func idle(delta: float) -> void:
	_run_phase += delta * 2.0
	_model.rotation.x = lerpf(_model.rotation.x, 0.0, 1.0 - exp(-delta * 10.0))
	_model.rotation.y = lerpf(_model.rotation.y, -0.45, 1.0 - exp(-delta * 6.0))  # face the menu camera
	_body.position.y = sin(_run_phase) * 0.02
	_leg_l.rotation.x = 0.0
	_leg_r.rotation.x = 0.0
	_arm_l.rotation = Vector3(0, 0, 0.12 + sin(_run_phase) * 0.04)
	_arm_r.rotation = Vector3(0, 0, -0.12 - sin(_run_phase) * 0.04)
	_shadow.position.y = 0.02


## Fall-over animation after a crash.
func die_anim(delta: float) -> void:
	_model.rotation.x = lerpf(_model.rotation.x, 1.45, 1.0 - exp(-delta * 8.0))
	vy -= GameConfig.GRAVITY * delta
	position.y = maxf(_ground, position.y + vy * delta)
	if position.y <= _ground:
		vy = 0.0
	_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -2.6, delta * 6.0)
	_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -2.6, delta * 6.0)


func _animate(delta: float, speed: float) -> void:
	var k := 1.0 - exp(-delta * 14.0)
	_land_squash = maxf(0.0, _land_squash - delta * 5.0)
	_shadow.position.y = 0.02 - (position.y - _ground_under())
	var shadow_scale := clampf(1.0 - (position.y - _ground_under()) * 0.15, 0.5, 1.0)
	_shadow.scale = Vector3(shadow_scale, 1, shadow_scale)
	# lean into lane changes
	var lean := 0.0
	if _lane_t < 1.0:
		lean = signf(GameConfig.lane_x(lane) - _lane_from_x) * -0.35 * sin(_lane_t * PI)
	_model.rotation.z = lean
	_model.rotation.y = lerpf(_model.rotation.y, 0.0, 1.0 - exp(-delta * 10.0))

	if is_sliding():
		_model.rotation.x = lerpf(_model.rotation.x, 1.15, k)
		_leg_l.rotation.x = lerpf(_leg_l.rotation.x, -1.2, k)
		_leg_r.rotation.x = lerpf(_leg_r.rotation.x, -1.0, k)
		_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -2.4, k)
		_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -2.4, k)
		_body.position.y = 0.0
		return
	_model.rotation.x = lerpf(_model.rotation.x, -0.12, k)
	if not grounded:
		var tuck := clampf(1.0 - absf(vy) / GameConfig.JUMP_VELOCITY, 0.0, 1.0)
		_leg_l.rotation.x = lerpf(_leg_l.rotation.x, -0.9 - tuck * 0.5, k)
		_leg_r.rotation.x = lerpf(_leg_r.rotation.x, 0.5 - tuck * 0.9, k)
		_arm_l.rotation.x = lerpf(_arm_l.rotation.x, -2.2, k)
		_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -2.2, k)
		_body.position.y = 0.0
		return
	_run_phase += delta * (8.0 + speed * 0.35)
	var s := sin(_run_phase)
	_leg_l.rotation.x = -s * 0.95
	_leg_r.rotation.x = s * 0.95
	_arm_l.rotation = Vector3(s * 0.9, 0, 0.1)
	_arm_r.rotation = Vector3(-s * 0.9, 0, -0.1)
	_body.position.y = absf(cos(_run_phase)) * 0.07 - _land_squash * 0.12


func _ground_under() -> float:
	return _ground


# ------------------------------------------------------------------ model

func _build_model() -> void:
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	_body = Node3D.new()
	_model.add_child(_body)

	var skin := MeshKit.mat(Color("f2c09b"), 0.7)
	var shirt := MeshKit.mat(Color("ff6b35"), 0.7)
	var pants := MeshKit.mat(Color("2d4b8e"), 0.8)
	var shoe := MeshKit.mat(Color("f5f5f5"), 0.6)
	var cap := MeshKit.mat(Color("1fa2e0"), 0.6)
	var pack := MeshKit.mat(Color("ffd23f"), 0.7)
	var dark := MeshKit.mat(Color("1d1d1d"), 0.5)

	MeshKit.box(_body, Vector3(0.62, 0.68, 0.36), shirt, Vector3(0, 1.1, 0))
	MeshKit.box(_body, Vector3(0.6, 0.2, 0.34), pants, Vector3(0, 0.78, 0))
	MeshKit.box(_body, Vector3(0.46, 0.5, 0.2), pack, Vector3(0, 1.12, 0.27))
	MeshKit.box(_body, Vector3(0.36, 0.14, 0.05), MeshKit.mat(Color("e0a800"), 0.7), Vector3(0, 0.98, 0.39))
	MeshKit.sphere(_body, 0.27, skin, Vector3(0, 1.7, 0))
	MeshKit.cylinder(_body, 0.29, 0.29, 0.16, cap, Vector3(0, 1.86, 0))
	MeshKit.box(_body, Vector3(0.36, 0.05, 0.26), cap, Vector3(0, 1.8, -0.3))
	for sx in [-0.1, 0.1]:
		MeshKit.box(_body, Vector3(0.06, 0.08, 0.03), dark, Vector3(sx, 1.72, -0.255))

	_leg_l = _limb(Vector3(-0.15, 0.78, 0))
	_leg_r = _limb(Vector3(0.15, 0.78, 0))
	for leg in [_leg_l, _leg_r]:
		MeshKit.box(leg, Vector3(0.23, 0.68, 0.25), pants, Vector3(0, -0.34, 0))
		MeshKit.box(leg, Vector3(0.25, 0.14, 0.36), shoe, Vector3(0, -0.71, -0.05))
	_arm_l = _limb(Vector3(-0.42, 1.38, 0))
	_arm_r = _limb(Vector3(0.42, 1.38, 0))
	for arm in [_arm_l, _arm_r]:
		MeshKit.box(arm, Vector3(0.18, 0.58, 0.2), shirt, Vector3(0, -0.28, 0))
		MeshKit.sphere(arm, 0.1, skin, Vector3(0, -0.62, 0))

	# soft blob shadow so you can judge jumps even without real shadows
	var blob := MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2(1.0, 1.0)
	blob.mesh = quad
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = _blob_texture()
	m.albedo_color = Color(0, 0, 0, 0.45)
	blob.material_override = m
	blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(blob)
	_shadow = blob


func _limb(pivot: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pivot
	_body.add_child(n)
	return n


func _blob_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	return t
