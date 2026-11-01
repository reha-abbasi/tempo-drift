extends RefCounted
## The 24 cities, one scene each (scenes/cities/<map>_<i>.tscn), set from the web game's look for that episode
## (data/looks.json: the era's look with the episode's on top, as the web game merges them):
##   sky in its four colours, the sun where it sits, stars and moon; haze in the fog colour; the sun's and the sky's
##   light; four street sections in the city's style (scenes/cities/<map>_<i>/section_<k>.tscn) with its road,
##   lamps or palms, open sea where a side is left open; the far skyline; the landmark; rain; the era's traffic.
## Every part is an ordinary node or scene: open a city and change it in the editor.

const LEN := 48.0
const FRONT := 7.2
## the web game's fog is exp2 per unit; Godot's is exp per metre: the same half-haze distance
const FOG_K := 0.83 / 1.4
const ERA_FOG_D := {"old": 0.0075, "sunset": 0.0068, "rain": 0.012}
const KINDS := {"old": ["oldcar", "dbus", "biplane", "barrier"], "sunset": ["taxi", "truck", "bus", "hovercab", "barrier"],
	"rain": ["taxi", "truck", "bus", "drone", "barrier"]}
## tower styles grow with the city's height; street fronts only a little
const TOWER_STYLES := ["glass", "cyber", "sg"]

var widths := {}


func build(_host: Node) -> void:
	widths = JSON.parse_string(FileAccess.get_file_as_string("res://data/styles.json"))
	var looks: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/looks.json"))
	for map in ["old", "sunset", "rain"]:
		var th: Dictionary = looks[map].theme
		for i in 8:
			var ep: Dictionary = looks[map].episodes[i]
			var L: Dictionary = (th.look as Dictionary).duplicate()
			L.merge(ep.look, true)
			city(map, i, ep.name, th, L)


static func hex(v) -> Color:
	var n := int(v)
	return Color8((n >> 16) & 255, (n >> 8) & 255, n & 255)


func city(map: String, i: int, name: String, th: Dictionary, L: Dictionary) -> void:
	var id := "%s_%d" % [map, i]
	var dir := "res://scenes/cities/" + id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var root := Node3D.new()
	root.name = name.replace(" ", "").replace("í", "i")
	root.set_script(load("res://scripts/city.gd"))
	root.display_name = name
	var sy: float = L.get("sunY", 0.07)
	var night := clampf((0.06 - sy) / 0.14, 0.15, 1.0) * clampf(float(L.get("glow", 1.0)) / 1.4, 0.6, 1.5)
	root.night = clampf(night, 0.1, 1.0)
	root.accent_a = hex(L.get("a", 0xff3fb4))
	root.accent_b = hex(L.get("b", 0x2ef2ff))
	if L.has("busCol"):
		root.bus_color = hex(L.busCol)
	var cols: Array[Color] = []
	for c in L.get("carCols", [0x1a1c22, 0x2a2a30, 0x3a1a1a]):
		cols.append(hex(c))
	root.car_colors = cols
	var traffic := {}
	for k in KINDS[map]:
		traffic[k] = load("res://scenes/traffic/%s.tscn" % k)
	root.traffic = traffic

	root.add_child(environment(map, th, L))
	root.add_child(sun(th, L))
	var street := Node3D.new()
	street.name = "Street"
	root.add_child(street)

	var sections: Array[PackedScene] = []
	for k in 4:
		var path := "%s/section_%d.tscn" % [dir, k]
		Kit.save(section(L, hash(id) + k * 7919, k), path)
		sections.append(load(path))
	root.sections = sections

	var horizon := Node3D.new()
	horizon.name = "Horizon"
	root.add_child(horizon)
	if L.get("towers", 0) is Array:
		horizon.add_child(skyline(L, hash(id)))
	var lm := "res://scenes/landmarks/%s.tscn" % L.bg
	if ResourceLoader.exists(lm):
		Kit.instance(horizon, lm, "Landmark", Vector3(0, 0, -340))
	for d in L.get("deco", []):
		var dp := "res://scenes/deco/%s.tscn" % d
		if d != "palms" and d != "lanterns" and ResourceLoader.exists(dp):
			Kit.instance(horizon, dp, String(d).capitalize().replace(" ", ""))
	if L.get("drizzle", false) or map == "rain":
		horizon.add_child(rain(L))
	Kit.save(root, "res://scenes/cities/%s.tscn" % id)


