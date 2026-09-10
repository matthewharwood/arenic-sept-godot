class_name ArenicArenaTheme
extends Resource
## Palette primitives stay in OKLCH: Vector3(lightness 0–1, chroma, hue degrees).
## Keys match upstream Theme fields: CSS --color-base-100 becomes base_100.

const TOKENS: PackedStringArray = [
	"base_100", "base_200", "base_300", "base_content", "primary", "primary_content",
	"secondary", "secondary_content", "accent", "accent_content", "neutral", "neutral_content",
	"info", "info_content", "success", "success_content", "warning", "warning_content", "error", "error_content",
]

@export var theme_id: String = ""
@export var arena_id: String = ""
@export_range(0, 8, 1) var atmosphere_id: int = 0
@export var subtitle: String = ""
@export var palette: Dictionary = {}

## Structural tokens use source-native logical pixels (CSS rem × 16).
@export var border: float = 1.0
@export var depth: float = 1.0
@export var radius_selector: float = 8.0
@export var radius_field: float = 8.0
@export var radius_box: float = 16.0

## Exact CloudStyle discriminants and Voice parameters from upstream arena.rs.
@export_enum("Banded", "Billows", "Vertical", "Spiral", "Embers", "Sweep", "Pulse", "Hearth", "Grain", "Streaks", "Ripple") var backdrop_style: int = 0
@export var backdrop_scale: float = 1.0
@export var backdrop_drift: Vector2 = Vector2.ZERO
@export var backdrop_coverage: float = 0.5
@export var backdrop_vignette: float = 0.0
@export var backdrop_speed: float = 1.0
@export_enum("Banded", "Billows", "Vertical", "Spiral", "Embers", "Sweep", "Pulse", "Hearth", "Grain", "Streaks", "Ripple") var foreground_style: int = 0
@export var foreground_scale: float = 1.0
@export var foreground_drift: Vector2 = Vector2.ZERO
@export var foreground_coverage: float = 0.5
@export var foreground_vignette: float = 0.0
@export var foreground_speed: float = 1.0

@export var source_repository: String = "https://github.com/matthewharwood/arenic"
@export var source_revision: String = "60da21575de191461a12f2b2f68a7efd1b254bcd"
@export var source_palette_path: String = "crates/arenic_game/src/theme/palettes.rs"
@export var source_identity_path: String = "crates/arenic_game/src/arena.rs"
## Empty for the six newer palettes absent from the source CSS catalogue.
@export var source_css_path: String = ""


## Use for Godot UI colors, material albedo, and source_color shader uniforms.
func color(token: String, alpha: float = 1.0) -> Color:
	return linear_color(token, alpha).linear_to_srgb()


## Use for explicit linear shader/math inputs. Clip only at this output boundary.
## Conversion: https://bottosson.github.io/posts/oklab/#converting-from-linear-srgb-to-oklab
func linear_color(token: String, alpha: float = 1.0) -> Color:
	var value: Variant = palette.get(token)
	if not value is Vector3:
		push_error("Theme %s has no OKLCH token '%s'." % [theme_id, token])
		return Color(0.0, 0.0, 0.0, 0.0)
	var oklch: Vector3 = value
	var hue: float = deg_to_rad(oklch.z)
	var a: float = oklch.y * cos(hue)
	var b: float = oklch.y * sin(hue)
	var l: float = oklch.x + 0.3963377774 * a + 0.2158037573 * b
	var m: float = oklch.x - 0.1055613458 * a - 0.0638541728 * b
	var s: float = oklch.x - 0.0894841775 * a - 1.2914855480 * b
	l = l * l * l
	m = m * m * m
	s = s * s * s
	return Color(
		clampf(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s, 0.0, 1.0),
		clampf(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s, 0.0, 1.0),
		clampf(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s, 0.0, 1.0),
		clampf(alpha, 0.0, 1.0)
	)


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if theme_id.is_empty() or arena_id.is_empty():
		errors.append("Theme and arena identities are required.")
	if palette.size() != TOKENS.size():
		errors.append("A theme must preserve exactly twenty palette primitives.")
	for token in TOKENS:
		var value: Variant = palette.get(token)
		if not value is Vector3:
			errors.append("Missing OKLCH primitive: " + token)
			continue
		var oklch: Vector3 = value
		if not oklch.is_finite() or oklch.x < 0.0 or oklch.x > 1.0 or oklch.y < 0.0:
			errors.append("Invalid OKLCH primitive: " + token)
	if atmosphere_id < 0 or atmosphere_id > 8 or backdrop_style < 0 or backdrop_style > 10 or foreground_style < 0 or foreground_style > 10:
		errors.append("Atmosphere identity or voice style is outside the source catalogue.")
	return errors
