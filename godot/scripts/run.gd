extends Node3D
## A run: the web game's rules (Rules) played on the song's clock (Music), drawn in the city of the episode.
## The run's parts are nodes in run.tscn (camera, effects, HUD, panels); this script only places things each frame
## and passes the rules' events to the parts that show them.
##
## The rules work in the web game's units; the world is 1.4 times bigger (K), with the road at y = 0.

const K := 1.4
const VIEW := 170.0          # how far ahead rings and traffic appear (m); the haze hides the street beyond
const CAM_H := 2.0           # the web game's run camera (PLAY_CAM), in its units
const CAM_LOOK_Y := -0.7
const CAM_Z := 7.2
const FOV := 62.0

signal finished_run(result: Dictionary)

var rules := Rules.new()
var course := {}
var info := {}               # the episode: name, map, i, look, audio
var city: City
var car: Node3D
var pilot: Node3D
var paused := false
var started := false
var _rings := {}             # note index -> ring
var _cars := {}              # hazard index -> vehicle
var _cam_pos := Vector3.ZERO
var _cam_look := Vector3.ZERO
var _fov := FOV
var _prev := Vector2.ZERO
var _lead_next := [0, 1]  # (with marked layers both start at the first note; see _music)     # the next note index of each melody layer
var _swipe_from := Vector2.INF
var _swiped := false
var _resume_at := -1.0
var _ring_scene: PackedScene = preload("res://scenes/track/note_ring.tscn")
var _theme := {}
var menu := false            # the main menu's backdrop: the car flies the era's first course by itself, round and round
var garage := false          # the garage: a slow showroom turn around the car
var garage_angle := 0.0
var menu_look := -1.1        # on the menu the car rides higher on the screen, above the menu sheet
var revived := false
var m_done := []             # missions finished in this run: [{say, rw}]
var _paid_hits := 0
var _overs := 0

@onready var music: Music = $Music
@onready var camera: Camera3D = $Camera3D
@onready var ride: Node3D = $Ride
@onready var hud = $HUDLayer/HUD
@onready var fx = $Effects


func _ready() -> void:
	# what to fly: an episode, Flight School, Endless, or (behind the menus) the era's loop flown by the autopilot.
	# The last three are the era's own loop song in its first city, as in the web game
	var loop_from := -1.0
	var gain := 0.0
	match Launch.mode:
		"school":
			info = {"map": Launch.map, "i": 0, "name": "Flight School", "course": "res://data/school_%s.json" % Launch.map, "audio": "res://audio/school_%s" % Launch.map,
				"level": "res://scenes/levels/school_%s.tscn" % Launch.map}
			gain = 6.0
		"endless", "menu":
			var level: String = Save.setting("level") if Launch.mode == "endless" else "normal"
			var k := randi() % 6 if Launch.mode == "endless" else 0
			info = {"map": Launch.map, "i": 0, "name": "Endless", "level": level, "course": "res://data/endless_%s_%s_%d.json" % [Launch.map, level, k], "audio": "res://audio/loop_%s" % Launch.map}
			gain = 6.0
		_:
			info = Catalog.episodes(Launch.map)[Launch.index].duplicate()
			info.level = "res://scenes/levels/%s_%d.tscn" % [info.map, info.i]
	# an episode or a lesson is its level scene (the street, the rings and the traffic as laid out in the editor);
	# Endless is a generated loop, read from its data
	var lv: Level = null
	if ResourceLoader.exists(info.get("level", "")):
		lv = (load(info.level) as PackedScene).instantiate() as Level
		course = lv.course()
		lv.get_node("Notes").free()
		lv.get_node("Traffic").free()
	else:
		course = JSON.parse_string(FileAccess.get_file_as_string(info.course))
	if course.get("loop") is Dictionary:
		loop_from = float(course.loop.from)
	if course.notes.size() > 0 and course.notes[0].has("layer"):
		_lead_next = [0, 0]
	_theme = Catalog.theme(info.map)
	var perk := Catalog.perk(Save.data.car)
	rules.reach_car = perk.reach
	rules.magnet_k = perk.mag
	rules.start_shield = perk.startShield
	menu = Launch.mode == "menu"
	rules.load_course(course, Launch.mode == "school" or menu)
	if menu:
		rules.autopilot = true
		rules.autopilot_lead = 0.13
	_connect_rules()
	# the city of the episode
	if lv:
		$CityHolder.add_child(lv)
		city = lv.get_node("City")
		city.use_street(lv.get_node("Street"))
	else:
		city = (load("res://scenes/cities/%s_%d.tscn" % [info.map, info.i]) as PackedScene).instantiate()
		$CityHolder.add_child(city)
	# the car in the era's paint, the pilot ready for the jetpack
	car = (load("res://scenes/cars/%s.tscn" % Save.data.car) as PackedScene).instantiate()
	ride.add_child(car)
	var pods: Array = _theme.pods
	car.paint(Catalog_hex(_theme.paint), Catalog_hex(_theme.strip), Color(pods[0], pods[1], pods[2]))
	pilot = (load("res://scenes/pilots/%s.tscn" % Save.data.pilot) as PackedScene).instantiate()
	ride.add_child(pilot)
	pilot.visible = false
	var cal = Save.data.settings.get("cal")
	music.offset = float(cal) if cal is float or cal is int else 0.0
	music.load_song(info.audio, loop_from, gain)
	if menu:
		# behind the menus the main-menu theme plays instead (main.gd)
		music.band_player.volume_db = -80.0
		music.lead_player.volume_db = -80.0
	hud.setup(info, rules)
	if menu:
		$HUDLayer.visible = false
	hud.pause_pressed.connect(pause)
	if has_node("Panels"):
		$Panels.run = self
	_cam_pos = _cam_target()
	_cam_look = _look_target()
	_place(0.0)
	await get_tree().create_timer(0.4).timeout
	music.start(0.0)
	started = true


