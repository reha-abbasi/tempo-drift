shader_type spatial;
render_mode unshaded;
uniform vec4 color : source_color = vec4(1.0, 0.2, 0.6, 1.0);
uniform float energy = 3.0;
uniform float seed = 1.0;
uniform vec2 grid = vec2(1.0, 4.0); // glyphs across and down
// a building's signs share one material: each sign's colour and seed then come from its vertices (MeshKit)
uniform bool vertex_tint = false;
varying flat vec4 tint;  // flat: the seed in its alpha goes through hash(), and blending it made every pixel random
float hash(vec2 p, float s) { return fract(sin(dot(p, vec2(12.9898, 78.233)) + s * 17.0) * 43758.5453); }
void vertex() { tint = COLOR; }
void fragment() {
	vec3 col = vertex_tint ? tint.rgb : color.rgb;
	float sd = vertex_tint ? tint.a * 10.0 : seed;
	vec2 g = UV * grid;
	vec2 cell = floor(g);
	vec2 f = fract(g) * 1.25 - 0.125;
	// each glyph: a few strokes on a 3x3 lattice
	vec2 q = floor(clamp(f, 0.0, 0.999) * 3.0);
	vec2 r = fract(clamp(f, 0.0, 0.999) * 3.0);
	float on = step(0.45, hash(cell * 3.1 + q, sd));
	float stroke = max(step(abs(r.x - 0.5), 0.16) * step(0.5, hash(cell + q + 0.3, sd)), step(abs(r.y - 0.5), 0.16) * step(0.5, hash(cell + q + 0.7, sd)));
	float inside = step(0.0, f.x) * step(f.x, 1.0) * step(0.0, f.y) * step(f.y, 1.0);
	float glyph = on * stroke * inside;
	float border = max(step(UV.x, 0.03), step(0.97, UV.x)) + max(step(UV.y, 0.02), step(0.98, UV.y));
	float flicker = 1.0 - 0.6 * step(0.985, fract(sin(floor(TIME * 8.0) + sd * 9.0) * 43758.5));
	vec3 base = col * 0.08;
	ALBEDO = base + col * energy * flicker * clamp(glyph + border, 0.0, 1.0);
}