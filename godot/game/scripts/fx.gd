class_name Fx
extends Node3D
## Effects: a burst of sparks, a flash ring and a glow on the car when a note is played, a light trail behind the car
## that grows with the combo, a shockwave on combo milestones, and the fireball, smoke and flying pieces when the car
## is wrecked.

var bursts := []
var flashes := []
var burst_i := 0
var flash_i := 0
var boom: GPUParticles3D
var smoke: GPUParticles3D
var sparks: GPUParticles3D
var debris := []
var glow: MeshInstance3D
var glow_k := 0.0
var glow_col := Color.WHITE
var trail: GPUParticles3D
var trail_col := Color.WHITE

func setup() -> void:
	for i in 8:
		bursts.append(_particles(26, 0.55, 1.0, Vector2(2.5, 6.0), Vector2(0.05, 0.11), "res://shaders/halo.gdshader", -3.0))
	var torus := TorusMesh.new()
	torus.inner_radius = 0.56
	torus.outer_radius = 0.59
	torus.rings = 40
	torus.ring_segments = 6
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/ring.gdshader")
	for i in 6:
		var mi := MeshInstance3D.new()
		mi.mesh = torus
		mi.material_override = m
		mi.rotation.x = PI * 0.5
		mi.visible = false
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		flashes.append({"m": mi, "age": 9.0, "col": Color.WHITE, "rel": Vector3.ZERO, "big": 1.0})
	# the glow that lights up the car for a moment on each note
	var q := QuadMesh.new()
	q.size = Vector2(3.2, 3.2)
	glow = MeshInstance3D.new()
	glow.mesh = q
	var gm := ShaderMaterial.new()
	gm.shader = load("res://shaders/halo.gdshader")
	gm.set_shader_parameter("fade", 0.0)
	glow.material_override = gm
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glow.visible = false
	add_child(glow)
	trail = _trail()
	boom = _particles(46, 0.9, 1.0, Vector2(2.0, 7.5), Vector2(0.35, 0.9), "res://shaders/halo.gdshader", 1.5)
	sparks = _particles(60, 1.1, 1.0, Vector2(5.0, 13.0), Vector2(0.04, 0.08), "res://shaders/halo.gdshader", -9.0)
	smoke = _particles(26, 2.4, 0.9, Vector2(0.6, 2.5), Vector2(1.0, 2.6), "res://shaders/smoke.gdshader", 0.8)

func _particles(amount: int, life: float, explode: float, speed: Vector2, size: Vector2, shader: String, grav: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = explode
	p.emitting = false
	# the effects travel with the car (the street is what moves past), so they're drawn relative to their emitter
	p.local_coords = true
	p.visibility_aabb = AABB(Vector3(-10, -10, -10), Vector3(20, 20, 20))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0.3, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = speed.x
	pm.initial_velocity_max = speed.y
	pm.gravity = Vector3(0, grav, 0)
	pm.damping_min = 1.5
	pm.damping_max = 3.0
	pm.scale_min = size.x
	pm.scale_max = size.y
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	p.process_material = pm
	var q := QuadMesh.new()
	var m := ShaderMaterial.new()
	m.shader = load(shader)
	if shader.ends_with("halo.gdshader"):
		m.set_shader_parameter("fade", 0.01)
	q.material = m
	p.draw_pass_1 = q
	p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD
	add_child(p)
	return p

## the combo trail: sparks of light the car leaves hanging in the air behind it (they stay where they're dropped, so
## they stream away behind you); more of them, and longer lived, the longer the combo
func _trail() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 90
	p.lifetime = 0.55
	p.emitting = false
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-10, -10, -40), Vector3(20, 20, 60))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.25
	pm.direction = Vector3(0, 0.2, 1)
	pm.spread = 40.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 1.2
	pm.gravity = Vector3(0, -0.6, 0)
	pm.scale_min = 0.08
	pm.scale_max = 0.2
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	p.process_material = pm
	var q := QuadMesh.new()
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/halo.gdshader")
	m.set_shader_parameter("fade", 0.01)
	m.set_shader_parameter("energy", 2.0)
	q.material = m
	p.draw_pass_1 = q
	add_child(p)
	return p

## the trail's strength (0 = none, 1 = full) and colour: the colour of the last note caught
func set_trail(k: float, col: Color) -> void:
	trail.emitting = k > 0.0
	trail.amount_ratio = clampf(k, 0.15, 1.0)
	trail_col = trail_col.lerp(col, 0.35)
	var m: ShaderMaterial = (trail.draw_pass_1 as QuadMesh).material
	m.set_shader_parameter("tint", trail_col)
	m.set_shader_parameter("energy", 1.2 + 1.4 * k)

## a combo milestone: a wide shockwave and a big burst of sparks
func milestone(pos: Vector3, col: Color) -> void:
	note_hit(pos, col, true)
	var f: Dictionary = flashes[flash_i % flashes.size()]
	flash_i += 1
	f.age = 0.0
	f.col = col * 1.4
	f.rel = pos - car_pos
	f.big = 3.2
	f.m.global_position = pos

