extends RefCounted
## The screens over a run (scenes/ui/panels.tscn), as in the web game: PAUSED, OUT OF LIVES (with the paid revive)
## and EPISODE CLEAR (grade stamp, stars, judgement counts, score and combo, chips, coins earned, missions,
## NEXT / RETRY / EPISODES). Run build_hud first: it writes the theme these use.

var theme: Theme


func build(_host: Node) -> void:
	theme = load("res://ui/theme.tres")
	var layer := CanvasLayer.new()
	layer.name = "Panels"
	layer.layer = 2
	var root := Control.new()
	root.name = "Root"
	root.theme = theme
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	layer.set_script(load("res://scripts/ui/panels.gd"))
	pause(root)
	over(root)
	clear(root)
	Kit.save(layer, "res://scenes/ui/panels.tscn")


# ------------------------------------------------------------------ helpers

func ctl(cls: String, name: String, parent: Node, uniq := true) -> Control:
	var c: Control = ClassDB.instantiate(cls)
	c.name = name
	parent.add_child(c)
	c.unique_name_in_owner = uniq
	return c


func lbl(name: String, parent: Node, text: String, variation: String, size := 0, color := Color(0, 0, 0, 0)) -> Label:
	var l := ctl("Label", name, parent) as Label
	l.text = text
	l.theme_type_variation = variation
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	if color.a > 0:
		l.add_theme_color_override("font_color", color)
	return l


func btn(name: String, parent: Node, text: String, variation: String) -> Button:
	var b := ctl("Button", name, parent) as Button
	b.text = text
	b.theme_type_variation = variation
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 46 if variation == "BigButton" else 40)
	return b


func overlay(name: String, parent: Node) -> VBoxContainer:
	## a full-screen wash (clear at the top, dark below, as the web game's .over) with a centred column that
	## scrolls on a short phone
	var o := ctl("Control", name, parent) as Control
	o.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	o.visible = false
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.36, 1.0])
	g.colors = PackedColorArray([Color(8 / 255.0, 6 / 255.0, 16 / 255.0, 0.15), Color(8 / 255.0, 6 / 255.0, 16 / 255.0, 0.8), Color(8 / 255.0, 6 / 255.0, 16 / 255.0, 0.92)])
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 256
	var wash := ctl("TextureRect", "Wash", o, false) as TextureRect
	wash.texture = gt
	wash.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wash.stretch_mode = TextureRect.STRETCH_SCALE
	wash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sc := ctl("ScrollContainer", "Scroll", o, false) as ScrollContainer
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var center := ctl("CenterContainer", "Center", sc, false) as CenterContainer
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var margin := ctl("MarginContainer", "Margin", center, false) as MarginContainer
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	var col := ctl("VBoxContainer", "Column", margin, false) as VBoxContainer
	col.custom_minimum_size = Vector2(354, 0)
	col.add_theme_constant_override("separation", 10)
	return col


func res_pair(parent: Node, a_name: String, a_label: String, b_name: String, b_label: String) -> void:
	var grid := ctl("GridContainer", "Res", parent, false) as GridContainer
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	for pair in [[a_name, a_label], [b_name, b_label]]:
		var p := ctl("PanelContainer", pair[0] + "Box", grid, false) as PanelContainer
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.add_theme_stylebox_override("panel", _box(Color(20 / 255.0, 14 / 255.0, 34 / 255.0, 0.75), 10, Vector2(10, 10)))
		var v := ctl("VBoxContainer", "V", p, false)
		v.add_theme_constant_override("separation", 0)
		lbl(pair[0] + "Label", v, pair[1], "Eyebrow", 10)
		lbl(pair[0], v, "0", "Title", 20)


func judgements(name: String, parent: Node) -> void:
	var grid := ctl("GridContainer", name, parent) as GridContainer
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	for c in [["Ex", "EXCELLENT", Color("ffd45c")], ["Gd", "GOOD", Color("8ff6ff")], ["Ok", "OK", Color("eceef2")], ["Miss", "MISSED", Color("ff8b95")]]:
		var p := ctl("PanelContainer", name + c[0] + "Box", grid, false) as PanelContainer
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.add_theme_stylebox_override("panel", _box(Color(20 / 255.0, 14 / 255.0, 34 / 255.0, 0.75), 10, Vector2(2, 6)))
		var v := ctl("VBoxContainer", "V", p, false)
		v.add_theme_constant_override("separation", 1)
		lbl(name + c[0], v, "0", "Title", 17, c[2])
		lbl(name + c[0] + "Label", v, c[1], "Eyebrow", 9)


