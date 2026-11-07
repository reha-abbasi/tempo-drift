// The light trail behind the engines: a ribbon whose vertices carry its colour and fade,
// soft at its edges and white-hot along its middle.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform float energy = 1.2;

void fragment() {
	float x = 1.0 - abs(UV.y * 2.0 - 1.0);
	float soft = pow(x, 1.6);
	float core = pow(x, 6.0);
	ALBEDO = mix(COLOR.rgb, vec3(1.0), core * 0.6) * energy * soft * COLOR.a;
}
