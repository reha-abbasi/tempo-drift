extends CanvasLayer
## The screens over a run: PAUSED, OUT OF LIVES and EPISODE CLEAR, with the web game's words and rules
## (coins for every note played, 40 a new star, one paid revive per run while the song has a bar to go).

const MENU := "res://scenes/main.tscn"
const RUN := "res://scenes/run/run.tscn"

var run: Node
var _clock := 0.0
var _anim := []   # [node, start, kind, value]


func _ready() -> void:
	%Resume.pressed.connect(func(): run.resume())
	%Restart.pressed.connect(_retry)
	%PauseMenu.pressed.connect(_menu)
	%Sound.pressed.connect(_sound)
	%Revive.pressed.connect(_revive)
	%Again.pressed.connect(_retry)
	%ToMenu.pressed.connect(_menu)
	%NextEp.pressed.connect(_next)
	%RetryEp.pressed.connect(_retry)
	%ClearMenu.pressed.connect(_menu)
	_sound_label()


func hide_all() -> void:
	for n in ["Pause", "Over", "Clear"]:
		$Root.get_node(n).visible = false


func _hud(on: bool) -> void:
	var h := run.get_node_or_null("HUDLayer") as CanvasLayer
	if h:
		h.visible = on


# ------------------------------------------------------------------ pause

func show_pause(r: Node) -> void:
	run = r
	hide_all()
	$Root/Pause.visible = true
	var ep: Dictionary = r.info
	%PauseInfo.text = "%s · EPISODE %d · %s" % [String(Catalog.ERAS[ep.map].name).to_upper(), int(ep.i) + 1, String(ep.name).to_upper()]


func _sound() -> void:
	Save.set_setting("sound", not bool(Save.setting("sound")))
	AudioServer.set_bus_mute(0, not bool(Save.setting("sound")))
	_sound_label()


func _sound_label() -> void:
	%Sound.text = "SOUND ON" if bool(Save.setting("sound")) else "SOUND OFF"


# ------------------------------------------------------------------ out of lives

func show_game_over(r: Node) -> void:
	run = r
	hide_all()
	_hud(false)
	$Root/Over.visible = true
	var rules: Rules = r.rules
	var ep: Dictionary = r.info
	var endless := Launch.mode == "endless"
	var can: bool = not endless and not r.get("revived") and rules.t < rules.gate - rules.BAR
	%Revive.visible = can
	if can:
		var w := Save.wallet()
		%Revive.disabled = w < Catalog.REVIVE_COST
		%Revive.text = "REVIVE · %d COINS" % Catalog.REVIVE_COST if w >= Catalog.REVIVE_COST else "REVIVE · NEED %d MORE COINS" % (Catalog.REVIVE_COST - w)
	%Again.theme_type_variation = "GhostButton" if can and Save.wallet() >= Catalog.REVIVE_COST else "BigButton"
	if endless:
		# Endless: the score against your best, and where it lands on the board
		var rank := Save.record_endless(ep.map, rules.score) if not rules.autopilot else 99
		var board: Array = Save.data.endless.get(ep.map, [])
		%OverTitle.text = "GAME OVER"
		%OverCity.text = "ENDLESS · %s · %s OF THE NOTES" % [String(Catalog.ERAS[ep.map].name).to_upper(), _acc(rules.accuracy())]
		%OverALabel.text = "SCORE"
		%OverA.text = _commas(rules.score)
		%OverBLabel.text = "BEST"
		%OverB.text = _commas(int(board[0].s)) if board.size() > 0 else "0"
		%OverNote.text = "NEW HIGH SCORE" if rank == 1 and rules.score > 0 else ("#%d on your %s board" % [rank, Catalog.ERAS[ep.map].name] if rank <= 5 else "")
		%Again.text = "FLY AGAIN"
		%ToMenu.text = "MAIN MENU"
	else:
		%OverTitle.text = "OUT OF LIVES"
		%OverCity.text = "%s · EPISODE %d · %s" % [String(Catalog.ERAS[ep.map].name).to_upper(), int(ep.i) + 1, String(ep.name).to_upper()]
		var prog := clampf((rules.t - rules.first_t) / (rules.gate - rules.first_t), 0.0, 1.0)
		%OverALabel.text = "SONG"
		%OverA.text = "%d%%" % roundi(prog * 100.0)
		%OverBLabel.text = "COINS CAUGHT"
		%OverB.text = _acc(rules.accuracy())
		%OverNote.text = "You lost the car and then the jetpack. The course is the same every try, so you can learn it."
		%Again.text = "TRY AGAIN"
		%ToMenu.text = "EPISODES"
	_judgements("OverJud", rules)
	var got: int = r.pay(0)
	%OverEarn.text = _earn(got, "")
	_missions(%OverMis, r.m_done)


func _revive() -> void:
	if Save.wallet() < Catalog.REVIVE_COST:
		return
	Save.add_coins(-Catalog.REVIVE_COST)
	run.revived = true
	hide_all()
	_hud(true)
	run.revive()


