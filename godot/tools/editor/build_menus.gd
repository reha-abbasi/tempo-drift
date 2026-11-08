extends RefCounted
## The menus (scenes/ui/menus.tscn), laid out as the web game's, over the live city behind them:
##   Home: wallet, stars, change log, settings; the logo and welcome; the era tabs; PLAY; Flight School and
##   Endless; Garage, Missions and Scores. Then the episode map, the garage, missions, high scores, settings,
##   audio sync, the change log and the daily gift.
## Run build_hud first (it writes the theme).

const GOLD := Color("ffd45c")
const MUTED := Color("9097a6")
const SOFT := Color("d8d0ec")
const INK := Color(10 / 255.0, 8 / 255.0, 18 / 255.0)
const CARD := Color(20 / 255.0, 16 / 255.0, 30 / 255.0)

var theme: Theme


func build(_host: Node) -> void:
	theme = load("res://ui/theme.tres")
	var layer := CanvasLayer.new()
	layer.name = "Menus"
	layer.layer = 1
	var root := Control.new()
	root.name = "Root"
	root.theme = theme
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	layer.set_script(load("res://scripts/ui/menus.gd"))
	home(root)
	episodes(root)
	garage(root)
	missions(root)
	board(root)
	settings(root)
	sync(root)
	changes(root)
	gift(root)
	toast(root)
	Kit.save(layer, "res://scenes/ui/menus.tscn")


# ------------------------------------------------------------------ helpers

func ctl(cls: String, name: String, parent: Node, uniq := true) -> Control:
	var c: Control = ClassDB.instantiate(cls)
	c.name = name
	parent.add_child(c)
	c.unique_name_in_owner = uniq
	if c is Container or c is Label or c is TextureRect:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE if not (c is ScrollContainer) else Control.MOUSE_FILTER_PASS
	return c


func lbl(name: String, parent: Node, text: String, variation := "Body", size := 0, color := Color(0, 0, 0, 0), uniq := true) -> Label:
	var l := ctl("Label", name, parent, uniq) as Label
	l.text = text
	l.theme_type_variation = variation
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	if color.a > 0:
		l.add_theme_color_override("font_color", color)
	return l


func btn(name: String, parent: Node, text: String, variation := "GhostButton", h := 40) -> Button:
	var b := ctl("Button", name, parent) as Button
	b.text = text
	b.theme_type_variation = variation
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, h)
	return b


