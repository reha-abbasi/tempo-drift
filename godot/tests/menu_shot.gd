extends Node
## Opens the main scene and photographs each menu: OUT=/dir SCREENS="Home,Eps,Garage"

func _ready() -> void:
	get_tree().create_timer(300.0).timeout.connect(get_tree().quit.bind(1))
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
		get_viewport().get_texture().get_image().save_png("%s/menu_%s.png" % [OS.get_environment("OUT"), s])
		print("shot ", s)
	get_tree().quit()
