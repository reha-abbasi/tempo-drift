extends Node
## Light & sky: each open city gets a strong mood of its own through light alone. London 1890 is a warm gaslight evening in coal haze with a low golden
## sun raking down the street; Rio is a golden-hour sunset over the sea; Berlin 2075 is a blue-violet neon night with
## big coloured bloom and a shining wet road. When a run starts it swaps the city's sky, sun, ambient light, haze,
## tonemapping, bloom and colour grade for its own, brightens the street lamps and makes the road shine. Other
## cities stay as they are. The run makes one after laying out the city; everything it changes is its own copy.

const SKY := preload("res://materials/gfx_light_sky.gdshader")
## the glossier wet road, in place of road_wet
const ROAD := preload("res://materials/gfx_light_road.gdshader")

## each city's look, by "map_i": the sun (height and bearing in degrees, 0 = straight down the street, + to the
## right, and its light), the sky shader's colours, the environment's settings, the colour grade (a tint added to
## the shadows and one multiplied into the highlights), the lamps (energy, reach and halo, as multiples), the road
## materials made glossier (a roughness, or the wet road's shine), how lit the windows are (city_night), for a wet
## street how bright its mirrored neon is (mirror), and the garage's spotlight on the car (colour, energy). A sun
## "disc" (height, bearing) puts the sun's disc in the sky somewhere else than where its light comes from
const LOOKS := {
	"old_0": {
		"night": 0.7,
		"sun": {"elev": 8.0, "az": -55.0, "light": {"light_color": Color(1.0, 0.64, 0.34), "light_energy": 2.8,
			"shadow_opacity": 0.92, "shadow_blur": 1.4, "directional_shadow_max_distance": 90.0}},
		"sky": {"zenith": Color(0.14, 0.16, 0.27), "upper": Color(0.42, 0.34, 0.36), "horizon": Color(0.95, 0.58, 0.32),
			"haze": Color(0.5, 0.4, 0.33), "haze_amount": 0.6, "ground": Color(0.22, 0.17, 0.13),
			"sun_color": Color(1.0, 0.62, 0.3), "sun_size": 0.035, "sun_disc": 3.0, "sun_glow": 0.5,
			"horizon_glow": 0.5, "glow_width": 5.0, "cloud_lit": Color(0.95, 0.55, 0.32),
			"cloud_shade": Color(0.27, 0.23, 0.26), "clouds": 0.5, "cloud_scale": 1.3},
		"env": {"ambient_light_source": Environment.AMBIENT_SOURCE_COLOR, "ambient_light_color": Color(0.42, 0.47, 0.64),
			"ambient_light_energy": 0.4, "tonemap_mode": Environment.TONE_MAPPER_ACES, "tonemap_exposure": 1.0,
			"tonemap_white": 8.0, "glow_intensity": 0.75, "glow_strength": 1.0, "glow_bloom": 0.03,
			"glow_hdr_threshold": 0.9, "glow_blend_mode": Environment.GLOW_BLEND_MODE_ADDITIVE,
			"fog_light_color": Color(0.42, 0.36, 0.32), "fog_density": 0.006, "fog_sun_scatter": 0.18,
			"fog_aerial_perspective": 0.2, "fog_sky_affect": 0.5, "fog_height": 3.0, "fog_height_density": 0.03,
			"adjustment_enabled": true, "adjustment_contrast": 1.12, "adjustment_saturation": 1.08},
		"grade": {"shadows": Color(0.0, 0.03, 0.07), "highlights": Color(1.06, 0.98, 0.86)},
		"lamps": {"gas_lamp": [3.0, 1.6, 1.8]},
		"gloss": {"cobblestone": 0.7},
		"showroom": [Color(1.0, 0.8, 0.58), 5.0],
	},
	"sunset_1": {
		"night": 0.3,
		"sun": {"elev": 9.0, "az": 26.0, "disc": [2.6, 2.5], "light": {"light_color": Color(1.0, 0.64, 0.32),
			"light_energy": 2.6, "shadow_opacity": 0.9, "shadow_blur": 1.2, "directional_shadow_max_distance": 90.0}},
		"sky": {"zenith": Color(0.1, 0.2, 0.5), "upper": Color(0.36, 0.3, 0.62), "horizon": Color(1.0, 0.6, 0.22),
			"haze": Color(1.0, 0.66, 0.38), "haze_amount": 0.2, "ground": Color(0.3, 0.22, 0.2),
			"sun_color": Color(1.0, 0.7, 0.32), "sun_size": 0.04, "sun_disc": 5.0, "sun_glow": 0.22,
			"horizon_glow": 0.55, "glow_width": 9.0, "cloud_lit": Color(1.0, 0.62, 0.36),
			"cloud_shade": Color(0.36, 0.3, 0.52), "clouds": 0.42, "cloud_scale": 1.0, "sea": 1.0,
			"sea_far": Color(1.0, 0.62, 0.32), "sea_deep": Color(0.06, 0.14, 0.3)},
		"env": {"ambient_light_source": Environment.AMBIENT_SOURCE_COLOR, "ambient_light_color": Color(0.6, 0.52, 0.6),
			"ambient_light_energy": 0.44, "tonemap_mode": Environment.TONE_MAPPER_ACES, "tonemap_exposure": 1.0,
			"tonemap_white": 8.0, "glow_intensity": 0.7, "glow_strength": 1.0, "glow_bloom": 0.03,
			"glow_hdr_threshold": 0.9, "glow_blend_mode": Environment.GLOW_BLEND_MODE_ADDITIVE,
			"fog_light_color": Color(0.95, 0.66, 0.46), "fog_density": 0.0012, "fog_sun_scatter": 0.15,
			"fog_aerial_perspective": 0.3, "fog_sky_affect": 0.1,
			"adjustment_enabled": true, "adjustment_contrast": 1.12, "adjustment_saturation": 1.12},
		"grade": {"shadows": Color(0.0, 0.01, 0.05), "highlights": Color(1.05, 0.98, 0.86)},
		"lamps": {},
		"gloss": {},
		"showroom": [Color(1.0, 0.85, 0.65), 4.0],
	},
	"rain_5": {
		"night": 1.0,
		"sun": {"elev": 32.0, "az": 150.0, "light": {"light_color": Color(0.5, 0.58, 1.0), "light_energy": 0.4,
			"shadow_opacity": 0.8, "directional_shadow_max_distance": 60.0}},
		"sky": {"zenith": Color(0.015, 0.015, 0.06), "upper": Color(0.07, 0.05, 0.19), "horizon": Color(0.34, 0.1, 0.4),
			"haze": Color(0.2, 0.08, 0.28), "haze_amount": 0.6, "ground": Color(0.04, 0.03, 0.08),
			"sun_color": Color(0.5, 0.55, 0.9), "sun_size": 0.0, "sun_disc": 0.0, "sun_glow": 0.0,
			"horizon_glow": 0.0, "cloud_lit": Color(0.42, 0.14, 0.42), "cloud_shade": Color(0.07, 0.05, 0.16),
			"clouds": 0.55, "cloud_scale": 1.6, "city_glow": Color(0.3, 0.08, 0.32)},
		"env": {"ambient_light_source": Environment.AMBIENT_SOURCE_COLOR, "ambient_light_color": Color(0.24, 0.2, 0.55),
			"ambient_light_energy": 0.42, "tonemap_mode": Environment.TONE_MAPPER_ACES, "tonemap_exposure": 1.1,
			"tonemap_white": 10.0, "glow_intensity": 0.9, "glow_strength": 1.0, "glow_bloom": 0.0,
			"glow_hdr_threshold": 1.0, "glow_blend_mode": Environment.GLOW_BLEND_MODE_ADDITIVE,
			"glow_levels/1": 0.0, "glow_levels/2": 0.0, "glow_levels/3": 0.6, "glow_levels/4": 1.0,
			"glow_levels/5": 1.0, "glow_levels/6": 0.6, "glow_levels/7": 0.0,
			"fog_light_color": Color(0.1, 0.06, 0.2), "fog_density": 0.0085, "fog_aerial_perspective": 0.3,
			"fog_sky_affect": 0.3, "fog_height": 1.5, "fog_height_density": 0.06,
			"adjustment_enabled": true, "adjustment_contrast": 1.1, "adjustment_saturation": 1.15},
		"grade": {"shadows": Color(0.01, 0.0, 0.06), "highlights": Color(1.0, 0.97, 1.04)},
		"lamps": {"neon_pole": [2.0, 1.4, 1.0]},
		"gloss": {"asphalt_wet": 2.0},
		"mirror": 1.2,
		"showroom": [Color(0.85, 0.8, 1.0), 8.0],
	},
}
## behind the menus an era shows its first city: these get the look of the era's open city
const MENU := {"sunset_0": "sunset_1", "rain_0": "rain_5"}
## the render layer the city is also put on, for the street's reflection probe to see only it
const MIRROR_LAYER := 1 << 19
## the lamp scenes whose light and halo the looks brighten
const LAMPS := ["gas_lamp", "neon_pole", "modern_lamp"]

