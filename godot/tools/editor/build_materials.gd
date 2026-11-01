extends RefCounted
## Builds the shared materials (materials/*.tres) once; edit them in the editor afterwards.
## Photographic ones use Poly Haven textures (albedo, normal, and AO/roughness/metal packed as ORM).

const PH := "res://assets/polyhaven/textures/%s/%s_%s.jpg"


func build(_host: Node) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://materials"))
	# ---- photographic surfaces (scale: metres per texture repeat is set where they are used)
	_pbr("cobblestone", "cobblestone_floor_04")
	_pbr("asphalt", "asphalt_02")
	_pbr("asphalt_worn", "worn_asphalt")
	_pbr("brick_red", "brick_wall_07")
	_pbr("brick_patched", "red_brick_plaster_patch_02")
	_pbr("portland_stone", "white_sandstone_bricks")
	_pbr("sandstone", "large_sandstone_blocks")
	_pbr("slate", "roof_slates_02", Color(0.42, 0.45, 0.52))
	_pbr("roof_tiles_grey", "grey_roof_tiles")
	_pbr("roof_tiles_clay", "clay_roof_tiles")
	_pbr("pavement", "pavement_02")
	_pbr("pavement_concrete", "concrete_pavement")
	_pbr("plaster_cream", "painted_plaster_wall", Color(1.0, 0.94, 0.82))
	_pbr("plaster_white", "painted_plaster_wall", Color(1, 1, 1))
	_pbr("granite", "granite_tile")
	_pbr("facade_tiles", "rectangular_facade_tiles_02")
	_pbr("concrete_panels", "concrete_tile_facade")
	_pbr("metal_plate", "metal_plate")

	# ---- painted and plain surfaces
	_plain("paint_black", Color(0.06, 0.06, 0.07), 0.45)
	_plain("paint_dark_green", Color(0.08, 0.2, 0.14), 0.5)
	_plain("paint_red", Color(0.62, 0.05, 0.04), 0.35)
	_paint("paint_cream", Color(0.82, 0.72, 0.54))
	_paint("paint_maroon", Color(0.3, 0.04, 0.06))
	_paint("paint_bottle_green", Color(0.04, 0.16, 0.1))
	_paint("paint_navy", Color(0.05, 0.08, 0.2))
	_plain("leaves", Color(0.22, 0.34, 0.12), 0.85)
	_plain("leaves_light", Color(0.36, 0.46, 0.16), 0.85)
	_plain("bark", Color(0.32, 0.28, 0.22), 0.9)
	_plain("flag_red", Color(0.72, 0.06, 0.08), 0.8)
	_plain("flag_white", Color(0.92, 0.9, 0.86), 0.8)
	_plain("flag_blue", Color(0.06, 0.12, 0.42), 0.8)
	_plain("paint_white", Color(0.92, 0.92, 0.9), 0.5)
	_plain("stone_trim", Color(0.86, 0.82, 0.74), 0.8)
	_plain("stone_trim_warm", Color(0.9, 0.78, 0.62), 0.8)
	_plain("wood_dark", Color(0.22, 0.13, 0.07), 0.6)
	_plain("fabric_red", Color(0.55, 0.08, 0.07), 0.9)
	_plain("fabric_green", Color(0.1, 0.32, 0.18), 0.9)
	_plain("fabric_cream", Color(0.86, 0.8, 0.66), 0.9)
	_plain("fabric_navy", Color(0.08, 0.12, 0.26), 0.9)
	_plain("rubber", Color(0.04, 0.04, 0.04), 0.8)
	_plain("leather_brown", Color(0.28, 0.15, 0.08), 0.55)
	_plain("skin", Color(0.86, 0.66, 0.53), 0.6)
	_plain("hair_dark", Color(0.09, 0.06, 0.04), 0.7)
	_plain("chrome", Color(0.85, 0.86, 0.88), 0.12, 1.0)
	_plain("brass", Color(0.86, 0.66, 0.3), 0.25, 1.0)
	_plain("gold", Color(1.0, 0.76, 0.33), 0.2, 1.0)
	_plain("iron", Color(0.12, 0.12, 0.13), 0.55, 0.8)
	_plain("steel", Color(0.55, 0.57, 0.6), 0.3, 0.9)
	_plain("glass_dark", Color(0.06, 0.08, 0.1), 0.05, 0.4)
	_plain("lens", Color(1.0, 0.95, 0.8), 0.1, 0.0, Color(1.0, 0.85, 0.55), 2.5)
	_plain("lamp_glow", Color(1.0, 0.85, 0.55), 0.3, 0.0, Color(1.0, 0.75, 0.4), 4.0)
	_plain("tail_glow", Color(0.9, 0.1, 0.08), 0.3, 0.0, Color(1.0, 0.12, 0.08), 3.0)
	_plain("clock_face", Color(0.98, 0.94, 0.8), 0.6, 0.0, Color(1.0, 0.86, 0.55), 1.4)

	# windows. Vertex colour: r = lit (or, in curtain-wall mode, the share of lit rooms), g = variation,
	# b > 0.5 = curtain-wall mode, where one surface covers many windows: UV counts (bays, floors) and the
	# shader draws mullions, spandrel bands and a scatter of lit rooms itself.
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode specular_schlick_ggx;
uniform vec4 glass_color : source_color = vec4(0.08, 0.1, 0.13, 1.0);
uniform vec4 room_color : source_color = vec4(1.0, 0.72, 0.38, 1.0);
uniform vec4 frame_color : source_color = vec4(0.12, 0.13, 0.15, 1.0);
uniform vec4 spandrel_color : source_color = vec4(0.55, 0.56, 0.58, 1.0);
uniform float room_energy = 2.2;
uniform float night = 0.4; // 0 = daylight (rooms barely show), 1 = night
global uniform float city_night; // set by each city: how dark it is there
uniform float spandrel = 0.0; // share of each floor that is solid band in curtain-wall mode
uniform float mullion = 0.04;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	bool wall = COLOR.b > 0.5;
	vec2 cell = floor(UV);
	vec2 f = fract(UV);
	float lit = COLOR.r;
	float vary = COLOR.g;
	if (wall) {
		float h = hash(cell);
		lit = step(1.0 - COLOR.r, h);
		vary = hash(cell + 7.3);
	}
	vec3 glass = glass_color.rgb * (0.75 + 0.5 * vary);
	float inside = smoothstep(1.1, 0.0, f.y) * 0.6 + 0.4;
	vec3 room = room_color.rgb * lit * room_energy * mix(0.25, 1.0, max(night, city_night)) * inside * (0.7 + 0.6 * vary);
	ALBEDO = glass;
	ROUGHNESS = 0.06;
	METALLIC = 0.65;
	SPECULAR = 0.8;
	EMISSION = room;
	if (wall) {
		float band = step(f.y, spandrel);
		float frame = max(step(f.x, mullion), step(1.0 - mullion, f.x));
		frame = max(frame, step(abs(f.y - spandrel), mullion * 0.6));
		vec3 solid = mix(spandrel_color.rgb, frame_color.rgb, frame);
		float s = max(band, frame);
		ALBEDO = mix(glass, solid, s);
		ROUGHNESS = mix(0.06, 0.45, s);
		METALLIC = mix(0.65, 0.3, s);
		EMISSION = room * (1.0 - s);
	}
}"""
	ResourceSaver.save(sh, "res://materials/shaders/window.gdshader")
	sh = load("res://materials/shaders/window.gdshader")
	for spec in [
		["window_warm", Color(1.0, 0.72, 0.38), 0.45, Color(0.08, 0.1, 0.13), Color(0.55, 0.56, 0.58), 0.0],
		["window_cool", Color(0.75, 0.88, 1.0), 0.35, Color(0.08, 0.1, 0.13), Color(0.55, 0.56, 0.58), 0.0],
		["window_neon", Color(0.55, 0.85, 1.0), 1.0, Color(0.05, 0.06, 0.09), Color(0.1, 0.1, 0.12), 0.0],
		# curtain walls: Dubai glass (blue-green with sandstone bands), Tokyo night glass (dark with lit offices)
		["curtain_dubai", Color(1.0, 0.82, 0.58), 0.3, Color(0.1, 0.2, 0.24), Color(0.78, 0.68, 0.52), 0.28],
		["curtain_dubai_gold", Color(1.0, 0.8, 0.55), 0.3, Color(0.3, 0.22, 0.12), Color(0.82, 0.74, 0.6), 0.12],
		["curtain_dubai_silver", Color(0.85, 0.92, 1.0), 0.3, Color(0.12, 0.15, 0.2), Color(0.7, 0.72, 0.76), 0.0],
		["curtain_tokyo", Color(0.75, 0.9, 1.0), 1.0, Color(0.03, 0.04, 0.06), Color(0.08, 0.09, 0.11), 0.22],
		["curtain_tokyo_warm", Color(1.0, 0.76, 0.5), 1.0, Color(0.03, 0.035, 0.05), Color(0.1, 0.1, 0.11), 0.3],
	]:
		var m := ShaderMaterial.new()
		m.shader = sh
		m.set_shader_parameter("room_color", spec[1])
		m.set_shader_parameter("night", spec[2])
		m.set_shader_parameter("glass_color", spec[3])
		m.set_shader_parameter("spandrel_color", spec[4])
		m.set_shader_parameter("spandrel", spec[5])
		ResourceSaver.save(m, "res://materials/%s.tres" % spec[0])

	# neon signs: glowing boards of made-up glyphs that flicker now and then
	var neon := Shader.new()
	neon.code = """shader_type spatial;
