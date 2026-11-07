class_name FlowMusic
extends Node
## Flow music: the band grows grander the longer you keep playing notes without missing, and loses its spark when
## you miss.
##
## The band's spark counts like Flow (+3 for a played note, -25 for a missed one, nothing left after a crash) but
## keeps counting through Overdrive, up to 200, so a long clean streak keeps building through the whole song. The
## band climbs eight steps: 1 drums and bass, 2 the whole band, 3 + arpeggio, 4 + percussion, 5-7 the city's grander
## parts (up1, up2, up3: rendered by tools/music/flow_layers.py), 8 the anthem: the tune doubled an octave up. A step
## is won on a bar line, after a fill on the beat before it (the rise layer); the mix opens up with each step
## (brighter, wider, a little more room) and the band makes room for each grand part, so the song grows without
## getting harsh. A miss takes a step away on the next beat and deflates the band for a moment: it dulls and dips,
## then comes back over about a bar.

## the spark each step needs: step 2 after 4 clean notes, 3 after 9, 4 after 15, 5 after 23, 6 after 33, 7 after 45,
## 8 after 60
const STEPS := [0.0, 12.0, 27.0, 45.0, 69.0, 99.0, 135.0, 180.0]
const SPARK_MAX := 200.0
const PLAYED := 3.0
const MISSED := 25.0
## the layers that join at steps 2 to 7 (step 1 is the core: drums and bass)
const LADDER := ["full", "arp", "perc", "up1", "up2", "up3"]
## cities whose band grows differently: Rio has no arpeggio, its bateria grows instead
const LADDERS := {"sunset_1": ["full", "up1", "perc", "up2", "up3", "up4"]}
## the extra band layers to load with the song (a city without them simply stops growing at its full band), and the
## anthem's doubles of the two melody layers
const EXTRA := ["up1", "up2", "up3", "up4", "rise"]
const EXTRA_LEAD := ["melUpA", "melUpB"]
const BAND := ["full", "arp", "perc", "up1", "up2", "up3", "up4"]
## the song's own band layers, which ease down to make room for the grand parts
const OWN := ["core", "full", "arp", "perc", "od"]
## the mix at each step: low-pass (Hz), stereo width (1 = as recorded), room (reverb); and how far the song's own
## layers ease down (dB) for each grand part playing, so each one adds to the band without the peaks rising
const CUT := [12000.0, 14000.0, 17000.0, 20000.0, 20000.0, 20000.0, 20000.0, 20000.0]
const WIDTH := [0.94, 0.96, 0.98, 1.0, 1.06, 1.12, 1.18, 1.22]
const ROOM := [0.0, 0.0, 0.0, 0.0, 0.03, 0.05, 0.07, 0.08]
const ROOM_FOR := [0.0, -1.5, -3.0, -4.0, -5.0]
## and the whole band and the melody a touch lower at the top steps, so the peaks stay a decibel under the limiter
const TOP_TRIM := [0.0, 0.0, 0.0, 0.0, -0.5, -1.0, -1.5, -2.0]
const LEAD_TRIM := [0.0, 0.0, 0.0, 0.0, 0.0, -0.5, -1.0, -1.0]
## Overdrive's hits over the grand parts: the band a decibel lower again while it plays
const OD_TRIM := -1.0
## the fill into a new step, a little under the band (it lands on the downbeat with the song's own hits)
const RISE := 0.7
## a miss: the band dulls to this (Hz) and dips this much (dB), then comes back
const DEFLATE_CUT := 1100.0
const DEFLATE_DB := -4.0
## how far ahead of what you hear the band is changed (plus the speakers' delay), so a step lands on its beat
const LOOKAHEAD := 0.04

var spark := 0.0
var level := 1
var rules: Rules
var music: Music
var ladder: Array = LADDER
var _beat := -999
var _rise := false           # a step is coming on the next bar line (its fill is playing)
var _rise_until := -1.0      # the rise layer is open until then (song time)
var _drop := -1              # the step to fall back to on the next beat, after a miss
var _dip := 0.0              # how deflated the band is (0..1)
var _dip_hold := 0.0
var _cut := CUT[0]
var _width := WIDTH[0]
var _room := 0.0
var _own := 1.0
var _trim := 0.0
var _lead_trim := 0.0
var _lead_db := INF          # the melody's own level (Endless plays it louder), read once the song is loaded
var _bus := -1
var _fx: Array = []
var _lp: AudioEffectLowPassFilter
var _wide: AudioEffectStereoEnhance
var _verb: AudioEffectReverb
var _amp: AudioEffectAmplify
var _pips: FlowPips
var _bar: Control


