extends Node3D
class_name Rooftop
## The main menu's backdrop: a roof high over the open city of the era you have chosen, in that city's light. Your
## car is parked on the landing pad; the pilot has climbed out and leans on the parapet with a drink, looking down
## the street to the landmark (London 1890 at gaslight dusk with Big Ben and a mug of tea; Rio at golden hour with
## Sugarloaf and a coconut; Berlin 2075 at neon night with the TV tower and a glowing can), now and then taking a
## sip. Traffic streams along the street below, the city's roofs run out to the horizon all round, and choosing
## another era fades over to that city's roof. The city, its new look (GfxWorld) and its light (gfx_light.gd) are
## the run's own; the roof, the props (Poly Haven, CC0), the car, the pilot and the far roofs are added here.
## The garage shows the car in the street instead (main.gd takes this scene out meanwhile).

## each era's roof: which side of the street (+1 right, -1 left, looking down the street), how far out from the
## middle, how high above the roofs below (or at a fixed height: Berlin's sky-dock stands over the street's edge,
## above the towers' lower floors), and which side has no far roofs (Rio's beach and sea)
const ERAS := {
	"old": {"side": 1.0, "x": 11.0, "lift": 1.5},
	"sunset": {"side": -1.0, "x": 11.0, "lift": 1.5, "sea": 1.0},
	"rain": {"side": 1.0, "x": 0.0, "height": 34.0},
}
const PAD := Vector2(8.0, 10.0)
const PARAPET := 0.8
## traffic that rides the road (the rest flies at the skyway's heights)
const ROAD_KINDS := ["oldcar", "dbus", "taxi", "truck", "bus"]
const RUN_SCRIPT := preload("res://scripts/run.gd")
const PROPS := "res://assets/polyhaven/models/%s/%s_1k.gltf"
## how far the camera wanders (1: a slow breathing drift, 0: still)
@export var drift := 1.0

var map := ""
var city: City
var _world: Node3D
var _car: Node3D
var _car_y := 0.0
var _pilot: Node3D
var _beacons: Array[MeshInstance3D] = []
var _traffic: Array = []      # [vehicle, speed]
var _t := 0.0
var _cam_at := Vector3.ZERO
var _cam_look := Vector3.ZERO
var _fading := false
## the garage's showroom: the camera goes to the car (or, on the pilots' tab, to the pilot, who turns round)
var garage := false
var _focus := "home"
var _roof: Node3D
var _side := 1.0
var _car_key := ""
var _pilot_key := ""
var _cam_now := Vector3.ZERO
var _look_now := Vector3.ZERO
var _pulse := 0.0            # a fresh car or outfit: the camera starts a little further out and eases in
var _turn := 0.0             # the pilot: 0 leaning on the parapet .. 1 turned round to the camera
var _lean_yaw := 0.0
var _gw: GfxWorld             # the city's new look, to dress the side streets as the levels' street is dressed
var _city_light: Node         # the city's light (gfx_light.gd), to light their lamps the same way

@onready var cam: Camera3D = $Camera3D
@onready var fade: ColorRect = $Fade/Black


func _notification(what: int) -> void:
	# back from the garage: this camera shows again
	if what == NOTIFICATION_ENTER_TREE and is_node_ready():
		cam.make_current.call_deferred()


func set_era(m: String) -> void:
	## show this era's roof; from another era, fade over
	if m == map and city:
		return
	if city == null:
		map = m
		_build()
		return
	if _fading:
		return
	_fading = true
	var tw := create_tween()
	tw.tween_property(fade, "color:a", 1.0, 0.25)
	tw.tween_callback(func() -> void:
		map = m
		_build())
	tw.tween_interval(0.15)
	tw.tween_property(fade, "color:a", 0.0, 0.45)
	tw.tween_callback(func() -> void: _fading = false)


