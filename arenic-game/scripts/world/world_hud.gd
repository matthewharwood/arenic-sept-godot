class_name ArenicWorldHUD
extends Control
## Persistent screen-space chrome. Overview blends into inexpensive themed glass.

signal toggle_requested
signal world_rect_changed

const DISPLAY_FONT: Font = preload("res://assets/fonts/PPMigra-Extrabold.ttf")
const BODY_FONT: Font = preload("res://assets/fonts/Barlow-Regular.ttf")
const TOP_HEIGHT: float = 35.0
const BOTTOM_HEIGHT: float = 96.0 # Keep the 589px world band and native 19px tiles.

var _top: Panel
var _bottom: Panel
var _brand: Label
var _progress_label: Label
var _boss_label: Label
var _top_context: Label
var _arena_key: Label
var _hero_label: Label
var _class_label: Label
var _hero_status: Label
var _arena_label: Label
var _subtitle: Label
var _future_label: Label
var _key_hint: Label
var _secondary_hint: Label
var _toggle: Button
var _accent: ColorRect
var _top_divider: ColorRect
var _hero_divider: ColorRect
var _stubs: Array[Button] = []
var _arena: ArenicArenaDefinition
var _visual_theme: ArenicArenaTheme
var _hero_name: String = ""
var _class_name_text: String = ""
var _zoomed: bool = false
var _hero_here: bool = false
var _hero_selected: bool = false
var _overview_mix: float = 0.0
var _top_style: StyleBoxFlat
var _bottom_style: StyleBoxFlat
var _key_style: StyleBoxFlat
var _toggle_styles: Array[StyleBoxFlat] = [] # Normal, hover, pressed, disabled.
var _top_sheen: TextureRect
var _bottom_sheen: TextureRect
var _sheen_gradient: Gradient
var _surface_color: Color
var _content_color: Color
var _primary_color: Color
var _deep_color: Color
var _field_color: Color
var _rail_color: Color
var _edge_color: Color
var _border_width: int = 1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_hud()
	resized.connect(_on_resized)
	_apply_context()
	_apply_palette()
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


func set_hero_control(here: bool, selected: bool) -> void:
	_hero_here = here
	_hero_selected = selected
	if is_node_ready():
		_apply_context()


## Zero preserves focused chrome; one reveals the sky through smoked glass.
## The stage owns this blend. No HUD animation or screen-reading pass is needed.
func set_overview_mix(value: float) -> void:
	var next_mix: float = clampf(value, 0.0, 1.0)
	if not is_finite(next_mix) or next_mix == _overview_mix:
		return
	_overview_mix = next_mix
	if is_node_ready():
		_apply_surfaces()


