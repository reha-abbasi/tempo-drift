extends Skeleton3D
## A sculpted pilot's one-piece body bends with the joints the game poses (Hip, Torso, Head, Shoulder*, Elbow, Leg*,
## Knee: plain nodes in the pilot's scene): each joint is copied onto its bone every frame.

@export var paths: PackedStringArray

var _joints: Array[Node3D] = []


func _ready() -> void:
	process_priority = 100
	var root := get_parent()
	for p in paths:
		_joints.append(root.get_node(p) as Node3D)


func _process(_delta: float) -> void:
	for i in _joints.size():
		set_bone_pose_position(i, _joints[i].position)
		set_bone_pose_rotation(i, _joints[i].quaternion)
