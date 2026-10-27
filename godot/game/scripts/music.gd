class_name Music
extends Node
## The soundtrack: the layers baked from the web game's synth, all started together so they stay sample-locked.
## The band layers run through the Band bus (its filters colour the band for each way of flying), the melody through
## the Lead bus. The game clock comes from the audio clock, so what you see matches what you hear.

const LAYERS_BAND := ["core", "full", "arp", "perc", "od", "jet", "ghost"]
const LAYERS_LEAD := ["melA", "melB", "harmA", "harmB"]
const OFF_DB := -80.0

var band_player: AudioStreamPlayer
var lead_player: AudioStreamPlayer
var band_stream: AudioStreamSynchronized
var lead_stream: AudioStreamSynchronized
# target and current gain (0..1) per layer, eased every frame so changes never click
var target := {}
var gain := {}
var playing := false
var _t0_usec := 0
# extra delay of the speakers or headphones, set in Settings (seconds)
var offset := 0.0
var _clock := 0.0
var _lp: AudioEffectLowPassFilter
var _hp: AudioEffectHighPassFilter
var _lp_target := 20000.0
var _hp_target := 20.0
# the chime when you catch a note: one glassy bell, tuned to C6 and pitched to each note
const CHIME_ROOT := 84
var _chime: AudioStreamWAV
var _chimes := []
var _chime_i := 0

func _ready() -> void:
	_setup_buses()

func _setup_buses() -> void:
	if AudioServer.get_bus_index("Band") != -1:
		return
	AudioServer.add_bus(1)
	AudioServer.set_bus_name(1, "Band")
	AudioServer.set_bus_send(1, "Master")
	_lp = AudioEffectLowPassFilter.new()
	_lp.cutoff_hz = 20000.0
	_hp = AudioEffectHighPassFilter.new()
	_hp.cutoff_hz = 20.0
	AudioServer.add_bus_effect(1, _lp)
	AudioServer.add_bus_effect(1, _hp)
	AudioServer.add_bus(2)
	AudioServer.set_bus_name(2, "Lead")
	AudioServer.set_bus_send(2, "Master")
	# a limiter on the master so the layers together never clip on phone speakers
	var lim := AudioEffectHardLimiter.new()
	lim.ceiling_db = -0.5
	AudioServer.add_bus_effect(0, lim)
	_chime = _bell()
	for i in 6:
		var pl := AudioStreamPlayer.new()
		pl.stream = _chime
		pl.bus = "Lead"
		add_child(pl)
		_chimes.append(pl)

## a small glass bell: a few partials (one a little off, for the shimmer), struck softly and dying away
func _bell() -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * 0.8)
	var f0 := 440.0 * pow(2.0, (CHIME_ROOT - 69) / 12.0)
	var partials := [[1.0, 1.0, 5.5], [2.0, 0.32, 9.0], [3.0, 0.1, 14.0], [4.17, 0.13, 20.0], [5.43, 0.05, 28.0]]
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var v := 0.0
		for pt in partials:
			v += sin(TAU * f0 * pt[0] * t) * pt[1] * exp(-t * pt[2])
		v *= minf(1.0, t / 0.002) * 0.5
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w

## the chime for a caught note, an octave over the melody so it rings with it; louder for an EXCELLENT
func chime(note: int, strong: bool) -> void:
	if _chimes.is_empty():
		return
	var pl: AudioStreamPlayer = _chimes[_chime_i % _chimes.size()]
	_chime_i += 1
	pl.pitch_scale = pow(2.0, (note + 12 - CHIME_ROOT) / 12.0)
	pl.volume_db = -15.0 if strong else -20.0
	pl.play()

