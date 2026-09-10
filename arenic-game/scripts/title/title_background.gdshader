shader_type canvas_item;
render_mode unshaded;

// Positions are authored in the reference's 1440 by 1024 layout.
const vec2 SPOTS[21] = {
	vec2(111.0, 73.0), vec2(264.0, 90.0), vec2(358.0, 98.0),
	vec2(576.0, 104.0), vec2(670.0, 114.0), vec2(78.0, 203.0),
	vec2(169.0, 180.0), vec2(351.0, 198.0), vec2(503.0, 216.0),
	vec2(597.0, 224.0), vec2(228.0, 275.0), vec2(324.0, 283.0),
	vec2(409.0, 306.0), vec2(319.0, 329.0), vec2(5.0, 373.0),
	vec2(154.0, 385.0), vec2(248.0, 394.0), vec2(60.0, 476.0),
	vec2(176.0, -12.0), vec2(442.0, -10.0), vec2(627.0, -23.0)
};

void fragment() {
	vec2 reference_position = UV / SCREEN_PIXEL_SIZE;
	float scale = min(1.0 / SCREEN_PIXEL_SIZE.x / 1440.0, 1.0 / SCREEN_PIXEL_SIZE.y / 1024.0);
	reference_position /= scale;
	float shadow = 0.0;
	for (int i = 0; i < 21; i++) {
		vec2 delta = (reference_position - SPOTS[i]) / 11.0;
		shadow += exp(-dot(delta, delta) * 0.5) * 0.055;
	}
	vec3 paper = vec3(244.0, 241.0, 238.0) / 255.0;
	COLOR = vec4(paper - shadow * vec3(1.21, 1.07, 0.93), 1.0);
}
