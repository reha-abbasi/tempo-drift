extends CanvasLayer
## The menus, with the web game's words and rules. The live city behind them is the main scene's Backdrop (a run
## in menu mode); changing era swaps it, and the garage turns its camera round the car.

const RUN := "res://scenes/run/run.tscn"
const CAR_KEYS := ["arrow", "bubble", "retro", "spinner", "manta"]
const PILOT_KEYS := ["astro", "testpilot", "racer", "robot", "fox", "ninja", "mech"]
const LEVELS := ["normal", "hard"]
const ERA_K := {"old": Color("e8c38a"), "sunset": Color("ffb37a"), "rain": Color("ff3fb4")}

var main: Node
var key := "old"
var ep_sel := -1
var board_map := "old"
var g_tab := "cars"
var g_i := 0
var _toast_t := 0.0
var _sync_taps: Array = []
var _sync_t0 := -1.0
var _sync_clicks: Array = []


func _ready() -> void:
	main = get_parent()
	key = Save.data.get("map", "old")
	# home
	%LogBtn.pressed.connect(func(): open("Changes"))
	%SetBtn.pressed.connect(func(): open("Settings"))
	for m in [["EraOld", "old"], ["EraSunset", "sunset"], ["EraRain", "rain"]]:
		get_node("%" + m[0]).pressed.connect(set_era.bind(m[1]))
	%EraPrev.pressed.connect(func(): cycle_era(-1))
	%EraNext.pressed.connect(func(): cycle_era(1))
	%Start.pressed.connect(func(): ep_sel = -1; open("Eps"))
	%ModeEp.pressed.connect(_school)
	%ModeInf.pressed.connect(_endless)
	%GarageBtn.pressed.connect(func(): open("Garage"))
	%MisBtn.pressed.connect(func(): open("Missions"))
	%BoardBtn.pressed.connect(func(): open("Board"))
	# panels
	for p in ["Eps", "Garage", "Missions", "Board", "Settings", "Changes"]:
		get_node("%" + p + "Back").pressed.connect(func(): open("Home"))
	%SyncBack.pressed.connect(func(): open("Settings"))
	%MapPrev.pressed.connect(func(): ep_sel = -1; cycle_era(-1); _render_eps())
	%MapNext.pressed.connect(func(): ep_sel = -1; cycle_era(1); _render_eps())
	%WMap.picked.connect(_pick)
	%EpPlay.pressed.connect(_ep_play)
	%TutPin.pressed.connect(_school)
	%GtCars.pressed.connect(func(): g_tab = "cars"; g_i = CAR_KEYS.find(Save.data.car); _render_garage())
	%GtPilots.pressed.connect(func(): g_tab = "pilots"; g_i = PILOT_KEYS.find(Save.data.pilot); _render_garage())
	%CarPrev.pressed.connect(func(): g_i -= 1; _render_garage())
	%CarNext.pressed.connect(func(): g_i += 1; _render_garage())
	%CarAct.pressed.connect(_garage_act)
	%CarView.pressed.connect(func(): main.toggle_garage_view(); _render_garage())
	%CarCoins.pressed.connect(func(): Save.add_coins(5000); _render_garage())
	for t in [["TabOld", "old"], ["TabSunset", "sunset"], ["TabRain", "rain"]]:
		get_node("%" + t[0]).pressed.connect(func(): board_map = t[1]; _render_board())
	%SndMenu.pressed.connect(_toggle.bind("sound"))
	%FxBtn.pressed.connect(_toggle.bind("fx_low"))
	%HapBtn.pressed.connect(_toggle.bind("haptics"))
	%DevBtn.pressed.connect(_toggle.bind("dev"))
	%LevelBtn.pressed.connect(func(): Save.set_setting("level", LEVELS[(LEVELS.find(Save.setting("level")) + 1) % 2]); _render_settings())
	%TutBtn.pressed.connect(_school)
	%SyncBtn.pressed.connect(func(): open("Sync"))
	%SyncPad.button_down.connect(_sync_tap)
	%SyncMinus.pressed.connect(func(): _cal(-0.01))
	%SyncPlus.pressed.connect(func(): _cal(0.01))
	%SyncAuto.pressed.connect(func(): Save.set_setting("cal", null); _render_sync())
	%GiftClaim.pressed.connect(_claim)
	open("Home")


