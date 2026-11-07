// A note ring, drawn on one quad: a glowing band in its height's colour with a white-hot
// line along it, a soft gradient filling the inside, a halo outside and a thin dark edge (so it reads on a bright
// sky as well as on a dark street), and the move's double chevron inside. pop: played (the band flares out white
// and a shock ring races off); dead: missed (it turns grey and breaks into pieces). Premultiplied alpha, so one
// pass both lights and darkens.
shader_type spatial;
render_mode blend_premul_alpha, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

const float R = 0.854;      // the band's middle (m), as the old ring's
const float W = 0.075;      // half the band's width (m)
const float SIZE = 1.35;    // half the quad (m)
const float L = 0.22;       // a chevron arm (m)

instance uniform vec4 color : source_color = vec4(1.0, 0.89, 0.72, 1.0);
instance uniform float alpha = 1.0;
instance uniform float pop = 0.0;
instance uniform float dead = 0.0;
instance uniform float dir = 0.0;
instance uniform float chev = 0.0;
uniform float energy = 2.2;

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0 * SIZE;
	p.y = -p.y;
	float d = length(p);
	float aa = max(fwidth(d), 0.004);
	float r = R * (1.0 + pop * 0.28);
	float w = W * (1.0 + pop * 0.8);
	float x = abs(d - r);
	float band = 1.0 - smoothstep(w - aa, w + aa, x);
	// a missed ring breaks into grey pieces
	float ang = atan(p.y, p.x) / 6.2831853 + 0.5;
	float gap = dead * 0.55;
	band *= 1.0 - dead * (1.0 - smoothstep(gap * 0.5 - 0.02, gap * 0.5 + 0.02, abs(fract(ang * 10.0) - 0.5)));
	float core = 1.0 - smoothstep(0.0, w * 0.6, x);
	float rimz = 1.0 - smoothstep(w + 0.03 - aa, w + 0.03 + aa, x);
	float edge = max(rimz - band, 0.0) * (1.0 - dead * 0.5);
	float inside = 1.0 - smoothstep(r - w - aa, r - w + aa, d);
	float fill = inside * (0.05 + 0.32 * pow(d / r, 2.2)) * (1.0 - dead);
	float halo = exp(-max(d - r - w, 0.0) * 6.5) * step(r, d) * 0.55 * (1.0 - dead);
	// the shock ring of a played note
	float shock = (1.0 - smoothstep(0.0, 0.035 + pop * 0.03, abs(d - R * (1.0 + pop * 0.85)))) * pop * (1.0 - pop) * 4.0;
	vec3 c = mix(color.rgb, vec3(dot(color.rgb, vec3(0.3, 0.5, 0.2)) * 0.55), dead);
	vec3 hot = mix(c, vec3(1.0), 0.45 * core + pop * 0.6);
	vec3 rgb = hot * energy * band + c * fill * (1.0 + pop) * (1.0 - pop) + c * halo * (1.0 - pop) + vec3(1.0) * shock * 1.5;
	float a = band * 0.95 + fill * 0.8 * (1.0 - pop) + edge * 0.5 * (1.0 - pop);
	rgb += c * 0.1 * edge;
	// the move's double chevron, white with a dark outline
	if (chev > 0.5 && pop < 0.3 && dead < 0.99) {
		float ca = cos(dir);
		float sa = sin(dir);
		vec2 q = vec2(ca * p.x + sa * p.y, -sa * p.x + ca * p.y);
		float cd = 1e3;
		for (int i = 0; i < 2; i++) {
			vec2 o = q - vec2(0.22 - float(i) * 0.24, 0.0);
			o.y = abs(o.y);
			cd = min(cd, seg(o, vec2(0.0), vec2(-L, L)));
		}
		float stroke = 1.0 - smoothstep(0.045 - aa, 0.045 + aa, cd);
		float outline = (1.0 - smoothstep(0.075 - aa, 0.075 + aa, cd)) - stroke;
		float gone = (1.0 - pop / 0.3) * (1.0 - dead);
		stroke *= gone;
		outline *= gone;
		vec3 cw = mix(vec3(1.0), c, 0.15) * 1.8 * (1.0 - dead * 0.6);
		rgb = rgb * (1.0 - stroke) + cw * stroke;
		rgb *= 1.0 - outline * 0.6;
		a = max(a, stroke) ;
		a = a + outline * 0.6 * (1.0 - a);
	}
	float k = alpha * (1.0 - smoothstep(0.3, 1.0, pop));
	ALBEDO = rgb * k;
	ALPHA = clamp(a, 0.0, 1.0) * k;
}
