extends Node
## Flies every episode's and Flight School's course with the autopilot, headless, and checks the rules port: a perfect flight plays
## every note, never crashes and reaches the finish. godot --headless --path godot res://tests/rules_sim.tscn
var failures := 0

func _ready() -> void:
	for f in DirAccess.get_files_at("res://data"):
		# the episodes' and Flight School's courses (Endless loops for 322 bars: too long to fly here)
		if not f.ends_with(".json") or f.begins_with("endless_"):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/" + f))
		if not (parsed is Dictionary and parsed.has("notes")):
			continue
		var c: Dictionary = parsed
		var r := Rules.new()
		r.load_course(c)
		r.autopilot = true
		r.autopilot_lead = float(OS.get_environment("LEAD")) if OS.get_environment("LEAD") != "" else 0.5
		var t := 0.0
		while not r.done and t < r.gate + 10.0:
			t += 1.0 / 60.0
			r.step(t)
		var ok: bool = r.J.m == 0 and r.lost == 0 and r.done
		if not ok:
			failures += 1
		print("%-14s %-16s notes %3d/%3d  crashes %d  ex %3d  gd %3d  ok %3d  score %6d  od %d  %s" % [f.get_basename(), c.name, r.J.c, r.notes.size(), r.lost, r.J.ex, r.J.gd, r.J.ok, r.score, r.od_n, "ok" if ok else "FAIL"])
	print("FAILURES: %d" % failures)
	get_tree().quit(1 if failures else 0)