var car_pos := Vector3.ZERO
var rel := {}

## a note played: sparks in the ring's colour and a flash ring that opens out
func note_hit(pos: Vector3, col: Color, strong: bool) -> void:
	var b: GPUParticles3D = bursts[burst_i % bursts.size()]
	burst_i += 1
	var m: ShaderMaterial = (b.draw_pass_1 as QuadMesh).material
	m.set_shader_parameter("tint", col)
	m.set_shader_parameter("energy", 2.6 if strong else 1.6)
	b.global_position = pos
	rel[b] = pos - car_pos
	b.restart()
	var f: Dictionary = flashes[flash_i % flashes.size()]
	flash_i += 1
	f.age = 0.0
	f.col = col
	f.rel = pos - car_pos
	f.big = 1.0
	f.m.global_position = pos
	# and the car lights up in the note's colour
	glow_k = 1.0 if strong else 0.7
	glow_col = col

func crash(pos: Vector3, car: Node3D, speed: float) -> void:
	var bm: ShaderMaterial = (boom.draw_pass_1 as QuadMesh).material
	bm.set_shader_parameter("tint", Color(1.0, 0.45, 0.15))
	bm.set_shader_parameter("energy", 2.2)
	boom.global_position = pos
	rel[boom] = pos - car_pos
	boom.restart()
	var sm: ShaderMaterial = (sparks.draw_pass_1 as QuadMesh).material
	sm.set_shader_parameter("tint", Color(1.0, 0.75, 0.4))
	sm.set_shader_parameter("energy", 3.0)
	sparks.global_position = pos
	rel[sparks] = pos - car_pos
	sparks.restart()
	var km: ShaderMaterial = (smoke.draw_pass_1 as QuadMesh).material
	km.set_shader_parameter("tint", Color(0.22, 0.2, 0.2))
	km.set_shader_parameter("alpha", 0.42)
	smoke.global_position = pos
	rel[smoke] = pos - car_pos
	smoke.restart()
	# the car flies apart: copies of its parts tumble away and fall
	if car == null:
		return
	var body: Node3D = car.get_meta("body")
	for c in body.get_children():
		if not (c is MeshInstance3D) or randf() < 0.35:
			continue
		var piece := MeshInstance3D.new()
		piece.mesh = c.mesh
		piece.material_override = c.material_override
		add_child(piece)
		piece.global_transform = c.global_transform
		# the pieces carry the car's speed, so they tumble out to the sides and drop away below and behind you
		var side := signf(c.position.x) if absf(c.position.x) > 0.05 else (1.0 if randf() < 0.5 else -1.0)
		var v := Vector3(side * randf_range(2.5, 5.5), randf_range(0.5, 2.5), -speed * randf_range(0.9, 0.97))
		debris.append({"n": piece, "v": v, "w": Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9)), "age": 0.0})

func update_fx(dt: float, at_car: Vector3) -> void:
	car_pos = at_car
	for e in rel:
		# the fireball and its smoke drift back a little, as if left in the air
		if e == boom or e == smoke:
			rel[e].z += dt * 5.0
		e.global_position = car_pos + rel[e]
	for f in flashes:
		if f.age > 0.28:
			f.m.visible = false
			continue
		f.age += dt
		var k: float = f.age / 0.28
		f.m.visible = true
		f.m.global_position = car_pos + f.rel
		f.m.scale = Vector3.ONE * (0.75 + k * 0.55 * f.big) * (1.0 + (f.big - 1.0) * 0.3)
		f.m.set_instance_shader_parameter("tint", f.col)
		f.m.set_instance_shader_parameter("glow", (1.0 - k) * (1.0 - k) * 1.1)
	glow_k = maxf(0.0, glow_k - dt * 5.0)
	glow.visible = glow_k > 0.0
	if glow.visible:
		glow.global_position = car_pos + Vector3(0, -0.1, 0.3)
		var gm: ShaderMaterial = glow.material_override
		gm.set_shader_parameter("tint", glow_col)
		gm.set_shader_parameter("energy", glow_k * glow_k * 0.55)
	trail.global_position = car_pos + Vector3(0, -0.15, 0.9)
	for d in debris:
		d.age += dt
		d.v.y -= 14.0 * dt
		d.v.z *= 1.0 - dt * 0.35
		var n: MeshInstance3D = d.n
		n.position += d.v * dt
		n.rotation += d.w * dt
		if n.position.y < World.ROAD_Y + 0.15:
			n.position.y = World.ROAD_Y + 0.15
			d.v *= Vector3(0.6, -0.35, 0.6)
	for i in range(debris.size() - 1, -1, -1):
		if debris[i].age > 1.8:
			debris[i].n.queue_free()
			debris.remove_at(i)
