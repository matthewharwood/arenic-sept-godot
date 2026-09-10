shader_type canvas_item;
render_mode unshaded;
// One explicitly bounded back-buffer copy; no mip pyramid or extra viewport.
uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_linear;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float initial_envelope = 0.0;
uniform vec2 flow_origin = vec2(0.0);
uniform vec4 from_ink : source_color;
uniform vec4 to_ink : source_color;
uniform vec4 sample_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 logical_viewport_size = vec2(1280.0, 720.0);

float hash21(vec2 p) {
	vec3 q = fract(vec3(p.xyx) * .1031);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}
float mist(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
vec3 read_scene(vec2 uv, vec2 half_texel) {
	return texture(scene_color, clamp(uv, sample_rect.xy+half_texel, sample_rect.zw-half_texel)).rgb;
}
void fragment() {
	float envelope = sin(clamp(progress, 0.0, 1.0) * 3.14159265);
	// Interrupted moves retain the visible fog density and cloud position.
	envelope += initial_envelope * (1.0-smoothstep(0.0,.5,progress)) * (1.0-envelope);
	vec2 flow = UV * vec2(6.0, 3.0) + flow_origin + vec2(progress*.7, -progress*.35);
	float cloud = mist(flow)*.7 + mist(flow*2.03+11.7)*.3;
	// Blur keeps its apparent size at Retina density; clamp uses actual texels.
	vec2 radius = envelope * (3.0 + cloud*3.0) / logical_viewport_size;
	vec2 half_texel = SCREEN_PIXEL_SIZE * .5;
	vec2 uv = SCREEN_UV;
	// Fixed nine-tap tent kernel: predictable work, including rapid retargets.
	vec3 soft = read_scene(uv,half_texel)*.25;
	soft += (read_scene(uv+vec2(radius.x,0),half_texel) + read_scene(uv-vec2(radius.x,0),half_texel)
		+read_scene(uv+vec2(0,radius.y),half_texel) +read_scene(uv-vec2(0,radius.y),half_texel))*.125;
	soft += (read_scene(uv+radius,half_texel) + read_scene(uv-radius,half_texel)
		+read_scene(uv+vec2(radius.x,-radius.y),half_texel) +read_scene(uv+vec2(-radius.x,radius.y),half_texel))*.0625;
	float dissolve = smoothstep(.26, .78, cloud + envelope*.08);
	float fog_alpha = envelope * (.12 + .82*dissolve);
	vec3 ink = mix(from_ink.rgb, to_ink.rgb, smoothstep(.15,.85,progress));
	COLOR = vec4(mix(soft, ink, fog_alpha), 1.0);
}
