shader_type spatial;

// Plain wall with a grid of windows, computed from the mesh's local position
// so the pattern sticks to the building as it scrolls past.

uniform vec3 wall : source_color = vec3(0.9, 0.6, 0.4);
uniform vec3 window_color : source_color = vec3(0.16, 0.25, 0.36);
uniform vec3 frame_color : source_color = vec3(0.95, 0.95, 0.92);

varying vec3 lpos;
varying vec3 lnorm;

void vertex() {
	lpos = VERTEX;
	lnorm = NORMAL;
}

void fragment() {
	vec3 col = wall;
	float rough = 0.85;
	// pick the horizontal coordinate that runs along this face
	float u = abs(lnorm.x) > 0.5 ? lpos.z : lpos.x;
	float y = lpos.y;
	bool vertical_face = abs(lnorm.y) < 0.5;
	if (vertical_face) {
		vec2 cell = vec2(fract(u / 1.6 + 0.5), fract(y / 1.5));
		vec2 d = abs(cell - vec2(0.5, 0.55));
		if (d.x < 0.26 && d.y < 0.3) {
			col = window_color;
			rough = 0.15;
		} else if (d.x < 0.31 && d.y < 0.35) {
			col = frame_color;
		}
	}
	ALBEDO = col;
	ROUGHNESS = rough;
}
