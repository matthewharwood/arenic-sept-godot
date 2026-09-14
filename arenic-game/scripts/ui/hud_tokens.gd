class_name ArenicHudTokens
extends RefCounted
## Semantic HUD sources stay in OKLCH; arena resources own the output conversion.
## Health/selection are blue, progress/gains green, and damage/debuffs red.

const XP: Vector3 = Vector3(0.70, 0.15, 150.0)
const HP: Vector3 = Vector3(0.68, 0.17, 250.0)
const NEGATIVE: Vector3 = Vector3(0.70, 0.20, 24.0)
const DEBUG: Vector3 = Vector3(0.68, 0.0, 0.0)
const WARNING: Vector3 = Vector3(0.82, 0.14, 85.0)
const SELECTION: Vector3 = Vector3(0.64, 0.22, 260.0)
const LIGHT_CONTENT: Vector3 = Vector3(0.96, 0.004, 260.0)
const DARK_CONTENT: Vector3 = Vector3(0.15, 0.004, 260.0)


static func color(token: String, visual_theme: ArenicArenaTheme = null, alpha: float = 1.0) -> Color:
	if visual_theme != null:
		if token == "content":
			return visual_theme.color("base_content", alpha)
		if token == "muted":
			return visual_theme.color("base_content", alpha * 0.72)
		if token == "track":
			return visual_theme.color("base_content", alpha * 0.16)
	var primitive: Vector3
	match token:
		"xp", "positive":
			primitive = XP
		"hp":
			primitive = HP
		"negative", "alert":
			primitive = NEGATIVE
		"debug":
			primitive = DEBUG
		"warning":
			primitive = WARNING
		"selection":
			primitive = SELECTION
		"map_active":
			primitive = Vector3(0.0, 0.0, 0.0)
		"selected_content":
			primitive = Vector3(1.0, 0.0, 0.0)
		"content", "muted", "track":
			primitive = LIGHT_CONTENT
		_:
			push_error("Unknown semantic HUD color: " + token)
			primitive = LIGHT_CONTENT
	# Semantic text needs a darker tone on the light arena surfaces.
	if visual_theme != null and token in ["xp", "positive", "hp", "negative", "alert", "selection", "debug", "warning"]:
		if visual_theme.color("base_content").get_luminance() < 0.5:
			primitive.x = 0.49 if token in ["xp", "positive"] else 0.55
	if visual_theme == null and token in ["muted", "track"]:
		alpha *= 0.72 if token == "muted" else 0.16
	# Reuse the established OKLCH-to-Godot boundary; this transient converter is
	# not an authored arena resource or part of the twenty-token arena catalogue.
	var converter := ArenicArenaTheme.new()
	converter.palette = {"hud": primitive}
	return converter.color("hud", alpha)
