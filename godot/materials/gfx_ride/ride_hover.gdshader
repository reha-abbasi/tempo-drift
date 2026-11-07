// The glow of a new car's anti-gravity field: a soft oval of light under the car with slow
// ripples running out from its middle. Drawn on a flat quad under the body; intensity follows the engines.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.8, 0.5, 1.0);
uniform float intensity = 1.0;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float d = length(p);
	float a = pow(clamp(1.0 - d, 0.0, 1.0), 1.6);
	float ripple = 0.75 + 0.25 * sin(d * 16.0 - TIME * 7.0);
	ALBEDO = color.rgb * intensity * a * ripple;
}
