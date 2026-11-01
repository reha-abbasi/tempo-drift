// A scarf streaming behind the pilot: the cloth ripples more towards its free end.
// UV.x runs from the neck (0) to the tip (1).
shader_type spatial;
render_mode cull_disabled;

uniform vec4 color : source_color = vec4(0.72, 0.06, 0.05, 1.0);
uniform float speed = 9.0;
uniform float amount = 0.16;

void vertex() {
	float k = UV.x * UV.x;
	float t = TIME * speed;
	VERTEX.y += sin(t - UV.x * 7.0) * amount * k;
	VERTEX.x += sin(t * 0.7 - UV.x * 5.0) * amount * 0.6 * k;
}

void fragment() {
	ALBEDO = color.rgb * (0.85 + 0.15 * sin(UV.y * 40.0));
	ROUGHNESS = 0.85;
}
