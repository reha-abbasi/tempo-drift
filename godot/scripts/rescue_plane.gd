extends Node3D
## The rescue plane: after a crash the car comes back a bit sooner, and a friend brings it. When the rescue meter is full your own car rises up from behind, just below the jetpack pilot, with a
## friend at the wheel and the canopy open. The friend reaches up, grabs the pilot's hand and pulls them down into
## the seat, popping out of the other side on their own jetpack; the car rises into place with the canopy shut on
## the beat, and the friend waves and drops away. The player steers all the while and nothing can hit them until
## the car is theirs. The run makes one (not in Flight School) and calls place() every frame after placing the ride.

## played notes that bring the car back in an era's first cities (was 23 in London, 25 in Rio)
const RESCUE_NOTES := 15
## later episodes ask a little more: this many more notes per episode (Berlin 2075: 17, was 34)
const NOTES_PER_EP := 0.4
## a missed note takes back this much of one played note (was a half to four fifths of one)
const MISS_PART := 0.25
## the car comes on the first beat at least this long after the meter fills (was 0.35 s): time to see it coming
const LEAD := 1.0
## the friend is the first of these pilots that isn't your own
const FRIENDS := ["fox", "robot", "racer"]
## the arrival, as shares of the time from a full meter to the beat the car is yours
const SWOOP := 0.45         # rising up from behind into its place below the pilot
const GRAB := 0.55          # the hands meet
const LET_GO := 0.64        # the friend lets go and pops out of the other side
const PLOP := 0.76          # the pilot lands in the seat (the car dips a little)
const SHUT := Vector2(0.8, 0.93)  # the canopy swings shut
## where the car waits for the pilot: a little towards the street's middle, below and just behind them (m)
const SLOT := Vector3(0.45, -1.0, 0.5)
## where the friend hovers to wave: out on the same side, below and behind the car, under the rings (m)
const HOVER := Vector3(1.0, -1.1, 2.6)
const WAVE := 0.45          # the friend pops out and waves for this long (s)
const AWAY := 0.35          # then drops back out of the picture this fast (s)
const SEAT := 0.2           # the seat's height in the car (m above its middle); a pilot's hip is 0.5 above its feet
const ARM := 0.5            # a pilot's arm, shoulder to hand (m)
const OPEN := 1.1           # how far the canopy stands open (rad)
## how much of their usual lean the pilot and the car keep while the friend comes (until just after the swap)
const LEAN := 0.45

var run: Node3D
var rules: Rules
var car: Node3D
var friend: Node3D
var _on := false
var _t0 := 0.0
var _at := INF
var _side := 1.0
var _grabbed := false
var _whoosh := false
var _pop_t := INF           # when the friend let go
var _pop_from := Vector3.ZERO
var _grab_t := INF          # when the hands met, and where (from the pilot)
var _grab_off := Vector3.ZERO
var _flash: MeshInstance3D  # a flash of light at the hand-hold
var _glass_i := -1          # the car's canopy surface
var _hinge: Node3D          # a copy of the canopy that can swing open
var _clear := StandardMaterial3D.new()


static func notes_needed(ep: int) -> int:
	return RESCUE_NOTES + roundi(ep * NOTES_PER_EP)


static func tune(r: Rules) -> void:
	## the rescue numbers for a course: fewer notes fill the meter, a miss costs less, the car is seen coming
	var need := notes_needed(r.ep)
	# a hair over a full meter so that exactly `need` notes always fill it
	r.rescue_k = 100.0 / (need * Rules.RESCUE_PER) * 1.001
	r.rescue_miss = Rules.RESCUE_PER * r.rescue_k * MISS_PART
	r.rescue_lead = LEAD


