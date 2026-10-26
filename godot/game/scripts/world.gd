class_name World
extends Node3D
## A city street of the Past, built from a "look": London 1890 in the rain (Victorian terraces, slate and chimneys,
## Big Ben), Istanbul 1910 at sunset (plaster houses with wooden bay windows, terracotta roofs, cypresses, a great
## mosque), Paris 1925 at dusk (limestone blocks with iron balconies and zinc mansard roofs, the Eiffel Tower).
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
var big_halos: MultiMeshInstance3D
var look: Dictionary

# wall styles for the facade shader: brick 0, plaster 0.25, stucco ground floor 0.5, ashlar stone 0.75, brick with
# stone bands 1
const LOOKS := {
	"london": {
		"sky": [Color(0.3, 0.34, 0.43), Color(0.53, 0.52, 0.53), Color(0.86, 0.7, 0.52), Color(1.0, 0.78, 0.52)],
		"cloud": Color(0.4, 0.4, 0.44), "cover": 0.55, "sun": Color(1.0, 0.7, 0.44), "sun_e": 2.0, "sun_dir": Vector3(0.62, -0.24, 1.0),
		"fog": Color(0.66, 0.55, 0.45), "fog_d": 0.0062, "haze": Color(0.88, 0.75, 0.6),
		"walls": [Color(0.62, 0.53, 0.40), Color(0.55, 0.30, 0.22), Color(0.40, 0.34, 0.29), Color(0.66, 0.58, 0.45), Color(0.48, 0.27, 0.21)],
		"styles": [0.0, 0.5, 1.0, 0.5, 0.0, 1.0], "floors": [3, 5], "roof": "pitch", "roof_col": Color(0.29, 0.31, 0.35),
		"chimneys": true, "bays": "ground", "railings": true, "balconies": false, "trees": "plane", "landmark": "bigben",
		"rain": true, "smoke": true, "puddles": 0.42, "seed": 1890},
	"istanbul": {
		"sky": [Color(0.34, 0.34, 0.6), Color(0.78, 0.56, 0.66), Color(1.0, 0.68, 0.5), Color(1.0, 0.8, 0.56)],
		"cloud": Color(0.62, 0.48, 0.58), "cover": 0.68, "sun": Color(1.0, 0.64, 0.48), "sun_e": 2.2, "sun_dir": Vector3(-0.55, -0.2, 1.0),
		"fog": Color(0.78, 0.58, 0.5), "fog_d": 0.0058, "haze": Color(0.95, 0.7, 0.6),
		"walls": [Color(0.86, 0.66, 0.48), Color(0.8, 0.5, 0.36), Color(0.92, 0.84, 0.7), Color(0.62, 0.46, 0.36), Color(0.76, 0.62, 0.44), Color(0.7, 0.36, 0.3)],
		"styles": [0.25, 0.25, 0.25, 0.5, 0.0], "floors": [2, 4], "roof": "pitch", "roof_col": Color(0.6, 0.31, 0.21),
		"chimneys": false, "bays": "upper", "railings": false, "balconies": false, "trees": "cypress", "landmark": "mosque",
		"rain": false, "smoke": false, "puddles": 0.08, "seed": 1910},
	"paris": {
		"sky": [Color(0.28, 0.32, 0.56), Color(0.68, 0.56, 0.71), Color(0.94, 0.65, 0.63), Color(1.0, 0.78, 0.63)],
		"cloud": Color(0.55, 0.5, 0.62), "cover": 0.62, "sun": Color(1.0, 0.69, 0.6), "sun_e": 1.8, "sun_dir": Vector3(0.5, -0.16, 1.0),
		"fog": Color(0.66, 0.55, 0.62), "fog_d": 0.0052, "haze": Color(0.86, 0.72, 0.76),
		"walls": [Color(0.8, 0.72, 0.58), Color(0.74, 0.66, 0.53), Color(0.84, 0.77, 0.63), Color(0.7, 0.62, 0.5)],
		"styles": [0.75], "floors": [5, 6], "roof": "mansard", "roof_col": Color(0.4, 0.45, 0.53),
		"chimneys": true, "bays": "", "railings": false, "balconies": true, "trees": "chestnut", "landmark": "eiffel",
		"rain": false, "smoke": false, "puddles": 0.18, "seed": 1925},
}

