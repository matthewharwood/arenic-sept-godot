class_name ArenicWorldHUD
extends Control
## Persistent screen-space outline. This scene owns no gameplay or camera state.

signal toggle_requested
signal world_rect_changed

const INK: Color = Color(0.11, 0.11, 0.11, 1.0)
const MUTED: Color = Color(0.43, 0.43, 0.43, 1.0)
const OUTLINE: Color = Color(0.77, 0.77, 0.77, 1.0)
const BLUE: Color = Color(0.15, 0.39, 0.77, 1.0)
const PAPER: Color = Color(1.0, 1.0, 1.0, 1.0)
const TOP_HEIGHT: float = 35.0
const BOTTOM_HEIGHT: float = 96.0 # 589px world band: tile edges land on whole pixels.

var _title_font: Font
var _body_font: Font
var _top: Panel
var _bottom: Panel
var _progress_label: Label
var _progress_outline: Panel
var _boss_label: Label
var _boss_outline: Panel
var _top_context: Label
var _hero_label: Label
var _class_label: Label
var _arena_label: Label
var _future_label: Label
var _key_hint: Label
var _toggle: Button
var _stubs: Array[Button] = []
var _arena: ArenicArenaDefinition
var _hero_name: String = ""
var _class_name_text: String = ""
var _zoomed: bool = false
var _hero_here: bool = false
var _hero_selected: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title_font = load("res://assets/fonts/PPMigra-Extrabold.ttf") as Font
	_body_font = load("res://assets/fonts/Barlow-Regular.ttf") as Font
	_build_hud()
	resized.connect(_on_resized)
	_apply_context()
	_layout_hud()
	world_rect_changed.emit()


func get_world_rect() -> Rect2:
	return Rect2(13.0, TOP_HEIGHT, maxf(0.0, size.x - 26.0), maxf(0.0, size.y - TOP_HEIGHT - BOTTOM_HEIGHT))


func set_context(arena: ArenicArenaDefinition, hero_name: String, class_name_text: String, zoomed: bool) -> void:
	_arena = arena
	_hero_name = hero_name
	_class_name_text = class_name_text
	_zoomed = zoomed
	if is_node_ready():
		_apply_context()


func _build_hud() -> void:
	_top = _make_panel(self, "TopStrip", _box(PAPER, OUTLINE))
	_bottom = _make_panel(self, "BottomStrip", _box(PAPER, OUTLINE))
	_progress_label = _make_label(_top, "ProgressLabel", "Progress · placeholder", _body_font, 12, MUTED)
	_progress_outline = _make_panel(_top, "ProgressPlaceholder", _box(PAPER, OUTLINE))
	_boss_label = _make_label(_top, "BossLabel", "Boss health · placeholder", _body_font, 12, MUTED)
	_boss_outline = _make_panel(_top, "BossHealthPlaceholder", _box(PAPER, OUTLINE))
	_top_context = _make_label(_top, "ViewContext", "Overview", _body_font, 13, MUTED)
	_top_context.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hero_label = _make_label(_bottom, "HeroName", "No hero selected", _title_font, 23, INK)
	_class_label = _make_label(_bottom, "ClassName", "Class not selected", _body_font, 14, MUTED)
	_arena_label = _make_label(_bottom, "ArenaName", "No arena selected", _body_font, 14, INK)
	var action_names: PackedStringArray = PackedStringArray(["Roster", "Loot", "Auction", "Craft"])
	for action_name: String in action_names:
		var stub: Button = _make_button(action_name, action_name, _body_font, 16)
		stub.disabled = true
		stub.focus_mode = Control.FOCUS_NONE
		stub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stub.tooltip_text = "Future action; not implemented."
		_bottom.add_child(stub)
		_stubs.append(stub)
	_future_label = _make_label(_bottom, "FutureActions", "Future actions", _body_font, 12, MUTED)
	_future_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toggle = _make_button("OverviewToggle", "Overview [P]", _title_font, 18)
	_toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.pressed.connect(_on_toggle_pressed)
	_bottom.add_child(_toggle)
	_key_hint = _make_label(_bottom, "NavigationHint", "← ↑ ↓ → Select   Enter Zoom", _body_font, 13, BLUE)
	_key_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _apply_context() -> void:
	var arena_name: String = _arena.display_name if _arena != null else "No arena selected"
	_hero_label.text = _hero_name if not _hero_name.is_empty() else "No hero selected"
	_class_label.text = _class_name_text if not _class_name_text.is_empty() else "Class not selected"
	_arena_label.text = arena_name
	_top_context.text = ("Arena view · " if _zoomed else "Overworld · ") + arena_name
	_toggle.text = "Overview [P]" if _zoomed else "Zoom in [P]"
	_toggle.disabled = _arena == null
	if _zoomed and _hero_here:
		_key_hint.text = "Arrows Step · Tab Select" if _hero_selected else "Click hero or Tab to select"
	else:
		_key_hint.text = "Arrows Select · Enter Zoom · Tab Hero"


