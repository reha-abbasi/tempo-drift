// Landmarks and roofs far away: flat shapes in the haze, darker the nearer they are, sinking into the mist at the bottom,
// with faint vertical ribs like stonework seen from a distance
shader_type spatial;
render_mode unshaded, fog_disabled;
uniform vec3 near_col : source_color = vec3(0.3, 0.29, 0.31);
uniform vec3 haze_col : source_color = vec3(0.88, 0.75, 0.6);
uniform float depth = 0.5;
uniform float ribs = 0.6;
uniform float lattice = 0.0;
uniform float lights = 0.0;
uniform float arches = 0.0;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float mist = 1.0 - smoothstep(-2.0, 28.0, wp.y);
	vec3 c = mix(near_col, haze_col, clamp(depth + mist * 0.4, 0.0, 1.0));
	c *= 1.0 - 0.06 * ribs * step(0.55, fract((wp.x + wp.z) * ribs));
	// open ironwork: cross-bracing in a diagonal grid, the gaps cut out
	if (lattice > 0.5) {
		vec2 g = vec2(wp.x + wp.z + wp.y, wp.x + wp.z - wp.y) * 0.45;
		vec2 f = abs(fract(g) - 0.5);
		if (min(f.x, f.y) > 0.12 && fract(wp.y * 0.12) > 0.1) discard;
	}
	// rows of arches (the Colosseum)
	if (arches > 0.5) {
		float ang = atan(wp.x - MODEL_MATRIX[3].x, wp.z - MODEL_MATRIX[3].z) * 18.0;
		vec2 g = vec2(fract(ang / 6.2832 * 6.0), fract((wp.y - MODEL_MATRIX[3].y) / 8.0));
		float hole = step(abs(g.x - 0.5), 0.3) * step(0.15, g.y) * step(g.y, 0.75);
		c *= 1.0 - 0.6 * hole;
	}
	ALBEDO = c;
	// lit windows on towers at night: a fine grid, some windows on
	if (lights > 0.0) {
		vec2 g = vec2(wp.x + wp.z, wp.y) / vec2(1.6, 2.2);
		vec2 f = fract(g);
		vec3 p3 = fract(vec3(floor(g).xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33);
		float on = step(1.0 - 0.45 * lights, fract((p3.x + p3.y) * p3.z));
		float win = step(0.25, f.x) * step(f.x, 0.75) * step(0.3, f.y) * step(f.y, 0.8);
		EMISSION = vec3(1.0, 0.78, 0.45) * on * win * 1.6 * (1.0 - depth * 0.6);
	}
}