func build(length_units: float, look_name := "london") -> void:
	look = LOOKS[look_name]
	rng.seed = look.seed
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
	for i in 4:
		sky_mat.set_shader_parameter(["top_col", "mid_col", "low_col", "hor_col"][i], look.sky[i])
	sky_mat.set_shader_parameter("sun_col", look.sun)
	sky_mat.set_shader_parameter("cloud_col", look.cloud)
	sky_mat.set_shader_parameter("cover", look.cover)
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
	env.fog_light_color = look.fog
	env.fog_light_energy = 1.0
	env.fog_density = look.fog_d
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
	sun.light_color = look.sun
	sun.light_energy = look.sun_e
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 70.0
	sun.directional_shadow_split_1 = 0.25
	sun.shadow_blur = 1.4
	sun.shadow_bias = 0.06
	sun.shadow_normal_bias = 1.2
	add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, look.sun_dir, Vector3.UP)
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
	var road_mat := _mat("res://shaders/cobble.gdshader", {"half_w": ROAD_HW, "puddles": look.puddles})
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

## a mansard roof (Paris): steep lower slopes and a low top, in zinc
func _mansard() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prof := [Vector2(-0.5, 0), Vector2(-0.36, 0.82), Vector2(-0.2, 1.0), Vector2(0.2, 1.0), Vector2(0.36, 0.82), Vector2(0.5, 0)]
	for k in prof.size() - 1:
		var a: Vector2 = prof[k]
		var b: Vector2 = prof[k + 1]
		var q := [Vector3(a.x, a.y, -0.5), Vector3(b.x, b.y, -0.5), Vector3(b.x, b.y, 0.5), Vector3(a.x, a.y, 0.5)]
		for tri in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]:
			var n: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
			for v in tri:
				st.set_normal(n)
				st.add_vertex(v)
	# the gable ends
	for zz in [-0.5, 0.5]:
		var n := Vector3(0, 0, signf(zz))
		for k in range(1, prof.size() - 1):
			var tri := [Vector3(prof[0].x, prof[0].y, zz), Vector3(prof[k].x, prof[k].y, zz), Vector3(prof[k + 1].x, prof[k + 1].y, zz)]
			if zz < 0.0:
				tri = [tri[0], tri[2], tri[1]]
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
	var balconies := []
	var palette: Array = look.walls
	var styles: Array = look.styles
	var fl: Array = look.floors
	for s in [-1.0, 1.0]:
		var z := z_start
		var since_gap := 0.0
		var col: Color = palette[0]
		while z > z_end:
			# now and then a side street opens between the terraces
			if since_gap > 70.0 and rng.randf() < 0.07:
				z -= 8.0 + rng.randf() * 4.0
				since_gap = 0.0
				continue
			var w: float = [4.5, 5.0, 5.0, 5.5, 6.0][rng.randi() % 5]
			if look.roof == "mansard":
				w *= 2.0
			var floors: int = fl[0] + rng.randi_range(0, fl[1] - fl[0])
			var h := floors * 2.7 + 0.7
			var cz := z - w * 0.5
			var cx: float = s * (FRONT + DEPTH * 0.5)
			var style: float = styles[rng.randi() % styles.size()]
			# neighbours are often built as a row and share their colour
			if rng.randf() < 0.65:
				col = palette[rng.randi() % palette.size()]
			walls.append(_box_xf(Vector3(cx, WALK_Y + h * 0.5, cz), Vector3(DEPTH, h, w)))
			wall_cd.append(Color(col.r, col.g, col.b, style))
			if look.bays == "ground" and rng.randf() < 0.3 and w >= 5.0:
				# a two-storey bay window in stucco (London)
				walls.append(_box_xf(Vector3(s * (FRONT - 0.35), WALK_Y + 2.7, cz), Vector3(0.7, 5.4, 2.6)))
				wall_cd.append(Color(0.84, 0.8, 0.72, 0.5))
			elif look.bays == "upper" and rng.randf() < 0.6 and floors >= 3:
				# a wooden bay jutting out over the street from the upper floors (Istanbul)
				var wood: Color = [Color(0.46, 0.3, 0.2), Color(0.62, 0.5, 0.36), Color(0.36, 0.3, 0.28)][rng.randi() % 3]
				var bh := (floors - 1) * 2.7
				walls.append(_box_xf(Vector3(s * (FRONT - 0.5), WALK_Y + 2.7 + bh * 0.5, cz), Vector3(1.0, bh, w * 0.7)))
				wall_cd.append(Color(wood.r, wood.g, wood.b, 0.25))
			if look.balconies:
				# wrought-iron balconies along the second and the top floor (Paris)
				for f in [2, floors - 1]:
					balconies.append(Transform3D(Basis.from_scale(Vector3(1, 0.95, w)), Vector3(s * (FRONT - 0.45), WALK_Y + f * 2.7 + 0.47, cz)))
					cornices.append(_box_xf(Vector3(s * (FRONT - 0.25), WALK_Y + f * 2.7 + 0.03, cz), Vector3(0.55, 0.08, w)))
			# the cornice along the top of the front
			cornices.append(_box_xf(Vector3(s * (FRONT - 0.12), WALK_Y + h - 0.12, cz), Vector3(0.36, 0.26, w + 0.02)))
			# the roof, its ridge along the street
			var rh := (2.8 + rng.randf() * 0.6) if look.roof == "mansard" else (1.6 + rng.randf() * 0.9 if look.chimneys else 1.1 + rng.randf() * 0.6)
			roofs.append(Transform3D(Basis.from_scale(Vector3(DEPTH * 0.92, rh, w)), Vector3(cx + s * 0.2, WALK_Y + h, cz)))
			if look.chimneys:
				# chimney stacks on the party wall, with clay pots
				var sh := 1.4 + rng.randf() * 1.2
				for dx in [-2.2, 2.2]:
					var sc := Vector3(cx + dx, WALK_Y + h + rh * 0.45 + sh * 0.5, z)
					stacks.append(_box_xf(sc, Vector3(0.8, sh + rh * 0.9, 1.5)))
					stack_cd.append(Color(col.r * 0.9, col.g * 0.9, col.b * 0.9, -1.0))
					for k in 3:
						pots.append(Transform3D(Basis.from_scale(Vector3(0.22, 0.5, 0.22)), sc + Vector3(0, sh * 0.5 + rh * 0.45 + 0.25, -0.45 + k * 0.45)))
			if look.railings:
				# iron railings in front of the basement areas
				rails.append(Transform3D(Basis.from_scale(Vector3(1, 1.0, w)), Vector3(s * (FRONT - 0.9), WALK_Y + 0.5, cz)))
			z -= w
			since_gap += w
	var wall_mat := _mat("res://shaders/facade.gdshader")
	_multi(BoxMesh.new(), wall_mat, walls, wall_cd)
	if stacks.size() > 0:
		_multi(BoxMesh.new(), wall_mat, stacks, stack_cd)
		var pot := CylinderMesh.new()
		pot.top_radius = 0.42; pot.bottom_radius = 0.5; pot.height = 1.0; pot.radial_segments = 8
		_multi(pot, _std(Color(0.62, 0.34, 0.24), 0.75), pots, [], false)
	_multi(_mansard() if look.roof == "mansard" else _prism(), _mat("res://shaders/roof.gdshader", {"slate": look.roof_col}), roofs)
	_multi(BoxMesh.new(), _std(Color(0.8, 0.77, 0.7), 0.6), cornices)
	var rail_mesh := QuadMesh.new()
	rail_mesh.orientation = PlaneMesh.FACE_X
	var rail_mat := ShaderMaterial.new()
	rail_mat.shader = _railing_shader()
	if rails.size() > 0:
		_multi(rail_mesh, rail_mat, rails, [], false)
	if balconies.size() > 0:
		_multi(rail_mesh, rail_mat, balconies, [], false)

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
			# a tree halfway between every other pair of lamps: London planes, Paris chestnuts, Istanbul's tall cypresses
			if n % 2 == 1:
				var tz := z + 6.5
				var tx: float = s * (ROAD_HW + 1.25)
				if look.trees == "cypress":
					trunks.append(Transform3D(Basis.from_scale(Vector3(0.24, 1.6, 0.24)), Vector3(tx, WALK_Y + 0.8, tz)))
					var th := 6.5 + rng.randf() * 3.0
					crowns.append(Transform3D(Basis.from_scale(Vector3(0.85, th * 0.5, 0.85)), Vector3(tx, WALK_Y + 1.2 + th * 0.5, tz)))
					crowns.append(Transform3D(Basis.from_scale(Vector3(0.6, th * 0.32, 0.6)), Vector3(tx, WALK_Y + 1.2 + th * 0.82, tz)))
				else:
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
	big_halos = _multi(quad, _mat("res://shaders/halo.gdshader", {"tint": Color(1.0, 0.66, 0.36), "energy": 0.16, "fade": 0.01}), halos_big, [], false)
	_multi(_pool_mesh(), _mat_pool(), pools, [], false)
	var bark := _std(Color(0.42, 0.4, 0.33), 0.85)
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.35; trunk.bottom_radius = 0.5; trunk.height = 1.0; trunk.radial_segments = 8
	_multi(trunk, bark, trunks)
	var crown := SphereMesh.new()
	crown.radial_segments = 14; crown.rings = 8
	var leaves := ShaderMaterial.new()
	leaves.shader = _leaves_shader()
	var greens: Array = {"plane": [Color(0.16, 0.22, 0.09), Color(0.36, 0.42, 0.16)], "chestnut": [Color(0.2, 0.3, 0.1), Color(0.44, 0.52, 0.2)],
		"cypress": [Color(0.06, 0.12, 0.07), Color(0.16, 0.24, 0.12)]}[look.trees]
	leaves.set_shader_parameter("dark", greens[0])
	leaves.set_shader_parameter("light", greens[1])
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
uniform vec3 dark : source_color = vec3(0.16, 0.22, 0.09);
uniform vec3 light : source_color = vec3(0.36, 0.42, 0.16);
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
	ALBEDO = mix(dark, light, n);
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
	match look.landmark:
		"mosque":
			_mosque()
		"eiffel":
			_eiffel()
		_:
			_bigben()
	_roofscape()

