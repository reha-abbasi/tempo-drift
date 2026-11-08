extends Node
## Plays Rio up to its first banners, reloads the run as Retry does, and plays it again: the banners must be there
## both times (hung, with their artwork and their masts). godot --path godot res://tests/replay_check.tscn


class Checker extends Node:
	var round := 0
	var bad := 0

	func _ready() -> void:
		get_tree().create_timer(600.0).timeout.connect(get_tree().quit.bind(1))
		_play()

	func _play() -> void:
		Launch.episode("sunset", 1)
		get_tree().change_scene_to_file("res://scenes/run/run.tscn")
		# the first time the car flies into the first banner (it sits in the middle lane, where the car starts);
		# the second time, after the retry, it flies past
		var crash_first := OS.get_environment("CRASH") != ""
		while true:
			await get_tree().process_frame
			var r := get_tree().current_scene
			if r and r.get("rules"):
				r.rules.autopilot = not (crash_first and round == 0)
				if r.rules.t > (8.0 if crash_first and round == 0 else 6.6):
					break
		var run := get_tree().current_scene
		print("round %d: crashes %d" % [round, run.rules.lost])
		var n := 0
		var ok := 0
		for v in run.get_node("Traffic").get_children():
			if v is StreetBanner:
				n += 1
				var m := (v.get_node("Hang/Cloth") as MeshInstance3D).material_override as ShaderMaterial
				var art = m.get_shader_parameter("art") if m else null
				var rig := v.get_node("Rig") as MeshInstance3D
				var good: bool = v.is_visible_in_tree() and art != null and rig.mesh != null and not v.is_struck()
				ok += 1 if good else 0
				print("  round %d banner at z %.0f  visible %s  art %s  rig %s" % [round, v.global_position.z, v.is_visible_in_tree(), art != null, rig.mesh != null])
		print("round %d: %d banners near, %d hung properly" % [round, n, ok])
		if n == 0 or ok < n:
			bad += 1
		round += 1
		if round < 2:
			_play()
		else:
			print("RESULT ", "PASS" if bad == 0 else "FAIL")
			get_tree().quit(1 if bad else 0)


func _ready() -> void:
	Save.data.settings.fx_low = false
	get_tree().root.add_child.call_deferred(Checker.new())
