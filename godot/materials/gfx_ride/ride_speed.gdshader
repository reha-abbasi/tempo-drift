// Overdrive's speed lines: a thin streak, bright gold-white at its head (the end nearer the
// camera) and fading out behind, in the particle's colour.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 tint : source_color = vec4(1.0, 0.86, 0.5, 1.0);
uniform float energy = 2.2;

varying float along;

void vertex() {
	along = clamp(VERTEX.z / 5.0 + 0.5, 0.0, 1.0);
}

void fragment() {
	float a = pow(along, 2.5);
	ALBEDO = mix(tint.rgb, vec3(1.0), a * 0.5) * energy * a * COLOR.a;
}
