extends Node3D
## The look of everything that moves with the
## player or comes at them. The run makes one when a run (or the menu/garage backdrop) starts;
## it swaps in the new cars and note rings (scenes/gfx_ride/, built by tools/editor/build_gfx_ride.gd), gives
## the jetpack a real flame, restyles the effects (catch sparkles, crash, smoke) and draws a light trail behind the
## engines. With "Reduce effects" on, the trail and the crash fireball are left out.

const CARS := "res://scenes/gfx_ride/cars/%s.tscn"
const CAR_SCRIPT := preload("res://scripts/gfx_ride_car.gd")
const RING := "res://scenes/gfx_ride/note_ring.tscn"
const TRAFFIC := "res://scenes/gfx_ride/traffic/%s.tscn"
## Berlin 2075's taxis, trucks and buses hover
const FUTURE := ["taxi", "truck", "bus"]
## each era's mood for the cars: how much neon they catch, and their outline (dark by day, the era's neon at night)
const MOODS := {"old": [0.0, Color(0.05, 0.04, 0.03), 1.0], "sunset": [0.3, Color(0.07, 0.03, 0.07), 1.0], "rain": [1.0, Color(), 2.2]}
const EXHAUST := preload("res://materials/gfx_ride/ride_exhaust.gdshader")
const GLOW := preload("res://materials/shaders/glow.gdshader")
const TRAIL_T := 0.08       # how long the light trail is, in seconds of flight
const TRAIL_OD := 0.16      # in Overdrive

var run: Node3D
var _low := false
var _trail: MeshInstance3D
var _im: ImmediateMesh
var _hist := []             # per engine: [[position, time], ...] newest first
var _emitters: Array = []
var _clock := 0.0
var _od := 0.0


func setup(r: Node3D) -> void:
	run = r
	_low = Save.data.settings.get("fx_low", false)
	run._ring_scene = load(RING)
	_swap_traffic(run.city, run.info.map == "rain")
	dress()
	_restyle_fx(run.fx)
	# (a car caught in a street banner is wrapped up in it, not blown up: scripts/street_banner.gd)
	run.rules.crashed.connect(_on_crashed)
	_im = ImmediateMesh.new()
	_trail = MeshInstance3D.new()
	_trail.mesh = _im
	_trail.top_level = true
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tm := ShaderMaterial.new()
	tm.shader = preload("res://materials/gfx_ride/ride_trail.gdshader")
	_trail.material_override = tm
	add_child(_trail)


func _on_crashed(h: Dictionary) -> void:
	if h.kind != "barrier":
		_fireball(run.ride.global_position)


func dress() -> void:
	## the new car in place of the old one (also after the garage swaps cars), and the pilot's jetpack flame
	if run.car.get_script() != CAR_SCRIPT:
		var key: String = run.car.scene_file_path.get_file().get_basename()
		var old: Node3D = run.car
		var at := old.get_index()
		old.free()
		run.car = (load(CARS % key) as PackedScene).instantiate()
		run.ride.add_child(run.car)
		run.ride.move_child(run.car, at)
		var pods: Array = run._theme.pods
		run.car.paint(run.Catalog_hex(run._theme.paint), run.Catalog_hex(run._theme.strip), Color(pods[0], pods[1], pods[2]))
		var mood: Array = MOODS.get(run.info.map, MOODS.old)
		run.car.look(mood[0], run.Catalog_hex(run._theme.strip) if mood[1] == Color() else mood[1], mood[2])
	if not run.pilot.has_meta("ride"):
		_dress_pilot(run.pilot)


func _dress_pilot(p: Node3D) -> void:
	## a long hot jetpack flame with a glow at the nozzle, and the suit's edges catching the light
	p.set_meta("ride", true)
	for f in p.find_children("Flame*", "", true, false):
		for c in f.get_children():
			(c as Node3D).visible = false
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.075
		cm.bottom_radius = 0.01
		cm.height = 0.7
		cm.radial_segments = 12
		cm.rings = 1
		cm.cap_top = false
		cm.cap_bottom = false
		var em := ShaderMaterial.new()
		em.shader = EXHAUST
		em.set_shader_parameter("outer", Color(1.0, 0.5, 0.15))
		em.set_shader_parameter("intensity", 2.6)
		cm.material = em
		cone.mesh = cm
		cone.rotation.x = -PI / 2
		cone.position.z = 0.35
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.add_child(cone)
		var g := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.5, 0.5)
		var gm := ShaderMaterial.new()
		gm.shader = GLOW
		gm.set_shader_parameter("color", Color(1.0, 0.72, 0.4))
		gm.set_shader_parameter("intensity", 2.2)
		q.material = gm
		g.mesh = q
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.add_child(g)
	for mi in p.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D)
		if m.mesh == null or m.get_parent().name.begins_with("Flame"):
			continue
		var sm := m.get_active_material(0) as StandardMaterial3D
		if sm and not sm.emission_enabled:
			var d: StandardMaterial3D = sm.duplicate()
			d.rim_enabled = true
			d.rim = 0.7
			d.rim_tint = 0.4
			d.clearcoat_enabled = true
			d.clearcoat_roughness = 0.2
			m.material_override = d