func environment(map: String, th: Dictionary, L: Dictionary) -> WorldEnvironment:
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://materials/shaders/sky.gdshader")
	var s: Array = L.sky
	sky_mat.set_shader_parameter("top", hex(s[0]))
	sky_mat.set_shader_parameter("mid", hex(s[1]))
	sky_mat.set_shader_parameter("hor", hex(s[2]))
	sky_mat.set_shader_parameter("sun_color", hex(s[3]))
	var sy: float = L.get("sunY", 0.07)
	sky_mat.set_shader_parameter("sun_dir", Vector3(0.12, sy, -1.0).normalized())
	if L.has("sea"):
		sky_mat.set_shader_parameter("sea", 1.0)
		sky_mat.set_shader_parameter("low", hex(L.sea))
	sky_mat.set_shader_parameter("stars", float(L.get("stars", 0.0)))
	if L.has("moon"):
		var mo: Array = L.moon
		sky_mat.set_shader_parameter("moon_dir", Vector3(mo[0], mo[1], -1.0).normalized())
		sky_mat.set_shader_parameter("moon_r", float(mo[2]))
		if float(mo[3]) > 0.0:
			sky_mat.set_shader_parameter("moon_cut", Vector3(mo[0] + mo[2] * mo[3], mo[1] + mo[2] * mo[3] * 0.35, -1.0).normalized())
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	var hm: Array = L.get("hemi", th.hemi)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# three.js lights give albedo x intensity / pi; Godot gives albedo x energy
	env.ambient_light_color = hex(hm[0]).lerp(hex(hm[1]), 0.4)
	env.ambient_light_energy = float(hm[2]) * 1.6 / PI
	# three.js ACES: x exposure / 0.6 and no white scaling; Godot's: x 1.8, divided by the mapped white
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = float(L.get("exposure", th.exposure)) * 1.12 / (0.6 * 1.8)
	env.tonemap_white = 16.0
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.96
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = true
	env.fog_light_color = hex(L.fog)
	env.fog_density = float(L.get("fogD", ERA_FOG_D[map])) * FOG_K
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	return we


func sun(th: Dictionary, L: Dictionary) -> DirectionalLight3D:
	## as in the web game: the light comes from the sun when it is up, otherwise from high behind the left shoulder
	var sy: float = L.get("sunY", 0.07)
	var from := Vector3(0.12, sy, -1.0).normalized() if sy > 0.02 else Vector3(-0.3, 0.8, 0.4).normalized()
	var sn: Array = L.get("sun", th.sun)
	var l := DirectionalLight3D.new()
	l.name = "Sun"
	l.light_color = hex(sn[0])
	l.light_energy = float(sn[1]) * 1.7 / PI
	l.shadow_enabled = true
	l.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	l.directional_shadow_max_distance = 60.0
	l.transform = Transform3D(Basis.looking_at(-from, Vector3.UP if absf(from.y) < 0.99 else Vector3.FORWARD), Vector3(0, 30, 0))
	return l


func section(L: Dictionary, seed_: int, k: int) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	var root := Node3D.new()
	root.name = "Section%d" % k
	var road: String = L.get("road", "asphalt")
	if L.get("wet", false):
		road = "wet"
	var mi := MeshInstance3D.new()
	mi.name = "Road"
	mi.mesh = load("res://assets/meshes/props/street_%s.res" % road)
	mi.position.y = -0.04
	root.add_child(mi)
	var cityH: Array = L.get("cityH", [1, 1])
	var style: String = L.fac
	for side: int in [-1, 1]:
		var kside: float = cityH[0 if side < 0 else 1]
		var row := Node3D.new()
		row.name = "Left" if side < 0 else "Right"
		root.add_child(row)
		if kside <= 0.0:
			var sea := Kit.instance(row, "res://scenes/props/sea_front.tscn", "SeaFront", Vector3(side * FRONT, 0, 0), 0.0 if side > 0 else PI)
			if L.has("sea"):
				sea.sea_color = hex(L.sea)
			continue
		var ys: float
		if style in TOWER_STYLES:
			ys = clampf(kside / 1.2, 0.7, 1.25)
		else:
			ys = clampf(0.8 + 0.35 * (kside - 0.4), 0.8, 1.15)
		_fill(row, style, side, ys, rng)
		row.add_child(_shadow_blocks(row))
	# lamps, or palms instead of them, staggered on the two pavements
	var palms: bool = L.get("palms", false)
	var lamp: String = L.get("lamp", "neon" if L.get("wet", false) else "modern")
	for j in 4:
		var side := -1 if j % 2 == 0 else 1
		var z := -6.0 - j * 12.0
		if palms:
			var p := Kit.instance(root, "res://scenes/props/palm.tscn", "Palm%d" % j, Vector3(side * 6.3, 0.16, z), rng.randf() * TAU, rng.randf_range(0.85, 1.05))
			p.rotation.z = -side * 0.12
		elif lamp == "gas":
			Kit.instance(root, "res://scenes/props/gas_lamp.tscn", "GasLamp%d" % j, Vector3(side * 5.67, 0.16, z), 0.0, 1.25)
		elif lamp == "modern":
			Kit.instance(root, "res://scenes/props/modern_lamp.tscn", "Streetlight%d" % j, Vector3(side * 5.67, 0.16, z), -side * PI / 2)
		elif lamp == "neon":
			Kit.instance(root, "res://scenes/props/neon_pole.tscn", "NeonPole%d" % j, Vector3(side * 5.67, 0.16, z))
	if "lanterns" in L.get("deco", []):
		for j in 3:
			Kit.instance(root, "res://scenes/props/lanterns.tscn", "Lanterns%d" % j, Vector3(0, 11.6, -8.0 - j * 16.0))
	return root