var _look: Dictionary
var _low := false
var _run: Node
## the garage's spotlight on the car, on while the garage shows
var _show: SpotLight3D
## the glossier copies of the road materials, by the original's path
var _glossy := {}
## the brighter copies of the lamp halos, by the original
var _halos := {}


func setup(holder: Node3D, city: City, key: String) -> Node:
	## give the city laid out under holder its new look (nothing if it has none); returns itself for the run to keep
	if not LOOKS.has(key) and Launch.mode == "menu":
		key = MENU.get(key, key)
	if not LOOKS.has(key):
		return self
	_look = LOOKS[key]
	_run = holder.get_parent()
	_low = Save.data.settings.get("fx_low", false)
	RenderingServer.global_shader_parameter_set("city_night", _look.night)
	var sun := city.get_node_or_null("Sun") as DirectionalLight3D
	var to_sun := _dir(_look.sun.elev, _look.sun.az)
	if sun:
		sun.basis = Basis.looking_at(-to_sun, Vector3.UP)
		for k in _look.sun.light:
			sun.set(k, _look.sun.light[k])
		if _low:
			sun.directional_shadow_max_distance = 60.0
	var we := city.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment:
		var disc: Array = _look.sun.get("disc", [_look.sun.elev, _look.sun.az])
		we.environment = _environment(we.environment, _dir(disc[0], disc[1]))
	_treat(holder)
	if _look.has("mirror") and not _low:
		_mirror(holder, float(_look.mirror))
	if city.street:
		city.street.child_entered_tree.connect(_treat)
	if _look.has("showroom") and _run.get("ride") is Node3D:
		_show = SpotLight3D.new()
		_show.light_color = _look.showroom[0]
		_show.light_energy = _look.showroom[1]
		_show.spot_range = 9.0
		_show.spot_angle = 38.0
		_show.spot_angle_attenuation = 0.6
		_show.position = Vector3(0.0, 6.0, 2.0)
		_show.rotation = Vector3(deg_to_rad(-72.0), 0.0, 0.0)
		_show.visible = false
		(_run.ride as Node3D).add_child(_show)
	return self


