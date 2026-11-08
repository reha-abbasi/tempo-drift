extends Node3D
## A pilot's pose: flying on the jetpack (legs trailing, arms out for balance, leaning into each swipe) or standing
## in the garage. The joints are nodes in the pilot's scene (Hip, Torso, Head, Shoulder*, Elbow, Leg*, Knee).

var flying := true
var _t := 0.0


func lean(vx: float, vy: float) -> void:
	## vx, vy: the pilot's sideways and vertical speed (m/s)
	_t += get_process_delta_time()
	var hip: Node3D = $Hip
	var torso: Node3D = $Hip/Torso
	if not flying:
		hip.rotation = Vector3.ZERO
		torso.rotation = Vector3(0, 0, sin(_t * 1.6) * 0.03)
		for s in ["L", "R"]:
			_joint("Hip/Torso/Shoulder" + s, Vector3(0.1, 0, (-0.12 if s == "L" else 0.12)))
			_joint("Hip/Torso/Shoulder%s/Elbow" % s, Vector3(-0.3, 0, 0))
			_joint("Hip/Leg" + s, Vector3.ZERO)
			_joint("Hip/Leg%s/Knee" % s, Vector3.ZERO)
		return
	# leaning forward in flight, banking into the swipe
	hip.rotation = Vector3(-0.35 - clampf(vy, -6, 6) * 0.03, 0, clampf(-vx * 0.06, -0.5, 0.5))
	torso.rotation = Vector3(0.1, 0, 0)
	var sway := sin(_t * 3.0) * 0.08
	_joint("Hip/Torso/ShoulderL", Vector3(0.2 + sway, 0, -0.7))
	_joint("Hip/Torso/ShoulderR", Vector3(0.2 - sway, 0, 0.7))
	_joint("Hip/Torso/ShoulderL/Elbow", Vector3(-0.5, 0, 0))
	_joint("Hip/Torso/ShoulderR/Elbow", Vector3(-0.5, 0, 0))
	_joint("Hip/LegL", Vector3(0.35 + sway, 0, 0.05))
	_joint("Hip/LegR", Vector3(0.25 - sway, 0, -0.05))
	_joint("Hip/LegL/Knee", Vector3(0.5, 0, 0))
	_joint("Hip/LegR/Knee", Vector3(0.7, 0, 0))
	var thrust := 0.9 + maxf(vy, 0.0) * 0.1 + 0.08 * sin(_t * 40.0)
	for f in find_children("Flame*", "", true, false):
		(f as Node3D).scale = Vector3(1, 1, thrust)


func _joint(path: String, rot: Vector3) -> void:
	var n := get_node_or_null(path) as Node3D
	if n:
		n.rotation = n.rotation.lerp(rot, 0.25)
