class_name Hud
extends CanvasLayer

## All on-screen UI (built in code for now): menu, in-run HUD, pause, game over.

signal pause_pressed
signal resume_pressed
signal restart_pressed
signal menu_pressed
signal sound_pressed

const INK := Color("17243a")
const ACCENT := Color("ff6b35")
const GOLD := Color("ffcf33")

var _theme := Theme.new()
var _safe_top := 0.0
var _safe_bottom := 0.0

var _run_ui: Control
var _score: Label
var _coins: Label
var _multiplier: Label
var _powers: VBoxContainer
var _power_bars := {}
var _warning: Label
var _popup: Label

var _menu: Control
var _menu_best: Label
var _menu_bank: Label
var _tap: Label
var _menu_sound: Button

var _pause: Control
var _pause_sound: Button

var _over: Control
var _over_score: Label
var _over_best: Label
var _over_coins: Label
var _over_new: Label

var _time := 0.0


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_compute_safe_area()
	_build_theme()
	var root := Control.new()
	root.name = "Root"
	root.theme = _theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_run_ui(root)
	_build_menu(root)
	_build_pause(root)
	_build_game_over(root)


func _process(delta: float) -> void:
	_time += delta
	if _tap.is_visible_in_tree():
		_tap.modulate.a = 0.55 + 0.45 * sin(_time * 4.0)
	if _warning.visible:
		_warning.modulate.a = maxf(0.0, _warning.modulate.a - delta * 0.6)
		if _warning.modulate.a <= 0.0:
			_warning.visible = false
	if _popup.visible:
		_popup.position.y -= delta * 60.0
		_popup.modulate.a = maxf(0.0, _popup.modulate.a - delta * 0.9)
		if _popup.modulate.a <= 0.0:
			_popup.visible = false


# ------------------------------------------------------------------ public API

func show_menu(best: int, bank: int) -> void:
	_menu_best.text = "BEST  %d" % best
	_menu_bank.text = "%d" % bank
	_menu_sound.text = _sound_text()
	_menu.visible = true
	_run_ui.visible = false
	_pause.visible = false
	_over.visible = false


func show_run() -> void:
	_menu.visible = false
	_pause.visible = false
	_over.visible = false
	_run_ui.visible = true
	_warning.visible = false
	_popup.visible = false
	update_run(0, 0, 0.0, 0.0)


func update_run(score: int, coins: int, magnet: float, double: float) -> void:
	_score.text = "%d" % score
	_coins.text = "%d" % coins
	_multiplier.visible = double > 0.0
	_set_power("magnet", magnet)
	_set_power("double", double)


func show_pause(on: bool) -> void:
	_pause_sound.text = _sound_text()
	_pause.visible = on


func show_game_over(score: int, coins: int, best: int, is_best: bool) -> void:
	_over_score.text = "%d" % score
	_over_coins.text = "+%d" % coins
	_over_best.text = "BEST  %d" % best
	_over_new.visible = is_best
	_over.visible = true
	_over.modulate.a = 0.0
	create_tween().tween_property(_over, "modulate:a", 1.0, 0.35)


func refresh_sound_buttons() -> void:
	_menu_sound.text = _sound_text()
	_pause_sound.text = _sound_text()


func is_over_menu_button(pos: Vector2) -> bool:
	return _menu_sound.is_visible_in_tree() and _menu_sound.get_global_rect().grow(10).has_point(pos)


func warn(text: String) -> void:
	_warning.text = text
	_warning.visible = true
	_warning.modulate.a = 1.0


func popup(text: String, color := GOLD) -> void:
	_popup.text = text
	_popup.add_theme_color_override("font_color", color)
	_popup.visible = true
	_popup.modulate.a = 1.0
	_popup.position.y = 420.0


# ------------------------------------------------------------------ build

func _compute_safe_area() -> void:
	# iPhone notch / home bar. On desktop the window has no unsafe area.
	if not OS.has_feature("mobile"):
		return
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if win.y <= 0:
		return
	var k := 1280.0 / float(win.y) if win.x * 1280 > win.y * 720 else 720.0 / float(win.x)
	_safe_top = safe.position.y * k
	_safe_bottom = (win.y - safe.end.y) * k