static func Catalog_hex(v) -> Color:
	var n := int(v)
	return Color8((n >> 16) & 255, (n >> 8) & 255, n & 255)


func _connect_rules() -> void:
	rules.judged.connect(_on_judged)
	rules.missed.connect(_on_missed)
	rules.crashed.connect(_on_crashed)
	rules.shield_saved.connect(func(h): fx.shield_hit(ride.global_position); _strike(h))
	rules.form_lost.connect(_on_form_lost)
	rules.delivered.connect(_on_delivered)
	rules.overdrive.connect(_on_overdrive)
	rules.tier_up.connect(func(t): hud.tier_up(t))
	rules.popped.connect(func(text, kind, pri): hud.pop(text, kind, pri))
	rules.power_up.connect(func(k): fx.power_up(ride.global_position, k); mission("power", 1); Sound.play("chime"))
	rules.edge_bump.connect(func(d): fx.edge_bump(d))
	rules.moved.connect(_on_moved)
	rules.cleared.connect(_on_cleared)
	rules.game_over.connect(_on_game_over)


# ------------------------------------------------------------------ the frame

func _process(delta: float) -> void:
	if not started or paused:
		return
	if _resume_at >= 0.0:
		return
	var t := music.song_time()
	if rules.tutorial and not menu:
		t = _school(t, delta)
	rules.step(t)
	_place(delta)
	_music()
	hud.update(t)
	if rules.overs != _overs:
		mission("over", rules.overs - _overs)
		_overs = rules.overs
	for d in get_tree().get_nodes_in_group("deco"):
		d.song_t = t
		d.beat = rules.BEAT


# ------------------------------------------------------------------ Flight School: hold until the move is made

const SLOWMO := 0.3
const TUT_MOVE := {"right": ["→", "SWIPE RIGHT"], "left": ["←", "SWIPE LEFT"], "up": ["↑", "SWIPE UP"], "down": ["↓", "SWIPE DOWN"]}
var _hold := {}
var _hold_t := 0.0
var _shown := {}


func _tut_ok(w: Dictionary) -> bool:
	return rules.row == int(w.row) if w.wait == "up" or w.wait == "down" else rules.col == int(w.col)


func _school(t: float, delta: float) -> float:
	## a note that teaches a move: as it comes up the world slows almost to a stop (the music waits) until you make
	## that move; each move is taught once
	if _hold.is_empty():
		for n in rules.notes:
			if n.state == 0 and String(n.get("wait", "")) != "" and not n.get("waited", false):
				if float(n.t) - t < 0.9:
					if _tut_ok(n) or _shown.has(n.wait):
						n.waited = true
					else:
						_hold = n
						_hold_t = t
						_shown[n.wait] = true
						music.set_paused(true)
						hud.hold(TUT_MOVE[n.wait][0], TUT_MOVE[n.wait][1])
				break
		return t
	if _tut_ok(_hold):
		_hold.waited = true
		_hold = {}
		hud.hold("", "")
		music.set_paused(false)
		music.seek(_hold_t)
		return _hold_t
	var lead := float(_hold.t) - _hold_t
	if lead > 0.34:
		_hold_t += minf(delta * SLOWMO, lead - 0.34)
	return _hold_t