func _build() -> void:
	if _world:
		_world.free()
	_traffic.clear()
	_beacons.clear()
	_world = Node3D.new()
	_world.name = "World"
	add_child(_world)
	var e: Dictionary = ERAS.get(map, ERAS.old)
	var i := int(Save.OPEN.get(map, [0])[0])
	var key := "%s_%d" % [map, i]
	# the city, seen far from up here, and its roofs out to the horizon on every side
	city = (load("res://scenes/cities/%s.tscn" % key) as PackedScene).instantiate() as City
	city.view_ahead = 300.0
	city.behind = 30.0
	_world.add_child(city)
	_gw = null
	if GfxWorld.dresses(map, i):
		_gw = GfxWorld.new()
		city.add_child(_gw)
		_gw.setup(city, null, map, i, bool(Save.data.settings.get("fx_low", false)))
	_city_light = preload("res://scripts/gfx_light.gd").new().setup(_world, city, key)
	_world.add_child(_city_light)
	_swap_traffic(map == "rain")
	city.follow(0.0)
	_world.add_child(_side_streets(float(e.get("sea", 0.0))))
	# the roof: the pad, its parapet and props, the car parked on it, the pilot at the parapet
	var side: float = e.side
	var y: float = float(e.height) if e.has("height") else _roof_height(side) + float(e.lift)
	var pad := Vector3(side * float(e.x), y, 2.0)
	var roof := _pad(map, pad, side)
	_world.add_child(roof)
	_roof = roof
	_side = side
	_car_key = ""
	_pilot_key = ""
	_set_car(Save.data.car)
	_set_pilot(Save.data.pilot)
	# the camera at eye height, a few steps behind the car and to the side, looking past the car and the pilot
	# down the street to the landmark, tipped 12 degrees down so the car sits clear of the menu below
	# (close enough that on a phone the car, the pilot and the landmark line up down the middle of the screen)
	_cam_at = pad + Vector3(side * 1.2, 1.9, 6.8)
	var ahead := Vector3(-side * 2.2, 0.0, -46.8).normalized()
	_cam_look = _cam_at + ahead * 40.0 + Vector3(0.0, -tan(deg_to_rad(12.0)) * 40.0, 0.0)
	_cam_now = _cam_at
	_look_now = _cam_look
	# a soft key light on the car from the camera's side, so it reads against the sky (as the garage's spotlight)
	var key_light := SpotLight3D.new()
	key_light.light_color = {"old": Color(1.0, 0.82, 0.6), "sunset": Color(1.0, 0.85, 0.65), "rain": Color(0.75, 0.7, 1.0)}.get(map, Color.WHITE)
	key_light.light_energy = 9.0
	key_light.spot_range = 14.0
	key_light.spot_angle = 30.0
	roof.add_child(key_light)
	key_light.position = Vector3(side * 2.4, 3.2, 5.0)
	key_light.look_at(roof.global_position + _car.position + Vector3(0, 0.3, 0))
	cam.position = _cam_at
	cam.look_at(_cam_look)
	cam.make_current()
	if map == "rain":
		_dim_near.call_deferred()
	# the traffic below
	var kinds := []
	for k in city.traffic.keys():
		if k != "barrier":
			kinds.append(k)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	for n in 14:
		if kinds.is_empty():
			break
		var kind: String = kinds[n % kinds.size()]
		var v := city.vehicle(kind, n)
		if v == null:
			continue
		var row := 0 if kind in ROAD_KINDS else rng.randi_range(1, 2)
		v.position = Vector3(Rules.LX[rng.randi_range(0, 2)] * 1.4, (Rules.LY[row] - Rules.ROAD_Y) * 1.4, -rng.randf_range(-60.0, 420.0))
		_world.add_child(v)
		_traffic.append([v, rng.randf_range(14.0, 24.0) * (1.0 if row == 0 else 1.3)])


func _process(delta: float) -> void:
	_t += delta
	_camera(delta)
	# the car idles: a gentle hover, the engines just alive
	if _car:
		_car.position.y = _car_y + sin(_t * 1.6) * 0.03
		if _car.has_method("motion"):
			_car.motion(Vector2.ZERO, 0.0)
	if _pilot:
		_turn = move_toward(_turn, 1.0 if _focus == "pilot" else 0.0, delta * 1.6)
		_pose_pilot()
	for b in _beacons:
		b.visible = fmod(_t, 1.4) < 0.7
	# the traffic streams down the street and comes round again
	for p in _traffic:
		var v: Node3D = p[0]
		v.position.z -= float(p[1]) * delta
		if v.position.z < -440.0:
			v.position.z = 80.0


# ------------------------------------------------------------------ the camera and the garage

func set_garage(on: bool) -> void:
	## the garage opens on the rooftop: the camera goes to the car; leaving, back to the view and to the car and
	## pilot you fly
	garage = on
	_focus = "car" if on else "home"
	if not on and city:
		_set_car(Save.data.car)
		_set_pilot(Save.data.pilot)


func show_ride(car_key: String, pilot_key: String, show_pilot: bool) -> void:
	## the garage shows this car (or, on the pilots' tab, this pilot): it takes its place on the roof and the camera
	## eases in to it; a pilot turns round to the camera
	if city == null:
		return
	if car_key != _car_key:
		_set_car(car_key)
		_pulse = 1.0
	if pilot_key != _pilot_key:
		_set_pilot(pilot_key)
		_pulse = 1.0
	var f := "pilot" if show_pilot else "car"
	if garage and f != _focus:
		_focus = f
		_pulse = maxf(_pulse, 0.6)