func _build_theme() -> void:
	_theme.default_font_size = 36
	var normal := _box(ACCENT, 28)
	var hover := _box(ACCENT.lightened(0.12), 28)
	var pressed := _box(ACCENT.darkened(0.15), 28)
	_theme.set_stylebox("normal", "Button", normal)
	_theme.set_stylebox("hover", "Button", hover)
	_theme.set_stylebox("pressed", "Button", pressed)
	_theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	_theme.set_color("font_color", "Button", Color.WHITE)
	_theme.set_color("font_hover_color", "Button", Color.WHITE)
	_theme.set_color("font_pressed_color", "Button", Color.WHITE)
	_theme.set_font_size("font_size", "Button", 40)


func _box(color: Color, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.content_margin_left = 28
	s.content_margin_right = 28
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	s.shadow_color = Color(0, 0, 0, 0.25)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 4)
	return s


func _label(text: String, size: int, color := Color.WHITE, outline := 10) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = outline
	ls.outline_color = INK
	ls.shadow_size = 0
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, on_press: Callable, color := ACCENT) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(380, 100)
	if color != ACCENT:
		b.add_theme_stylebox_override("normal", _box(color, 28))
		b.add_theme_stylebox_override("hover", _box(color.lightened(0.12), 28))
		b.add_theme_stylebox_override("pressed", _box(color.darkened(0.15), 28))
	b.pressed.connect(func():
		Sfx.play("click")
		on_press.call())
	return b


func _coin_icon(size: float) -> Control:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(size, size)
	var s := StyleBoxFlat.new()
	s.bg_color = GOLD
	s.set_corner_radius_all(int(size / 2))
	s.border_color = Color("c98a00")
	s.set_border_width_all(int(size / 8))
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


func _full(parent: Control, n: String) -> Control:
	var c := Control.new()
	c.name = n
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c


func _dim(parent: Control, alpha: float) -> void:
	var d := ColorRect.new()
	d.color = Color(0.05, 0.08, 0.15, alpha)
	d.set_anchors_preset(Control.PRESET_FULL_RECT)
	d.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(d)


func _center_column(parent: Control, separation: int) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(center)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", separation)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(col)
	return col


func _build_run_ui(root: Control) -> void:
	_run_ui = _full(root, "RunUI")

	var pause := Button.new()
	pause.text = "II"
	pause.custom_minimum_size = Vector2(96, 96)
	pause.add_theme_stylebox_override("normal", _box(Color(0.09, 0.14, 0.23, 0.55), 22))
	pause.add_theme_stylebox_override("hover", _box(Color(0.09, 0.14, 0.23, 0.7), 22))
	pause.add_theme_stylebox_override("pressed", _box(Color(0.09, 0.14, 0.23, 0.85), 22))
	pause.position = Vector2(24, 24 + _safe_top)
	pause.pressed.connect(func(): pause_pressed.emit())
	_run_ui.add_child(pause)

	var right := VBoxContainer.new()
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.anchor_left = 1.0
	right.offset_left = -360
	right.offset_right = -24
	right.offset_top = 18 + _safe_top
	right.alignment = BoxContainer.ALIGNMENT_BEGIN
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_run_ui.add_child(right)

	_score = _label("0", 64)
	_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(_score)

	var coin_row := HBoxContainer.new()
	coin_row.alignment = BoxContainer.ALIGNMENT_END
	coin_row.add_theme_constant_override("separation", 10)
	coin_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_multiplier = _label("x2", 40, Color("37d67a"))
	coin_row.add_child(_multiplier)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(16, 0)
	coin_row.add_child(spacer)
	var icon := _coin_icon(40)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin_row.add_child(icon)
	_coins = _label("0", 44, GOLD)
	coin_row.add_child(_coins)
	right.add_child(coin_row)

	_powers = VBoxContainer.new()
	_powers.add_theme_constant_override("separation", 8)
	_powers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_powers)
	_power_bars["magnet"] = _power_bar("MAGNET", Color("e8313a"))
	_power_bars["double"] = _power_bar("x2 SCORE", Color("37d67a"))

	_warning = _label("", 52, Color("ffdf5e"), 12)
	_warning.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_warning.anchor_left = 0.0
	_warning.anchor_right = 1.0
	_warning.offset_top = 300 + _safe_top
	_warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning.visible = false
	_run_ui.add_child(_warning)

	_popup = _label("", 48, GOLD, 12)
	_popup.anchor_left = 0.0
	_popup.anchor_right = 1.0
	_popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_popup.visible = false
	_run_ui.add_child(_popup)


