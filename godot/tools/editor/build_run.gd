extends RefCounted
## The run scene (scenes/run/run.tscn): where the city, the car and the rings go, the camera, the music, the effects
## and the HUD. Everything here is an ordinary node to adjust in the editor; scripts/run.gd plays the run.


func build(_host: Node) -> void:
	var root := Node3D.new()
	root.name = "Run"
	root.set_script(load("res://scripts/run.gd"))
	for n in ["CityHolder", "Ride", "Rings", "Traffic"]:
		var c := Node3D.new()
		c.name = n
		root.add_child(c)
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.fov = 62.0
	cam.near = 0.1
	cam.far = 900.0
	cam.current = true
	root.add_child(cam)
	var music := Node.new()
	music.name = "Music"
	music.set_script(load("res://scripts/music.gd"))
	root.add_child(music)
	root.add_child(effects())
	Kit.instance_any(root, "res://scenes/ui/hud.tscn", "HUDLayer")
	if ResourceLoader.exists("res://scenes/ui/panels.tscn"):
		Kit.instance_any(root, "res://scenes/ui/panels.tscn", "Panels")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/run"))
	Kit.save(root, "res://scenes/run/run.tscn")


func dot_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.add_point(0.25, Color(1, 1, 1, 0.6))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	return t


func glow_material(c: Color, tex: Texture2D = null, billboard := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = c
	m.albedo_texture = tex
	m.vertex_color_use_as_albedo = true
	m.disable_fog = true
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	return m


func fade_ramp(a: Color, b: Color) -> GradientTexture1D:
	var g := Gradient.new()
	g.set_color(0, a)
	g.set_color(1, b)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


func shrink_curve() -> CurveTexture:
	var c := Curve.new()
	c.add_point(Vector2(0, 1))
	c.add_point(Vector2(1, 0))
	var t := CurveTexture.new()
	t.curve = c
	return t


func burst(name: String, amount: int, life: float, vmin: float, vmax: float, gravity: float, mesh: Mesh) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = name
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 1.0
	p.emitting = false
	p.local_coords = false
	p.visibility_aabb = AABB(Vector3(-10, -10, -10), Vector3(20, 20, 20))
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = vmin
	pm.initial_velocity_max = vmax
	pm.gravity = Vector3(0, gravity, 0)
	pm.damping_min = 2.0
	pm.damping_max = 4.0
	pm.scale_curve = shrink_curve()
	p.process_material = pm
	p.draw_pass_1 = mesh
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


func effects() -> Node3D:
	var fx := Node3D.new()
	fx.name = "Effects"
	fx.set_script(load("res://scripts/run_fx.gd"))
	var dot := dot_texture()
	# glints round a played note
	var q := QuadMesh.new()
	q.size = Vector2(0.16, 0.16)
	q.material = glow_material(Color(2, 2, 2), dot)
	var sp := burst("Sparkles", 16, 0.45, 3.0, 6.5, 0.0, q)
	(sp.process_material as ParticleProcessMaterial).color_ramp = fade_ramp(Color.WHITE, Color(1, 1, 1, 0))
	fx.add_child(sp)
	# a crash: hot debris, then smoke
	var deb := BoxMesh.new()
	deb.size = Vector3(0.18, 0.12, 0.25)
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.2, 0.2, 0.22)
	dm.emission_enabled = true
	dm.emission = Color(1.0, 0.45, 0.15)
	dm.emission_energy_multiplier = 3.0
	deb.material = dm
	var cb := burst("CrashBurst", 40, 1.2, 6.0, 12.0, -14.0, deb)
	(cb.process_material as ParticleProcessMaterial).angular_velocity_min = -400.0
	(cb.process_material as ParticleProcessMaterial).angular_velocity_max = 400.0
	fx.add_child(cb)
	var sq := QuadMesh.new()
	sq.size = Vector2(1.6, 1.6)
	var sm := glow_material(Color(0.5, 0.48, 0.5, 0.55), dot)
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	sm.disable_fog = false
	sq.material = sm
	var smoke := burst("Smoke", 24, 1.6, 1.0, 3.0, 1.0, sq)
	var spm := smoke.process_material as ParticleProcessMaterial
	spm.color_ramp = fade_ramp(Color(1, 0.7, 0.5, 0.9), Color(0.4, 0.4, 0.45, 0))
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 2.0))
	var gt := CurveTexture.new()
	gt.curve = grow
	spm.scale_curve = gt
	fx.add_child(smoke)
	# Overdrive: streaks rushing past the camera
	var sl := GPUParticles3D.new()
	sl.name = "SpeedLines"
	sl.amount = 70
	sl.lifetime = 0.35
	sl.local_coords = true
	sl.visibility_aabb = AABB(Vector3(-12, -10, -30), Vector3(24, 20, 50))
	var lpm := ParticleProcessMaterial.new()
	lpm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	lpm.emission_box_extents = Vector3(9, 7, 6)
	lpm.direction = Vector3(0, 0, 1)
	lpm.spread = 0.0
	lpm.initial_velocity_min = 70.0
	lpm.initial_velocity_max = 90.0
	lpm.gravity = Vector3.ZERO
	lpm.color_ramp = fade_ramp(Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.5))
	sl.process_material = lpm
	var line := BoxMesh.new()
	line.size = Vector3(0.03, 0.03, 4.0)
	line.material = glow_material(Color(1, 0.85, 0.95, 0.5), null, false)
	sl.draw_pass_1 = line
	sl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.add_child(sl)
	# the shield bubble, the magnet's ring, the rescue flash
	var bubble := MeshInstance3D.new()
	bubble.name = "Shield"
	var sph := SphereMesh.new()
	sph.radius = 1.4
	sph.height = 2.2
	var fres := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform vec4 color : source_color = vec4(0.18, 0.95, 1.0, 1.0);
void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	ALBEDO = color.rgb * (f * 1.6 + 0.04);
}"""
	fres.shader = sh
	sph.material = fres
	bubble.mesh = sph
	bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.add_child(bubble)
	var mag := MeshInstance3D.new()
	mag.name = "Magnet"
	var tor := TorusMesh.new()
	tor.inner_radius = 1.5
	tor.outer_radius = 1.6
	tor.rings = 48
	var gm := StandardMaterial3D.new()
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gm.albedo_color = Color(1.0, 0.83, 0.36) * 1.8
	tor.material = gm
	mag.mesh = tor
	mag.rotation.x = PI / 2
	mag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.add_child(mag)
	var res := MeshInstance3D.new()
	res.name = "Rescue"
	var rt := TorusMesh.new()
	rt.inner_radius = 0.9
	rt.outer_radius = 1.0
	rt.rings = 48
	res.mesh = rt
	var rm := ShaderMaterial.new()
	rm.shader = load("res://materials/shaders/ring.gdshader")
	rm.set_shader_parameter("color", Color("ffd45c"))
	rm.set_shader_parameter("energy", 2.4)
	res.material_override = rm
	res.rotation.x = PI / 2
	fx.add_child(res)
	return fx