func load_song(folder: String) -> void:
	band_stream = AudioStreamSynchronized.new()
	band_stream.stream_count = LAYERS_BAND.size()
	for i in LAYERS_BAND.size():
		band_stream.set_sync_stream(i, load("%s/%s.ogg" % [folder, LAYERS_BAND[i]]))
	lead_stream = AudioStreamSynchronized.new()
	lead_stream.stream_count = LAYERS_LEAD.size()
	for i in LAYERS_LEAD.size():
		lead_stream.set_sync_stream(i, load("%s/%s.ogg" % [folder, LAYERS_LEAD[i]]))
	if band_player == null:
		band_player = AudioStreamPlayer.new()
		band_player.bus = "Band"
		add_child(band_player)
		lead_player = AudioStreamPlayer.new()
		lead_player.bus = "Lead"
		add_child(lead_player)
	band_player.stream = band_stream
	lead_player.stream = lead_stream
	for k in LAYERS_BAND + LAYERS_LEAD:
		target[k] = 0.0
		gain[k] = 0.0
	target.core = 1.0
	target.ghost = 1.0
	_apply_all()

func start() -> void:
	_apply_all()
	band_player.play()
	lead_player.play()
	_t0_usec = Time.get_ticks_usec()
	_clock = 0.0
	playing = true

func stop() -> void:
	playing = false
	if band_player:
		band_player.stop()
		lead_player.stop()

func set_paused(p: bool) -> void:
	band_player.stream_paused = p
	lead_player.stream_paused = p

## The song time in seconds: the stream's position, plus the time since the last mix, minus the output latency.
## When the audio clock doesn't move (no sound device), the wall clock keeps time instead.
func song_time() -> float:
	if not playing:
		return _clock
	var pos := band_player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency() - offset
	var wall := (Time.get_ticks_usec() - _t0_usec) / 1000000.0 - AudioServer.get_output_latency() - offset
	var t := pos if band_player.get_playback_position() > 0.0 else wall
	# never run backwards (the mix lands in steps)
	_clock = maxf(_clock, t)
	return _clock

## Which band layers play: 1 = drums and bass, 2 = the whole band, 3 = + arpeggio, 4 = + claps and shaker
func set_band(level: int, overdrive: bool, jetpack: bool) -> void:
	target.core = 1.0 if level < 2 else 0.0
	target.full = 1.0 if level >= 2 else 0.0
	target.arp = 1.0 if level >= 3 else 0.0
	target.perc = 1.0 if level >= 4 else 0.0
	target.od = 1.0 if overdrive else 0.0
	target.jet = 1.0 if jetpack else 0.0

func set_ghosts(on: bool) -> void:
	target.ghost = 1.0 if on else 0.0

## a melody layer on or off (snappy, so a caught note keeps its attack and a missed one goes quiet at once);
## layers 0-1 are the melody, 2-3 the duet voice
func set_lead(layer: int, on: bool) -> void:
	var k: String = LAYERS_LEAD[layer]
	target[k] = 1.0 if on else 0.0

## the band's colour for each way of flying: open in the car, airy on the jetpack; a crash muffles it for a moment
func set_form_filter(form: int) -> void:
	_lp_target = [1500.0, 9000.0, 20000.0][clampi(form, 0, 2)]
	_hp_target = [20.0, 160.0, 20.0][clampi(form, 0, 2)]

func muffle() -> void:
	_lp_target = 260.0

func _process(delta: float) -> void:
	if band_stream == null:
		return
	for k in gain.keys():
		# band layers ease over ~0.15 s, the melody in ~15 ms
		var rate := 70.0 if k.begins_with("mel") or k.begins_with("harm") else 9.0
		gain[k] = move_toward(gain[k], target[k], delta * rate)
	_apply_all()
	if _lp:
		_lp.cutoff_hz = lerpf(_lp.cutoff_hz, _lp_target, clampf(delta * 12.0, 0.0, 1.0))
		_hp.cutoff_hz = lerpf(_hp.cutoff_hz, _hp_target, clampf(delta * 12.0, 0.0, 1.0))

func _apply_all() -> void:
	if band_stream == null:
		return
	for i in LAYERS_BAND.size():
		band_stream.set_sync_stream_volume(i, _db(gain.get(LAYERS_BAND[i], 0.0)))
	for i in LAYERS_LEAD.size():
		lead_stream.set_sync_stream_volume(i, _db(gain.get(LAYERS_LEAD[i], 0.0)))

func _db(g: float) -> float:
	return OFF_DB if g <= 0.001 else linear_to_db(g)
