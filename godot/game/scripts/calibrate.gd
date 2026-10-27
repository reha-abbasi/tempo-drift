class_name Calibrate
extends Control
## The audio timing test: a click plays every 0.6 s and you tap along. Speakers and wireless headphones play sound
## late, and people tap a little late too; the game measures how late, on average, and shifts its clock by that much
## so the rings and the music line up for you. Four clicks to warm up, then eight that count.

signal measured(ms: int)
signal closed

const GAP := 0.6
const FIRST := 1.0
const CLICKS := 12
const WARMUP := 4

var player: AudioStreamPlayer
var big: Label
var small: Label
var pad: Button
var deltas := []
var running := false
var font: Font

func setup(f: Font, f_small: Font) -> void:
	font = f
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.08, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 30; v.offset_right = -30; v.offset_top = 80; v.offset_bottom = -60
	v.add_theme_constant_override("separation", 14)
	add_child(v)
	var h := Label.new()
	h.text = "AUDIO TIMING"
	h.add_theme_font_override("font", f)
	h.add_theme_font_size_override("font_size", 30)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(h)
	small = Label.new()
	small.text = "Use the speakers or headphones you play with.\nTap the pad on every click you hear."
	small.add_theme_font_override("font", f_small)
	small.add_theme_font_size_override("font_size", 16)
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	small.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(small)
	pad = Button.new()
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pad.add_theme_font_override("font", f)
	pad.add_theme_font_size_override("font_size", 40)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.08)
	sb.set_corner_radius_all(30)
	sb.border_color = Color(1, 0.83, 0.36, 0.6)
	sb.set_border_width_all(2)
	for st in ["normal", "hover", "pressed", "focus"]:
		pad.add_theme_stylebox_override(st, sb)
	pad.text = "START"
	pad.button_down.connect(_tap)
	v.add_child(pad)
	big = Label.new()
	big.add_theme_font_override("font", f_small)
	big.add_theme_font_size_override("font_size", 16)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(big)
	var close := Button.new()
	close.text = "CLOSE"
	close.flat = true
	close.add_theme_font_override("font", f_small)
	close.pressed.connect(func():
		_stop()
		closed.emit())
	v.add_child(close)
	player = AudioStreamPlayer.new()
	player.stream = _click_track()
	add_child(player)

## the clicks: a short wooden tick every GAP seconds, the first of each four higher
func _click_track() -> AudioStreamWAV:
	var sr := 44100
	var n := int(sr * (FIRST + GAP * CLICKS + 1.0))
	var data := PackedByteArray()
	data.resize(n * 2)
	for c in CLICKS:
		var f := 1760.0 if c % 4 == 0 else 1320.0
		var start := int((FIRST + c * GAP) * sr)
		for i in int(sr * 0.05):
			var tt := float(i) / sr
			var v := sin(TAU * f * tt) * exp(-tt * 90.0) * 0.7
			data.encode_s16((start + i) * 2, int(v * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = sr
	w.stereo = false
	w.data = data
	return w

func _heard() -> float:
	return player.get_playback_position() + AudioServer.get_time_since_last_mix() - AudioServer.get_output_latency()

func _tap() -> void:
	if not running:
		deltas.clear()
		running = true
		player.play()
		pad.text = "TAP"
		big.text = "4 to warm up, then 8 that count"
		return
	var t := _heard()
	var k := int(round((t - FIRST) / GAP))
	if k < 0 or k >= CLICKS:
		return
	if k >= WARMUP:
		deltas.append(t - (FIRST + k * GAP))
	pad.text = str(maxi(0, CLICKS - k - 1)) if k < CLICKS - 1 else "…"

func _process(_dt: float) -> void:
	if running and not player.playing:
		_finish()

func _finish() -> void:
	running = false
	pad.text = "AGAIN"
	if deltas.size() < 5:
		big.text = "Not enough taps — try again"
		return
	deltas.sort()
	var med: float = deltas[deltas.size() / 2]
	var ms := clampi(int(round(med * 1000.0 / 5.0) * 5.0), -150, 300)
	big.text = "Your audio offset: %+d ms (saved)" % ms
	measured.emit(ms)

func _stop() -> void:
	running = false
	player.stop()
	pad.text = "START"
