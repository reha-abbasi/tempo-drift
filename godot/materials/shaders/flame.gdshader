// Thruster exhaust: a hot core that cools and thins along the cone (UV.y from the nozzle).
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 core : source_color = vec4(1.0, 0.95, 0.8, 1.0);
uniform vec4 outer : source_color = vec4(1.0, 0.45, 0.12, 1.0);
uniform float intensity = 2.2;

void fragment() {
	float along = clamp(UV.y, 0.0, 1.0);
	float rim = pow(clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.5);
	float flick = 0.85 + 0.15 * sin(TIME * 40.0 + along * 12.0);
	vec3 c = mix(core.rgb, outer.rgb, smoothstep(0.0, 0.6, along));
	float a = (1.0 - along) * rim * flick;
	ALBEDO = c * intensity * a;
	ALPHA = a;
}
