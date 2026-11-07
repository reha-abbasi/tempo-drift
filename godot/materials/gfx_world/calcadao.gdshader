// Copacabana's promenade: black and white Portuguese stones laid in waves along the shore. Drawn in world space,
// so the street's own pavement and the wide promenade beyond it join without a seam.
shader_type spatial;

uniform vec4 light_stone : source_color = vec4(0.93, 0.91, 0.86, 1.0);
uniform vec4 dark_stone : source_color = vec4(0.07, 0.07, 0.08, 1.0);
uniform float band = 1.15;     // width of one black or white band across the walk (m)
uniform float wave_len = 4.6;  // length of one wave along the walk (m)
uniform float wave_amp = 0.8;  // how far a wave swings across (m)
uniform float stone = 0.085;   // size of one stone (m)

varying vec3 wp;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// the waves: bands along the shore whose edges swing like the sea (mirrored on the other side of the street)
	float x = abs(wp.x);
	float s = sin((x + wave_amp * sin(wp.z * 6.2831853 / wave_len)) / band * 3.14159265);
	float w = max(fwidth(s) * 1.5, 0.0001);
	float dark = smoothstep(-w, w, s);
	// the stones, set in rows, fade into an even tone far away
	vec2 p = wp.xz / stone;
	p.x += floor(p.y) * 0.5;
	vec2 c = floor(p);
	vec2 g = fract(p);
	float aa = clamp(1.6 - fwidth(p.x) * 2.5, 0.0, 1.0);
	float joint = smoothstep(0.0, 0.14, min(min(g.x, 1.0 - g.x), min(g.y, 1.0 - g.y)));
	vec3 col = mix(light_stone.rgb, dark_stone.rgb, dark);
	col *= 1.0 + (hash(c) - 0.5) * 0.16 * aa;
	col *= mix(1.0, mix(0.68, 1.0, joint), aa);
	ALBEDO = col;
	ROUGHNESS = mix(0.75, 0.55, dark);
	SPECULAR = 0.35;
}
