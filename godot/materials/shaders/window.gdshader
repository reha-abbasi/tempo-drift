shader_type spatial;
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
}