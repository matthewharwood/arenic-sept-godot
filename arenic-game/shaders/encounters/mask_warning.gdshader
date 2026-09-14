shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform vec4 ink : source_color = vec4(1.0);
uniform vec2 cells = vec2(1.0);
uniform float urgency = 0.0;
uniform int motif = 0;
void fragment() {
	vec2 p = UV * cells;
	vec2 edge = min(p, cells - p);
	float border = 1.0 - step(0.09, min(edge.x, edge.y));
	float pattern;
	if (motif == 1) { // Moon: diagonal bands.
		pattern = 1.0 - step(0.16, fract((p.x + p.y) * 0.5));
	} else if (motif == 2) { // Hammer: interlocking crosses.
		vec2 f = abs(fract(p * 0.5) - 0.5);
		pattern = 1.0 - step(0.08, min(f.x, f.y));
	} else if (motif == 3) { // Confession: repeated beam segments.
		pattern = 1.0 - step(0.25, fract(p.y));
	} else { // Sun: straight rays.
		pattern = 1.0 - step(0.12, fract(p.x * 0.5));
	}
	ALBEDO = ink.rgb;
	ALPHA = ink.a * max(border * 0.95, (0.10 + pattern * 0.26) + urgency * 0.23);
}
