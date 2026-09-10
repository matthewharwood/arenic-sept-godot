class_name ArenicDisplayPolicy
extends Node
## Physical window sizing is a platform boundary; game/camera coordinates stay logical.
const GAME_LAYOUT := Vector2i(1280, 720)
const USABLE_FRACTION: float = 0.90


func _ready() -> void:
	set_process(false)
	if OS.has_feature("web") or DisplayServer.get_name() == "headless" or Engine.is_editor_hint():
		return
	# Tests, embedded previews and explicit launch sizes own their window geometry.
	var arguments: PackedStringArray = OS.get_cmdline_args()
	for argument: String in arguments:
		if argument in ["--script", "-s", "--resolution", "--wid", "--fullscreen", "-f", "--maximized", "-m"]:
			return
	var window := get_window()
	if window.is_embedded() or window.mode != Window.MODE_WINDOWED:
		return
	var screen: int = window.current_screen
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen)
	if not usable.has_area():
		return
	var density: float = DisplayServer.screen_get_scale(screen)
	if OS.get_name() == "macOS":
		# Godot's Cocoa window coordinates use the maximum connected backing scale,
		# including a non-Retina screen beside a Retina screen (Godot 4.7.2).
		density = DisplayServer.screen_get_max_scale()
	window.size = initial_window_size(usable.size, density)
	window.position = usable.position + (usable.size - window.size) / 2


static func initial_window_size(usable_size: Vector2i, density: float) -> Vector2i:
	if not is_finite(density) or density <= 0.0:
		density = 1.0
	var desired: Vector2 = Vector2(GAME_LAYOUT) * density
	var available: Vector2 = Vector2(usable_size).max(Vector2.ONE) * USABLE_FRACTION
	var fit: float = minf(1.0, minf(available.x / desired.x, available.y / desired.y))
	# Whole 16:9 units avoid an accidental one-pixel letterbox in the default window.
	var unit: int = maxi(1, floori(minf(desired.x * fit / 16.0, desired.y * fit / 9.0)))
	return Vector2i(16, 9) * unit


static func apply_game_layout(window: Window) -> void:
	window.content_scale_size = GAME_LAYOUT
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	window.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
