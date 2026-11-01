// The sky of each city, as the web game paints it (its sky dome shader, ported): horizon, middle and top colours,
// the sun's glow ahead, the sea below the horizon where a city has one, stars, and a moon with its crescent cut.
shader_type sky;

uniform vec4 top : source_color = vec4(0.44, 0.53, 0.79, 1.0);
uniform vec4 mid : source_color = vec4(0.77, 0.65, 0.78, 1.0);
uniform vec4 hor : source_color = vec4(1.0, 0.73, 0.58, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.82, 0.63, 1.0);
uniform vec3 sun_dir = vec3(0.12, 0.07, -1.0);
uniform vec4 low : source_color = vec4(0.16, 0.35, 0.54, 1.0);
uniform float sea = 0.0;
uniform float stars = 0.0;
uniform vec3 moon_dir = vec3(0.0, 0.0, -1.0);
uniform vec3 moon_cut = vec3(0.0, -1.0, 0.0);
uniform float moon_r = 0.0;

void sky() {
	vec3 D = EYEDIR;
	float h = D.y;
	vec3 sd = normalize(sun_dir);
	vec3 c = mix(hor.rgb, mid.rgb, smoothstep(0.0, 0.16, h));
	c = mix(c, top.rgb, smoothstep(0.16, 0.6, h));
	c = mix(c, hor.rgb * 0.85, smoothstep(0.0, -0.25, h));
	if (sea > 0.0 && h < 0.0) {
		vec3 w = mix(hor.rgb * 0.85, low.rgb, smoothstep(0.0, 0.07, -h));
		vec3 r = vec3(D.x, -h, D.z);
		float g = max(dot(r, sd), 0.0);
		float sh = 0.5 + 0.5 * sin(D.x * 260.0 / (0.015 - h) + TIME * 2.4) * sin(-h * 900.0 + TIME * 1.3);
		w += sun_color.rgb * (pow(g, 240.0) * 2.6 * sh + pow(g, 14.0) * 0.22 * (0.6 + 0.4 * sh));
		c = mix(c, w, sea);
	}
	if (stars > 0.0 && h > 0.02) {
		vec3 q = floor(D * 520.0);
		float n = fract(sin(dot(q, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
		c += vec3(step(0.9965, n) * stars * smoothstep(0.02, 0.25, h) * (0.65 + 0.35 * sin(TIME * 2.0 + n * 90.0)));
	}
	if (moon_r > 0.0) {
		float m = acos(clamp(dot(D, normalize(moon_dir)), -1.0, 1.0));
		float k = 1.0 - smoothstep(moon_r * 0.9, moon_r, m);
		k *= smoothstep(moon_r * 0.9, moon_r, acos(clamp(dot(D, normalize(moon_cut)), -1.0, 1.0)));
		c += vec3(0.7, 0.75, 1.0) * 0.22 * exp(-m / moon_r * 0.9);
		c = mix(c, vec3(1.25, 1.2, 1.1), k);
	}
	float s = max(dot(D, sd), 0.0);
	c += sun_color.rgb * (pow(s, 900.0) * 6.0 + pow(s, 40.0) * 0.5 + pow(s, 6.0) * 0.18);
	COLOR = c;
}