func setup(r: Rules, m: Music, hud: Control, audio: String) -> void:
	## before the song loads: asks the music for the extra layers, adds the mix's effects to the Band bus
	rules = r
	music = m
	ladder = LADDERS.get(audio.get_file(), LADDER)
	music.extra_band = EXTRA
	music.extra_lead = EXTRA_LEAD
	r.judged.connect(func(_g, _n): spark = minf(SPARK_MAX, spark + PLAYED))
	r.missed.connect(_on_missed)
	r.crashed.connect(_on_crashed)
	_bus = AudioServer.get_bus_index("Band")
	if _bus >= 0:
		_lp = AudioEffectLowPassFilter.new()
		_lp.cutoff_hz = _cut
		_wide = AudioEffectStereoEnhance.new()
		_wide.pan_pullout = _width
		_wide.time_pullout_ms = 0.0
		_verb = AudioEffectReverb.new()
		_verb.room_size = 0.55
		_verb.damping = 0.6
		_verb.hipass = 0.15
		_verb.dry = 1.0
		_verb.wet = 0.0
		_amp = AudioEffectAmplify.new()
		_fx = [_lp, _wide, _verb, _amp]
		for e in _fx:
			AudioServer.add_bus_effect(_bus, e)
	# (on the HUD itself, under the Flow bar, so Overdrive's rainbow on the bar doesn't tint them)
	_bar = hud.get_node_or_null("%FlowBar") as Control
	if _bar:
		_pips = FlowPips.new()
		_pips.size = Vector2(_bar.custom_minimum_size.x, 4)
		_pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(_pips)


func _exit_tree() -> void:
	if _bus < 0:
		return
	for i in range(AudioServer.get_bus_effect_count(_bus) - 1, -1, -1):
		if AudioServer.get_bus_effect(_bus, i) in _fx:
			AudioServer.remove_bus_effect(_bus, i)


func step_for(s: float) -> int:
	var k := 1
	while k < STEPS.size() and s >= STEPS[k]:
		k += 1
	return k


func cap() -> int:
	## the grand parts need the car: on the jetpack the band stops at the percussion
	return STEPS.size() if rules.form >= 2 else 4


func update(t: float) -> void:
	## every frame, after the run has set the band: the steps on the beat, the layers and the mix
	var dt := get_process_delta_time()
	# (the song is mixed ahead of what you hear by the speakers' delay; a recorded video has none)
	var la := t + LOOKAHEAD
	if Engine.get_write_movie_path() == "":
		la += AudioServer.get_output_latency() + music.offset
	var bi := floori(la / rules.BEAT)
	if bi != _beat:
		_beat = bi
		_on_beat(bi, la)
	var lv := mini(level, cap())
	music.target.core = 1.0 if lv < 2 else 0.0
	var parts := 0
	for k in BAND:
		var i := ladder.find(k)
		music.target[k] = 1.0 if i >= 0 and lv >= i + 2 else 0.0
		if k.begins_with("up") and music.target[k] > 0.0:
			parts += 1
	music.target.rise = RISE if la < _rise_until else 0.0
	var room_db: float = ROOM_FOR[parts] - (1.0 if lv >= STEPS.size() else 0.0)
	_own = lerpf(_own, db_to_linear(room_db), clampf(dt * 4.0, 0.0, 1.0))
	for k in OWN:
		music.target[k] *= _own
	# the anthem: the tune doubled an octave up (each double follows its melody layer, note by note)
	music.double_on = lv >= STEPS.size()
	if not music.double_on:
		for k in EXTRA_LEAD:
			music.target[k] = 0.0
	# the mix opens up with each step and dulls for a moment on a miss
	_dip_hold -= dt
	_dip = move_toward(_dip, 1.0 if _dip_hold > 0.0 else 0.0, dt * (5.0 if _dip_hold > 0.0 else 0.85))
	var ease := clampf(dt * 1.5, 0.0, 1.0)
	_cut = exp(lerpf(log(_cut), log(CUT[lv - 1]), ease))
	_width = lerpf(_width, WIDTH[lv - 1], ease)
	_room = lerpf(_room, ROOM[lv - 1], ease)
	_trim = lerpf(_trim, TOP_TRIM[lv - 1] + (OD_TRIM if rules.od_t > 0.0 and lv >= 5 else 0.0), ease)
	_lead_trim = lerpf(_lead_trim, LEAD_TRIM[lv - 1], ease)
	if _lead_db == INF:
		_lead_db = music.lead_player.volume_db
	music.lead_player.volume_db = _lead_db + _lead_trim
	if _lp:
		var d := _dip * _dip * (3.0 - 2.0 * _dip)
		_lp.cutoff_hz = exp(lerpf(log(_cut), log(minf(_cut, DEFLATE_CUT)), d))
		_amp.volume_db = _trim + DEFLATE_DB * d
		_wide.pan_pullout = _width
		_verb.wet = _room
	if _pips:
		_pips.global_position = _bar.global_position + Vector2(0, 10)
		_pips.show_level(lv, cap(), spark, dt)


