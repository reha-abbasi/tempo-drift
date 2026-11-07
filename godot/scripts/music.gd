class_name Music
extends Node
## The soundtrack: an episode's layers (rendered from the web game's own band and leads), started together so they
## stay sample-locked, and faded in and out as the run goes, like the web game's band:
##   core = drums and bass (band level 1), full = the whole band (2+), arp = the arpeggio (3+), perc = claps and
##   shaker (4), od = Overdrive's kicks and crashes, jet = the jetpack's wind and heartbeat, ghost = the melody's
##   in-between notes, melA / melB = the ring notes (every other note each, so neighbouring notes don't cut each other)
## The band plays through filters that colour it for each way of flying, as in the web game.
## The melody layers each play on their own player, started with the band: a player's volume glides across each mix,
## while a layer's volume inside a synchronized stream jumps once a frame, which clicked when a note opened or closed.

const LAYERS_BAND := ["core", "full", "arp", "perc", "od", "jet", "ghost"]
const LAYERS_LEAD := ["melA", "melB"]
const OFF_DB := -80.0

var band_player: AudioStreamPlayer
var lead_player: AudioStreamPlayer   # the melody's level (the menu silences it); each layer plays on _lead_players
var band_stream: AudioStreamSynchronized
var _lead_players: Array = []
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
## recording a video (--write-movie): frames are drawn slower than real time, so the song clock follows the frames
var _movie := Engine.get_write_movie_path() != ""
var _movie_t := 0.0
var _hp_target := 20.0
var _late := {}
## Flow music: extra band layers to load with the song (scripts/flow_music.gd); none = as before
var extra_band: Array = []
var _band: Array = LAYERS_BAND
## Flow music: doubles of melA / melB that follow them while double_on (the anthem step)
var extra_lead: Array = []
var double_on := false
var _lead: Array = LAYERS_LEAD


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
	_band = LAYERS_BAND + extra_band
	band_stream = AudioStreamSynchronized.new()
	band_stream.stream_count = _band.size()
	for i in _band.size():
		band_stream.set_sync_stream(i, _layer(folder, _band[i]))
	_lead = LAYERS_LEAD + extra_lead
	for p in _lead_players:
		p.queue_free()
	_lead_players = []
	for i in _lead.size():
		var p := AudioStreamPlayer.new()
		p.bus = "Lead"
		p.stream = _layer(folder, _lead[i])
		add_child(p)
		_lead_players.append(p)
	band_player.volume_db = gain_db
	lead_player.volume_db = gain_db
	band_player.stream = band_stream
	for k in _band + _lead:
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
	if not ResourceLoader.exists(path):
		return null   # (only Berlin has its new music so far: the menu backdrop flies the others silent)
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
	for p in _lead_players:
		if p.stream:
			p.play(at)
	_t0 = Time.get_ticks_usec() - int(at * 1e6)
	_clock = at
	_movie_t = at
	_paused_at = -1.0
	playing = true


func seek(t: float) -> void:
	## carry on from t (Flight School, after waiting for a move)
	band_player.seek(t)
	for p in _lead_players:
		if p.playing:
			p.seek(t)
	_t0 = Time.get_ticks_usec() - int((t + offset) * 1e6)
	_clock = t
	_movie_t = t
	_last_pos = t


func stop() -> void:
	playing = false
	band_player.stop()
	for p in _lead_players:
		p.stop()


func set_paused(p: bool) -> void:
	if p:
		_paused_at = song_time()
	elif _paused_at >= 0.0:
		_t0 = Time.get_ticks_usec() - int(_paused_at * 1e6)
		_paused_at = -1.0
	band_player.stream_paused = p
	for l in _lead_players:
		l.stream_paused = p


func song_time() -> float:
	## what the player hears now: the stream's position, plus the time since the last mix, minus the output delay
	## and the calibrated offset. With no sound device the wall clock keeps time instead. Never runs backwards.
	if _paused_at >= 0.0:
		return _paused_at
	if not playing:
		return _clock
	if _movie:
		return _movie_t
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


func set_lead(layer: int, on: bool, late := false) -> void:
	## late: the note is already sounding (caught late, or missed): its layer fades in over ~0.12 s or out over
	## ~0.08 s instead, since opening or closing fast mid-note clicked
	target[LAYERS_LEAD[layer]] = 1.0 if on else 0.0
	_late[LAYERS_LEAD[layer]] = late
	if layer < extra_lead.size():
		target[extra_lead[layer]] = 1.0 if on and double_on else 0.0
		_late[extra_lead[layer]] = late


func set_form(form: int) -> void:
	## open in the car, airy (less bass) on the jetpack
	_lp_target = [1500.0, 9000.0, 20000.0][clampi(form, 0, 2)]
	_hp_target = [20.0, 160.0, 20.0][clampi(form, 0, 2)]


func muffle() -> void:
	## a crash: the band drops out under a muffle until the next bar
	_lp_target = 260.0


func _process(delta: float) -> void:
	if _movie and playing and _paused_at < 0.0:
		_movie_t += delta
	if band_stream == null:
		return
	for k in gain.keys():
		# the band eases over ~0.15 s. The melody opens over ~40 ms (it opens ~20 ms before its note, so the attack
		# stays) and closes over ~25 ms: snapping it open in one frame clicked on the echoes still ringing in it
		var rate := 9.0
		if k.begins_with("mel"):
			var late: bool = _late.get(k, false)
			rate = (8.0 if late else 25.0) if target[k] > gain[k] else (12.0 if late else 40.0)
		gain[k] = move_toward(gain[k], target[k], delta * rate)
	_apply()
	if _lp:
		_lp.cutoff_hz = lerpf(_lp.cutoff_hz, _lp_target, clampf(delta * 12.0, 0.0, 1.0))
		_hp.cutoff_hz = lerpf(_hp.cutoff_hz, _hp_target, clampf(delta * 12.0, 0.0, 1.0))


func _apply() -> void:
	if band_stream == null:
		return
	for i in _band.size():
		band_stream.set_sync_stream_volume(i, _db(gain.get(_band[i], 0.0)))
	for i in _lead_players.size():
		_lead_players[i].volume_db = lead_player.volume_db + _db(gain.get(_lead[i], 0.0))


static func _db(g: float) -> float:
	return OFF_DB if g <= 0.001 else linear_to_db(g)