func _process(_delta: float) -> void:
	if _show:
		_show.visible = _run.garage


func _mirror(holder: Node3D, k: float) -> void:
	## the wet street's reflections: a reflection probe takes one picture of the street ahead at the start and lays it
	## over everything shiny along the whole street (the road mirrors the neon), k times as bright. It sees only
	## the city (the layer _treat puts it on), not the rings or the traffic
	var p := ReflectionProbe.new()
	p.update_mode = ReflectionProbe.UPDATE_ONCE
	p.size = Vector3(60.0, 60.0, 4000.0)
	p.position = Vector3(0.0, 0.0, -1960.0)
	p.origin_offset = Vector3(0.0, 4.0, 1900.0)
	p.max_distance = 220.0
	p.intensity = k
	p.cull_mask = MIRROR_LAYER
	holder.add_child(p)


func _dir(elev: float, az: float) -> Vector3:
	## the direction towards something elev degrees up and az degrees to the right of straight down the street
	var e := deg_to_rad(elev)
	var a := deg_to_rad(az)
	return Vector3(sin(a) * cos(e), sin(e), -cos(a) * cos(e))


func _environment(old: Environment, to_sun: Vector3) -> Environment:
	## a copy of the city's environment with the look's sky, light, haze, tonemapping, bloom and grade
	var env := old.duplicate() as Environment
	var m := ShaderMaterial.new()
	m.shader = SKY
	for k in _look.sky:
		m.set_shader_parameter(k, _look.sky[k])
	m.set_shader_parameter("sun_dir", to_sun)
	if _low:
		m.set_shader_parameter("clouds", 0.0)
	var sky := Sky.new()
	sky.sky_material = m
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	env.sky = sky
	for k in _look.env:
		env.set(k, _look.env[k])
	if _low:
		env.glow_bloom = 0.0
		for i in range(4, 8):
			env.set("glow_levels/%d" % i, 0.0)
	env.adjustment_color_correction = _grade_lut(_look.grade)
	return env