func _on_beat(i: int, la: float) -> void:
	var per := maxi(1, roundi(rules.BAR / rules.BEAT))
	var k := posmod(i, per)
	if _drop >= 0:
		if _drop < level and _pips:
			_pips.lose(_drop, level)
		level = _drop
		_drop = -1
	if k == 0 and _rise:
		_rise = false
		if level < cap():
			level += 1
			if _pips:
				_pips.win(level)
	# the last beat of a bar: if the spark has reached the next step, its fill plays now and the step lands on the
	# bar line
	if k == per - 1 and not _rise and level < cap() and step_for(spark) > level and la > rules.first_t - rules.BAR:
		_rise = true
		_rise_until = (i + 3) * rules.BEAT


func _on_missed(n: Dictionary) -> void:
	if int(n.state) != 2:
		return   # (lost in a crash: the crash took the spark already)
	spark = maxf(0.0, spark - MISSED)
	var from := level if _drop < 0 else _drop
	_drop = maxi(1, mini(step_for(spark), from - 1))
	# every miss costs a step: the step comes back after a couple more notes, not on the very next bar line
	spark = minf(spark, STEPS[_drop] - 2.0 * PLAYED)
	_rise = false
	_rise_until = -1.0
	_dip_hold = 0.2


func _on_crashed(_h: Dictionary) -> void:
	spark = 0.0
	if _pips and level > 1:
		_pips.lose(1, level)
	level = 1
	_drop = -1
	_rise = false
	_rise_until = -1.0


## the band's steps, a row of pips under the Flow bar: lit up to the band's step, the grand ones gold; a step won
## flashes, a step lost flashes red and fades
class FlowPips:
	extends Control
	const N := 8
	const GOLD := Color("ffd45c")
	const RED := Color("ff6b78")
	var lit := 1
	var top := N
	var won := 0.0
	var won_i := -1
	var lost := 0.0
	var lost_from := 0
	var lost_to := 0
	var near := 0.0

	func show_level(lv: int, cap: int, spark: float, dt: float) -> void:
		won = maxf(0.0, won - dt * 2.0)
		lost = maxf(0.0, lost - dt * 1.4)
		# how close the next step is (its pip fills in faintly)
		var a: float = FlowMusic.STEPS[mini(lv - 1, N - 1)]
		var b: float = FlowMusic.STEPS[mini(lv, N - 1)]
		near = clampf((spark - a) / maxf(1.0, b - a), 0.0, 1.0) if lv < N else 0.0
		lit = lv
		top = cap
		queue_redraw()

	func win(lv: int) -> void:
		won = 1.0
		won_i = lv - 1

	func lose(to: int, from: int) -> void:
		lost = 1.0
		lost_to = to
		lost_from = from

	func _draw() -> void:
		var gap := 3.0
		var w := (size.x - gap * (N - 1)) / N
		for i in N:
			var r := Rect2(i * (w + gap), 0.0, w, size.y)
			var on: Color = GOLD if i >= 4 else Color.WHITE
			var c := Color(1, 1, 1, 0.16 if i < top else 0.06)
			if i < lit:
				c = on
				if i == won_i and won > 0.0:
					c = on.lerp(Color.WHITE, won)
					r = r.grow_individual(0.0, won * 2.0, 0.0, won * 2.0)
			elif i == lit and lit < top:
				c = Color(on, 0.16 + 0.34 * near)
			if lost > 0.0 and i >= lost_to and i < lost_from:
				c = Color(RED, lost)
			draw_rect(r, c)
