extends SceneTree
## Bakes the edge-bounce "boing" (Edge bounce, scripts/edge_bounce.gd) into res://audio/sfx/boing.res, made
## here from sine waves: a soft low bump as the ride meets the wall, then a round tone that glides up with a rubbery
## wobble as it springs back, gone in under half a second.
##   godot --headless --path . -s res://tools/editor/bake_boing.gd   (WAV_OUT=<path> also keeps the .wav)

const SR := 44100
const LEN := 0.46
const PEAK := 0.5        # the file's peak (-6 dBFS); the game sets the level (bounce.gd BOING_DB)


func _init() -> void:
	var n := int(LEN * SR)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	var ph_bump := 0.0
	var top := 0.0
	for i in n:
		var t := float(i) / SR
		# the tone glides up from a fifth below and wobbles, the wobble settling as it rings out
		var f := 440.0 * pow(2.0, -0.58 * exp(-t / 0.045)) * (1.0 + 0.075 * exp(-t / 0.16) * sin(TAU * 15.0 * t))
		ph += f / SR
		var env := minf(1.0, t / 0.006) * exp(-t / 0.11)
		var tone := sin(TAU * ph) + 0.3 * exp(-t / 0.07) * sin(TAU * 2.0 * ph) + 0.1 * exp(-t / 0.04) * sin(TAU * 3.0 * ph)
		# the bump: a short low thud under the start
		ph_bump += (90.0 + 80.0 * exp(-t / 0.02)) / SR
		var bump := sin(TAU * ph_bump) * minf(1.0, t / 0.003) * exp(-t / 0.03)
		var tail := clampf((LEN - t) / 0.06, 0.0, 1.0)
		s[i] = (tone * env * 0.8 + bump * 0.55) * tail
		top = maxf(top, absf(s[i]))
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(round(s[i] / top * PEAK * 32767.0)))
	var wav := _wav(data)
	var tmp := OS.get_environment("WAV_OUT")
	if tmp == "":
		tmp = OS.get_cache_dir().path_join("boing.wav")
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	f.store_buffer(wav)
	f.close()
	var st := AudioStreamWAV.load_from_file(tmp, {"compress/mode": 0})
	ResourceSaver.save(st, "res://audio/sfx/boing.res", ResourceSaver.FLAG_COMPRESS)
	print("boing baked (%.2f s, %s)" % [LEN, tmp])
	quit()


func _wav(data: PackedByteArray) -> PackedByteArray:
	## a mono 16-bit WAV file around the samples
	var h := PackedByteArray()
	h.resize(44)
	h.encode_u32(0, 0x46464952)       # RIFF
	h.encode_u32(4, 36 + data.size())
	h.encode_u32(8, 0x45564157)       # WAVE
	h.encode_u32(12, 0x20746d66)      # fmt
	h.encode_u32(16, 16)
	h.encode_u16(20, 1)
	h.encode_u16(22, 1)
	h.encode_u32(24, SR)
	h.encode_u32(28, SR * 2)
	h.encode_u16(32, 2)
	h.encode_u16(34, 16)
	h.encode_u32(36, 0x61746164)      # data
	h.encode_u32(40, data.size())
	return h + data
