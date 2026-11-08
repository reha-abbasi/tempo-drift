extends Node3D
class_name Rooftop
## The main menu's backdrop: your car parked on a rooftop landing pad high over the open city of the era you have
## chosen, in that city's light: London 1890 at gaslight dusk with Big Ben down the street, Rio de Janeiro at golden
## hour with Sugarloaf over the sea, Berlin 2075 at neon night with the TV tower. Traffic streams along the street
## below, the camera drifts slowly, and choosing another era fades over to that city's rooftop. The city, its
## new look (GfxWorld) and its light (gfx_light.gd) are the run's own; the pad, the car and the traffic are added
## here. The garage shows the car in the street instead (main.gd takes this scene out meanwhile).

## each era's rooftop: which side of the street it stands on (+1 right, -1 left, looking down the street), how far
## out from the middle, how high above the roofs below (or at a fixed height: Berlin's sky-dock stands over the
## middle of the street, above the towers' lower floors), and the camera: how far behind and above the car, and how
## far it tips down (degrees) as it looks down the street to the landmark
const ERAS := {
	"old": {"side": 1.0, "x": 12.5, "lift": 2.5, "back": 12.5, "up": 1.4, "tilt": 4.0},
	"sunset": {"side": -1.0, "x": 12.0, "lift": 2.5, "back": 12.5, "up": 1.4, "tilt": 4.0},
	"rain": {"side": 1.0, "x": 0.0, "height": 34.0, "back": 12.5, "up": 1.4, "tilt": 5.0},
}
## traffic that rides the road (the rest flies at the skyway's heights)
const ROAD_KINDS := ["oldcar", "dbus", "taxi", "truck", "bus"]
const RUN_SCRIPT := preload("res://scripts/run.gd")
## how far the camera wanders (1: a slow breathing drift, 0: still)
@export var drift := 1.0

var map := ""
var city: City
var _world: Node3D
var _car: Node3D
var _beacons: Array[MeshInstance3D] = []
var _traffic: Array = []      # [vehicle, speed]
var _t := 0.0
var _cam_at := Vector3.ZERO
var _cam_look := Vector3.ZERO
var _fading := false

@onready var cam: Camera3D = $Camera3D
@onready var fade: ColorRect = $Fade/Black


func _notification(what: int) -> void:
	# back from the garage: this camera shows again
	if what == NOTIFICATION_ENTER_TREE and is_node_ready():
		cam.make_current.call_deferred()


func set_era(m: String) -> void:
	## show this era's rooftop; from another era, fade over
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
	# the city, seen far from up here
	city = (load("res://scenes/cities/%s.tscn" % key) as PackedScene).instantiate() as City
	city.view_ahead = 420.0
	city.behind = 60.0
	_world.add_child(city)
	if GfxWorld.dresses(map, i):
		var gw := GfxWorld.new()
		city.add_child(gw)
		gw.setup(city, null, map, i, bool(Save.data.settings.get("fx_low", false)))
	_world.add_child(preload("res://scripts/gfx_light.gd").new().setup(_world, city, key))
	_swap_traffic(map == "rain")
	city.follow(0.0)
	# the pad on the tallest roof by the camera, the car on it
	var side: float = e.side
	var y: float = float(e.height) if e.has("height") else _roof_height(side) + float(e.lift)
	var pad := Vector3(side * float(e.x), y, 6.0)
	_world.add_child(_pad(map, pad, side))
	_car = _make_car(pad + Vector3(0, 0.75, 0))
	_world.add_child(_car)
	# the camera straight behind and a little above the car, looking down the street to the landmark, tipped down a
	# little: the car sits just over the era tabs, the city and its landmark in the open middle of the screen
	_cam_at = pad + Vector3(0, 0.75 + float(e.up), float(e.back))
	_cam_look = Vector3(0.0, _cam_at.y - tan(deg_to_rad(float(e.tilt))) * (_cam_at.z + 340.0), -340.0)
	cam.position = _cam_at
	cam.look_at(_cam_look)
	cam.make_current()
	# the traffic below
	var kinds := []
	for k in city.traffic.keys():
		if k != "barrier":
			kinds.append(k)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	for n in 12:
		if kinds.is_empty():
			break
		var kind: String = kinds[n % kinds.size()]
		var v := city.vehicle(kind, n)
		if v == null:
			continue
		var row := 0 if kind in ROAD_KINDS else rng.randi_range(1, 2)
		v.position = Vector3(Rules.LX[rng.randi_range(0, 2)] * 1.4, (Rules.LY[row] - Rules.ROAD_Y) * 1.4, -rng.randf_range(-40.0, 420.0))
		_world.add_child(v)
		_traffic.append([v, rng.randf_range(14.0, 24.0) * (1.0 if row == 0 else 1.3)])


