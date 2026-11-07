// The new cars' canopy glass: dark tinted and opaque, with a soft sky reflected in it (the
// city's neon at night) and a bright streak of light along the top, so it reads as glass from the chase camera.
shader_type spatial;

uniform vec4 tint : source_color = vec4(0.03, 0.05, 0.08, 1.0);
global uniform vec4 accent_a;
global uniform vec4 accent_b;
uniform float night = 0.0;

void fragment() {
	vec3 n_w = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 v_w = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 r_w = reflect(-v_w, n_w);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	vec3 sky = mix(vec3(0.22, 0.26, 0.32), vec3(0.85, 0.92, 1.0), smoothstep(-0.1, 0.7, r_w.y));
	vec3 neon = mix(accent_a.rgb, accent_b.rgb, 0.5 + 0.5 * r_w.x);
	sky = mix(sky, neon * 0.9, night * 0.75);
	float streak = smoothstep(0.08, 0.0, abs(n_w.x + 0.25)) * smoothstep(0.3, 0.8, n_w.y);
	ALBEDO = tint.rgb;
	METALLIC = 0.2;
	ROUGHNESS = 0.05;
	SPECULAR = 0.35;
	EMISSION = sky * (0.02 + (0.12 + 0.4 * night) * fres) + vec3(1.0) * streak * 0.45;
}
