extends Node3D

## Main controller: game states, input (swipes + keyboard), collisions,
## scoring, camera.
##
## Command-line options for testing (put them after `--`):
##   --autoplay          a bot plays (see autopilot.gd)
##   --runs=N            with --autoplay: play N runs, print a report, quit
##   --seed=N            fixed random seed for the track
##   --no-bot            with --autoplay: the runner never steers (sanity check: must crash)
##   --max-time=S        with --autoplay: end a run after S seconds of game time
##   --shots=DIR         save screenshots into DIR while playing

enum State { MENU, PLAYING, PAUSED, DEAD }

const SWIPE_MIN := 45.0          # pixels (viewport units) before a drag counts as a swipe
const DEATH_PANEL_DELAY := 0.9
const MENU_CAM_POS := Vector3(1.7, 1.5, -3.9)
const MENU_CAM_LOOK := Vector3(0.1, 2.15, 0.0)

@onready var track: Track = $Track
@onready var player: Player = $Player
@onready var camera: Camera3D = $Camera3D
@onready var hud: Hud = $HUD

var state := State.MENU
var save_scores := true          # tests and bot runs switch this off
var speed := GameConfig.START_SPEED
var run_time := 0.0
var score := 0.0
var run_coins := 0
var magnet_left := 0.0
var double_left := 0.0
var stumble_left := 0.0

var _dead_time := 0.0
var _final_score := 0
var _final_best := false
var _over_shown := false
var _shake := 0.0
var _cam_pos := MENU_CAM_POS
var _cam_look := MENU_CAM_LOOK
var _touch_start := Vector2.ZERO
var _touch_down := false
var _swiped := false
var _queued := ""                # action pressed slightly before it was possible

# testing
var _autoplay := false
var _bot: Autopilot
var _runs_wanted := 0
var _runs_done := 0
var _seed := -1
var _max_time := 0.0
var _bot_enabled := true
var _shot_dir := ""
var _shot_timer := 0.0
var _shot_count := 0
var _report: Array[String] = []
var _death_cause := ""


func _ready() -> void:
	_parse_args()
	_tune_for_renderer()
	hud.pause_pressed.connect(_pause)
	hud.resume_pressed.connect(_resume)
	hud.restart_pressed.connect(_start_run)
	hud.menu_pressed.connect(_go_menu)
	hud.sound_pressed.connect(func():
		Sfx.toggle_sound()
		hud.refresh_sound_buttons())
	_go_menu()
	if _autoplay:
		_bot = Autopilot.new()
		_start_run.call_deferred()


## The Compatibility renderer (used by the Web build) lights the scene brighter
## than the Mobile renderer used on iPhone, so tone it down to look the same.
func _tune_for_renderer() -> void:
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		return
	var env: Environment = $WorldEnvironment.environment
	env.ambient_light_energy = 0.45
	env.tonemap_exposure = 0.8
	$Sun.light_energy = 1.0


func _exit_tree() -> void:
	MeshKit.clear_cache()
	WorldKit.clear_cache()


func _parse_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--autoplay":
			_autoplay = true
		elif arg.begins_with("--runs="):
			_runs_wanted = int(arg.get_slice("=", 1))
		elif arg == "--no-bot":
			_bot_enabled = false
		elif arg.begins_with("--max-time="):
			_max_time = float(arg.get_slice("=", 1))
		elif arg.begins_with("--seed="):
			_seed = int(arg.get_slice("=", 1))
		elif arg.begins_with("--shots="):
			_shot_dir = arg.get_slice("=", 1)
			DirAccess.make_dir_recursive_absolute(_shot_dir)


# ------------------------------------------------------------------ states

func _go_menu() -> void:
	get_tree().paused = false
	state = State.MENU
	track.reset(_seed)
	player.reset()
	hud.show_menu(SaveData.best_score, SaveData.total_coins)
	Sfx.music(true)


func _start_run() -> void:
	get_tree().paused = false
	if state != State.MENU:
		track.reset(_seed if _seed < 0 else _seed + _runs_done)
		player.reset()
	state = State.PLAYING
	speed = GameConfig.START_SPEED
	run_time = 0.0
	score = 0.0
	run_coins = 0
	magnet_left = 0.0
	double_left = 0.0
	stumble_left = 0.0
	_queued = ""
	_death_cause = ""
	hud.show_run()
	Sfx.music(true)


func _pause() -> void:
	if state != State.PLAYING:
		return
	state = State.PAUSED
	get_tree().paused = true
	hud.show_pause(true)


