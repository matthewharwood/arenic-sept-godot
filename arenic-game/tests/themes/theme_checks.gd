extends SceneTree
## Godot --headless --path arenic-game --script res://tests/themes/theme_checks.gd
## Pure resource/conversion checks; no renderer or gameplay scene required.

const ARENAS: PackedStringArray = ["labyrinth", "guild_house", "sanctum", "mountain", "bastion", "pawnshop", "crucible", "casino", "gala"]
const THEMES: PackedStringArray = ["tokyo_night", "coffee", "luxury", "forest", "gruvbox_dark", "ayu_dark", "abyss", "rose_pine", "synthwave"]
const BASES: Array[Vector3] = [
	Vector3(0.226, 0.021, 280.5), Vector3(0.24, 0.025, 329.4), Vector3(0.08, 0.005, 50.0),
	Vector3(0.18, 0.03, 155.0), Vector3(0.277, 0.0, 89.9), Vector3(0.162, 0.014, 258.4),
	Vector3(0.219, 0.042, 225.9), Vector3(0.213, 0.025, 291.1), Vector3(0.18, 0.04, 290.0),
]
const VOICES: Array[Vector2i] = [Vector2i(0, 9), Vector2i(7, 4), Vector2i(1, 8), Vector2i(2, 8), Vector2i(2, 4), Vector2i(0, 5), Vector2i(1, 10), Vector2i(3, 9), Vector2i(1, 6)]
const SOURCE_REVISION: String = "60da21575de191461a12f2b2f68a7efd1b254bcd"
const EPSILON: float = 0.0001

var _checks: int = 0
var _started_ms: int = 0
var _done: bool = false


func _initialize() -> void:
	_started_ms = Time.get_ticks_msec()
	_run.call_deferred()


func _run() -> void:
	if not _check_resources() or not _check_world_assignments() or not _check_conversion():
		return
	_finish(0, "Theme checks passed: %d assertions; nine source palettes, 180 primitives, and OKLCH output boundaries." % _checks)


func _check_resources() -> bool:
	for index in ARENAS.size():
		var theme := load("res://data/themes/%s.tres" % ARENAS[index]) as ArenicArenaTheme
		if not _check(theme != null, "Theme resource loads: " + ARENAS[index]):
			return false
		if not _check(theme.arena_id == ARENAS[index] and theme.theme_id == THEMES[index] and theme.atmosphere_id == index, "Arena/theme/atmosphere identity stays in canonical world order."):
			return false
		if not _check(theme.validation_errors().is_empty(), "%s preserves all twenty valid OKLCH primitives." % theme.theme_id):
			return false
		var base: Vector3 = theme.palette["base_100"]
		if not _check(base.is_equal_approx(BASES[index]), "Canonical source base color is preserved: " + theme.theme_id):
			return false
		# The requested outdoor clearing intentionally replaces Guild House's
		# upstream indoor embers with restrained grain. Other source voices and
		# every source palette token retain their original provenance contract.
		var expected_voice: Vector2i = Vector2i(7, 8) if ARENAS[index] == "guild_house" else VOICES[index]
		if not _check(Vector2i(theme.backdrop_style, theme.foreground_style) == expected_voice, "Authored atmosphere matches the approved clearing override or original source voice: " + theme.theme_id):
			return false
		if ARENAS[index] == "guild_house" and not _check(is_equal_approx(theme.foreground_coverage, 0.24) and theme.foreground_drift == Vector2(0.014, 0.006), "The outdoor clearing uses low-coverage drifting grain instead of indoor embers."):
			return false
		var selector_radius: float = 4.0 if index == 2 else (0.0 if index == 8 else 8.0)
		if not _check(theme.border == 1.0 and theme.depth == 1.0 and theme.radius_selector == selector_radius and theme.radius_field == selector_radius and theme.radius_box == selector_radius * 2.0, "Source structural tokens remain native logical pixels."):
			return false
		if not _check(theme.source_revision == SOURCE_REVISION and theme.source_palette_path == "crates/arenic_game/src/theme/palettes.rs" and theme.source_identity_path == "crates/arenic_game/src/arena.rs", "Source provenance is pinned."):
			return false
		var has_css_palette: bool = index in [2, 3, 8]
		if not _check((theme.source_css_path == "theme-css/arenic.css") == has_css_palette, "CSS provenance exists only for palettes present in that source file."):
			return false
		for token in ArenicArenaTheme.TOKENS:
			var encoded: Color = theme.color(token, 0.37)
			var linear: Color = theme.linear_color(token, 0.37)
			if not _check(_unit_color(encoded) and _unit_color(linear) and absf(encoded.a - 0.37) < EPSILON and absf(linear.a - 0.37) < EPSILON, "Every palette token produces bounded finite channels and unchanged alpha."):
				return false
			if not _check(_near_color(encoded.srgb_to_linear(), linear), "sRGB and linear methods describe the same clipped color."):
				return false
	return true


