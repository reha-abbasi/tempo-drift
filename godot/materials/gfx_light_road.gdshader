// The "New light & sky" try's wet street (scripts/gfx_light.gd swaps it in for road_wet): the same painted
// smears of neon, on a glossier road whose puddles mirror the neon and the lit windows (from the street's
// reflection probe), with rain rippling them. The mirror is softest and weakest close to the camera, where the
// rings and the traffic are, and strongest a little way down the street.
shader_type spatial;
render_mode cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile = 3.0;
uniform float darkness = 0.22;
uniform float shine = 1.0;
uniform float rough = 0.14;       // the road's roughness between the puddles
uniform float wet = 0.6;          // how much of the road the puddles cover (0..1)
uniform float mirror_near = 10.0;        // the mirror fades in from this far from the camera (m)
uniform float mirror_full = 40.0;       // to its full strength this far away (m)
uniform float ripples = 0.35;     // how strongly the rain ripples the puddles
global uniform vec4 accent_a;
global uniform vec4 accent_b;

varying vec3 wpos;

float hash(float n) { return fract(sin(n * 91.345) * 47453.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i.x + i.y * 57.0);
	float b = hash(i.x + 1.0 + i.y * 57.0);
	float c = hash(i.x + (i.y + 1.0) * 57.0);
	float d = hash(i.x + 1.0 + (i.y + 1.0) * 57.0);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// the slope of the rain's rings on the water round p (in cells of 1 m), each cell its own drop at its own time
vec2 ripple(vec2 p, float t) {
	vec2 cell = floor(p);
	vec2 f = fract(p) - 0.5;
	float k = hash(cell.x + cell.y * 113.0);
	vec2 o = vec2(hash(k * 7.0 + 1.0), hash(k * 13.0 + 2.0)) - 0.5;
	float ph = fract(t * 0.8 + k);
	vec2 d = f - o * 0.4;
	float r = length(d) + 1e-4;
	float x = r - ph * 0.45;
	float w = sin(x * 50.0) * exp(-abs(x) * 30.0) * (1.0 - ph);
	return d / r * w;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wpos.xz / tile;
	// puddles: patches where the road is wetter, darker, flatter and shinier
	float n = vnoise(wpos.xz * vec2(0.45, 0.12)) * 0.65 + vnoise(wpos.xz * vec2(1.3, 0.4) + 7.0) * 0.35;
	float pud = smoothstep(1.0 - wet, 1.0 - wet + 0.18, n);
	// close to the camera the road is mostly plain wet asphalt; the puddles come in further down the street
	float dist = length(VERTEX);
	float far_k = smoothstep(mirror_near, mirror_full, dist);
	pud *= mix(0.1, 1.0, far_k);
	ALBEDO = texture(albedo_tex, uv).rgb * darkness * (1.0 - 0.5 * pud);
	vec3 nm = texture(normal_tex, uv).rgb * 2.0 - 1.0;
	nm.xy *= mix(0.6, 0.15, pud);
	nm.xy += (ripple(wpos.xz * 1.6, TIME) + ripple(wpos.xz * 1.1 + 0.5, TIME * 0.9 + 0.37)) * ripples * pud;
	NORMAL_MAP = normalize(nm) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.0;
	ROUGHNESS = mix(mix(0.45, rough, far_k), 0.07, pud);
	SPECULAR = mix(0.5, 0.65, pud) * mix(0.3, 1.0, far_k);
	METALLIC = 0.0;
	// smears: columns across the road (one per sign or window column), broken up along the street
	float col = floor(wpos.x * 2.2);
	float h = hash(col);
	float along = pow(0.5 + 0.5 * sin(wpos.z * (0.12 + 0.16 * hash(col + 3.0)) + h * 40.0), 6.0);
	// puddles: patches where the road is wetter and shines more
	float puddle = smoothstep(0.55, 0.8, texture(albedo_tex, wpos.xz / 37.0).g * 1.6);
	float side = smoothstep(1.0, 4.4, abs(wpos.x));
	vec3 c = mix(accent_a.rgb, accent_b.rgb, step(0.5, hash(col + 7.0)));
	c = mix(c, vec3(1.0, 0.85, 0.6), step(0.75, hash(col + 11.0)));
	float s = step(0.45, h) * along * (0.2 + 0.8 * side) * (0.35 + puddle);
	// far away the road is a mirror (Fresnel), close by mostly dark
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = c * s * shine * mix(0.3, 1.0, far_k) * (0.15 + 1.4 * fres) * (0.6 + 0.4 * texture(albedo_tex, uv * 0.5).r);
}
