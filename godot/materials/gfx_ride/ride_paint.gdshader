// The new cars' paint: deep clear-coated metallic paint, a shade darker low down so the
// shape reads, a bright line of reflected horizon, and the city's two neon colours caught along its edges (strong
// at night), so the car stands out on a bright street and a dark one alike. glow warms the body in Overdrive;
// night (0 day .. 1 night, set per city by scripts/gfx_ride.gd) says how much neon there is to catch.
shader_type spatial;

uniform vec4 paint : source_color = vec4(0.91, 0.86, 0.78, 1.0);
uniform float metal = 0.35;
uniform float rough = 0.3;
uniform float rim = 0.7;
// racing stripes along the top in the light strip's colour: their distance out from the middle (0: none) and width
uniform float stripe_x = 0.0;
uniform float stripe_w = 0.03;
uniform vec4 stripe : source_color = vec4(1.0, 0.77, 0.42, 1.0);
uniform float glow = 0.0;
uniform vec4 glow_color : source_color = vec4(1.0, 0.75, 0.35, 1.0);
global uniform vec4 accent_a;
global uniform vec4 accent_b;
uniform float night = 0.0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec3 n_w = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 v_w = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 r_w = reflect(-v_w, n_w);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float shade = mix(0.3, 1.0, smoothstep(0.0, 0.3, local_pos.y));
	float top = smoothstep(0.55, 0.8, n_w.y);
	float st = stripe_x > 0.0 ? (1.0 - smoothstep(stripe_w * 0.7, stripe_w, abs(abs(local_pos.x) - stripe_x))) * top : 0.0;
	ALBEDO = mix(paint.rgb * shade, stripe.rgb, st);
	METALLIC = metal;
	ROUGHNESS = rough;
	CLEARCOAT = 1.0;
	CLEARCOAT_ROUGHNESS = 0.05;
	vec3 day = vec3(1.0, 0.95, 0.88);
	vec3 neon = mix(accent_a.rgb, accent_b.rgb, smoothstep(-0.5, 0.5, n_w.x));
	vec3 rim_c = mix(day * 0.5, neon * 1.2, night);
	float horizon = smoothstep(0.1, 0.0, abs(r_w.y - 0.06)) * smoothstep(-0.2, 0.3, n_w.y);
	EMISSION = stripe.rgb * st * 1.2 + rim_c * fres * rim * (0.3 + night) + day * horizon * 0.12 + glow_color.rgb * glow * (0.3 + 0.7 * fres);
}