func _camera(delta: float) -> void:
	## the view (with a slow breathing drift), or close on the car or the pilot; it glides from one to the next
	var at := _cam_at
	var look := _cam_look
	if _focus == "home" and drift > 0.0:
		at += Vector3(sin(_t * 0.11) * 0.25, sin(_t * 0.17) * 0.08, sin(_t * 0.07) * 0.2) * drift
		look += Vector3(sin(_t * 0.09) * 1.5, 0.0, 0.0) * drift
	elif _focus == "car" and _car:
		var c := _roof.to_global(_car.position)
		var away := Vector3(_cam_at.x - c.x, 0.0, _cam_at.z - c.z).normalized().rotated(Vector3.UP, -_side * 0.25)
		at = c + away * 4.2 * (1.0 + 0.4 * _pulse) + Vector3(0, 1.35, 0)
		look = c + Vector3(0, -0.45, 0)
	elif _focus == "pilot" and _pilot:
		var p := _roof.to_global(_pilot.position)
		var away := Vector3(_cam_at.x - p.x, 0.0, _cam_at.z - p.z).normalized()
		at = p + away * 2.7 * (1.0 + 0.35 * _pulse) + Vector3(0, 1.05, 0)
		look = p + Vector3(0, 0.5, 0)
	_pulse = move_toward(_pulse, 0.0, delta * 0.9)
	var k := 1.0 - exp(-delta * 2.4)
	_cam_now = _cam_now.lerp(at, k)
	_look_now = _look_now.lerp(look, k)
	cam.position = _cam_now
	cam.look_at(_look_now)


func _set_car(key: String) -> void:
	## the car parked side-on to the camera, nose towards the street, turned a little towards us
	if _car:
		_car.queue_free()
	_car_key = key
	_car = _make_car(key)
	_roof.add_child(_car)
	_car.position = Vector3(_side * 0.3, 0.55, 0.6)
	_car.rotation.y = _side * (PI / 2.0 + 0.35)
	_car_y = _car.position.y


func _set_pilot(key: String) -> void:
	## the pilot at the parapet
	if _pilot:
		_pilot.queue_free()
	_pilot_key = key
	_pilot = _make_pilot(key)
	_roof.add_child(_pilot)
	_pilot.position = Vector3(-_side * 0.9, 0.15, -PAD.y / 2.0 + 0.62)
	_lean_yaw = _side * 0.18
	_pilot.rotation.y = _lean_yaw


func _dim_near() -> void:
	## Berlin at night: the neon close to the camera (the dock's LEDs, the neon pole, the nearest signs) at half
	## strength, so it doesn't wash out the view
	for f in 3:
		await get_tree().process_frame
	if not is_instance_valid(_world):
		return
	for g in _world.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		if not gi.is_inside_tree() or gi.get_aabb().size == Vector3.ZERO:
			continue
		var box := gi.global_transform * gi.get_aabb()
		if box.get_center().distance_to(_cam_at) > 32.0 and not _roof.is_ancestor_of(gi):
			continue
		if gi is MeshInstance3D and (gi as MeshInstance3D).mesh:
			var mi := gi as MeshInstance3D
			for i in mi.mesh.get_surface_count():
				var m := mi.get_active_material(i)
				var d := _dimmed(m)
				if d:
					mi.set_surface_override_material(i, d)


func _dimmed(m: Material) -> Material:
	if m is StandardMaterial3D and (m as StandardMaterial3D).emission_enabled:
		var c := (m as StandardMaterial3D).duplicate() as StandardMaterial3D
		c.emission_energy_multiplier *= 0.5
		return c
	if m is ShaderMaterial:
		var sm := m as ShaderMaterial
		for p in ["energy", "glow", "emission_energy"]:
			var v = sm.get_shader_parameter(p)
			if v is float:
				var c := sm.duplicate() as ShaderMaterial
				c.set_shader_parameter(p, float(v) * 0.5)
				return c
	return null


# ------------------------------------------------------------------ the pilot

func _make_pilot(key: String) -> Node3D:
	## the pilot, out of the car, with the era's drink in the right hand; the jetpack is off
	var p := (load("res://scenes/pilots/%s.tscn" % key) as PackedScene).instantiate() as Node3D
	for f in p.find_children("Flame*", "", true, false):
		(f as Node3D).visible = false
	var elbow := p.get_node_or_null("Hip/Torso/ShoulderR/Elbow") as Node3D
	var hand := p.get_node_or_null("Hip/Torso/ShoulderR/Elbow/Hand") as Node3D
	if elbow and hand:
		var drink := _drink(map)
		drink.position = hand.position + Vector3(0.0, -0.02, -0.05)
		elbow.add_child(drink)
	p.set_process(false)
	return p


