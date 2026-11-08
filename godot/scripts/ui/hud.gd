extends Control
## The run's HUD, as the web game draws it. The run calls update() every frame and the event functions as the
## rules report them; all the pieces are nodes in hud.tscn.

signal pause_pressed

const FORM_NAME := ["", "JETPACK", "CAR"]
const POP_COLORS := {"gold": Color("ffd45c"), "red": Color("ff6b78"), "": Color.WHITE}

var rules: Rules
var info := {}
var _coins := 0
var _form := -1
var _tier := 1
var _pop_pri := 0
var _pop_until := 0.0
var _pop_t := 9.0
var _pop_len := 0.95
var _judge_t := 9.0
var _score_bump := 0.0
var _flash := 0.0
var _od := false
var _last_count := -1
var _clock := 0.0
var _chips := ""
var _hint_until := 0.0


func setup(ep: Dictionary, r: Rules) -> void:
	info = ep
	rules = r
	%EpLabel.text = ("FLIGHT SCHOOL" if Launch.mode == "school" else "ENDLESS · %s · %s" % [String(Catalog.ERAS[ep.map].name).to_upper(), String(ep.get("level", "normal")).to_upper()] if Launch.mode == "endless" else "EPISODE %d · %s" % [int(ep.i) + 1, String(ep.name).to_upper()])
	%Progress.visible = Launch.mode != "endless"
	%Pause.pressed.connect(func(): pause_pressed.emit())
	# the first episodes open with the controls, then with the rules of the run
	if Launch.mode == "episode" and int(ep.i) < 2 and ep.map == "old":
		_hint("SWIPE ← → LANES · ↑ HOP · ↓ DIVE" if int(ep.i) == 0 else "EVERY NOTE IS A MOVE · SWIPE AS THE RING CLOSES", r.first_t + r.BAR * 2.0)
	form(2)
	%Score.pivot_offset = %Score.size / 2.0


func hold(arrow: String, text: String) -> void:
	## Flight School: show the move to make (empty = done)
	%Tut.visible = arrow != ""
	%TutArrow.text = arrow
	%TutText.text = text


func _hint(text: String, until: float) -> void:
	%HintText.text = text
	%Hint.visible = text != ""
	_hint_until = until


func update(t: float) -> void:
	var dt := get_process_delta_time()
	_clock += dt
	%Score.text = _commas(rules.score)
	_score_bump = maxf(0.0, _score_bump - dt * 5.0)
	%Score.scale = Vector2.ONE * (1.0 + 0.22 * _score_bump * _score_bump)
	%Combo.text = "%d COMBO" % rules.combo if rules.combo >= 5 else ""
	%Mel.visible = not rules.melody_on and not rules.over and rules.combo == 0 and rules.J.m > 0
	# lives and rescue
	var full: bool = rules.form >= 2
	%Rescue.visible = not full and not rules.tutorial
	%RescueLabel.visible = %Rescue.visible
	%Rescue.value = 100.0 if rules.deliver_at < INF else rules.rescue
	if rules.deliver_at < INF:
		%Rescue.modulate.a = 0.6 + 0.4 * sin(_clock * 20.0)
	else:
		%Rescue.modulate.a = 1.0
	var danger: bool = rules.form == 1 and not rules.tutorial and not rules.over and not Save.data.settings.get("fx_low", false)
	%Danger.modulate.a = (0.25 + 0.55 * (0.5 + 0.5 * sin(_clock * PI / 0.9))) if danger else move_toward(%Danger.modulate.a, 0.0, dt * 3.0)
	# Flow and the multiplier
	%FlowBar.value = rules.od_t / (Rules.OD_BARS * rules.BAR) * 100.0 if rules.od_t > 0.0 else rules.flow
	var tier := rules.tier()
	if tier != _tier:
		_tier = tier
		%Mult.text = "×%d" % tier
		%Mult.scale = Vector2.ONE * 1.6
	%Mult.scale = %Mult.scale.lerp(Vector2.ONE, minf(1.0, dt * 10.0))
	if _od:
		var b: float = 0.5 + 0.5 * cos(t / rules.BEAT * TAU)
		%OdGlow.modulate.a = 0.35 + 0.45 * b
		%FlowBar.modulate = Color.from_hsv(fmod(_clock * 1.6, 1.0), 0.5, 1.0)
	else:
		%OdGlow.modulate.a = move_toward(%OdGlow.modulate.a, 0.0, dt * 3.0)
		%FlowBar.modulate = Color.WHITE
	# power-up chips
	var chips := []
	if rules.magnet_t > 0.0:
		chips.append("MAGNET %ds" % ceili(rules.magnet_t))
	if rules.x2_t > 0.0:
		chips.append("2× SCORE %ds" % ceili(rules.x2_t))
	if rules.shield_on:
		chips.append("SHIELD ON")
	var key := "|".join(chips)
	if key != _chips:
		_chips = key
		for c in %PowerUps.get_children():
			c.queue_free()
		for text in chips:
			var p := PanelContainer.new()
			p.theme_type_variation = "Chip"
			p.size_flags_horizontal = Control.SIZE_SHRINK_END
			var l := Label.new()
			l.theme_type_variation = "HudChip"
			l.text = text
			p.add_child(l)
			%PowerUps.add_child(p)
	# progress through the episode
	if %Progress.visible:
		%Progress.value = clampf((t - rules.first_t) / maxf(1.0, rules.gate - rules.first_t), 0.0, 1.0) * 100.0
	%EpLabel.modulate.a = move_toward(%EpLabel.modulate.a, 0.0 if t > rules.first_t + rules.BAR else 0.8, dt * 1.2)
	if %Hint.visible and t > _hint_until:
		%Hint.visible = false
	# Flight School: the lesson for the coming bar (shown a beat early)
	if rules.tutorial and Launch.mode == "school":
		var say := ""
		for line in rules.course.get("say", []):
			if float(line.t) <= t + rules.BEAT:
				say = line.say
		if say != %HintText.text:
			%HintText.text = say
		%Hint.visible = say != ""
	if %Tut.visible:
		%TutArrow.position.y = sin(_clock * TAU / 0.7) * 6.0
	# the count-in lands on the first note's bar line: 3, 2, 1, GO!
	var bl := ceili((rules.first_t - t) / rules.BEAT)
	if bl != _last_count and bl >= 0 and bl <= 3:
		_last_count = bl
		pop("GO!" if bl == 0 else str(bl), "gold big" if bl == 0 else "big", 3)
	# the call-out: pops in, settles, rises and fades
	_pop_t += dt
	var k := _pop_t / _pop_len
	if k < 1.0:
		var s := 0.55 + (1.18 - 0.55) * (k / 0.14) if k < 0.14 else (1.18 - 0.18 * (k - 0.14) / 0.14 if k < 0.28 else 1.0)
		%Pop.scale = Vector2.ONE * s
		%Pop.modulate.a = (k / 0.14) if k < 0.14 else (1.0 if k < 0.78 else 1.0 - (k - 0.78) / 0.22)
		%Pop.position.y = 118.0 - (16.0 * (k - 0.78) / 0.22 if k > 0.78 else 0.0)
	else:
		%Pop.modulate.a = 0.0
	# the timing word, just above the car
	_judge_t += dt
	var jk := _judge_t / 0.6
	if jk < 1.0:
		%Judge.modulate.a = (jk / 0.15) if jk < 0.15 else (1.0 if jk < 0.7 else 1.0 - (jk - 0.7) / 0.3)
		%Judge.scale = Vector2.ONE * (0.8 + 0.26 * jk / 0.15 if jk < 0.15 else 1.0)
	else:
		%Judge.modulate.a = 0.0
	var cam := get_viewport().get_camera_3d()
	var ride := get_tree().current_scene.get_node_or_null("Ride") as Node3D
	if cam and ride:
		var p := cam.unproject_position(ride.global_position + Vector3(0, 1.26, 0))
		%Judge.position = p - %Judge.size / 2 - Vector2(0, 40.0 * clampf(jk - 0.7, 0.0, 0.3) / 0.3)
	# the crash flash
	_flash = maxf(0.0, _flash - dt / 0.8)
	%Flash.modulate.a = _flash


