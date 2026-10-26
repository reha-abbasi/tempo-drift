// A synthwave sun: a disc fading from yellow at the top to pink, cut by horizontal bands that thicken toward the bottom
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	float disc = smoothstep(1.0, 0.97, r);
	float y = UV.y;
	float bands = step(0.5, y) * step(0.5, fract(y * 18.0 - pow(y, 2.0) * 6.0)) * smoothstep(0.5, 0.65, y);
	vec3 c = mix(vec3(1.0, 0.85, 0.3), vec3(1.0, 0.2, 0.6), smoothstep(0.1, 0.9, y));
	float glow = smoothstep(1.4, 0.9, r) * 0.25;
	ALBEDO = c * (disc * (1.0 - bands) * 1.6 + glow);
}
