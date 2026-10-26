// Pavement: large York stone flags with a granite kerb along the road
shader_type spatial;
uniform vec3 stone : source_color = vec3(0.52, 0.49, 0.44);
varying vec3 wp;
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 c = vec2(wp.x / 0.9, wp.z / 0.75);
	c.y += mod(floor(c.x), 2.0) * 0.3;
	vec2 f = abs(fract(c) - 0.5);
	float joint = 1.0 - smoothstep(0.44, 0.48, max(f.x, f.y));
	float n = h21(floor(c));
	float wet = smoothstep(0.55, 0.8, h21(floor(c) * 1.7 + 3.0));
	vec3 col = stone * (0.8 + 0.3 * n) * mix(0.5, 1.0, joint);
	ALBEDO = col * mix(1.0, 0.6, wet);
	ROUGHNESS = mix(0.7, 0.12, wet);
	SPECULAR = 0.5;
}
