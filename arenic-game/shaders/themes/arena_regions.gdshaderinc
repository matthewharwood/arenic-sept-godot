// Shared world-space field: all adjoining meshes evaluate identical seam colors.
// Inputs are explicit linear RGB, converted once from the source OKLCH palettes.
uniform float overview_mix : hint_range(0.0, 1.0) = 0.0;
uniform bool regions_ready = false;
uniform vec2 region_world_origin = vec2(-0.125, -7.625);
uniform vec2 region_arena_size = vec2(16.5, 7.75);
uniform vec3 region_floor_colors[9];
uniform vec3 region_backdrop_colors[9];
uniform vec3 region_dot_colors[9];
varying vec2 region_world_xz;

struct ArenaRegionSample {
	vec3 floor_color;
	vec3 backdrop_color;
	vec3 dot_color;
};

// The mask reaches one on the actual mesh join, regardless of the organic warp.
// Only interior seams blend; arena centers and the world's outer shape stay fixed.
float arena_region_mix(vec2 world_xz) {
	if (!regions_ready || overview_mix <= 0.0) {
		return 0.0;
	}
	vec2 p = world_xz - region_world_origin;
	vec2 distances = min(abs(p - region_arena_size), abs(p - region_arena_size * 2.0));
	float distance_to_seam = min(distances.x, distances.y);
	float width = 2.55 + 0.25 * sin(p.x * 0.41 + p.y * 0.63);
	return overview_mix * (1.0 - smoothstep(0.3, width, distance_to_seam));
}

ArenaRegionSample arena_region_sample(vec2 world_xz) {
	vec2 p = world_xz - region_world_origin;
	// Stable, broad bends: no time drift, per-arena seed, or rectangular UV reset.
	vec2 warp = vec2(
		sin(p.y * 0.73 + p.x * 0.11) * 0.58 + sin(p.y * 1.31 + 0.8) * 0.19,
		sin(p.x * 0.39 - p.y * 0.17 + 1.7) * 0.54 + sin(p.x * 0.91) * 0.18
	);
	vec2 warped = p + warp;
	ivec2 low = ivec2(clamp(floor(warped / region_arena_size - 0.5), vec2(0.0), vec2(1.0)));
	vec2 seam = (vec2(low) + 1.0) * region_arena_size;
	vec2 blend = smoothstep(seam - vec2(2.0), seam + vec2(2.0), warped);
	// Four nonnegative weights sum to one, including all four-way intersections.
	vec4 weights = vec4(
		(1.0 - blend.x) * (1.0 - blend.y), blend.x * (1.0 - blend.y),
		(1.0 - blend.x) * blend.y, blend.x * blend.y
	);
	int a = low.y * 3 + low.x;
	int b = a + 1;
	int c = a + 3;
	int d = a + 4;
	ArenaRegionSample result;
	result.floor_color = region_floor_colors[a] * weights.x + region_floor_colors[b] * weights.y + region_floor_colors[c] * weights.z + region_floor_colors[d] * weights.w;
	result.backdrop_color = region_backdrop_colors[a] * weights.x + region_backdrop_colors[b] * weights.y + region_backdrop_colors[c] * weights.z + region_backdrop_colors[d] * weights.w;
	result.dot_color = region_dot_colors[a] * weights.x + region_dot_colors[b] * weights.y + region_dot_colors[c] * weights.z + region_dot_colors[d] * weights.w;
	return result;
}
