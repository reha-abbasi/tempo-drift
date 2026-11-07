shader_type spatial;
// The soft wall along the outer lanes' edge (Edge bounce, scripts/edge_bounce.gd): a panel standing along the
// street, unseen until the ride touches it, then a short upright shimmer of warm light where it was touched that
// spreads a little along the street and fades.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.92, 0.78);
uniform float age = 1.0;            // 0 at the touch, 1 faded away
uniform float power = 1.0;          // touches in a row glow a little brighter
uniform vec2 size = vec2(1.75, 0.95); // the panel (m): along the street, up

void fragment() {
	vec2 p = (UV - 0.5) * size;      // metres from the touch: along the street, up
	float a = clamp(age, 0.0, 1.0);
	float spread = mix(0.04, 0.5, 1.0 - pow(1.0 - a, 2.0));
	// the line where it touched, softening as it spreads, and one faint pair of ripples moving off along the street
	float line = exp(-pow(p.x / (0.03 + spread * 0.25), 2.0)) * pow(1.0 - a, 1.5);
	float ripple = exp(-pow((abs(p.x) - spread) / 0.06, 2.0)) * 0.45 * (1.0 - a);
	float tall = 1.0 - smoothstep(0.25, 0.47, abs(p.y));
	float shimmer = 0.75 + 0.25 * sin(p.y * 22.0 - a * 30.0);
	float v = (line * shimmer + ripple) * tall;
	ALBEDO = mix(color, vec3(1.0), clamp(line * 0.6, 0.0, 1.0)) * 1.3;
	ALPHA = clamp(v * power, 0.0, 1.0);
}
