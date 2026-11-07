// Copacabana's beach and the Atlantic in one sheet, in world space: dry and wet sand, the swash running up the
// beach, lines of surf rolling in, and the sea deepening to the horizon, catching the low sun.
shader_type spatial;
render_mode specular_schlick_ggx;

uniform vec4 sand : source_color = vec4(0.96, 0.85, 0.67, 1.0);
uniform vec4 wet_sand : source_color = vec4(0.64, 0.53, 0.41, 1.0);
uniform vec4 shallow : source_color = vec4(0.1, 0.72, 0.7, 1.0);
uniform vec4 deep : source_color = vec4(0.02, 0.28, 0.48, 1.0);
uniform vec4 foam : source_color = vec4(0.97, 0.98, 1.0, 1.0);
uniform float shore = 13.6;  // where the water starts (m from the street's middle)

varying vec3 wp;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float t = TIME;
	float z = wp.z;
	// the swash: the water's edge runs up the sand and back
	float run = 0.9 * sin(t * 0.7 + z * 0.021) + 0.5 * sin(z * 0.11 + 1.3) + 0.6 * noise(vec2(z * 0.07, t * 0.25));
	float d = wp.x - (shore - run);
	float far = wp.x - shore;
	// sand, darker where the sea has just been
	float grain = noise(wp.xz * 7.0) * 0.07 + noise(wp.xz * 0.6) * 0.06;
	vec3 sandc = mix(sand.rgb, wet_sand.rgb, smoothstep(-7.0, -0.2, d)) * (0.94 + grain);
	// surf: broken lines of white water rolling in towards the beach
	float ph = far * 0.1 + t * 0.32 + 0.6 * sin(z * 0.033) + 0.3 * sin(z * 0.087 + 2.0);
	float line = pow(max(sin(ph * 6.2831853), 0.0), 6.0);
	float broken = smoothstep(0.3, 0.7, noise(vec2(z * 0.1, far * 0.08 - t * 0.2)));
	float aa = clamp(1.2 - fwidth(ph) * 2.5, 0.0, 1.0);
	float crest = line * broken * (1.0 - smoothstep(10.0, 110.0, far)) * smoothstep(0.5, 3.0, far) * aa;
	float edge = (1.0 - smoothstep(0.2, 3.0, d)) * (0.6 + 0.4 * noise(vec2(z * 0.5, t)));
	float f = clamp(max(crest, edge), 0.0, 1.0);
	vec3 water = mix(shallow.rgb, deep.rgb, smoothstep(2.0, 110.0, far));
	vec3 sea = mix(water, foam.rgb, f);
	float wet = smoothstep(-0.15, 0.15, d);
	ALBEDO = mix(sandc, sea, wet);
	ROUGHNESS = mix(0.95, mix(0.05, 0.6, f), wet);
	SPECULAR = mix(0.15, 0.7, wet);
	// small waves catch the low sun
	vec2 q = wp.xz * vec2(0.42, 0.25) + vec2(t * 0.3, t * 0.12);
	float n0 = noise(q);
	vec3 wn = normalize(vec3((n0 - noise(q + vec2(0.3, 0.0))) * 2.2, 1.0, (n0 - noise(q + vec2(0.0, 0.3))) * 2.2));
	// white water catches the light even when the sun is low
	EMISSION = foam.rgb * f * wet * 0.3;
	NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(wn, 0.0)).xyz, wet * (1.0 - f)));
}
