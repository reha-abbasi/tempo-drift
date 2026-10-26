// The cobbled street after rain: granite setts in rows across the road, dark wet joints, puddles that mirror the sky,
// and a pair of polished tram rails between the lanes
shader_type spatial;
uniform vec3 stone_a : source_color = vec3(0.30, 0.29, 0.28);
uniform vec3 stone_b : source_color = vec3(0.44, 0.39, 0.33);
uniform float puddles = 0.42;
uniform float half_w = 4.6;
varying vec3 wp;
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { return vn(p) * 0.55 + vn(p * 2.1 + 3.1) * 0.3 + vn(p * 4.3 + 7.7) * 0.15; }
// the height of a sett: a soft dome inside each cell; setts vary a little in length, and rows wander
float sett(vec2 p, out vec2 id) {
	vec2 cs = vec2(0.15, 0.095);
	float row = floor(p.y / cs.y);
	vec2 c = vec2(p.x / cs.x + h21(vec2(row, 3.0)) * 7.0, p.y / cs.y);
	id = floor(c);
	float stretch = 0.75 + 0.5 * h21(id + 0.5);
	vec2 f = abs(fract(c) - 0.5) * cs;
	vec2 e = cs * 0.5 * vec2(stretch, 1.0) - f;
	float d = min(e.x, e.y);
	return smoothstep(0.0, 0.016, d) * (0.8 + 0.2 * h21(id));
}
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wp.xz;
	vec2 id;
	float h = sett(p, id);
	vec2 i2;
	float hx = sett(p + vec2(0.006, 0.0), i2);
	float hz = sett(p + vec2(0.0, 0.006), i2);
	float far = clamp(length(wp - CAMERA_POSITION_WORLD) / 40.0, 0.0, 1.0);
	float n = h21(id);
	vec3 col = mix(stone_a, stone_b, n * n) * (0.75 + 0.35 * vn(p * 2.0)) * (0.85 + 0.3 * h21(id * 1.7));
	col = mix(col * 0.22, col, mix(h, 0.8, far));
	float rough = mix(0.55, 0.3, h);
	// puddles: dark and mirror-smooth
	float pd = smoothstep(0.62 - puddles * 0.25, 0.7 - puddles * 0.25, fbm(p * vec2(0.22, 0.12) + 4.0));
	col = mix(col, col * 0.35, pd);
	rough = mix(rough, 0.03, pd);
	vec2 slope = vec2(h - hx, h - hz) * (1.0 - pd) * (1.0 - far) * 4.0;
	// polished tram rails between the lanes, and the gutters by the kerb
	float ax = abs(wp.x);
	float rail = (1.0 - smoothstep(0.03, 0.05, abs(ax - 0.8))) + (1.0 - smoothstep(0.03, 0.05, abs(ax - 0.95)));
	col = mix(col, vec3(0.62, 0.56, 0.48), rail * 0.85);
	rough = mix(rough, 0.12, rail);
	float met = rail * 0.9;
	float gut = smoothstep(half_w - 0.5, half_w - 0.1, ax);
	col *= 1.0 - gut * 0.45;
	rough = mix(rough, 0.06, gut);
	col = mix(col, mix(stone_a, stone_b, 0.4) * 0.6, far * 0.5);
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = met;
	SPECULAR = 0.6;
	NORMAL_MAP = normalize(vec3(slope.x, slope.y, 1.0)) * 0.5 + 0.5;
}