func _sil_h(depth: float, ribs := 0.6) -> ShaderMaterial:
	var m := _sil(depth, ribs)
	m.set_shader_parameter("haze_col", look.haze)
	return m

## a great mosque on the skyline: a square hall, a big dome on semidomes, and four slender minarets
func _mosque() -> void:
	var mos := Node3D.new()
	mos.position = Vector3(-4.0, ROAD_Y, 0.0)
	far.add_child(mos)
	var m := _sil_h(0.34, 0.0)
	var dome := SphereMesh.new()
	dome.radial_segments = 32; dome.rings = 16; dome.is_hemisphere = true
	_part(mos, BoxMesh.new(), m, Vector3(0, 9, 0), Vector3(40, 18, 34))
	_part(mos, CylinderMesh.new(), m, Vector3(0, 21, 0), Vector3(22, 6, 22))
	_part(mos, dome, m, Vector3(0, 24, 0), Vector3(14, 13, 14))
	for d in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		_part(mos, dome, m, Vector3(0, 18, 0) + d * 12.0, Vector3(9, 7, 9))
	for c in [Vector3(-14, 0, -12), Vector3(14, 0, -12), Vector3(-14, 0, 12), Vector3(14, 0, 12)]:
		_part(mos, dome, m, Vector3(c.x, 18, c.z), Vector3(4, 4, 4))
	var spire := CylinderMesh.new()
	spire.top_radius = 0.02; spire.bottom_radius = 0.5; spire.height = 1.0; spire.radial_segments = 10
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.5; shaft.bottom_radius = 0.5; shaft.height = 1.0; shaft.radial_segments = 12
	for c in [Vector3(-27, 0, -20), Vector3(27, 0, -20), Vector3(-27, 0, 20), Vector3(27, 0, 20)]:
		_part(mos, shaft, m, c + Vector3(0, 30, 0), Vector3(2.2, 60, 2.2))
		for by in [36.0, 48.0]:
			_part(mos, shaft, m, c + Vector3(0, by, 0), Vector3(3.4, 1.0, 3.4))
		_part(mos, spire, m, c + Vector3(0, 66, 0), Vector3(2.4, 12, 2.4))
	# the lamps of the courtyard and the gallery of each minaret, warm in the dusk
	var glow_mat := _mat("res://shaders/halo.gdshader", {"tint": Color(1.0, 0.72, 0.45), "energy": 0.9, "fade": 0.0})
	for c in [Vector3(-27, 0, -20), Vector3(27, 0, -20)]:
		var h := MeshInstance3D.new()
		h.mesh = QuadMesh.new()
		h.material_override = glow_mat
		h.position = c + Vector3(0, 48, 2)
		h.scale = Vector3.ONE * 5.0
		mos.add_child(h)
	# a second mosque further off, and the Galata tower on the left
	var m2 := _sil_h(0.6, 0.0)
	_part(far, dome, m2, Vector3(95, ROAD_Y + 16, 110), Vector3(16, 14, 16))
	_part(far, BoxMesh.new(), m2, Vector3(95, ROAD_Y + 8, 110), Vector3(34, 16, 30))
	for sx in [-1.0, 1.0]:
		_part(far, shaft, m2, Vector3(95 + sx * 22, ROAD_Y + 26, 110), Vector3(1.8, 52, 1.8))
		_part(far, spire, m2, Vector3(95 + sx * 22, ROAD_Y + 57, 110), Vector3(2.0, 10, 2.0))
	var gal := _sil_h(0.5, 0.0)
	_part(far, shaft, gal, Vector3(-80, ROAD_Y + 22, 60), Vector3(9, 44, 9))
	_part(far, spire, gal, Vector3(-80, ROAD_Y + 50, 60), Vector3(11, 12, 11))