func _check_world_assignments() -> bool:
	var world := load("res://data/world/arenia.tres") as ArenicWorldDefinition
	if not _check(world != null and world.validation_errors().is_empty() and world.arenas.size() == ARENAS.size(), "The canonical nine-arena world loads and remains valid."):
		return false
	for index in ARENAS.size():
		var arena: ArenicArenaDefinition = world.arenas[index]
		var expected := load("res://data/themes/%s.tres" % ARENAS[index]) as ArenicArenaTheme
		if not _check(arena.arena_id == ARENAS[index] and arena.visual_theme != null and arena.visual_theme == expected, "The loaded world uses the matching shared theme resource for " + ARENAS[index]):
			return false
		if not _check(arena.visual_theme.arena_id == arena.arena_id and arena.visual_theme.theme_id == THEMES[index] and arena.visual_theme.atmosphere_id == index, "World theme assignment preserves arena, palette, and atmosphere identity."):
			return false
	return true


func _check_conversion() -> bool:
	var theme := ArenicArenaTheme.new()
	# Independent known sRGB primaries expressed in OKLCH, plus achromatic endpoints.
	# Oklab reference: https://bottosson.github.io/posts/oklab/
	var examples: Array = [
		[Vector3(0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0, 1.0)],
		[Vector3(1.0, 0.0, 0.0), Color(1.0, 1.0, 1.0, 1.0)],
		[Vector3(0.627955361, 0.257683308, 29.23388519), Color(1.0, 0.0, 0.0, 1.0)],
		[Vector3(0.866439612, 0.294827240, 142.49533889), Color(0.0, 1.0, 0.0, 1.0)],
		[Vector3(0.452013718, 0.313214372, 264.05202064), Color(0.0, 0.0, 1.0, 1.0)],
		[Vector3(0.5, 0.0, 217.0), Color(0.38857286, 0.38857286, 0.38857286, 1.0)],
	]
	for example in examples:
		theme.palette["probe"] = example[0]
		if not _check(_near_color(theme.color("probe"), example[1]), "Known OKLCH/sRGB reference pair converts correctly."):
			return false
	theme.palette["probe"] = Vector3(0.5, 0.0, 217.0)
	if not _check(_near_color(theme.linear_color("probe"), Color(0.125, 0.125, 0.125, 1.0)), "Neutral OKLCH lightness cubes to linear intensity before transfer encoding."):
		return false
	if not _check(theme.color("probe", -0.25).a == 0.0 and theme.color("probe", 1.25).a == 1.0, "Alpha clips at the output boundary."):
		return false
	var extreme: Vector3 = Vector3(0.75, 0.5, 145.0)
	theme.palette["probe"] = extreme
	var clipped: Color = theme.linear_color("probe")
	if not _check(clipped.r == 0.0 and clipped.b == 0.0 and _unit_color(clipped), "Out-of-gamut channels clip at output."):
		return false
	var stored: Vector3 = theme.palette["probe"]
	return _check(stored == extreme, "Conversion never rewrites the authored OKLCH primitive.")


func _unit_color(value: Color) -> bool:
	return is_finite(value.r) and is_finite(value.g) and is_finite(value.b) and is_finite(value.a) and value.r >= 0.0 and value.r <= 1.0 and value.g >= 0.0 and value.g <= 1.0 and value.b >= 0.0 and value.b <= 1.0 and value.a >= 0.0 and value.a <= 1.0


func _near_color(actual: Color, expected: Color) -> bool:
	return absf(actual.r - expected.r) < EPSILON and absf(actual.g - expected.g) < EPSILON and absf(actual.b - expected.b) < EPSILON and absf(actual.a - expected.a) < EPSILON


func _check(condition: bool, message: String) -> bool:
	if _done:
		return false
	if Time.get_ticks_msec() - _started_ms >= 5000:
		_finish(1, "Theme checks exceeded the five-second limit.")
		return false
	_checks += 1
	if not condition:
		_finish(1, "Theme assertion failed: " + message)
		return false
	return true


func _finish(code: int, message: String) -> void:
	if _done:
		return
	_done = true
	print(message)
	quit(code)
