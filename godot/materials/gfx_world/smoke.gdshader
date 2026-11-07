// Chimney smoke over London's roofs: a soft, slowly rising plume, thin at the chimney and spreading as it drifts.
// COLOR.a is a seed so no two plumes rise alike.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(0.42, 0.4, 0.38, 1.0);
uniform float density = 0.55;

varying float seed;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	seed = COLOR.a * 17.0;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME * 0.05;
	vec2 q = vec2(uv.x * 2.0 + seed, uv.y * 3.0 + t * 6.0 + seed);
	float n = noise(q) * 0.55 + noise(q * 2.3 - vec2(0.0, t * 4.0)) * 0.3 + noise(q * 5.1) * 0.15;
	float across = 1.0 - smoothstep(0.15, 0.5, abs(uv.x - 0.5));
	float along = (1.0 - smoothstep(0.82, 1.0, uv.y)) * smoothstep(0.0, 0.6, uv.y);
	ALBEDO = color.rgb * (0.85 + 0.3 * n);
	ALPHA = clamp(smoothstep(0.35, 0.8, n * across) * along * density, 0.0, 1.0);
}
