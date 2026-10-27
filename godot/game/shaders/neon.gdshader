// A neon sign: glowing tubes forming blocky glyphs on a dark backing, flickering now and then.
// The sign's colour and a seed come from INSTANCE_CUSTOM (rgb colour, a seed)
shader_type spatial;
render_mode unshaded, cull_disabled;
varying flat vec4 cd;
float h21(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
void vertex() { cd = INSTANCE_CUSTOM; }
void fragment() {
	vec2 uv = UV;
	// glyphs on a 3 x 7 grid of cells, each a 3 x 5 pattern of tube segments
	vec2 cell = vec2(3.0, 7.0);
	vec2 g = uv * cell;
	vec2 gi = floor(g);
	vec2 gf = fract(g);
	vec2 sub = floor(gf * vec2(3.0, 5.0));
	float on = step(0.45, h21(gi * 7.3 + sub * 1.9 + cd.a * 91.0));
	vec2 sf = fract(gf * vec2(3.0, 5.0));
	float tube = on * smoothstep(0.5, 0.2, abs(sf.x - 0.5)) * smoothstep(0.5, 0.25, abs(sf.y - 0.5));
	float border = max(step(uv.x, 0.03) + step(0.97, uv.x), step(uv.y, 0.02) + step(0.98, uv.y));
	float flick = 0.85 + 0.15 * step(0.08, fract(sin(TIME * 7.0 + cd.a * 50.0) * 13.0));
	vec3 c = cd.rgb * (tube * 3.2 + border * 2.4) * flick;
	ALBEDO = vec3(0.02) + c;
}
