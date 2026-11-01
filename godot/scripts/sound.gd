extends Node
## Sound effects (autoload "Sound"): the web game's crash, explosion, whoosh, chime, rescue and click, rendered from
## its own code into audio/sfx. play("chime").

const GAIN_DB := 6.0   # the renders are written 6 dB down (tools/bake/render_audio.mjs)

var _streams := {}


func play(name: String, db := 0.0) -> void:
	if not _streams.has(name):
		var path := "res://audio/sfx/%s.res" % name
		_streams[name] = load(path) if ResourceLoader.exists(path) else null
	if _streams[name] == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = _streams[name]
	p.volume_db = GAIN_DB + db
	p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
