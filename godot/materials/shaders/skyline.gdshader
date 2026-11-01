// The far city: tower silhouettes in the haze with a few lit windows, as the web game paints its horizon.
// Not fogged (the haze is in the colour), so the skyline stays on the horizon however thick the street fog is.
shader_type spatial;
render_mode unshaded, fog_disabled;

uniform vec4 color : source_color = vec4(0.12, 0.12, 0.17, 1.0);
uniform vec4 window_color : source_color = vec4(1.0, 0.82, 0.55, 1.0);
uniform float lit = 0.3;
uniform vec4 haze : source_color = vec4(0.6, 0.6, 0.6, 1.0);
uniform float haze_amount = 0.35;

varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void vertex() {
	wpos = VERTEX;
}

void fragment() {
	vec2 cell = vec2(floor((wpos.x + wpos.z) / 1.8), floor(wpos.y / 2.6));
	vec2 f = fract(vec2((wpos.x + wpos.z) / 1.8, wpos.y / 2.6));
	float win = step(0.25, f.x) * step(f.x, 0.75) * step(0.3, f.y) * step(f.y, 0.75);
	float on = step(1.0 - lit, hash(cell)) * win;
	// the base of the skyline fades into the haze
	float base = smoothstep(0.0, 40.0, wpos.y);
	vec3 c = mix(haze.rgb, color.rgb, mix(0.25, 1.0, base) * (1.0 - haze_amount));
	ALBEDO = mix(c, window_color.rgb * 1.6, on * (0.6 + 0.4 * hash(cell + 7.0)) * base);
}
