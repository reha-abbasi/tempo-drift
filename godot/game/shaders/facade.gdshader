// Terrace house walls: bricks or stucco, stone bands, and a grid of sash windows on the street side, some lit warm.
// The pattern is drawn from each wall's size (taken from its transform), so one material serves every house.
// INSTANCE_CUSTOM: rgb = wall colour, a = style (0 brick, 0.25 plaster, 0.5 stucco ground floor, 0.75 ashlar stone,
// 1 brick with stone bands);
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
// (flat: the same exact value on every pixel of a wall; interpolated, these carry tiny rounding differences that the
// hash below would blow up into per-pixel noise, speckling the windows)
varying flat vec3 sz;
varying flat vec4 cd;
varying flat vec3 org;

// a hash without sine (stable on every GPU, phones included)
float h21(vec2 p) { vec3 p3 = fract(vec3(p.xyx) * 0.1031); p3 += dot(p3, p3.yzx + 33.33); return fract((p3.x + p3.y) * p3.z); }

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
	float seed = h21(floor(org.xz * 4.0) * 0.37);
	vec2 uv = abs(ln.x) > 0.5 ? vec2(lp.z, lp.y + sz.y * 0.5) : vec2(lp.x, lp.y + sz.y * 0.5);
	bool face = abs(ln.x) > 0.5 && !plain;
	// running-bond bricks with mortar lines (fading out with distance so they don't shimmer)
	vec2 bc = uv / vec2(0.25, 0.082);
	float brow = floor(bc.y);
	bc.x += mod(brow, 2.0) * 0.5;
	vec2 bf = fract(bc);
	// how much of a brick one pixel covers: past about half a brick the bricks blend into their average colour
	float fw = smoothstep(0.2, 0.6, fwidth(bc.y));
	float mortar = max(1.0 - smoothstep(0.0, 0.07 + fw * 0.2, bf.x), 1.0 - smoothstep(0.0, 0.16 + fw * 0.2, bf.y)) * (1.0 - fw);
	float bn = h21(floor(bc) + seed * 17.0);
	vec3 brick = cd.rgb * (0.78 + 0.36 * mix(bn, 0.5, fw));
	vec3 col = mix(brick, cd.rgb * 0.55 + vec3(0.18, 0.17, 0.15), mortar * 0.8);
	float rough = 0.82;
	float bump = mortar;
	vec3 emit = vec3(0.0);
	float fy = uv.y;
	if (face) {
		float fl = floor(fy / floor_h);
		float fv = fy - fl * floor_h;
		// smooth lime plaster over the whole front, a little patchy (Istanbul)
		if (style > 0.15 && style < 0.35) {
			col = cd.rgb * (0.9 + 0.1 * h21(floor(uv / vec2(1.7, 1.3)) + seed)) * (0.94 + 0.06 * sin(uv.x * 2.3 + uv.y * 1.1 + seed * 9.0));
			rough = 0.75;
			bump = 0.0;
		}
		// dressed limestone blocks with fine joints (Paris)
		if (style > 0.65 && style < 0.85) {
			vec2 ac = uv / vec2(0.9, 0.42);
			ac.x += mod(floor(ac.y), 2.0) * 0.5;
			vec2 af = fract(ac);
			float j2 = max(1.0 - smoothstep(0.0, 0.025, af.x), 1.0 - smoothstep(0.0, 0.05, af.y)) * (1.0 - fw);
			float af_w = smoothstep(0.2, 0.6, fwidth(ac.y));
			col = cd.rgb * (0.92 + 0.12 * mix(h21(floor(ac) + seed), 0.5, af_w)) * (1.0 - j2 * 0.28);
			rough = 0.7;
			bump = j2;
		}
		// stucco ground floor with rusticated joints
		if (style > 0.35 && style < 0.65 && fl < 1.0) {
			col = vec3(0.86, 0.82, 0.74) * (0.92 + 0.08 * h21(floor(uv / vec2(1.0, 0.42)) + seed));
			float j = 1.0 - smoothstep(0.0, 0.035, abs(fract(fy / 0.42) - 0.5) * 0.42 - 0.17);
			col *= 1.0 - 0.35 * j;
			rough = 0.6;
		}
		// stone string course on each floor line, and a cornice band at the top
		float band = (style > 0.75 ? 1.0 : 0.0) * (1.0 - smoothstep(0.14, 0.18, fv)) * step(0.5, fl);
		float top = smoothstep(sz.y - 0.57, sz.y - 0.53, fy);
		col = mix(col, stone_col * (0.9 + 0.1 * seed), max(band, top));
		// windows: tall sashes, one per bay, with a stone lintel and sill. Every edge is smoothed over the width of a
		// pixel and the thin glazing bars fade out with distance, so the windows don't shimmer or crawl as you fly past
		float nb = max(1.0, floor(sz.z / bay_w));
		float u = (lp.z + sz.z * 0.5) / sz.z * nb;
		float bi = floor(u);
		float cu = (fract(u) - 0.5) * sz.z / nb;
		bool ground = fl < 1.0;
		float ww = ground ? 0.95 : 0.74;
		float w0 = ground ? 0.45 : 0.62;
		float wh = ground ? 1.75 : 1.5 - 0.12 * max(0.0, fl - 2.0);
		float upper_ok = 1.0 - smoothstep(sz.y - 0.8, sz.y - 0.7, fy);
		// the door: one bay on the ground floor
		bool door = ground && bi == floor(seed * nb);
		if (door) { ww = 0.86; w0 = 0.0; wh = 2.15; }
		// (measured on the smooth coordinates, so the seams between bays and floors don't show as lines)
		float fp = fwidth(u);
		float au = max(fp * sz.z / nb, 0.0005);
		float av = max(fwidth(fy), 0.0005);
		float detail = 1.0 - smoothstep(0.025, 0.07, max(au, av));
		float hx = ww * 0.5;
		float win = smoothstep(hx + au, hx - au, abs(cu)) * smoothstep(w0 - av, w0 + av, fv) * smoothstep(w0 + wh + av, w0 + wh - av, fv) * upper_ok;
		float fr = 0.055;
		float glass_m = smoothstep(hx - fr + au, hx - fr - au, abs(cu)) * smoothstep(w0 + fr - av, w0 + fr + av, fv) * smoothstep(w0 + wh - fr + av, w0 + wh - fr - av, fv) * win;
		// one random light per window up close; far away, where a pixel covers several windows, their average
		float lit = mix(step(1.0 - lit_share, h21(vec2(bi, fl) + seed * 31.0)), lit_share, smoothstep(0.2, 0.5, fp));
		if (door) {
			col = mix(col, mix(frame_col * 0.7, cd.rgb * 0.25 + vec3(0.05, 0.04, 0.05), glass_m), win);
			rough = mix(rough, 0.35, win);
		} else {
			float bars = max(smoothstep(0.03 + av, 0.03 - av, abs(fv - (w0 + wh * 0.5))), smoothstep(0.022 + au, 0.022 - au, abs(cu))) * detail;
			float pane = glass_m * (1.0 - bars);
			vec3 glass = mix(vec3(0.06, 0.07, 0.09), lit_col * 0.4, lit);
			col = mix(col, frame_col, win);
			col = mix(col, glass, pane);
			rough = mix(rough, 0.5, win);
			rough = mix(rough, 0.08, pane);
			// warm light inside, a little uneven from window to window
			emit = lit_col * lit_energy * pane * lit * mix(0.75 + 0.5 * h21(vec2(bi * 3.1, fl * 7.3) + seed), 1.0, smoothstep(0.2, 0.5, fp));
			bump *= 1.0 - win;
			// lintel and sill
			float lx = smoothstep(hx + 0.08 + au, hx + 0.08 - au, abs(cu));
			float ly = smoothstep(w0 + wh - av, w0 + wh + av, fv) * smoothstep(w0 + wh + 0.14 + av, w0 + wh + 0.14 - av, fv)
				+ smoothstep(w0 - 0.1 - av, w0 - 0.1 + av, fv) * smoothstep(w0 + av, w0 - av, fv);
			col = mix(col, stone_col, lx * ly * upper_ok * 0.9);
		}
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