# ------------------------------------------------------------------ episode clear

func show_results(res: Dictionary) -> void:
	hide_all()
	_hud(false)
	$Root/Clear.visible = true
	var rules: Rules = run.rules
	var ep: Dictionary = run.info
	var map: String = ep.map
	var last := int(ep.i) == 7
	%ClearCity.text = "%s · EPISODE %d · %s" % [String(Catalog.ERAS[map].name).to_upper(), int(ep.i) + 1, String(ep.name).to_upper()]
	%ClearTitle.text = "ERA COMPLETE" if last else "EPISODE CLEAR"
	var g: String = res.grade
	var stars: int = res.stars
	var clean: bool = res.lost == 0
	# missions finished by the result, then the record, then the coins
	if clean:
		run.mission("clean", 1)
	if rules.J.m == 0:
		run.mission("nomiss", 1)
	if g == "S" or g == "A":
		run.mission("agrade", 1)
	if g == "S":
		run.mission("sgrade", 1)
	var k := Catalog.MAPS.find(map)
	var next_era: String = Catalog.MAPS[k + 1] if k + 1 < Catalog.MAPS.size() else ""
	var was_open := next_era == "" or Save.era_open(next_era)
	# the tests fly on autopilot: their results are not kept
	var rec := Save.record_ep(map, int(ep.i), stars, rules.score, res.acc, g) if not rules.autopilot else {"best": false, "new_stars": 0}
	var got: int = run.pay(int(rec.new_stars) * Catalog.STAR_PAY)
	var opened := not was_open and Save.era_open(next_era)
	%ClearEarn.text = _earn(got, " (%d for new stars)" % (int(rec.new_stars) * Catalog.STAR_PAY) if int(rec.new_stars) > 0 else "")
	_missions(%ClearMis, run.m_done)
	# the grade stamps in, the stars light one by one, the numbers roll up
	%Rank.visible = true
	%GradeLetter.text = g
	_grade_style(g)
	%Grade.scale = Vector2.ONE * 2.2
	%Grade.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_property(%Grade, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(%Grade, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in 3:
		var s: Label = get_node("%%Star%d" % i)
		s.add_theme_color_override("font_color", Color(1, 1, 1, 0.16))
		s.scale = Vector2.ONE * 0.6
		if i < stars:
			var st := create_tween()
			st.tween_interval(0.7 + i * 0.22)
			st.tween_callback(func(): s.add_theme_color_override("font_color", Color("ffd45c")))
			st.tween_property(s, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_count_up(%ClearAcc, res.acc, func(v): return _acc(v))
	_count_up(%ClearScore, float(rules.score), func(v): return _commas(roundi(v)))
	%ClearCombo.text = str(rules.max_combo)
	_judgements("ClearJud", rules)
	var tip := "Flawless." if g == "S" else ("S needs 99% of the notes." if clean else "S needs 99% of the notes and no crash.") if g == "A" else "★★ for 95% of the notes (grade A), ★★★ for 99% with no crash (S)."
	var chips := []
	if opened:
		chips.append("%s UNLOCKED" % String(Catalog.ERAS[next_era].name).to_upper())
	if rec.best:
		chips.append("NEW BEST")
	if rules.od_n > 0:
		chips.append("%d OVERDRIVE%s" % [rules.od_n, "S" if rules.od_n > 1 else ""])
	if clean:
		chips.append("NO CRASH")
	_chips(chips)
	%ClearNote.text = tip
	# after the last episode of an era, on to the next era if it's open
	var to_era := next_era if last and next_era != "" and Save.era_open(next_era) else ""
	%NextEp.visible = not (last and to_era == "")
	# (while only Berlin is open there is no next episode to go on to)
	if not last and not Save.unlocked(map, int(ep.i) + 1):
		%NextEp.visible = false
	%NextEp.set_meta("era", to_era)
	if to_era != "":
		%NextEp.text = "NEXT ERA · %s" % String(Catalog.ERAS[to_era].name).to_upper()
	elif not last:
		%NextEp.text = "NEXT · %s" % String(Catalog.episodes(map)[int(ep.i) + 1].name).to_upper()


func _grade_style(g: String) -> void:
	var sb := (%Grade.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	var fg := Color.WHITE
	match g:
		"S":
			sb.bg_color = Color("ffd45c")
			sb.border_color = Color("fff3b0")
			sb.shadow_color = Color(1, 0.83, 0.36, 0.9)
			sb.shadow_size = 20
			fg = Color("1a0a04")
		"A":
			sb.border_color = Color("8ff6ff")
			sb.shadow_color = Color(0.18, 0.95, 1, 0.6)
			sb.shadow_size = 14
			fg = Color("8ff6ff")
		"B":
			sb.border_color = Color("a98cff")
			fg = Color("c9b6ff")
		_:
			fg = Color("d8d0ec")
	%Grade.add_theme_stylebox_override("panel", sb)
	%GradeLetter.add_theme_color_override("font_color", fg)


func _chips(list: Array) -> void:
	for c in %ClearChips.get_children():
		c.queue_free()
	for text in list:
		var p := PanelContainer.new()
		p.theme_type_variation = "Chip"
		var l := Label.new()
		l.theme_type_variation = "HudChip"
		l.text = text
		p.add_child(l)
		%ClearChips.add_child(p)


func _judgements(prefix: String, rules: Rules) -> void:
	get_node("%" + prefix + "Ex").text = str(rules.J.ex)
	get_node("%" + prefix + "Gd").text = str(rules.J.gd)
	get_node("%" + prefix + "Ok").text = str(rules.J.ok)
	get_node("%" + prefix + "Miss").text = str(rules.J.m)


func _missions(box: VBoxContainer, done: Array) -> void:
	## the missions finished in this run, then how far along the three current ones are
	for c in box.get_children():
		c.queue_free()
	if done.size() > 2:
		var total := 0
		for d in done:
			total += int(d.rw)
		_mrow(box, "✓ %d missions done" % done.size(), "+%d" % total, -1.0)
	else:
		for d in done:
			_mrow(box, "✓ " + String(d.say), "+%d" % int(d.rw), -1.0)
	for a in Save.missions().active:
		var gl := Save.mission_goal(a)
		_mrow(box, Catalog.mission_text(a.id, gl), "%d/%d" % [mini(int(a.prog), gl), gl], minf(1.0, float(a.prog) / gl))


func _mrow(box: VBoxContainer, text: String, right: String, pct: float) -> void:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(20 / 255.0, 16 / 255.0, 30 / 255.0, 0.72)
	sb.border_color = Color(1, 1, 1, 0.1)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(9)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	p.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	p.add_child(v)
	var h := HBoxContainer.new()
	v.add_child(h)
	var t := Label.new()
	t.theme_type_variation = "Muted"
	t.add_theme_font_size_override("font_size", 11)
	t.add_theme_color_override("font_color", Color("d8d0ec"))
	t.text = text
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.clip_text = true
	h.add_child(t)
	var r := Label.new()
	r.theme_type_variation = "Muted"
	r.add_theme_font_size_override("font_size", 11)
	r.add_theme_color_override("font_color", Color("ffd45c"))
	r.text = right
	h.add_child(r)
	if pct >= 0.0:
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 4)
		bar.value = pct * 100.0
		v.add_child(bar)
	box.add_child(p)


func _count_up(l: Label, to: float, fmt: Callable) -> void:
	if Save.data.settings.get("fx_low", false):
		l.text = fmt.call(to)
		return
	var tw := create_tween()
	tw.tween_method(func(k: float): l.text = fmt.call(to * (1.0 - pow(1.0 - k, 3.0))), 0.0, 1.0, 0.9)


static func _acc(a: float) -> String:
	return "%d%%" % floori(a * 100.0 + 0.0001)


static func _commas(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


static func _earn(n: int, why: String) -> String:
	return "+%s coins%s · you have %s" % [_commas(n), why, _commas(Save.wallet())]


# ------------------------------------------------------------------ Flight School done

func show_school() -> void:
	## no stars: a one-time bonus, then on to episode 1
	hide_all()
	_hud(false)
	$Root/Clear.visible = true
	var rules: Rules = run.rules
	var first: bool = not Save.data.tut
	if not rules.autopilot:
		Save.data.tut = true
		Save.write()
	var got: int = run.pay(100 if first else 0)
	%Rank.visible = false
	%ClearTitle.text = "GRADUATED"
	%ClearCity.text = "FLIGHT SCHOOL · YOU KNOW EVERY MOVE"
	_judgements("ClearJud", rules)
	%ClearScore.text = _commas(rules.score)
	%ClearCombo.text = str(rules.max_combo)
	_chips([])
	%ClearNote.text = "In episodes you have 2 lives: a crash wrecks your car and you carry on by jetpack; crash again and the run is over. Play notes to fill the rescue meter and get your car back."
	%ClearEarn.text = _earn(got, " (100 for finishing school)" if first else "")
	_missions(%ClearMis, run.m_done)
	%NextEp.visible = true
	%NextEp.set_meta("era", "")
	%NextEp.set_meta("first", true)
	%NextEp.text = "START EPISODE 1"


# ------------------------------------------------------------------ where to go next

func _retry() -> void:
	# (Flight School and Endless go round again in the same mode; an episode the same episode)
	get_tree().paused = false
	get_tree().change_scene_to_file(RUN)


func _menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU)


func _next() -> void:
	var to_era: String = %NextEp.get_meta("era", "")
	if %NextEp.get_meta("first", false):
		Launch.episode(run.info.map, 0)
	elif to_era != "":
		Launch.episode(to_era, 0)
	else:
		Launch.episode(run.info.map, mini(7, int(run.info.i) + 1))
	get_tree().change_scene_to_file(RUN)
