// Berlin 2075's holographic billboards: light hanging in the air off a tower, in the colour of its vertices. A turning
// emblem, a word in pixel letters, scan lines drifting up, corner brackets, and now and then a glitch. Additive,
// so it never hides what's behind it.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled;

uniform float energy = 1.6;

varying vec4 tint;

float hash(float n) { return fract(sin(n * 12.9898) * 43758.5453); }

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec3 col = tint.rgb;
	float sd = tint.a * 10.0;
	float t = TIME + sd * 7.0;
	vec2 uv = UV;
	// a glitch: for a moment the picture slips sideways in bands
	float g = step(0.96, hash(floor(t * 6.0) + sd));
	uv.x += g * (hash(floor(uv.y * 14.0) + floor(t * 30.0)) - 0.5) * 0.08;
	vec2 c = uv - vec2(0.5, 0.42);
	c.x *= 0.9;
	// the emblem: a ring and a diamond turning inside it
	float r = length(c);
	float ring = exp(-pow((r - 0.28) / 0.012, 2.0)) + 0.5 * exp(-pow((r - 0.33) / 0.006, 2.0));
	float a = t * 0.6;
	vec2 q = mat2(vec2(cos(a), -sin(a)), vec2(sin(a), cos(a))) * c;
	float dia = abs(abs(q.x) + abs(q.y) * 1.4 - 0.17);
	float shape = exp(-pow(dia / 0.012, 2.0)) + 0.25 * step(abs(q.x) + abs(q.y) * 1.4, 0.17);
	float ticks = step(0.92, fract(atan(c.y, c.x) / 6.2831853 * 24.0 + t * 0.1)) * step(abs(r - 0.36), 0.02);
	// a band of light below it, like a caption
	float cap = step(abs(uv.y - 0.86), 0.035) * step(abs(uv.x - 0.5), 0.3) * step(0.4, hash(floor(uv.x * 22.0) + sd));
	// scan lines drifting up, brackets in the corners, a soft edge
	float scan = 0.65 + 0.35 * sin((uv.y + t * 0.08) * 220.0);
	vec2 e = min(uv, 1.0 - uv);
	float bracket = step(min(e.x, e.y), 0.015) * step(max(e.x, e.y), 0.12);
	float fade = smoothstep(0.0, 0.06, min(e.x, e.y));
	float body = (ring + shape + ticks * 0.8 + cap * 0.7) * scan * fade + bracket * 1.2 + 0.04 * fade;
	float flick = 0.85 + 0.15 * sin(t * 23.0) * sin(t * 7.0);
	float far = 1.0 - smoothstep(70.0, 140.0, length(VERTEX));
	ALBEDO = col * body * energy * flick * far;
}
