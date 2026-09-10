shader_type canvas_item;
render_mode unshaded;

uniform sampler2D cloud_noise : repeat_enable, filter_linear;
uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform vec4 land_rect = vec4(13.0, 35.0, 1254.0, 589.0);
uniform vec2 land_origin = vec2(13.0, 35.0);
uniform vec2 land_u = vec2(0.00079745, 0.0);
uniform vec2 land_v = vec2(0.0, 0.00169779);
uniform vec2 land_size = vec2(1254.0, 589.0);
uniform vec4 sky_low : source_color;
uniform vec4 sky_high : source_color;
uniform vec4 mist_ink : source_color;
uniform float overview_mix = 0.0;
uniform float cloud_phase = 0.0;

float rounded_distance(vec2 p, vec2 half_size, float radius) {
	vec2 q = abs(p) - half_size + radius;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
	vec2 screen = UV * viewport_size;
	vec2 relative = screen - land_origin;
	vec2 land_uv = vec2(dot(relative, land_u), dot(relative, land_v));
	float radius = min(land_size.x, land_size.y) * 0.20;
	float coast = texture(cloud_noise, land_uv * vec2(3.0, 2.0)).r;
	float d = rounded_distance((land_uv - 0.5) * land_size,
		land_size * 0.5 - vec2(20.0, 18.0), radius) + (coast - 0.5) * 16.0;
	float outside = smoothstep(-16.0, 12.0, d);
	float sky_cloud = texture(cloud_noise, UV * vec2(1.8, 1.15) - vec2(cloud_phase, 0.0)).r;
	vec3 sky = mix(sky_low.rgb, sky_high.rgb, clamp(UV.y * 0.5 + sky_cloud * 0.5, 0.0, 1.0));
	// A soft rock shadow gives the connected landmass depth in the surrounding sky.
	float shadow = exp(-max(d - 5.0, 0.0) / 24.0) * 0.60;
	sky *= 1.0 - shadow;
	sky = mix(sky, mist_ink.rgb, smoothstep(0.48, 0.82, sky_cloud) * 0.12);
	// Feather the coast from the inside as well; no hard outline is drawn.
	float inner_mist = exp(-abs(d + 8.0) / 23.0) * (0.04 + coast * 0.04);
	float alpha = outside + inner_mist * (1.0 - outside);
	COLOR = vec4(mix(sky_high.rgb * 0.65, sky, outside), alpha * overview_mix);
}
