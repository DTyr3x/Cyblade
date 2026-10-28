shader_type spatial;
// Piso de teste com grade em escala real: linhas finas a cada 1 m, fortes a cada 5 m.
// Serve para medir distâncias (por exemplo, o alcance da esquiva) direto na tela.

uniform vec3 base_color : source_color = vec3(0.07, 0.08, 0.1);
uniform vec3 line_color : source_color = vec3(0.1, 0.7, 0.9);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float grid_line(vec2 p) {
	vec2 g = abs(fract(p - 0.5) - 0.5) / max(fwidth(p), vec2(0.0001));
	return 1.0 - min(min(g.x, g.y), 1.0);
}

void fragment() {
	float fine = grid_line(world_pos.xz);
	float bold = grid_line(world_pos.xz / 5.0);
	ALBEDO = base_color + line_color * (0.12 * fine + 0.6 * bold);
	ROUGHNESS = 0.6;
	METALLIC = 0.2;
}
