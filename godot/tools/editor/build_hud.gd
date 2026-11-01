extends RefCounted
## The run's HUD (scenes/ui/hud.tscn), laid out as the web game's: the progress line along the top, the score in
## the middle, lives (car, then jetpack) with the rescue meter on the left, the Flow meter and multiplier under the
## score, the combo, power-up chips on the right, coins and pause at the top right, call-outs, the timing word over
## the car, and the screen-edge glows (crash flash, last-life danger, Overdrive).
## Also writes the shared look (ui/theme.tres): the web game's colours and type.

const BG := Color("0b0c10")
const FG := Color("eceef2")
const MUTED := Color("9097a6")
const AMBER := Color("ffb347")
const PINK := Color("ff3fb4")
const CYAN := Color("2ef2ff")
const RED := Color("ff3d4f")
const GOLD := Color("ffd45c")
const SOFT := Color("efe9f8")
const INK := Color(10 / 255.0, 8 / 255.0, 18 / 255.0)

var theme: Theme
var display: FontVariation
var display_italic: FontVariation
var body: FontVariation
var mono: FontVariation


func build(_host: Node) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/ui"))
	_fonts()
	_theme()
	hud()


func _font(path: String, name: String, weight: int, spacing := 0, slant := 0.0) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = load(path)
	f.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	f.spacing_glyph = spacing
	if slant != 0.0:
		f.variation_transform = Transform2D(Vector2(1, 0), Vector2(slant, 1), Vector2.ZERO)
	ResourceSaver.save(f, "res://ui/font_%s.tres" % name)
	return load("res://ui/font_%s.tres" % name)


func _fonts() -> void:
	# the web game sets Chakra Petch (display), IBM Plex Sans and Plex Mono; Outfit stands in for all three here
	display = _font("res://fonts/Outfit.ttf", "display", 700)
	display_italic = _font("res://fonts/Outfit.ttf", "display_italic", 700, 0, -0.18)
	body = _font("res://fonts/Outfit.ttf", "body", 450)
	mono = _font("res://fonts/Outfit.ttf", "mono", 500, 1)


