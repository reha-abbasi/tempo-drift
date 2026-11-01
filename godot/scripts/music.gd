class_name Music
extends Node
## The soundtrack: an episode's layers (rendered from the web game's own band and leads), started together so they
## stay sample-locked, and faded in and out as the run goes, like the web game's band:
##   core = drums and bass (band level 1), full = the whole band (2+), arp = the arpeggio (3+), perc = claps and
##   shaker (4), od = Overdrive's kicks and crashes, jet = the jetpack's wind and heartbeat, ghost = the melody's
##   in-between notes, melA / melB = the ring notes (every other note each, so neighbouring notes don't cut each other)
## The band plays through filters that colour it for each way of flying, as in the web game.

const LAYERS_BAND := ["core", "full", "arp", "perc", "od", "jet", "ghost"]
const LAYERS_LEAD := ["melA", "melB"]
const OFF_DB := -80.0

var band_player: AudioStreamPlayer
var lead_player: AudioStreamPlayer
var band_stream: AudioStreamSynchronized
var lead_stream: AudioStreamSynchronized
var target := {}
var gain := {}
var playing := false
var offset := 0.0  # the speakers' or headphones' delay (Settings · Audio sync), seconds
var _t0 := 0
var _clock := 0.0
var _paused_at := -1.0
var _lp: AudioEffectLowPassFilter
var _hp: AudioEffectHighPassFilter
var _lp_target := 20000.0
var _hp_target := 20.0


func _ready() -> void:
	var bus := AudioServer.get_bus_index("Band")
	if bus >= 0:
		_lp = AudioServer.get_bus_effect(bus, 0) as AudioEffectLowPassFilter
		_hp = AudioServer.get_bus_effect(bus, 1) as AudioEffectHighPassFilter
	band_player = AudioStreamPlayer.new()
	band_player.bus = "Band"
	add_child(band_player)
	lead_player = AudioStreamPlayer.new()
	lead_player.bus = "Lead"
	add_child(lead_player)


func load_song(folder: String, loop_from := -1.0, gain_db := 0.0) -> void:
	## folder: the song's layers (.ogg recordings of the episodes, or .res renders of the loops and Flight School).
	## loop_from: for Endless, the layers repeat from this time (after the intro) to their end, forever
	_loop_from = loop_from
	_loop_len = 0.0
	_wraps = 0
	_last_pos = 0.0
	band_stream = AudioStreamSynchronized.new()
	band_stream.stream_count = LAYERS_BAND.size()
	for i in LAYERS_BAND.size():
		band_stream.set_sync_stream(i, _layer(folder, LAYERS_BAND[i]))
	lead_stream = AudioStreamSynchronized.new()
	lead_stream.stream_count = LAYERS_LEAD.size()
	for i in LAYERS_LEAD.size():
		lead_stream.set_sync_stream(i, _layer(folder, LAYERS_LEAD[i]))
	band_player.volume_db = gain_db
	lead_player.volume_db = gain_db
	band_player.stream = band_stream
	lead_player.stream = lead_stream
	for k in LAYERS_BAND + LAYERS_LEAD:
		target[k] = 0.0
		gain[k] = 0.0
	target.core = 1.0
	target.ghost = 1.0
	_apply()


var _loop_from := -1.0
var _loop_len := 0.0
var _wraps := 0
var _last_pos := 0.0


func _layer(folder: String, name: String) -> AudioStream:
	var path := "%s/%s.ogg" % [folder, name]
	if not ResourceLoader.exists(path):
		path = "%s/%s.res" % [folder, name]
	var s: AudioStream = load(path)
	if _loop_from >= 0.0:
		if s is AudioStreamWAV:
			s = s.duplicate()
			s.loop_mode = AudioStreamWAV.LOOP_FORWARD
			s.loop_begin = int(_loop_from * s.mix_rate)
			s.loop_end = int(s.get_length() * s.mix_rate)
		elif s is AudioStreamOggVorbis:
			s = s.duplicate()
			s.loop = true
			s.loop_offset = _loop_from
		_loop_len = s.get_length() - _loop_from
	return s


