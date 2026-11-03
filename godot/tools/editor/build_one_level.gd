extends RefCounted
## Rebuilds one episode's level scene from its baked course (build_levels does them all):
##   LEVEL="sunset 1" godot --headless --path godot res://tools/editor/runner.tscn -- build_one_level


func build(_host: Node) -> void:
	var a := OS.get_environment("LEVEL").split(" ")
	var map := a[0]
	var i := int(a[1])
	for e in Catalog.episodes(map):
		if e.i == i:
			load("res://tools/editor/build_levels.gd").new().level(map, i, e.name, e.course, e.audio, false)
			print("built ", map, "_", i)
