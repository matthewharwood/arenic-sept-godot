shader_type canvas_item;
render_mode unshaded;

uniform sampler2D cloud_noise : repeat_enable, filter_linear;
uniform vec4 mist_ink : source_color;
uniform float overview_mix = 0.0;
uniform float cloud_phase = 0.0;

void fragment() {
	// A seamless texture translates left to right and returns exactly every cycle.
	float broad = texture(cloud_noise, UV * vec2(1.5, 0.95) - vec2(cloud_phase, 0.0)).r;
	float wisps = texture(cloud_noise, UV * vec2(3.0, 2.1) - vec2(cloud_phase * 2.0, 0.13)).r;
	float cloud = smoothstep(0.40, 0.77, broad * 0.76 + wisps * 0.24);
	float edge = pow(abs(UV.y - 0.5) * 2.0, 2.0);
	// Very light over the labels and HUD. Pure presentation: never intercept input.
	float alpha = cloud * mix(0.085, 0.17, edge) * overview_mix;
	COLOR = vec4(mist_ink.rgb, alpha);
}