func _pose_pilot() -> void:
	## leaning on the parapet, forearms on the ledge, weight on one leg, the head turning now and then over the
	## city; every eight seconds the right hand lifts the drink for a sip. In the garage's pilot view the pilot
	## stands up and turns round to the camera, drink in hand
	var breathe := sin(_t * 1.3) * 0.02
	var cycle := fmod(_t, 8.0)
	var sip := smoothstep(5.2, 5.9, cycle) * (1.0 - smoothstep(7.0, 7.7, cycle)) * (1.0 - _turn)
	var u := smoothstep(0.0, 1.0, _turn)
	if _roof and u > 0.0:
		var p := _roof.to_global(_pilot.position)
		var to_cam := cam.global_position - p
		var face := atan2(-to_cam.x, -to_cam.z)
		_pilot.rotation.y = lerp_angle(_lean_yaw, face, u)
		_pilot.position.z = -PAD.y / 2.0 + 0.62 + 0.45 * u
	else:
		_pilot.rotation.y = _lean_yaw
		_pilot.position.z = -PAD.y / 2.0 + 0.62
	_j("Hip", Vector3(-0.42 + breathe, 0.0, 0.04))
	_j("Hip/Torso", Vector3(-0.22 + sip * 0.18, 0.0, 0.0))
	_j("Hip/Torso/Head", Vector3(0.25 - sip * 0.45, sin(_t * 0.23) * 0.35 * (1.0 - sip), 0.0))
	# the left forearm lies along the ledge, the right holds the drink on it, then up to the mouth
	_j("Hip/Torso/ShoulderL", Vector3(1.25, 0.0, 0.25))
	_j("Hip/Torso/ShoulderL/Elbow", Vector3(-1.1, 0.0, 0.0))
	_j("Hip/Torso/ShoulderR", Vector3(1.25 + sip * 0.55, 0.0, -0.25 + sip * 0.15))
	_j("Hip/Torso/ShoulderR/Elbow", Vector3(-1.1 - sip * 1.0, 0.0, 0.0))
	_j("Hip/LegL", Vector3(0.38, 0.0, 0.06))
	_j("Hip/LegL/Knee", Vector3(0.12, 0.0, 0.0))
	_j("Hip/LegR", Vector3(0.52, 0.0, -0.1))
	_j("Hip/LegR/Knee", Vector3(0.35, 0.0, 0.0))


func _j(path: String, rot: Vector3) -> void:
	## a joint between its leaning pose and standing (arms easy, the drink held up a little, looking at the camera)
	var stand := {"Hip": Vector3(0.0, 0.0, 0.0), "Hip/Torso": Vector3(0.05, 0.0, 0.0), "Hip/Torso/Head": Vector3(0.0, 0.0, 0.0),
		"Hip/Torso/ShoulderL": Vector3(0.1, 0.0, -0.12), "Hip/Torso/ShoulderL/Elbow": Vector3(-0.25, 0.0, 0.0),
		"Hip/Torso/ShoulderR": Vector3(0.55, 0.0, -0.2), "Hip/Torso/ShoulderR/Elbow": Vector3(-1.1, 0.0, 0.0),
		"Hip/LegL": Vector3.ZERO, "Hip/LegL/Knee": Vector3.ZERO, "Hip/LegR": Vector3(0.05, 0.0, -0.04), "Hip/LegR/Knee": Vector3(0.08, 0.0, 0.0)}
	var n := _pilot.get_node_or_null(path) as Node3D
	if n:
		n.rotation = rot.lerp(stand.get(path, rot), smoothstep(0.0, 1.0, _turn))


