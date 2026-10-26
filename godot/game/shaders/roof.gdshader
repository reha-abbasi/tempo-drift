// Wet slate roofs: rows of tiles that catch the low sun
shader_type spatial;
uniform vec3 slate : source_color = vec3(0.29, 0.31, 0.35);
varying vec3 wp;
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 g = vec2(wp.z / 0.32 + floor(wp.y / 0.2) * 0.5, wp.y / 0.2);
	float n = h21(floor(g));
	float line = 1.0 - smoothstep(0.0, 0.12, fract(g.y));
	ALBEDO = slate * (0.75 + 0.4 * n) * (1.0 - line * 0.5);
	ROUGHNESS = 0.32 + 0.3 * n;
	SPECULAR = 0.6;
}