func _fill(row: Node3D, style: String, side: int, ys: float, rng: RandomNumberGenerator) -> void:
	## pick buildings until the 48 m are filled, then stretch them a little to meet the next section exactly
	var names: Array = (widths[style] as Dictionary).keys()
	var best := []
	var best_err := INF
	for attempt in 40:
		var picks := []
		var total := 0.0
		var last := ""
		while total < LEN - 4.0:
			var n: String = names[rng.randi_range(0, names.size() - 1)]
			if n == last and names.size() > 1:
				continue
			picks.append(n)
			total += float(widths[style][n])
			last = n
		var err := absf(total / LEN - 1.0)
		if err < best_err:
			best_err = err
			best = picks
		if err < 0.04:
			break
	var total := 0.0
	for n in best:
		total += float(widths[style][n])
	var stretch := LEN / total
	var z := 0.0
	for n in best:
		var w: float = widths[style][n] * stretch
		var b := Kit.instance(row, "res://scenes/buildings/%s/%s.tscn" % [style, n], "", Vector3(side * FRONT, 0, -(z + w / 2)), -side * PI / 2)
		b.scale = Vector3(stretch, ys, 1.0)
		z += w


func _shadow_blocks(row: Node3D) -> MeshInstance3D:
	## one plain block per building, drawn only into the sun's shadow map: the street's shadows for one draw call
	var k := MeshKit.new()
	var m := StandardMaterial3D.new()
	k.use("block", m)
	for b in row.get_children():
		var mi := b.get_node_or_null("Building") as MeshInstance3D
		if mi == null:
			continue
		var box: AABB = (b as Node3D).transform * mi.get_aabb()
		k.box("block", box.get_center(), box.size)
	var out := MeshInstance3D.new()
	out.name = "ShadowBlocks"
	out.mesh = k.bake()
	out.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
	return out


func skyline(L: Dictionary, seed_: int) -> MeshInstance3D:
	var tw: Array = L.towers
	var k := MeshKit.new()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://materials/shaders/skyline.gdshader")
	mat.set_shader_parameter("color", hex(tw[1]))
	mat.set_shader_parameter("haze", hex(L.fog))
	mat.set_shader_parameter("window_color", hex(L.get("b", 0xffd28c)) if L.get("wet", false) else Color(1.0, 0.84, 0.58))
	mat.set_shader_parameter("lit", 0.12 + 0.25 * clampf((0.06 - float(L.get("sunY", 0.07))) / 0.16, 0.0, 1.0))
	k.use("tower", mat)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_
	for i in 70:
		var x := rng.randf_range(-320, 320)
		if absf(x) < 14:
			continue
		var w := rng.randf_range(12, 34)
		var h := rng.randf_range(30, 110) * float(tw[0]) * (0.6 + 0.4 * clampf(absf(x) / 120.0, 0.0, 1.0))
		var z := -rng.randf_range(380, 470)
		k.box("tower", Vector3(x, h / 2 - 6, z), Vector3(w, h, rng.randf_range(10, 24)), ["-y"])
	var mi := MeshInstance3D.new()
	mi.name = "Skyline"
	mi.mesh = k.bake()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func rain(L: Dictionary) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = "Rain"
	p.amount = int(700 * float(L.get("rain", 1.0)))
	p.lifetime = 0.7
	p.preprocess = 1.0
	p.visibility_aabb = AABB(Vector3(-16, -4, -50), Vector3(32, 26, 60))
	p.position = Vector3(0, 0, 0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(14, 2, 22)
	pm.emission_shape_offset = Vector3(0, 18, -30)
	pm.direction = Vector3(0, -1, 0.15)
	pm.spread = 2.0
	pm.initial_velocity_min = 28.0
	pm.initial_velocity_max = 34.0
	pm.gravity = Vector3.ZERO
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.018, 0.8)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	var rc := hex(L.get("rainCol", 0xd2b8f0))
	rc.a = 0.22
	m.albedo_color = rc
	m.disable_fog = true
	q.material = m
	p.draw_pass_1 = q
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p
