class_name Hud
extends CanvasLayer
## The HUD: score and multiplier at the top with the Flow bar under them, combo, lives, the song's progress, the timing
## grade over the car, short messages, and the title and results cards.

signal start_pressed
signal again_pressed
signal quality_chosen(choice: int)
signal episode_chosen(i: int)
signal menu_pressed
signal offset_changed(ms: int)

const GOLD := Color(1.0, 0.83, 0.36)
const ROSE := Color(1.0, 0.45, 0.6)
const RED := Color(1.0, 0.5, 0.55)
const CYAN := Color(0.56, 0.96, 1.0)

var font_display: SystemFont
var font_body: SystemFont
var root: Control
var score_l: Label
var mult_l: Label
var combo_l: Label
var flow_bg: ColorRect
var flow_fg: ColorRect
var prog_fg: ColorRect
var lives_l: Label
var rescue_bg: ColorRect
var rescue_fg: ColorRect
var judge_l: Label
var judge_age := 9.0
var pops: VBoxContainer
var title: Control
var results: Control
var cards: HBoxContainer
var ep_label: Label
var _cards := []
var res_box: VBoxContainer

func _ready() -> void:
	font_display = SystemFont.new()
	font_display.font_names = PackedStringArray(["Futura", "Avenir Next Condensed", "Bahnschrift", "DIN Alternate", "Roboto Condensed", "Segoe UI", "sans-serif"])
	font_display.font_weight = 700
	font_display.font_italic = true
	font_body = SystemFont.new()
	font_body.font_names = PackedStringArray(["Avenir Next", "Segoe UI", "Roboto", "sans-serif"])
	font_body.font_weight = 500
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_play()
	_build_title()
	_build_results()
	_build_settings()

func _label(text: String, size: int, col := Color.WHITE, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font if font else font_display)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _rect(col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r

var play: Control

func _build_play() -> void:
	play = Control.new()
	play.set_anchors_preset(Control.PRESET_FULL_RECT)
	play.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(play)
	var root := play
	# the song's progress: a hairline across the very top
	var pbg := _rect(Color(1, 1, 1, 0.12))
	pbg.set_anchors_preset(Control.PRESET_TOP_WIDE)
	pbg.offset_bottom = 3
	root.add_child(pbg)
	prog_fg = _rect(GOLD)
	prog_fg.position = Vector2.ZERO
	prog_fg.size = Vector2(0, 3)
	root.add_child(prog_fg)
	score_l = _label("0", 44)
	score_l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	score_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_l.offset_left = -200; score_l.offset_right = 200; score_l.offset_top = 18
	root.add_child(score_l)
	flow_bg = _rect(Color(1, 1, 1, 0.16))
	flow_bg.set_anchors_preset(Control.PRESET_CENTER_TOP)
	flow_bg.offset_left = -70; flow_bg.offset_right = 70; flow_bg.offset_top = 76; flow_bg.offset_bottom = 80
	root.add_child(flow_bg)
	flow_fg = _rect(GOLD)
	flow_bg.add_child(flow_fg)
	flow_fg.size = Vector2(0, 4)
	mult_l = _label("×1", 20, GOLD)
	mult_l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	mult_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mult_l.offset_left = -60; mult_l.offset_right = 60; mult_l.offset_top = 84
	root.add_child(mult_l)
	combo_l = _label("", 18, Color(1, 1, 1, 0.85))
	combo_l.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	combo_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	combo_l.offset_left = -160; combo_l.offset_right = -18; combo_l.offset_top = 26
	root.add_child(combo_l)
	lives_l = _label("CAR · JET", 16, Color(1, 1, 1, 0.85), font_body)
	lives_l.position = Vector2(18, 28)
	root.add_child(lives_l)
	rescue_bg = _rect(Color(1, 1, 1, 0.15))
	rescue_bg.position = Vector2(18, 54)
	rescue_bg.size = Vector2(96, 4)
	root.add_child(rescue_bg)
	rescue_fg = _rect(GOLD)
	rescue_bg.add_child(rescue_fg)
	rescue_fg.size = Vector2(0, 4)
	judge_l = _label("", 30, GOLD)
	judge_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	judge_l.size = Vector2(300, 44)
	judge_l.pivot_offset = Vector2(150, 22)
	judge_l.modulate.a = 0.0
	root.add_child(judge_l)
	pops = VBoxContainer.new()
	pops.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pops.offset_left = -240; pops.offset_right = 240; pops.offset_top = 150
	pops.alignment = BoxContainer.ALIGNMENT_BEGIN
	pops.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pops)

