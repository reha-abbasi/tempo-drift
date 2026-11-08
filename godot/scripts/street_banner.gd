@tool
extends Node3D
class_name StreetBanner
## A street banner, the roadblock hung across the skyway: you fly under it on the road or hop over it. The cloth
## covers its lane at skyway height and hangs from a cable strung between two masts at the kerbs, so it no longer
## floats. Each era has its own banner and masts:
##   the Past     a gilt-framed cloth bill on dark green cast-iron masts with gilt finials, Union bunting
##   the Present  a samba-school flag on white steel masts, paper bandeirinhas on the cable
##   the Future   a glowing LED mesh panel on gunmetal pylons with light strips, LED beads on the cable
## The artwork is assets/banners/<city>_<n>.webp (tools/editor/build_banners.gd); the city picks one for each
## banner (City.vehicle), and in a level scene the banner finds its city itself. The rules' cell is unchanged.

const K := 1.4
## the masts stand at the kerbs, this far from the middle of the street (the lamps stand at 5.67 m)
const MAST_X := 6.2
## the skyway's height above the road: the banner's centre (Rules.LY[1] - Rules.ROAD_Y) * K
const ROAD := 3.22
const SIZE := Vector2(2.9, 1.8125)
const STYLES := {"old": "gaslight", "sunset": "carnival", "rain": "led"}

## the city whose banners these are (old_0 ...) and which of its three
@export var city_key := "old_0":
	set(v):
		city_key = v
		_dirty = true
@export var pick := 0:
	set(v):
		pick = v
		_dirty = true

var _struck := false
var _wraps := false           # the car crashed into it: the cloth wraps the wreck
var _wreck: Node3D            # a copy of the car, left to tumble with the banner round it
var _wreck_v := Vector3.ZERO
var _wreck_spin := Vector3.ZERO
var _pilot: Node3D            # the pilot, thrown out of the wreck up to the jetpack
var _ride: Node3D
var _t_hit := 0.0
var _line: MeshInstance3D     # the cable and what hangs on it (snaps when hit)
var _dangles: Array[Node3D] = []
var _dirty := true
var _lane_x := INF
var _hang: Node3D
var _cloth: MeshInstance3D
var _rig: MeshInstance3D
var _fall := 0.0


func setup_banner(key: String, n: int) -> void:
	## the city sets which banner hangs here (City.vehicle)
	city_key = key
	pick = n


func _ready() -> void:
	if Engine.is_editor_hint():
		_find_city()
	_hang = get_node_or_null("Hang")
	_cloth = get_node_or_null("Hang/Cloth")
	_rig = get_node_or_null("Rig")


func _find_city() -> void:
	## in a level scene: the level's City says which banners hang here
	var p := get_parent()
	while p:
		var c := p.get_node_or_null("City")
		if c and c.scene_file_path != "":
			city_key = c.scene_file_path.get_file().get_basename()
			pick = get_parent().get_index() if get_parent() else 0
			return
		p = p.get_parent()


func _process(delta: float) -> void:
	if not is_inside_tree() or _cloth == null:
		return
	if _dirty:
		_dirty = false
		_dress()
	# the masts follow the lane: rebuilt when the banner is first placed (or moved in the editor)
	var x := global_position.x
	if absf(x - _lane_x) > 0.01:
		_lane_x = x
		_build_rig()
	if _struck and not Engine.is_editor_hint():
		_t_hit += delta
		_swing_dangles()
		if _wraps:
			_wrap_step(delta)
		else:
			# torn off by a shield (or the jetpack): it falls away behind
			_fall = minf(_fall + delta / 0.7, 1.0)
			_hang.rotation.x = -1.35 * _fall * _fall
			_hang.position.y = SIZE.y / 2.0 - 2.4 * _fall * _fall
			_cloth.transparency = _fall


func struck(_from: Vector3) -> void:
	## hit: the cable snaps and its two ends swing down from the masts. If the car crashed into it, the cloth wraps
	## round the car, the wrapped car tumbles on and drops to the road, and the pilot is thrown out of it up to the
	## jetpack; a shield (or the jetpack) only tears it off, and it falls away
	_struck = true
	_fall = 0.0
	_t_hit = 0.0
	_snap()
	var run := get_tree().current_scene
	if run == null or run.get("rules") == null or run.get("car") == null:
		return
	# (called while the crash is being dealt: the car is lost only after this)
	if run.rules.respawn > 0.0 and run.rules.form == 2 and is_instance_valid(run.car):
		_wraps = true
		_ride = run.ride
		_pilot = run.pilot
		_wreck = run.car.duplicate() as Node3D
		get_parent().add_child(_wreck)
		_wreck.global_transform = run.car.global_transform
		_wreck_v = Vector3(0.0, 1.5, -float(run.rules.SPEED) * K * 0.98)
		_wreck_spin = Vector3(randf_range(-1.0, 1.0), randf_range(-1.5, 1.5), randf_range(2.0, 3.5) * (1.0 if randf() < 0.5 else -1.0))
		_cloth.top_level = true
		_cloth.extra_cull_margin = 4.0
		_cloth.global_transform = _wreck.global_transform
		(_cloth.material_override as ShaderMaterial).set_shader_parameter("wrap", 0.001)
		tree_exiting.connect(func() -> void:
			if is_instance_valid(_pilot):
				_pilot.position = Vector3.ZERO)


