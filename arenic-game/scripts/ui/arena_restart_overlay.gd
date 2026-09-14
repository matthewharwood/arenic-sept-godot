class_name ArenicArenaRestartOverlay
extends Control
## Transient, input-transparent presentation. The shell owns every phase and
## clock; showing this view never pauses, rewinds, or starts an arena itself.

const BODY_FONT: Font = preload("res://assets/fonts/Barlow-Regular.ttf")
const NUMBER_FONT: Font = preload("res://assets/fonts/Rajdhani-Bold.ttf")
const SURFACE: Vector3 = Vector3(0.15, 0.014, 270.0)

var _phase: String = ""
var _visual_theme: ArenicArenaTheme
var _caption: Label
var _readout: Label
var _panel_rect: Rect2
var _chevron_rect: Rect2
var _surface: Color
var _accent: Color


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	_caption = _label("Caption", BODY_FONT)
	_readout = _label("Readout", NUMBER_FONT)
	var converter := ArenicArenaTheme.new()
	converter.palette = {"surface": SURFACE}
	_surface = converter.color("surface", 0.87)
	_accent = ArenicHudTokens.color("selection")
	_caption.add_theme_color_override("font_color", ArenicHudTokens.color("content", null, 0.85))
	_readout.add_theme_color_override("font_color", ArenicHudTokens.color("content"))
	resized.connect(_layout)
	hide()


## `phase` is "rewind", "countdown", or empty to hide. display_tick is the
## visual position in the existing 60 Hz, 120-second cycle, never a time source.
func present(phase: String, countdown: int, display_tick: float, arena_theme: ArenicArenaTheme) -> void:
	if phase not in ["rewind", "countdown"]:
		_phase = ""
		hide()
		return
	var seconds: int = floori(clampf(display_tick, 0.0, 7200.0) / 60.0) if is_finite(display_tick) else 0
	var next_text: String = "%d:%02d" % [seconds / 60, seconds % 60] if phase == "rewind" else str(clampi(countdown, 1, 3))
	var changed: bool = _phase != phase or _readout.text != next_text
	_phase = phase
	_caption.text = "Rewinding" if phase == "rewind" else "Arena starts in"
	_readout.text = next_text
	if _visual_theme != arena_theme:
		_visual_theme = arena_theme
		_accent = arena_theme.color("accent") if arena_theme != null else ArenicHudTokens.color("selection")
		changed = true
	if changed:
		_layout()
	show()


func _label(node_name: String, font: Font) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.focus_mode = Control.FOCUS_NONE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.add_theme_font_override("font", font)
	add_child(label)
	return label


func _layout() -> void:
	if _phase.is_empty() or size.x <= 0.0 or size.y <= 0.0:
		return
	# Fit the whole composition, including padding, to the caller's actual rect.
	# Measure the two shaped lines at their chosen font sizes rather than using
	# character counts; small world rectangles get proportionally smaller text.
	var factor: float = minf(1.0, minf(size.x / 320.0, size.y / 220.0))
	var caption_size: int = maxi(1, roundi(16.0 * factor))
	var number_size: int = maxi(1, roundi((28.0 if _phase == "rewind" else 72.0) * factor))
	_caption.add_theme_font_size_override("font_size", caption_size)
	_readout.add_theme_font_size_override("font_size", number_size)
	var caption_extent: Vector2 = BODY_FONT.get_string_size(_caption.text, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_size)
	var readout_extent: Vector2 = NUMBER_FONT.get_string_size(_readout.text, HORIZONTAL_ALIGNMENT_LEFT, -1, number_size)
	caption_extent.y = ceilf(BODY_FONT.get_height(caption_size))
	readout_extent.y = ceilf(NUMBER_FONT.get_height(number_size))
	var icon_width: float = 24.0 * factor if _phase == "rewind" else 0.0
	var padding: float = (12.0 if _phase == "rewind" else 22.0) * factor
	var gap: float = 6.0 * factor
	var content_width: float = maxf(caption_extent.x + icon_width, readout_extent.x)
	var panel_size := Vector2(content_width + padding * 2.0, caption_extent.y + gap + readout_extent.y + padding * 2.0)
	_panel_rect = Rect2((size - panel_size) * 0.5, panel_size)
	if _phase == "rewind":
		# Keep the founder and its reverse path clear near the arena center.
		_panel_rect.position.y = 12.0 * factor
	var y: float = _panel_rect.position.y + padding
	_caption.position = Vector2((size.x - caption_extent.x - icon_width) * 0.5 + icon_width, y)
	_caption.size = caption_extent
	_readout.position = Vector2((size.x - readout_extent.x) * 0.5, y + caption_extent.y + gap)
	_readout.size = readout_extent
	_chevron_rect = Rect2(Vector2(_caption.position.x - icon_width, y + caption_extent.y * 0.5 - 5.0 * factor), Vector2(15.0, 10.0) * factor)
	queue_redraw()


func _draw() -> void:
	if _phase.is_empty():
		return
	draw_rect(_panel_rect, _surface)
	draw_rect(_panel_rect, Color(_accent, 0.36), false, 1.0)
	if _phase != "rewind":
		return
	var edge: Vector2 = _chevron_rect.position
	var unit: Vector2 = _chevron_rect.size / Vector2(3.0, 2.0)
	for offset: float in [0.0, unit.x * 2.0]:
		var tip: Vector2 = edge + Vector2(offset, unit.y)
		draw_polyline(PackedVector2Array([tip + Vector2(unit.x, -unit.y), tip, tip + unit]), _accent, 1.5, true)
