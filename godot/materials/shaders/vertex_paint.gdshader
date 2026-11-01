// Painted parts merged into one surface (one draw instead of one per colour). Each vertex carries
// its part's colour in COLOR.rgb; COLOR.a packs metal and roughness: a = 0.5 * metal + 0.49 * roughness.
shader_type spatial;

void fragment() {
	float metal = step(0.5, COLOR.a);
	ALBEDO = COLOR.rgb;
	METALLIC = metal;
	ROUGHNESS = clamp((COLOR.a - 0.5 * metal) / 0.49, 0.03, 1.0);
}
