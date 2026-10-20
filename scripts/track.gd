class_name Track
extends Node3D

## Owns everything that scrolls: obstacles, coins, power-ups and scenery.
## The world moves toward +Z; new stuff is spawned at GameConfig.SPAWN_Z.

const COIN_HEIGHT := 0.9

var obstacles: Array[Obstacle] = []
var coins: Array[Node3D] = []
var powers: Array[Node3D] = []
var scenery: Array[Node3D] = []

var distance := 0.0
var spawning := true        # tests turn this off to build their own layouts
var rng := RandomNumberGenerator.new()

var _cursor := 0.0          # world z where the next pattern starts
var _last_pattern := ""
var _scenery_cursor := {}   # stream name -> world z
var _coin_spin := 0.0
var _obstacle_root: Node3D
var _pickup_root: Node3D
var _scenery_root: Node3D
var _ground_mat: ShaderMaterial


func _ready() -> void:
	_obstacle_root = _make_root("Obstacles")
	_pickup_root = _make_root("Pickups")
	_scenery_root = _make_root("Scenery")
	_build_ground()


func _make_root(n: String) -> Node3D:
	var r := Node3D.new()
	r.name = n
	add_child(r)
	return r


func _build_ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 240)
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = plane
	ground.position = Vector3(0, 0, -100)
	_ground_mat = ShaderMaterial.new()
	_ground_mat.shader = preload("res://shaders/ground.gdshader")
	ground.material_override = _ground_mat
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)
	# curbs between the tracks and the sidewalks
	var curb := MeshKit.mat(Color("b9b9bd"), 0.8)
	for sx in [-1.0, 1.0]:
		MeshKit.box(self, Vector3(0.3, 0.25, 240), curb, Vector3(sx * 4.05, 0.12, -100))