func _backdrop() -> Node:
	## the garage's view of the car: the rooftop showroom, or the street's in-game view
	return main.garage_view() if main.has_method("garage_view") else main.backdrop


func _process(delta: float) -> void:
	if _toast_t > 0.0:
		_toast_t -= delta
		%Toast.visible = _toast_t > 0.0
	if $Root/Sync.visible and _sync_t0 >= 0.0:
		_sync_step()


func toast(text: String) -> void:
	%ToastText.text = text
	%Toast.visible = true
	_toast_t = 2.4


# ------------------------------------------------------------------ navigation

func open(screen: String) -> void:
	if main.has_method("screen"):
		main.screen(screen)
	for s in ["Home", "Eps", "Garage", "Missions", "Board", "Settings", "Sync", "Changes"]:
		$Root.get_node(s).visible = s == screen
	if _backdrop() and not _backdrop() is Rooftop:
		_backdrop().set_garage(false)
		_backdrop().menu_look = -1.1 if screen == "Home" else -0.7
	match screen:
		"Home":
			_render_home()
			_gift()
		"Eps":
			_render_eps()
		"Garage":
			g_tab = "cars"
			g_i = CAR_KEYS.find(Save.data.car)
			_render_garage()
			if not _backdrop() is Rooftop:
				_backdrop().set_garage(true)
		"Missions":
			_render_missions()
		"Board":
			board_map = key
			_render_board()
		"Settings":
			_render_settings()
		"Sync":
			_render_sync()
		"Changes":
			_render_log()


func set_era(m: String) -> void:
	if m == key:
		return
	key = m
	Save.data.map = m
	Save.write()
	main.show_era(m)
	_render_home()


func cycle_era(d: int) -> void:
	var i := (Catalog.MAPS.find(key) + d + 3) % 3
	set_era(Catalog.MAPS[i])


func _play(m: String, i: int) -> void:
	Launch.episode(m, i)
	get_tree().change_scene_to_file(RUN)


func _school() -> void:
	Launch.mode = "school"
	Launch.map = key
	Launch.index = 0
	if not ResourceLoader.exists("res://data/school.json"):
		toast("FLIGHT SCHOOL IS COMING IN THE NEXT BUILD")
		return
	get_tree().change_scene_to_file(RUN)


func _endless() -> void:
	Launch.mode = "endless"
	Launch.map = key
	Launch.index = 0
	if not ResourceLoader.exists("res://data/endless_%s.json" % key):
		toast("ENDLESS IS COMING IN THE NEXT BUILD")
		return
	get_tree().change_scene_to_file(RUN)


# ------------------------------------------------------------------ home