## the Eiffel Tower at the end of the street: four legs in iron lattice meeting in a spire, its platforms lit
func _eiffel() -> void:
	var tw := Node3D.new()
	tw.position = Vector3(2.0, ROAD_Y, -90.0)
	tw.scale = Vector3.ONE * 0.72
	far.add_child(tw)
	var iron := _sil_h(0.3, 0.0)
	iron.set_shader_parameter("lattice", 1.0)
	iron.set_shader_parameter("near_col", Color(0.24, 0.2, 0.22))
	var solid := _sil_h(0.3, 0.0)
	solid.set_shader_parameter("near_col", Color(0.24, 0.2, 0.22))
	# each leg: a tapering box leaning in toward the middle
	var leg := CylinderMesh.new()
	leg.top_radius = 0.35; leg.bottom_radius = 0.5; leg.height = 1.0; leg.radial_segments = 4
	var hgt := [0.0, 40.0, 80.0, 150.0]
	var half := [34.0, 17.0, 7.0, 0.6]
	var thick := [11.0, 6.0, 4.0, 2.5]
	for k in 3:
		for c in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			var a := Vector3(c.x * half[k], hgt[k], c.y * half[k])
			var b := Vector3(c.x * half[k + 1], hgt[k + 1], c.y * half[k + 1])
			if k == 2:
				b = Vector3(c.x * half[3] * 2.0, hgt[3] - 10.0, c.y * half[3] * 2.0)
			var p := MeshInstance3D.new()
			p.mesh = leg
			p.material_override = iron
			var dir := (b - a)
			p.position = (a + b) * 0.5
			p.basis = Basis.looking_at(dir.normalized(), Vector3.FORWARD if absf(dir.normalized().y) > 0.99 else Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)
			p.basis = p.basis.scaled_local(Vector3(thick[k], dir.length(), thick[k]))
			p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			tw.add_child(p)
	# the arches under the first platform, and the platforms
	_part(tw, BoxMesh.new(), iron, Vector3(0, 40, 0), Vector3(38, 2.2, 38))
	_part(tw, BoxMesh.new(), iron, Vector3(0, 80, 0), Vector3(19, 1.6, 19))
	_part(tw, BoxMesh.new(), solid, Vector3(0, 140, 0), Vector3(5, 3, 5))
	var spire := CylinderMesh.new()
	spire.top_radius = 0.05; spire.bottom_radius = 0.5; spire.height = 1.0; spire.radial_segments = 6
	_part(tw, spire, solid, Vector3(0, 152, 0), Vector3(2.6, 20, 2.6))
	var arch := TorusMesh.new()
	arch.inner_radius = 0.86; arch.outer_radius = 1.0; arch.rings = 32; arch.ring_segments = 4
	for r in [0.0, PI * 0.5]:
		var a := MeshInstance3D.new()
		a.mesh = arch
		a.material_override = solid
		a.position = Vector3(0, 22, 0)
		a.basis = Basis(Vector3.UP, r) * Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(26, 1, 20))
		tw.add_child(a)
	# lights on the platforms and the beacon at the top
	var glow_mat := _mat("res://shaders/halo.gdshader", {"tint": Color(1.0, 0.78, 0.48), "energy": 0.7, "fade": 0.0})
	for y in [40.0, 80.0, 140.0]:
		var h := MeshInstance3D.new()
		h.mesh = QuadMesh.new()
		h.material_override = glow_mat
		h.position = Vector3(0, y, 14)
		h.scale = Vector3(40, 6, 1) if y < 100 else Vector3(10, 10, 1)
		tw.add_child(h)
	var bm := _mat("res://shaders/halo.gdshader", {"tint": Color(1.0, 0.9, 0.7), "energy": 1.6, "fade": 0.0})
	var beacon := MeshInstance3D.new()
	beacon.mesh = QuadMesh.new()
	beacon.material_override = bm
	beacon.position = Vector3(0, 162, 4)
	beacon.scale = Vector3.ONE * 9.0
	tw.add_child(beacon)
	# the dome of the Invalides on the right
	var dome := SphereMesh.new()
	dome.radial_segments = 24; dome.rings = 12; dome.is_hemisphere = true
	var gold := _sil_h(0.5, 0.0)
	_part(far, CylinderMesh.new(), gold, Vector3(90, ROAD_Y + 18, 90), Vector3(20, 14, 20))
	_part(far, dome, gold, Vector3(90, ROAD_Y + 25, 90), Vector3(11, 14, 11))
	_part(far, spire, gold, Vector3(90, ROAD_Y + 44, 90), Vector3(1.6, 10, 1.6))

