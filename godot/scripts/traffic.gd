@tool
extends Node3D
## A vehicle in the flight grid: painted in its city's colours, bobbing if it flies, spinning its rotors and
## propellers (the "spin" group), knocked aside when the car hits it.

@export var bob := 0.06
var _struck := false
var _t := 0.0
var _vel := Vector3.ZERO
var _rot := Vector3.ZERO
@onready var body: MeshInstance3D = get_node_or_null("Body")


func _ready() -> void:
	_t = randf() * 10.0


func paint(c: Color) -> void:
	if body == null:
		return
	for i in body.mesh.get_surface_count():
		var mat := body.mesh.surface_get_material(i)
		if mat and mat.resource_path.ends_with("traffic_paint.tres"):
			var p: StandardMaterial3D = mat.duplicate()
			p.albedo_color = c
			body.set_surface_override_material(i, p)


func struck(from: Vector3) -> void:
	_struck = true
	var away := signf(global_position.x - from.x)
	if away == 0.0:
		away = 1.0 if randf() < 0.5 else -1.0
	_vel = Vector3(away * 6.0, 5.0, -6.0)
	_rot = Vector3(randf_range(-3, 3), randf_range(-4, 4), away * 5.0)


func is_struck() -> bool:
	return _struck


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_t += delta
	for n in get_tree().get_nodes_in_group("spin"):
		if is_ancestor_of(n):
			(n as Node3D).rotate_y(35.0 * delta)
	if _struck:
		position += _vel * delta
		_vel.y -= 18.0 * delta
		rotation += _rot * delta
	elif body and bob > 0.0 and body.position.y == 0.0:
		body.position.y = 0.0
		position.y += sin(_t * 1.8) * bob * delta
