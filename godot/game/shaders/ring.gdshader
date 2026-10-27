// The note rings, their discs, arrows and cue rings: plain glowing colour set per ring
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
instance uniform vec4 tint : source_color = vec4(1.0);
instance uniform float glow = 1.0;
uniform sampler2D mask : source_color, hint_default_white;
uniform bool use_mask = false;
uniform float fade = 0.01;
void fragment() {
	float a = use_mask ? texture(mask, UV).a : 1.0;
	ALBEDO = tint.rgb * glow * a * tint.a * exp(-length(VERTEX) * fade);
}
