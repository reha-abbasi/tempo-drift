extends Node
## Opens the garage in an era and photographs the showroom camera at four points round the car (ahead, side,
## straight back, other side), so the street and the landmark behind the car can be checked:
##   MAP=old OUT=/dir [ANGLES=180]  (run with --fixed-fps so the camera turns the same each time)

func _ready() -> void:
	get_tree().create_timer(400.0).timeout.connect(get_tree().quit.bind(1))
	var map := OS.get_environment("MAP") if OS.get_environment("MAP") != "" else "old"
	Save.data.map = map
	(load("res://scripts/main.gd") as GDScript).set("Intro_seen", true)
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().create_timer(2.5).timeout
	var menus = main.get_node("Menus")
	menus.visible = true
	menus.get_node("%Gift").visible = false
	menus.open("Garage")
	await get_tree().create_timer(1.0).timeout
	var run: Node = main.backdrop
	var angles := [0, 90, 180, 270]
	if OS.get_environment("ANGLES") != "":
		angles = Array(OS.get_environment("ANGLES").split(",")).map(func(a): return int(a))
	for deg in angles:
		# the camera's angle round the car is garage_angle + t * 0.3: hold it at deg for the shot
		for f in 45:
			run.garage_angle = deg_to_rad(deg) - run.rules.t * 0.3
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/garage_%s_%03d.png" % [OS.get_environment("OUT"), map, deg])
		print("shot %s %d  sections %d  behind %.0f" % [map, deg, run.city.street.get_child_count(), run.city.behind])
	get_tree().quit()
