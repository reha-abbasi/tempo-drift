class_name WorldLondon
extends Node3D
## London 1890 at the end of a rainy afternoon: a cobbled street between Victorian terraces, gas lamps and plane
## trees, wet slate roofs and chimney stacks, and the Elizabeth Tower at the end of the street.
## The whole route is laid out once at load: each kind of piece (walls, roofs, chimneys, lamps...) is one batched mesh,
## so the street is a few dozen draw calls however long it is.

const ROAD_Y := -2.3
const WALK_Y := -2.12
const ROAD_HW := 4.6      # half the road's width
const FRONT := 6.8        # where the house fronts stand
const DEPTH := 9.0        # how deep a house is

var z_start := 40.0
var z_end := -1500.0
var far: Node3D           # the skyline at the end of the street, kept at the same distance ahead
var sun: DirectionalLight3D
var env: Environment
var rng := RandomNumberGenerator.new()

# London stock brick (yellow-grey), red brick, soot-darkened brick, and cream stucco
const BRICKS := [Color(0.62, 0.53, 0.40), Color(0.55, 0.30, 0.22), Color(0.40, 0.34, 0.29), Color(0.66, 0.58, 0.45), Color(0.48, 0.27, 0.21)]

func build(length_units: float) -> void:
	rng.seed = 1890
	z_end = -length_units - 260.0
	_environment()
	_street()
	_houses()
	_lamps_and_trees()
	_skyline()
	_weather()

