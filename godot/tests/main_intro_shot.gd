extends Node
## Plays the studio intro inside the main scene, as on a first launch, and saves frames: OUT=/dir SHOTS="1.0,2.2,3.0"
## Prints which camera is drawing at each frame (it must be the intro's until the intro ends), then a frame of the menu.

func _ready() -> void:
	get_tree().create_timer(200.0).timeout.connect(get_tree().quit.bind(1))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	var intro: Node = main.get_node("Intro")
	var ev := InputEventMouseButton.new()
	ev.pressed = true
	ev.button_index = MOUSE_BUTTON_LEFT
	intro._unhandled_input(ev)
	var bad := 0
	for s in OS.get_environment("SHOTS").split(","):
		while intro.get_node("AnimationPlayer").current_animation_position < float(s):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var cam := get_viewport().get_camera_3d()
		var ok := cam == intro.get_node("Camera3D")
		bad += 0 if ok else 1
		print("t=%s camera %s %s" % [s, cam.get_path() if cam else "none", "ok" if ok else "WRONG"])
		get_viewport().get_texture().get_image().save_png("%s/main_intro_%s.png" % [OS.get_environment("OUT"), s])
	while is_instance_valid(intro):
		await get_tree().process_frame
	for i in 90:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	print("after intro camera ", get_viewport().get_camera_3d().get_path())
	get_viewport().get_texture().get_image().save_png("%s/main_intro_menu.png" % OS.get_environment("OUT"))
	print("RESULT ", "FAIL" if bad else "PASS")
	get_tree().quit()
