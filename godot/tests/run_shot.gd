extends Node
## Plays an episode with the autopilot and saves frames: MAP=old EP=0 SHOTS="6,12,20" OUT=/dir LEAD=0.13

var run: Node
var shots: Array = []
var out := ""


func _ready() -> void:
	get_tree().create_timer(600.0).timeout.connect(get_tree().quit.bind(1))
	Launch.episode(OS.get_environment("MAP") if OS.get_environment("MAP") != "" else "old", int(OS.get_environment("EP")))
	if OS.get_environment("MODE") != "":
		Launch.mode = OS.get_environment("MODE")
	for s in OS.get_environment("SHOTS").split(","):
		shots.append(float(s))
	out = OS.get_environment("OUT")
	run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(run)
	await get_tree().process_frame
	get_tree().current_scene = run
	await get_tree().process_frame
	run.rules.autopilot = true
	run.rules.autopilot_lead = float(OS.get_environment("LEAD")) if OS.get_environment("LEAD") != "" else 0.13


func _process(_d: float) -> void:
	if run == null or not run.music.playing or shots.is_empty():
		return
	var t: float = run.music.song_time()
	if t >= shots[0]:
		var at: float = shots.pop_front()
		match OS.get_environment("DIAG"):
			"noshadow":
				run.city.get_node("Sun").shadow_enabled = false
			"nocity":
				run.city.get_node("Street").visible = false
			"nohorizon":
				run.city.get_node("Horizon").visible = false
			"norings":
				run.get_node("Rings").visible = false
			"noglow":
				run.city.get_node("WorldEnvironment").environment.glow_enabled = false
		if OS.get_environment("DIAG") != "":
			for i in 3:
				await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/run_%05.1f.png" % [out, at])
		print("shot %.1f score %d combo %d flow %.0f form %d" % [t, run.rules.score, run.rules.combo, run.rules.flow, run.rules.form])
		print("  draw calls %d · objects %d · triangles %dk · lights in view %d" % [Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME) / 1000, get_tree().root.find_children("*", "Light3D", true, false).size()])
		if shots.is_empty():
			get_tree().quit()
