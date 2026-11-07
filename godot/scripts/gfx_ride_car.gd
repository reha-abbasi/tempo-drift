extends Node3D
## A car in the new look (scenes/gfx_ride/cars/, built by tools/editor/build_gfx_ride.gd).
## It keeps its own livery in every era (the era's colours light its strips and engines, as the old cars took the
## era's paint, scripts/car_look.gd) and a thin outline rings it (dark by day, neon at night). Its engines follow the
## moves: the exhausts stretch and
## run hotter on a climb or a swipe, the anti-gravity glow under it swells, and in Overdrive everything burns hotter
## and the body warms up. Fans in the "spin" group turn; a light bar (surfaces "red" and "blue") flashes.

## the car's own body colour and stripe colour (transparent: the era's paint, the era's light strip)
@export var livery := Color(0, 0, 0, 0)
@export var stripe_color := Color(0, 0, 0, 0)
## racing stripes along the top: how far out from the middle (0: none) and how wide (m)
@export var stripe_x := 0.0
@export var stripe_w := 0.03

var _t := 0.0
var _heat := 0.0
var _boost := 0.0
var _paint: ShaderMaterial
var _pods: StandardMaterial3D
var _cones: Array[ShaderMaterial] = []
var _glows: Array[ShaderMaterial] = []
var _hover: ShaderMaterial
var _bar: Array[StandardMaterial3D] = []
var _pods_color := Color.WHITE
var _outlines: Array[ShaderMaterial] = []
var _night := 0.0


func paint(body: Color, strip: Color, pods: Color) -> void:
	_pods_color = pods
	if livery.a > 0.0:
		body = livery
	var outline: ShaderMaterial = preload("res://materials/gfx_ride/outline.tres")
	_outlines.clear()
	var b := $Body as MeshInstance3D
	for i in b.mesh.get_surface_count():
		var mat := b.mesh.surface_get_material(i)
		match b.mesh.surface_get_name(i):
			"paint":
				_paint = mat.duplicate()
				_paint.set_shader_parameter("paint", body)
				# a dark livery stays dark: less metal, so it doesn't turn the light's colour
				if body.get_luminance() < 0.15:
					_paint.set_shader_parameter("metal", 0.05)
				# the stripes in the car's stripe colour, else the light strip's, or dark where that would vanish
				var sc := stripe_color if stripe_color.a > 0.0 else strip
				var far := Vector3(sc.r - body.r, sc.g - body.g, sc.b - body.b).length() > 0.3
				_paint.set_shader_parameter("stripe", sc if far else Color(0.07, 0.08, 0.1))
				_paint.set_shader_parameter("stripe_x", stripe_x)
				_paint.set_shader_parameter("stripe_w", stripe_w)
				_paint.set_shader_parameter("night", _night)
				_paint.next_pass = outline.duplicate()
				_outlines.append(_paint.next_pass)
				b.set_surface_override_material(i, _paint)
			"carbon":
				var m: StandardMaterial3D = mat.duplicate()
				m.next_pass = outline.duplicate()
				_outlines.append(m.next_pass)
				b.set_surface_override_material(i, m)
			"strip":
				var m: StandardMaterial3D = mat.duplicate()
				m.albedo_color = strip
				m.emission = strip
				b.set_surface_override_material(i, m)
			"pods":
				_pods = mat.duplicate()
				_pods.albedo_color = pods
				_pods.emission = pods
				b.set_surface_override_material(i, _pods)
			"red", "blue":
				var m: StandardMaterial3D = mat.duplicate()
				b.set_surface_override_material(i, m)
				_bar.append(m)
	_cones.clear()
	_glows.clear()
	for f in find_children("Flame*", "", true, false):
		var cone := f.get_node("Cone") as MeshInstance3D
		var cm: ShaderMaterial = cone.mesh.surface_get_material(0).duplicate()
		cm.set_shader_parameter("outer", pods)
		cone.material_override = cm
		_cones.append(cm)
		var glow := f.get_node("Glow") as MeshInstance3D
		var gm: ShaderMaterial = glow.mesh.surface_get_material(0).duplicate()
		gm.set_shader_parameter("color", pods.lerp(Color.WHITE, 0.3))
		glow.material_override = gm
		_glows.append(gm)
	var hv := $Hover as MeshInstance3D
	_hover = hv.mesh.surface_get_material(0).duplicate()
	_hover.set_shader_parameter("color", pods)
	hv.material_override = _hover
	$Underglow.light_color = pods


func look(night: float, line: Color, line_energy: float) -> void:
	## the city's mood: how much neon the paint and glass catch (0 day .. 1 night) and the outline's colour
	_night = night
	if _paint:
		_paint.set_shader_parameter("night", night)
	var glass_i := -1
	var b := $Body as MeshInstance3D
	for i in b.mesh.get_surface_count():
		if b.mesh.surface_get_name(i) == "~paint":
			glass_i = i
	if glass_i >= 0:
		(b.mesh.surface_get_material(glass_i) as ShaderMaterial).set_shader_parameter("night", night)
	for m in _outlines:
		m.set_shader_parameter("color", line)
		m.set_shader_parameter("energy", line_energy)


func motion(vel: Vector2, boost: float) -> void:
	## vel: sideways and vertical speed (m/s); boost 0..1 (Overdrive)
	var dt := get_process_delta_time()
	_t += dt
	var want := clampf(absf(vel.x) * 0.06 + maxf(vel.y, 0.0) * 0.1, 0.0, 1.0)
	_heat = maxf(want, move_toward(_heat, want, dt * 2.5))
	_boost = move_toward(_boost, boost, dt * 2.0)
	var hot := clampf(_heat + _boost * 0.7, 0.0, 1.4)
	var flick := 0.92 + 0.08 * sin(_t * 47.0) + 0.04 * sin(_t * 23.0)
	for f in find_children("Flame*", "", true, false):
		(f as Node3D).scale = Vector3(1, 1, (0.8 + hot * 0.9) * flick)
	for m in _cones:
		m.set_shader_parameter("heat", hot)
		m.set_shader_parameter("core", Color(1.0, 0.97, 0.9).lerp(Color(1.0, 0.85, 0.45), _boost))
	for m in _glows:
		m.set_shader_parameter("intensity", 1.6 + hot * 1.4)
	if _pods:
		_pods.emission_energy_multiplier = 4.0 + hot * 4.0
	if _hover:
		_hover.set_shader_parameter("intensity", 0.9 + hot * 0.8 - minf(vel.y, 0.0) * 0.05)
	if _paint:
		_paint.set_shader_parameter("glow", _boost * 0.45)


func _process(delta: float) -> void:
	for n in get_tree().get_nodes_in_group("spin"):
		if is_ancestor_of(n):
			(n as Node3D).rotate_y(40.0 * delta)
	if _bar.size() == 2:
		# the light bar: red and blue in turn, a double flash each
		var ph := fmod(Time.get_ticks_msec() / 1000.0 * 2.0, 1.0)
		var on_a := ph < 0.5 and fmod(ph, 0.25) < 0.14
		var on_b := ph >= 0.5 and fmod(ph, 0.25) < 0.14
		_bar[0].emission_energy_multiplier = 7.0 if on_a else 0.6
		_bar[1].emission_energy_multiplier = 7.0 if on_b else 0.6