func _wrap_step(delta: float) -> void:
	var m := _cloth.material_override as ShaderMaterial
	m.set_shader_parameter("wrap", maxf(0.001, smoothstep(0.0, 0.35, _t_hit)))
	# the wreck: carried on by its speed, dragged down, tumbling, until it lies on the road
	if is_instance_valid(_wreck):
		_wreck_v.z *= exp(-delta * 0.45)
		_wreck_v.y -= 14.0 * delta
		_wreck.global_position += _wreck_v * delta
		if _wreck.global_position.y < 0.45:
			_wreck.global_position.y = 0.45
			_wreck_v.y = absf(_wreck_v.y) * 0.25
			_wreck_spin *= 0.6
		_wreck.rotation += _wreck_spin * delta * (1.0 if _t_hit > 0.25 else 0.3)
		_cloth.global_transform = _wreck.global_transform
	# the pilot bursts out of the wreck and arcs up to where the jetpack carries on
	if is_instance_valid(_pilot) and is_instance_valid(_ride) and is_instance_valid(_wreck):
		var k := clampf((_t_hit - 0.3) / 0.45, 0.0, 1.0)
		if k < 1.0:
			var from := _ride.to_local(_wreck.global_position)
			_pilot.position = from.lerp(Vector3.ZERO, smoothstep(0.0, 1.0, k)) + Vector3(0, sin(k * PI) * 1.6, 0)
			_pilot.rotation.z = (1.0 - k) * TAU * 0.5
		else:
			_pilot.position = Vector3.ZERO
			_pilot.rotation.z = 0.0
			_pilot = null


func _snap() -> void:
	## the cable parts at the banner: what hung on it goes, and each end swings down from its mast
	if _line:
		_line.visible = false
	var s := style()
	var top := SIZE.y / 2.0 + 0.04
	for mx in [-MAST_X - _lane_x, MAST_X - _lane_x]:
		var pivot := Node3D.new()
		pivot.position = Vector3(mx + signf(-mx) * 0.25, top, 0)
		add_child(pivot)
		var len := minf(absf(mx) - SIZE.x / 2.0, 3.6)
		var tube := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.014
		cm.bottom_radius = 0.014
		cm.height = len
		cm.radial_segments = 4
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("2ef2ff") if s == "led" else Color("15161a")
		if s == "led":
			mat.emission_enabled = true
			mat.emission = mat.albedo_color
			mat.emission_energy_multiplier = 2.0
		cm.material = mat
		tube.mesh = cm
		tube.position.y = -len / 2.0
		pivot.add_child(tube)
		pivot.set_meta("dir", signf(-mx))
		_dangles.append(pivot)
	_swing_dangles()


func _swing_dangles() -> void:
	## from lying along the street (where the cable was) down to hanging, with a damped swing
	for p in _dangles:
		var dir: float = p.get_meta("dir")
		var a := (PI / 2.0) * exp(-2.2 * _t_hit) * cos(5.0 * _t_hit)
		p.rotation.z = -dir * a


func is_struck() -> bool:
	return _struck


func style() -> String:
	return STYLES.get(city_key.get_slice("_", 0), "gaslight")


func _dress() -> void:
	var path := "res://assets/banners/%s_%d.webp" % [city_key, posmod(pick, 3)]
	if not ResourceLoader.exists(path):
		path = "res://assets/banners/old_0_0.webp"
	var m := (_cloth.material_override as ShaderMaterial)
	if m == null or not m.resource_local_to_scene:
		m = (_cloth.get_surface_override_material(0) if _cloth.get_surface_override_material(0) else _cloth.mesh.surface_get_material(0)).duplicate() as ShaderMaterial
		m.resource_local_to_scene = true
		_cloth.material_override = m
	m.set_shader_parameter("art", load(path))
	var s := style()
	m.set_shader_parameter("stiff", 1.0 if s == "led" else 0.0)
	m.set_shader_parameter("glow", 1.6 if s == "led" else 0.28)
	m.set_shader_parameter("phase", float(hash(city_key + str(pick)) % 100) * 0.13)
	m.set_shader_parameter("back_color", {"gaslight": Color("3a0d14"), "carnival": Color("0c5a32"), "led": Color("0a0b12")}[s])
	_lane_x = INF