func _process(delta: float) -> void:
	_t += delta
	# a slow drift: the camera breathes sideways and up and down
	if cam and drift > 0.0:
		var off := Vector3(sin(_t * 0.11) * 0.7, sin(_t * 0.17) * 0.25, sin(_t * 0.07) * 0.6) * drift
		cam.position = _cam_at + off
		cam.look_at(_cam_look + Vector3(sin(_t * 0.09) * 3.0, 0.0, 0.0) * drift)
	# the car idles: a gentle hover, the engines just alive
	if _car:
		_car.position.y += sin(_t * 1.6) * 0.0015
		if _car.has_method("motion"):
			_car.motion(Vector2.ZERO, 0.0)
	for b in _beacons:
		b.visible = fmod(_t, 1.4) < 0.7
	# the traffic streams down the street and comes round again
	for p in _traffic:
		var v: Node3D = p[0]
		v.position.z -= float(p[1]) * delta
		if v.position.z < -440.0:
			v.position.z = 60.0


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


func _make_car(at: Vector3) -> Node3D:
	## the car you fly, in its own livery with the era's light on it (as the run dresses it)
	var key: String = Save.data.car
	var path := "res://scenes/gfx_ride/cars/%s.tscn" % key
	if not ResourceLoader.exists(path):
		path = "res://scenes/cars/%s.tscn" % key
	var car := (load(path) as PackedScene).instantiate() as Node3D
	car.position = at
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


# ------------------------------------------------------------------ the pads