func _build_hud() -> void:
	_top = _make_panel(self, "TopStrip")
	_bottom = _make_panel(self, "BottomStrip")
	_sheen_gradient = Gradient.new()
	_sheen_gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
	var sheen_texture := GradientTexture2D.new()
	sheen_texture.width = 4
	sheen_texture.height = 64
	sheen_texture.gradient = _sheen_gradient
	sheen_texture.fill_from = Vector2.ZERO
	sheen_texture.fill_to = Vector2(0.0, 1.0)
	_top_sheen = _make_sheen(_top, sheen_texture)
	_bottom_sheen = _make_sheen(_bottom, sheen_texture)
	_brand = _make_label(_top, "Wordmark", "Arenic", DISPLAY_FONT, 19)
	_top_divider = _make_rule(_top, "StatusDivider")
	_progress_label = _make_label(_top, "ProgressLabel", "Progress  —", BODY_FONT, 12)
	_boss_label = _make_label(_top, "BossLabel", "Boss health  —", BODY_FONT, 12)
	_top_context = _make_label(_top, "ViewContext", "OVERWORLD", BODY_FONT, 12)
	_top_context.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_arena_key = _make_label(_top, "ArenaHotkey", "—", BODY_FONT, 13)
	_arena_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_accent = _make_rule(_bottom, "HeroAccent")
	_hero_divider = _make_rule(_bottom, "HeroDivider")
	_class_label = _make_label(_bottom, "ClassName", "HERO", BODY_FONT, 12)
	_hero_label = _make_label(_bottom, "HeroName", "No hero selected", DISPLAY_FONT, 28)
	_hero_status = _make_label(_bottom, "HeroControl", "Tab to locate", BODY_FONT, 12)
	_subtitle = _make_label(_bottom, "ArenaSubtitle", "", BODY_FONT, 12)
	_arena_label = _make_label(_bottom, "ArenaName", "No arena selected", DISPLAY_FONT, 27)
	_future_label = _make_label(_bottom, "FutureActions", "LATER", BODY_FONT, 10)
	for action_name: String in PackedStringArray(["Roster", "Loot", "Auction", "Craft"]):
		var stub := Button.new()
		stub.name = action_name
		stub.text = action_name + " —"
		stub.disabled = true
		stub.focus_mode = Control.FOCUS_NONE
		stub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stub.alignment = HORIZONTAL_ALIGNMENT_LEFT
		stub.add_theme_font_override("font", BODY_FONT)
		stub.add_theme_font_size_override("font_size", 12)
		stub.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
		_bottom.add_child(stub)
		_stubs.append(stub)
	_toggle = Button.new()
	_toggle.name = "OverviewToggle"
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	_toggle.add_theme_font_override("font", BODY_FONT)
	_toggle.add_theme_font_size_override("font_size", 16)
	_toggle.pressed.connect(_on_toggle_pressed)
	_bottom.add_child(_toggle)
	_key_hint = _make_label(_bottom, "NavigationHint", "", BODY_FONT, 13)
	_key_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_secondary_hint = _make_label(_bottom, "NavigationDetail", "", BODY_FONT, 12)
	_secondary_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_top_style = StyleBoxFlat.new()
	_bottom_style = StyleBoxFlat.new()
	_key_style = StyleBoxFlat.new()
	_top.add_theme_stylebox_override("panel", _top_style)
	_bottom.add_theme_stylebox_override("panel", _bottom_style)
	_arena_key.add_theme_stylebox_override("normal", _key_style)
	for state_name: String in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		_toggle_styles.append(style)
		_toggle.add_theme_stylebox_override(state_name, style)
	_toggle.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _apply_context() -> void:
	var next_theme: ArenicArenaTheme = _arena.visual_theme if _arena != null else null
	if next_theme != _visual_theme:
		_visual_theme = next_theme
		_apply_palette()
	var arena_name: String = _arena.display_name if _arena != null else "No arena selected"
	_hero_label.text = _hero_name if not _hero_name.is_empty() else "No hero selected"
	_class_label.text = _class_name_text.to_upper() if not _class_name_text.is_empty() else "HERO"
	_arena_label.text = arena_name
	_subtitle.text = _visual_theme.subtitle if _visual_theme != null else ""
	_top_context.text = ("ARENA  /  " if _zoomed else "OVERWORLD  /  ") + arena_name.to_upper()
	_arena_key.text = _arena.hotkey if _arena != null else "—"
	_toggle.text = "Overview     [P]" if _zoomed else "Zoom in     [P]"
	_toggle.disabled = _arena == null
	_hero_status.text = "Selected" if _hero_here and _hero_selected else ("Click to select" if _hero_here else "Tab to locate")
	if _zoomed and _hero_here:
		_key_hint.text = "ARROWS  Step · TAB  Select" if _hero_selected else "TAB  Select hero"
		_secondary_hint.text = "ESC  Overview · Click hero to select"
	elif _zoomed:
		_key_hint.text = "ARROWS  Select · TAB  Hero"
		_secondary_hint.text = "[ ]  Cycle · ESC  Overview"
	else:
		_key_hint.text = "ARROWS  Select · ENTER  Zoom"
		_secondary_hint.text = "[ ]  Cycle · TAB  Hero · Wheel  Zoom"