func start(at := 0.0) -> void:
	_wraps = 0
	_last_pos = at
	_apply()
	band_player.play(at)
	lead_player.play(at)
	_t0 = Time.get_ticks_usec() - int(at * 1e6)
	_clock = at
	_paused_at = -1.0
	playing = true


func seek(t: float) -> void:
	## carry on from t (Flight School, after waiting for a move)
	band_player.seek(t)
	lead_player.seek(t)
	_t0 = Time.get_ticks_usec() - int((t + offset) * 1e6)
	_clock = t
	_last_pos = t


func stop() -> void:
	playing = false
	band_player.stop()
	lead_player.stop()


func set_paused(p: bool) -> void:
	if p:
		_paused_at = song_time()
	elif _paused_at >= 0.0:
		_t0 = Time.get_ticks_usec() - int(_paused_at * 1e6)
		_paused_at = -1.0
	band_player.stream_paused = p
	lead_player.stream_paused = p


func song_time() -> float:
	## what the player hears now: the stream's position, plus the time since the last mix, minus the output delay
	## and the calibrated offset. With no sound device the wall clock keeps time instead. Never runs backwards.
	if _paused_at >= 0.0:
		return _paused_at
	if not playing:
		return _clock
	var wall := (Time.get_ticks_usec() - _t0) / 1e6 - offset
	var t := wall
	if band_player.playing and band_player.get_playback_position() > 0.0 and AudioServer.get_driver_name() != "Dummy":
		var pos := band_player.get_playback_position()
		# a looping song: count the times it went round, so the clock keeps running forward
		if _loop_len > 0.0 and pos + 1.0 < _last_pos:
			_wraps += 1
		_last_pos = pos
		t = pos + _wraps * _loop_len + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency() - offset
	_clock = maxf(_clock, t)
	return _clock


func set_band(level: int, overdrive: bool, jetpack: bool) -> void:
	target.core = 1.0 if level < 2 else 0.0
	target.full = 1.0 if level >= 2 else 0.0
	target.arp = 1.0 if level >= 3 else 0.0
	target.perc = 1.0 if level >= 4 else 0.0
	target.od = 1.0 if overdrive else 0.0
	target.jet = 1.0 if jetpack else 0.0


func set_ghosts(on: bool) -> void:
	target.ghost = 1.0 if on else 0.0


func set_lead(layer: int, on: bool) -> void:
	target[LAYERS_LEAD[layer]] = 1.0 if on else 0.0


func set_form(form: int) -> void:
	## open in the car, airy (less bass) on the jetpack
	_lp_target = [1500.0, 9000.0, 20000.0][clampi(form, 0, 2)]
	_hp_target = [20.0, 160.0, 20.0][clampi(form, 0, 2)]


func muffle() -> void:
	## a crash: the band drops out under a muffle until the next bar
	_lp_target = 260.0


func _process(delta: float) -> void:
	if band_stream == null:
		return
	for k in gain.keys():
		# the band eases over ~0.15 s; the melody snaps (~15 ms) so a played note keeps its attack
		var rate := 70.0 if k.begins_with("mel") else 9.0
		gain[k] = move_toward(gain[k], target[k], delta * rate)
	_apply()
	if _lp:
		_lp.cutoff_hz = lerpf(_lp.cutoff_hz, _lp_target, clampf(delta * 12.0, 0.0, 1.0))
		_hp.cutoff_hz = lerpf(_hp.cutoff_hz, _hp_target, clampf(delta * 12.0, 0.0, 1.0))


func _apply() -> void:
	if band_stream == null:
		return
	for i in LAYERS_BAND.size():
		band_stream.set_sync_stream_volume(i, _db(gain.get(LAYERS_BAND[i], 0.0)))
	for i in LAYERS_LEAD.size():
		lead_stream.set_sync_stream_volume(i, _db(gain.get(LAYERS_LEAD[i], 0.0)))


static func _db(g: float) -> float:
	return OFF_DB if g <= 0.001 else linear_to_db(g)
