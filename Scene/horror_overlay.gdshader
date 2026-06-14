shader_type canvas_item;
render_mode unshaded;
// Efek POV horror "nearsight": blur, chromatic aberration, tunnel-vision vignette,
// dan desaturasi kemerahan yang menguat saat penghuni kebun mendekat (intensity 0..1).

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 dir = uv - vec2(0.5);
	float amt = intensity;

	vec3 col = texture(screen_tex, uv).rgb;

	if (amt > 0.001) {
		// Blur kotak sederhana
		float b = 0.006 * amt;
		vec3 acc = vec3(0.0);
		acc += texture(screen_tex, uv + vec2(b, 0.0)).rgb;
		acc += texture(screen_tex, uv + vec2(-b, 0.0)).rgb;
		acc += texture(screen_tex, uv + vec2(0.0, b)).rgb;
		acc += texture(screen_tex, uv + vec2(0.0, -b)).rgb;
		acc += texture(screen_tex, uv + vec2(b, b)).rgb;
		acc += texture(screen_tex, uv + vec2(-b, -b)).rgb;
		acc *= (1.0 / 6.0);
		col = mix(col, acc, amt);

		// Chromatic aberration ke arah tepi
		vec2 ca = dir * 0.02 * amt;
		col.r = mix(col.r, texture(screen_tex, uv + ca).r, amt);
		col.b = mix(col.b, texture(screen_tex, uv - ca).b, amt);
	}

	// Tunnel-vision vignette
	float d = length(dir);
	float vig = smoothstep(0.78, 0.22, d);
	col *= mix(1.0, vig, amt * 0.95);

	// Desaturasi + tint merah saat panik
	float g = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 horror = vec3(g * 1.1, g * 0.22, g * 0.18);
	col = mix(col, horror, amt * 0.55);

	COLOR = vec4(col, 1.0);
}
