extends Node3D
## Tempo Drift: three eras of eight cities each, from London 1890 to Las Vegas 2099.
## Puts the pieces together: the baked course and soundtrack, the street, the car, the rings, the traffic, the HUD,
## and the camera, and runs a song from the title card to the results.
##
## Command-line options (after "--"), for testing:
##   --ep=N             which episode (0 London ... 7 Rome, 8 Dubai ... 15 Reykjavik, 16 Hong Kong ... 23 Las Vegas)
##   --sim              play the whole episode at once with a perfect pilot and print the result
##   --shots=DIR        play it with the perfect pilot at a fixed frame rate and save screenshots in DIR
##   --at=SECONDS       (with --shots) where in the song to take them

const EPISODES := [
	{"id": "old_0", "city": "LONDON", "geo": "London", "year": "1890", "look": "london", "band": "music-hall swing · piano"},
	{"id": "old_1", "city": "ISTANBUL", "geo": "Istanbul", "year": "1910", "look": "istanbul", "band": "oud, darbuka and kanun"},
	{"id": "old_2", "city": "PARIS", "geo": "Paris", "year": "1925", "look": "paris", "band": "gypsy jazz · accordion"},
	{"id": "old_3", "city": "NEW YORK", "geo": "New York", "year": "1935", "look": "newyork", "band": "big band · clarinet"},
	{"id": "old_4", "city": "HAVANA", "geo": "Havana", "year": "1955", "look": "havana", "band": "son cubano · trumpet"},
	{"id": "old_5", "city": "VIENNA", "geo": "Vienna", "year": "1905", "look": "vienna", "band": "salon orchestra · violin"},
	{"id": "old_6", "city": "CAIRO", "geo": "Cairo", "year": "1925", "look": "cairo", "band": "oud and kanun · nay"},
	{"id": "old_7", "city": "ROME", "geo": "Rome", "year": "1948", "look": "rome", "band": "mandolin and accordion"},
	{"id": "sunset_0", "city": "DUBAI", "geo": "Dubai", "year": "", "look": "dubai", "band": "Arabic pop · harp"},
	{"id": "sunset_1", "city": "RIO", "geo": "Rio de Janeiro", "year": "", "look": "rio", "band": "bossa nova · trumpet"},
	{"id": "sunset_2", "city": "SINGAPORE", "geo": "Singapore", "year": "", "look": "singapore", "band": "synth pop · celesta"},
	{"id": "sunset_3", "city": "SAN FRANCISCO", "geo": "San Francisco", "year": "", "look": "sanfrancisco", "band": "guitar pop · glockenspiel"},
	{"id": "sunset_4", "city": "SYDNEY", "geo": "Sydney", "year": "", "look": "sydney", "band": "house · supersaw"},
	{"id": "sunset_5", "city": "CAPE TOWN", "geo": "Cape Town", "year": "", "look": "capetown", "band": "afro house · marimba"},
	{"id": "sunset_6", "city": "BARCELONA", "geo": "Barcelona", "year": "", "look": "barcelona", "band": "flamenco pop · guitar"},
	{"id": "sunset_7", "city": "REYKJAVIK", "geo": "Reykjavík", "year": "", "look": "reykjavik", "band": "ambient electronica"},
	{"id": "rain_0", "city": "HONG KONG", "geo": "Hong Kong", "year": "2049", "look": "hongkong", "band": "synthwave · crystal"},
	{"id": "rain_1", "city": "TOKYO", "geo": "Tokyo", "year": "2060", "look": "tokyo", "band": "808 trap · koto"},
	{"id": "rain_2", "city": "LOS ANGELES", "geo": "Los Angeles", "year": "2070", "look": "losangeles", "band": "synthwave · tenor sax"},
	{"id": "rain_3", "city": "SHANGHAI", "geo": "Shanghai", "year": "2085", "look": "shanghai", "band": "techno · crystal"},
	{"id": "rain_4", "city": "SEOUL", "geo": "Seoul", "year": "2099", "look": "seoul", "band": "future k-pop · flute"},
	{"id": "rain_5", "city": "BERLIN", "geo": "Berlin", "year": "2075", "look": "berlin", "band": "acid techno"},
	{"id": "rain_6", "city": "MIAMI", "geo": "Miami", "year": "2088", "look": "miami", "band": "outrun · supersaw"},
	{"id": "rain_7", "city": "LAS VEGAS", "geo": "Las Vegas", "year": "2099", "look": "vegas", "band": "electro house · chiptune"},
]
# the three eras: an era opens with ERA_NEED stars in the one before it
const ERAS := {"old": {"name": "THE PAST", "years": "1890–1955"}, "sunset": {"name": "THE PRESENT", "years": "today"},
	"rain": {"name": "THE FUTURE", "years": "2049–2099"}}