func _apply_palette() -> void:
	_surface_color = _color("base_100")
	_content_color = _color("base_content")
	_primary_color = _color("primary")
	_deep_color = _color("base_300")
	_field_color = _color("base_200")
	var content: Color = _color("base_content")
	var primary: Color = _color("primary")
	for label: Label in [_brand, _hero_label, _arena_label]:
		label.add_theme_color_override("font_color", content)
	for label: Label in [_progress_label, _boss_label, _top_context, _hero_status, _subtitle, _secondary_hint]:
		label.add_theme_color_override("font_color", _color("base_content", 0.78))
	_class_label.add_theme_color_override("font_color", primary)
	_key_hint.add_theme_color_override("font_color", content)
	_future_label.add_theme_color_override("font_color", _color("base_content", 0.55))
	for stub: Button in _stubs:
		stub.add_theme_color_override("font_disabled_color", _color("base_content", 0.38))
	_accent.color = primary
	_border_width = maxi(1, roundi(_visual_theme.border)) if _visual_theme != null else 1
	_arena_key.add_theme_color_override("font_color", primary)
	_toggle.add_theme_color_override("font_color", content)
	_toggle.add_theme_color_override("font_hover_color", content)
	_toggle.add_theme_color_override("font_pressed_color", primary)
	_toggle.add_theme_color_override("font_disabled_color", _color("base_content", 0.38))
	var sheen: Color = content.lerp(primary, 0.18)
	_sheen_gradient.colors = PackedColorArray([
		Color(sheen, 0.13), Color(sheen, 0.035), Color(sheen, 0.0),
	])
	_apply_surfaces()


func _apply_surfaces() -> void:
	# Mutate seven existing style resources; never rebuild controls while blending.
	var fill: Color = _surface_color.lerp(_primary_color, 0.08 * _overview_mix)
	fill.a = lerpf(1.0, 0.78, _overview_mix)
	_edge_color = _content_color.lerp(_primary_color, 0.24 * _overview_mix)
	_edge_color.a = lerpf(0.18, 0.32, _overview_mix)
	# HUD strips meet the viewport edges: square glass, without an outer frame.
	for style: StyleBoxFlat in [_top_style, _bottom_style]:
		style.bg_color = fill
		style.border_color = _edge_color
		style.set_border_width_all(0)
		style.set_corner_radius_all(0)
		style.shadow_size = 0
		style.shadow_offset = Vector2.ZERO
	_top_style.border_width_bottom = 1
	_bottom_style.border_width_top = 1
	var field: Color = _field_color.lerp(_primary_color, 0.08 * _overview_mix)
	field.a = lerpf(1.0, 0.64, _overview_mix)
	_key_style.bg_color = field
	_key_style.border_color = _edge_color
	_key_style.set_border_width_all(_border_width)
	_key_style.set_corner_radius_all(0)
	var hover: Color = _deep_color.lerp(_primary_color, 0.12 * _overview_mix)
	hover.a = lerpf(1.0, 0.88, _overview_mix)
	for index: int in range(_toggle_styles.size()):
		var style: StyleBoxFlat = _toggle_styles[index]
		style.bg_color = field if index == 0 else (fill if index == 3 else hover)
		style.border_color = _edge_color if index == 3 else Color(_primary_color, 0.65 if index == 0 else 1.0)
		style.set_border_width_all(_border_width + (1 if index == 2 else 0))
		style.set_corner_radius_all(0)
	_rail_color = Color(_field_color, lerpf(1.0, 0.50, _overview_mix))
	_top_divider.color = _edge_color
	_hero_divider.color = _edge_color
	_top_sheen.modulate.a = _overview_mix
	_bottom_sheen.modulate.a = _overview_mix
	_top_sheen.visible = _overview_mix > 0.001
	_bottom_sheen.visible = _overview_mix > 0.001
	queue_redraw()