func _bigben() -> void:
	# the Elizabeth Tower: the shaft, the belfry with its four lit clock faces, and the spire
	var tower := Node3D.new()
	tower.position = Vector3(3.0, ROAD_Y, 0.0)
	far.add_child(tower)
	var tw := _sil_h(0.34, 1.4)
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
	var pal := _sil_h(0.46, 1.8)
	_part(far, BoxMesh.new(), pal, Vector3(-30, ROAD_Y + 11, 12), Vector3(48, 22, 14))
	for i in 10:
		_part(far, spire, pal, Vector3(-52 + i * 5.0, ROAD_Y + 25, 12), Vector3(1.6, 6, 1.6), PI * 0.25)
	var vic := _sil_h(0.6, 1.2)
	_part(far, BoxMesh.new(), vic, Vector3(-70, ROAD_Y + 30, 40), Vector3(12, 60, 12))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_part(far, spire, vic, Vector3(-70 + sx * 5.2, ROAD_Y + 63, 40 + sz * 5.2), Vector3(1.8, 8, 1.8), PI * 0.25)
	# St Paul's dome far to the right
	var sp := _sil_h(0.68, 0.0)
	var dome := SphereMesh.new()
	dome.radial_segments = 24; dome.rings = 12; dome.is_hemisphere = true
	_part(far, CylinderMesh.new(), sp, Vector3(110, ROAD_Y + 26, 120), Vector3(30, 18, 30))
	_part(far, dome, sp, Vector3(110, ROAD_Y + 35, 120), Vector3(17, 17, 17))
	_part(far, CylinderMesh.new(), sp, Vector3(110, ROAD_Y + 54, 120), Vector3(3, 6, 3))

func _roofscape() -> void:
	# the roofs of the rest of the city, layer behind layer
	for layer in 3:
		var m := _sil_h(0.5 + layer * 0.14, 0.0)
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
	rain.visible = look.rain
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
	smoke.visible = look.smoke
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
