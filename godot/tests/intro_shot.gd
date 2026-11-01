extends Node
## Plays the studio intro and saves frames: OUT=/dir SHOTS="1.0,2.2,3.0"

func _ready() -> void:
	get_tree().create_timer(120.0).timeout.connect(get_tree().quit.bind(1))
	var intro: Node = (load("res://scenes/intro/intro.tscn") as PackedScene).instantiate()
	add_child(intro)
	await get_tree().process_frame
	var ev := InputEventMouseButton.new()
	ev.pressed = true
	ev.button_index = MOUSE_BUTTON_LEFT
	intro._unhandled_input(ev)
	for s in OS.get_environment("SHOTS").split(","):
		while intro.get_node("AnimationPlayer").current_animation_position < float(s):
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/intro_%s.png" % [OS.get_environment("OUT"), s])
	get_tree().quit()
