// Glowing parts (lamps, LED lines, tail lights) merged into one surface. COLOR.rgb is the light's
// colour; COLOR.a is its strength / 8.
shader_type spatial;

void fragment() {
	ALBEDO = COLOR.rgb * 0.3;
	ROUGHNESS = 0.3;
	EMISSION = COLOR.rgb * COLOR.a * 8.0;
}