func setup(r: Node3D) -> void:
	run = r
	rules = r.rules
	car = r.car
	tune(rules)
	rules.rescue_inbound.connect(_inbound)
	rules.delivered.connect(_delivered)
	# the canopy (the car's plain "~paint" surface) copied onto a hinge at its front, to stand open and swing shut
	# (hinged at the front it stands up beyond the friend, not between them and the camera)
	_clear.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_clear.albedo_color = Color(0, 0, 0, 0)
	var body := car.get_node("Body") as MeshInstance3D
	for i in body.mesh.get_surface_count():
		if body.mesh.surface_get_name(i) == "~paint":
			_glass_i = i
	if _glass_i >= 0:
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, body.mesh.surface_get_arrays(_glass_i))
		m.surface_set_material(0, body.mesh.surface_get_material(_glass_i))
		var box := m.get_aabb()
		_hinge = Node3D.new()
		_hinge.position = Vector3(0, box.position.y, box.position.z)
		var glass := MeshInstance3D.new()
		glass.mesh = m
		glass.position = -_hinge.position
		_hinge.add_child(glass)
		_hinge.visible = false
		car.add_child(_hinge)
	var key: String = FRIENDS[0] if Save.data.pilot != FRIENDS[0] else FRIENDS[1]
	friend = (load("res://scenes/pilots/%s.tscn" % key) as PackedScene).instantiate()
	add_child(friend)
	# bright gloves, so the grab reads from the chase camera, and a glow at each jetpack nozzle
	var glove := StandardMaterial3D.new()
	glove.albedo_color = Color("fff3d0")
	glove.emission_enabled = true
	glove.emission = Color("ffe08a")
	glove.emission_energy_multiplier = 1.2
	for s in ["L", "R"]:
		var hand := friend.get_node("Hip/Torso/Shoulder%s/Elbow/Hand" % s) as MeshInstance3D
		hand.material_override = glove
		hand.scale = Vector3.ONE * 2.6
	for f in friend.find_children("Flame*", "", true, false):
		var g := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.45, 0.45)
		var gm := ShaderMaterial.new()
		gm.shader = load("res://materials/shaders/glow.gdshader")
		gm.set_shader_parameter("color", Color(1.0, 0.7, 0.35))
		gm.set_shader_parameter("intensity", 2.0)
		q.material = gm
		g.mesh = q
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.add_child(g)
	friend.visible = false
	_flash = MeshInstance3D.new()
	var fq := QuadMesh.new()
	fq.size = Vector2(1.0, 1.0)
	var fm := ShaderMaterial.new()
	fm.shader = load("res://materials/shaders/glow.gdshader")
	fm.set_shader_parameter("color", Color(1.0, 0.92, 0.6))
	fq.material = fm
	_flash.mesh = fq
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.visible = false
	add_child(_flash)


func _inbound(at: float) -> void:
	## the meter is full: the friend sets off, coming up on the pilot's side nearer the street's middle
	_on = true
	_t0 = rules.t
	_at = at
	_side = -1.0 if rules.col == 2 else 1.0
	_grabbed = false
	_whoosh = false
	_pop_t = INF
	_grab_t = INF
	# nothing can hit the pilot while the car is on its way
	rules.invuln = maxf(rules.invuln, at - rules.t + 0.05)
	_canopy(0.0)
	friend.visible = true
	_flames(friend, 0.0)


func _delivered(form: int) -> void:
	if not _on or form != 2:
		return
	# the car is in its place: back to its own look
	car.transform = Transform3D()
	_canopy(1.0)
	run.pilot.transform = Transform3D()
	run.fx.catch(run.ride.global_position + Vector3(0, 0.4, 0), 1)


func place() -> void:
	if not _on:
		return
	var t := rules.t
	# calmer leans, so the catch reads cleanly even in the middle of a dash
	var calm := lerpf(1.0, LEAN, smoothstep(_t0, _t0 + 0.15, t) * (1.0 - smoothstep(_at + 0.25, _at + 0.55, t)))
	run.ride.rotation *= calm
	(run.pilot.get_node("Hip") as Node3D).rotation.z *= calm
	if t < _at:
		if rules.deliver_at == INF or rules.form != 1:
			# the rescue was called off (the run ended)
			_stop()
			return
		_arrive(clampf((t - _t0) / maxf(0.01, _at - _t0), 0.0, 1.0), t)
	if _pop_t < INF:
		_away(t - _pop_t)
	var g := clampf((t - _grab_t) / 0.3, 0.0, 1.0)
	_flash.visible = g < 1.0
	if _flash.visible:
		_flash.global_position = run.ride.global_position + _grab_off
		_flash.scale = Vector3.ONE * (0.5 + 1.3 * g)
		(_flash.mesh.surface_get_material(0) as ShaderMaterial).set_shader_parameter("intensity", 3.0 * (1.0 - g))
	if not friend.visible and t > _at + 0.55:
		_on = false


