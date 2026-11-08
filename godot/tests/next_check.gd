extends Node
## The results screen's Next goes to the next open city, era by era, round to the first after the last.
## godot --headless --path godot res://tests/next_check.tscn

func _ready() -> void:
	var bad := 0
	var open := []
	for m in Catalog.MAPS:
		for k in 8:
			if Save.unlocked(m, k):
				open.append("%s_%d" % [m, k])
	print("open cities in order: ", open)
	for j in open.size():
		var parts: PackedStringArray = open[j].split("_")
		var n := Save.next_open(parts[0], int(parts[1]))
		var want: String = open[(j + 1) % open.size()]
		var got := "%s_%d" % [n.get("map", "?"), int(n.get("i", -1))]
		var ok := got == want and (open.size() > 1)
		bad += 0 if ok else 1
		print("after %-9s next %-9s %s" % [open[j], got, "ok" if ok else "WRONG (want %s)" % want])
	var first := Save.next_open("sunset", -1)
	var ok_first: bool = "%s_%d" % [first.get("map"), int(first.get("i"))] == open[0]
	bad += 0 if ok_first else 1
	print("from nowhere      next %s_%d %s" % [first.get("map"), int(first.get("i")), "ok" if ok_first else "WRONG"])
	print("RESULT ", "PASS" if bad == 0 else "FAIL")
	get_tree().quit(1 if bad else 0)
