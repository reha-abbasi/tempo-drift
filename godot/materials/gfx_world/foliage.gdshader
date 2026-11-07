// Leaves and fronds, merged into one surface: each vertex carries its colour in COLOR.rgb and in COLOR.a how far it
// is from the trunk (the tips sway in the breeze). Both sides drawn; the low sun shines through.
shader_type spatial;
render_mode cull_disabled;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float s = sin(TIME * 1.4 + w.x * 0.35 + w.z * 0.21) * COLOR.a * COLOR.a;
	VERTEX += vec3(0.12, 0.2, 0.06) * s;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.65;
	SPECULAR = 0.3;
	BACKLIGHT = COLOR.rgb * 0.6;
}
