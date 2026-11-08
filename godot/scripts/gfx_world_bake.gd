extends SceneTree
## Bakes the "New city look" detail (GfxWorld) into scenes, so a run only has to load it:
## scenes/gfx_world/<city>/section_<n>.scn for each street section kind, horizon.scn for the far view ahead and
## horizon_back.scn for the view behind (GfxWorldBack).
## Run it again after changing a gfx_world builder:
##   godot --headless --path . -s res://scripts/gfx_world_bake.gd


func _initialize() -> void:
	for key in GfxWorld.BUILDERS:
		var b: RefCounted = (load(GfxWorld.BUILDERS[key]) as GDScript).new()
		var dir: String = GfxWorld.BAKED + key
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		var c := (load("res://scenes/cities/%s.tscn" % key) as PackedScene).instantiate() as City
		for ps in c.sections:
			var sec := ps.instantiate() as Node3D
			_save(GfxWorld.pack(GfxWorld.section_node(b, sec)), dir + "/" + ps.resource_path.get_file().get_basename() + ".scn")
			sec.free()
		_save(GfxWorld.pack(b.horizon()), dir + "/horizon.scn")
		var back := GfxWorldBack.build(key, b)
		if back:
			_save(GfxWorld.pack(back), dir + "/horizon_back.scn")
		c.free()
	quit()


func _save(ps: PackedScene, path: String) -> void:
	var err := ResourceSaver.save(ps, path, ResourceSaver.FLAG_COMPRESS)
	print("baked %s (%d KB)%s" % [path, FileAccess.get_file_as_bytes(path).size() / 1024, "" if err == OK else " FAILED"])
