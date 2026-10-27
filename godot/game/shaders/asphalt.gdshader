// A modern road: dark asphalt with grain, white dashed lines between the lanes and solid ones at the edges,
// tyre-polished tracks, and (after rain) puddles that mirror the lights
shader_type spatial;
uniform vec3 tar : source_color = vec3(0.16, 0.16, 0.17);
uniform vec3 paint_col : source_color = vec3(0.9, 0.9, 0.86);
uniform float wet = 0.2;
uniform float half_w = 4.6;
varying vec3 wp;
// a hash without sine (stable on every GPU, phones included)
float h21(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }
float vn(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) { return vn(p) * 0.55 + vn(p * 2.1 + 3.1) * 0.3 + vn(p * 4.3 + 7.7) * 0.15; }
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wp.xz;
	float ax = abs(wp.x);
	// the grain is 2.5 cm: it fades out before it gets finer than a pixel (where it would twinkle)
	vec2 fw = fwidth(p);
	float far = smoothstep(0.006, 0.02, max(fw.x, fw.y));
	float grain = mix(h21(floor(p * 40.0)), 0.5, far);
	vec3 col = tar * (0.85 + 0.3 * vn(p * 0.8)) * (0.92 + 0.16 * grain);
	// the polished tracks where the wheels run, a little darker and smoother
	float track = 1.0 - smoothstep(0.15, 0.4, abs(fract((wp.x + 0.8) / 1.6) - 0.5) * 1.6 - 0.35);
	col *= 1.0 - 0.12 * track;
	float rough = mix(0.75, 0.55, track);
	// lane lines: dashed between the lanes, solid near the kerb
	float aa = max(fwidth(ax), 0.002) * 1.5;
	float dz = fwidth(wp.z / 6.0) * 1.5;
	float dash = smoothstep(0.45 - dz, 0.45 + dz, fract(wp.z / 6.0)) * (1.0 - smoothstep(1.0 - dz, 1.0, fract(wp.z / 6.0)));
	float lane = (1.0 - smoothstep(0.05, 0.05 + aa, abs(ax - 0.8))) * dash * clamp(0.1 / (0.1 + aa), 0.0, 1.0);
	float edge = (1.0 - smoothstep(0.06, 0.06 + aa, abs(ax - (half_w - 0.5)))) * clamp(0.12 / (0.12 + aa), 0.0, 1.0);
	float line = max(lane, edge);
	col = mix(col, paint_col, line * 0.9);
	rough = mix(rough, 0.5, line);
	// puddles
	float pd = smoothstep(0.6 - wet * 0.3, 0.68 - wet * 0.3, fbm(p * vec2(0.25, 0.14) + 2.0)) * step(0.01, wet);
	col = mix(col, col * 0.3, pd);
	rough = mix(rough, 0.03, pd);
	rough = mix(rough, rough * 0.6, wet);
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.55;
}
