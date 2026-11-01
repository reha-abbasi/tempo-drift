extends SceneTree
## Packs the rendered WAVs (tools/bake/render_audio.mjs) into compressed (QOA) audio the game loads:
## <WAV_DIR>/<song>/<layer>.wav -> res://audio/<song>/<layer>.res. Loop points come from LOOPS (seconds).
##   godot --headless --path . -s res://tools/editor/pack_baked.gd   (WAV_DIR in the environment)

func _init() -> void:
	var src := OS.get_environment("WAV_DIR")
	for song in DirAccess.get_directories_at(src):
		var out := "res://audio/" + song
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
		for f in DirAccess.get_files_at(src + "/" + song):
			if not f.ends_with(".wav"):
				continue
			var s := AudioStreamWAV.load_from_file(src + "/" + song + "/" + f, {"compress/mode": 2})
			var dest := out + "/" + f.get_basename() + ".res"
			ResourceSaver.save(s, dest, ResourceSaver.FLAG_COMPRESS)
		print("%s packed" % song)
	quit()