func _card() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.06, 0.12, 0.72)
	sb.set_corner_radius_all(22)
	sb.content_margin_left = 28; sb.content_margin_right = 28; sb.content_margin_top = 26; sb.content_margin_bottom = 26
	sb.border_color = Color(1, 0.85, 0.5, 0.25)
	sb.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", sb)
	return p

func _button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font_display)
	b.add_theme_font_size_override("font_size", 24)
	b.add_theme_color_override("font_color", Color(0.12, 0.06, 0.02))
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = GOLD if st != "pressed" else GOLD.darkened(0.15)
		sb.set_corner_radius_all(30)
		sb.content_margin_top = 14; sb.content_margin_bottom = 14; sb.content_margin_left = 40; sb.content_margin_right = 40
		b.add_theme_stylebox_override(st, sb)
	return b

func _build_title() -> void:
	title = Control.new()
	title.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(title)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER_TOP)
	v.offset_left = -230; v.offset_right = 230; v.offset_top = 70; v.offset_bottom = 300
	v.add_theme_constant_override("separation", 10)
	title.add_child(v)
	var name_l := _label("TEMPO DRIFT", 54, Color(1, 0.95, 0.85))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_l)
	ep_label = _label("PAST", 17, GOLD, font_body)
	ep_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(ep_label)
	var hint := _label("Every note is a ring. Swipe into each one,\njust before its note for EXCELLENT.", 16, Color(1, 1, 1, 0.8), font_body)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)
	# the three cities of the Past, one card each: pick one, then FLY
	cards = HBoxContainer.new()
	cards.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	cards.grow_horizontal = Control.GROW_DIRECTION_BOTH
	cards.offset_top = -250; cards.offset_bottom = -170
	cards.add_theme_constant_override("separation", 8)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	title.add_child(cards)
	var b := _button("FLY")
	b.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	b.grow_horizontal = Control.GROW_DIRECTION_BOTH
	b.offset_top = -140; b.offset_bottom = -76
	b.pressed.connect(func(): start_pressed.emit())
	title.add_child(b)

func _ghost_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font_body)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	b.add_theme_color_override("font_pressed_color", Color(0.12, 0.06, 0.02))
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = GOLD if st == "pressed" else Color(1, 1, 1, 0.1)
		sb.set_corner_radius_all(18)
		sb.border_color = Color(1, 1, 1, 0.25)
		sb.set_border_width_all(1)
		sb.content_margin_top = 8; sb.content_margin_bottom = 8; sb.content_margin_left = 14; sb.content_margin_right = 14
		b.add_theme_stylebox_override(st, sb)
	return b

# ---------------------------------------------------------------- settings: picture quality and the audio offset

var settings: Control
var q_buttons := []
var off_slider: HSlider
var off_label: Label
var q_label: Label