func _arrive(p: float, t: float) -> void:
	var ride: Node3D = run.ride
	var at := ride.global_position
	ride.visible = true   # (no invulnerability blinking while the friend comes)
	# 1. the car rises from behind and below the camera into its place under the pilot, level, slowing to match
	var slot := Vector3(_side * SLOT.x, SLOT.y, SLOT.z)
	var a := 1.0 - pow(1.0 - clampf(p / SWOOP, 0.0, 1.0), 3.0)
	var off := Vector3(_side * 0.7, -2.8, 10.0).lerp(slot, a)
	if p >= SWOOP:
		off.y += 0.03 * sin((t - _t0) * 9.0)
	if not _whoosh and p > 0.15:
		_whoosh = true
		Sound.play("whoosh", -2.0)
	# 4. with the pilot in, it dips (the plop) and rises into the ride's place, taking on its lean
	var rise := smoothstep(PLOP, 1.0, p)
	off = off.lerp(Vector3.ZERO, rise)
	off.y -= 0.12 * sin(clampf((p - PLOP) / 0.1, 0.0, 1.0) * PI)
	var pos := at + off
	pos.y = maxf(pos.y, 0.45)
	# kept in the picture even while the camera is catching up with a dash (let go as it takes the ride's place)
	pos = pos.lerp(_in_view(pos, 0.75, 0.0), 1.0 - rise)
	var level := Basis(Vector3.RIGHT, 0.12 * (1.0 - a))
	var world := Transform3D(level.slerp(ride.global_basis.orthonormalized(), rise), pos)
	car.transform = ride.global_transform.affine_inverse() * world
	car.visible = true
	car.motion(Vector2.ZERO, 1.0 - a * 0.7)
	var seat := world * Vector3(0, SEAT - 0.5, 0)   # where a seated pilot's feet-origin goes
	var up := world.basis.y
	# the pilot: reaches down, then (2) is pulled down in a short arc into the seat, then (5) sinks in as the canopy shuts
	var pilot: Node3D = run.pilot
	var p_in := "R" if _side > 0 else "L"
	var psh := pilot.get_node("Hip/Torso/Shoulder" + p_in) as Node3D
	var pull := smoothstep(GRAB, PLOP, p)
	var shut := smoothstep(SHUT.x, SHUT.y, p)
	if pull > 0.0:
		var from := at
		var mid := Vector3(seat.x, at.y - 0.15, (at.z + seat.z) * 0.5)
		var k := pull * pull
		var root := from.lerp(mid, k).lerp(mid.lerp(seat, k), k) - up * 0.3 * shut
		pilot.transform = ride.global_transform.affine_inverse() * Transform3D(world.basis, root)
		(pilot.get_node("Hip") as Node3D).rotation *= 1.0 - pull
		_sit(pilot, pull)
	pilot.visible = shut < 0.5
	# 3. the friend: waves at the wheel, reaches up and grabs, then lets go and pops out of the other side
	if p < LET_GO:
		friend.global_transform = Transform3D(world.basis, seat)
		_sit(friend, 1.0)
		var reach := smoothstep(0.25, GRAB, p)
		(friend.get_node("Hip/Torso") as Node3D).rotation = Vector3(-0.1, 0, _side * 0.3 * reach)
		var f_in := "L" if _side > 0 else "R"
		var f_out := "R" if _side > 0 else "L"
		var fsh_out := friend.get_node("Hip/Torso/Shoulder" + f_out) as Node3D
		_aim(fsh_out, fsh_out.global_position + up * 0.45 + world.basis.x * _side * (0.25 + 0.15 * sin((t - _t0) * 16.0)))
		var fsh := friend.get_node("Hip/Torso/Shoulder" + f_in) as Node3D
		var meet := fsh.global_position.lerp(psh.global_position, 0.5)
		_aim(fsh, (fsh.global_position - world.basis.z * 0.4 - up * 0.15).lerp(meet, reach))
		_aim(psh, meet, smoothstep(0.3, GRAB, p), false)
		if p >= GRAB and not _grabbed:
			_grabbed = true
			_grab_t = t
			_grab_off = meet - at
			run.fx.catch(meet, 1)
	elif _pop_t == INF:
		_pop_t = t
		_pop_from = friend.global_position - at
	# 5. the canopy swings shut over the pilot
	_canopy(shut * shut)