func _resume() -> void:
	if state != State.PAUSED:
		return
	state = State.PLAYING
	get_tree().paused = false
	hud.show_pause(false)


func _die(cause: String) -> void:
	state = State.DEAD
	_death_cause = cause
	player.dead = true
	_dead_time = 0.0
	_shake = 0.6
	Sfx.play("crash")
	Input.vibrate_handheld(250)
	_final_score = int(score)
	# bot runs must not touch the real save file
	_final_best = false if (_autoplay or not save_scores) else SaveData.record_run(_final_score, run_coins)
	_over_shown = false
	if _autoplay:
		_bot_report(_final_score)


func _notification(what: int) -> void:
	# auto-pause when the app goes to the background (phone call, home button...)
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_pause()


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		_on_key(event.keycode)
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_down = true
			_swiped = false
			_touch_start = event.position
		else:
			_touch_down = false
			if not _swiped and state == State.MENU and not hud.is_over_menu_button(event.position):
				_start_run()
	elif event is InputEventScreenDrag and _touch_down and not _swiped:
		var d: Vector2 = event.position - _touch_start
		if d.length() >= SWIPE_MIN:
			_swiped = true
			if absf(d.x) > absf(d.y):
				_action("right" if d.x > 0 else "left")
			else:
				_action("slide" if d.y > 0 else "jump")


func _on_key(key: Key) -> void:
	match key:
		KEY_LEFT, KEY_A:
			_action("left")
		KEY_RIGHT, KEY_D:
			_action("right")
		KEY_UP, KEY_W, KEY_SPACE:
			_action("jump")
		KEY_DOWN, KEY_S:
			_action("slide")
		KEY_ESCAPE, KEY_P:
			if state == State.PLAYING:
				_pause()
			elif state == State.PAUSED:
				_resume()
		KEY_ENTER, KEY_KP_ENTER:
			if state == State.MENU or state == State.DEAD:
				_start_run()


func _action(a: String) -> void:
	if state == State.MENU:
		_start_run()
		return
	if state != State.PLAYING:
		return
	match a:
		"left", "right":
			if player.move_lane(-1 if a == "left" else 1):
				Sfx.play("swipe", randf_range(0.95, 1.1), -4.0)
		"jump":
			if player.jump():
				Sfx.play("jump")
			else:
				_queued = "jump"  # pressed just before landing: jump as soon as we touch down
		"slide":
			player.slide()
			Sfx.play("slide", 1.0, -3.0)


# ------------------------------------------------------------------ update

func _physics_process(delta: float) -> void:
	match state:
		State.MENU:
			player.idle(delta)
			track.animate(delta)
		State.PLAYING:
			_update_run(delta)
		State.DEAD:
			_dead_time += delta
			player.die_anim(delta)
			track.animate(delta)
			if _autoplay and _dead_time > (2.5 if _shot_dir != "" else 0.3):
				_after_bot_death()
			elif not _over_shown and _dead_time > DEATH_PANEL_DELAY:
				_over_shown = true
				hud.show_game_over(_final_score, run_coins, SaveData.best_score, _final_best)
	_update_camera(delta)
	_maybe_screenshot(delta)


func _update_run(delta: float) -> void:
	if _bot and _bot_enabled:
		var a := _bot.think(player, track, speed)
		if a != "":
			_action(a)
	run_time += delta
	if _max_time > 0.0 and run_time >= _max_time:
		_die("survived")
		return
	speed = GameConfig.speed_at(run_time)
	var dz := speed * delta
	track.advance(dz, speed, delta)
	if player.step(delta, track, speed) == "land":
		Sfx.play("land", 1.0, -6.0)
		if _queued == "jump" and player.jump():
			Sfx.play("jump")
	if player.grounded:
		_queued = ""

	_check_hits(dz)
	if state != State.PLAYING:
		return
	_collect(delta)

	score += dz * (2.0 if double_left > 0.0 else 1.0)
	magnet_left = maxf(0.0, magnet_left - delta)
	double_left = maxf(0.0, double_left - delta)
	stumble_left = maxf(0.0, stumble_left - delta)
	hud.update_run(int(score), run_coins, magnet_left / GameConfig.MAGNET_TIME, double_left / GameConfig.DOUBLE_TIME)