func _build_settings() -> void:
	var gear := _ghost_button("SETTINGS")
	gear.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	gear.offset_left = -130; gear.offset_right = -16; gear.offset_top = 16; gear.offset_bottom = 52
	gear.pressed.connect(func(): settings.visible = true)
	title.add_child(gear)
	settings = CenterContainer.new()
	settings.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings.visible = false
	root.add_child(settings)
	var card := _card()
	card.custom_minimum_size = Vector2(420, 0)
	settings.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	card.add_child(v)
	var h := _label("SETTINGS", 26, Color(1, 0.95, 0.85))
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(h)
	v.add_child(_label("Picture quality", 15, GOLD, font_body))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	var group := ButtonGroup.new()
	for i in 4:
		var b := _ghost_button(["AUTO", "LOW", "MEDIUM", "HIGH"][i])
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var c := i - 1
		b.pressed.connect(func(): quality_chosen.emit(c))
		row.add_child(b)
		q_buttons.append(b)
	q_label = _label("", 13, Color(1, 1, 1, 0.6), font_body)
	v.add_child(q_label)
	v.add_child(_label("Audio offset", 15, GOLD, font_body))
	var orow := HBoxContainer.new()
	v.add_child(orow)
	off_slider = HSlider.new()
	off_slider.min_value = -150
	off_slider.max_value = 300
	off_slider.step = 5
	off_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	off_slider.value_changed.connect(func(x):
		off_label.text = "%+d ms" % int(x)
		offset_changed.emit(int(x)))
	orow.add_child(off_slider)
	off_label = _label("0 ms", 15, Color.WHITE, font_body)
	off_label.custom_minimum_size = Vector2(80, 0)
	off_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	orow.add_child(off_label)
	var hint := _label("Wireless headphones play sound late. If the notes sound\nlater than the rings, move this to the right.", 12, Color(1, 1, 1, 0.6), font_body)
	v.add_child(hint)
	var done := _button("DONE")
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.pressed.connect(func(): settings.visible = false)
	v.add_child(done)

func set_episodes(list: Array, sel: int) -> void:
	for c in cards.get_children():
		c.queue_free()
	_cards.clear()
	for i in list.size():
		var e: Dictionary = list[i]
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = i == sel
		b.custom_minimum_size = Vector2(132, 78)
		b.text = "%s\n%s   %s" % [e.city, e.year, "★".repeat(e.stars) + "☆".repeat(3 - e.stars)]
		b.add_theme_font_override("font", font_body)
		b.add_theme_font_size_override("font_size", 14)
		b.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
		b.add_theme_color_override("font_pressed_color", Color(0.12, 0.06, 0.02))
		b.add_theme_color_override("font_hover_pressed_color", Color(0.12, 0.06, 0.02))
		for st in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
			var sb := StyleBoxFlat.new()
			sb.bg_color = GOLD if st.contains("pressed") else Color(0.08, 0.06, 0.12, 0.6)
			sb.set_corner_radius_all(16)
			sb.border_color = Color(1, 0.85, 0.5, 0.35)
			sb.set_border_width_all(1)
			b.add_theme_stylebox_override(st, sb)
		var k := i
		b.pressed.connect(func():
			for o in _cards:
				o.button_pressed = o == b
			episode_chosen.emit(k))
		cards.add_child(b)
		_cards.append(b)
	var e: Dictionary = list[sel]
	ep_label.text = "PAST · EPISODE %d · %s %s%s" % [sel + 1, e.city, e.year, ("   ·   BEST %s" % _thousands(e.best)) if e.best > 0 else ""]

func show_settings_state(choice: int, label: String, offset_ms: int) -> void:
	q_buttons[choice + 1].button_pressed = true
	q_label.text = "Now: " + label
	off_slider.set_value_no_signal(offset_ms)
	off_label.text = "%+d ms" % offset_ms

func _build_results() -> void:
	results = CenterContainer.new()
	results.set_anchors_preset(Control.PRESET_FULL_RECT)
	results.visible = false
	root.add_child(results)
	var card := _card()
	results.add_child(card)
	res_box = VBoxContainer.new()
	res_box.add_theme_constant_override("separation", 8)
	card.add_child(res_box)

func show_title(on: bool) -> void:
	title.visible = on
	play.visible = not on

