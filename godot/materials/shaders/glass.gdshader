// Glass case around a sealed note: clear in the middle, bright at grazing angles, with a faint sheen.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, specular_schlick_ggx;

uniform vec4 tint : source_color = vec4(0.75, 0.92, 1.0, 1.0);
uniform float edge = 0.85;

void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	ALBEDO = tint.rgb * 0.2;
	ROUGHNESS = 0.05;
	METALLIC = 0.0;
	SPECULAR = 1.0;
	EMISSION = tint.rgb * f * edge;
	ALPHA = 0.12 + f * 0.6;
}