func _build_rig() -> void:
	## the two masts, the cable between them and what hangs on it, around this lane's banner
	var s := style()
	var ground := -ROAD
	var top := SIZE.y / 2.0
	var cable_y := top + 0.04
	var xl := -MAST_X - _lane_x
	var xr := MAST_X - _lane_x
	var am := ArrayMesh.new()
	var col_mast: Color = {"gaslight": Color("1f2b24"), "carnival": Color("eef0f2"), "led": Color("2a2e38")}[s]
	var col_trim: Color = {"gaslight": Color("d9b25a"), "carnival": Color("e6347f"), "led": Color("ff3fb4")}[s]
	# the masts
	var mast := SurfaceTool.new()
	mast.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trimst := SurfaceTool.new()
	trimst.begin(Mesh.PRIMITIVE_TRIANGLES)
	for mx in [xl, xr]:
		var h := cable_y + 0.55 - ground
		match s:
			"gaslight":
				_cyl(mast, Vector3(mx, ground, 0), 0.2, 0.17, 0.7, 10)
				_cyl(mast, Vector3(mx, ground + 0.7, 0), 0.1, 0.075, h - 0.7, 10)
				for ry in [0.7, 1.9, h - 0.65]:
					_cyl(trimst, Vector3(mx, ground + ry, 0), 0.115, 0.115, 0.08, 10)
				_ball(trimst, Vector3(mx, ground + h + 0.09, 0), 0.11)
				_cyl(trimst, Vector3(mx, ground + h + 0.18, 0), 0.025, 0.0, 0.32, 6)
			"carnival":
				_cyl(mast, Vector3(mx, ground, 0), 0.12, 0.12, 0.35, 10)
				_cyl(mast, Vector3(mx, ground + 0.35, 0), 0.065, 0.055, h - 0.35, 10)
				_cyl(trimst, Vector3(mx, ground + h - 0.9, 0), 0.07, 0.07, 0.25, 10)
				_ball(trimst, Vector3(mx, ground + h + 0.05, 0), 0.08)
			_:
				_box(mast, Vector3(mx, ground + h / 2.0, 0), Vector3(0.16, h, 0.16))
				_box(trimst, Vector3(mx + signf(-mx) * 0.085, ground + h / 2.0 + 0.3, 0), Vector3(0.02, h - 0.9, 0.06))
				_box(trimst, Vector3(mx, ground + h + 0.06, 0), Vector3(0.24, 0.1, 0.24))
		# the arm the cable is tied to
		_box(mast, Vector3(mx + signf(-mx) * 0.12, cable_y, 0), Vector3(0.26, 0.05, 0.05))
	# the cable, dipping a little in the middle of each span
	var cab := SurfaceTool.new()
	cab.begin(Mesh.PRIMITIVE_TRIANGLES)
	var deco := SurfaceTool.new()
	deco.begin(Mesh.PRIMITIVE_TRIANGLES)
	for span in [[xl, -SIZE.x / 2.0], [SIZE.x / 2.0, xr]]:
		var a: float = span[0]
		var b: float = span[1]
		if b - a < 0.3:
			continue
		var n := maxi(4, int((b - a) / 0.35))
		var prev := Vector3(a, cable_y, 0)
		for i in range(1, n + 1):
			var u := float(i) / n
			var p := Vector3(lerpf(a, b, u), cable_y - 0.22 * sin(u * PI), 0)
			_tube(cab, prev, p, 0.012)
			# bunting, paper flags or LED beads, one per step
			if i < n:
				match s:
					"gaslight", "carnival":
						var w := 0.22
						var hh := 0.3 if s == "gaslight" else 0.24
						deco.set_color(_flag_color(s, i))
						deco.add_vertex(p + Vector3(-w / 2, 0, 0))
						deco.add_vertex(p + Vector3(w / 2, 0, 0))
						deco.add_vertex(p + Vector3(0, -hh, 0))
					_:
						deco.set_color(Color("2ef2ff") if i % 2 else col_trim)
						_box(deco, p + Vector3(0, -0.03, 0), Vector3(0.06, 0.06, 0.06))
			prev = p
	# the banner's own rod or frame along its top edge
	if s == "led":
		_box(trimst, Vector3(0, top + 0.02, 0), Vector3(SIZE.x + 0.12, 0.06, 0.08))
		_box(trimst, Vector3(0, -top + 0.05, 0), Vector3(SIZE.x + 0.12, 0.04, 0.06))
	else:
		_cyl(trimst, Vector3(-SIZE.x / 2.0 - 0.08, top + 0.02, 0), 0.025, 0.025, SIZE.x + 0.16, 8, true)
	_commit(am, mast, _mat(col_mast, 0.55, 0.6 if s != "carnival" else 0.1))
	_commit(am, trimst, _mat(col_trim, 0.35, 0.8 if s == "gaslight" else 0.2, 2.5 if s == "led" else 0.0))
	_rig.mesh = am
	# the cable and what hangs on it, apart from the masts so it can snap
	var lm := ArrayMesh.new()
	_commit(lm, cab, _mat(Color("15161a"), 0.6, 0.3))
	var dm := _mat(Color.WHITE, 0.8, 0.0, 1.8 if s == "led" else 0.15)
	dm.vertex_color_use_as_albedo = true
	dm.cull_mode = BaseMaterial3D.CULL_DISABLED
	_commit(lm, deco, dm)
	if _line == null:
		_line = MeshInstance3D.new()
		_line.name = "Line"
		_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_line)
	_line.mesh = lm
	_line.visible = not _struck