render_mode unshaded;
uniform vec4 color : source_color = vec4(1.0, 0.2, 0.6, 1.0);
uniform float energy = 3.0;
uniform float seed = 1.0;
uniform vec2 grid = vec2(1.0, 4.0); // glyphs across and down
// a building's signs share one material: each sign's colour and seed then come from its vertices (MeshKit)
uniform bool vertex_tint = false;
varying vec4 tint;
float hash(vec2 p, float s) { return fract(sin(dot(p, vec2(12.9898, 78.233)) + s * 17.0) * 43758.5453); }
void vertex() { tint = COLOR; }
void fragment() {
	vec3 col = vertex_tint ? tint.rgb : color.rgb;
	float sd = vertex_tint ? tint.a * 10.0 : seed;
	vec2 g = UV * grid;
	vec2 cell = floor(g);
	vec2 f = fract(g) * 1.25 - 0.125;
	// each glyph: a few strokes on a 3x3 lattice
	vec2 q = floor(clamp(f, 0.0, 0.999) * 3.0);
	vec2 r = fract(clamp(f, 0.0, 0.999) * 3.0);
	float on = step(0.45, hash(cell * 3.1 + q, sd));
	float stroke = max(step(abs(r.x - 0.5), 0.16) * step(0.5, hash(cell + q + 0.3, sd)), step(abs(r.y - 0.5), 0.16) * step(0.5, hash(cell + q + 0.7, sd)));
	float inside = step(0.0, f.x) * step(f.x, 1.0) * step(0.0, f.y) * step(f.y, 1.0);
	float glyph = on * stroke * inside;
	float border = max(step(UV.x, 0.03), step(0.97, UV.x)) + max(step(UV.y, 0.02), step(0.98, UV.y));
	float flicker = 1.0 - 0.6 * step(0.985, fract(sin(floor(TIME * 8.0) + sd * 9.0) * 43758.5));
	vec3 base = col * 0.08;
	ALBEDO = base + col * energy * flicker * clamp(glyph + border, 0.0, 1.0);
}"""
	ResourceSaver.save(neon, "res://materials/shaders/neon_sign.gdshader")
	neon = load("res://materials/shaders/neon_sign.gdshader")
	var palette := [Color(1.0, 0.2, 0.6), Color(0.2, 0.9, 1.0), Color(1.0, 0.75, 0.2), Color(0.6, 0.3, 1.0), Color(0.3, 1.0, 0.5), Color(1.0, 0.35, 0.2)]
	for i in palette.size():
		var m := ShaderMaterial.new()
		m.shader = neon
		m.set_shader_parameter("color", palette[i])
		m.set_shader_parameter("seed", float(i) * 1.7 + 0.3)
		ResourceSaver.save(m, "res://materials/neon_%d.tres" % i)
	var all := ShaderMaterial.new()
	all.shader = neon
	all.set_shader_parameter("vertex_tint", true)
	ResourceSaver.save(all, "res://materials/neon_all.tres")
	# emissive strips for modern architecture and vehicles
	_plain("led_white", Color(0.9, 0.95, 1.0), 0.3, 0.0, Color(0.85, 0.92, 1.0), 4.0)
	_plain("led_gold", Color(1.0, 0.8, 0.45), 0.3, 0.0, Color(1.0, 0.72, 0.35), 4.0)
	_plain("led_cyan", Color(0.3, 0.9, 1.0), 0.3, 0.0, Color(0.2, 0.85, 1.0), 6.0)
	_plain("led_magenta", Color(1.0, 0.3, 0.8), 0.3, 0.0, Color(1.0, 0.2, 0.7), 6.0)
	_plain("lane_glow", Color(0.3, 0.9, 1.0), 0.3, 0.0, Color(0.2, 0.85, 1.0), 1.6)
	_plain("palm_frond", Color(0.24, 0.38, 0.14), 0.8)
	_plain("palm_trunk", Color(0.45, 0.36, 0.25), 0.9)
	var wet := ShaderMaterial.new()
	wet.shader = load("res://materials/shaders/road_wet.gdshader")
	wet.set_shader_parameter("albedo_tex", load(PH % ["asphalt_02", "asphalt_02", "albedo"]))
	wet.set_shader_parameter("normal_tex", load(PH % ["asphalt_02", "asphalt_02", "normal"]))
	ResourceSaver.save(wet, "res://materials/asphalt_wet.tres")
	_plain("lane_white", Color(0.85, 0.85, 0.82), 0.6)
	_plain("lane_yellow", Color(0.9, 0.7, 0.15), 0.6)
	_paint("paint_white_pearl", Color(0.9, 0.9, 0.88))
	_paint("paint_gold", Color(0.75, 0.55, 0.25))
	_paint("paint_taxi_red", Color(0.62, 0.08, 0.07))
	_paint("paint_black_gloss", Color(0.03, 0.03, 0.035))
	_paint("paint_graphite", Color(0.14, 0.15, 0.17))
	_paint("paint_silver", Color(0.6, 0.62, 0.66))
	for pair in [["vertex_paint", "res://materials/shaders/vertex_paint.gdshader"], ["vertex_glow", "res://materials/shaders/vertex_glow.gdshader"]]:
		var vm := ShaderMaterial.new()
		vm.shader = load(pair[1])
		ResourceSaver.save(vm, "res://materials/%s.tres" % pair[0])
	print("materials done")


func _pbr(name: String, tex: String, tint := Color.WHITE) -> void:
	var m := ORMMaterial3D.new()
	m.albedo_texture = load(PH % [tex, tex, "albedo"])
	m.albedo_color = tint
	m.normal_enabled = true
	m.normal_texture = load(PH % [tex, tex, "normal"])
	m.orm_texture = load(PH % [tex, tex, "arm"])
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	ResourceSaver.save(m, "res://materials/%s.tres" % name)


func _paint(name: String, col: Color) -> void:
	## car paint: a little metal flake under a clear coat
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.32
	m.metallic = 0.25
	m.clearcoat_enabled = true
	m.clearcoat = 1.0
	m.clearcoat_roughness = 0.08
	ResourceSaver.save(m, "res://materials/%s.tres" % name)


func _plain(name: String, col: Color, rough: float, metal := 0.0, emit := Color.BLACK, energy := 0.0) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emit
		m.emission_energy_multiplier = energy
	ResourceSaver.save(m, "res://materials/%s.tres" % name)
