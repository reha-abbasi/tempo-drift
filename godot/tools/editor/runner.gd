extends Node
## Runs scene builders inside a normal game start (so autoloads such as Game exist):
##   godot --headless --path godot res://tools/editor/runner.tscn -- build_props build_cities ...
## Each builder is tools/editor/<name>.gd with a `build(host: Node)` function.


func _ready() -> void:
	# a builder that fails to load would leave the run hanging: give up after a while
	get_tree().create_timer(900.0).timeout.connect(get_tree().quit.bind(1))
	for name in OS.get_cmdline_user_args():
		var script: GDScript = load("res://tools/editor/%s.gd" % name)
		if script == null or not script.can_instantiate() or script.new() == null:
			printerr("BUILDER FAILED TO LOAD: ", name)
			get_tree().quit(1)
			return
		print("== ", name)
		await script.new().build(self)
	get_tree().quit()
