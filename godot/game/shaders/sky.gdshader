// A soft late-afternoon London sky: a grey-blue overcast above, warm toward the horizon, the low sun glowing through
// a break in the clouds. Static, so the reflections it lights are worked out once
shader_type sky;
render_mode use_half_res_pass;
uniform vec3 top_col : source_color = vec3(0.3, 0.34, 0.43);
uniform vec3 mid_col : source_color = vec3(0.53, 0.52, 0.53);
uniform vec3 low_col : source_color = vec3(0.86, 0.7, 0.52);
uniform vec3 hor_col : source_color = vec3(1.0, 0.78, 0.52);
uniform vec3 sun_col : source_color = vec3(1.0, 0.82, 0.58);
uniform vec3 cloud_col : source_color = vec3(0.4, 0.4, 0.44);
uniform float cover = 0.55;
// an aurora over the north (Reykjavik), and the glow of a big city on the horizon at night (the Future)
uniform float aurora = 0.0;
uniform vec3 city_glow : source_color = vec3(0.0);
uniform float stars = 0.0;
// a hash without sine (stable on every GPU, phones included)
float h21(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float a = 0.5, s = 0.0;
	for (int i = 0; i < 5; i++) { s += vn(p) * a; p = p * 2.03 + 1.7; a *= 0.5; }
	return s;
}
void sky() {
	vec3 d = EYEDIR;
	float e = d.y;
	vec3 c = hor_col;
	c = mix(c, low_col, smoothstep(0.0, 0.07, e));
	c = mix(c, mid_col, smoothstep(0.05, 0.24, e));
	c = mix(c, top_col, smoothstep(0.2, 0.75, e));
	vec3 L = LIGHT0_ENABLED ? LIGHT0_DIRECTION : normalize(vec3(0.2, 0.05, -1.0));
	float sd = max(dot(d, L), 0.0);
	// clouds on a flat layer above, thinning toward the sun
	if (e > 0.0) {
		vec2 cp = d.xz / (e + 0.08) * 1.6;
		float n = fbm(cp + vec2(3.0, 1.0));
		float m = smoothstep(cover - 0.15, cover + 0.2, n) * smoothstep(0.0, 0.12, e);
		m *= 1.0 - 0.55 * pow(sd, 6.0);
		vec3 cc = cloud_col * (0.85 + 0.3 * fbm(cp * 2.0)) + sun_col * pow(sd, 3.0) * 0.6;
		// lit rims where the sun catches the edges
		cc += sun_col * smoothstep(0.1, 0.0, abs(n - cover)) * pow(sd, 2.0) * 0.5;
		c = mix(c, cc, m * 0.85);
	} else {
		c = mix(hor_col, low_col * 0.7, smoothstep(0.0, -0.25, e));
	}
	c += sun_col * (pow(sd, 6.0) * 0.35 + pow(sd, 60.0) * 1.2 + pow(sd, 900.0) * 6.0);
	if (aurora > 0.0 && e > 0.0) {
		// curtains of light: bands that wave across the sky, green below and violet at the top
		vec2 ap = d.xz / (e + 0.25);
		float band = sin(ap.x * 2.0 + fbm(ap * 0.7) * 6.0) * 0.5 + 0.5;
		float curtain = pow(band, 6.0) * smoothstep(0.05, 0.3, e) * smoothstep(0.85, 0.35, e) * (0.6 + 0.8 * fbm(ap * vec2(5.0, 0.5)));
		c += mix(vec3(0.2, 1.0, 0.55), vec3(0.6, 0.3, 1.0), smoothstep(0.2, 0.6, e)) * curtain * aurora;
	}
	if (stars > 0.0 && e > 0.05) {
		vec2 sp = d.xz / (e + 0.2) * 60.0;
		float st = step(0.996, h21(floor(sp))) * smoothstep(0.05, 0.3, e);
		c += vec3(st) * stars;
	}
	c += city_glow * smoothstep(0.25, 0.0, abs(e - 0.02)) * 1.2;
	COLOR = c;
}
