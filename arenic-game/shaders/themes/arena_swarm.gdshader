shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, blend_mix, depth_draw_never;

// Source: matthewharwood/arenic @ 32acbd243471d731bf9e2904d02939b7b07d4bdf,
// crates/arenic_game/src/swarm.rs: swarm_home, swarm_amp, swarm_offset.
// Frequencies, phases, saws, tanh holds and 0.5x time are preserved below.
// Flat adaptation: source lift contributes half its displacement to source Y;
// Godot XZ = source (X,-Y), with fixed elevation -0.005 below the glass floor.
// A radial clamp keeps motes in a sparse outer ellipse, clear of the actors.
// Source nominal scales are retained; masks quantize their footprint to 4–8 pixels.

uniform vec4 primary : source_color;
uniform int mote = 0; // Spark, Flake, Dart, Bubble.
uniform int motion = 0; // Patrol, HearthRise, PendulumFall, GustDrift, UpdraftChurn,
                        // FurtiveDart, OpposingDrift, TumbleArc, BeatDrift.
uniform float source_scale = 0.07;
uniform float atmosphere_time = 0.0;
uniform float strength : hint_range(0.0, 1.0) = 1.0;

const float PIXELS_PER_UNIT = 76.0;
const float ELEVATION = -0.005;
const float GOLDEN_ANGLE = 2.3999632;
const vec2 SOURCE_RING = vec2(7.5, 3.4);
const vec2 SAFE_RING = vec2(7.8, 3.45);
varying flat float pixel_span;

float wave(float t, float phase, float k) {
	return sin(t * k + phase);
}

float saw(float t, float phase, float k) {
	return mod(t * k + phase, TAU) / TAU;
}

vec3 source_offset(float t, float p, vec3 a) {
	if (motion == 0) {
		return vec3(a.x * tanh(2.0 * wave(t,p,0.35)), a.y * wave(t,p,0.16), a.z * 0.2 * wave(t,p,0.5));
	}
	if (motion == 1) {
		return vec3(a.x * 0.4 * wave(t,p,0.3), a.y * 0.3 * wave(t,p,0.25), a.z * saw(t,p,0.10));
	}
	if (motion == 2) {
		return vec3(a.x * wave(t,p,0.6), a.y * 0.3 * wave(t,p,0.4), a.z * (1.0 - saw(t,p,0.08)));
	}
	if (motion == 3) {
		return vec3(a.x * (wave(t,p,0.2) + 0.4 * sin(t * 0.07 + p * 3.0)), a.y * wave(t,p,0.17), a.z * 0.3 * wave(t,p,0.13));
	}
	if (motion == 4) {
		return vec3(a.x * 0.4 * wave(t,p,0.3), a.y * 0.3 * wave(t,p,0.27), a.z * (0.5 + 0.5 * wave(t,p,0.4)));
	}
	if (motion == 5) {
		return vec3(a.x * tanh(3.0 * wave(t,p,0.6)), a.y * tanh(3.0 * sin(t * 0.5 + p + 1.0)), a.z * 0.2 * wave(t,p,0.7));
	}
	if (motion == 6) {
		return vec3(a.x * 0.3 * wave(t,p,0.2), a.y * 0.3 * wave(t,p,0.18), a.z * saw(t,p,0.12));
	}
	if (motion == 7) {
		return vec3(a.x * wave(t,p,0.3), a.y * 0.4 * wave(t,p,0.25), a.z * wave(t,p,0.4));
	}
	float beat = pow(max(0.0, sin(t * 2.0 + p)), 4.0);
	return vec3(a.x * wave(t,p,0.2), a.y * wave(t,p,0.16), -a.z * 0.3 * saw(t,p,0.1) + a.z * 0.5 * beat);
}

