class_name PilotAnim
extends RefCounted
## Brings the jetpack pilot to life. Every joint is a small spring pulled toward a pose: the body leads and the limbs
## follow a moment later and settle, so a dodge swings the legs out behind and the arms balance it. The legs kick
## lazily to stay up, the chest breathes, and the head looks where you're going and nods to the beat.

# how stiff each joint is and how quickly it settles: the spine is firm, the legs hang loose
const SPRING := {"spine": [140.0, 16.0], "neck": [170.0, 17.0], "shoulder": [70.0, 9.0], "elbow": [95.0, 11.0],
	"hip": [38.0, 5.5], "knee": [55.0, 7.0]}

var j := {}           # joint name -> {n, base, a, v, k, d}
var last := Vector2.ZERO
var acc := Vector2.ZERO

func _init(pilot: Node3D) -> void:
	var joints: Dictionary = pilot.get_meta("joints")
	for name in joints:
		var n: Node3D = joints[name]
		var kd: Array = SPRING[name.get_slice("_", 0)]
		j[name] = {"n": n, "base": n.rotation, "a": Vector3.ZERO, "v": Vector3.ZERO, "k": kd[0], "d": kd[1]}

## vel: the pilot's sideways and up-down speed; pulse: the beat (1 on it, falling to 0); tumble: 1 while thrown
## out of a wreck, when the arms and legs fly out
func update(vel: Vector2, t: float, pulse: float, tumble: float, dt: float) -> void:
	if dt <= 0.0:
		return
	# the acceleration, smoothed a little (the moves start and stop sharply)
	acc = acc.lerp((vel - last) / dt, clampf(dt * 20.0, 0.0, 1.0))
	last = vel
	var ax := clampf(acc.x, -80.0, 80.0)
	var ay := clampf(acc.y, -80.0, 80.0)
	var vx := vel.x
	var vy := vel.y
	var breathe := sin(t * 2.1)
	var kick := t * 2.6
	var nod := pulse * pulse
	var tgt := {}
	var push := {}
	# the spine leans a touch further into the move than the jetpack does, and curls on a climb
	tgt.spine = Vector3(-vy * 0.025 + breathe * 0.015, 0, -vx * 0.03)
	# the head stays nearly level, turns toward where you're heading and nods on the beat
	tgt.neck = Vector3(0.14 * nod - vy * 0.02 + 0.03 * sin(t * 1.3), -vx * 0.07, vx * 0.035)
	for sx in [-1.0, 1.0]:
		var sd := "l" if sx < 0.0 else "r"
		var ph := 0.0 if sx < 0.0 else PI
		# the arms: they swing away from a dodge and settle, and the grips pump a little on the beat
		tgt["shoulder_" + sd] = Vector3(breathe * 0.04 - vy * 0.02, 0, -vx * 0.03)
		push["shoulder_" + sd] = Vector3(ay * 0.002, 0, -ax * 0.004)
		tgt["elbow_" + sd] = Vector3(0.1 * nod, 0, 0)
		# the legs: a lazy flutter kick, swung out behind a dodge, trailing on a climb and lifting on a drop
		tgt["hip_" + sd] = Vector3(sin(kick + ph) * 0.13 - absf(vx) * 0.015, 0, -vx * 0.04)
		push["hip_" + sd] = Vector3(ay * 0.004, 0, -ax * 0.005)
		tgt["knee_" + sd] = Vector3(sin(kick + ph - 1.1) * 0.16 - 0.04, 0, 0)
		push["knee_" + sd] = Vector3(-ay * 0.003, 0, 0)
		if tumble > 0.0:
			# thrown clear: arms flung up and out, legs splayed
			tgt["shoulder_" + sd] = tgt["shoulder_" + sd].lerp(Vector3(-1.2, 0, sx * 1.1), tumble)
			tgt["elbow_" + sd] = tgt["elbow_" + sd].lerp(Vector3(-0.3, 0, 0), tumble)
			tgt["hip_" + sd] = tgt["hip_" + sd].lerp(Vector3(0.4, 0, sx * 0.5), tumble)
			tgt["knee_" + sd] = tgt["knee_" + sd].lerp(Vector3(-0.8, 0, 0), tumble)
	if tumble > 0.0:
		tgt.neck = tgt.neck.lerp(Vector3(-0.35, 0, 0), tumble)
	# (a slow frame is stepped in pieces, so the stiff springs stay steady)
	var steps := int(ceil(dt / (1.0 / 90.0)))
	var h := dt / steps
	for name in j:
		var s: Dictionary = j[name]
		var target: Vector3 = tgt.get(name, Vector3.ZERO)
		# (a push of p holds the joint p radians off its pose for as long as it lasts)
		var force: Vector3 = push.get(name, Vector3.ZERO) * s.k
		for k in steps:
			s.v += ((target - s.a) * s.k + force - s.v * s.d) * h
			s.a += s.v * h
		s.a = s.a.clamp(Vector3(-1.4, -1.0, -1.4), Vector3(1.4, 1.0, 1.4))
		s.n.rotation = s.base + s.a
