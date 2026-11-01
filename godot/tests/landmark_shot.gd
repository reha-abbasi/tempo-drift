extends Node3D
## A landmark alone in its city's light, seen from 200 m: LM=paris CITY=old_2 SHOT=/path.png

func _ready() -> void:
	get_tree().create_timer(200.0).timeout.connect(get_tree().quit.bind(1))
	var c: Node3D = (load("res://scenes/cities/%s.tscn" % OS.get_environment("CITY")) as PackedScene).instantiate()
	for n in c.get_children():
		if n.name == "Street" or n.name == "Horizon":
			n.free()
	add_child(c)
	var lm: Node3D = (load("res://scenes/landmarks/%s.tscn" % OS.get_environment("LM")) as PackedScene).instantiate()
	add_child(lm)
	var cam := Camera3D.new()
	cam.fov = 50
	cam.far = 2000
	cam.position = Vector3(0, 30, 230)
	add_child(cam)
	cam.look_at(Vector3(0, 40, 0))
	for i in 10:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT"))
	get_tree().quit()