func car_z() -> float:
	return -rules.t * rules.SPEED * K


func world(cx: float, cy: float, z: float) -> Vector3:
	## a place in the rules' units (x, y across and up, the road at ROAD_Y) at street depth z (m)
	return Vector3(cx * K, (cy - Rules.ROAD_Y) * K, z)


func _place(delta: float) -> void:
	var cz := car_z()
	city.follow(cz)
	# the ride
	var vel := Vector2(rules.vx, rules.vy) * K
	ride.position = world(rules.x, rules.y, cz)
	ride.rotation = Vector3(clampf(vel.y * 0.04, -0.3, 0.3), 0.0, clampf(-vel.x * 0.05, -0.45, 0.45))
	var crashed := rules.respawn > 0.0
	ride.visible = not crashed or fmod(rules.respawn, 0.2) < 0.1
	if rules.invuln > 0.0 and not crashed:
		ride.visible = fmod(rules.invuln, 0.16) < 0.11
	car.visible = rules.form == 2 and not (garage and _show_pilot)
	pilot.visible = rules.form == 1 or (garage and _show_pilot)
	pilot.flying = not garage
	if car.visible:
		car.motion(vel, 1.0 if rules.od_t > 0.0 else 0.0)
	else:
		pilot.lean(vel.x, vel.y)
	# rings ahead, from the note data
	var t := rules.t
	var ahead := VIEW / (rules.SPEED * K)
	for n in rules.notes:
		var i: int = n.i
		var near := float(n.t) > t - 0.6 and float(n.t) < t + ahead
		if near and not _rings.has(i):
			var r := _ring_scene.instantiate()
			$Rings.add_child(r)
			r.setup(n)
			r.position = world(Rules.LX[n.col], Rules.LY[n.row], -float(n.t) * rules.SPEED * K)
			_rings[i] = r
		elif not near and _rings.has(i):
			_rings[i].queue_free()
			_rings.erase(i)
		if _rings.has(i):
			_rings[i].show_cue(t)
			_rings[i].set_distance(cz - _rings[i].position.z)
	# traffic and roadblocks
	for hi in rules.hazards.size():
		var h: Dictionary = rules.hazards[hi]
		var z := rules.hazard_z(h) * K
		var near := z > -VIEW and z < 30.0
		if near and not _cars.has(hi):
			var v := city.vehicle(h.kind, hi)
			if v == null:
				continue
			$Traffic.add_child(v)
			_cars[hi] = v
		elif not near and _cars.has(hi):
			_cars[hi].queue_free()
			_cars.erase(hi)
		if _cars.has(hi):
			var v: Node3D = _cars[hi]
			if not (v.has_method("is_struck") and v.is_struck()):
				v.position = world(Rules.LX[h.col], Rules.LY[h.row], cz + z)
	# the camera glides after the car, never rolls or shakes; the view widens in Overdrive
	var k := 1.0 - exp(-delta * 4.0) if delta > 0.0 else 1.0
	_cam_pos = _cam_pos.lerp(_cam_target(), k)
	_cam_look = _cam_look.lerp(_look_target(), k)
	camera.position = Vector3(_cam_pos.x, _cam_pos.y, cz + _cam_pos.z)
	camera.look_at(Vector3(_cam_look.x, _cam_look.y, cz + _cam_look.z))
	var fov_t := FOV + (9.0 if rules.od_t > 0.0 and not Save.data.settings.get("fx_low", false) else 0.0)
	_fov += (fov_t - _fov) * minf(1.0, delta * 5.0)
	camera.fov = _fov
	fx.follow(camera, ride, rules)


func set_garage(on: bool) -> void:
	garage = on


