shader_type canvas_item;
// Engraved gold lettering with a slow moving glint (used for the game logo).
varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float g = clamp(fract(world.y / 70.0), 0.0, 1.0);
	vec3 gold = mix(vec3(1.0, 0.92, 0.62), vec3(0.62, 0.42, 0.14), smoothstep(0.15, 0.95, g));
	float glint = smoothstep(0.06, 0.0, abs(fract((world.x + world.y * 0.6) / 900.0 - TIME * 0.07) - 0.5));
	gold += glint * 0.55;
	// Outline / shadow pixels keep their own colour (COLOR carries it), fill pixels get gold.
	vec3 col = mix(COLOR.rgb, gold, step(0.95, COLOR.r * COLOR.g * COLOR.b));
	COLOR = vec4(col * tex.rgb, tex.a * COLOR.a);
}
