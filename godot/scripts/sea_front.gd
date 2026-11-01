@tool
extends Node3D
## The promenade along an open side of the street, and the sea beyond it.

@export var sea_color := Color(0.16, 0.35, 0.54):
	set(v):
		sea_color = v
		_paint()


func _ready() -> void:
	_paint()


func _paint() -> void:
	var sea := get_node_or_null("Sea") as MeshInstance3D
	if sea == null:
		return
	var m := StandardMaterial3D.new()
	m.albedo_color = sea_color
	m.metallic = 0.3
	m.roughness = 0.12
	sea.material_override = m