func show_ride(car_key: String, pilot_key: String, show_pilot: bool) -> void:
	## the garage: swap in the car or pilot being looked at
	if car.scene_file_path.get_file().get_basename() != car_key:
		car.queue_free()
		car = (load("res://scenes/cars/%s.tscn" % car_key) as PackedScene).instantiate()
		ride.add_child(car)
		var pods: Array = _theme.pods
		car.paint(Catalog_hex(_theme.paint), Catalog_hex(_theme.strip), Color(pods[0], pods[1], pods[2]))
	if pilot.scene_file_path.get_file().get_basename() != pilot_key:
		pilot.queue_free()
		pilot = (load("res://scenes/pilots/%s.tscn" % pilot_key) as PackedScene).instantiate()
		ride.add_child(pilot)
	_show_pilot = show_pilot


var _show_pilot := false


func _cam_target() -> Vector3:
	if garage:
		var a := garage_angle + rules.t * 0.3
		var sa := sin(a)
		return Vector3(rules.x * K + sa * 3.3 * K, (rules.y - Rules.ROAD_Y + 1.2 + absf(sa) * 0.9) * K, cos(a) * 4.8 * K)
	if menu:
		return Vector3(rules.x * 0.7 * K, (rules.y * 0.45 + 1.4 - Rules.ROAD_Y) * K, CAM_Z * K)
	var cz := CAM_Z - (1.0 if rules.form < 2 else 0.0)
	return Vector3(rules.x * 0.7 * K, (rules.y * 0.45 + CAM_H - Rules.ROAD_Y) * K, cz * K)


func _look_target() -> Vector3:
	if garage:
		return Vector3(rules.x * K, (rules.y - 0.55 - Rules.ROAD_Y) * K, 0.0)
	if menu:
		return Vector3(rules.x * 0.6 * K, (rules.y * 0.4 + menu_look - Rules.ROAD_Y) * K, -14.0 * K)
	return Vector3(rules.x * 0.6 * K, (rules.y * 0.4 + CAM_LOOK_Y - Rules.ROAD_Y) * K, -14.0 * K)


func _music() -> void:
	music.set_band(rules.band, rules.od_t > 0.0, rules.form == 1)
	music.set_form(rules.form if rules.respawn <= 0.0 else 0)
	# the melody: every other note on its own layer. As each note comes up its layer opens if the note is played
	# (or the car is in its cell), and closes if not, so a missed note is never heard
	# (the episodes' recordings alternate note by note; the loop songs mark each note's layer)
	var marked: bool = rules.notes.size() > 0 and rules.notes[0].has("layer")
	for layer in 2:
		var i: int = _lead_next[layer]
		while i < rules.notes.size():
			var n: Dictionary = rules.notes[i]
			if float(n.t) - 0.02 > rules.t:
				break
			if marked and int(n.layer) != layer:
				i += 1
				continue
			var ok: bool = n.state == 1 or (n.state == 0 and absf(rules.x - Rules.LX[n.col]) < rules.reach_now() and absf(rules.y - Rules.LY[n.row]) < 0.7)
			music.set_lead(layer, ok)
			i += 1 if marked else 2
		_lead_next[layer] = i


# ------------------------------------------------------------------ events

func _on_overdrive(on: bool) -> void:
	fx.overdrive(on)
	hud.overdrive(on)
	if on:
		mission("od", 1)


func _on_moved(dc: int, dr: int) -> void:
	fx.moved(dc, dr)
	if not menu:
		Sound.play("whoosh")


func _on_judged(grade: String, n: Dictionary) -> void:
	music.set_lead(int(n.get("layer", int(n.i) % 2)), true)
	if _rings.has(n.i):
		_rings[n.i].played()
		fx.catch(_rings[n.i].global_position, int(n.row))
	hud.judged(grade, rules)
	mission("coins", 1)
	mission("combo", rules.combo)
	if grade == "ex":
		mission("excellent", 1)


func _on_missed(n: Dictionary) -> void:
	music.set_lead(int(n.get("layer", int(n.i) % 2)), false)
	if _rings.has(n.i):
		_rings[n.i].missed()
	hud.missed(rules)


func _strike(h: Dictionary) -> void:
	var hi := rules.hazards.find(h)
	if _cars.has(hi) and _cars[hi].has_method("struck"):
		_cars[hi].struck(ride.global_position)


func _on_crashed(h: Dictionary) -> void:
	_strike(h)
	if not menu:
		Sound.play("crash")
	music.muffle()
	fx.crash(ride.global_position, rules.form)
	hud.crash()
	if Save.data.settings.get("haptics", true):
		Input.vibrate_handheld(220)