func _mat(path: String, params := {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(path)
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m

func _std(col: Color, rough := 0.8, metal := 0.0, emit := Color.BLACK, emit_e := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	if emit_e > 0.0:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = emit_e
	return m

## one batched mesh: transforms (and optional per-piece custom data) for every copy
func _multi(mesh: Mesh, mat: Material, xforms: Array, custom: Array = [], shadows := true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = custom.size() > 0
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		if custom.size() > 0:
			mm.set_instance_custom_data(i, custom[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi

func _box_xf(center: Vector3, size: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale(size), center)

# ---------------------------------------------------------------- light, sky, fog

func _environment() -> void:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.42
	env.ambient_light_sky_contribution = 0.85
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 0.95
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 0.95
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 0.6)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.8)
	env.set_glow_level(4, 0.5)
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color(0.66, 0.55, 0.45)
	env.fog_light_energy = 1.0
	env.fog_density = 0.0062
	env.fog_sun_scatter = 0.45
	env.fog_sky_affect = 0.15
	env.fog_height = -1.2
	env.fog_height_density = 0.018
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	# the low sun ahead and to the left: long shadows toward the camera, warm light grazing the right-hand houses
	sun = DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.7, 0.44)
	sun.light_energy = 2.0
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 70.0
	sun.directional_shadow_split_1 = 0.25
	sun.shadow_blur = 1.4
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.2
	add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, Vector3(0.62, -0.24, 1.0), Vector3.UP)
	sun.light_angular_distance = 1.2

## the skyline stays the same distance ahead of the car
func follow(car_z: float) -> void:
	if far:
		far.position.z = car_z - 250.0

# ---------------------------------------------------------------- street, pavements, kerbs

func _street() -> void:
	var len := z_start - z_end
	var mid := (z_start + z_end) * 0.5
	# the road: one long plane (it is drawn in pieces so nothing far away is computed for nothing)
	var piece := 60.0
	var road_mat := _mat("res://shaders/cobble.gdshader", {"half_w": ROAD_HW})
	var z := z_start
	while z > z_end:
		var pm := PlaneMesh.new()
		pm.size = Vector2(ROAD_HW * 2.0, piece)
		pm.subdivide_depth = 0
		var mi := MeshInstance3D.new()
		mi.mesh = pm
		mi.material_override = road_mat
		mi.position = Vector3(0, ROAD_Y, z - piece * 0.5)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		z -= piece
	# pavements and granite kerbs
	var walk_mat := _mat("res://shaders/flags.gdshader")
	var kerb_mat := _std(Color(0.5, 0.49, 0.47), 0.45)
	var walks := []
	var kerbs := []
	for s in [-1.0, 1.0]:
		walks.append(_box_xf(Vector3(s * (ROAD_HW + FRONT) * 0.5, WALK_Y - 0.1, mid), Vector3(FRONT - ROAD_HW, 0.2, len)))
		kerbs.append(_box_xf(Vector3(s * (ROAD_HW + 0.12), WALK_Y - 0.09, mid), Vector3(0.24, 0.22, len)))
	_multi(BoxMesh.new(), walk_mat, walks, [], false)
	_multi(BoxMesh.new(), kerb_mat, kerbs, [], false)

# ---------------------------------------------------------------- the terraces

func _prism() -> ArrayMesh:
	# a pitched roof: a triangle across the house, run along the street, with gable ends
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := Vector3(-0.5, 0, -0.5); var b := Vector3(0.5, 0, -0.5); var c := Vector3(0, 1, -0.5)
	var a2 := Vector3(-0.5, 0, 0.5); var b2 := Vector3(0.5, 0, 0.5); var c2 := Vector3(0, 1, 0.5)
	for tri in [[a, c, c2], [a, c2, a2], [b, b2, c2], [b, c2, c], [a, b, c], [a2, c2, b2]]:
		var n: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
		for v in tri:
			st.set_normal(n)
			st.add_vertex(v)
	return st.commit()

func _houses() -> void:
	var walls := []; var wall_cd := []
	var roofs := []
	var stacks := []; var stack_cd := []
	var pots := []
	var cornices := []
	var rails := []
	for s in [-1.0, 1.0]:
		var z := z_start
		var since_gap := 0.0
		while z > z_end:
			# now and then a side street opens between the terraces
			if since_gap > 70.0 and rng.randf() < 0.07:
				z -= 8.0 + rng.randf() * 4.0
				since_gap = 0.0
				continue
			var w: float = [4.5, 5.0, 5.0, 5.5, 6.0][rng.randi() % 5]
			var floors := 3 + int(rng.randf() < 0.55) + int(rng.randf() < 0.25)
			var h := floors * 2.7 + 0.7
			var cz := z - w * 0.5
			var cx: float = s * (FRONT + DEPTH * 0.5)
			var style: float = [0.0, 0.5, 1.0, 0.5, 0.0, 1.0][rng.randi() % 6]
			var col: Color = BRICKS[rng.randi() % BRICKS.size()]
			# a row of houses built together shares its brick: the next few stay close to this colour
			walls.append(_box_xf(Vector3(cx, WALK_Y + h * 0.5, cz), Vector3(DEPTH, h, w)))
			wall_cd.append(Color(col.r, col.g, col.b, style))
			# some houses have a two-storey bay window
			if rng.randf() < 0.3 and w >= 5.0:
				var bw := 2.6
				walls.append(_box_xf(Vector3(s * (FRONT - 0.35), WALK_Y + 2.7, cz), Vector3(0.7, 5.4, bw)))
				wall_cd.append(Color(0.84, 0.8, 0.72, 0.5))
			# the cornice along the top of the front
			cornices.append(_box_xf(Vector3(s * (FRONT - 0.12), WALK_Y + h - 0.12, cz), Vector3(0.36, 0.26, w + 0.02)))
			# a slate roof, its ridge along the street
			var rh := 1.6 + rng.randf() * 0.9
			roofs.append(Transform3D(Basis.from_scale(Vector3(DEPTH * 0.92, rh, w)), Vector3(cx + s * 0.2, WALK_Y + h, cz)))
			# chimney stacks on the party wall, with clay pots
			var sh := 1.4 + rng.randf() * 1.2
			for dx in [-2.2, 2.2]:
				var sc := Vector3(cx + dx, WALK_Y + h + rh * 0.45 + sh * 0.5, z)
				stacks.append(_box_xf(sc, Vector3(0.8, sh + rh * 0.9, 1.5)))
				stack_cd.append(Color(col.r * 0.9, col.g * 0.9, col.b * 0.9, -1.0))
				for k in 3:
					pots.append(Transform3D(Basis.from_scale(Vector3(0.22, 0.5, 0.22)), sc + Vector3(0, sh * 0.5 + rh * 0.45 + 0.25, -0.45 + k * 0.45)))
			# iron railings in front of the basement areas
			rails.append(Transform3D(Basis.from_scale(Vector3(1, 1.0, w)), Vector3(s * (FRONT - 0.9), WALK_Y + 0.5, cz)))
			z -= w
			since_gap += w
	var wall_mat := _mat("res://shaders/facade.gdshader")
	_multi(BoxMesh.new(), wall_mat, walls, wall_cd)
	_multi(BoxMesh.new(), wall_mat, stacks, stack_cd)
	_multi(_prism(), _mat("res://shaders/roof.gdshader"), roofs)
	_multi(BoxMesh.new(), _std(Color(0.8, 0.77, 0.7), 0.6), cornices)
	var pot := CylinderMesh.new()
	pot.top_radius = 0.42; pot.bottom_radius = 0.5; pot.height = 1.0; pot.radial_segments = 8
	_multi(pot, _std(Color(0.62, 0.34, 0.24), 0.75), pots, [], false)
	var rail_mesh := QuadMesh.new()
	rail_mesh.orientation = PlaneMesh.FACE_X
	var rail_mat := ShaderMaterial.new()
	rail_mat.shader = _railing_shader()
	_multi(rail_mesh, rail_mat, rails, [], false)

func _railing_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float bar = step(fract(wp.z / 0.16), 0.22);
	float top = step(0.9, UV.y) * step(UV.y, 0.96) + step(0.08, UV.y) * step(UV.y, 0.12);
	if (max(bar, top) < 0.5) discard;
	ALBEDO = vec3(0.04, 0.05, 0.045);
	METALLIC = 0.6;
	ROUGHNESS = 0.35;
}
"""
	return sh

# ---------------------------------------------------------------- gas lamps and plane trees

func _lamps_and_trees() -> void:
	var bases := []; var poles := []; var bars := []; var lanterns := []; var caps := []
	var halos := []; var halos_big := []; var pools := []
	var trunks := []; var crowns := []
	for s in [-1.0, 1.0]:
		var z := z_start - (0.0 if s < 0 else 6.5)
		var n := 0
		while z > z_end:
			var x: float = s * (ROAD_HW + 0.75)
			bases.append(Transform3D(Basis.from_scale(Vector3(0.32, 0.6, 0.32)), Vector3(x, WALK_Y + 0.3, z)))
			poles.append(Transform3D(Basis.from_scale(Vector3(0.11, 3.7, 0.11)), Vector3(x, WALK_Y + 2.15, z)))
			bars.append(_box_xf(Vector3(x, WALK_Y + 3.45, z), Vector3(0.7, 0.05, 0.05)))
			var lp := Vector3(x, WALK_Y + 4.25, z)
			lanterns.append(_box_xf(lp, Vector3(0.38, 0.55, 0.38)))
			caps.append(Transform3D(Basis.from_scale(Vector3(0.6, 0.32, 0.6)), lp + Vector3(0, 0.42, 0)))
			halos.append(Transform3D(Basis.from_scale(Vector3.ONE * 1.5), lp))
			halos_big.append(Transform3D(Basis.from_scale(Vector3.ONE * 5.0), lp))
			pools.append(Transform3D(Basis.from_scale(Vector3(5.5, 1, 5.5)), Vector3(x - s * 0.6, WALK_Y + 0.02, z)))
			# a plane tree halfway between every other pair of lamps
			if n % 2 == 1:
				var tz := z + 6.5
				var tx: float = s * (ROAD_HW + 1.25)
				trunks.append(Transform3D(Basis.from_scale(Vector3(0.36, 4.4, 0.36)), Vector3(tx, WALK_Y + 2.2, tz)))
				for k in 4:
					var r := 1.4 + rng.randf() * 0.7
					var off := Vector3((rng.randf() - 0.5) * 1.6 + s * 0.3, 4.4 + rng.randf() * 1.6 + k * 0.35, (rng.randf() - 0.5) * 2.2)
					crowns.append(Transform3D(Basis.from_scale(Vector3(r, r * 0.85, r)).rotated(Vector3.UP, rng.randf() * TAU), Vector3(tx, WALK_Y, tz) + off))
			z -= 13.0
			n += 1
	var iron := _std(Color(0.06, 0.08, 0.07), 0.4, 0.6)
	var cyl := CylinderMesh.new()
	cyl.radial_segments = 10; cyl.top_radius = 0.5; cyl.bottom_radius = 0.5; cyl.height = 1.0
	_multi(cyl, iron, bases)
	_multi(cyl, iron, poles)
	_multi(BoxMesh.new(), iron, bars, [], false)
	_multi(BoxMesh.new(), _std(Color(1.0, 0.85, 0.6), 0.2, 0.0, Color(1.0, 0.72, 0.4), 4.0), lanterns, [], false)
	var cap := CylinderMesh.new()
	cap.top_radius = 0.05; cap.bottom_radius = 0.5; cap.height = 1.0; cap.radial_segments = 4
	_multi(cap, iron, caps, [], false)
	var quad := QuadMesh.new()
	_multi(quad, _mat("res://shaders/halo.gdshader", {"tint": Color(1.0, 0.7, 0.38), "energy": 1.1, "fade": 0.012}), halos, [], false)
	_multi(quad, _mat("res://shaders/halo.gdshader", {"tint": Color(1.0, 0.66, 0.36), "energy": 0.16, "fade": 0.01}), halos_big, [], false)
	_multi(_pool_mesh(), _mat_pool(), pools, [], false)
	var bark := _std(Color(0.42, 0.4, 0.33), 0.85)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.35; trunk.bottom_radius = 0.5; trunk.height = 1.0; trunk.radial_segments = 8
	_multi(trunk, bark, trunks)
	var crown := SphereMesh.new()
	crown.radial_segments = 14; crown.rings = 8
	var leaves := ShaderMaterial.new()
	leaves.shader = _leaves_shader()
	_multi(crown, leaves, crowns)

func _pool_mesh() -> PlaneMesh:
	var p := PlaneMesh.new()
	p.size = Vector2(1, 1)
	return p

## the pool of lamplight on the wet pavement and road
func _mat_pool() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, shadows_disabled, fog_disabled;
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float f = exp(-length(VERTEX) * 0.02);
	ALBEDO = vec3(1.0, 0.62, 0.3) * pow(clamp(1.0 - d, 0.0, 1.0), 2.2) * 0.32 * f;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m

func _leaves_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
varying vec3 wp;
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec3 p) {
	vec3 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = mix(h21(i.xy + i.z * 7.1), h21(i.xy + vec2(1, 0) + i.z * 7.1), f.x);
	float b = mix(h21(i.xy + vec2(0, 1) + i.z * 7.1), h21(i.xy + vec2(1, 1) + i.z * 7.1), f.x);
	return mix(a, b, f.y);
}
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// lumpy, leafy silhouettes instead of smooth balls
	VERTEX += NORMAL * (vn(w * 1.3) - 0.5) * 0.5;
	wp = w;
}
void fragment() {
	float n = vn(wp * 3.0) * 0.6 + vn(wp * 7.0) * 0.4;
	ALBEDO = mix(vec3(0.16, 0.22, 0.09), vec3(0.36, 0.42, 0.16), n);
	ROUGHNESS = 0.7;
	SPECULAR = 0.3;
	BACKLIGHT = vec3(0.35, 0.4, 0.12);
}
"""
	return sh

# ---------------------------------------------------------------- the skyline at the end of the street

func _sil(depth: float, ribs := 0.6) -> ShaderMaterial:
	return _mat("res://shaders/silhouette.gdshader", {"depth": depth, "ribs": ribs})

func _skyline() -> void:
	far = Node3D.new()
	add_child(far)
	# the Elizabeth Tower: the shaft, the belfry with its four lit clock faces, and the spire
	var tower := Node3D.new()
	tower.position = Vector3(3.0, ROAD_Y, 0.0)
	far.add_child(tower)
	var tw := _sil(0.34, 1.4)
	_part(tower, BoxMesh.new(), tw, Vector3(0, 26, 0), Vector3(7.5, 52, 7.5))
	_part(tower, BoxMesh.new(), tw, Vector3(0, 56.5, 0), Vector3(9.0, 9.0, 9.0))
	var face_mat := _std(Color(1.0, 0.9, 0.7), 0.3, 0.0, Color(1.0, 0.8, 0.5), 2.6)
	face_mat.disable_fog = true
	var disc := CylinderMesh.new()
	disc.top_radius = 3.1; disc.bottom_radius = 3.1; disc.height = 0.2; disc.radial_segments = 24
	for k in 4:
		var a := k * PI * 0.5
		var d := Vector3(sin(a), 0, cos(a))
		var p := MeshInstance3D.new()
		p.mesh = disc
		p.material_override = face_mat
		p.position = Vector3(0, 56.5, 0) + d * 4.55
		p.basis = Basis.looking_at(d, Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
		tower.add_child(p)
	var glow_q := QuadMesh.new()
	var halo := MeshInstance3D.new()
	halo.mesh = glow_q
	halo.material_override = _mat("res://shaders/halo.gdshader", {"tint": Color(1.0, 0.75, 0.45), "energy": 0.5, "fade": 0.0})
	halo.position = Vector3(0, 56.5, 6.0)
	halo.scale = Vector3.ONE * 16.0
	tower.add_child(halo)
	_part(tower, BoxMesh.new(), tw, Vector3(0, 63, 0), Vector3(8.0, 4.0, 8.0))
	var spire := CylinderMesh.new()
	spire.top_radius = 0.1; spire.bottom_radius = 0.5; spire.height = 1.0; spire.radial_segments = 4
	_part(tower, spire, tw, Vector3(0, 74, 0), Vector3(10.5, 18, 10.5), PI * 0.25)
	_part(tower, spire, tw, Vector3(0, 86, 0), Vector3(1.8, 7, 1.8), PI * 0.25)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_part(tower, spire, tw, Vector3(sx * 4.2, 69, sz * 4.2), Vector3(1.4, 6, 1.4), PI * 0.25)
	# the Palace of Westminster beside it, with its row of pinnacles, and the Victoria Tower further off
	var pal := _sil(0.46, 1.8)
	_part(far, BoxMesh.new(), pal, Vector3(-30, ROAD_Y + 11, 12), Vector3(48, 22, 14))
	for i in 10:
		_part(far, spire, pal, Vector3(-52 + i * 5.0, ROAD_Y + 25, 12), Vector3(1.6, 6, 1.6), PI * 0.25)
	var vic := _sil(0.6, 1.2)
	_part(far, BoxMesh.new(), vic, Vector3(-70, ROAD_Y + 30, 40), Vector3(12, 60, 12))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_part(far, spire, vic, Vector3(-70 + sx * 5.2, ROAD_Y + 63, 40 + sz * 5.2), Vector3(1.8, 8, 1.8), PI * 0.25)
	# St Paul's dome far to the right
	var sp := _sil(0.68, 0.0)
	var dome := SphereMesh.new()
	dome.radial_segments = 24; dome.rings = 12; dome.is_hemisphere = true
	_part(far, CylinderMesh.new(), sp, Vector3(110, ROAD_Y + 26, 120), Vector3(30, 18, 30))
	_part(far, dome, sp, Vector3(110, ROAD_Y + 35, 120), Vector3(17, 17, 17))
	_part(far, CylinderMesh.new(), sp, Vector3(110, ROAD_Y + 54, 120), Vector3(3, 6, 3))
	# the roofs of the rest of the city, layer behind layer
	for layer in 3:
		var m := _sil(0.5 + layer * 0.14, 0.0)
		for i in 26:
			var x := -90.0 + i * 7.0 + rng.randf() * 4.0
			if absf(x - 3.0) < 6.0:
				continue
			var h := 8.0 + rng.randf() * 12.0 + layer * 3.0
			_part(far, BoxMesh.new(), m, Vector3(x, ROAD_Y + h * 0.5, 30.0 + layer * 40.0), Vector3(6.0 + rng.randf() * 4.0, h, 8.0))

func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, scl: Vector3, rot_y := 0.0) -> MeshInstance3D:
	var p := MeshInstance3D.new()
	p.mesh = mesh
	p.material_override = mat
	p.position = pos
	p.basis = Basis(Vector3.UP, rot_y).scaled(scl)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	return p

# ---------------------------------------------------------------- drizzle, chimney smoke and street mist

var rain: GPUParticles3D
var smoke: GPUParticles3D
var mist: GPUParticles3D

func _weather() -> void:
	rain = GPUParticles3D.new()
	rain.amount = 1600
	rain.lifetime = 0.9
	rain.preprocess = 1.0
	rain.visibility_aabb = AABB(Vector3(-40, -20, -80), Vector3(80, 40, 160))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(9, 5, 22)
	pm.direction = Vector3(0.06, -1, 0.12)
	pm.spread = 2.0
	pm.initial_velocity_min = 14.0
	pm.initial_velocity_max = 18.0
	pm.gravity = Vector3(0, -4, 0)
	pm.particle_flag_align_y = true
	rain.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.018, 0.7)
	var rm := ShaderMaterial.new()
	rm.shader = load("res://shaders/rain.gdshader")
	q.material = rm
	rain.draw_pass_1 = q
	add_child(rain)
	smoke = _puffs(70, 7.0, Vector3(13, 1.2, 70), Vector3(0.6, 0.35, 0), Vector2(3.0, 7.0), Color(0.6, 0.58, 0.56), 0.16)
	mist = _puffs(36, 8.0, Vector3(5, 0.4, 70), Vector3(0.3, 0.02, 0), Vector2(7.0, 12.0), Color(0.82, 0.75, 0.66), 0.07)

