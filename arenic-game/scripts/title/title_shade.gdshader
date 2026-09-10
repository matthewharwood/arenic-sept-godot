shader_type canvas_item;
render_mode unshaded;
void fragment() {
 float left_mask = 1.0 - smoothstep(0.18, 0.66, UV.x);
 float edge_mask = pow(abs(UV.y - 0.5) * 2.0, 4.0);
 COLOR = vec4(0.008, 0.014, 0.028, left_mask * 0.76 + edge_mask * 0.18);
}