func box(bg: Color, radius: int, border := Color(0, 0, 0, 0), bw := 0, pad := Vector2(0, 0)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.content_margin_left = pad.x
	s.content_margin_right = pad.x
	s.content_margin_top = pad.y
	s.content_margin_bottom = pad.y
	s.anti_aliasing_size = 1.0
	return s


func grad_box(a: Color, b: Color, radius: int, pad: Vector2) -> StyleBoxTexture:
	## a gradient fill with rounded corners (the web game's gold-to-coral buttons)
	var img := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 64:
			var r := float(radius)
			var dx := maxf(0.0, maxf(r - x, x - (63 - r)))
			var dy := maxf(0.0, maxf(r - y, y - (31 - r)))
			var inside := clampf(r + 0.5 - sqrt(dx * dx + dy * dy), 0.0, 1.0) if dx > 0 and dy > 0 else 1.0
			var c := a.lerp(b, x / 63.0)
			c.a = inside
			img.set_pixel(x, y, c)
	var st := StyleBoxTexture.new()
	st.texture = ImageTexture.create_from_image(img)
	st.texture_margin_left = r_of(radius)
	st.texture_margin_right = r_of(radius)
	st.texture_margin_top = r_of(radius)
	st.texture_margin_bottom = r_of(radius)
	st.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	st.content_margin_left = pad.x
	st.content_margin_right = pad.x
	st.content_margin_top = pad.y
	st.content_margin_bottom = pad.y
	return st


func r_of(radius: int) -> float:
	return float(radius) + 1.0


func label_type(name: String, font: Font, size: int, color: Color, shadow := true) -> void:
	theme.add_type(name)
	theme.set_type_variation(name, "Label")
	theme.set_font("font", name, font)
	theme.set_font_size("font_size", name, size)
	theme.set_color("font_color", name, color)
	if shadow:
		theme.set_color("font_shadow_color", name, Color(0, 0, 0, 0.55))
		theme.set_constant("shadow_offset_y", name, 1)
		theme.set_constant("shadow_outline_size", name, 3)


func _theme() -> void:
	theme = Theme.new()
	theme.default_font = body
	theme.default_font_size = 15
	theme.set_color("font_color", "Label", FG)
	# HUD text
	label_type("HudScore", display, 28, Color.WHITE)
	label_type("HudSmall", mono, 11, SOFT)
	label_type("HudTiny", mono, 9, Color(SOFT, 0.8))
	label_type("HudMult", display, 15, GOLD)
	label_type("HudCombo", mono, 12, SOFT)
	label_type("HudCoins", display, 15, Color("ffe7a6"), false)
	label_type("HudChip", mono, 10, Color("1a0a04"), false)
	label_type("HudMel", mono, 10, Color("ff8b95"), false)
	label_type("HudMode", mono, 12, Color.WHITE, false)
	label_type("Judge", display_italic, 21, Color.WHITE)
	label_type("Pop", display_italic, 21, Color.WHITE)
	for t in ["Judge", "Pop"]:
		theme.set_color("font_outline_color", t, Color(0, 0, 0, 0.75))
		theme.set_constant("outline_size", t, 5)
		theme.set_color("font_shadow_color", t, Color(0, 0, 0, 0.45))
		theme.set_constant("shadow_offset_y", t, 2)
	# menu text (used by the menus)
	label_type("Logo", display, 40, Color.WHITE)
	label_type("Title", display, 20, FG)
	label_type("Body", body, 15, FG, false)
	label_type("Muted", body, 13, MUTED, false)
	label_type("Eyebrow", mono, 11, MUTED, false)
	label_type("Big", display, 30, FG)
	# buttons: quiet by default, the play button big and gold
	theme.set_font("font", "Button", display)
	theme.set_font_size("font_size", "Button", 15)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		theme.set_color(c, "Button", FG)
	theme.set_color("font_disabled_color", "Button", Color(FG, 0.35))
	theme.set_stylebox("normal", "Button", box(Color(1, 1, 1, 0.06), 12, Color(1, 1, 1, 0.16), 1, Vector2(14, 10)))
	theme.set_stylebox("hover", "Button", box(Color(1, 1, 1, 0.12), 12, Color(1, 1, 1, 0.3), 1, Vector2(14, 10)))
	theme.set_stylebox("pressed", "Button", box(Color(1, 1, 1, 0.2), 12, Color(1, 1, 1, 0.4), 1, Vector2(14, 10)))
	theme.set_stylebox("disabled", "Button", box(Color(1, 1, 1, 0.03), 12, Color(1, 1, 1, 0.08), 1, Vector2(14, 10)))
	theme.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	theme.add_type("BigButton")
	theme.set_type_variation("BigButton", "Button")
	theme.set_font_size("font_size", "BigButton", 17)
	for c in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		theme.set_color(c, "BigButton", Color("1a0a04"))
	theme.set_stylebox("normal", "BigButton", grad_box(GOLD, Color("ff9a6b"), 12, Vector2(13, 13)))
	theme.set_stylebox("hover", "BigButton", grad_box(GOLD.lightened(0.1), Color("ff9a6b").lightened(0.1), 12, Vector2(13, 13)))
	theme.set_stylebox("pressed", "BigButton", grad_box(GOLD.darkened(0.1), Color("ff9a6b").darkened(0.1), 12, Vector2(13, 13)))
	theme.set_stylebox("disabled", "BigButton", box(Color(1, 1, 1, 0.1), 12, Color(1, 1, 1, 0.1), 1, Vector2(13, 13)))
	theme.set_color("font_disabled_color", "BigButton", Color(FG, 0.5))
	theme.add_type("GhostButton")
	theme.set_type_variation("GhostButton", "Button")
	theme.set_font_size("font_size", "GhostButton", 13)
	theme.set_stylebox("normal", "GhostButton", box(Color(0, 0, 0, 0), 12, Color(1, 1, 1, 0.25), 1, Vector2(6, 10)))
	theme.set_stylebox("hover", "GhostButton", box(Color(1, 1, 1, 0.06), 12, Color(1, 1, 1, 0.4), 1, Vector2(6, 10)))
	theme.set_stylebox("pressed", "GhostButton", box(Color(1, 1, 1, 0.12), 12, Color(GOLD, 0.6), 1, Vector2(6, 10)))
	theme.set_stylebox("disabled", "GhostButton", box(Color(0, 0, 0, 0), 12, Color(1, 1, 1, 0.1), 1, Vector2(6, 10)))
	# panels and meters
	theme.add_type("Sheet")
	theme.set_type_variation("Sheet", "PanelContainer")
	var sheet := box(Color(BG, 0.92), 22, Color(1, 1, 1, 0.08), 1, Vector2(16, 16))
	theme.set_stylebox("panel", "Sheet", sheet)
	theme.add_type("Card")
	theme.set_type_variation("Card", "PanelContainer")
	theme.set_stylebox("panel", "Card", box(Color("12141a"), 14, Color("242833"), 1, Vector2(14, 12)))
	theme.add_type("Chip")
	theme.set_type_variation("Chip", "PanelContainer")
	var chip := StyleBoxFlat.new()
	chip.set_corner_radius_all(99)
	chip.bg_color = GOLD
	chip.content_margin_left = 8
	chip.content_margin_right = 8
	chip.content_margin_top = 2
	chip.content_margin_bottom = 2
	theme.set_stylebox("panel", "Chip", chip)
	theme.set_stylebox("background", "ProgressBar", box(Color(INK, 0.55), 3, Color(1, 1, 1, 0.2), 1))
	theme.set_stylebox("fill", "ProgressBar", box(GOLD, 3))
	ResourceSaver.save(theme, "res://ui/theme.tres")
	theme = load("res://ui/theme.tres")


# ------------------------------------------------------------------ helpers

func ctl(cls: String, name: String, parent: Node, uniq := true) -> Control:
	var c: Control = ClassDB.instantiate(cls)
	c.name = name
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	c.unique_name_in_owner = uniq
	return c


func lbl(name: String, parent: Node, text: String, variation: String, uniq := true) -> Label:
	var l := ctl("Label", name, parent, uniq) as Label
	l.text = text
	l.theme_type_variation = variation
	return l


func at_top_center(c: Control, top: float, w := 300.0, h := 30.0) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.offset_left = -w / 2
	c.offset_right = w / 2
	c.offset_top = top
	c.offset_bottom = top + h


func icon(path: String) -> Texture2D:
	return load(path)


func meter(name: String, parent: Node, w: float, h: float, a: Color, b: Color) -> ProgressBar:
	## a slim meter with a gradient fill (the web game's bars)
	var p := ctl("ProgressBar", name, parent) as ProgressBar
	p.show_percentage = false
	p.custom_minimum_size = Vector2(w, h)
	p.max_value = 100
	var g := Gradient.new()
	g.set_color(0, a)
	g.set_color(1, b)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 64
	gt.height = 4
	var fill := StyleBoxTexture.new()
	fill.texture = gt
	p.add_theme_stylebox_override("fill", fill)
	p.add_theme_stylebox_override("background", box(Color(INK, 0.55), int(h / 2), Color(1, 1, 1, 0.22), 1))
	return p


func edge(name: String, parent: Node, color: Color, inner := 0.55) -> ColorRect:
	## a glow round the screen edges in one colour (crash flash, danger, Overdrive)
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform vec4 tint : source_color;
uniform float inner = 0.55;
uniform float wash = 0.0;
void fragment() {
	vec2 d = abs(UV - 0.5) * 2.0;
	float e = smoothstep(inner, 1.0, max(d.x * 0.9, d.y * 0.97));
	COLOR = vec4(tint.rgb, clamp(tint.a * e + wash, 0.0, 1.0));
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("tint", color)
	m.set_shader_parameter("inner", inner)
	var r := ctl("ColorRect", name, parent) as ColorRect
	r.material = m
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.modulate.a = 0.0
	return r


# ------------------------------------------------------------------ the HUD

func hud() -> void:
	var root := Control.new()
	root.name = "HUD"
	root.theme = theme
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_script(load("res://scripts/ui/hud.gd"))
	var layer := CanvasLayer.new()
	layer.name = "HUDLayer"
	layer.add_child(root)

	edge("Flash", root, Color(1.0, 0.16, 0.24, 0.9), 0.35)
	edge("Danger", root, Color(1.0, 0.16, 0.24, 0.55), 0.5)
	edge("OdGlow", root, PINK, 0.45)

	# progress line
	var prog := meter("Progress", root, 0, 3, GOLD, PINK)
	prog.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	prog.offset_bottom = 3
	prog.add_theme_stylebox_override("background", box(Color(1, 1, 1, 0.14), 0))

	# score
	var score := lbl("Score", root, "0", "HudScore")
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	at_top_center(score, 8, 220, 36)

	# lives: CAR / JETPACK, the two icons, the rescue meter
	var forms := ctl("VBoxContainer", "Forms", root) as VBoxContainer
	forms.position = Vector2(14, 16)
	forms.add_theme_constant_override("separation", 3)
	lbl("FormLabel", forms, "CAR", "HudSmall")
	var fis := ctl("HBoxContainer", "Icons", forms) as HBoxContainer
	fis.add_theme_constant_override("separation", 5)
	for f in [["CarIcon", "res://ui/icons/car.svg", Vector2(34, 15)], ["JetIcon", "res://ui/icons/jetpack.svg", Vector2(16, 16)]]:
		var chipbox := ctl("PanelContainer", f[0], fis) as PanelContainer
		chipbox.custom_minimum_size = Vector2(0, 22)
		chipbox.add_theme_stylebox_override("panel", box(Color(INK, 0.5), 6, Color(1, 1, 1, 0.22), 1, Vector2(4, 3)))
		var tr := ctl("TextureRect", "Icon", chipbox, false) as TextureRect
		tr.texture = icon(f[1])
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = f[2]
	var rescue := meter("Rescue", forms, 96, 6, Color("ffc44a"), Color("fff0b0"))
	rescue.visible = false
	var rs := lbl("RescueLabel", forms, "RESCUE", "HudTiny")
	rs.visible = false

	# Flow: label, meter with marks at 30 / 60 / 90, multiplier
	var flow := ctl("HBoxContainer", "Flow", root) as HBoxContainer
	flow.alignment = BoxContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("separation", 7)
	at_top_center(flow, 44, 220, 18)
	lbl("FlowLabel", flow, "FLOW", "HudSmall")
	var fb := meter("FlowBar", flow, 104, 6, GOLD, Color("ff9a6b"))
	fb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for k in [0.3, 0.6, 0.9]:
		var s := ctl("ColorRect", "Mark%d" % int(k * 100), fb, false) as ColorRect
		s.color = Color(1, 1, 1, 0.45)
		s.position = Vector2(104 * k, -2)
		s.size = Vector2(1, 10)
	var mult := lbl("Mult", flow, "×1", "HudMult")
	mult.custom_minimum_size = Vector2(30, 0)
	mult.pivot_offset = Vector2(10, 10)

	var combo := lbl("Combo", root, "", "HudCombo")
	combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	at_top_center(combo, 66, 220, 18)

	var mel := ctl("PanelContainer", "Mel", root) as PanelContainer
	mel.add_theme_stylebox_override("panel", box(Color(INK, 0.55), 99, Color(1, 0.36, 0.36, 0.75), 1, Vector2(10, 3)))
	at_top_center(mel, 86, 250, 20)
	var ml := lbl("MelText", mel, "MELODY LOST · PLAY A NOTE TO BRING IT BACK", "HudMel")
	ml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mel.visible = false

	var ep := lbl("EpLabel", root, "EPISODE 1 · LONDON 1890", "HudTiny")
	ep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	at_top_center(ep, 90, 300, 14)

	# power-ups, top right
	var puh := ctl("VBoxContainer", "PowerUps", root) as VBoxContainer
	puh.anchor_left = 1.0
	puh.anchor_right = 1.0
	puh.offset_left = -150
	puh.offset_right = -10
	puh.offset_top = 60
	puh.alignment = BoxContainer.ALIGNMENT_BEGIN
	puh.add_theme_constant_override("separation", 4)

	# coins and pause
	var coins := ctl("PanelContainer", "Coins", root) as PanelContainer
	coins.add_theme_stylebox_override("panel", box(Color(INK, 0.5), 99, Color(1.0, 0.83, 0.36, 0.35), 1, Vector2(9, 5)))
	coins.anchor_left = 1.0
	coins.anchor_right = 1.0
	coins.offset_left = -150
	coins.offset_right = -60
	coins.offset_top = 12
	coins.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var crow := ctl("HBoxContainer", "Row", coins, false) as HBoxContainer
	crow.alignment = BoxContainer.ALIGNMENT_END
	crow.add_theme_constant_override("separation", 6)
	var ci := ctl("TextureRect", "Coin", crow, false) as TextureRect
	ci.texture = icon("res://ui/icons/coin.svg")
	ci.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ci.custom_minimum_size = Vector2(17, 17)
	ci.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lbl("CoinN", crow, "0", "HudCoins")
	var pause := ctl("Button", "Pause", root) as Button
	pause.mouse_filter = Control.MOUSE_FILTER_STOP
	pause.focus_mode = Control.FOCUS_NONE
	pause.icon = icon("res://ui/icons/pause.svg")
	pause.expand_icon = true
	pause.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause.anchor_left = 1.0
	pause.anchor_right = 1.0
	pause.offset_left = -52
	pause.offset_right = -8
	pause.offset_top = 6
	pause.offset_bottom = 50
	for st in ["normal", "hover", "pressed"]:
		pause.add_theme_stylebox_override(st, box(Color(INK, 0.45 if st == "normal" else 0.7), 22, Color(1, 1, 1, 0.22), 1, Vector2(12, 12)))

	# call-outs (one at a time), the timing word over the car, hints at the bottom
	var pops := lbl("Pop", root, "", "Pop")
	pops.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	at_top_center(pops, 118, 380, 60)
	pops.pivot_offset = Vector2(190, 26)
	var judge := lbl("Judge", root, "", "Judge")
	judge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	judge.size = Vector2(240, 30)
	judge.pivot_offset = Vector2(120, 15)
	judge.modulate.a = 0.0
	var mode := ctl("PanelContainer", "Hint", root) as PanelContainer
	mode.add_theme_stylebox_override("panel", box(Color(INK, 0.6), 12, Color(0, 0, 0, 0), 0, Vector2(12, 6)))
	mode.anchor_left = 0.5
	mode.anchor_right = 0.5
	mode.anchor_top = 1.0
	mode.anchor_bottom = 1.0
	mode.offset_left = -170
	mode.offset_right = 170
	mode.offset_top = -86
	mode.offset_bottom = -50
	var mt := lbl("HintText", mode, "", "HudMode")
	mt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mode.visible = false
	# Flight School's prompt: the move to make, while the world waits for it
	var tut := ctl("PanelContainer", "Tut", root) as PanelContainer
	tut.add_theme_stylebox_override("panel", box(Color(INK, 0.62), 18, Color(1.0, 0.83, 0.36, 0.5), 1, Vector2(22, 14)))
	tut.anchor_left = 0.5
	tut.anchor_right = 0.5
	tut.anchor_top = 0.26
	tut.anchor_bottom = 0.26
	tut.offset_left = -90
	tut.offset_right = 90
	tut.offset_top = -62
	tut.offset_bottom = 62
	tut.visible = false
	var tv := ctl("VBoxContainer", "V", tut, false) as VBoxContainer
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	var arrow := lbl("TutArrow", tv, "↑", "Pop")
	arrow.add_theme_font_size_override("font_size", 64)
	arrow.add_theme_color_override("font_color", GOLD)
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tt := lbl("TutText", tv, "SWIPE UP", "HudMode")
	tt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Kit.save(layer, "res://scenes/ui/hud.tscn")