func box(c: Color, r: int, border := Color(0, 0, 0, 0), bw := 0, pad := Vector2(0, 0)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(r)
	s.border_color = border
	s.set_border_width_all(bw)
	s.content_margin_left = pad.x
	s.content_margin_right = pad.x
	s.content_margin_top = pad.y
	s.content_margin_bottom = pad.y
	s.anti_aliasing_size = 1.0
	return s


func panel(name: String, parent: Node, style: StyleBox, uniq := true) -> PanelContainer:
	var p := ctl("PanelContainer", name, parent, uniq) as PanelContainer
	p.add_theme_stylebox_override("panel", style)
	return p


func wash(parent: Node, stops: Array) -> void:
	## the web game's dark wash behind a menu: [offset, alpha] pairs from top to bottom
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for s in stops:
		offs.append(s[0])
		cols.append(Color(8 / 255.0, 6 / 255.0, 16 / 255.0, s[1]))
	g.offsets = offs
	g.colors = cols
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 4
	gt.height = 256
	var t := ctl("TextureRect", "Wash", parent, false) as TextureRect
	t.texture = gt
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func screen(name: String, parent: Node, stops: Array, pad := Vector4(16, 18, 16, 16)) -> VBoxContainer:
	var s := ctl("Control", name, parent) as Control
	s.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.visible = name == "Home"  # the screen the editor shows; the game switches screens itself
	wash(s, stops)
	var m := ctl("MarginContainer", "Margin", s, false) as MarginContainer
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", int(pad.x))
	m.add_theme_constant_override("margin_top", int(pad.y))
	m.add_theme_constant_override("margin_right", int(pad.z))
	m.add_theme_constant_override("margin_bottom", int(pad.w))
	var v := ctl("VBoxContainer", "Column", m, false) as VBoxContainer
	v.add_theme_constant_override("separation", 9)
	return v


func panel_screen(name: String, parent: Node, title: String) -> VBoxContainer:
	var v := screen(name, parent, [[0.0, 0.55], [0.3, 0.9], [1.0, 0.95]])
	var head := ctl("HBoxContainer", "Head", v, false) as HBoxContainer
	head.add_theme_constant_override("separation", 10)
	btn(name + "Back", head, "‹ BACK", "GhostButton", 34).custom_minimum_size.x = 84
	var t := lbl(name + "Title", head, title, "Title", 15)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tot := lbl(name + "Tot", head, "", "Eyebrow", 12, GOLD)
	tot.custom_minimum_size.x = 84
	tot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return v


func legend(name: String, parent: Node, text: String) -> Label:
	var l := lbl(name, parent, text, "Muted", 11, Color("c9c2d8"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func icon_rect(name: String, parent: Node, path: String, size: Vector2, tint := Color.WHITE) -> TextureRect:
	var t := ctl("TextureRect", name, parent, false) as TextureRect
	t.texture = load(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = size
	t.modulate = tint
	return t


func pill(name: String, parent: Node, text: String, color: Color, border: Color) -> PanelContainer:
	var p := panel(name, parent, box(Color(INK, 0.55), 99, border, 1, Vector2(11, 5)))
	var h := ctl("HBoxContainer", "Row", p, false)
	h.add_theme_constant_override("separation", 6)
	lbl(name + "Text", h, text, "Eyebrow", 13, color)
	return p


func scroll_list(name: String, parent: Node) -> VBoxContainer:
	var sc := ctl("ScrollContainer", name + "Scroll", parent, false) as ScrollContainer
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var v := ctl("VBoxContainer", name, sc) as VBoxContainer
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	return v


# ------------------------------------------------------------------ Home

func home(root: Control) -> void:
	var v := screen("Home", root, [[0.0, 0.55], [0.16, 0.0], [0.44, 0.0], [0.62, 0.7], [1.0, 0.94]], Vector4(16, 12, 16, 16))
	v.add_theme_constant_override("separation", 0)
	var top := ctl("HBoxContainer", "TopBar", v, false) as HBoxContainer
	top.add_theme_constant_override("separation", 8)
	var w := pill("Wallet", top, "0", GOLD, Color(1, 0.83, 0.36, 0.35))
	var row: Node = w.get_node("Row")
	var coin := icon_rect("Coin", row, "res://ui/icons/coin.svg", Vector2(13, 13))
	row.move_child(coin, 0)
	pill("StarTot", top, "★ 0/72", Color.WHITE, Color(1, 1, 1, 0.22))
	var sp := ctl("Control", "Gap", top, false)
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var log := btn("LogBtn", top, "✦ v31", "GhostButton", 30)
	log.add_theme_font_size_override("font_size", 12)
	log.add_theme_stylebox_override("normal", box(Color(INK, 0.55), 99, Color(1, 1, 1, 0.3), 1, Vector2(11, 5)))
	var gear := btn("SetBtn", top, "", "GhostButton", 34)
	gear.icon = load("res://ui/icons/gear.svg")
	gear.expand_icon = true
	gear.custom_minimum_size = Vector2(34, 34)
	gear.add_theme_stylebox_override("normal", box(Color(INK, 0.45), 99, Color(1, 1, 1, 0.22), 1, Vector2(7, 7)))
	var logo := lbl("Logo", v, "TEMPO DRIFT", "Logo", 34, Color("fff7ea"))
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_constant_override("shadow_outline_size", 16)
	logo.add_theme_color_override("font_shadow_color", Color(1.0, 0.7, 0.48, 0.6))
	logo.add_theme_constant_override("shadow_offset_y", 0)
	(ctl("Control", "LogoGap", v, false)).custom_minimum_size = Vector2(0, 24)
	v.move_child(v.get_node("LogoGap"), 1)
	var wel := panel("WelcomeBox", v, box(Color(INK, 0.35), 99, Color(0, 0, 0, 0), 0, Vector2(10, 3)))
	wel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lbl("Welcome", wel, "Welcome, pilot! Fly through time to the beat.", "Eyebrow", 12, Color("fff7ea"))
	ctl("Control", "Spacer", v, false).size_flags_vertical = Control.SIZE_EXPAND_FILL
	var sheet := ctl("VBoxContainer", "Sheet", v) as VBoxContainer
	sheet.add_theme_constant_override("separation", 10)
	# era tabs
	var eras := panel("Eras", sheet, box(Color(INK, 0.55), 99, Color(1, 1, 1, 0.12), 1, Vector2(4, 4)))
	eras.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var eh := ctl("HBoxContainer", "Row", eras, false)
	eh.add_theme_constant_override("separation", 4)
	for m in [["EraOld", "PAST"], ["EraSunset", "PRESENT"], ["EraRain", "FUTURE"]]:
		var b := btn(m[0], eh, m[1], "GhostButton", 30)
		b.add_theme_stylebox_override("normal", box(Color(0, 0, 0, 0), 99, Color(0, 0, 0, 0), 0, Vector2(16, 6)))
		b.add_theme_stylebox_override("hover", box(Color(1, 1, 1, 0.06), 99, Color(0, 0, 0, 0), 0, Vector2(16, 6)))
		b.add_theme_stylebox_override("pressed", box(Color(1, 1, 1, 0.1), 99, Color(0, 0, 0, 0), 0, Vector2(16, 6)))
		b.add_theme_color_override("font_color", MUTED)
	# era line: ‹ London 1890 → Rome 1948 / swing music ›
	var line := ctl("HBoxContainer", "EraLine", sheet, false) as HBoxContainer
	line.add_theme_constant_override("separation", 8)
	for n in ["EraPrev", "EraNext"]:
		var a := btn(n, line, "‹" if n == "EraPrev" else "›", "GhostButton", 34)
		a.custom_minimum_size = Vector2(34, 34)
		a.add_theme_font_size_override("font_size", 22)
		a.add_theme_stylebox_override("normal", box(Color(INK, 0.4), 99, Color(1, 1, 1, 0.25), 1))
		if n == "EraPrev":
			var info := ctl("VBoxContainer", "EraInfo", line, false) as VBoxContainer
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info.add_theme_constant_override("separation", 0)
			var s := lbl("EraSub", info, "London 1890 → Rome 1948", "Title", 14, Color.WHITE)
			s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var mu := lbl("EraMus", info, "1890–1955 · swing music", "Eyebrow", 11, SOFT)
			mu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var play := btn("Start", sheet, "▶ PLAY", "BigButton", 58)
	var pv := ctl("VBoxContainer", "PlayText", play, false) as VBoxContainer
	pv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	pv.add_theme_constant_override("separation", 0)
	play.text = ""
	var pl := lbl("PlayLabel", pv, "▶ PLAY", "Title", 17, Color("1a0a04"))
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var ps := lbl("PlaySub", pv, "choose a city · ★ 0/24", "Eyebrow", 11, Color(0.1, 0.04, 0.02, 0.75))
	ps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var seg := ctl("HBoxContainer", "Seg", sheet, false) as HBoxContainer
	seg.add_theme_constant_override("separation", 8)
	for s in [["ModeEp", "FLIGHT SCHOOL", "EpsSub", "learn the moves"], ["ModeInf", "ENDLESS", "InfSub", "no best yet"]]:
		var b := btn(s[0], seg, "", "GhostButton", 48)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_stylebox_override("normal", box(Color(INK, 0.5), 12, Color(1, 1, 1, 0.25), 1))
		var bv := ctl("VBoxContainer", "Text", b, false) as VBoxContainer
		bv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bv.alignment = BoxContainer.ALIGNMENT_CENTER
		bv.add_theme_constant_override("separation", 1)
		lbl(s[0] + "Label", bv, s[1], "Title", 13).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl(s[2], bv, s[3], "Eyebrow", 10, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tiles := ctl("HBoxContainer", "Tiles", sheet, false) as HBoxContainer
	tiles.add_theme_constant_override("separation", 8)
	for t in [["GarageBtn", "GARAGE", "res://ui/icons/garage.svg", Vector2(50, 22)], ["MisBtn", "MISSIONS", "res://ui/icons/missions.svg", Vector2(22, 22)], ["BoardBtn", "SCORES", "res://ui/icons/scores.svg", Vector2(22, 22)]]:
		var b := btn(t[0], tiles, "", "GhostButton", 58)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_stylebox_override("normal", box(Color(CARD, 0.7), 14, Color(1, 1, 1, 0.14), 1))
		var bv := ctl("VBoxContainer", "Text", b, false) as VBoxContainer
		bv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bv.alignment = BoxContainer.ALIGNMENT_CENTER
		bv.add_theme_constant_override("separation", 4)
		icon_rect("Icon", bv, t[2], t[3], Color("ffe2b8"))
		lbl(t[0] + "Label", bv, t[1], "Title", 11).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if t[0] == "MisBtn":
			var badge := panel("MisBadge", b, box(Color("ff5a6a"), 99))
			badge.custom_minimum_size = Vector2(8, 8)
			badge.position = Vector2(86, 6)
			badge.visible = false


# ------------------------------------------------------------------ the episode map

func episodes(root: Control) -> void:
	var v := screen("Eps", root, [[0.0, 0.55], [0.3, 0.9], [1.0, 0.95]])
	var head := ctl("HBoxContainer", "Head", v, false) as HBoxContainer
	head.add_theme_constant_override("separation", 10)
	btn("EpsBack", head, "‹ BACK", "GhostButton", 34).custom_minimum_size.x = 84
	var et := ctl("HBoxContainer", "EraTitle", head, false) as HBoxContainer
	et.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	et.alignment = BoxContainer.ALIGNMENT_CENTER
	et.add_theme_constant_override("separation", 8)
	for n in ["MapPrev", "EpsTitle", "MapNext"]:
		if n == "EpsTitle":
			lbl(n, et, "PAST", "Title", 15)
		else:
			var a := btn(n, et, "‹" if n == "MapPrev" else "›", "GhostButton", 28)
			a.custom_minimum_size = Vector2(28, 28)
			a.add_theme_font_size_override("font_size", 17)
			a.add_theme_stylebox_override("normal", box(Color(0, 0, 0, 0), 99, Color(1, 1, 1, 0.25), 1))
	var tot := lbl("EpsStars", head, "★ 0/24", "Eyebrow", 12, GOLD)
	tot.custom_minimum_size.x = 84
	tot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var frame := panel("WMapFrame", v, box(Color(0, 0, 0, 0), 14, Color(1, 1, 1, 0.14), 1))
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.custom_minimum_size = Vector2(0, 190)
	var wm := ctl("Control", "WMap", frame) as Control
	wm.clip_contents = true
	wm.set_script(load("res://scripts/ui/world_map.gd"))
	wm.mouse_filter = Control.MOUSE_FILTER_STOP
	# Flight School
	var school := btn("TutPin", v, "", "GhostButton", 44)
	school.add_theme_stylebox_override("normal", box(Color(CARD, 0.8), 12, Color(1, 1, 1, 0.14), 1))
	var sh := ctl("HBoxContainer", "Row", school, false) as HBoxContainer
	sh.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sh.offset_left = 8
	sh.offset_right = -12
	sh.add_theme_constant_override("separation", 10)
	var n := panel("TutBadge", sh, box(GOLD, 8))
	n.custom_minimum_size = Vector2(28, 28)
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lbl("TutStar", n, "✦", "Title", 14, Color.WHITE).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sv := ctl("VBoxContainer", "Text", sh, false) as VBoxContainer
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sv.alignment = BoxContainer.ALIGNMENT_CENTER
	sv.add_theme_constant_override("separation", 0)
	lbl("TutName", sv, "Flight School", "Title", 13)
	lbl("TutSub", sv, "learn the moves · about a minute", "Eyebrow", 10, MUTED)
	var ts := lbl("TutState", sh, "START HERE", "Eyebrow", 11, GOLD)
	ts.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# the chosen episode
	var card := panel("EpCard", v, box(Color(CARD, 0.86), 14, Color(1, 1, 1, 0.16), 1, Vector2(12, 11)))
	var cv := ctl("VBoxContainer", "V", card, false)
	cv.add_theme_constant_override("separation", 9)
	var ch := ctl("HBoxContainer", "Head", cv, false) as HBoxContainer
	ch.add_theme_constant_override("separation", 10)
	var num := panel("EcNumBox", ch, box(GOLD, 17))
	num.custom_minimum_size = Vector2(34, 34)
	var nl := lbl("EcNum", num, "1", "Title", 15, Color("140c06"))
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var cn := ctl("VBoxContainer", "Name", ch, false) as VBoxContainer
	cn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cn.add_theme_constant_override("separation", 0)
	lbl("EcName", cn, "London 1890", "Title", 16).clip_text = true
	lbl("EcSub", cn, "112 BPM · saloon piano", "Eyebrow", 11, MUTED).clip_text = true
	var st := ctl("VBoxContainer", "St", ch, false) as VBoxContainer
	st.alignment = BoxContainer.ALIGNMENT_CENTER
	st.add_theme_constant_override("separation", 0)
	lbl("EcStars", st, "", "Title", 15, GOLD).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl("EcGrade", st, "", "Eyebrow", 10, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	btn("EpPlay", cv, "PLAY EPISODE 1", "BigButton", 44)
	legend("EpsLegend", v, "★ clear the song · ★★ grade A (95% of the notes) · ★★★ grade S (99%, no crash). Clearing an episode opens the next; 10★ in an era opens the next era.")


# ------------------------------------------------------------------ the garage

func garage(root: Control) -> void:
	var v := screen("Garage", root, [[0.0, 0.6], [0.15, 0.0], [0.5, 0.0], [0.72, 0.88], [1.0, 0.95]])
	var head := ctl("HBoxContainer", "Head", v, false) as HBoxContainer
	head.add_theme_constant_override("separation", 10)
	btn("GarageBack", head, "‹ BACK", "GhostButton", 34).custom_minimum_size.x = 84
	var t := lbl("GarageTitle", head, "GARAGE", "Title", 15)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tot := lbl("GWallet", head, "0", "Eyebrow", 12, GOLD)
	tot.custom_minimum_size.x = 84
	tot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var tabs := ctl("HBoxContainer", "Tabs", v, false) as HBoxContainer
	tabs.add_theme_constant_override("separation", 8)
	for n in [["GtCars", "CARS"], ["GtPilots", "PILOTS"]]:
		btn(n[0], tabs, n[1], "GhostButton", 34).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var space := ctl("Control", "GSpace", v) as Control
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	space.mouse_filter = Control.MOUSE_FILTER_STOP
	var card := ctl("VBoxContainer", "GCard", v, false) as VBoxContainer
	card.add_theme_constant_override("separation", 9)
	var row := ctl("HBoxContainer", "Row", card, false) as HBoxContainer
	row.add_theme_constant_override("separation", 8)
	for n in ["CarPrev", "GName", "CarNext"]:
		if n == "GName":
			var g := ctl("VBoxContainer", n, row, false) as VBoxContainer
			g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			g.add_theme_constant_override("separation", 2)
			for l in [["CarName", "ARROW", "Title", 24, Color.WHITE], ["CarAbout", "", "Eyebrow", 11, Color("c9c2d8")], ["CarPerk", "", "Eyebrow", 11, Color("8ff6ff")], ["CarPrice", "", "Eyebrow", 12, GOLD]]:
				var x := lbl(l[0], g, l[1], l[2], l[3], l[4])
				x.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				x.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		else:
			var a := btn(n, row, "‹" if n == "CarPrev" else "›", "GhostButton", 44)
			a.custom_minimum_size = Vector2(40, 44)
			a.add_theme_font_size_override("font_size", 22)
	var dots := ctl("HBoxContainer", "CarDots", card) as HBoxContainer
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	dots.add_theme_constant_override("separation", 8)
	btn("CarAct", card, "YOUR CAR", "BigButton", 46)
	var r2 := ctl("HBoxContainer", "Row2", card, false) as HBoxContainer
	r2.add_theme_constant_override("separation", 8)
	btn("CarView", r2, "IN-GAME VIEW", "GhostButton", 40).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn("CarCoins", r2, "+5,000 COINS (DEV)", "GhostButton", 40).size_flags_horizontal = Control.SIZE_EXPAND_FILL


# ------------------------------------------------------------------ missions, scores, settings, sync, log

func missions(root: Control) -> void:
	var v := panel_screen("Missions", root, "MISSIONS")
	ctl("VBoxContainer", "MList", v).add_theme_constant_override("separation", 8)
	legend("MisLegend", v, "Three missions at a time. Finish one to earn its coins, and a harder one takes its place.")
	lbl("DailyLabel", v, "DAILY GIFT", "Eyebrow", 11, Color("c9c2d8"))
	legend("DailyNote", v, "")


func board(root: Control) -> void:
	var v := panel_screen("Board", root, "HIGH SCORES")
	var tabs := ctl("HBoxContainer", "BoardTabs", v) as HBoxContainer
	tabs.add_theme_constant_override("separation", 6)
	for n in [["TabOld", "Past"], ["TabSunset", "Present"], ["TabRain", "Future"]]:
		btn(n[0], tabs, n[1], "GhostButton", 34).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var list := scroll_list("BoardList", v)
	lbl("InfLabel", list, "ENDLESS · YOUR TOP 5", "Eyebrow", 11, Color("c9c2d8"))
	ctl("VBoxContainer", "BoardInf", list).add_theme_constant_override("separation", 7)
	lbl("EpsLabel", list, "EPISODES · STARS, BEST GRADE AND SCORE", "Eyebrow", 11, Color("c9c2d8"))
	ctl("VBoxContainer", "BoardEps", list).add_theme_constant_override("separation", 7)
	legend("BoardLegend", v, "Saved on this device.")


func settings(root: Control) -> void:
	var v := panel_screen("Settings", root, "SETTINGS")
	var list := ctl("VBoxContainer", "SetList", v) as VBoxContainer
	list.add_theme_constant_override("separation", 8)
	for r in [["SndMenu", "Sound", "music and effects", "SOUND ON"], ["SyncBtn", "Audio sync", "automatic", "SET UP"],
			["FxBtn", "Reduce effects", "no rain, fewer sparks, steadier view", "OFF"], ["HapBtn", "Haptics", "a buzz on catches and crashes", "HAPTICS ON"],
			["LevelBtn", "Endless difficulty", "how fast Endless gets", "NORMAL"], ["TutBtn", "Flight School", "replay the tutorial", "PLAY"],
			["DevBtn", "Dev mode", "opens every era and episode, test coins in the Garage", "ON"]]:
		var p := panel(r[0] + "Row", list, box(Color(CARD, 0.8), 12, Color(1, 1, 1, 0.12), 1, Vector2(12, 10)))
		var h := ctl("HBoxContainer", "H", p, false) as HBoxContainer
		h.add_theme_constant_override("separation", 10)
		var tv := ctl("VBoxContainer", "T", h, false) as VBoxContainer
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tv.add_theme_constant_override("separation", 2)
		lbl(r[0] + "Name", tv, r[1], "Title", 14)
		var sub := lbl(r[0] + "Sub", tv, r[2], "Eyebrow", 10, MUTED)
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var b := btn(r[0], h, r[3], "GhostButton", 36)
		b.custom_minimum_size.x = 112
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.add_theme_font_size_override("font_size", 12)
	legend("SetLegend", v, "Every note is a ring: swipe left and right to change lanes, up to hop, down to dive. Swipe just before the note for EXCELLENT. Everything is saved on this device.")


func sync(root: Control) -> void:
	var v := panel_screen("Sync", root, "AUDIO SYNC")
	legend("SyncLegend", v, "Use the speaker or headphones you play with. Press START, then tap the pad on every click you hear: four to warm up, then eight that count.")
	var pad := btn("SyncPad", v, "", "GhostButton", 200)
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pad.add_theme_stylebox_override("normal", box(Color(CARD, 0.88), 20, Color(1, 1, 1, 0.2), 1))
	pad.add_theme_stylebox_override("hover", box(Color(CARD, 0.88), 20, Color(1, 1, 1, 0.3), 1))
	pad.add_theme_stylebox_override("pressed", box(Color(0.45, 0.36, 0.2, 0.9), 20, Color(1, 0.83, 0.36, 0.6), 1))
	var pv := ctl("VBoxContainer", "Text", pad, false) as VBoxContainer
	pv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	lbl("SyncBig", pv, "START", "Big", 30).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl("SyncCount", pv, "12 clicks · about 8 seconds", "Eyebrow", 11, SOFT).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var res := ctl("VBoxContainer", "SyncRes", v, false) as VBoxContainer
	res.add_theme_constant_override("separation", 2)
	lbl("SyncResLabel", res, "SOUND DELAY", "Eyebrow", 10, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl("SyncVal", res, "AUTO", "Title", 22).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	legend("SyncNote", res, "")
	var r2 := ctl("HBoxContainer", "Row", v, false) as HBoxContainer
	r2.add_theme_constant_override("separation", 8)
	btn("SyncMinus", r2, "− 10 ms", "GhostButton").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn("SyncPlus", r2, "+ 10 ms", "GhostButton").size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn("SyncAuto", v, "USE AUTOMATIC", "GhostButton")


func changes(root: Control) -> void:
	var v := panel_screen("Changes", root, "CHANGE LOG")
	scroll_list("CLog", v)


func gift(root: Control) -> void:
	var g := ctl("Control", "Gift", root) as Control
	g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	g.visible = false
	g.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ctl("ColorRect", "Dim", g, false) as ColorRect
	dim.color = Color(6 / 255.0, 4 / 255.0, 12 / 255.0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var c := ctl("CenterContainer", "Center", g, false) as CenterContainer
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var cardbox := box(Color(CARD, 0.95), 20, Color(1, 0.83, 0.36, 0.45), 1, Vector2(18, 18))
	cardbox.shadow_color = Color(1, 0.7, 0.35, 0.35)
	cardbox.shadow_size = 30
	var card := panel("GiftCard", c, cardbox)
	card.custom_minimum_size = Vector2(290, 0)
	var v := ctl("VBoxContainer", "V", card, false) as VBoxContainer
	v.add_theme_constant_override("separation", 6)
	lbl("GiftTitle", v, "DAILY GIFT", "Eyebrow", 11, GOLD).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl("GiftDay", v, "DAY 1", "Big", 24, Color.WHITE).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var amt := ctl("HBoxContainer", "Amt", v, false) as HBoxContainer
	amt.alignment = BoxContainer.ALIGNMENT_CENTER
	amt.add_theme_constant_override("separation", 8)
	icon_rect("Coin", amt, "res://ui/icons/coin.svg", Vector2(34, 34))
	lbl("GiftAmt", amt, "+100", "Big", 40, GOLD)
	var nx := lbl("GiftNext", v, "", "Eyebrow", 12, SOFT)
	nx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn("GiftClaim", v, "CLAIM", "BigButton", 48)


func toast(root: Control) -> void:
	var t := panel("Toast", root, box(GOLD, 99, Color(0, 0, 0, 0), 0, Vector2(14, 6)))
	t.anchor_left = 0.5
	t.anchor_right = 0.5
	t.offset_top = 58
	t.offset_left = -150
	t.offset_right = 150
	t.visible = false
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := lbl("ToastText", t, "", "Eyebrow", 12, Color("1a0a04"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
