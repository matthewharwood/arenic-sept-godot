shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, blend_mix, depth_draw_never;

uniform vec4 base_100 : source_color;
uniform vec4 base_200 : source_color;
uniform vec4 base_300 : source_color;
uniform vec4 base_content : source_color;
uniform vec4 primary : source_color;
uniform vec4 secondary : source_color;
uniform vec4 accent : source_color;
uniform int identity = 0;
uniform sampler2D guild_grass : source_color, filter_nearest, repeat_disable;
uniform float atmosphere_time = 0.0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;
#include "res://shaders/themes/arena_regions.gdshaderinc"
varying vec2 cell;

float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float stone_noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
float band(float x, float width) { return 1.0 - step(width, abs(x)); }
float line_period(float x, float period, float width) { return band(mod(x + period * 0.5, period) - period * 0.5, width); }

void vertex() {
	// Match arena_tiles.gd: exact binary fractions, including half-float buffers.
	cell = round(INSTANCE_CUSTOM.xy * vec2(128.0, 32.0));
	region_world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 px = min(floor(UV * 19.0), vec2(18.0));
	vec2 p = cell * 19.0 + px;
	vec2 size = vec2(1254.0, 589.0);
	vec2 q = p - size * 0.5;
	float edge = min(min(p.x, size.x - 1.0 - p.x), min(p.y, size.y - 1.0 - p.y));
	float grain = hash21(p);
	vec3 color = mix(base_100.rgb, base_200.rgb, 0.30 + grain * 0.08);
	float seam = 0.0;
	float inlay = 0.0;
	float ornament = 0.0;
	float radius = length(q / vec2(1.0, 0.92));
	if (identity == 0) { // Tokyo Night: interlocking indigo stone and a maze at the perimeter.
		vec2 brick = vec2(p.x + mod(floor(p.y / 38.0), 2.0) * 38.0, p.y);
		seam = max(line_period(brick.x, 76.0, 1.0), line_period(brick.y, 38.0, 1.0));
		vec2 maze = abs(mod(p + 19.0, 152.0) - 76.0);
		inlay = max(band(max(maze.x, maze.y) - 48.0, 1.0), band(min(maze.x, maze.y) - 19.0, 1.0));
		inlay *= 1.0 - smoothstep(65.0, 145.0, edge);
		ornament = band(q.y + 0.23*q.x - 32.0, .7) * (1.0 - smoothstep(350.0, 510.0, abs(q.x))) * .35;
	} else if (identity == 1) { // Native Aseprite grass; the Guild House is an outdoor clearing.
		float tile_variant = mod(floor(cell.x / 5.0) + floor(cell.y / 4.0) * 3.0, 4.0);
		vec2 grass_uv = (vec2(tile_variant * 19.0, 0.0) + px + 0.5) / vec2(76.0, 19.0);
		color = texture(guild_grass, grass_uv).rgb;
	} else if (identity == 2) { // Luxury: dark marble, gilded rose window and radial tracery.
		seam = max(line_period(p.x, 76.0, 0.5), line_period(p.y, 76.0, 0.5));
		float a = atan(q.y, q.x);
		inlay = max(band(radius - 209.0, 1.0), band(radius - 219.0, 1.0));
		ornament = max(band(radius - 133.0, 0.7), band(sin(a * 8.0) * radius, 0.7)) * step(radius, 209.0) * 0.32;
		color = mix(color, base_content.rgb, pow(abs(sin(p.x * .016 + sin(p.y * .014) * 3.0)), 28.0) * 0.015);
	} else if (identity == 3) { // Forest: moss beds and weathered stepping stone strata.
		vec2 block = floor(vec2(p.x + floor(p.y / 38.0) * 19.0, p.y) / 38.0);
		color = mix(color, secondary.rgb, stone_noise(p / 95.0) * 0.025 + hash21(block) * 0.008);
		seam = max(line_period(p.x + floor(p.y / 38.0) * 19.0, 38.0, 0.5), line_period(p.y, 38.0, 0.5));
		float moss = hash21(floor(p / 3.0)) * stone_noise(p / 48.0);
		inlay = step(.47, moss) * (1.0 - smoothstep(28.0, 155.0, edge)) * 0.55;
		float fault = q.y - q.x*.24 - (stone_noise(vec2(floor(q.x/19.0)*.6, 7.0))-.5)*47.0;
		ornament = band(fault - 51.0, .9) * .30;
		ornament += band(fault - 56.0, .5) * .10;
	} else if (identity == 4) { // Gruvbox: broad iron flagstones and broken forge seams.
		vec2 brick = vec2(p.x + mod(floor(p.y / 57.0), 2.0) * 57.0, p.y);
		seam = max(line_period(brick.x, 114.0, 1.0), line_period(brick.y, 57.0, 1.0));
		color = mix(color, secondary.rgb, hash21(floor(brick / vec2(114.0, 57.0))) * .035);
		inlay = seam * step(.66, hash21(floor(p / 19.0))) * (1.0 - smoothstep(24.0, 110.0, edge));
		float hexagon = max(abs(q.y), dot(abs(q), vec2(.8660254,.5)));
		ornament = band(hexagon-152.0, .8) * .45;
		// A small angular anvil mark within the defensive hexagon.
		float anvil = max(abs(q.x)-mix(50.0,86.0,step(q.y,-12.0)), abs(q.y)-38.0);
		ornament = max(ornament, band(anvil,.7)*.28);
	} else if (identity == 5) { // Ayu: diagonal dark parquet and brass diamond edging.
		vec2 h = vec2(p.x + p.y, p.x - p.y);
		seam = max(line_period(h.x, 76.0, .7), line_period(h.y, 38.0, .7));
		color = mix(color, base_300.rgb, mod(floor(h.x / 76.0) + floor(h.y / 38.0), 2.0) * .35);
		inlay = line_period(h.x, 38.0, 1.0) * line_period(h.y, 38.0, 1.0) * (1.0 - smoothstep(35.0, 95.0, edge));
		float crack = q.x + 327.0 + floor(q.y/38.0)*9.0;
		ornament = band(crack, .7) * smoothstep(55.0,150.0,abs(q.y)) * .55;
	} else if (identity == 6) { // Abyss: concentric alchemical rings, channels and fractured teal slate.
		seam = max(line_period(p.x + floor(p.y / 57.0) * 19.0, 57.0, .5), line_period(p.y, 57.0, .5));
		inlay = max(band(radius - 190.0, .8), band(radius - 202.0, .8));
		float spoke = band(sin(atan(q.y, q.x) * 6.0) * radius, .8);
		ornament = max(band(radius - 114.0, .7), spoke * step(114.0, radius) * step(radius, 190.0)) * .4;
	} else if (identity == 7) { // Rose Pine: a muted diamond floor and brass card-table outlines.
		vec2 d = vec2(p.x + p.y, p.x - p.y) / 57.0;
		color = mix(color, secondary.rgb, mod(floor(d.x) + floor(d.y), 2.0) * .026);
		seam = max(line_period(p.x + p.y, 57.0, .6), line_period(p.x - p.y, 57.0, .6));
		float oval = length(q / vec2(1.5, .85));
		inlay = max(band(oval - 209.0, .8), band(oval - 218.0, .8));
		ornament = band(abs(q.x) + abs(q.y) - 133.0, .8) * .35;
		vec2 tally_cell = floor(p / 76.0);
		vec2 tally = abs(mod(p, 76.0)-vec2(38.0));
		float sparkle = step(tally.x, .6)*step(tally.y, 3.0) + step(tally.x, 3.0)*step(tally.y, .6);
		float phase = hash21(tally_cell)*6.28318;
		float glint = pow(.5+.5*sin(atmosphere_time*(.19+hash21(tally_cell+7.0)*.31)+phase),12.0);
		ornament += sparkle*glint*.9*strength;
	} else { // Synthwave: stage-panel grid, neon rails and an equalizer border.
		seam = max(line_period(p.x, 57.0, .5), line_period(p.y, 57.0, .5));
		inlay = max(band(abs(q.x) - 456.0, .7), band(abs(q.y) - 209.0, .7));
		float beat = pow(.5+.5*sin(atmosphere_time*.75),4.0);
		float height = 8.0 + hash21(vec2(floor(p.x / 19.0), 1.0)) * (14.0+beat*16.0*strength);
		color = mix(color, secondary.rgb, seam*(.025+.035*beat*strength));
		ornament = step(abs(q.y), 275.0) * step(275.0 - height, abs(q.y)) * (1.0 - step(4.0, mod(p.x, 19.0))) * .55;
	}
	color = mix(color, base_300.rgb, seam * 0.40);
	color = mix(color, primary.rgb, clamp(inlay, 0.0, 1.0) * 0.27);
	color = mix(color, accent.rgb, ornament * 0.22);
	// A narrow double frame stops at the four travel corridors.
	bool gate = abs(q.x) < 38.0 || abs(q.y) < 28.5;
	float frame = (band(edge - 8.0, .6) + band(edge - 12.0, .6)) * (gate || identity == 1 ? 0.0 : 1.0);
	if (overview_mix > 0.0 && regions_ready) {
		frame *= 1.0 - overview_mix;
	}
	color = mix(color, primary.rgb, frame * .38);
	// No antialiasing here: exactly one center pixel per native 19px cell.
	float dot_pixel = (identity != 1 && px.x == 9.0 && px.y == 9.0) ? 1.0 : 0.0;
	color = mix(color, mix(base_100.rgb, base_content.rgb, .40), dot_pixel);
	float regional_mix = arena_region_mix(region_world_xz);
	if (regional_mix > 0.0) {
		ArenaRegionSample regional = arena_region_sample(region_world_xz);
		// Replace the full local motif at a physical join, including its dot tint.
		// Neighboring tiles retain their exact native dot footprint and opacity.
		vec3 shared_color = mix(regional.floor_color, regional.dot_color, dot_pixel);
		color = mix(color, shared_color, regional_mix);
	}
	ALBEDO = color;
	ALPHA = mix(.94, 1.0, dot_pixel);
}