func judged() -> void:
	## a played note: the coin count ticks up and the score swells for a moment as it takes the points
	_coins += 1
	%CoinN.text = _commas(_coins)
	%Coins.scale = Vector2.ONE * 1.12
	create_tween().tween_property(%Coins, "scale", Vector2.ONE, 0.24)
	_score_bump = 1.0


func missed(_r: Rules) -> void:
	pass


func pop(text: String, kind: String, pri: int) -> void:
	## one call-out at a time: a new one replaces the current one unless the current one matters more
	## (3: countdown, crash, finish · 2: power-ups, shields, missions · 1: everything else)
	var now := Time.get_ticks_msec() / 1000.0
	if now < _pop_until and pri < _pop_pri:
		return
	_pop_pri = pri
	_pop_len = 0.95
	_pop_until = now + _pop_len * 0.75
	%Pop.text = text
	var big := kind.contains("big")
	var od := kind.contains("od")
	%Pop.add_theme_font_size_override("font_size", 38 if od else 44 if big else 21)
	var col: Color = POP_COLORS.gold if kind.contains("gold") else POP_COLORS.red if kind.contains("red") else Color.WHITE
	%Pop.add_theme_color_override("font_color", col)
	%Pop.add_theme_color_override("font_outline_color", Color("ff3fb4") if od else Color(0, 0, 0, 0.75))
	_pop_t = 0.0


func count(n: int) -> void:
	## the count-in after a pause or a revive
	if n > 0:
		pop(str(n), "big", 3)


func overdrive(on: bool) -> void:
	_od = on
	var era := Catalog.ERAS[info.get("map", "old")] as Dictionary
	(%OdGlow.material as ShaderMaterial).set_shader_parameter("tint", era.color)


func tier_up(_t: int) -> void:
	pass


func crash() -> void:
	_flash = 1.0 if not Save.data.settings.get("fx_low", false) else 0.5


func form(f: int) -> void:
	_form = f
	%FormLabel.text = FORM_NAME[maxi(f, 1)]
	_icon(%CarIcon, f == 2, f < 2)
	_icon(%JetIcon, f == 1, false)
	var last: bool = f == 1 and not rules.tutorial
	if last:
		(%JetIcon.get_theme_stylebox("panel") as StyleBoxFlat).bg_color = Color("ff5a4e")


func _icon(chip: PanelContainer, now: bool, lost: bool) -> void:
	var sb := (chip.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
	sb.bg_color = Color("ffc44a") if now else Color(10 / 255.0, 8 / 255.0, 18 / 255.0, 0.5)
	sb.shadow_color = Color(1.0, 0.77, 0.29, 0.7) if now else Color(0, 0, 0, 0)
	sb.shadow_size = 6 if now else 0
	chip.add_theme_stylebox_override("panel", sb)
	var ic := chip.get_child(0) as TextureRect
	ic.modulate = Color("140c06") if now else Color.WHITE
	chip.modulate.a = 0.28 if lost else 1.0


static func _commas(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