func _on_form_lost(form: int) -> void:
	hud.form(form)
	# the car blows up and the pilot ejects
	Sound.play("explode", -4.0 if form == 1 else 0.0)


func _on_delivered(form: int) -> void:
	Sound.play("deliver")
	if form == 2:
		mission("rescue", 1)
	fx.delivered(ride.global_position, form)
	hud.form(form)


func _on_cleared() -> void:
	if menu:
		# round again
		for r in _rings.values():
			r.queue_free()
		for v in _cars.values():
			v.queue_free()
		_rings.clear()
		_cars.clear()
		_lead_next = [0, 0] if course.notes[0].has("layer") else [0, 1]
		rules.load_course(course, true)
		rules.autopilot = true
		rules.autopilot_lead = 0.13
		music.stop()
		music.start(0.0)
		return
	started = false
	var res := result()
	finished_run.emit(res)
	if has_node("Panels"):
		if Launch.mode == "school":
			$Panels.show_school()
		else:
			$Panels.show_results(res)


func _on_game_over() -> void:
	paused = true
	music.set_paused(true)
	if has_node("Panels"):
		$Panels.show_game_over(self)


func mission(id: String, n: int) -> void:
	## mission progress during a run (not in Flight School); a finished one pays at once and says so
	if rules.tutorial or rules.autopilot:
		return
	for d in Save.mission(id, n):
		m_done.append(d)
		hud.pop("MISSION DONE +%d" % int(d.rw), "gold", 2)


func pay(bonus: int) -> int:
	## coins for the notes played since the last payment (the car's perk can add a quarter), plus any bonus
	var n := roundi((rules.hits - _paid_hits) * float(Catalog.perk(Save.data.car).coin)) + bonus
	_paid_hits = rules.hits
	if not rules.autopilot:
		Save.add_coins(n)
	return n


func result() -> Dictionary:
	var acc := rules.accuracy()
	var g := Rules.grade_of(acc, rules.lost == 0)
	return {"map": info.map, "i": info.i, "name": info.name, "score": rules.score, "acc": acc, "grade": g,
		"stars": Rules.stars_for(g), "J": rules.J.duplicate(), "max_combo": rules.max_combo, "lost": rules.lost,
		"overs": rules.overs, "hits": rules.hits, "od": rules.od_n, "mode": Launch.mode}


# ------------------------------------------------------------------ pause, revive

func pause() -> void:
	if paused or not started:
		return
	paused = true
	music.set_paused(true)
	if has_node("Panels"):
		$Panels.show_pause(self)


func resume() -> void:
	## a count-in of three beats, then the song carries on where it stopped
	if has_node("Panels"):
		$Panels.hide_all()
	_resume_at = 0.0
	paused = false
	for i in 3:
		hud.count(3 - i)
		await get_tree().create_timer(0.5).timeout
	hud.count(0)
	_resume_at = -1.0
	music.set_paused(false)


func revive() -> void:
	rules.revive()
	hud.form(1)
	resume()


# ------------------------------------------------------------------ input: swipes, arrows

func _unhandled_input(e: InputEvent) -> void:
	if not started or paused or menu:
		return
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_LEFT, KEY_A:
				rules.move(-1, 0)
			KEY_RIGHT, KEY_D:
				rules.move(1, 0)
			KEY_UP, KEY_W:
				rules.move(0, 1)
			KEY_DOWN, KEY_S:
				rules.move(0, -1)
			KEY_ESCAPE, KEY_P:
				pause()
		return
	if e is InputEventScreenTouch:
		if e.pressed:
			_swipe_from = e.position
			_swiped = false
		else:
			_swipe_from = Vector2.INF
	elif e is InputEventScreenDrag and _swipe_from != Vector2.INF and not _swiped:
		var d: Vector2 = e.position - _swipe_from
		# a swipe counts as soon as it is long enough, so moves land on the beat rather than on lifting the finger
		if d.length() > 22.0:
			_swiped = true
			if absf(d.x) > absf(d.y):
				rules.move(signi(int(d.x)), 0)
			else:
				rules.move(0, -signi(int(d.y)))


func _notification(what: int) -> void:
	if not menu and (what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED):
		pause()
