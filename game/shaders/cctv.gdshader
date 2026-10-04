shader_type canvas_item;
// Old security monitor: green tint, scanlines, noise, vignette.
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	uv = 0.5 + c * (1.0 + dot(c, c) * 0.15);
	vec3 col = texture(screen_tex, uv).rgb;
	float l = dot(col, vec3(0.3, 0.59, 0.11)) * 1.8 + 0.03;
	col = vec3(l * 0.55, l * 1.0, l * 0.65);
	col *= 0.85 + 0.15 * sin(uv.y * 900.0);
	col += (hash(uv * 700.0 + TIME * 13.0) - 0.5) * 0.12;
	float roll = smoothstep(0.0, 0.02, abs(fract(uv.y - TIME * 0.1) - 0.5));
	col *= 0.9 + 0.1 * roll;
	col *= 1.0 - dot(c, c) * 1.4;
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) col = vec3(0.0);
	COLOR = vec4(col, 1.0);
}