func _render_home() -> void:
	var E := Catalog.episodes(key)
	var era: Dictionary = Catalog.ERAS[key]
	%EraSub.text = "%s → %s" % [Catalog.city_of(E[0].name), Catalog.city_of(E[-1].name)]
	%EraMus.text = "%s · %s music" % [era.years, era.music]
	%PlaySub.text = "choose a city · ★ %d/24" % Save.map_stars(key)
	var open := Save.era_open(key)
	var k := Catalog.MAPS.find(key)
	%Start.disabled = not open
	%ModeInf.disabled = not open
	%PlayLabel.text = "▶ PLAY" if open else "🔒 LOCKED"
	if not open:
		var prev: String = Catalog.MAPS[k - 1]
		%PlaySub.text = "Earn %d more ★ in the %s to open" % [Catalog.ERA_NEED - Save.map_stars(prev), Catalog.ERAS[prev].name]
	%EpsSub.text = "✓ done · replay" if Save.data.tut else "learn the moves"
	var best: Array = Save.data.endless.get(key, [])
	%InfSub.text = "best %s" % _commas(int(best[0].s)) if best.size() > 0 else "no best yet"
	%StarTotText.text = "★ %d/72" % Save.total_stars()
	%WalletText.text = _commas(Save.wallet())
	# the version on the pill is always the newest entry of the change log, so it can never show an old number
	var log_top: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/changelog.json"))
	%LogBtn.text = "✦ v%s" % log_top[0].v
	for m in [["EraOld", "old"], ["EraSunset", "sunset"], ["EraRain", "rain"]]:
		var b: Button = get_node("%" + m[0])
		var on: bool = m[1] == key
		var c: Color = ERA_K[m[1]]
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(99)
		sb.content_margin_left = 16
		sb.content_margin_right = 16
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		sb.bg_color = c if on else Color(0, 0, 0, 0)
		if on:
			sb.shadow_color = Color(c, 0.5)
			sb.shadow_size = 9
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_color_override("font_color", Color("140c06") if on else Color("9097a6"))
		b.add_theme_color_override("font_hover_color", Color("140c06") if on else Color.WHITE)
	%Logo.add_theme_color_override("font_shadow_color", Color(ERA_K[key], 0.7))
	var ms := Save.missions()
	var half := false
	for a in ms.active:
		if int(a.prog) >= Save.mission_goal(a) / 2.0:
			half = true
	%MisBadge.visible = half


func _gift() -> void:
	var g := Save.gift_today()
	if g.is_empty():
		%Gift.visible = false
		return
	%GiftDay.text = "DAY %d%s" % [g.streak, " IN A ROW" if g.streak > 1 else ""]
	%GiftAmt.text = "+%d" % g.gift
	%GiftNext.text = "Come back tomorrow for +%d" % mini(400, g.gift + 50) if g.gift < 400 else "Top gift every day while your streak lasts"
	%Gift.visible = true


func _claim() -> void:
	var n := Save.claim_gift()
	%Gift.visible = false
	if n > 0:
		Sound.play("chime")
		toast("+%d COINS · YOU HAVE %s" % [n, _commas(Save.wallet())])
	_render_home()


# ------------------------------------------------------------------ the episode map

