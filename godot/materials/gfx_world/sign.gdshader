// Lit signs (Berlin 2075's neon, Rio's shop signs): a dark panel in a lit frame, a real word in glowing pixel letters
// and the soft glow of the tubes around them. A building's signs share this one material: each sign's colour and
// seed come from its vertices (COLOR.rgb, COLOR.a = seed / 10), as in neon_sign.gdshader.
shader_type spatial;
render_mode unshaded;

uniform float energy = 3.2;

#include "res://materials/gfx_world/sign_font.gdshaderinc"

varying flat vec4 tint;  // flat: the seed in its alpha goes through hash(), and blending it made every pixel random
varying vec3 wp;

void vertex() {
	tint = COLOR;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 col = tint.rgb;
	float sd = tint.a * 10.0;
	vec2 size = sign_size(UV, wp);
	vec4 l = letters(UV, size, sd, 0.72);
	// the frame: a lit line inset from the edge, glowing to both sides
	vec2 e = min(UV, 1.0 - UV) * size;
	float edge = min(e.x, e.y);
	float ft = clamp(l.z * 0.5, 0.03, 0.12);
	float frame = 1.0 - smoothstep(ft * 0.5, ft, abs(edge - ft * 1.5));
	float frame_glow = exp(-abs(edge - ft * 1.5) / ft * 0.8);
	float flick = 1.0 - 0.7 * step(0.993, hash(floor(TIME * 9.0) + sd * 31.0));
	vec3 panel = col * 0.06 + vec3(0.01);
	vec3 tube = mix(col, vec3(1.0), 0.5);
	vec3 light = (tube * l.x + col * l.y * 0.3) * l.w + col * 0.22 * (1.0 - l.w);
	light += mix(col, vec3(1.0), 0.35) * frame + col * frame_glow * 0.25;
	// far down the street the signs dim, so the rings stay the brightest things there
	float far = mix(1.0, 0.4, smoothstep(60.0, 160.0, length(VERTEX)));
	ALBEDO = panel + light * energy * flick * far;
}
