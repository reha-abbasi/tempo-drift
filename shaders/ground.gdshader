shader_type spatial;

// One big ground plane: gravel + sleepers + rails for the 3 lanes,
// paving stones on the sidewalks, sand beyond. `offset` scrolls the
// pattern toward the camera so the ground feels like it is moving.

uniform float offset = 0.0;
uniform float lane_width = 2.5;
uniform float track_half_width = 3.9;
uniform float sidewalk_edge = 8.0;
uniform vec3 gravel : source_color = vec3(0.50, 0.47, 0.44);
uniform vec3 sleeper : source_color = vec3(0.40, 0.29, 0.21);
uniform vec3 rail : source_color = vec3(0.62, 0.6, 0.58);
uniform vec3 paving : source_color = vec3(0.86, 0.83, 0.78);
uniform vec3 sand : source_color = vec3(0.93, 0.84, 0.64);

varying vec3 wpos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float x = wpos.x;
	float z = wpos.z - offset;
	vec3 col;
	float rough = 0.95;
	float metal = 0.0;
	float ax = abs(x);
	if (ax < track_half_width) {
		col = gravel * (0.88 + 0.2 * hash(floor(vec2(x, z) * 14.0)));
		float lx = x - lane_width * round(x / lane_width);
		float s = fract(z / 1.2);
		if (abs(lx) < 0.95 && s < 0.32) {
			col = sleeper * (0.9 + 0.15 * hash(vec2(floor(z / 1.2), round(x / lane_width))));
		}
		if (abs(abs(lx) - 0.62) < 0.06) {
			col = rail;
			rough = 0.35;
			metal = 0.25;
		}
	} else if (ax < sidewalk_edge) {
		vec2 t = vec2(fract(x / 1.0), fract(z / 1.0));
		float grout = step(0.94, max(t.x, t.y));
		col = mix(paving * (0.93 + 0.1 * hash(floor(vec2(x, z)))), paving * 0.7, grout);
		// curb
		if (ax < track_half_width + 0.3) col = vec3(0.7, 0.7, 0.72);
	} else {
		col = sand * (0.92 + 0.12 * hash(floor(vec2(x, z) * 3.0)));
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
}
