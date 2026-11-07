// London's wet cobbles: the street's own cobblestone photo, darker and glossier in the gutters by the kerbs, puddles
// lying in the dips that mirror the sky and the lamps (rain rings spreading on them), and the horse tram's iron rails
// set into the middle lane. In world space, so it runs on unbroken from section to section.
shader_type spatial;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D orm_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile = 2.4;        // metres per texture repeat
uniform float puddles = 0.42;    // how much of the street is under water
uniform float rails = 0.72;      // half the gauge of the tram line (m)

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
	vec2 uv = wp.xz / tile;
	vec3 alb = texture(albedo_tex, uv).rgb;
	vec3 orm = texture(orm_tex, uv).rgb;
	vec3 nm = texture(normal_tex, uv).rgb;
	// where the water lies: dips across the street, and the gutters by both kerbs
	float n = noise(wp.xz * vec2(0.32, 0.16)) * 0.65 + noise(wp.xz * vec2(1.1, 0.7)) * 0.35;
	float gutter = smoothstep(3.3, 4.3, abs(wp.x));
	float lowness = 1.0 - orm.g;  // the joints between the stones hold water first
	float water = smoothstep(1.0 - puddles, 1.0 - puddles + 0.08, n + gutter * 0.45 + lowness * 0.12);
	float damp = 0.55 + 0.45 * smoothstep(0.2, 0.9, n + gutter);
	// the tram rails: a polished iron head with a dark groove beside it
	float rx = abs(abs(wp.x) - rails);
	float rail = 1.0 - smoothstep(0.03, 0.045, rx);
	float groove = (1.0 - smoothstep(0.015, 0.03, abs(abs(wp.x) - rails - 0.07))) * (1.0 - rail);
	float aa = clamp(1.5 - fwidth(wp.x) * 12.0, 0.0, 1.0);
	rail *= aa;
	groove *= aa;
	// rain rings on the puddles
	vec2 cellp = wp.xz / 0.7;
	vec2 c = floor(cellp);
	vec2 f = fract(cellp) - 0.5;
	f += (vec2(hash(c + 3.1), hash(c + 5.7)) - 0.5) * 0.3;
	float ph = fract(TIME * 0.7 + hash(c) * 7.0);
	float drop = step(0.6, hash(c + floor(TIME * 0.7 + hash(c) * 7.0)));
	float ring = (1.0 - smoothstep(0.0, 0.03, abs(length(f) - ph * 0.4))) * (1.0 - ph) * water * aa * drop;
	vec3 wet = alb * mix(1.0, 0.5, damp);
	ALBEDO = mix(mix(wet, alb * 0.18, water), vec3(0.22, 0.22, 0.24), rail);
	ALBEDO *= 1.0 - groove * 0.7;
	ROUGHNESS = mix(mix(orm.g * mix(1.0, 0.55, damp), 0.02, water), 0.22, rail);
	METALLIC = rail * 0.9;
	SPECULAR = mix(0.5, 0.9, water);
	AO = orm.r;
	NORMAL_MAP = mix(nm, vec3(0.5 + ring * 0.18, 0.5 + ring * 0.18, 1.0), max(water * 0.92, rail));
}