func show_results(r: Dictionary, cleared: bool, place := "") -> void:
	for c in res_box.get_children():
		c.queue_free()
	var head := _label(place + (" · CLEARED" if cleared else " · OUT OF LIVES") + ("   ·   NEW BEST" if r.get("new_best", false) else ""), 16, GOLD, font_body)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	res_box.add_child(head)
	var g := _label(r.grade if cleared else "—", 96, GOLD if cleared else RED)
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	res_box.add_child(g)
	if cleared:
		var stars := _label("★".repeat(r.stars) + "☆".repeat(3 - r.stars), 34, GOLD, font_body)
		stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		res_box.add_child(stars)
	var acc := _label("%.1f%% OF THE NOTES PLAYED" % (r.acc * 100.0), 15, Color(1, 1, 1, 0.8), font_body)
	acc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	res_box.add_child(acc)
	var grid := HBoxContainer.new()
	grid.alignment = BoxContainer.ALIGNMENT_CENTER
	grid.add_theme_constant_override("separation", 18)
	for item in [["EXCELLENT", r.J.ex, GOLD], ["GOOD", r.J.gd, CYAN], ["OK", r.J.ok, Color(0.9, 0.86, 0.95)], ["MISSED", r.J.m, RED]]:
		var col := VBoxContainer.new()
		var n := _label(str(item[1]), 28, item[2])
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var k := _label(item[0], 11, Color(1, 1, 1, 0.6), font_body)
		k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(n)
		col.add_child(k)
		grid.add_child(col)
	res_box.add_child(grid)
	var sc := _label("SCORE %s   ·   MAX COMBO %d   ·   DUET NOTES %d" % [_thousands(r.score), r.max_combo, r.get("duets", 0)], 15, Color(1, 1, 1, 0.9), font_body)
	sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	res_box.add_child(sc)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	res_box.add_child(gap)
	var b := _button("PLAY AGAIN")
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func(): again_pressed.emit())
	res_box.add_child(b)
	var m := _ghost_button("CITIES")
	m.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	m.pressed.connect(func(): menu_pressed.emit())
	res_box.add_child(m)
	results.visible = true

func hide_results() -> void:
	results.visible = false

func _thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out

func judge(text: String, col: Color) -> void:
	judge_l.text = text
	judge_l.add_theme_color_override("font_color", col)
	judge_age = 0.0

func pop(text: String, kind: String) -> void:
	var col := GOLD if kind == "gold" else RED if kind == "red" else Color(1.0, 0.6, 0.25) if kind == "od" else Color.WHITE
	var l := _label(text, 26 if kind == "od" else 22, col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pops.add_child(l)
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)

func update_play(g: Game, car_screen: Vector2, dt: float, progress: float) -> void:
	score_l.text = _thousands(g.score)
	var tier := g.tier()
	mult_l.text = "OVERDRIVE ×8" if g.od_t > 0.0 else "×%d" % tier
	mult_l.add_theme_color_override("font_color", Color(1.0, 0.6, 0.25) if g.od_t > 0.0 else GOLD)
	flow_fg.size = Vector2(140.0 * (1.0 if g.od_t > 0.0 else g.flow / 100.0), 4)
	flow_fg.color = Color(1.0, 0.55, 0.2) if g.od_t > 0.0 else GOLD
	var duet := g.ex_streak >= Game.DUET_AFTER
	combo_l.text = ("DUET · " if duet else "") + ("%d COMBO" % g.combo if g.combo >= 5 else "")
	combo_l.add_theme_color_override("font_color", GOLD if duet else Color(1, 1, 1, 0.85))
	lives_l.text = "◆ CAR   ◇ JET" if g.form == 2 else "◇ CAR   ◆ JET"
	rescue_bg.visible = g.form < 2 and not g.over
	rescue_fg.size = Vector2(96.0 * g.rescue / 100.0, 4)
	prog_fg.size = Vector2(root.size.x * clampf(progress, 0.0, 1.0), 3)
	# the timing grade pops up just above the car
	judge_age += dt
	var k := clampf(judge_age / 0.6, 0.0, 1.0)
	judge_l.modulate.a = 0.0 if judge_age > 0.6 else (1.0 if k < 0.7 else 1.0 - (k - 0.7) / 0.3)
	judge_l.scale = Vector2.ONE * (0.8 + 0.26 * minf(1.0, k * 6.0) - 0.06 * k)
	judge_l.position = car_screen - Vector2(150, 110 + 30 * k)