func _power_bar(title: String, color: Color) -> ProgressBar:
	var row := VBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 2)
	var l := _label(title, 26, color, 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(l)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.custom_minimum_size = Vector2(220, 16)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_END
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.35)
	bg.set_corner_radius_all(8)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(8)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)
	row.visible = false
	_powers.add_child(row)
	return bar


func _set_power(kind: String, frac: float) -> void:
	var bar: ProgressBar = _power_bars[kind]
	bar.get_parent().visible = frac > 0.0
	bar.value = frac


func _build_menu(root: Control) -> void:
	_menu = _full(root, "Menu")
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 150 + _safe_top
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	top.add_theme_constant_override("separation", -10)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(top)
	for line in ["LANE", "RUNNER"]:
		var t := _label(line, 120, Color.WHITE if line == "LANE" else GOLD, 22)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		top.add_child(t)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	top.add_child(gap)
	_menu_best = _label("BEST 0", 44)
	_menu_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_menu_best)
	var bank_row := HBoxContainer.new()
	bank_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bank_row.add_theme_constant_override("separation", 12)
	bank_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := _coin_icon(40)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bank_row.add_child(icon)
	_menu_bank = _label("0", 44, GOLD)
	bank_row.add_child(_menu_bank)
	top.add_child(bank_row)

	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -300 - _safe_bottom
	bottom.offset_bottom = -60 - _safe_bottom
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_theme_constant_override("separation", 16)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(bottom)
	_tap = _label("TAP TO RUN", 64, Color.WHITE, 14)
	_tap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_tap)
	var help := _label("Swipe  left / right  to change lanes\nSwipe  up  to jump  -  down  to slide", 30, Color.WHITE, 8)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(help)

	_menu_sound = Button.new()
	_menu_sound.custom_minimum_size = Vector2(200, 72)
	_menu_sound.add_theme_font_size_override("font_size", 30)
	_menu_sound.add_theme_stylebox_override("normal", _box(Color(0.09, 0.14, 0.23, 0.6), 22))
	_menu_sound.add_theme_stylebox_override("hover", _box(Color(0.09, 0.14, 0.23, 0.75), 22))
	_menu_sound.add_theme_stylebox_override("pressed", _box(Color(0.09, 0.14, 0.23, 0.9), 22))
	_menu_sound.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_menu_sound.offset_left = -224
	_menu_sound.offset_top = 24 + _safe_top
	_menu_sound.offset_right = -24
	_menu_sound.offset_bottom = 96 + _safe_top
	_menu_sound.pressed.connect(func(): sound_pressed.emit())
	_menu.add_child(_menu_sound)


func _build_pause(root: Control) -> void:
	_pause = _full(root, "Pause")
	_dim(_pause, 0.6)
	var col := _center_column(_pause, 24)
	var t := _label("PAUSED", 96, Color.WHITE, 18)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	col.add_child(_button("RESUME", func(): resume_pressed.emit()))
	_pause_sound = _button("SOUND: ON", func(): sound_pressed.emit(), Color("3d8fd6"))
	col.add_child(_pause_sound)
	col.add_child(_button("MENU", func(): menu_pressed.emit(), Color("5b6475")))
	_pause.visible = false


func _build_game_over(root: Control) -> void:
	_over = _full(root, "GameOver")
	_dim(_over, 0.55)
	var col := _center_column(_over, 14)
	var t := _label("GAME OVER", 92, Color.WHITE, 18)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	_over_new = _label("NEW BEST!", 52, GOLD, 12)
	_over_new.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_over_new)
	_over_score = _label("0", 130, Color.WHITE, 20)
	_over_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_over_score)
	var coin_row := HBoxContainer.new()
	coin_row.alignment = BoxContainer.ALIGNMENT_CENTER
	coin_row.add_theme_constant_override("separation", 12)
	coin_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := _coin_icon(44)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin_row.add_child(icon)
	_over_coins = _label("+0", 52, GOLD)
	coin_row.add_child(_over_coins)
	col.add_child(coin_row)
	_over_best = _label("BEST 0", 40)
	_over_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_over_best)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	col.add_child(gap)
	col.add_child(_button("RUN AGAIN", func(): restart_pressed.emit()))
	col.add_child(_button("MENU", func(): menu_pressed.emit(), Color("5b6475")))
	_over.visible = false


func _sound_text() -> String:
	return "SOUND: ON" if SaveData.sound_on else "SOUND: OFF"
