// An engine's exhaust on the new cars: a white-hot core cooling to the engine's colour,
// with bright shock rings running down it; heat (a swipe, Overdrive) makes it hotter and brighter.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 core : source_color = vec4(1.0, 0.97, 0.9, 1.0);
uniform vec4 outer : source_color = vec4(1.0, 0.6, 0.25, 1.0);
uniform float intensity = 2.2;
uniform float heat = 0.0;

void fragment() {
	float along = clamp(UV.y, 0.0, 1.0);
	float rim = pow(clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.3);
	float rings = 0.78 + 0.22 * cos(along * 30.0 - TIME * 34.0);
	vec3 c = mix(core.rgb, outer.rgb, smoothstep(0.0, 0.5 - heat * 0.2, along));
	float a = pow(1.0 - along, 1.5) * rim * rings;
	ALBEDO = c * intensity * (1.0 + heat * 0.8) * a;
}