const ERA_ORDER := ["old", "sunset", "rain"]
const ERA_NEED := 10
const SAVE := "user://save.cfg"

var ep := 0
var game: Game
var music: Music
var world: World
var rings: Rings
var traffic: Traffic
var fx: Fx
var hud: Hud
var cam: Camera3D
var car: Node3D
var pilot: Node3D
var arch: Node3D
var quality: Quality

var state := "title"      # title, play, results
var cam_pos := Vector3(0, 2.0, 7.2)
var cam_look := Vector3(0, -0.7, -14.0)
var touch_start := Vector2.ZERO
var touch_fired := false
var touching := false
var sim_mode := false
var shot_dir := ""
var shot_at := []
var fixed_t := -0.05
var auto := false
var last_beat := -1
var beat_pulse := 0.0
var bank := 0.0
var pitch := 0.0
var eject_from := Vector3.ZERO
var title_shot := false
var crash_at := -1.0
var results_shot := false
var ep_arg := -1
var od_k := 0.0
var streaks: GPUParticles3D

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a == "--sim":
			sim_mode = true
		elif a.begins_with("--ep="):
			ep_arg = int(a.substr(5))
		elif a.begins_with("--shots="):
			shot_dir = a.substr(8)
		elif a.begins_with("--crash="):
			crash_at = float(a.substr(8))
		elif a == "--results":
			results_shot = true
		elif a == "--title":
			title_shot = true
		elif a.begins_with("--at="):
			for s in a.substr(5).split(","):
				shot_at.append(float(s))
	auto = sim_mode or shot_dir != ""
	var save := ConfigFile.new()
	save.load(SAVE)
	ep = ep_arg if ep_arg >= 0 else clampi(save.get_value("play", "episode", 0), 0, EPISODES.size() - 1)
	game = Game.new()
	add_child(game)
	game.load_course("res://data/%s.json" % EPISODES[ep].id)
	if sim_mode:
		_run_sim()
		return
	music = Music.new()
	add_child(music)
	fx = Fx.new()
	add_child(fx)
	fx.setup()
	var sv := ConfigFile.new()
	sv.load(SAVE)
	sel_car = sv.get_value("garage", "car", "roadster")
	sel_pilot = sv.get_value("garage", "pilot", "aviator")
	_rebuild_vehicles(sel_car, sel_pilot)
	var fill := DirectionalLight3D.new()
	fill.light_color = Color(0.86, 0.9, 1.0)
	fill.light_energy = 0.85
	fill.light_cull_mask = 2
	fill.light_specular = 0.6
	add_child(fill)
	fill.look_at_from_position(Vector3.ZERO, Vector3(0.25, -0.55, -1.0), Vector3.UP)
	streaks = _make_streaks()
	add_child(streaks)
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.1
	cam.far = 600.0
	add_child(cam)
	cam.make_current()
	hud = Hud.new()
	add_child(hud)
	hud.start_pressed.connect(_start)
	hud.again_pressed.connect(_again)
	hud.episode_chosen.connect(_choose_episode)
	hud.menu_pressed.connect(_to_title)
	hud.garage_opened.connect(func():
		state = "garage"
		hud.open_garage(_garage_data()))
	hud.garage_browse.connect(_garage_browse)
	hud.garage_action.connect(_garage_action)
	hud.garage_closed.connect(func():
		state = "title"
		garage_tab = "cars"
		_rebuild_vehicles(sel_car, sel_pilot))
	hud.dev_coins.connect(func():
		_wallet_add(5000)
		hud.refresh_garage(_garage_data()))
	game.shielded.connect(func(): fx.note_hit(car.global_position, Color(0.56, 0.96, 1.0) * 2.5, true))
	hud.fly_to.connect(func(i):
		await _choose_episode(i)
		_start())
	hud.dev_toggled.connect(func(on):
		var dsv := ConfigFile.new()
		dsv.load(SAVE)
		dsv.set_value("play", "dev", on)
		dsv.save(SAVE)
		hud.set_episodes(_episode_cards(), ep))
	game.judged.connect(_on_judged)
	game.missed.connect(_on_missed)
	game.crashed.connect(_on_crashed)
	game.delivered.connect(_on_delivered)
	game.popped.connect(func(text, kind): hud.pop(text, kind))
	game.cleared.connect(func(r): _finish(r, true))
	game.game_over.connect(func(r): _finish(r, false))
	game.finished.connect(func(): hud.pop("FINISH!", "gold"))
	quality = Quality.new()
	add_child(quality)
	await _load_episode(ep)
	quality.setup(self)
	var cf := ConfigFile.new()
	cf.load(Quality.SAVE)
	music.offset = cf.get_value("audio", "offset_ms", 0) / 1000.0
	hud.quality_chosen.connect(func(c):
		quality.set_choice(c)
		hud.show_settings_state(quality.choice, quality.label(), int(music.offset * 1000.0)))
	hud.offset_changed.connect(func(ms):
		music.offset = ms / 1000.0
		var cf2 := ConfigFile.new()
		cf2.load(Quality.SAVE)
		cf2.set_value("audio", "offset_ms", ms)
		cf2.save(Quality.SAVE))
	hud.show_settings_state(quality.choice, quality.label(), int(music.offset * 1000.0))
	var sv0 := ConfigFile.new()
	sv0.load(SAVE)
	hud.dev_check.set_pressed_no_signal(sv0.get_value("play", "dev", true))
	_place_camera(1.0)
	hud.show_title(true)
	if shot_dir != "":
		DirAccess.make_dir_recursive_absolute(shot_dir)
		Engine.max_fps = 0
		if "--garage" in OS.get_cmdline_user_args():
			# every car and every pilot in the showroom
			state = "garage"
			hud.open_garage(_garage_data())
			for tab in ["cars", "pilots"]:
				var src: Dictionary = Models.CARS if tab == "cars" else Models.PILOTS
				hud._g_show_tab(tab)
				for k in src:
					hud.g_i = src.keys().find(k)
					hud._g_show()
					_garage_browse(tab, k)
					for i in 45:
						await get_tree().process_frame
					await RenderingServer.frame_post_draw
					get_viewport().get_texture().get_image().save_png("%s/garage_%s_%s.png" % [shot_dir, tab, k])
					print("SHOT garage ", k)
			get_tree().quit()
			return
		if "--map" in OS.get_cmdline_user_args():
			hud.open_map()
			for i in 30:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(shot_dir + "/map.png")
			print("SHOT map")
			get_tree().quit()
			return
		if title_shot:
			for i in 40:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(shot_dir + "/title.png")
			print("SHOT title")
		_start()

