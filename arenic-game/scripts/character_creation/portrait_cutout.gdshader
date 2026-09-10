shader_type canvas_item;
render_mode unshaded;

varying vec4 canvas_tint;

void vertex() {
	canvas_tint = COLOR;
}

// Generated originals are preserved. Pure white backing is removed at display
// time; the original alpha is respected when an RGBA portrait is supplied.
void fragment() {
	vec4 sample_color = texture(TEXTURE, UV);
	float backing = smoothstep(0.92, 0.995, min(sample_color.r, min(sample_color.g, sample_color.b)));
	COLOR = vec4(sample_color.rgb, sample_color.a * (1.0 - backing)) * canvas_tint;
}
