// Terrace house walls: bricks or stucco, stone bands, and a grid of sash windows on the street side, some lit warm.
// The pattern is drawn from each wall's size (taken from its transform), so one material serves every house.
// INSTANCE_CUSTOM: rgb = wall colour, a = style (0 brick, 0.5 stucco ground floor, 1 brick with stone bands);
// a negative style means a plain wall (chimneys, side walls far away): bricks, no windows
shader_type spatial;
render_mode cull_back;

uniform float floor_h = 2.7;
uniform float bay_w = 1.5;
uniform vec3 lit_col : source_color = vec3(1.0, 0.68, 0.34);
uniform float lit_energy = 3.2;
uniform float lit_share = 0.34;
uniform vec3 stone_col : source_color = vec3(0.78, 0.74, 0.66);
uniform vec3 frame_col : source_color = vec3(0.86, 0.84, 0.78);

varying vec3 lp;
varying vec3 ln;
varying vec3 sz;
varying vec4 cd;
varying vec3 org;

float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	sz = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	lp = VERTEX * sz;
	ln = NORMAL;
	cd = INSTANCE_CUSTOM;
	org = MODEL_MATRIX[3].xyz;
}

void fragment() {
	float style = cd.a;
	bool plain = style < 0.0;
	float seed = h21(org.xz * 0.37);
	vec2 uv = abs(ln.x) > 0.5 ? vec2(lp.z, lp.y + sz.y * 0.5) : vec2(lp.x, lp.y + sz.y * 0.5);
	bool face = abs(ln.x) > 0.5 && !plain;
	// running-bond bricks with mortar lines (fading out with distance so they don't shimmer)
	vec2 bc = uv / vec2(0.25, 0.082);
	float brow = floor(bc.y);
	bc.x += mod(brow, 2.0) * 0.5;
	vec2 bf = fract(bc);
	float fw = clamp(fwidth(bc.y) * 2.0, 0.0, 1.0);
	float mortar = max(1.0 - smoothstep(0.0, 0.07 + fw * 0.2, bf.x), 1.0 - smoothstep(0.0, 0.16 + fw * 0.2, bf.y)) * (1.0 - fw);
	float bn = h21(floor(bc) + seed * 17.0);
	vec3 brick = cd.rgb * (0.78 + 0.36 * bn);
	vec3 col = mix(brick, cd.rgb * 0.55 + vec3(0.18, 0.17, 0.15), mortar * 0.8);
	float rough = 0.82;
	float bump = mortar;
	vec3 emit = vec3(0.0);
	float fy = uv.y;
	if (face) {
		float fl = floor(fy / floor_h);
		float fv = fy - fl * floor_h;
		// stucco ground floor with rusticated joints
		if (style > 0.25 && style < 0.75 && fl < 1.0) {
			col = vec3(0.86, 0.82, 0.74) * (0.92 + 0.08 * h21(floor(uv / vec2(1.0, 0.42)) + seed));
			float j = 1.0 - smoothstep(0.0, 0.035, abs(fract(fy / 0.42) - 0.5) * 0.42 - 0.17);
			col *= 1.0 - 0.35 * j;
			rough = 0.6;
		}
		// stone string course on each floor line, and a cornice band at the top
		float band = (style > 0.75 ? 1.0 : 0.0) * (1.0 - step(0.16, fv)) * step(0.5, fl);
		float top = step(sz.y - 0.55, fy);
		col = mix(col, stone_col * (0.9 + 0.1 * seed), max(band, top));
		// windows: tall sashes, one per bay, with a stone lintel and sill
		float nb = max(1.0, floor(sz.z / bay_w));
		float u = (lp.z + sz.z * 0.5) / sz.z * nb;
		float bi = floor(u);
		float cu = (fract(u) - 0.5) * sz.z / nb;
		bool ground = fl < 1.0;
		float ww = ground ? 0.95 : 0.74;
		float w0 = ground ? 0.45 : 0.62;
		float wh = ground ? 1.75 : 1.5 - 0.12 * max(0.0, fl - 2.0);
		bool upper_ok = fy < sz.y - 0.75;
		// the door: one bay on the ground floor
		bool door = ground && bi == floor(seed * nb);
		if (door) { ww = 0.86; w0 = 0.0; wh = 2.15; }
		float inx = step(abs(cu), ww * 0.5);
		float iny = step(w0, fv) * step(fv, w0 + wh);
		if (upper_ok && inx * iny > 0.5) {
			float ex = ww * 0.5 - abs(cu);
			float ey = min(fv - w0, w0 + wh - fv);
			float frame = 1.0 - step(0.055, min(ex, ey));
			// the meeting rail and glazing bars of a sash window
			float bars = door ? 0.0 : max(1.0 - step(0.03, abs(fv - (w0 + wh * 0.5))), 1.0 - step(0.022, abs(cu)));
			float lit = step(1.0 - lit_share, h21(vec2(bi, fl) + seed * 31.0));
			if (door) {
				col = mix(cd.rgb * 0.25 + vec3(0.05, 0.04, 0.05), frame_col * 0.7, frame);
				rough = 0.35;
			} else {
				vec3 glass = mix(vec3(0.06, 0.07, 0.09), lit_col * 0.4, lit);
				col = mix(glass, frame_col, max(frame, bars));
				rough = mix(0.06, 0.5, max(frame, bars));
				// warm light inside, a little uneven across the pane
				float pane = (1.0 - max(frame, bars)) * lit;
				emit = lit_col * lit_energy * pane * (0.75 + 0.5 * h21(vec2(bi * 3.1, fl * 7.3) + seed));
				bump = 0.0;
			}
		}
		// lintel and sill
		float lin = step(abs(cu), ww * 0.5 + 0.08) * (step(w0 + wh, fv) * step(fv, w0 + wh + 0.14) + step(w0 - 0.1, fv) * step(fv, w0)) * float(upper_ok && !door);
		col = mix(col, stone_col, lin * 0.9);
	}
	// soot and damp toward the street, and a darker band where the rain runs down
	float ao = mix(0.5, 1.0, smoothstep(0.0, 2.4, fy));
	col *= ao * (0.93 + 0.07 * h21(vec2(floor(uv.x * 0.7), floor(fy * 0.3)) + seed));
	if (ln.y > 0.5) col *= 0.4;
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.45;
	EMISSION = emit;
	NORMAL_MAP = vec3(0.5, 0.5 + bump * 0.18, 1.0);
}
