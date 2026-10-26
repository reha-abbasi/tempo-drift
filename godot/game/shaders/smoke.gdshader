// Chimney smoke and street mist: soft puffs, lit warm on the side facing the sun
shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec3 tint : source_color = vec3(0.62, 0.6, 0.58);
uniform float alpha = 0.35;
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 q = UV - 0.5;
	float d = length(q) * 2.0;
	float n = vn(UV * 4.0 + COLOR.r * 10.0) * 0.6 + vn(UV * 9.0 - COLOR.r * 7.0) * 0.4;
	float a = smoothstep(1.0, 0.2, d + (n - 0.5) * 0.6) * alpha * COLOR.a;
	ALBEDO = tint * (0.9 + 0.2 * n);
	ALPHA = a;
}
