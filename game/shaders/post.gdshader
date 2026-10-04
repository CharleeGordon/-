shader_type canvas_item;
// Cinematic post-process: film grain, vignette, fear-driven chromatic aberration + desaturation.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float threat : hint_range(0.0, 1.0) = 0.0;
uniform float grain : hint_range(0.0, 0.2) = 0.045;
uniform float vignette : hint_range(0.0, 2.0) = 0.9;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform vec3 flash_color = vec3(0.8, 0.0, 0.0);
uniform float hidden : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float r2 = dot(c, c);
	float ca = 0.0015 + threat * 0.006;
	vec3 col;
	col.r = texture(screen_tex, uv + c * ca).r;
	col.g = texture(screen_tex, uv).g;
	col.b = texture(screen_tex, uv - c * ca).b;
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(lum), threat * 0.35);
	float v = 1.0 - r2 * (vignette + threat * 0.9);
	col *= clamp(v, 0.0, 1.0);
	float g = hash(uv * vec2(1920.0, 1080.0) + vec2(TIME * 61.0, TIME * 17.0)) - 0.5;
	col += g * (grain + threat * 0.03);
	// Locker slats when hiding
	if (hidden > 0.0) {
		float slat = step(0.5, fract(uv.y * 9.0));
		float window = smoothstep(0.18, 0.12, abs(c.x)) * smoothstep(0.32, 0.25, abs(c.y));
		col *= mix(1.0, mix(0.04, 1.0, slat * window), hidden);
	}
	col = mix(col, flash_color, flash);
	COLOR = vec4(col, 1.0);
}
