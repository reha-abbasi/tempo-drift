extends Node3D
## Renders a city from the run camera: CITY=old_0 SHOT=/path.png (Z = how far along the street).

func _ready() -> void:
	get_tree().create_timer(400.0).timeout.connect(get_tree().quit.bind(1))
	var id := OS.get_environment("CITY")
	var c: City = (load("res://scenes/cities/%s.tscn" % id) as PackedScene).instantiate()
	add_child(c)
	var z := -float(OS.get_environment("Z")) if OS.get_environment("Z") != "" else -30.0
	c.follow(z)
	for kind in ["oldcar", "taxi", "drone", "biplane"]:
		var v: Node3D = c.vehicle(kind, 1)
		if v:
			v.position = Vector3(2.24, 0.84, z - 26)
			add_child(v)
			break
	var car := (load("res://scenes/cars/arrow.tscn") as PackedScene).instantiate() as Node3D
	car.position = Vector3(0, 0.84, z)
	add_child(car)
	var cam := Camera3D.new()
	cam.fov = 62
	cam.far = 900
	cam.position = Vector3(0, 6.02, z + 10.08)
	add_child(cam)
	cam.look_at(Vector3(0, 2.24, z - 6))
	cam.current = true
	for i in 12:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT"))
	get_tree().quit()