func _grade_lut(g: Dictionary) -> ImageTexture3D:
	## the colour grade as a small 3D lookup table: the shadows pushed towards one tint, the highlights towards another
	const N := 17
	var sh: Color = g.shadows
	var hi: Color = g.highlights
	var slices: Array[Image] = []
	for b in N:
		var img := Image.create(N, N, false, Image.FORMAT_RGB8)
		for gi in N:
			for r in N:
				var c := Color((r + 0.5) / N, (gi + 0.5) / N, (b + 0.5) / N)
				var l := c.get_luminance()
				var w := (1.0 - l) * (1.0 - l)
				c = Color(c.r + sh.r * w, c.g + sh.g * w, c.b + sh.b * w)
				c = c.lerp(Color(c.r * hi.r, c.g * hi.g, c.b * hi.b), l * l)
				img.set_pixel(r, gi, c.clamp())
		slices.append(img)
	var t := ImageTexture3D.new()
	t.create(Image.FORMAT_RGB8, N, N, N, false, slices)
	return t


func _treat(root: Node) -> void:
	## brighten the lamps and gloss the road under root (the laid-out street, or a section as it's placed)
	var lamps: Dictionary = _look.lamps
	if not lamps.is_empty():
		for n in root.find_children("*", "Node3D", true, false):
			var lamp := _lamp_kind(n)
			if lamp == "" or not lamps.has(lamp):
				continue
			var k: Array = lamps[lamp]
			if n is OmniLight3D:
				n.light_energy *= k[0]
				n.omni_range *= k[1]
			elif n is SpotLight3D:
				n.light_energy *= k[0]
				n.spot_range *= k[1]
			elif n is MeshInstance3D and n.name == "Glow" and k[2] != 1.0:
				n.material_override = _halo((n as MeshInstance3D).mesh.surface_get_material(0), k[2])
	var gloss: Dictionary = _look.gloss
	if gloss.is_empty() and not _look.has("mirror"):
		return
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		mi.layers |= MIRROR_LAYER
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i)
			if mat == null:
				continue
			var base := mat.resource_path.get_file().get_basename()
			if gloss.has(base):
				mi.set_surface_override_material(i, _gloss(mat, gloss[base]))


func _lamp_kind(n: Node) -> String:
	## which lamp scene n belongs to ("" if none)
	var p := n.get_parent()
	if p == null:
		return ""
	var f := p.scene_file_path.get_file().get_basename()
	return f if f in LAMPS else ""


func _halo(mat: Material, k: float) -> Material:
	## a copy of a lamp's halo k times as bright
	if not _halos.has(mat):
		var m := mat.duplicate() as ShaderMaterial
		m.set_shader_parameter("intensity", float(m.get_shader_parameter("intensity")) * k)
		_halos[mat] = m
	return _halos[mat]


func _gloss(mat: Material, v: float) -> Material:
	## a copy of a road material that shines more: a lower roughness, or the glossier wet road with its painted
	## shine times v
	if not _glossy.has(mat.resource_path):
		var m := mat.duplicate()
		if m is BaseMaterial3D:
			(m as BaseMaterial3D).roughness = v
		elif m is ShaderMaterial:
			var s = m.get_shader_parameter("shine")
			if (m as ShaderMaterial).shader.resource_path.ends_with("road_wet.gdshader"):
				var tex = [m.get_shader_parameter("albedo_tex"), m.get_shader_parameter("normal_tex")]
				var keep := {"tile": m.get_shader_parameter("tile"), "darkness": m.get_shader_parameter("darkness")}
				(m as ShaderMaterial).shader = ROAD
				m.set_shader_parameter("albedo_tex", tex[0])
				m.set_shader_parameter("normal_tex", tex[1])
				for k in keep:
					if keep[k] != null:
						m.set_shader_parameter(k, keep[k])
			m.set_shader_parameter("shine", (float(s) if s != null else 1.0) * v)
		_glossy[mat.resource_path] = m
	return _glossy[mat.resource_path]
