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
	menus.visible = true
	menus.get_node("%Gift").visible = false
	for s in OS.get_environment("SCREENS").split(","):
		# "Pilots": the garage's pilots tab
		if s == "Pilots":
			menus.get_node("%GtPilots").pressed.emit()
		else:
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
		print("shot ", s, " camera ", cam.get_path() if cam else "none", " · draw calls ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " · triangles ", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000, "k")
	# DIAG=1: what the rooftop's draw calls come from (each part hidden in turn)
	if OS.get_environment("DIAG") != "" and main.rooftop:
		var w: Node3D = main.rooftop.get_node("World")
		for part in w.get_children() + main.rooftop.city.get_children():
			if not part is Node3D or not (part as Node3D).visible:
				continue
			(part as Node3D).visible = false
			for f in 3:
				await get_tree().process_frame
			print("  without %-16s draw calls %d" % [part.name, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
			(part as Node3D).visible = true
	get_tree().quit()
