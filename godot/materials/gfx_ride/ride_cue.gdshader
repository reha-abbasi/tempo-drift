// A note ring's cue: a crisp thin ring, white tinted by the ring's colour, with a dark edge,
// closing in on the band; grow is its scale, so the line keeps its width; land flashes it as it lands on the band.
shader_type spatial;
render_mode blend_premul_alpha, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

const float R = 0.854;
const float SIZE = 0.95;

instance uniform vec4 color : source_color = vec4(1.0, 0.89, 0.72, 1.0);
instance uniform float alpha = 1.0;
instance uniform float grow = 1.0;
instance uniform float land = 0.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0 * SIZE;
	float d = length(p);
	float aa = max(fwidth(d), 0.002);
	float w = (0.026 + land * 0.03) / grow;
	float x = abs(d - R);
	float line = 1.0 - smoothstep(w - aa, w + aa, x);
	float edge = (1.0 - smoothstep(w + 0.02 / grow - aa, w + 0.02 / grow + aa, x)) - line;
	vec3 c = mix(vec3(1.0), color.rgb, 0.35) * (1.6 + land * 1.5);
	ALBEDO = c * line * alpha;
	ALPHA = (line + edge * 0.45) * alpha;
}