func _pad(era: String, at: Vector3, side: float) -> Node3D:
	var n := Node3D.new()
	n.name = "Pad"
	n.position = at
	var k := MeshKit.new()
	var w := 11.0
	var d := 14.0
	match era:
		"old":
			# London: a leaded flat roof behind a stone balustrade, a brass landing ring with a compass star, chimney
			# stacks with their pots, a gas lantern on an iron post
			GfxWorld.paint(k, "lead", Color("5a5f66"), 0.6, 0.4)
			GfxWorld.paint(k, "stone", Color("c8bca4"), 0.85)
			GfxWorld.paint(k, "brick", Color("7a3a2a"), 0.9)
			GfxWorld.paint(k, "pot", Color("b5603a"), 0.8)
			GfxWorld.paint(k, "brass", Color("d8b060"), 0.3, 1.0)
			GfxWorld.paint(k, "iron", Color("16181a"), 0.45, 1.0)
			GfxWorld.paint(k, "lamp", Color("ffd890"), 0.3, 0.0, 6.0)
			k.box("lead", Vector3(0, -0.6, 0), Vector3(w, 1.2, d))
			_balustrade(k, w, d, "stone")
			_ring(k, "brass", 3.0, 3.35, 0.03)
			_ring(k, "brass", 1.6, 1.75, 0.03)
			for j in 8:
				var a := TAU * j / 8.0
				var dir := Vector3(cos(a), 0, sin(a))
				var len := 2.9 if j % 2 == 0 else 1.9
				var sd := dir.cross(Vector3.UP) * 0.18
				k.tri("brass", Vector3(0, 0.04, 0) + sd, dir * len + Vector3(0, 0.04, 0), Vector3(0, 0.04, 0) - sd)
			for cz in [-d / 2 + 1.6, d / 2 - 2.0]:
				var c := Vector3(-side * (w / 2 - 1.4), 0, cz)
				k.box("brick", c + Vector3(0, 1.4, 0), Vector3(1.6, 2.8, 2.6))
				k.box("stone", c + Vector3(0, 2.9, 0), Vector3(1.8, 0.2, 2.8))
				for p in 3:
					k.cylinder("pot", c + Vector3(0, 3.35, -0.8 + p * 0.8), 0.18, 0.7, 10)
			var lp := Vector3(side * (w / 2 - 0.8), 0, d / 2 - 0.8)
			k.cylinder("iron", lp + Vector3(0, 1.4, 0), 0.06, 2.8, 8)
			k.box("iron", lp + Vector3(0, 2.95, 0), Vector3(0.42, 0.06, 0.42))
			k.box("lamp", lp + Vector3(0, 3.2, 0), Vector3(0.32, 0.45, 0.32))
			k.box("iron", lp + Vector3(0, 3.5, 0), Vector3(0.46, 0.08, 0.46))
			_light(n, lp + Vector3(0, 3.2, 0), Color(1.0, 0.75, 0.45), 2.5, 9.0)
		"sunset":
			# Rio: a tiled terrace behind white parapets, a painted landing circle, potted palms, a striped parasol,
			# string lights on two posts
			GfxWorld.paint(k, "tile", Color("c8734a"), 0.75)
			GfxWorld.paint(k, "stucco", Color("f4ede0"), 0.85)
			GfxWorld.paint(k, "white", Color("fbf6ec"), 0.6)
			GfxWorld.paint(k, "yellow", Color("ffd23f"), 0.6)
			GfxWorld.paint(k, "pot", Color("a24e2e"), 0.8)
			GfxWorld.paint(k, "trunk", Color("6a5038"), 0.9)
			GfxWorld.paint(k, "leaf", Color("2f7a3a"), 0.8)
			GfxWorld.paint(k, "bulb", Color("ffe0a0"), 0.3, 0.0, 7.0)
			GfxWorld.paint(k, "post", Color("2a2a2a"), 0.6, 0.6)
			GfxWorld.paint(k, "canvas_a", Color("e8443a"), 0.8)
			GfxWorld.paint(k, "canvas_b", Color("f4f0e6"), 0.8)
			k.box("tile", Vector3(0, -0.6, 0), Vector3(w, 1.2, d))
			for e2 in [[Vector3(-side * (w / 2 - 0.15), 0.5, 0), Vector3(0.3, 1.0, d)], [Vector3(side * (w / 2 - 0.15), 0.5, 0), Vector3(0.3, 1.0, d)]]:
				k.box("stucco", e2[0], e2[1])
			_ring(k, "white", 2.9, 3.3, 0.02)
			k.box("yellow", Vector3(0, 0.03, 0), Vector3(0.5, 0.02, 3.0))
			k.box("yellow", Vector3(0, 0.03, 0), Vector3(3.0, 0.02, 0.5))
			for pp in [Vector3(-side * (w / 2 - 1.2), 0, -d / 2 + 1.3), Vector3(-side * (w / 2 - 1.2), 0, d / 2 - 1.6), Vector3(side * (w / 2 - 1.1), 0, -d / 2 + 1.3)]:
				_palm(k, pp)
			var par := Vector3(-side * (w / 2 - 2.0), 0, 1.0)
			k.cylinder("post", par + Vector3(0, 1.2, 0), 0.04, 2.4, 6)
			for j in 8:
				var a0 := TAU * j / 8.0
				var a1 := TAU * (j + 1) / 8.0
				k.tri("canvas_a" if j % 2 == 0 else "canvas_b", par + Vector3(0, 2.75, 0), par + Vector3(cos(a1) * 1.6, 2.2, sin(a1) * 1.6), par + Vector3(cos(a0) * 1.6, 2.2, sin(a0) * 1.6))
			var pa := Vector3(-side * (w / 2 - 0.4), 0, -d / 2 + 0.4)
			var pb := Vector3(-side * (w / 2 - 0.4), 0, d / 2 - 0.4)
			for p in [pa, pb]:
				k.cylinder("post", p + Vector3(0, 1.5, 0), 0.04, 3.0, 6)
			for j in 15:
				var u := (j + 0.5) / 15.0
				var q := pa.lerp(pb, u) + Vector3(0, 2.9 - 0.5 * sin(u * PI), 0)
				k.sphere("bulb", q, Vector3.ONE * 0.07, 6, 4)
			_light(n, Vector3(-side * (w / 2 - 0.6), 2.6, 0), Color(1.0, 0.8, 0.55), 2.0, 10.0)
		_:
			# Berlin 2075: a steel helipad on a dark grid, LED strips round its edge, a glowing ring with an H, vents,
			# and an aerial mast with red beacons
			GfxWorld.paint(k, "deck", Color("1c1f26"), 0.35, 0.8)
			GfxWorld.paint(k, "grid", Color("2c313c"), 0.4, 0.8)
			GfxWorld.paint(k, "led_a", Color("2ef2ff"), 0.3, 0.0, 6.0)
			GfxWorld.paint(k, "led_b", Color("ff3fb4"), 0.3, 0.0, 6.0)
			GfxWorld.paint(k, "steel", Color("3a404c"), 0.4, 0.9)
			k.box("deck", Vector3(0, -0.6, 0), Vector3(w, 1.2, d))
			for gx in range(-5, 6):
				k.box("grid", Vector3(gx, 0.005, 0), Vector3(0.04, 0.01, d - 0.4))
			for gz in range(-6, 7):
				k.box("grid", Vector3(0, 0.006, gz), Vector3(w - 0.4, 0.01, 0.04))
			for e2 in [[Vector3(0, 0.04, -d / 2 + 0.1), Vector3(w, 0.06, 0.08)], [Vector3(0, 0.04, d / 2 - 0.1), Vector3(w, 0.06, 0.08)],
					[Vector3(-w / 2 + 0.1, 0.04, 0), Vector3(0.08, 0.06, d)], [Vector3(w / 2 - 0.1, 0.04, 0), Vector3(0.08, 0.06, d)]]:
				k.box("led_a", e2[0], e2[1])
			_ring(k, "led_b", 3.0, 3.25, 0.03)
			for hx in [-0.9, 0.9]:
				k.box("led_b", Vector3(hx, 0.03, 0), Vector3(0.3, 0.02, 2.4))
			k.box("led_b", Vector3(0, 0.03, 0), Vector3(1.8, 0.02, 0.3))
			for v in 3:
				k.box("steel", Vector3(-side * (w / 2 - 1.2), 0.55, -4.0 + v * 2.2), Vector3(1.4, 1.1, 1.6))
			var mast := Vector3(-side * (w / 2 - 0.7), 0, d / 2 - 0.9)
			k.box("steel", mast + Vector3(0, 3.5, 0), Vector3(0.14, 7.0, 0.14))
			for y in [2.5, 4.5, 6.5]:
				k.box("steel", mast + Vector3(0, y, 0), Vector3(0.9, 0.05, 0.05))
			var bm := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.12
			sm.height = 0.24
			var bmat := StandardMaterial3D.new()
			bmat.albedo_color = Color("ff2a2a")
			bmat.emission_enabled = true
			bmat.emission = Color("ff2a2a")
			bmat.emission_energy_multiplier = 8.0
			sm.material = bmat
			bm.mesh = sm
			bm.position = mast + Vector3(0, 7.1, 0)
			n.add_child(bm)
			_beacons.append(bm)
			_light(n, Vector3(0, 2.2, 0), Color(0.7, 0.55, 1.0), 2.0, 9.0)
	# what holds the pad up: the building under it, down to the roofs; in Berlin a slim pylon down to the street,
	# between the lanes
	if era == "rain":
		GfxWorld.paint(k, "wall", Color("2a2e38"), 0.4, 0.8)
		k.box("wall", Vector3(0, -1.6, 0), Vector3(w * 0.7, 0.8, d * 0.7))
		k.box("wall", Vector3(0, -at.y / 2.0 - 1.0, 0), Vector3(1.1, at.y, 1.1))
		k.box("led_a", Vector3(0.56, -at.y / 2.0 - 1.0, 0), Vector3(0.04, at.y - 4.0, 0.12))
	else:
		GfxWorld.paint(k, "wall", Color("7a6a5a"), 0.9)
		k.box("wall", Vector3(0, -1.2 - 9.0, 0), Vector3(w - 0.2, 18.0, d - 0.2))
	GfxWorld.add_mesh(n, k.bake(), "Pad")
	return n