## builds an episode: its course and soundtrack, its city, its rings and traffic, its finish arch
## on the web the Present and the Future come as their own downloads (each about 75 MB of music), fetched the first time
## you fly there and kept on the device; the Past ships with the game
func _ensure_era(era: String) -> void:
	if not OS.has_feature("web") or era == "old" or ResourceLoader.exists("res://audio/%s_0/core.ogg" % era):
		return
	var file := "user://%s.pck" % era
	if not FileAccess.file_exists(file):
		var base: String = str(JavaScriptBridge.eval("location.href.replace(/[^/]*$/, '')"))
		var http := HTTPRequest.new()
		http.download_file = file
		add_child(http)
		var done := [false, 0]
		http.request_completed.connect(func(res, code, _h, _b):
			done[0] = true
			done[1] = code)
		http.request(base + era + ".pck")
		while not done[0]:
			var total := http.get_body_size()
			hud.show_loading("DOWNLOADING %s" % ERAS[era].name, float(http.get_downloaded_bytes()) / total if total > 0 else 0.0)
			await get_tree().process_frame
		http.queue_free()
		if done[1] != 200:
			DirAccess.remove_absolute(file)
			hud.show_loading("COULDN'T DOWNLOAD %s · CHECK THE CONNECTION" % ERAS[era].name, 0.0)
			await get_tree().create_timer(2.5).timeout
			hud.hide_loading()
			return
	ProjectSettings.load_resource_pack(file)
	hud.hide_loading()

