// A searchlight beam: a pale shaft fading out toward its end and its edges
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
void vertex() {
	// pivot at the bottom of the quad
	VERTEX.y += 0.5;
}
void fragment() {
	float x = abs(UV.x - 0.5) * 2.0;
	float a = (1.0 - x * x) * UV.y * UV.y;
	ALBEDO = vec3(0.7, 0.75, 0.9) * a * 0.22;
}
