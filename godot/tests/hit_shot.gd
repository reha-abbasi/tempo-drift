extends Node
## Flies into a street banner and saves frames through the hit: the cable snapping, the cloth wrapping the car,
## the pilot thrown out. MAP=sunset EP=1 TIMES="6.9,7.1,7.3,7.6,8.0" OUT=/dir (game time, autopilot off)

func _ready() -> void:
	get_tree().create_timer(500.0).timeout.connect(get_tree().quit.bind(1))
	Launch.episode(OS.get_environment("MAP") if OS.get_environment("MAP") != "" else "sunset", int(OS.get_environment("EP")) if OS.get_environment("EP") != "" else 1)
	var run: Node = (load("res://scenes/run/run.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(run)
	await get_tree().process_frame
	get_tree().current_scene = run
	var times := Array(OS.get_environment("TIMES").split(",")).map(func(v): return float(v))
	for at in times:
		while run.rules.t < at:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/hit_%05.2f.png" % [OS.get_environment("OUT"), at])
		print("shot %.2f form %d lost %d" % [run.rules.t, run.rules.form, run.rules.lost])
	get_tree().quit()