func _puffs(amount: int, life: float, box: Vector3, vel: Vector3, size: Vector2, col: Color, alpha: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.visibility_aabb = AABB(Vector3(-60, -30, -160), Vector3(120, 60, 320))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = box
	pm.direction = vel.normalized() if vel.length() > 0.0 else Vector3.UP
	pm.spread = 25.0
	pm.initial_velocity_min = vel.length() * 0.6
	pm.initial_velocity_max = vel.length() * 1.4
	pm.gravity = Vector3.ZERO
	pm.scale_min = size.x
	pm.scale_max = size.y
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0))
	curve.add_point(Vector2(0.25, 1))
	curve.add_point(Vector2(0.8, 0.7))
	curve.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.alpha_curve = ct
	# each puff gets its own random number in its colour's red channel (the shader turns it into its shape)
	var g := Gradient.new()
	g.set_color(0, Color(0, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 1))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_initial_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/smoke.gdshader")
	m.set_shader_parameter("tint", col)
	m.set_shader_parameter("alpha", alpha)
	m.render_priority = -1
	q.material = m
	p.draw_pass_1 = q
	p.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD
	add_child(p)
	return p

## the weather moves with the camera: rain falls around it, smoke rises from the roofs ahead, mist hangs over the road
func weather_follow(cam_pos: Vector3) -> void:
	if rain:
		rain.global_position = cam_pos + Vector3(0, 1.5, -16)
		smoke.global_position = Vector3(0, WALK_Y + 15.0, cam_pos.z - 60.0)
		mist.global_position = Vector3(0, ROAD_Y + 0.6, cam_pos.z - 55.0)
