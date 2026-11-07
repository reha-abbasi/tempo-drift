// Berlin's TV tower over the skyline: a clear silhouette even through the night haze. Each vertex carries its part's
// colour (COLOR.rgb) and how brightly it is lit (COLOR.a: 0 concrete and steel, up to 1 the LED lines and beacons).
// The haze is drawn here, lighter than the city's fog, so the hero of the skyline never melts away.
shader_type spatial;
render_mode unshaded, fog_disabled;

uniform vec4 haze : source_color = vec4(0.17, 0.11, 0.21, 1.0);
uniform float haze_amount = 0.45;
uniform float energy = 6.0;

varying vec4 c;
varying float h;

void vertex() {
	c = COLOR;
	h = VERTEX.y;
}

void fragment() {
	// the concrete catches the city's glow from below, fading up the shaft
	vec3 body = c.rgb * mix(1.25, 0.8, clamp(h / 160.0, 0.0, 1.0));
	vec3 lit = c.rgb * energy * c.a;
	float blink = c.a > 0.95 ? step(0.5, fract(TIME * 0.7)) : 1.0;
	ALBEDO = mix(body, haze.rgb, haze_amount) * (1.0 - c.a) + lit * blink;
}