func _render_eps() -> void:
	var E := Catalog.episodes(key)
	%EpsTitle.text = String(Catalog.ERAS[key].name).to_upper()
	%EpsStars.text = "★ %d/24" % Save.map_stars(key)
	%TutState.text = "✓ DONE" if Save.data.tut else "START HERE"
	var nx := Save.next_episode(key)
	if ep_sel < 0 or ep_sel >= E.size():
		ep_sel = maxi(0, nx)
	var wm := %WMap
	wm.names = E.map(func(e): return Catalog.city_of(e.name))
	wm.stars = range(8).map(func(i): return int(Save.ep(key, i).stars))
	wm.unlocked = range(8).map(func(i): return Save.unlocked(key, i))
	wm.next_ep = nx
	wm.selected = ep_sel
	wm.map = key
	wm.queue_redraw()
	var pin: Color = wm.STYLES[key].pin
	var e: Dictionary = E[ep_sel]
	var sv := Save.ep(key, ep_sel)
	var open := Save.unlocked(key, ep_sel)
	(%EcNumBox.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = pin
	%EcNum.text = str(ep_sel + 1) if open else "🔒"
	%EcName.text = e.name
	if open:
		%EcSub.text = "%d BPM · %s" % [e.bpm, Catalog.LEAD_NAMES.get(e.lead, e.lead)]
	elif not Save.era_open(key):
		%EcSub.text = "Earn %d★ in the %s to open" % [Catalog.ERA_NEED, Catalog.ERAS[Catalog.MAPS[Catalog.MAPS.find(key) - 1]].name]
	else:
		%EcSub.text = "Clear episode %d to open" % ep_sel
	%EcStars.text = "★".repeat(int(sv.stars)) if open and int(sv.stars) > 0 else ""
	%EcGrade.text = "%s · %d%%" % [sv.grade, floori(float(sv.acc) * 100.0)] if open and int(sv.stars) > 0 else ""
	%EpPlay.disabled = not open
	%EpPlay.text = ("PLAY AGAIN · EPISODE %d" % (ep_sel + 1) if int(sv.stars) > 0 else "PLAY EPISODE %d" % (ep_sel + 1)) if open else "LOCKED"


func _ep_play() -> void:
	if Save.unlocked(key, ep_sel):
		_play(key, ep_sel)


func _pick(i: int) -> void:
	if ep_sel == i and Save.unlocked(key, i):
		_play(key, i)
		return
	ep_sel = i
	_render_eps()


# ------------------------------------------------------------------ the garage

func _render_garage() -> void:
	var cars := g_tab == "cars"
	var keys: Array = CAR_KEYS if cars else PILOT_KEYS
	g_i = posmod(g_i, keys.size())
	var k: String = keys[g_i]
	var item: Dictionary = (Catalog.CARS if cars else Catalog.PILOTS)[k]
	var owned := Save.owns_car(k) if cars else Save.owns_pilot(k)
	var current: bool = (Save.data.car if cars else Save.data.pilot) == k
	%GWallet.text = _commas(Save.wallet())
	%CarName.text = String(item.name).to_upper()
	%CarAbout.text = item.about
	%CarPerk.text = item.say if cars else "Plays the %s" % Catalog.LEAD_NAMES.get(item.lead, item.lead)
	%CarPrice.text = "" if owned else "%s coins" % _commas(int(item.price))
	%CarAct.disabled = false
	if current:
		%CarAct.text = "YOUR CAR" if cars else "YOUR PILOT"
		%CarAct.disabled = true
	elif owned:
		%CarAct.text = "FLY THIS ONE"
	elif Save.wallet() >= int(item.price):
		%CarAct.text = "BUY · %s" % _commas(int(item.price))
	else:
		%CarAct.text = "NEED %s MORE" % _commas(int(item.price) - Save.wallet())
		%CarAct.disabled = true
	%CarCoins.visible = Save.dev()
	%CarView.text = "SHOWROOM" if main.get("garage_street") else "IN-GAME VIEW"
	for c in %CarDots.get_children():
		c.queue_free()
	for i in keys.size():
		var d := Panel.new()
		d.custom_minimum_size = Vector2(12, 12)
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(6)
		sb.border_color = Color(1, 1, 1, 0.45)
		sb.set_border_width_all(1)
		var own: bool = Save.owns_car(keys[i]) if cars else Save.owns_pilot(keys[i])
		sb.bg_color = Color("ffd45c") if i == g_i else (Color(1, 1, 1, 0.35) if own else Color(0, 0, 0, 0))
		d.add_theme_stylebox_override("panel", sb)
		%CarDots.add_child(d)
	for t in [["GtCars", cars], ["GtPilots", not cars]]:
		var b: Button = get_node("%" + t[0])
		b.add_theme_color_override("font_color", Color("ffd45c") if t[1] else Color("eceef2"))
	_backdrop().show_ride(k if cars else Save.data.car, k if not cars else Save.data.pilot, not cars)


func _garage_act() -> void:
	var cars := g_tab == "cars"
	var k: String = (CAR_KEYS if cars else PILOT_KEYS)[g_i]
	var owned := Save.owns_car(k) if cars else Save.owns_pilot(k)
	if not owned and not Save.buy("car" if cars else "pilot", k):
		return
	if cars:
		Save.data.car = k
	else:
		Save.data.pilot = k
	Save.write()
	_render_garage()


# ------------------------------------------------------------------ missions, scores, settings, log

func _render_missions() -> void:
	%MissionsTot.text = _commas(Save.wallet())
	for c in %MList.get_children():
		c.queue_free()
	for a in Save.missions().active:
		var g := Save.mission_goal(a)
		var p := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(20 / 255.0, 16 / 255.0, 30 / 255.0, 0.85)
		sb.border_color = Color(1, 1, 1, 0.14)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(12)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		p.add_theme_stylebox_override("panel", sb)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 6)
		p.add_child(v)
		var h := HBoxContainer.new()
		v.add_child(h)
		var t := Label.new()
		t.theme_type_variation = "Title"
		t.add_theme_font_size_override("font_size", 14)
		t.text = Catalog.mission_text(a.id, g)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.add_child(t)
		var rw := Label.new()
		rw.theme_type_variation = "Eyebrow"
		rw.add_theme_color_override("font_color", Color("ffd45c"))
		rw.text = "%d coins" % Save.mission_reward(a)
		h.add_child(rw)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 6)
		bar.value = minf(100.0, float(a.prog) / g * 100.0)
		v.add_child(bar)
		var n := Label.new()
		n.theme_type_variation = "Eyebrow"
		n.text = "%d / %d" % [mini(int(a.prog), g), g]
		v.add_child(n)
		%MList.add_child(p)
	var st := int(Save.data.daily.get("streak", 0))
	%DailyNote.text = "Come back each day for a gift: 100 coins, then 50 more for every day in a row (up to 400). Your streak: %d day%s." % [st, "" if st == 1 else "s"]