func _load_episode(i: int) -> void:
	await _ensure_era(EPISODES[i].id.split("_")[0])
	ep = i
	var E: Dictionary = EPISODES[i]
	for n in [world, rings, traffic, arch]:
		if n:
			n.queue_free()
	game.load_course("res://data/%s.json" % E.id)
	music.stop()
	music.load_song("res://audio/" + E.id)
	world = World.new()
	add_child(world)
	world.build((game.gate + game.BAR * 3.0) * game.SPEED, E.look)
	rings = Rings.new()
	add_child(rings)
	rings.setup(game)
	traffic = Traffic.new()
	add_child(traffic)
	traffic.setup(game)
	arch = Models.finish_arch()
	arch.position = Vector3(0, World.ROAD_Y, -game.gate * game.SPEED)
	add_child(arch)
	if quality.main:
		quality.apply()
	hud.set_episodes(_episode_cards(), ep)
	var save := ConfigFile.new()
	save.load(SAVE)
	save.set_value("play", "episode", ep)
	save.save(SAVE)

var geo := {}
var bpms := {}

## what the map and the title show for each city: where it is, its band, its best result, and whether it's open
## (a city opens when the one before it is cleared, or all at once with the testing switch)
func _episode_cards() -> Array:
	var save := ConfigFile.new()
	save.load(SAVE)
	if geo.is_empty():
		geo = JSON.parse_string(FileAccess.open("res://data/world.json", FileAccess.READ).get_as_text()).cities
		for E in EPISODES:
			bpms[E.id] = JSON.parse_string(FileAccess.open("res://data/%s.json" % E.id, FileAccess.READ).get_as_text()).bpm
	var dev: bool = save.get_value("play", "dev", true)
	# stars per era, for opening the next era
	var era_stars := {}
	for E in EPISODES:
		var er: String = E.id.split("_")[0]
		era_stars[er] = era_stars.get(er, 0) + save.get_value(E.id, "stars", 0)
	var out := []
	for i in EPISODES.size():
		var E: Dictionary = EPISODES[i]
		var era: String = E.id.split("_")[0]
		var k := int(E.id.split("_")[1])
		var ll: Array = geo[E.geo]
		var ei := ERA_ORDER.find(era)
		var era_open: bool = ei == 0 or era_stars.get(ERA_ORDER[ei - 1], 0) >= ERA_NEED
		var open: bool = dev or (era_open and (k == 0 or save.get_value(EPISODES[i - 1].id, "stars", 0) > 0))
		out.append({"city": E.city, "geo": E.geo, "year": E.year, "band": E.band, "bpm": bpms[E.id], "lat": ll[0], "lon": ll[1],
			"stars": save.get_value(E.id, "stars", 0), "best": save.get_value(E.id, "best", 0), "grade": save.get_value(E.id, "grade", ""),
			"open": open, "era": era, "k": k, "era_name": ERAS[era].name, "era_years": ERAS[era].years,
			"era_lock": "" if (dev or era_open) else "%d★ IN %s TO OPEN" % [ERA_NEED, ERAS[ERA_ORDER[maxi(ei - 1, 0)]].name]})
	return out

func _choose_episode(i: int) -> void:
	if i == ep or state == "play":
		return
	await _load_episode(i)
	game.t = -0.05
	_place_camera(1.0)

func _to_title() -> void:
	music.stop()
	state = "title"
	game.reset()
	hud.hide_results()
	hud.show_title(true)
	hud.set_episodes(_episode_cards(), ep)

func _start() -> void:
	game.perk = Models.CARS[sel_car].perk
	game.reset()
	game.running = true
	state = "play"
	hud.show_title(false)
	hud.hide_results()
	car.visible = true
	pilot.visible = false
	music.set_form_filter(2)
	if shot_dir == "":
		music.start()
	fixed_t = -0.05

func _again() -> void:
	music.stop()
	for i in traffic.models:
		traffic.models[i].visible = false
	_start()

## keeps the best result of each episode
func _save_result(r: Dictionary) -> void:
	var id: String = EPISODES[ep].id
	var save := ConfigFile.new()
	save.load(SAVE)
	if r.stars > save.get_value(id, "stars", 0):
		save.set_value(id, "stars", r.stars)
		save.set_value(id, "grade", r.grade)
	if r.score > save.get_value(id, "best", 0):
		save.set_value(id, "best", r.score)
		r.new_best = true
	save.save(SAVE)

