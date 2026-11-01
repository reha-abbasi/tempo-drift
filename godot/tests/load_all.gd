extends SceneTree
## Loads and instances every scene in the project; prints any that fail.

func _init() -> void:
	var bad := 0
	var n := 0
	var stack := ["res://scenes"]
	while not stack.is_empty():
		var d: String = stack.pop_back()
		for sub in DirAccess.get_directories_at(d):
			stack.append(d + "/" + sub)
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".tscn"):
				n += 1
				var ps := load(d + "/" + f) as PackedScene
				var inst = ps.instantiate() if ps else null
				if inst == null:
					bad += 1
					print("FAILED ", d + "/" + f)
				else:
					inst.free()
	print("%d scenes, %d failed" % [n, bad])
	quit()