func _drink(era: String) -> Node3D:
	## a mug of tea (London), a green coconut with a straw (Rio), a glowing can (Berlin)
	var k := MeshKit.new()
	match era:
		"old":
			GfxWorld.paint(k, "enamel", Color("f2efe6"), 0.35)
			GfxWorld.paint(k, "rim", Color("1d3a7a"), 0.35)
			GfxWorld.paint(k, "tea", Color("8a5a32"), 0.2)
			k.cylinder("enamel", Vector3(0, 0, 0), 0.045, 0.09, 12)
			k.cylinder("rim", Vector3(0, 0.046, 0), 0.047, 0.008, 12)
			k.cylinder("tea", Vector3(0, 0.04, 0), 0.04, 0.004, 12)
			k.box("enamel", Vector3(0.055, 0.0, 0), Vector3(0.02, 0.06, 0.012))
		"sunset":
			GfxWorld.paint(k, "husk", Color("6aa83a"), 0.6)
			GfxWorld.paint(k, "straw", Color("ff4a7a"), 0.4)
			k.sphere("husk", Vector3.ZERO, Vector3(0.075, 0.085, 0.075), 10, 8)
			k.box("straw", Vector3(0.02, 0.12, 0), Vector3(0.012, 0.12, 0.012))
		_:
			GfxWorld.paint(k, "can", Color("2ef2ff"), 0.25, 0.8, 1.25)
			GfxWorld.paint(k, "top", Color("c8ccd4"), 0.3, 0.9)
			k.cylinder("can", Vector3.ZERO, 0.035, 0.12, 12)
			k.cylinder("top", Vector3(0, 0.061, 0), 0.032, 0.006, 12)
	var mi := MeshInstance3D.new()
	mi.name = "Drink"
	mi.mesh = k.bake()
	return mi


# ------------------------------------------------------------------ the car and the traffic

func _make_car(key: String) -> Node3D:
	## a car in its own livery with the era's light on it (as the run dresses it)
	var path := "res://scenes/gfx_ride/cars/%s.tscn" % key
	if not ResourceLoader.exists(path):
		path = "res://scenes/cars/%s.tscn" % key
	var car := (load(path) as PackedScene).instantiate() as Node3D
	var th := Catalog.theme(map)
	var pods: Array = th.pods
	var hexc := func(v) -> Color: return RUN_SCRIPT.Catalog_hex(v)
	if car.has_method("paint"):
		car.paint(hexc.call(th.paint), hexc.call(th.strip), Color(pods[0], pods[1], pods[2]))
	if car.has_method("look"):
		var moods := {"old": [0.0, Color(0.05, 0.04, 0.03), 1.0], "sunset": [0.3, Color(0.07, 0.03, 0.07), 1.0], "rain": [1.0, hexc.call(th.strip), 2.2]}
		var mood: Array = moods.get(map, moods.old)
		car.look(mood[0], mood[1], mood[2])
	return car


func _swap_traffic(future: bool) -> void:
	## the city's traffic in the run's new look (as scripts/gfx_ride.gd does)
	var t: Dictionary = city.traffic.duplicate()
	for kind in t.keys():
		var k: String = kind + ("_2075" if future and kind in ["taxi", "truck", "bus"] else "")
		var path := "res://scenes/gfx_ride/traffic/%s.tscn" % k
		if ResourceLoader.exists(path):
			t[kind] = load(path)
	city.traffic = t


func _roof_height(side: float) -> float:
	## the highest roof on this side of the street near the pad
	var top := 12.0
	for s in city.street.get_children():
		for mi in (s as Node).find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if not m.is_inside_tree() or m.mesh == null:
				continue
			var box := m.global_transform * m.get_aabb()
			var cx := box.get_center().x
			if signf(cx) == side and absf(cx) > 7.0 and absf(cx) < 24.0 and box.end.z > -30.0 and box.position.z < 30.0 and box.size.y < 120.0:
				top = maxf(top, box.end.y)
	return top


# ------------------------------------------------------------------ the side streets

const SIDE_STREETS := [34.0, 68.0]


func _side_streets(sea_side: float) -> Node3D:
	## the city behind the two rows that line the street: more of its own streets, parallel to it, built from the
	## same street sections and dressed the same way as in the levels (GfxWorld, gfx_light), so from up here the
	## city is whole all round, also on a wide screen. Rio's sea side stays open
	var n := Node3D.new()
	n.name = "SideStreets"
	for off in SIDE_STREETS:
		for s in [-1.0, 1.0]:
			if sea_side != 0.0 and s == sea_side:
				continue
			# (only what the camera can see: from just behind it to the far end of the view)
			for j in range(-1, 6):
				var k := posmod(j * 7 + int(off) + (1 if s > 0 else 0), city.sections.size())
				var sec := city.sections[k].instantiate() as Node3D
				sec.position = Vector3(s * float(off), 0.0, -j * city.section_length)
				n.add_child(sec)
				if _gw:
					_gw._dress(sec)
	if _city_light and _city_light.has_method("_treat"):
		_city_light._treat(n)
	# the ground under it all, out to the haze, so nothing floats over a gap (not over Rio's sea)
	var g := MeshInstance3D.new()
	g.name = "Ground"
	var pm := PlaneMesh.new()
	var x0 := -1500.0
	var x1 := 1500.0 if sea_side == 0.0 else 9.0
	if sea_side < 0.0:
		x0 = -9.0
	pm.size = Vector2(x1 - x0, 2400.0)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = {"old": Color("2a2420"), "sunset": Color("4a3a30"), "rain": Color("0c0d12")}.get(map, Color("2a2420"))
	gm.roughness = 1.0
	pm.material = gm
	g.mesh = pm
	g.position = Vector3((x0 + x1) / 2.0, -0.35, -700.0)
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(g)
	return n