## Clear everything and lay out a fresh track. `seed_value` < 0 = random.
func reset(seed_value := -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	for arr: Array in [obstacles, coins, powers, scenery]:
		for n: Node3D in arr:
			n.queue_free()
		arr.clear()
	distance = 0.0
	_last_pattern = ""
	_cursor = -45.0
	for stream in ["bL", "bR", "pL", "pR"]:
		_scenery_cursor[stream] = 12.0
	_spawn_ahead(GameConfig.START_SPEED)
	_ground_mat.set_shader_parameter("offset", 0.0)


func advance(dz: float, speed: float, delta: float) -> void:
	distance += dz
	_cursor += dz
	for k: String in _scenery_cursor:
		_scenery_cursor[k] += dz
	for arr: Array in [obstacles, coins, powers, scenery]:
		for n: Node3D in arr:
			n.position.z += dz
	_despawn()
	_spawn_ahead(speed)
	_ground_mat.set_shader_parameter("offset", fmod(distance, 120.0))
	animate(delta)


## Spin coins/power-ups (also called on the menu when nothing moves).
func animate(delta: float) -> void:
	_coin_spin = fmod(_coin_spin + delta * 3.5, TAU)
	for c in coins:
		c.rotation.y = _coin_spin
	for p in powers:
		var spin := p.get_node("Spin") as Node3D
		spin.rotation.y = _coin_spin
		spin.position.y = sin(_coin_spin * 2.0) * 0.12


func _despawn() -> void:
	var limit := GameConfig.DESPAWN_Z
	for i in range(obstacles.size() - 1, -1, -1):
		if obstacles[i].far_z() > limit:
			obstacles[i].queue_free()
			obstacles.remove_at(i)
	for arr: Array in [coins, powers]:
		for i in range(arr.size() - 1, -1, -1):
			var n: Node3D = arr[i]
			if n.position.z > limit:
				n.queue_free()
				arr.remove_at(i)
	for i in range(scenery.size() - 1, -1, -1):
		if scenery[i].position.z - float(scenery[i].get_meta("depth", 0.0)) * 0.5 > limit + 10.0:
			scenery[i].queue_free()
			scenery.remove_at(i)


## For tests: place a single obstacle by hand.
func add_obstacle(o: Obstacle, lane: int, z: float) -> Obstacle:
	o.lane = lane
	o.position = Vector3(GameConfig.lane_x(lane), 0, z)
	_obstacle_root.add_child(o)
	obstacles.append(o)
	return o


func remove_coin(c: Node3D) -> void:
	coins.erase(c)
	c.queue_free()


func remove_power(p: Node3D) -> void:
	powers.erase(p)
	p.queue_free()


# ------------------------------------------------------------------ queries

## Highest surface the player can stand on at (x, z).
func ground_height(x: float, z: float, feet: float) -> float:
	var g := 0.0
	for o in obstacles:
		if o.walks.is_empty():
			continue
		g = maxf(g, o.surface_height(x, z, feet, GameConfig.STEP_UP))
	return g


## Ground height ignoring the player's feet (for placing coins).
func _surface_for_spawn(x: float, z: float) -> float:
	return ground_height(x, z, 100.0)


# ------------------------------------------------------------------ spawning

func _spawn_ahead(speed: float) -> void:
	while spawning and _cursor > GameConfig.SPAWN_Z:
		_spawn_pattern(speed)
	for side in [-1.0, 1.0]:
		var bkey := "bL" if side < 0 else "bR"
		while _scenery_cursor[bkey] > GameConfig.SPAWN_Z - 20.0:
			_spawn_building(side, bkey)
		var pkey := "pL" if side < 0 else "pR"
		while _scenery_cursor[pkey] > GameConfig.SPAWN_Z - 20.0:
			_spawn_prop(side, pkey)


func _spawn_pattern(speed: float) -> void:
	var level := Patterns.level_for(distance)
	var p := Patterns.pick(rng, level, _last_pattern)
	_last_pattern = p["name"]
	var mirror := rng.randf() < 0.5
	var stretch := clampf(speed / GameConfig.START_SPEED, 1.0, 2.2)
	var start := _cursor
	var far := start - float(p["len"]) * stretch
	var deferred: Array = []  # coins/power-ups go after obstacles so they can sit on roofs
	for item: Array in p["items"]:
		var kind: String = item[0]
		var lane: int = item[1]
		if mirror:
			lane = 2 - lane
		var z := start - float(item[2]) * stretch
		var o: Obstacle = null
		match kind:
			"hurdle":
				o = WorldKit.hurdle(lane)
			"bar":
				o = WorldKit.bar(lane)
			"train":
				o = WorldKit.train(lane, float(item[3]), bool(item[4]), rng)
			_:
				deferred.append([item, lane, z])
		if o:
			o.pattern = p["name"]
			o.position = Vector3(GameConfig.lane_x(lane), 0, z)
			_obstacle_root.add_child(o)
			obstacles.append(o)
			far = minf(far, o.far_z())
	for d: Array in deferred:
		var item: Array = d[0]
		var lane: int = d[1]
		var z: float = d[2]
		match item[0]:
			"coins":
				_spawn_coins(lane, z, int(item[3]), item[4], speed)
			"power":
				# power-ups are a treat: only show up about half the time
				if rng.randf() < 0.55:
					var pw := WorldKit.power_up(item[3])
					var x := GameConfig.lane_x(lane)
					pw.position = Vector3(x, _surface_for_spawn(x, z) + COIN_HEIGHT + 0.2, z)
					_pickup_root.add_child(pw)
					powers.append(pw)
	var gap := 8.0 + speed * 0.45
	_cursor = far - gap


func _spawn_coins(lane: int, z: float, count: int, style: String, speed: float) -> void:
	var x := GameConfig.lane_x(lane)
	if style == "jump":
		# arc that matches the jump: centred on z, as long as one jump covers
		var air := 2.0 * GameConfig.JUMP_VELOCITY / GameConfig.GRAVITY
		var span := speed * air * 0.9
		for i in count:
			var t := (i + 0.5) / count
			var cz := z + span * 0.5 - span * t
			var h := GameConfig.JUMP_VELOCITY * (t * air) - 0.5 * GameConfig.GRAVITY * pow(t * air, 2)
			_add_coin(Vector3(x, _surface_for_spawn(x, cz) + COIN_HEIGHT + h, cz))
	else:
		for i in count:
			var cz := z - i * 2.2
			_add_coin(Vector3(x, _surface_for_spawn(x, cz) + COIN_HEIGHT, cz))


func _add_coin(pos: Vector3) -> void:
	var c := WorldKit.coin()
	c.position = pos
	_pickup_root.add_child(c)
	coins.append(c)


func _spawn_building(side: float, key: String) -> void:
	var w := rng.randf_range(4.0, 7.0)
	var d := rng.randf_range(5.0, 10.0)
	var h := rng.randf_range(4.0, 13.0)
	var b := WorldKit.building(rng, w, d, h, side)
	var z: float = _scenery_cursor[key] - d * 0.5
	b.position = Vector3(side * (9.0 + w * 0.5), 0, z)
	b.set_meta("depth", d)
	_scenery_root.add_child(b)
	scenery.append(b)
	_scenery_cursor[key] = z - d * 0.5 - rng.randf_range(0.6, 3.0)


func _spawn_prop(side: float, key: String) -> void:
	var z: float = _scenery_cursor[key]
	var r := rng.randf()
	var n: Node3D
	if r < 0.5:
		n = WorldKit.palm(rng)
		n.position = Vector3(side * rng.randf_range(6.2, 7.2), 0, z)
	elif r < 0.8:
		n = WorldKit.lamp_post(side)
		n.position = Vector3(side * 5.0, 0, z)
	else:
		n = WorldKit.bench()
		n.position = Vector3(side * 6.4, 0, z)
		n.rotation.y = 0.0 if side < 0 else PI
	n.set_meta("depth", 2.0)
	_scenery_root.add_child(n)
	scenery.append(n)
	_scenery_cursor[key] = z - rng.randf_range(7.0, 13.0)
