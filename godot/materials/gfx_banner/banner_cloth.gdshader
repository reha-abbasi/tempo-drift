shader_type spatial;
// A street banner's cloth: the baked artwork (scripts/banner_art.gd) with its cut-out edges (fringe, tassels,
// pennant points), swaying in the wind from the cable down; the back shows plain cloth. An LED panel ("stiff")
// keeps still and glows.
render_mode cull_disabled, depth_draw_opaque;

uniform sampler2D art : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 back_color : source_color = vec4(0.3, 0.1, 0.12, 1.0);
uniform float sway = 1.0;
uniform float phase = 0.0;
uniform float glow = 0.25;
uniform float stiff = 0.0;

void vertex() {
	float hang = pow(UV.y, 1.4) * (1.0 - stiff);
	float t = TIME + phase;
	float wave = sin(t * 1.7 + UV.x * 2.6) * 0.11 + sin(t * 4.3 + UV.x * 7.0 + UV.y * 5.0) * 0.025;
	VERTEX.z += wave * hang * sway;
	VERTEX.x += sin(t * 1.1 + UV.y * 2.0) * 0.03 * hang * sway;
}

void fragment() {
	vec4 a = texture(art, UV);
	if (a.a < 0.45) {
		discard;
	}
	if (FRONT_FACING) {
		ALBEDO = a.rgb;
		EMISSION = a.rgb * glow;
		// the folds catch the light a little differently
		float fold = sin(UV.x * 18.0 + TIME * 1.7) * 0.04 * (1.0 - stiff);
		ALBEDO *= 1.0 + fold;
	} else {
		ALBEDO = back_color.rgb;
		EMISSION = back_color.rgb * glow * 0.4;
	}
	ROUGHNESS = mix(0.86, 0.4, stiff);
	SPECULAR = 0.25;
}
