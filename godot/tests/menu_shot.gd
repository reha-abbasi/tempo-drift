extends Node
## Opens the main scene and photographs each menu: OUT=/dir SCREENS="Home,Eps,Garage" [MAP=old]

func _ready() -> void:
	get_tree().create_timer(300.0).timeout.connect(get_tree().quit.bind(1))
	# (straight to the menus: the intro is skipped, as after a first launch)
	(load("res://scripts/main.gd") as GDScript).set("Intro_seen", true)
	if OS.get_environment("MAP") != "":
		Save.data.map = OS.get_environment("MAP")
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(main)
	await get_tree().create_timer(2.5).timeout
	var menus = main.get_node("Menus")
	if main.has_node("Intro"):
		main.get_node("Intro").queue_free()
	menus.visible = true
	menus.get_node("%Gift").visible = false
	for s in OS.get_environment("SCREENS").split(","):
		menus.open(s)
		if s == "Home":
			menus.get_node("%Gift").visible = false
		await get_tree().create_timer(2.0).timeout
		await RenderingServer.frame_post_draw
		var n := 1
		while FileAccess.file_exists("%s/menu_%s%s.png" % [OS.get_environment("OUT"), s, "" if n == 1 else str(n)]):
			n += 1
		get_viewport().get_texture().get_image().save_png("%s/menu_%s%s.png" % [OS.get_environment("OUT"), s, "" if n == 1 else str(n)])
		var cam := get_viewport().get_camera_3d()
		print("shot ", s, " camera ", cam.get_path() if cam else "none")
	get_tree().quit()
