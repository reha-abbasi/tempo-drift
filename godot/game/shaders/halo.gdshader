// A soft glow that always faces the camera (gas lamps, windows far away, the car's pods). Added on top, faded by
// distance like the fog
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
uniform vec3 tint : source_color = vec3(1.0, 0.7, 0.35);
uniform float energy = 1.0;
uniform float fade = 0.012;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0),
		vec4(0, 0, length(MODEL_MATRIX[2].xyz), 0), vec4(0, 0, 0, 1));
}
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float g = pow(clamp(1.0 - d, 0.0, 1.0), 2.6) + pow(clamp(1.0 - d, 0.0, 1.0), 14.0) * 1.5;
	float f = exp(-length(VERTEX) * fade);
	ALBEDO = tint * energy * g * f;
}
