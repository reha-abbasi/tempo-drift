extends Node
## Reads every level scene back as a course and compares it with the baked course it was laid out from:
## the same notes (time, lane, height, swipe, power-up, lesson wait, recording layer) and the same traffic.

func _ready() -> void:
	var bad := 0
	var files := []
	for m in Catalog.MAPS:
		for i in 8:
			files.append("%s_%d" % [m, i])
		files.append("school_" + m)
	for f in files:
		var lv := (load("res://scenes/levels/%s.tscn" % f) as PackedScene).instantiate() as Level
		var c := lv.course()
		var j: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(lv.course_file))
		var errs := []
		if c.notes.size() != j.notes.size():
			errs.append("note count %d vs %d" % [c.notes.size(), j.notes.size()])
		else:
			for k in j.notes.size():
				var a: Dictionary = c.notes[k]
				var b: Dictionary = j.notes[k]
				if absf(float(a.t) - float(b.t)) > 0.001:
					errs.append("note %d time %s vs %s" % [k, a.t, b.t])
				for key in ["col", "row", "note", "len"]:
					if int(a[key]) != int(b[key]):
						errs.append("note %d %s %s vs %s" % [k, key, a[key], b[key]])
				for key in ["dir", "pu", "wait"]:
					if str(a.get(key, "")) != str(b.get(key, "")):
						errs.append("note %d %s '%s' vs '%s'" % [k, key, a.get(key, ""), b.get(key, "")])
				if bool(a.mv) != bool(b.mv) or a.has("layer") != b.has("layer") or int(a.get("layer", 0)) != int(b.get("layer", 0)):
					errs.append("note %d mv/layer" % k)
		if c.hazards.size() != j.hazards.size():
			errs.append("hazard count")
		else:
			for k in j.hazards.size():
				var a: Dictionary = c.hazards[k]
				var b: Dictionary = j.hazards[k]
				if absf(float(a.t) - float(b.t)) > 0.001 or int(a.col) != int(b.col) or int(a.row) != int(b.row) or a.kind != b.kind or bool(a.over) != bool(b.over) or bool(a.under) != bool(b.under):
					errs.append("hazard %d" % k)
		print("%-14s %3d notes %3d hazards %3d street sections  %s" % [f, c.notes.size(), c.hazards.size(), lv.get_node("Street").get_child_count(), "ok" if errs.is_empty() else "DIFFERS: " + ", ".join(errs.slice(0, 4))])
		bad += 0 if errs.is_empty() else 1
		lv.free()
	print("RESULT ", "PASS" if bad == 0 else "FAIL (%d levels)" % bad)
	get_tree().quit(1 if bad else 0)
