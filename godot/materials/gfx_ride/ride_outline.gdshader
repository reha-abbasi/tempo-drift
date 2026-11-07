// The new cars' outline: the body drawn again a little bigger, inside out, in one flat
// colour, so a thin line rings the car against any background: dark on a bright street, the city's neon at night.
// grow is in metres at 10 m from the camera and scales with distance, so the line keeps about the same width.
shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled;

uniform vec4 color : source_color = vec4(0.03, 0.03, 0.05, 1.0);
uniform float energy = 1.0;
uniform float grow = 0.016;

void vertex() {
	float dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	VERTEX += NORMAL * grow * clamp(dist / 10.0, 0.4, 2.0);
}

void fragment() {
	ALBEDO = color.rgb * energy;
}