# ------------------------------------------------------------------ the roof

func _lvl(k: MeshKit, name: String, tres: String, tile := 1.0) -> String:
	## one of the levels' own materials (Poly Haven textures) on a roof surface
	k.use(name, load("res://materials/%s.tres" % tres), tile)
	return name


func _scene(parent: Node3D, path: String, at: Vector3, yaw := 0.0, scl := 1.0) -> Node3D:
	## one of the levels' own props (gas lamps, neon poles)
	var p := (load(path) as PackedScene).instantiate() as Node3D
	p.position = at
	p.rotation.y = yaw
	p.scale = Vector3.ONE * scl
	parent.add_child(p)
	return p


func _pad(era: String, at: Vector3, side: float) -> Node3D:
	var n := Node3D.new()
	n.name = "Roof"
	n.position = at
	var k := MeshKit.new()
	var w := PAD.x
	var d := PAD.y
	var front := -d / 2.0
	var street := -side * w / 2.0
	match era:
		"old":
			# London: a leaded flat roof with a stone balustrade on the street side and the front, a brass landing
			# ring with a compass star, a gas lantern; a bench and planters
			_lvl(k, "lead", "slate", 2.0)
			_lvl(k, "stone", "portland_stone", 1.5)
			_lvl(k, "brass", "brass")
			k.box("lead", Vector3(0, -0.6, 0), Vector3(w, 1.2, d))
			_balustrade(k, Vector3(-w / 2.0, 0, front), Vector3(w / 2.0, 0, front), "stone")
			_balustrade(k, Vector3(street, 0, front), Vector3(street, 0, d / 2.0), "stone")
			_ring(k, "brass", 1.9, 2.1, 0.03, Vector3(side * 0.3, 0, 0.6))
			for j in 8:
				var a := TAU * j / 8.0
				var dir := Vector3(cos(a), 0, sin(a))
				var c := Vector3(side * 0.3, 0.04, 0.6)
				var sd := dir.cross(Vector3.UP) * 0.12
				k.tri("brass", c + sd, c + dir * (1.8 if j % 2 == 0 else 1.2), c - sd)
			# a gas lamp of the street's own, on the corner of the parapet
			_scene(n, "res://scenes/props/gas_lamp.tscn", Vector3(street + side * 0.35, 0, front + 0.35), 0.0, 1.0)
			_prop(n, "painted_wooden_bench", Vector3(-side * 1.6, 0, d / 2.0 - 2.2), PI)
			_prop(n, "planter_box_01", Vector3(-side * 0.6, 0, d / 2.0 - 0.6), 0.0)
			_prop(n, "potted_plant_02", Vector3(street + side * 0.5, 0, 1.8), 0.0)
		"sunset":
			# Rio: a tiled terrace with white parapets, a painted landing circle, a café table and chairs under a
			# striped parasol, potted plants, string lights on two posts
			_lvl(k, "tile", "facade_tiles", 1.2)
			_lvl(k, "stucco", "plaster_white", 1.5)
			GfxWorld.paint(k, "white", Color("fbf6ec"), 0.6)
			GfxWorld.paint(k, "yellow", Color("ffd23f"), 0.6)
			GfxWorld.paint(k, "bulb", Color("ffe0a0"), 0.3, 0.0, 7.0)
			GfxWorld.paint(k, "post", Color("2a2a2a"), 0.6, 0.6)
			GfxWorld.paint(k, "canvas_a", Color("e8443a"), 0.8)
			GfxWorld.paint(k, "canvas_b", Color("f4f0e6"), 0.8)
			k.box("tile", Vector3(0, -0.6, 0), Vector3(w, 1.2, d))
			k.box("stucco", Vector3(0, PARAPET / 2.0, front + 0.12), Vector3(w, PARAPET, 0.24))
			k.box("stucco", Vector3(street + side * 0.12, PARAPET / 2.0, 0), Vector3(0.24, PARAPET, d))
			k.box("white", Vector3(0, PARAPET + 0.03, front + 0.12), Vector3(w + 0.06, 0.06, 0.32))
			k.box("white", Vector3(street + side * 0.12, PARAPET + 0.03, 0), Vector3(0.32, 0.06, d + 0.06))
			_ring(k, "white", 1.9, 2.15, 0.02, Vector3(side * 0.3, 0, 0.6))
			k.box("yellow", Vector3(side * 0.3, 0.03, 0.6), Vector3(0.35, 0.02, 1.8))
			k.box("yellow", Vector3(side * 0.3, 0.03, 0.6), Vector3(1.8, 0.02, 0.35))
			var par := Vector3(side * (w / 2.0 - 1.6), 0, -1.4)
			k.cylinder("post", par + Vector3(0, 1.2, 0), 0.035, 2.4, 6)
			for j in 10:
				var a0 := TAU * j / 10.0
				var a1 := TAU * (j + 1) / 10.0
				k.tri("canvas_a" if j % 2 == 0 else "canvas_b", par + Vector3(0, 2.6, 0), par + Vector3(cos(a1) * 1.5, 2.1, sin(a1) * 1.5), par + Vector3(cos(a0) * 1.5, 2.1, sin(a0) * 1.5))
			_prop(n, "outdoor_table_chair_set_01", par, 0.4)
			# palms in big planters, Rio's own (the promenade's palms, gfx_world_rio.gd)
			if _gw and _gw.builder and _gw.builder.has_method("_palm"):
				var rng := RandomNumberGenerator.new()
				rng.seed = 1950
				var pk := MeshKit.new()
				for pp in [Vector3(street + side * 0.8, 0.45, -3.4)]:
					_gw.builder._palm(pk, pp, rng.randf_range(4.2, 5.2), rng)
					k.cylinder("stucco", pp + Vector3(0, -0.2, 0), 0.55, 0.5, 14)
				GfxWorld.add_mesh(n, pk.bake(), "Palms")
			_prop(n, "potted_plant_02", Vector3(street + side * 0.45, 0, 2.2), 0.0)
			_prop(n, "potted_plant_02", Vector3(side * (w / 2.0 - 0.5), 0, d / 2.0 - 0.6), 1.0)
			var pa := Vector3(street + side * 0.3, 0, front + 0.3)
			var pb := Vector3(side * (w / 2.0 - 0.3), 0, front + 0.3)
			for p in [pa, pb]:
				k.cylinder("post", p + Vector3(0, 1.5, 0), 0.035, 3.0, 6)
			for j in 14:
				var u := (j + 0.5) / 14.0
				k.sphere("bulb", pa.lerp(pb, u) + Vector3(0, 2.9 - 0.45 * sin(u * PI), 0), Vector3.ONE * 0.06, 6, 4)
			_light(n, Vector3(0, 2.6, front + 0.6), Color(1.0, 0.8, 0.55), 1.8, 9.0)
		_:
			# Berlin 2075: a steel sky-dock on a dark grid with LED edges, a glowing ring and H, a glass rail with a
			# lit top, an armchair and succulents, an aerial with red beacons
			_lvl(k, "deck", "metal_plate", 1.0)
			GfxWorld.paint(k, "grid", Color("2c313c"), 0.4, 0.8)
			GfxWorld.paint(k, "led_a", Color("2ef2ff"), 0.3, 0.0, 3.0)
			GfxWorld.paint(k, "led_b", Color("ff3fb4"), 0.3, 0.0, 3.0)
			_lvl(k, "steel", "steel")
			GfxWorld.paint(k, "glass", Color("6a9ab8"), 0.1, 0.3)
			k.box("deck", Vector3(0, -0.6, 0), Vector3(w, 1.2, d))
			for gx in range(-3, 4):
				k.box("grid", Vector3(gx, 0.005, 0), Vector3(0.03, 0.01, d - 0.4))
			for gz in range(-4, 5):
				k.box("grid", Vector3(0, 0.006, gz), Vector3(w - 0.4, 0.01, 0.03))
			_ring(k, "led_b", 1.9, 2.05, 0.03, Vector3(side * 0.3, 0, 0.6))
			for hx in [-0.55, 0.55]:
				k.box("led_b", Vector3(side * 0.3 + hx, 0.03, 0.6), Vector3(0.18, 0.02, 1.5))
			k.box("led_b", Vector3(side * 0.3, 0.03, 0.6), Vector3(1.1, 0.02, 0.18))
			for e2 in [[Vector3(0, PARAPET / 2.0, front + 0.05), Vector3(w, PARAPET, 0.04)], [Vector3(street + side * 0.05, PARAPET / 2.0, 0), Vector3(0.04, PARAPET, d)]]:
				k.box("glass", e2[0], e2[1])
				k.box("led_a", e2[0] + Vector3(0, PARAPET / 2.0 + 0.02, 0), Vector3(maxf(e2[1].x, 0.08), 0.05, maxf(e2[1].z, 0.08)))
			for e2 in [[Vector3(0, 0.04, d / 2.0 - 0.05), Vector3(w, 0.05, 0.06)], [Vector3(-street, 0.04, 0), Vector3(0.06, 0.05, d)]]:
				k.box("led_a", e2[0], e2[1])
			var mast := Vector3(side * (w / 2.0 - 0.5), 0, d / 2.0 - 0.6)
			k.box("steel", mast + Vector3(0, 3.0, 0), Vector3(0.12, 6.0, 0.12))
			for yy in [2.0, 3.8, 5.6]:
				k.box("steel", mast + Vector3(0, yy, 0), Vector3(0.8, 0.04, 0.04))
			var bm := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.1
			sm.height = 0.2
			var bmat := StandardMaterial3D.new()
			bmat.albedo_color = Color("ff2a2a")
			bmat.emission_enabled = true
			bmat.emission = Color("ff2a2a")
			bmat.emission_energy_multiplier = 4.0
			sm.material = bmat
			bm.mesh = sm
			bm.position = mast + Vector3(0, 6.1, 0)
			n.add_child(bm)
			_beacons.append(bm)
			_prop(n, "modern_arm_chair_01", Vector3(side * (w / 2.0 - 1.0), 0, -1.6), side * -2.2)
			_prop(n, "potted_plant_04", Vector3(street + side * 0.45, 0, 2.0), 0.0)
			_prop(n, "potted_plant_04", Vector3(side * (w / 2.0 - 0.6), 0, -3.2), 0.8)
			_light(n, Vector3(0, 2.2, 0), Color(0.7, 0.55, 1.0), 1.8, 8.0)
			_scene(n, "res://scenes/props/neon_pole.tscn", Vector3(street + side * 0.4, 0, front + 0.4))
	# what holds the roof up: the building under it, down to the roofs; in Berlin a pylon down to the street
	if era == "rain":
		GfxWorld.paint(k, "wall", Color("2a2e38"), 0.4, 0.8)
		k.box("wall", Vector3(0, -1.6, 0), Vector3(w * 0.7, 0.8, d * 0.7))
		k.box("wall", Vector3(0, -at.y / 2.0 - 1.0, 0), Vector3(1.1, at.y, 1.1))
	else:
		_lvl(k, "wall", "brick_red" if era == "old" else "plaster_sand", 2.0)
		k.box("wall", Vector3(0, -1.2 - 9.0, 0), Vector3(w - 0.2, 18.0, d - 0.2))
	GfxWorld.add_mesh(n, k.bake(), "Pad")
	return n