func _box(c: Color, r: int, pad: Vector2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(r)
	s.content_margin_left = pad.x
	s.content_margin_right = pad.x
	s.content_margin_top = pad.y
	s.content_margin_bottom = pad.y
	return s


func note(name: String, parent: Node, gold := false) -> Label:
	var l := lbl(name, parent, "", "Muted", 12, Color("ffd45c") if gold else Color("e6dff2"))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(330, 0)
	return l


func title(name: String, parent: Node, text: String, glow: Color) -> Label:
	var l := lbl(name, parent, text, "Big", 34, Color.WHITE)
	l.add_theme_color_override("font_shadow_color", glow)
	l.add_theme_constant_override("shadow_outline_size", 14)
	l.add_theme_constant_override("shadow_offset_y", 0)
	l.add_theme_constant_override("shadow_offset_x", 0)
	return l


# ------------------------------------------------------------------ the three screens

func pause(root: Control) -> void:
	var col := overlay("Pause", root)
	title("PauseTitle", col, "PAUSED", Color(1, 1, 1, 0.5))
	note("PauseInfo", col)
	btn("Resume", col, "RESUME", "BigButton")
	var row := ctl("HBoxContainer", "Row", col, false)
	row.add_theme_constant_override("separation", 8)
	for b in [["Restart", "RESTART"], ["PauseMenu", "MAIN MENU"]]:
		btn(b[0], row, b[1], "GhostButton").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn("Sound", col, "SOUND ON", "GhostButton")


func over(root: Control) -> void:
	var col := overlay("Over", root)
	lbl("OverCity", col, "", "Eyebrow", 11)
	title("OverTitle", col, "OUT OF LIVES", Color("ff3d4f"))
	res_pair(col, "OverA", "SONG", "OverB", "COINS CAUGHT")
	judgements("OverJud", col)
	note("OverNote", col)
	note("OverEarn", col, true)
	ctl("VBoxContainer", "OverMis", col).add_theme_constant_override("separation", 5)
	btn("Revive", col, "REVIVE · 200", "BigButton")
	btn("Again", col, "TRY AGAIN", "BigButton")
	btn("ToMenu", col, "EPISODES", "GhostButton")


func clear(root: Control) -> void:
	var col := overlay("Clear", root)
	lbl("ClearCity", col, "", "Eyebrow", 11)
	title("ClearTitle", col, "EPISODE CLEAR", Color(1, 1, 1, 0.5))
	var rank := ctl("HBoxContainer", "Rank", col) as HBoxContainer
	rank.alignment = BoxContainer.ALIGNMENT_CENTER
	rank.add_theme_constant_override("separation", 18)
	var grade := ctl("PanelContainer", "Grade", rank) as PanelContainer
	grade.custom_minimum_size = Vector2(104, 104)
	grade.pivot_offset = Vector2(52, 52)
	var gs := _box(Color(20 / 255.0, 14 / 255.0, 34 / 255.0, 0.8), 26, Vector2(0, 0))
	gs.border_color = Color(1, 1, 1, 0.3)
	gs.set_border_width_all(2)
	grade.add_theme_stylebox_override("panel", gs)
	var gl := lbl("GradeLetter", grade, "S", "Big", 76, Color.WHITE)
	gl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var side := ctl("VBoxContainer", "Side", rank, false) as VBoxContainer
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	var stars := ctl("HBoxContainer", "Stars", side) as HBoxContainer
	stars.add_theme_constant_override("separation", 4)
	for i in 3:
		var s := lbl("Star%d" % i, stars, "★", "Big", 30, Color(1, 1, 1, 0.16))
		s.pivot_offset = Vector2(14, 18)
	var acc := lbl("ClearAcc", side, "0%", "Title", 22)
	acc.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var al := lbl("ClearAccLabel", side, "NOTES PLAYED", "Eyebrow", 10)
	al.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	judgements("ClearJud", col)
	res_pair(col, "ClearScore", "SCORE", "ClearCombo", "MAX COMBO")
	var chips := ctl("HFlowContainer", "ClearChips", col) as HFlowContainer
	chips.alignment = FlowContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("h_separation", 5)
	note("ClearNote", col)
	note("ClearEarn", col, true)
	ctl("VBoxContainer", "ClearMis", col).add_theme_constant_override("separation", 5)
	btn("NextEp", col, "NEXT EPISODE", "BigButton")
	var row := ctl("HBoxContainer", "Row", col, false)
	row.add_theme_constant_override("separation", 8)
	for b in [["RetryEp", "RETRY"], ["ClearMenu", "EPISODES"]]:
		btn(b[0], row, b[1], "GhostButton").size_flags_horizontal = Control.SIZE_EXPAND_FILL
