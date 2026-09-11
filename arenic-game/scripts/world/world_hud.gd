class_name ArenicWorldHUD
extends Control
## Persistent screen-space chrome. Overview blends into inexpensive themed glass.

signal toggle_requested
signal ability_requested
signal ability_released
signal world_rect_changed

const DISPLAY_FONT: Font = preload("res://assets/fonts/PPMigra-Extrabold.ttf")
const BODY_FONT: Font = preload("res://assets/fonts/Barlow-Regular.ttf")
const TOP_HEIGHT: float = 35.0
const BOTTOM_HEIGHT: float = 96.0 # Keep the 589px world band and native 19px tiles.
const DAMAGE_BAR_HEIGHT: float = 9.0

var _top: Panel
var _bottom: Panel
var _brand: Label
var _damage_label: Label
var _phase_label: Label
var _damage_bar: ArenicArenaDamageBar
var _top_context: Label
var _arena_key: Label
var _hero_label: Label
var _class_label: Label
var _hero_status: Label
var _arena_label: Label
var _subtitle: Label
var _ability: Button
var _ability_status: Label
var _key_hint: Label
var _secondary_hint: Label
var _toggle: Button
var _accent: ColorRect
var _top_divider: ColorRect
var _hero_divider: ColorRect
var _total_damage: int = 0
var _phase_damage: int = 20
var _ability_title: String = "Ability"
var _ability_status_text: String = "Choose a hero"
var _ability_cooldown: float = 0.0
var _ability_active: float = 0.0
var _ability_enabled: bool = false
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
	_apply_damage()
	_apply_ability()
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


## Damage is cumulative; per-phase damage is the layer threshold, not the remainder.
func set_damage_progress(total_damage: int, phase_damage: int = 20) -> void:
	var next_total: int = maxi(0, total_damage)
	var next_phase: int = maxi(1, phase_damage)
	if is_node_ready() and next_total == _total_damage and next_phase == _phase_damage:
		return
	_total_damage = next_total
	_phase_damage = next_phase
	if is_node_ready():
		_apply_damage()


## The shell owns input and timers; positive infinity denotes a held channel.
func set_ability_context(title: String, status: String, cooldown: float, active_remaining: float, enabled: bool) -> void:
	_ability_title = title if not title.is_empty() else "Ability"
	_ability_status_text = status
	_ability_cooldown = maxf(0.0, cooldown) if is_finite(cooldown) else 0.0
	_ability_active = maxf(0.0, active_remaining) if not is_nan(active_remaining) else 0.0
	_ability_enabled = enabled
	if is_node_ready():
		_apply_ability()


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
	_damage_bar = ArenicArenaDamageBar.new()
	_damage_bar.name = "DamageBar"
	_top.add_child(_damage_bar)
	_damage_label = _make_label(_top, "DamageLabel", "Damage  0", BODY_FONT, 12)
	_phase_label = _make_label(_top, "PhaseLabel", "Phase 1  ·  0 / 20", BODY_FONT, 12)
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
	_ability = Button.new()
	_ability.name = "AbilityAction"
	_ability.focus_mode = Control.FOCUS_NONE
	_ability.mouse_filter = Control.MOUSE_FILTER_STOP
	_ability.clip_text = true
	_ability.add_theme_font_override("font", BODY_FONT)
	_ability.add_theme_font_size_override("font_size", 13)
	_ability.button_down.connect(_on_ability_down)
	_ability.button_up.connect(_on_ability_up)
	_bottom.add_child(_ability)
	_ability_status = _make_label(_bottom, "AbilityStatus", "Choose a hero", BODY_FONT, 12)
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
		_ability.add_theme_stylebox_override(state_name, style)
	_toggle.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_ability.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


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
	for label: Label in [_damage_label, _phase_label, _top_context, _hero_status, _subtitle, _secondary_hint, _ability_status]:
		label.add_theme_color_override("font_color", _color("base_content", 0.78))
	_class_label.add_theme_color_override("font_color", primary)
	_key_hint.add_theme_color_override("font_color", content)
	_damage_bar.set_visual_theme(_visual_theme)
	_accent.color = primary
	_border_width = maxi(1, roundi(_visual_theme.border)) if _visual_theme != null else 1
	_arena_key.add_theme_color_override("font_color", primary)
	for button: Button in [_toggle, _ability]:
		button.add_theme_color_override("font_color", content)
		button.add_theme_color_override("font_hover_color", content)
		button.add_theme_color_override("font_pressed_color", primary)
		button.add_theme_color_override("font_disabled_color", _color("base_content", 0.38))
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
	_place(_damage_bar, 0.0, 0.0, size.x, DAMAGE_BAR_HEIGHT)
	var label_height: float = TOP_HEIGHT - DAMAGE_BAR_HEIGHT
	_place(_brand, 13.0, DAMAGE_BAR_HEIGHT, 79.0, label_height)
	_place(_top_divider, 108.0, 15.0, 1.0, 14.0)
	_place(_damage_label, 127.0, DAMAGE_BAR_HEIGHT, 123.0, label_height)
	_place(_phase_label, 265.0, DAMAGE_BAR_HEIGHT, 200.0, label_height)
	_place(_top_context, 475.0, DAMAGE_BAR_HEIGHT, maxf(0.0, size.x - 527.0), label_height)
	_place(_arena_key, size.x - 39.0, 11.0, 26.0, 22.0)
	_place(_accent, 13.0, 14.0, 2.0, 48.0)
	_place(_class_label, 25.0, 9.0, 250.0, 18.0)
	_place(_hero_label, 24.0, 27.0, 260.0, 36.0)
	_place(_hero_status, 25.0, 69.0, 250.0, 18.0)
	_place(_hero_divider, 302.0, 16.0, 1.0, 65.0)
	var center_width: float = maxf(0.0, size.x - 670.0)
	_place(_subtitle, 323.0, 9.0, center_width, 18.0)
	_place(_arena_label, 322.0, 28.0, center_width, 35.0)
	_place(_ability, 323.0, 67.0, 222.0, 24.0)
	_place(_ability_status, 557.0, 69.0, maxf(0.0, size.x - 904.0), 20.0)
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


func _apply_damage() -> void:
	_damage_bar.set_progress(_total_damage, _phase_damage)
	_damage_label.text = "Damage  %d" % _total_damage
	_phase_label.text = "Phase %d  ·  %d / %d" % [_damage_bar.completed_phases + 1, _damage_bar.current_damage, _phase_damage]
	_damage_bar.tooltip_text = "%d damage · %d completed phases" % [_total_damage, _damage_bar.completed_phases]


func _apply_ability() -> void:
	var channeling: bool = is_inf(_ability_active) and _ability_active > 0.0
	_ability.text = _ability_title + "   [SPACE]"
	_ability.disabled = not (_ability_enabled or channeling)
	if channeling:
		_ability_status.text = "Channeling · release to stop"
	else:
		var parts: PackedStringArray = []
		if not _ability_status_text.is_empty():
			parts.append(_ability_status_text)
		if _ability_active > 0.0:
			parts.append("%.1fs active" % _ability_active)
		if _ability_cooldown > 0.0:
			parts.append("%.1fs cooldown" % _ability_cooldown)
		_ability_status.text = " · ".join(parts) if not parts.is_empty() else "Ready"
	_ability.tooltip_text = _ability_title + " · " + _ability_status.text


func _on_ability_down() -> void:
	ability_requested.emit()


func _on_ability_up() -> void:
	ability_released.emit()


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
