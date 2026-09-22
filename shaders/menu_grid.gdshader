shader_type canvas_item;

// Retícula técnica de fondo para los menús: base oscura + líneas cian.

uniform vec2 cells = vec2(26.0, 15.0);
uniform vec4 grid_color : source_color = vec4(0.1, 0.9, 1.0, 0.14);

void fragment() {
	vec4 base = COLOR;
	vec2 gv = fract(UV * cells);
	vec2 edge = min(gv, vec2(1.0) - gv);
	float lw = 0.03;
	float gx = 1.0 - smoothstep(0.0, lw, edge.x);
	float gy = 1.0 - smoothstep(0.0, lw, edge.y);
	float grid = max(gx, gy);
	base.rgb = mix(base.rgb, grid_color.rgb, grid * grid_color.a);
	COLOR = base;
}