func _away(e: float) -> void:
	## the friend pops out on their jetpack, turns to wave at you, then drops back out of the bottom corner
	if e > WAVE + AWAY:
		friend.visible = false
		return
	var at: Vector3 = run.ride.global_position
	# the hover spot stays low in the picture (below where the rings ahead are) and inside its edges
	var hover := _in_view(at + Vector3(_side * HOVER.x, HOVER.y + 0.04 * sin(e * 12.0), HOVER.z), 0.5, 0.48)
	var k := smoothstep(0.0, 0.18, e)
	var pos := (at + _pop_from).lerp(hover, k) + Vector3(0, 0.3 * sin(k * PI), 0)
	var x := maxf(0.0, e - WAVE)
	pos += Vector3(_side * 6.0 * x * x, -2.5 * x * x, 40.0 * x * x)
	friend.global_transform = Transform3D(Basis(Vector3.UP, _side * PI * smoothstep(0.05, 0.2, e)), pos)
	(friend.get_node("Hip") as Node3D).rotation = Vector3(-0.2, 0, 0)
	(friend.get_node("Hip/Torso") as Node3D).rotation = Vector3.ZERO
	_sit(friend, 1.0 - k)
	# the arm away from the car waves, the other is out for balance
	var right := friend.global_basis.x
	for s in ["L", "R"]:
		var sh := friend.get_node("Hip/Torso/Shoulder" + s) as Node3D
		var out := right * (-1.0 if s == "L" else 1.0)
		var waving := out.dot(Vector3(-_side, 0, 0)) < 0.0
		var to := Vector3.UP * 0.45 + out * (0.25 + 0.18 * sin(e * 24.0)) if waving else out * 0.4 - Vector3.UP * 0.25
		_aim(sh, sh.global_position + to)
	_flames(friend, 1.8 + 0.15 * sin(e * 40.0))


func _in_view(pos: Vector3, side_room: float, below: float) -> Vector3:
	## a place moved into the camera's picture: at least side_room (m) in from its left and right edges and, when
	## below > 0, at least that share of the half-height under its middle (under the rings ahead)
	var cam: Camera3D = run.camera
	var l := cam.global_transform.affine_inverse() * pos
	var depth := -l.z
	if depth < 1.0:
		return pos
	var tv := tan(deg_to_rad(cam.fov * 0.5))
	var size := cam.get_viewport().get_visible_rect().size
	var w := maxf(0.0, depth * tv * size.x / size.y - side_room)
	l.x = clampf(l.x, -w, w)
	if below > 0.0:
		l.y = clampf(l.y, -depth * tv * 0.85, -depth * tv * below)
	return cam.global_transform * l


func _canopy(shut: float) -> void:
	## the canopy open (0) or shut (1); shut, the car's own canopy is back
	if _hinge == null:
		return
	var body := car.get_node("Body") as MeshInstance3D
	_hinge.visible = shut < 1.0
	_hinge.rotation.x = -OPEN * (1.0 - shut)
	body.set_surface_override_material(_glass_i, _clear if shut < 1.0 else null)


func _stop() -> void:
	_on = false
	_at = INF
	_pop_t = INF
	_grab_t = INF
	friend.visible = false
	_flash.visible = false
	car.transform = Transform3D()
	_canopy(1.0)
	run.pilot.transform = Transform3D()


static func _sit(p: Node3D, k: float) -> void:
	## a pilot's legs from flying (k 0: trailing a little) to sitting (k 1: thighs forward, shins down)
	for s in ["L", "R"]:
		var o := 0.1 if s == "R" else -0.1
		(p.get_node("Hip/Leg" + s) as Node3D).rotation = Vector3(0.3, 0, o * 0.5).lerp(Vector3(1.5, 0, o), k)
		(p.get_node("Hip/Leg%s/Knee" % s) as Node3D).rotation = Vector3(0.6, 0, 0).lerp(Vector3(-1.4, 0, 0), k)


static func _aim(joint: Node3D, at: Vector3, k := 1.0, stretch := true) -> void:
	## points an arm (it hangs along -Y from its shoulder) straight at a place in the world, k of the way from where it
	## is; stretched a little if it falls short (only the friend's: the player's pilot keeps its size)
	var d: Vector3 = joint.get_parent_node_3d().global_transform.affine_inverse() * at - joint.position
	var l := d.length()
	if l < 0.01:
		return
	var dir := d / l
	if dir.dot(Vector3.DOWN) < -0.999:
		dir = (dir + Vector3(0.01, 0, 0)).normalized()
	var to := Basis(Quaternion(Vector3.DOWN, dir))
	if stretch:
		joint.basis = to * Basis.from_scale(Vector3(1, clampf(l / ARM, 0.85, 1.7), 1))
	else:
		joint.basis = joint.basis.orthonormalized().slerp(to, k)
	var elbow := joint.get_node_or_null("Elbow") as Node3D
	if elbow:
		elbow.basis = elbow.basis.orthonormalized().slerp(Basis(), k)


static func _flames(p: Node3D, k: float) -> void:
	for f in p.find_children("Flame*", "", true, false):
		(f as Node3D).scale = Vector3(1.3, 1.3, maxf(0.01, k)) if k > 0.05 else Vector3.ONE * 0.01
