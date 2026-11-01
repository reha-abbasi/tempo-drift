// The Future's wet street: dark asphalt that mirrors the neon around it. Real reflections cost too much on a
// phone, so the shine is painted: long smears of the city's two accent colours (set by the city) and of the window
// light, stretched along the street the way a wet road stretches them, stronger towards the distance.
shader_type spatial;
render_mode cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile = 3.0;
uniform float darkness = 0.22;
uniform float shine = 1.0;
global uniform vec4 accent_a;
global uniform vec4 accent_b;

varying vec3 wpos;

float hash(float n) { return fract(sin(n * 91.345) * 47453.5453); }

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = wpos.xz / tile;
	ALBEDO = texture(albedo_tex, uv).rgb * darkness;
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	NORMAL_MAP_DEPTH = 0.6;
	ROUGHNESS = 0.18;
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
	EMISSION = c * s * shine * (0.15 + 1.4 * fres) * (0.6 + 0.4 * texture(albedo_tex, uv * 0.5).r);
}