// Projects the source's rotation into the floor plane. Pitch/roll foreshorten a
// flat flake; a source Z rotation turns its plan silhouette. Geometry stays flat.
vec2 source_rotation(vec2 q, float t, float p) {
	float angle = 0.0;
	if (motion == 0) angle = 0.3 * wave(t,p,0.4);
	if (motion == 3) angle = 0.5 * wave(t,p,0.3);
	if (motion == 5) angle = 0.4 * wave(t,p,0.8);
	if (motion == 8) angle = 0.5 * wave(t,p,0.35);
	if (motion == 2) return vec2(q.x * cos(0.6 * wave(t,p,0.6)), q.y);
	if (motion == 4) return vec2(q.x, q.y * cos(0.8 * wave(t,p,0.5)));
	if (motion == 7) {
		vec3 axis = normalize(vec3(0.4, 1.0, 0.2));
		float c = cos(t * 2.0 + p), s = sin(t * 2.0 + p), k = 1.0 - c;
		return vec2(
			(c + axis.x * axis.x * k) * q.x + (axis.x * axis.y * k - axis.z * s) * q.y,
			(axis.y * axis.x * k + axis.z * s) * q.x + (c + axis.y * axis.y * k) * q.y
		);
	}
	return vec2(cos(angle)*q.x-sin(angle)*q.y, sin(angle)*q.x+cos(angle)*q.y);
}

void vertex() {
	float t = atmosphere_time * 0.5;
	// Power-of-two encoding survives Compatibility's half-float instance buffer.
	// Reconstruct source values here instead of quantizing arbitrary phase/home data.
	float index = round(INSTANCE_CUSTOM.x * 16.0);
	float count = max(1.0, round(INSTANCE_CUSTOM.z * 16.0));
	float phase = index * 0.7;
	float lift_sign = 1.0 - 2.0 * INSTANCE_CUSTOM.y;
	float angle = index * GOLDEN_ANGLE;
	float home_radius = 0.65 + 0.4 * sqrt((index + 0.5) / count);
	vec2 home = vec2(cos(angle), sin(angle)) * home_radius * SOURCE_RING;
	vec3 drift = source_offset(t, phase, vec3(1.4, 1.0, 0.9 * lift_sign));
	vec2 center = home + vec2(drift.x, drift.y + drift.z * 0.5);
	vec2 radial = center / SAFE_RING;
	float radius = length(radial);
	// Source homes never reach the origin; this also makes a malformed phase safe.
	radial = radius > 0.0001 ? radial * (clamp(radius, 0.65, 1.0) / radius) : vec2(0.65, 0.0);
	center = radial * SAFE_RING;
	pixel_span = clamp(floor(source_scale * PIXELS_PER_UNIT + 0.5), 4.0, 8.0);
	// Keep the resting canvas on native pixel edges at the close-view scale.
	center = (floor(center * PIXELS_PER_UNIT - pixel_span * 0.5) + pixel_span * 0.5) / PIXELS_PER_UNIT;
	vec2 corner = source_rotation(vec2(VERTEX.x, -VERTEX.z), t, phase) * pixel_span / PIXELS_PER_UNIT;
	VERTEX = vec3(center.x + corner.x, ELEVATION, -(center.y + corner.y));
}

void fragment() {
	// Four deliberately tiny integer masks; no textures, noise, CPU particles or RNG.
	vec2 p = floor(UV * pixel_span) + 0.5 - pixel_span * 0.5;
	float half_span = pixel_span * 0.5;
	float shape = 0.0;
	float highlight = 0.0;
	if (mote == 0) {
		shape = step(dot(p,p), half_span * half_span);
		highlight = step(abs(p.x) + abs(p.y), 1.5);
	} else if (mote == 1) {
		shape = step(abs(p.x), half_span - 0.5) * step(abs(p.y), half_span - 0.5);
		highlight = step(p.x + p.y, -1.0);
	} else if (mote == 2) {
		float width = p.y < 0.0 ? 0.5 : 1.5;
		shape = step(abs(p.x), width) * step(abs(p.y), half_span - 0.5);
		highlight = step(abs(p.x), 0.5);
	} else {
		float radius = length(p);
		shape = step(radius, half_span) * step(half_span - 1.4, radius);
		highlight = step(p.x + p.y, -1.0);
	}
	if (shape < 0.5) discard;
	ALBEDO = primary.rgb * mix(0.72, 1.0, highlight);
	EMISSION = primary.rgb * 1.6 * mix(0.45, 1.0, highlight) * strength;
	ALPHA = shape * 0.55 * strength;
}