func _balustrade(k: MeshKit, w: float, d: float, m: String) -> void:
	## a stone balustrade along the two sides (the front, towards the view, and the camera's side are left open)
	for edge in [[Vector3(-w / 2, 0, -d / 2), Vector3(-w / 2, 0, d / 2)], [Vector3(w / 2, 0, -d / 2), Vector3(w / 2, 0, d / 2)]]:
		var a: Vector3 = edge[0]
		var b: Vector3 = edge[1]
		var len := a.distance_to(b)
		var mid := (a + b) * 0.5
		var along := (b - a).normalized()
		k.box(m, mid + Vector3(0, 0.95, 0), Vector3(absf(along.x) * len + 0.3, 0.14, absf(along.z) * len + 0.3))
		k.box(m, mid + Vector3(0, 0.08, 0), Vector3(absf(along.x) * len + 0.3, 0.16, absf(along.z) * len + 0.3))
		var n := int(len / 0.42)
		for j in n + 1:
			k.cylinder(m, a + along * (len * j / n) + Vector3(0, 0.5, 0), 0.08, 0.72, 6)


func _ring(k: MeshKit, m: String, r0: float, r1: float, y: float) -> void:
	k.lathe(m, PackedVector2Array([Vector2(r1, y), Vector2(r0, y)]), Vector3.ZERO, 40, false)


func _palm(k: MeshKit, at: Vector3) -> void:
	k.cylinder("pot", at + Vector3(0, 0.35, 0), 0.38, 0.7, 10)
	k.cylinder("trunk", at + Vector3(0, 1.5, 0), 0.08, 1.8, 6)
	for j in 7:
		var a := TAU * j / 7.0
		var dir := Vector3(cos(a), 0, sin(a))
		var tip := at + Vector3(0, 2.2, 0) + dir * 1.2 + Vector3(0, -0.35, 0)
		var base := at + Vector3(0, 2.45, 0)
		var sd := dir.cross(Vector3.UP) * 0.22
		k.quad("leaf", base - sd * 0.3, base + sd * 0.3, tip + sd * 0.05, tip - sd * 0.05)
		k.quad("leaf", base + sd * 0.3, base - sd * 0.3, tip - sd * 0.05, tip + sd * 0.05)


func _light(parent: Node3D, at: Vector3, c: Color, energy: float, reach: float) -> void:
	var o := OmniLight3D.new()
	o.position = at
	o.light_color = c
	o.light_energy = energy
	o.omni_range = reach
	parent.add_child(o)
