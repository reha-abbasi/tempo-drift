// The "New light & sky" try's sky (scripts/gfx_light.gd sets it per city): a deep gradient from the horizon
// to the zenith, the sun's disc with its glow spreading along the horizon, a haze band where the street's fog meets
// the sky, long streaks of cloud lit from below by the low sun, a city's own glow on the horizon at night, stars,
// and the sea below the horizon with the sun's path of light on it.
shader_type sky;

uniform vec4 zenith : source_color = vec4(0.12, 0.16, 0.36, 1.0);
uniform vec4 upper : source_color = vec4(0.55, 0.40, 0.50, 1.0);
uniform vec4 horizon : source_color = vec4(1.0, 0.62, 0.32, 1.0);
uniform vec4 haze : source_color = vec4(0.85, 0.60, 0.40, 1.0);
uniform float haze_amount = 0.5;
uniform vec4 ground : source_color = vec4(0.20, 0.16, 0.14, 1.0);
uniform vec3 sun_dir = vec3(0.0, 0.1, -1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.70, 0.40, 1.0);
uniform float sun_size = 0.03;       // the disc's radius (radians)
uniform float sun_disc = 4.0;        // how bright the disc is
uniform float sun_glow = 0.6;        // the broad glow round the sun
uniform float horizon_glow = 0.8;    // the warm band along the horizon under the sun
uniform float glow_width = 4.0;      // how narrow that band is (higher, narrower)
uniform vec4 cloud_lit : source_color = vec4(1.0, 0.62, 0.42, 1.0);
uniform vec4 cloud_shade : source_color = vec4(0.36, 0.26, 0.36, 1.0);
uniform float clouds = 0.0;          // how much of the sky the clouds cover (0 none)
uniform float cloud_scale = 1.0;
uniform vec4 city_glow : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float stars = 0.0;
uniform float sea = 0.0;
uniform vec4 sea_far : source_color = vec4(0.70, 0.42, 0.34, 1.0);
uniform vec4 sea_deep : source_color = vec4(0.05, 0.12, 0.24, 1.0);

float hash2(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + vec2(17.1, 3.7);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 D = EYEDIR;
	float h = D.y;
	vec3 sd = normalize(sun_dir);
	float mu = max(dot(D, sd), 0.0);
	// how close to the sun's side of the sky this direction looks, ignoring height
	vec2 dh = normalize(D.xz + vec2(1e-5));
	float side = max(dot(dh, normalize(sd.xz + vec2(1e-5))), 0.0);
	float hp = max(h, 0.0);
	vec3 c = mix(horizon.rgb, upper.rgb, smoothstep(0.0, 0.14, hp));
	c = mix(c, zenith.rgb, smoothstep(0.08, 0.65, hp));
	// the sun's colour spreads along the horizon on its side, and glows round the disc
	c += sun_color.rgb * horizon_glow * pow(side, glow_width) * exp(-hp * 9.0);
	c += sun_color.rgb * (pow(mu, 8.0) * sun_glow + pow(mu, 90.0) * sun_glow * 1.5);
	c += city_glow.rgb * exp(-hp * 7.0);
	if (stars > 0.0 && h > 0.05) {
		vec3 q = floor(D * 480.0);
		float n = fract(sin(dot(q, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
		c += vec3(step(0.997, n) * stars * smoothstep(0.05, 0.35, h));
	}
	// the disc, behind the clouds
	float disc = smoothstep(cos(sun_size), cos(sun_size * 0.8), dot(D, sd));
	c += sun_color.rgb * sun_disc * disc;
	if (clouds > 0.0 && h > 0.0) {
		// a cloud deck seen from below: flat-projected, stretched across the street into long streaks
		vec2 p = D.xz / (h + 0.08) * cloud_scale;
		float n = fbm(vec2(p.x * 0.35, p.y * 1.4) + vec2(3.0, 0.0));
		float cover = smoothstep(1.0 - clouds, 1.0 - clouds + 0.28, n);
		cover *= smoothstep(0.0, 0.05, h) * (1.0 - smoothstep(0.45, 0.9, h) * 0.6);
		float lit = pow(side, 2.0) * exp(-hp * 3.0);
		vec3 cc = mix(cloud_shade.rgb, cloud_lit.rgb, clamp(lit + (1.0 - n) * 0.25, 0.0, 1.0));
		cc += sun_color.rgb * pow(mu, 12.0) * 1.4;
		c = mix(c, cc, cover * 0.92);
	}
	// haze where the sky meets the street's fog
	c = mix(c, haze.rgb + sun_color.rgb * pow(side, 6.0) * 0.25, haze_amount * exp(-abs(h) * 14.0));
	if (h < 0.0) {
		vec3 g = mix(haze.rgb, ground.rgb, smoothstep(0.0, 0.2, -h));
		if (sea > 0.0) {
			vec3 w = mix(sea_far.rgb, sea_deep.rgb, smoothstep(0.0, 0.09, -h));
			// the sun's path on the water: a column under the sun, broken into glints
			vec3 r = vec3(D.x, -h, D.z);
			float g2 = max(dot(r, sd), 0.0);
			float glint = 0.55 + 0.45 * noise(vec2(D.x * 900.0, -h * 3000.0));
			w += sun_color.rgb * (pow(g2, 300.0) * 3.0 * glint + pow(side, 160.0) * exp(h * 40.0) * 0.9 * glint);
			g = mix(g, w, sea);
		}
		c = mix(c, g, smoothstep(0.0, 0.015, -h));
	}
	COLOR = c;
}