func _color(token: String, alpha: float = 1.0) -> Color:
	if _visual_theme != null:
		return _visual_theme.color(token, alpha)
	# A neutral, readable shell while no arena has been supplied.
	var value: float = 1.0 if token in ["base_content", "primary"] else 0.0
	return Color(value, value, value, alpha)


func _layout_hud() -> void:
	_place(_top, 0.0, 0.0, size.x, TOP_HEIGHT)
	_place(_bottom, 0.0, size.y - BOTTOM_HEIGHT, size.x, BOTTOM_HEIGHT)
	_place(_top_sheen, 0.0, 0.0, size.x, 17.0)
	_place(_bottom_sheen, 0.0, 1.0, size.x, 42.0)
	_place(_brand, 13.0, 0.0, 79.0, TOP_HEIGHT)
	_place(_top_divider, 108.0, 10.0, 1.0, 15.0)
	_place(_progress_label, 127.0, 0.0, 115.0, TOP_HEIGHT)
	_place(_boss_label, 265.0, 0.0, 140.0, TOP_HEIGHT)
	_place(_top_context, 450.0, 0.0, maxf(0.0, size.x - 502.0), TOP_HEIGHT)
	_place(_arena_key, size.x - 39.0, 7.0, 26.0, 22.0)
	_place(_accent, 13.0, 14.0, 2.0, 48.0)
	_place(_class_label, 25.0, 9.0, 250.0, 18.0)
	_place(_hero_label, 24.0, 27.0, 260.0, 36.0)
	_place(_hero_status, 25.0, 69.0, 250.0, 18.0)
	_place(_hero_divider, 302.0, 16.0, 1.0, 65.0)
	var center_width: float = maxf(0.0, size.x - 670.0)
	_place(_subtitle, 323.0, 9.0, center_width, 18.0)
	_place(_arena_label, 322.0, 28.0, center_width, 35.0)
	_place(_future_label, 323.0, 70.0, 39.0, 18.0)
	for index: int in range(_stubs.size()):
		_place(_stubs[index], 369.0 + float(index) * 70.0, 69.0, 66.0, 19.0)
	_place(_toggle, size.x - 193.0, 12.0, 180.0, 37.0)
	_place(_key_hint, size.x - 326.0, 55.0, 313.0, 19.0)
	_place(_secondary_hint, size.x - 326.0, 75.0, 313.0, 16.0)


func _draw() -> void:
	var world_rect: Rect2 = get_world_rect()
	draw_rect(Rect2(0.0, TOP_HEIGHT, 13.0, world_rect.size.y), _rail_color)
	draw_rect(Rect2(size.x - 13.0, TOP_HEIGHT, 13.0, world_rect.size.y), _rail_color)
	draw_line(Vector2(12.0, TOP_HEIGHT), Vector2(12.0, world_rect.end.y), _edge_color)
	draw_line(Vector2(size.x - 13.0, TOP_HEIGHT), Vector2(size.x - 13.0, world_rect.end.y), _edge_color)


func _on_resized() -> void:
	if not is_node_ready():
		return
	_layout_hud()
	queue_redraw()
	world_rect_changed.emit()


func _on_toggle_pressed() -> void:
	toggle_requested.emit()


func _make_label(parent: Control, node_name: String, text: String, font: Font, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _make_panel(parent: Control, node_name: String) -> Panel:
	var panel := Panel.new()
	panel.name = node_name
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(panel)
	return panel


func _make_rule(parent: Control, node_name: String) -> ColorRect:
	var rule := ColorRect.new()
	rule.name = node_name
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rule)
	return rule


func _make_sheen(parent: Control, texture: GradientTexture2D) -> TextureRect:
	var sheen := TextureRect.new()
	sheen.name = "GlassSheen"
	sheen.texture = texture
	sheen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sheen.stretch_mode = TextureRect.STRETCH_SCALE
	sheen.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sheen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sheen.visible = false
	parent.add_child(sheen)
	return sheen


func _place(control: Control, x: float, y: float, width: float, height: float) -> void:
	control.position = Vector2(x, y)
	control.size = Vector2(width, height)
