shader_type canvas_item;
render_mode unshaded;

uniform int pattern_id : hint_range(0, 8) = 0;
uniform vec4 bed_color : source_color;
uniform vec4 primary_color : source_color;
uniform vec4 secondary_color : source_color;
uniform vec4 accent_color : source_color;
uniform vec4 light_color : source_color;
uniform vec2 logical_size = vec2(1280.0, 9.0);
uniform float fill_fraction : hint_range(0.0, 1.0) = 0.0;
uniform bool has_foundation = false;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 345.45));
	p += dot(p, p + 34.345);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), f.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = vec2(UV.x * logical_size.x / 44.0, UV.y * 1.8);
	float t = TIME * 0.24;
	float flow = noise(vec2(p.x - t, p.y + 0.22 * sin(p.x * 0.7 + t)));
	float vein = 1.0 - smoothstep(0.03, 0.20, abs(flow - 0.52));
	float motif = 0.0;
	if (pattern_id == 0) {
		// Labyrinth: drifting cyan channels and broken sightlines.
		float lanes = abs(fract(p.y * 2.0 + sin(p.x * 0.55 - t) * 0.18) - 0.5);
		motif = (1.0 - smoothstep(0.05, 0.15, lanes)) * smoothstep(0.18, 0.48, sin(p.x * 1.2 - t));
	} else if (pattern_id == 1) {
		// Guild House: slow hearth billows, with small rising embers.
		motif = pow(max(0.0, sin(p.x * 1.4 + 1.2 * sin(p.y + t) - t)), 5.0);
		motif *= 0.45 + 0.55 * (1.0 - UV.y);
	} else if (pattern_id == 2) {
		// Sanctum: liquid concentric gold bands.
		float rings = abs(sin(length(vec2(mod(p.x, 3.6) - 1.8, p.y - 0.9)) * 5.0 - t * 0.7));
		motif = 1.0 - smoothstep(0.08, 0.34, rings);
	} else if (pattern_id == 3) {
		// Mountain: organic green fault lines.
		float fault = p.y - 0.7 - 0.34 * sin(p.x * 1.6) - 0.16 * sin(p.x * 4.1 + t);
		motif = 1.0 - smoothstep(0.07, 0.24, abs(fault));
	} else if (pattern_id == 4) {
		// Bastion: interlocking chevrons, with a restrained forge pulse.
		float teeth = abs(fract(p.x * 0.65) - 0.5) * 2.0;
		motif = (1.0 - smoothstep(0.08, 0.22, abs(p.y - teeth))) * (0.8 + 0.2 * sin(t));
	} else if (pattern_id == 5) {
		// Pawnshop: amber torch streaks flowing through the melt.
		motif = pow(max(0.0, sin(p.x * 1.3 - p.y * 3.0 - t * 1.3 + flow)), 6.0);
	} else if (pattern_id == 6) {
		// Crucible: two crossing alchemical currents.
		float wave = sin(p.x * 2.0 - t) * 0.55;
		motif = 1.0 - smoothstep(0.04, 0.19, min(abs(p.y - 0.9 - wave), abs(p.y - 0.9 + wave)));
	} else if (pattern_id == 7) {
		// Casino: asynchronous sparks; no shared global beat.
		vec2 cell = floor(p * vec2(1.5, 2.0));
		float seed = hash21(cell);
		vec2 point = fract(p * vec2(1.5, 2.0)) - vec2(0.5);
		float sparkle = 1.0 - smoothstep(0.04, 0.25, length(point));
		motif = sparkle * pow(max(0.0, sin(t * (1.0 + seed) + seed * 35.0)), 4.0);
	} else {
		// Gala: neon equalizer ribbons, softly moving in alternating steps.
		float beat = 0.5 + 0.5 * sin(floor(p.x * 1.1) * 1.73 + t * 2.0);
		float bars = step(fract(p.x * 1.1), 0.72) * (1.0 - smoothstep(beat * 1.3 + 0.2, beat * 1.3 + 0.35, 1.8 - p.y));
		motif = bars;
	}
	float heat = clamp(flow * 0.75 + vein * 0.4, 0.0, 1.0);
	vec3 molten = mix(primary_color.rgb, secondary_color.rgb, heat);
	float cool_seam = 1.0 - smoothstep(0.025, 0.13, abs(flow - 0.36));
	molten = mix(molten, bed_color.rgb, cool_seam * 0.52);
	molten = mix(molten, accent_color.rgb, motif * 0.7);
	molten = mix(molten, light_color.rgb, clamp(vein * 0.18 + motif * 0.23, 0.0, 0.5));
	// The same mask applies to every arena. No screen copy or texture sampling.
	float pixel_width = 1.0 / max(logical_size.x, 1.0);
	float nonempty = fill_fraction > 0.0 ? 1.0 : 0.0;
	float fill = (1.0 - smoothstep(fill_fraction - pixel_width, fill_fraction + pixel_width, UV.x)) * nonempty;
	vec3 foundation = has_foundation ? mix(bed_color.rgb, molten, 0.43) : bed_color.rgb;
	vec3 result = mix(foundation, molten, fill);
	float edge_glint = (1.0 - smoothstep(0.0, pixel_width * 1.5, abs(UV.x - fill_fraction))) * nonempty;
	result = mix(result, light_color.rgb, edge_glint * 0.45);
	COLOR = vec4(result, 1.0);
}