func _swap_traffic(city: City, future: bool) -> void:
	## the city's traffic in the new look (a copy of its list, so the city scene itself is left as it was)
	var t: Dictionary = city.traffic.duplicate()
	for kind in t.keys():
		var key: String = kind + ("_2075" if future and kind in FUTURE else "")
		if ResourceLoader.exists(TRAFFIC % key):
			t[kind] = load(TRAFFIC % key)
	city.traffic = t


# ------------------------------------------------------------------ effects

func _restyle_fx(fx: Node3D) -> void:
	## new looks for run_fx's own effects, which it copies and fires as before
	var sp: GPUParticles3D = fx.sparkles
	var star := StandardMaterial3D.new()
	star.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	star.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	star.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star.disable_fog = true
	star.vertex_color_use_as_albedo = true
	star.albedo_texture = _star_texture()
	star.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var sq := QuadMesh.new()
	sq.size = Vector2(0.3, 0.3)
	sq.material = star
	sp.draw_pass_1 = sq
	var pm: ParticleProcessMaterial = sp.process_material.duplicate()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3(0, 0, 1)
	pm.emission_ring_radius = 0.86
	pm.emission_ring_inner_radius = 0.8
	pm.emission_ring_height = 0.02
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.6
	pm.radial_velocity_min = 4.0
	pm.radial_velocity_max = 7.5
	pm.damping_min = 6.0
	pm.damping_max = 9.0
	pm.angle_min = 0.0
	pm.angle_max = 90.0
	sp.process_material = pm
	sp.lifetime = 0.45
	# the crash: hot shards and a darker, bigger smoke
	var sm: GPUParticles3D = fx.smoke
	var smoke_q: QuadMesh = sm.draw_pass_1.duplicate()
	smoke_q.size = Vector2(2.2, 2.2)
	var smat: StandardMaterial3D = smoke_q.material.duplicate()
	smat.albedo_color = Color(0.32, 0.3, 0.32, 0.75)
	smoke_q.material = smat
	sm.draw_pass_1 = smoke_q
	sm.amount = 10 if _low else 20
	# Overdrive's speed lines: thin streaks around the edges of the view (the middle stays clear for the car and the
	# rings), bright at the head and fading behind, in the trail's gold
	var sl: GPUParticles3D = fx.speed_lines
	var streak := BoxMesh.new()
	streak.size = Vector3(0.035, 0.035, 5.0)
	var stm := ShaderMaterial.new()
	stm.shader = preload("res://materials/gfx_ride/ride_speed.gdshader")
	streak.material = stm
	sl.draw_pass_1 = streak
	var spm: ParticleProcessMaterial = sl.process_material.duplicate()
	spm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	spm.emission_ring_axis = Vector3(0, 0, 1)
	spm.emission_ring_radius = 7.5
	spm.emission_ring_inner_radius = 3.6
	spm.emission_ring_height = 8.0
	sl.process_material = spm
	sl.amount = 48
	var cb: GPUParticles3D = fx.crash_burst
	var shard := PrismMesh.new()
	shard.size = Vector3(0.1, 0.08, 0.16)
	var shm := StandardMaterial3D.new()
	shm.albedo_color = Color(0.25, 0.25, 0.28)
	shm.metallic = 0.6
	shm.roughness = 0.35
	shm.emission_enabled = true
	shm.emission = Color(1.0, 0.5, 0.18)
	shm.emission_energy_multiplier = 1.6
	shard.material = shm
	cb.draw_pass_1 = shard