func _layout_hud() -> void:
	_place(_top, 0.0, 0.0, size.x, TOP_HEIGHT)
	_place(_bottom, 0.0, size.y - BOTTOM_HEIGHT, size.x, BOTTOM_HEIGHT)
	_place(_progress_label, 13.0, 7.0, 137.0, 21.0)
	_place(_progress_outline, 153.0, 11.0, 130.0, 13.0)
	_place(_boss_label, 316.0, 7.0, 153.0, 21.0)
	_place(_boss_outline, 474.0, 11.0, 202.0, 13.0)
	_place(_top_context, 710.0, 7.0, maxf(0.0, size.x - 723.0), 21.0)
	_place(_hero_label, 13.0, 10.0, 375.0, 29.0)
	_place(_class_label, 13.0, 42.0, 375.0, 19.0)
	_place(_arena_label, 13.0, 65.0, 375.0, 19.0)
	var actions_width: float = 364.0
	var actions_left: float = size.x * 0.5 - actions_width * 0.5
	for index: int in range(_stubs.size()):
		_place(_stubs[index], actions_left + float(index) * 93.0, 24.0, 85.0, 38.0)
	_place(_future_label, actions_left, 68.0, actions_width, 18.0)
	_place(_toggle, size.x - 193.0, 17.0, 180.0, 43.0)
	_place(_key_hint, size.x - 303.0, 68.0, 290.0, 19.0)


func _on_resized() -> void:
	if not is_node_ready():
		return
	_layout_hud()
	world_rect_changed.emit()


func _on_toggle_pressed() -> void:
	toggle_requested.emit()


func _make_label(parent: Control, node_name: String, text: String, font: Font, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.name = node_name
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	if font != null:
		label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _make_panel(parent: Control, node_name: String, style: StyleBoxFlat) -> Panel:
	var panel: Panel = Panel.new()
	panel.name = node_name
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel


func _make_button(node_name: String, text: String, font: Font, font_size: int) -> Button:
	var button: Button = Button.new()
	button.name = node_name
	button.text = text
	if font != null:
		button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_disabled_color", MUTED)
	button.add_theme_stylebox_override("normal", _box(PAPER, INK, 1, 5))
	button.add_theme_stylebox_override("hover", _box(Color(0.95, 0.97, 1.0, 1.0), BLUE, 1, 5))
	button.add_theme_stylebox_override("pressed", _box(Color(0.90, 0.94, 1.0, 1.0), BLUE, 1, 5))
	button.add_theme_stylebox_override("disabled", _box(PAPER, OUTLINE, 1, 5))
	button.add_theme_stylebox_override("focus", _box(Color(0.0, 0.0, 0.0, 0.0), BLUE, 2, 5))
	return button


func _box(fill: Color, border: Color, border_width: int = 1, corner_radius: int = 0) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	return style


func _place(control: Control, x: float, y: float, width: float, height: float) -> void:
	control.position = Vector2(x, y)
	control.size = Vector2(width, height)

func set_hero_control(here: bool, selected: bool) -> void:
	_hero_here = here
	_hero_selected = selected
	if is_node_ready():
		_apply_context()
