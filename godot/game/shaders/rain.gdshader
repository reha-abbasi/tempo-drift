// A falling rain streak, brighter where it catches the light
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
uniform vec3 tint : source_color = vec3(0.78, 0.8, 0.86);
uniform float energy = 0.35;
void fragment() {
	float x = abs(UV.x - 0.5) * 2.0;
	float a = (1.0 - x) * smoothstep(0.0, 0.3, UV.y) * smoothstep(1.0, 0.6, UV.y);
	ALBEDO = tint * energy * a * COLOR.a;
}
