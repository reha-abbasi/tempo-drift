// A note ring: a bright band of light in its height's colour, brighter on the beat; the inside faintly filled.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.89, 0.72, 1.0);
uniform float energy = 2.6;
uniform float fill = 0.12;   // how much the inside disc shows
uniform float alpha = 1.0;   // fades a played or missed ring

void fragment() {
	// UV.x across the band (0 inside edge .. 1 outside edge) for the torus; the disc uses a radial UV
	float edge = 1.0 - abs(UV.y - 0.5) * 2.0;
	ALBEDO = color.rgb * energy * mix(fill, 1.0, step(0.01, edge)) * alpha;
	ALPHA = alpha;
}