func _finish(r: Dictionary, cleared: bool) -> void:
	state = "results"
	var stars_before := 0
	if shot_dir == "":
		var sv := ConfigFile.new()
		sv.load(SAVE)
		stars_before = sv.get_value(EPISODES[ep].id, "stars", 0)
	if cleared and shot_dir == "":
		_save_result(r)
	if shot_dir == "":
		# coins: one for every note played (the Manta adds a quarter), and STAR_PAY for every new star
		var n := int(round(r.J.c * (1.25 if game.perk == "coins" else 1.0)))
		if cleared:
			n += maxi(0, r.stars - stars_before) * STAR_PAY
		_wallet_add(n)
		r.coins = n
		r.wallet = _wallet()
	if shot_dir != "":
		print("RESULT ", JSON.stringify(r))
		if results_shot:
			hud.show_results(r, cleared, (EPISODES[ep].city + " " + EPISODES[ep].year).strip_edges())
			for i in 20:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(shot_dir + "/results.png")
			print("SHOT results")
		get_tree().quit()
		return
	await get_tree().create_timer(0.9 if cleared else 1.4).timeout
	hud.show_results(r, cleared, (EPISODES[ep].city + " " + EPISODES[ep].year).strip_edges())

## Overdrive's light streaks: long warm lines flying past on both sides
func _make_streaks() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 90
	p.lifetime = 0.7
	p.emitting = false
	p.visibility_aabb = AABB(Vector3(-20, -10, -40), Vector3(40, 20, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(6.0, 3.0, 8.0)
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 0.0
	pm.initial_velocity_min = 45.0
	pm.initial_velocity_max = 70.0
	pm.gravity = Vector3.ZERO
	pm.particle_flag_align_y = true
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.035, 3.2)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/rain.gdshader")
	m.set_shader_parameter("tint", Color(1.0, 0.7, 0.4))
	m.set_shader_parameter("energy", 1.4)
	q.material = m
	p.draw_pass_1 = q
	return p

# ---------------------------------------------------------------- the garage and the wallet

const STAR_PAY := 100
var sel_car := "roadster"
var sel_pilot := "aviator"
var garage_tab := "cars"

func _wallet() -> int:
	var sv := ConfigFile.new()
	sv.load(SAVE)
	return sv.get_value("wallet", "coins", 0)

func _wallet_add(n: int) -> void:
	var sv := ConfigFile.new()
	sv.load(SAVE)
	sv.set_value("wallet", "coins", maxi(0, sv.get_value("wallet", "coins", 0) + n))
	sv.save(SAVE)

func _owned(tab: String) -> Array:
	var sv := ConfigFile.new()
	sv.load(SAVE)
	return sv.get_value("garage", "owned_" + tab, ["roadster"] if tab == "cars" else ["aviator"])

func _garage_data() -> Dictionary:
	var sv := ConfigFile.new()
	sv.load(SAVE)
	var d := {"wallet": _wallet(), "dev": sv.get_value("play", "dev", true), "cars": {}, "pilots": {}}
	for tab in ["cars", "pilots"]:
		var src: Dictionary = Models.CARS if tab == "cars" else Models.PILOTS
		var own := _owned(tab)
		for k in src:
			var it: Dictionary = src[k].duplicate()
			it.owned = own.has(k) or it.price == 0
			it.selected = k == (sel_car if tab == "cars" else sel_pilot)
			d[tab][k] = it
	return d

func _garage_browse(tab: String, key: String) -> void:
	garage_tab = tab
	if tab == "cars":
		_rebuild_vehicles(key, sel_pilot)
	else:
		_rebuild_vehicles(sel_car, key)

func _garage_action(tab: String, key: String) -> void:
	var src: Dictionary = Models.CARS if tab == "cars" else Models.PILOTS
	var sv := ConfigFile.new()
	sv.load(SAVE)
	var own := _owned(tab)
	if not own.has(key) and src[key].price > 0:
		if _wallet() < src[key].price:
			return
		_wallet_add(-src[key].price)
		sv.load(SAVE)
		own.append(key)
		sv.set_value("garage", "owned_" + tab, own)
	if tab == "cars":
		sel_car = key
		sv.set_value("garage", "car", key)
	else:
		sel_pilot = key
		sv.set_value("garage", "pilot", key)
	sv.save(SAVE)
	hud.refresh_garage(_garage_data())
	Input.vibrate_handheld(30)

## swaps in a car and a pilot (the car's cockpit shows that pilot)
func _rebuild_vehicles(car_key: String, pilot_key: String) -> void:
	for n in [car, pilot]:
		if n:
			n.queue_free()
	car = Models.car(car_key, pilot_key)
	add_child(car)
	pilot = Models.pilot(pilot_key)
	pilot.visible = false
	add_child(pilot)
	for n in [car, pilot]:
		_set_layers(n, 1 | 2)
	if quality and quality.main:
		quality.apply()

func _set_layers(n: Node, mask: int) -> void:
	if n is VisualInstance3D:
		n.layers = mask
	for c in n.get_children():
		_set_layers(c, mask)

# ---------------------------------------------------------------- the frame

func _process(dt: float) -> void:
	if sim_mode:
		return
	var t: float
	if shot_dir != "":
		fixed_t += 1.0 / 30.0
		t = fixed_t
		dt = 1.0 / 30.0
	elif state == "play":
		t = music.song_time()
	else:
		t = game.t
	if state == "play":
		# (screenshot runs race ahead between shots: the rules step in thirtieths, but only a few frames get drawn)
		var sub := 1
		if shot_dir != "" and (shot_at.is_empty() or shot_at[0] - t > 1.5) and not (crash_at > 0.0 and crash_at - t < 1.5):
			sub = 12
		for k in sub:
			if k > 0:
				fixed_t += 1.0 / 30.0
				t = fixed_t
			if auto:
				_autopilot()
			if crash_at > 0.0 and t >= crash_at:
				crash_at = -1.0
				game._crash({"t": t, "col": game.col, "row": game.row, "kind": "oldcar", "state": 0})
			game.step(t, dt)
		_music_follow()
		if shot_dir == "":
			quality.watch(dt)
	_beat(game.t, dt)
	var car_z := -game.t * game.SPEED
	_pose_car(car_z, dt)
	_place_camera(dt)
	world.follow(car_z)
	world.weather_follow(cam.global_position)
	rings.update_rings(beat_pulse)
	traffic.update_traffic(car_z, dt)
	fx.update_fx(dt, Vector3(game.x, game.y, car_z))
	var cs := cam.unproject_position(car.global_position if car.visible else pilot.global_position)
	hud.update_play(game, cs, dt, (game.t - game.course.intro * game.BAR) / maxf(1.0, game.gate - game.course.intro * game.BAR))
	if shot_dir != "":
		_maybe_shot()

func _beat(t: float, dt: float) -> void:
	var b := int(floor(t / game.BEAT))
	if b != last_beat:
		last_beat = b
		beat_pulse = 1.0
	beat_pulse = maxf(0.0, beat_pulse - dt * 4.0)

## which layers of the soundtrack play right now
func _music_follow() -> void:
	music.set_band(game.band, game.od_t > 0.0, game.form == 1)
	music.set_ghosts(game.melody_on and game.respawn <= 0.0)
	# each melody layer holds every other note: it's on while its current note is (or is about to be) played
	for layer in 2:
		var cur = null
		for n in game.notes:
			if n.i % 2 != layer:
				continue
			if n.t <= game.t + 0.03:
				cur = n
			else:
				break
		var on := false
		if cur != null:
			if cur.state == 1:
				on = true
			elif cur.state == 0:
				on = game.col == cur.col and game.row == cur.row and game.respawn <= 0.0
		music.set_lead(layer, on)
		music.set_lead(layer + 2, cur != null and cur.state == 1 and cur.get("duet", false))

# ---------------------------------------------------------------- the car, the pilot and the camera

func _pose_car(car_z: float, dt: float) -> void:
	var p := Vector3(game.x, game.y, car_z)
	var fa: Dictionary = game.form_anim
	var since: float = game.t - fa.t0
	# lean into lane changes, nose up on a hop
	bank = lerpf(bank, clampf(-game.vx * 0.09, -0.45, 0.45), clampf(dt * 10.0, 0.0, 1.0))
	pitch = lerpf(pitch, clampf(game.vy * 0.05, -0.3, 0.3), clampf(dt * 10.0, 0.0, 1.0))
	var bob := sin(game.t * 3.1) * 0.035
	if game.form == 2:
		var fly_in := 0.0
		if fa.kind == "deliver" and since < 0.3:
			# the new car flies in from behind and the pilot drops into it
			fly_in = (1.0 - since / 0.3)
			fly_in = fly_in * fly_in * 14.0
		car.visible = true
		pilot.visible = fa.kind == "deliver" and since < 0.3
		car.position = p + Vector3(0, bob, fly_in)
		car.rotation = Vector3(pitch, 0, bank)
		var body: Node3D = car.get_meta("body")
		if body.has_meta("fans"):
			for fan in body.get_meta("fans"):
				fan.rotation.y += dt * 30.0
		if state == "garage" and garage_tab == "pilots":
			# the pilot shows off their jetpack where the car would be
			car.visible = false
			pilot.visible = true
			pilot.position = p + Vector3(0, 0.2 + bob, 0)
			pilot.rotation = Vector3.ZERO
		var flames: Array = car.get_meta("flames")
		var boost := 1.0 + (0.7 if game.row != Game.HOME else 0.0)
		for f in flames:
			f.scale = Vector3(1, 1, 1) * (0.8 + 0.25 * sin(game.t * 40.0 + f.get_instance_id()) + boost * 0.3)
		if fa.kind == "deliver" and since < 0.3:
			pilot.position = p + Vector3(0, 0.6 * (1.0 - since / 0.3), 0)
	else:
		car.visible = false
		pilot.visible = true
		var pp := p + Vector3(0, bob * 1.5, 0)
		if fa.kind == "eject" and since < 0.7:
			# thrown up out of the wreck, then the jetpack catches you
			var k := since / 0.7
			# (from where the car was across the street, carried along at the car's speed)
			pp = Vector3(eject_from.x, eject_from.y, p.z).lerp(p, k * k) + Vector3(0, sin(k * PI) * 2.2, 0)
			pilot.rotation = Vector3(-k * TAU, 0, 0)
		else:
			pilot.rotation = Vector3(pitch * 1.5, 0, bank * 1.3)
		pilot.position = pp + Vector3(0, 0.15, 0)
		var pf: Array = pilot.get_meta("flames")
		for f in pf:
			f.scale = Vector3.ONE * (0.85 + 0.3 * sin(game.t * 45.0 + f.get_instance_id()))
		# the scarf ripples in the wind, more toward its end
		var sc: Array = pilot.get_meta("scarf")
		for k in sc.size():
			sc[k].rotation = Vector3(sin(game.t * 11.0 - k * 0.9) * 0.22 + 0.05, sin(game.t * 7.0 - k * 0.7) * 0.18, sin(game.t * 9.0 - k) * 0.12)
	# a moment of blinking while you can't be hit
	var blink := game.invuln > 0.0 and game.respawn <= 0.0 and int(game.t * 12.0) % 2 == 0
	car.visible = car.visible and not blink
	pilot.visible = pilot.visible and not blink

func _place_camera(dt: float) -> void:
	var car_z := -game.t * game.SPEED
	var jet := 1.0 if game.form < 2 else 0.0
	var target := Vector3(game.x * 0.7, game.y * 0.45 + 2.0, car_z + 7.2 - jet)
	var look := Vector3(game.x * 0.6, game.y * 0.4 - 0.95, car_z - 14.0)
	if state == "title":
		# on the title card the camera sits a little higher and wider, looking down the street
		target += Vector3(0, 1.0, 2.0)
		look += Vector3(0, 1.6, 0)
	elif state == "garage":
		# the showroom: a slow turn around the car (or the pilot), a little above it
		var a := Time.get_ticks_msec() / 1000.0 * 0.35
		var c := Vector3(game.x, game.y, car_z)
		# (a phone screen is narrow: the camera stands back far enough for the whole car to fit across it)
		var r := 4.0 if garage_tab == "pilots" else 7.0
		target = c + Vector3(sin(a) * r, 1.6 if garage_tab == "cars" else 0.6, cos(a) * r)
		look = c + Vector3(0, -0.9 if garage_tab == "cars" else -0.1, 0)
		cam_pos = cam_pos.lerp(target, clampf(dt * 3.0, 0.0, 1.0))
		cam.position = cam_pos
		cam.look_at(look, Vector3.UP)
		cam.fov = 50.0
		return
	var k := clampf(1.0 - exp(-dt * 7.0), 0.0, 1.0)
	# along the street the camera keeps exact pace with the car; only the sideways and up-down moves are eased
	cam_pos = Vector3(lerpf(cam_pos.x, target.x, k), lerpf(cam_pos.y, target.y, k), target.z)
	cam_look = Vector3(lerpf(cam_look.x, look.x, k), lerpf(cam_look.y, look.y, k), look.z)
	cam.position = cam_pos
	cam.look_at(cam_look, Vector3.UP)
	# Overdrive opens the view out and warms the picture; the light streaks rush past
	od_k = lerpf(od_k, 1.0 if game.od_t > 0.0 else 0.0, clampf(dt * 3.0, 0.0, 1.0))
	cam.fov = 62.0 + 9.0 * od_k
	if world and world.env:
		world.env.glow_intensity = 0.55 + 0.35 * od_k
		world.env.adjustment_saturation = 1.12 + 0.2 * od_k
		world.env.adjustment_brightness = 1.0 + 0.06 * od_k
	if streaks:
		streaks.emitting = od_k > 0.5
		streaks.global_position = cam.global_position + Vector3(0, -0.5, -22)

# ---------------------------------------------------------------- what happens in a run

func _on_judged(grade: String, n: Dictionary) -> void:
	var pos := Vector3(game.LX[n.col], game.LY[n.row], -n.t * game.SPEED)
	fx.note_hit(pos, Game.ROW_COLORS[n.row] * 2.2, grade == "ex")
	if grade != "":
		var col := Hud.GOLD if grade == "ex" else Hud.CYAN if grade == "gd" else Color(0.9, 0.86, 0.95)
		hud.judge(Game.TIMING[grade].say, col)

func _on_missed(_n: Dictionary) -> void:
	pass

func _on_crashed(h: Dictionary, form_left: int) -> void:
	var pos := car.global_position if car.visible or form_left >= 1 else pilot.global_position
	eject_from = pos
	fx.crash(pos, car if form_left >= 1 else null, game.SPEED)
	music.muffle()
	# the band comes back on the next bar, coloured for the jetpack
	var wait := game.BAR - fmod(game.t, game.BAR)
	get_tree().create_timer(maxf(0.3, wait)).timeout.connect(func(): music.set_form_filter(game.form))
	Input.vibrate_handheld(120)

func _on_delivered(form: int) -> void:
	music.set_form_filter(form)
	Input.vibrate_handheld(40)

# ---------------------------------------------------------------- input: swipes and keys

func _unhandled_input(e: InputEvent) -> void:
	if state != "play" or auto:
		return
	if e is InputEventScreenTouch:
		if e.pressed:
			touching = true
			touch_fired = false
			touch_start = e.position
		else:
			touching = false
	elif e is InputEventScreenDrag and touching and not touch_fired:
		var d: Vector2 = e.position - touch_start
		var need := minf(get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y) * 0.045
		if d.length() >= need:
			touch_fired = true
			if absf(d.x) >= absf(d.y):
				_move(int(signf(d.x)), 0)
			else:
				_move(0, -int(signf(d.y)))
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_LEFT, KEY_A:
				_move(-1, 0)
			KEY_RIGHT, KEY_D:
				_move(1, 0)
			KEY_UP, KEY_W:
				_move(0, 1)
			KEY_DOWN, KEY_S:
				_move(0, -1)

func _move(dx: int, dy: int) -> void:
	if game.move(dx, dy):
		Input.vibrate_handheld(12)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == "play" and music:
		music.set_paused(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and state == "play" and music:
		music.set_paused(false)

# ---------------------------------------------------------------- testing

## a perfect pilot: makes each move at the best moment before its note
func _autopilot() -> void:
	var nx = null
	for n in game.notes:
		if n.state == 0 and n.t > game.t - 0.05:
			nx = n
			break
	if nx == null:
		return
	var lead: float = nx.t - game.t
	if lead > Game.MOVE_BEST + 0.01:
		return
	if nx.col != game.col:
		game.move(int(signf(nx.col - game.col)), 0)
	elif nx.row != game.row and nx.row != Game.HOME:
		game.move(0, int(signf(nx.row - game.row)))

func _run_sim() -> void:
	game.reset()
	game.running = true
	var t := -0.05
	var steps := 0
	while not game.done and steps < 60 * 400:
		t += 1.0 / 60.0
		_autopilot()
		game.step(t, 1.0 / 60.0)
		steps += 1
	print("SIM ", JSON.stringify(game.result()))
	get_tree().quit()

func _maybe_shot() -> void:
	if shot_at.is_empty():
		return
	if game.t >= shot_at[0]:
		var at: float = shot_at.pop_front()
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/shot_%05.1f.png" % [shot_dir, at])
		print("SHOT ", at)
		if shot_at.is_empty() and not results_shot:
			get_tree().quit()
