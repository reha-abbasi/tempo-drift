// Painted shop boards (London 1890): a board in its vertex colour with a thin gilt border and the shop's word in gilt
// pixel letters, lit by the street like any painted wood. COLOR.rgb = the board, COLOR.a = seed / 10.
shader_type spatial;

uniform vec4 gilt : source_color = vec4(0.95, 0.76, 0.38, 1.0);

#include "res://materials/gfx_world/sign_font.gdshaderinc"

varying flat vec4 tint;  // flat: the seed in its alpha goes through hash(), and blending it made every pixel random
varying vec3 wp;

void vertex() {
	tint = COLOR;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 size = sign_size(UV, wp);
	vec4 l = letters(UV, size, tint.a * 10.0, 0.6);
	vec2 e = min(UV, 1.0 - UV) * size;
	float edge = min(e.x, e.y);
	float border = 1.0 - smoothstep(0.02, 0.04, abs(edge - 0.07));
	float g = clamp(max(l.x * l.w + 0.3 * (1.0 - l.w) * step(0.12, edge), border), 0.0, 1.0);
	ALBEDO = mix(tint.rgb, gilt.rgb, g);
	METALLIC = g * 0.8;
	ROUGHNESS = mix(0.45, 0.3, g);
	EMISSION = gilt.rgb * g * 0.12;
}
