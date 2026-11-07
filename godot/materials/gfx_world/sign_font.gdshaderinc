// The signs' pixel letters (included by sign.gdshader and sign_painted.gdshader): a 3x5 pixel font, the words to
// show (set by GfxWorld.sign_mat), and the layout of one word on a sign of any size, stacked down a tall sign or
// along a wide one, centred, letters a pixel apart.

// 3x5 pixel letters, one bit per pixel from the top left (A-Z, '-', 2, 0, 7, 5)
const int FONT[31] = int[](11245, 27566, 14627, 27502, 31143, 31140, 14699, 23533, 29847, 4714, 23469, 18727, 24557, 27501, 11114, 27556, 11123, 27565, 14478, 29842, 23407, 23402, 23549, 23213, 23186, 29351, 448, 25255, 31599, 29330, 31118);
// the words, up to six letters each (5 bits a letter, 1 = A), and their lengths
uniform int words[16];
uniform int lens[16];
uniform int count = 1;

float hash(float n) { return fract(sin(n * 12.9898) * 43758.5453); }

float pix(int glyph, ivec2 q) {
	// is pixel q (x 0..2 from the left, y 0..4 from the top) of a glyph lit?
	if (glyph <= 0 || q.x < 0 || q.x > 2 || q.y < 0 || q.y > 4) {
		return 0.0;
	}
	int bit = 14 - (q.y * 3 + q.x);
	return float((FONT[glyph - 1] >> bit) & 1);
}

vec2 sign_size(vec2 uv, vec3 wp) {
	// the sign's size in metres, from how the UVs run over the surface
	vec2 dux = dFdx(uv);
	vec2 duy = dFdy(uv);
	vec3 dpx = dFdx(wp);
	vec3 dpy = dFdy(wp);
	float det = dux.x * duy.y - dux.y * duy.x;
	vec2 size = vec2(1.5, 8.0);
	if (abs(det) > 1e-12) {
		size = vec2(length((dpx * duy.y - dpy * dux.y) / det), length((dpy * dux.x - dpx * duy.x) / det));
	}
	return clamp(size, vec2(0.3), vec2(40.0));
}

// the letters of the sign's word at uv: x = the stroke (0..1), y = the glow around it, z = the pixel size (m),
// w = how sharp the letters still are (0 far away)
vec4 letters(vec2 uv, vec2 size, float sd, float fill) {
	bool tall = size.y > size.x * 1.6;
	float p = tall ? size.x * fill / 5.0 : size.y * fill / 7.0;
	int fit = tall ? int((size.y * 0.88 / p + 1.0) / 6.0) : int((size.x * 0.9 / p + 1.0) / 4.0);
	int wi = 0;
	for (int k = 0; k < 6; k++) {
		wi = int(floor(hash(sd * 1.7 + float(k) * 3.1 + 0.37) * float(count)));
		if (lens[wi] <= fit) {
			break;
		}
	}
	int len = lens[wi];
	int word = words[wi];
	// a word that is still too long gets smaller letters
	p = tall ? min(p, size.y * 0.88 / float(6 * len - 1)) : min(p, size.x * 0.9 / float(4 * len - 1));
	vec2 block = tall ? vec2(3.0, float(6 * len - 1)) : vec2(float(4 * len - 1), 5.0);
	vec2 g = (uv * size - (size - block * p) * 0.5) / p;
	vec2 cell = floor(g);
	vec2 f = fract(g);
	int li = tall ? int(floor(cell.y / 6.0)) : int(floor(cell.x / 4.0));
	ivec2 q = tall ? ivec2(int(cell.x), int(cell.y) - li * 6) : ivec2(int(cell.x) - li * 4, int(cell.y));
	int glyph = (li >= 0 && li < len) ? (word >> (5 * li)) & 31 : 0;
	float core = 0.0;
	float halo = 0.0;
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			if (pix(glyph, q + ivec2(dx, dy)) > 0.0) {
				vec2 d = abs(f - (vec2(float(dx), float(dy)) + 0.5));
				float box = max(d.x, d.y);
				core = max(core, 1.0 - smoothstep(0.36, 0.5, box));
				halo = max(halo, exp(-box * box * 4.0));
			}
		}
	}
	float aa = clamp(1.6 - fwidth(g.x) * 1.4, 0.0, 1.0);
	return vec4(core, halo, p, aa);
}