func _star_texture() -> ImageTexture:
	## a four-pointed glint with a soft round core
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var p := Vector2(x + 0.5 - n / 2.0, y + 0.5 - n / 2.0) / (n / 2.0)
			var core := pow(clampf(1.0 - p.length(), 0.0, 1.0), 2.5)
			var rays := pow(clampf(1.0 - absf(p.x) * 7.0, 0.0, 1.0), 2.0) * (1.0 - absf(p.y)) + pow(clampf(1.0 - absf(p.y) * 7.0, 0.0, 1.0), 2.0) * (1.0 - absf(p.x))
			var a := clampf(core + rays * 0.9, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


func _fireball(at: Vector3) -> void:
	## the crash: a flash of fire that swells and fades
	if _low:
		return
	var g := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var gm := ShaderMaterial.new()
	gm.shader = GLOW
	gm.set_shader_parameter("color", Color(1.0, 0.55, 0.2))
	gm.set_shader_parameter("intensity", 3.0)
	gm.set_shader_parameter("softness", 1.4)
	q.material = gm
	g.mesh = q
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(g)
	g.global_position = at
	# it rides along with the wreck for a moment, so it's seen from the chase camera
	var back: Vector3 = at - run.ride.global_position
	var burn := func(v: float) -> void:
		gm.set_shader_parameter("intensity", v)
		g.global_position = run.ride.global_position + back + Vector3(0, (3.5 - v) * 0.2, (3.5 - v) * 0.8)
	var tw := g.create_tween().set_parallel()
	tw.tween_property(g, "scale", Vector3.ONE * 5.0, 0.5).from(Vector3.ONE * 1.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(burn, 3.5, 0.0, 0.6)
	tw.chain().tween_callback(g.queue_free)


# ------------------------------------------------------------------ the light trail

func _process(delta: float) -> void:
	if run == null or not run.started or run.paused:
		return
	_clock += delta
	var rules: Rules = run.rules
	_od = move_toward(_od, 1.0 if rules.od_t > 0.0 else 0.0, delta * 2.0)
	var src: Node3D = run.car if run.car.visible else run.pilot
	var flames := src.find_children("Flame*", "", true, false)
	if flames != _emitters:
		_emitters = flames
		_hist.clear()
		for f in flames:
			_hist.append([])
	_im.clear_surfaces()
	# (none while the rescue plane flies the car in: it moves on its own then)
	if _low or run.garage or not run.ride.visible or not src.is_visible_in_tree() or src.position != Vector3.ZERO:
		for h in _hist:
			h.clear()
		return
	var span := lerpf(TRAIL_T, TRAIL_OD, _od)
	var cam: Vector3 = run.camera.global_position
	var col: Color = Color(1.0, 0.8, 0.5)
	if run._theme.has("pods"):
		var pods: Array = run._theme.pods
		col = Color(pods[0], pods[1], pods[2])
	col = col.lerp(Color(1.0, 0.82, 0.35), _od)
	# fainter at night, where the wet street already shines
	if run.info.map == "rain":
		col *= 0.55
	var width := (0.06 if src == run.car else 0.045) * (1.0 + _od * 0.8)
	var drew := false
	for i in _emitters.size():
		var h: Array = _hist[i]
		h.push_front([(_emitters[i] as Node3D).global_position, _clock])
		while h.size() > 2 and _clock - float(h[-1][1]) > span:
			h.pop_back()
		if h.size() < 2:
			continue
		if not drew:
			_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			drew = true
		_ribbon(h, cam, width, col, span)
	if drew:
		_im.surface_end()


func _ribbon(h: Array, cam: Vector3, width: float, col: Color, span: float) -> void:
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var prev_c := Color()
	for j in h.size():
		var p: Vector3 = h[j][0]
		var q: Vector3 = h[mini(j + 1, h.size() - 1)][0] if j < h.size() - 1 else p + (p - h[j - 1][0])
		var tang := (q - p).normalized()
		var side := tang.cross(cam - p).normalized()
		var age := clampf((_clock - float(h[j][1])) / span, 0.0, 1.0)
		var w := width * (1.0 - age * 0.7)
		var c := Color(col, pow(1.0 - age, 3.0))
		var l := p - side * w
		var r := p + side * w
		if j > 0:
			for v in [[prev_l, 0.0, prev_c], [prev_r, 1.0, prev_c], [r, 1.0, c], [prev_l, 0.0, prev_c], [r, 1.0, c], [l, 0.0, c]]:
				_im.surface_set_color(v[2])
				_im.surface_set_uv(Vector2(0.0, v[1]))
				_im.surface_add_vertex(v[0])
		prev_l = l
		prev_r = r
		prev_c = c
