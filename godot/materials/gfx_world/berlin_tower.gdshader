// Berlin 2075's curtain walls, one window per UV cell (a bay wide, a floor tall): dark glass and thin mullions, rooms
// lit in runs along a floor (offices cool, homes warm, now and then a screen in the city's two neon colours), a
// slab between floors, and every few floors an LED line along the slab. Each face of each tower has its own pattern.
shader_type spatial;
render_mode specular_schlick_ggx;

uniform vec4 glass_color : source_color = vec4(0.03, 0.04, 0.06, 1.0);
uniform vec4 slab_color : source_color = vec4(0.07, 0.075, 0.09, 1.0);
uniform float spandrel = 0.22;  // share of each floor that is solid slab
uniform float lit_share = 0.42; // share of rooms with the light on
uniform float energy = 1.7;
global uniform vec4 accent_a;
global uniform vec4 accent_b;

// (flat: the same exact number over the whole face. Blended across a wall, its tiny rounding differences went through
// hash() and came out as a different window pattern on every pixel: black specks all over the lit walls)
varying flat float face;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void vertex() {
	vec3 n = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	face = fract(sin(dot(MODEL_MATRIX[3].xz + n.xz * 17.0, vec2(3.17, 7.31))) * 1931.7);
}

void fragment() {
	vec2 cell = floor(UV);
	vec2 f = fract(UV);
	vec2 o = vec2(face * 61.0, face * 37.0);
	// rooms light up in big, steady blocks (several bays across, two floors up), hardly a window on its own
	vec2 run = floor((cell + vec2(floor(face * 6.0), floor(face * 3.0))) / vec2(6.0, 2.0)) + o;
	float lit = step(1.0 - lit_share, mix(hash(run), hash(cell + o), 0.05));
	float kind = hash(run + 9.7);
	vec3 room = kind < 0.6 ? vec3(0.6, 0.8, 1.0) : vec3(1.0, 0.68, 0.4);
	float scr = hash(cell + o + 21.3);
	if (scr > 0.985) {
		room = scr > 0.993 ? accent_a.rgb : accent_b.rgb;
		lit = 1.0;
	}
	float bright = 0.8 + 0.2 * hash(run + 4.4);
	// ceiling light near the top of the window, furniture darkening the bottom
	float inside = mix(1.0, 0.35, smoothstep(0.55, 0.98, f.y)) * mix(0.7, 1.0, 1.0 - smoothstep(0.0, 0.3, abs(f.x - 0.5) - 0.2));
	// far away the windows blur into a soft average
	float aa = clamp(1.6 - max(fwidth(UV.x), fwidth(UV.y)) * 2.4, 0.0, 1.0);
	vec3 rooms = room * lit * bright * inside;
	vec3 avg = mix(vec3(0.6, 0.75, 1.0), vec3(1.0, 0.7, 0.45), 0.4) * lit_share * 0.55;
	vec3 glow = mix(avg, rooms, aa) * energy;
	// slab and mullions
	float slab = step(f.y, spandrel);
	float mull = max(step(f.x, 0.035), step(0.965, f.x));
	float solid = max(slab, mull) * aa;
	// an LED line along the slab every few floors, in one of the city's colours
	float led_floor = step(0.8, hash(vec2(cell.y, floor(face * 9.0)) + 1.3));
	float led = led_floor * (1.0 - smoothstep(0.0, 0.03, abs(f.y - spandrel * 0.5))) * aa;
	vec3 led_col = face > 0.5 ? accent_a.rgb : accent_b.rgb;
	ALBEDO = mix(glass_color.rgb, slab_color.rgb, solid);
	METALLIC = mix(0.7, 0.3, solid);
	ROUGHNESS = mix(0.07, 0.5, solid);
	SPECULAR = 0.7;
	// far down the street the windows dim, so the rings stay the brightest things there
	float far = mix(1.0, 0.45, smoothstep(60.0, 160.0, length(VERTEX)));
	EMISSION = (glow * (1.0 - solid) + led_col * led * 2.5) * far;
}