func _flag_color(s: String, i: int) -> Color:
	if s == "gaslight":
		return [Color("b0182a"), Color("f2ede0"), Color("1d3a7a")][i % 3]
	return [Color("ffd23f"), Color("e6347f"), Color("0c8f4a"), Color("3fd0ff"), Color("ff7a2e")][i % 5]


func _mat(c: Color, rough: float, metal: float, glow := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = glow
	return m


func _commit(am: ArrayMesh, st: SurfaceTool, m: Material) -> void:
	st.generate_normals()
	var before := am.get_surface_count()
	st.commit(am)
	if am.get_surface_count() > before:
		am.surface_set_material(before, m)


static func _box(st: SurfaceTool, c: Vector3, sz: Vector3) -> void:
	var h := sz / 2.0
	var faces := [[Vector3.RIGHT, Vector3.UP, Vector3.BACK], [Vector3.LEFT, Vector3.UP, Vector3.FORWARD], [Vector3.UP, Vector3.BACK, Vector3.RIGHT],
		[Vector3.DOWN, Vector3.FORWARD, Vector3.RIGHT], [Vector3.BACK, Vector3.UP, Vector3.LEFT], [Vector3.FORWARD, Vector3.UP, Vector3.RIGHT]]
	for f in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var o := c + n * h
		var du := u * h
		var dv := v * h
		var q := [o - du - dv, o - du + dv, o + du + dv, o + du - dv]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.add_vertex(q[idx])


static func _cyl(st: SurfaceTool, base: Vector3, r0: float, r1: float, h: float, seg: int, along_x := false) -> void:
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var p := func(a: float, r: float, y: float) -> Vector3:
			return base + (Vector3(y, cos(a) * r, sin(a) * r) if along_x else Vector3(cos(a) * r, y, sin(a) * r))
		var a: Vector3 = p.call(a0, r0, 0.0)
		var b: Vector3 = p.call(a1, r0, 0.0)
		var c: Vector3 = p.call(a1, r1, h)
		var d: Vector3 = p.call(a0, r1, h)
		for v in [a, d, c, a, c, b]:
			st.add_vertex(v)


static func _ball(st: SurfaceTool, c: Vector3, r: float) -> void:
	var rings := 6
	var seg := 10
	for j in rings:
		var t0 := PI * j / rings
		var t1 := PI * (j + 1) / rings
		for i in seg:
			var a0 := TAU * i / seg
			var a1 := TAU * (i + 1) / seg
			var p := func(t: float, a: float) -> Vector3:
				return c + Vector3(sin(t) * cos(a), cos(t), sin(t) * sin(a)) * r
			var q := [p.call(t0, a0), p.call(t0, a1), p.call(t1, a1), p.call(t1, a0)]
			for idx in [0, 1, 2, 0, 2, 3]:
				st.add_vertex(q[idx])


static func _tube(st: SurfaceTool, a: Vector3, b: Vector3, r: float) -> void:
	var d := (b - a).normalized()
	var u := d.cross(Vector3.FORWARD).normalized() * r
	var v := d.cross(u).normalized() * r
	for i in 4:
		var a0 := TAU * i / 4
		var a1 := TAU * (i + 1) / 4
		var o0 := u * cos(a0) + v * sin(a0)
		var o1 := u * cos(a1) + v * sin(a1)
		for p in [a + o0, b + o0, b + o1, a + o0, b + o1, a + o1]:
			st.add_vertex(p)