func _prop(parent: Node3D, asset: String, at: Vector3, yaw: float) -> void:
	## a Poly Haven model (CC0) on the roof
	var path := PROPS % [asset, asset]
	if not ResourceLoader.exists(path):
		return
	var p := (load(path) as PackedScene).instantiate() as Node3D
	p.position = at
	p.rotation.y = yaw
	parent.add_child(p)


func _balustrade(k: MeshKit, a: Vector3, b: Vector3, m: String) -> void:
	## a stone balustrade from a to b: a plinth, a row of balusters, the coping the pilot leans on
	var len := a.distance_to(b)
	var mid := (a + b) * 0.5
	var along := (b - a).normalized()
	k.box(m, mid + Vector3(0, PARAPET - 0.07, 0), Vector3(absf(along.x) * len + 0.3, 0.14, absf(along.z) * len + 0.3))
	k.box(m, mid + Vector3(0, 0.08, 0), Vector3(absf(along.x) * len + 0.3, 0.16, absf(along.z) * len + 0.3))
	var n := int(len / 0.3)
	for j in n + 1:
		k.cylinder(m, a + along * (len * j / n) + Vector3(0, (PARAPET - 0.14) / 2.0 + 0.08, 0), 0.06, PARAPET - 0.3, 6)


func _ring(k: MeshKit, m: String, r0: float, r1: float, y: float, c := Vector3.ZERO) -> void:
	k.lathe(m, PackedVector2Array([Vector2(r1, y), Vector2(r0, y)]), c, 40, false)


func _light(parent: Node3D, at: Vector3, c: Color, energy: float, reach: float) -> void:
	var o := OmniLight3D.new()
	o.position = at
	o.light_color = c
	o.light_energy = energy
	o.omni_range = reach
	parent.add_child(o)