func _render_board() -> void:
	%BoardTot.text = "★ %d/72" % Save.total_stars()
	for t in [["TabOld", "old"], ["TabSunset", "sunset"], ["TabRain", "rain"]]:
		var b: Button = get_node("%" + t[0])
		var on: bool = t[1] == board_map
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(10)
		sb.set_border_width_all(1)
		sb.border_color = ERA_K[t[1]] if on else Color(1, 1, 1, 0.18)
		sb.bg_color = Color(1, 1, 1, 0.1) if on else Color(0, 0, 0, 0)
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		b.add_theme_stylebox_override("normal", sb)
	for box in [%BoardInf, %BoardEps]:
		for c in box.get_children():
			c.queue_free()
	var inf: Array = Save.data.endless.get(board_map, [])
	if inf.is_empty():
		_rank(%BoardInf, ["No Endless runs yet"], true)
	for i in inf.size():
		_rank(%BoardInf, [str(i + 1), String(inf[i].get("d", "")), _commas(int(inf[i].s))])
	var E := Catalog.episodes(board_map)
	for i in E.size():
		var sv := Save.ep(board_map, i)
		var right := ("★".repeat(int(sv.stars)) + " %s · %s" % [sv.grade, _commas(int(sv.score))]) if int(sv.stars) > 0 else "—"
		_rank(%BoardEps, [str(i + 1), E[i].name, right], false, int(sv.stars) == 0)


func _rank(box: VBoxContainer, cells: Array, empty := false, dim := false) -> void:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(20 / 255.0, 16 / 255.0, 30 / 255.0, 0.8)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	for i in cells.size():
		var l := Label.new()
		l.theme_type_variation = "Body"
		l.text = cells[i]
		if empty:
			l.add_theme_color_override("font_color", Color("9097a6"))
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		elif i == 0:
			l.custom_minimum_size.x = 18
			l.add_theme_color_override("font_color", Color("9097a6"))
		elif i == 1:
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l.clip_text = true
		else:
			l.add_theme_color_override("font_color", Color("9097a6") if dim else Color("ffd45c"))
		h.add_child(l)
	box.add_child(p)


func _toggle(k: String) -> void:
	Save.set_setting(k, not bool(Save.setting(k)))
	if k == "sound":
		AudioServer.set_bus_mute(0, not bool(Save.setting("sound")))
	_render_settings()


func _render_settings() -> void:
	%SndMenu.text = "SOUND ON" if Save.setting("sound") else "SOUND OFF"
	%FxBtn.text = "ON" if Save.setting("fx_low") else "OFF"
	%HapBtn.text = "HAPTICS ON" if Save.setting("haptics") else "HAPTICS OFF"
	%LevelBtn.text = String(Save.setting("level")).to_upper()
	%DevBtn.text = "ON" if Save.dev() else "OFF"
	var cal = Save.setting("cal")
	%SyncBtnSub.text = "automatic" if cal == null else "%+d ms" % roundi(float(cal) * 1000.0)