func _check_hits(dz: float) -> void:
	var pbox := player.hit_box()
	for o in track.obstacles:
		if o.position.z < -60.0:
			continue
		for i in o.boxes.size():
			var b := o.world_box(i)
			if not b.intersects(pbox):
				continue
			# Did the obstacle just slide into our front, or were we already beside it?
			var front_before := b.end.z - dz
			var head_on := front_before <= pbox.position.z + 0.02
			if head_on or not player.is_changing_lane():
				_die("%s head-on (%s)" % [Obstacle.Kind.keys()[o.kind], o.pattern])
				return
			if player.is_reverting():
				return  # already bouncing back from this bump
			if stumble_left > 0.0:
				_die("%s second bump (%s)" % [Obstacle.Kind.keys()[o.kind], o.pattern])
				return
			stumble_left = GameConfig.STUMBLE_WINDOW
			player.revert_lane()
			_shake = 0.35
			Sfx.play("bump")
			Input.vibrate_handheld(60)
			hud.warn("CAREFUL!")
			return


func _collect(delta: float) -> void:
	var pc := player.center()
	var magnet := magnet_left > 0.0
	for i in range(track.coins.size() - 1, -1, -1):
		var c := track.coins[i]
		if magnet and c.position.z > -GameConfig.MAGNET_RANGE and c.position.z < 1.0:
			c.position = c.position.move_toward(pc, delta * (25.0 + speed))
		var d := c.position - pc
		if absf(d.x) < 0.8 and absf(d.z) < 0.8 and absf(d.y) < 1.1:
			track.remove_coin(c)
			run_coins += 1
			score += 5.0 * (2.0 if double_left > 0.0 else 1.0)
			Sfx.play("coin", 1.0 + float(run_coins % 5) * 0.03, -5.0)
	for i in range(track.powers.size() - 1, -1, -1):
		var p := track.powers[i]
		var d := p.position - pc
		if absf(d.x) < 0.9 and absf(d.z) < 0.9 and absf(d.y) < 1.3:
			var kind: String = p.get_meta("kind")
			track.remove_power(p)
			Sfx.play("power")
			if kind == "magnet":
				magnet_left = GameConfig.MAGNET_TIME
				hud.popup("MAGNET!", Color("ff6b6b"))
			else:
				double_left = GameConfig.DOUBLE_TIME
				hud.popup("x2 SCORE!", Color("37d67a"))


func _update_camera(delta: float) -> void:
	# portrait phone: fit the 3 lanes to the width. Wide desktop window: fit the height.
	var vp := get_viewport().get_visible_rect().size
	camera.keep_aspect = Camera3D.KEEP_WIDTH if vp.x < vp.y else Camera3D.KEEP_HEIGHT
	var target: Vector3
	var look: Vector3
	var px := player.position.x
	var py := player.position.y
	if state == State.MENU:
		target = MENU_CAM_POS
		look = MENU_CAM_LOOK
	else:
		target = Vector3(px * 0.8, 3.1 + py * 0.75, 5.0)
		look = Vector3(px * 0.8, 0.9 + py * 0.75, -12.0)
	var k := 1.0 - exp(-delta * (3.0 if state == State.MENU else 7.0))
	_cam_pos = _cam_pos.lerp(target, k)
	_cam_look = _cam_look.lerp(look, k)
	var shake_offset := Vector3.ZERO
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta)
		shake_offset = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.35
	camera.position = _cam_pos + shake_offset
	camera.look_at(_cam_look + shake_offset, Vector3.UP)
	var speed_t := (speed - GameConfig.START_SPEED) / (GameConfig.MAX_SPEED - GameConfig.START_SPEED)
	camera.fov = lerpf(camera.fov, 66.0 + 10.0 * speed_t if state == State.PLAYING else 66.0, k)


# ------------------------------------------------------------------ testing

func _bot_report(final: int) -> void:
	var line := "RUN %d: score=%d distance=%.0fm coins=%d time=%.1fs speed=%.1f died_on=%s" % [
		_runs_done + 1, final, track.distance, run_coins, run_time, speed, _death_cause]
	print(line)
	_report.append(line)


func _after_bot_death() -> void:
	_runs_done += 1
	if _runs_wanted > 0 and _runs_done >= _runs_wanted:
		print("BOT_SUMMARY runs=%d" % _runs_done)
		get_tree().quit()
		return
	_start_run()


func _maybe_screenshot(delta: float) -> void:
	if _shot_dir == "":
		return
	_shot_timer += delta
	if _shot_timer < 1.5:
		return
	_shot_timer = 0.0
	_shot_count += 1
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/shot_%03d_%s.png" % [_shot_dir, _shot_count, State.keys()[state].to_lower()])