func _render_log() -> void:
	if %CLog.get_child_count() > 0:
		return
	var log: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/changelog.json"))
	for i in log.size():
		var e: Dictionary = log[i]
		var p := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(20 / 255.0, 16 / 255.0, 30 / 255.0, 0.86)
		sb.border_color = Color("ffd45c") if i == 0 else Color(1, 1, 1, 0.13)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(12)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 10
		sb.content_margin_bottom = 10
		p.add_theme_stylebox_override("panel", sb)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		p.add_child(v)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		v.add_child(h)
		for c in [["v" + String(e.v), "Eyebrow", Color("ffd45c")], [e.name, "Title", Color.WHITE], [e.date, "Eyebrow", Color("9097a6")]]:
			var l := Label.new()
			l.theme_type_variation = c[1]
			l.text = c[0]
			l.add_theme_color_override("font_color", c[2])
			if c[1] == "Title":
				l.add_theme_font_size_override("font_size", 14)
				l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(l)
		for it in e.items:
			var l := Label.new()
			l.theme_type_variation = "Muted"
			l.text = "· " + String(it)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			v.add_child(l)
		%CLog.add_child(p)


# ------------------------------------------------------------------ audio sync: tap along with clicks

func _render_sync() -> void:
	var cal = Save.setting("cal")
	%SyncVal.text = "AUTO" if cal == null else "%+d ms" % roundi(float(cal) * 1000.0)
	%SyncNote.text = "" if cal == null else "Notes and the music move by this much."
	%SyncBig.text = "START"
	%SyncCount.text = "12 clicks · about 8 seconds"
	_sync_t0 = -1.0


func _sync_tap() -> void:
	var now := Time.get_ticks_usec() / 1e6
	if _sync_t0 < 0.0:
		# twelve clicks, two thirds of a second apart, starting in a moment
		_sync_t0 = now + 0.6
		_sync_taps = []
		_sync_clicks = []
		for i in 12:
			_sync_clicks.append(_sync_t0 + i * 0.667)
		%SyncBig.text = "TAP"
		return
	_sync_taps.append(now)


func _sync_step() -> void:
	var now := Time.get_ticks_usec() / 1e6
	var played := 0
	for c in _sync_clicks:
		if now >= c:
			played += 1
	if played > 0 and played <= 12 and not has_meta("clicked_%d" % played):
		set_meta("clicked_%d" % played, true)
		_click()
	%SyncCount.text = "%d / 12" % played
	if now > _sync_clicks[-1] + 0.6:
		for i in 13:
			if has_meta("clicked_%d" % i):
				remove_meta("clicked_%d" % i)
		# the delay: how late the taps land after the clicks that count (the last eight), by the median
		var lags := []
		for c in _sync_clicks.slice(4):
			var best := INF
			for t in _sync_taps:
				if absf(t - c) < absf(best):
					best = t - c
			if absf(best) < 0.3:
				lags.append(best)
		_sync_t0 = -1.0
		if lags.size() >= 5:
			lags.sort()
			var med: float = lags[lags.size() / 2]
			Save.set_setting("cal", snappedf(med, 0.001))
		_render_sync()
		if lags.size() < 5:
			%SyncNote.text = "Not enough taps landed near the clicks. Try again."


func _click() -> void:
	if ResourceLoader.exists("res://audio/sfx/click.res"):
		Sound.play("click")
		return
	var p := AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 44100
	p.stream = gen
	p.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	add_child(p)
	p.play()
	var pb := p.get_stream_playback() as AudioStreamGeneratorPlayback
	for i in 2200:
		var v := sin(i * TAU * 1760.0 / 44100.0) * exp(-i / 300.0) * 0.6
		pb.push_frame(Vector2(v, v))
	get_tree().create_timer(0.3).timeout.connect(p.queue_free)


func _cal(d: float) -> void:
	var cal = Save.setting("cal")
	Save.set_setting("cal", snappedf((0.0 if cal == null else float(cal)) + d, 0.001))
	_render_sync()


static func _commas(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
