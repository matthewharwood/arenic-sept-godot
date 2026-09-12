class_name ArenicWorldHUD
extends Control
## Persistent screen-space chrome. Overview blends into inexpensive themed glass.

signal toggle_requested
signal ability_requested
signal ability_released
signal world_rect_changed
signal hero_requested(identity: int)
signal arena_requested(index: int)
signal record_requested
signal save_title_requested

const DISPLAY_FONT: Font = preload("res://assets/fonts/PPMigra-Extrabold.ttf")
const BODY_FONT: Font = preload("res://assets/fonts/Barlow-Regular.ttf")
const TOP_HEIGHT: float = 35.0
const BOTTOM_HEIGHT: float = 96.0 # Keep the 589px world band and native 19px tiles.
const DAMAGE_BAR_HEIGHT: float = 9.0

var _top: Panel
var _save_title: Button
var _save_error: Label
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
var _vitals: ArenicHeroVitals
var _roster: ArenicRosterStrip
var _roster_hint: Button
var _reserve: Button
var _reserve_panel: Panel
var _reserve_list: VBoxContainer
var _slots: Array[Button] = []
var _record: Button
var _raid: Label
var _map: Array[Button] = []
var _map_styles: Array[StyleBoxFlat] = []
var _previous: Button
var _next: Button
var _help: Button
var _help_panel: Panel
var _help_text: Label
var _world: ArenicWorldDefinition
var _hero: ArenicHeroState
var _selected_arena: int = -1
var _roster_entries: Array[Dictionary] = []
var _selected_identity: int = -1
## Ghosts per arena — what the map's X has always meant: no activity here.
var _map_counts: Array[int] = []
## Guild members standing there, recorded or not, for the tooltip.
var _map_present: Array[int] = []
## Supplied by the shell so the strip can mark a folded member without the HUD
## reaching into the conductor.
var _ghost_check: Callable = Callable()
var _recruit: Label
## Supplied by the shell so the strip can mark a fallen guild member without the
## HUD holding a combat reference of its own.
var _combat_health: Callable = Callable()


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
	_recruit = _make_label(_top, "GuildRolls", "", BODY_FONT, 12)
	_top_context = _make_label(_top, "ViewContext", "OVERWORLD", BODY_FONT, 12)
	_top_context.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_save_error = _make_label(self, "SaveError", "", BODY_FONT, 13)
	_save_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_save_error.add_theme_color_override("font_color", Color(1.0, 0.8, 0.65))
	_save_error.hide()
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
	_save_title = _small_button(_top, "SaveAndTitle", "Saved · Title")
	_save_title.pressed.connect(func() -> void: save_title_requested.emit())
	_build_roster_hud()


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
	_apply_roster_palette()


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
	_place(_recruit, 452.0, DAMAGE_BAR_HEIGHT, 232.0, label_height)
	_place(_top_context, 700.0, DAMAGE_BAR_HEIGHT, maxf(0.0, size.x - 878.0), label_height)
	_place(_save_title, size.x - 165.0, 11.0, 112.0, 22.0)
	_place(_save_error, size.x - 510.0, TOP_HEIGHT + 8.0, 480.0, 72.0)
	_place(_arena_key, size.x - 39.0, 11.0, 26.0, 22.0)
	# Preserve the existing 96px strip so the world and native 19px sprites keep their framing.
	for legacy: Control in [_accent, _class_label, _hero_label, _hero_status, _subtitle, _arena_label, _secondary_hint]:
		legacy.hide()
	_place(_roster_hint, 13, 4, 106, 17)
	_place(_reserve, 123, 4, 55, 17)
	_place(_roster, 13, 25, 160, 64)
	_place(_hero_divider, 185, 12, 1, 72)
	_place(_vitals, 200, 7, 255, 82)
	for index: int in 4:
		_place(_slots[index], 478 + index * 72, 20, 66, 43)
	_place(_ability_status, 478, 66, 282, 24)
	_ability_status.add_theme_font_size_override("font_size", 10)
	_place(_record, 782, 20, 68, 43)
	_place(_raid, 869, 5, 136, 15)
	for index: int in _map.size():
		var slot: Vector2i = _world.arenas[index].grid_slot if _world != null else Vector2i(index % 3, index / 3)
		_place(_map[index], 869 + slot.x * 26, 26 + slot.y * 19, 23, 16)
	_place(_previous, 952, 26, 32, 23)
	_place(_next, 952, 54, 32, 23)
	_place(_toggle, size.x - 268, 12, 151, 30)
	_toggle.add_theme_font_size_override("font_size", 13)
	_place(_help, size.x - 109, 12, 96, 30)
	_place(_key_hint, size.x - 268, 49, 255, 37)
	_key_hint.add_theme_font_size_override("font_size", 11)
	_place(_reserve_panel, 13, size.y - BOTTOM_HEIGHT - 192, 254, 184)
	_place(_reserve_list, 8, 8, 238, 168)
	_place(_help_panel, size.x - 373, size.y - BOTTOM_HEIGHT - 230, 360, 222)
	_place(_help_text, 14, 12, 332, 198)


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
	_ability.text = _ability_title + "\n1"
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
	_ability.tooltip_text = _ability_title + " · 1 / Space · " + _ability_status.text
	for index: int in range(1, 4):
		_slots[index].text = "—\n%d" % (index + 1)
		_slots[index].tooltip_text = "Unassigned ability slot %d" % (index + 1)


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


func _build_roster_hud() -> void:
	_vitals = ArenicHeroVitals.new()
	_vitals.name = "HeroVitals"
	_bottom.add_child(_vitals)
	_roster = ArenicRosterStrip.new()
	_roster.name = "CharacterRoster"
	_roster.character_requested.connect(func(identity: int) -> void: hero_requested.emit(identity))
	_bottom.add_child(_roster)
	_roster_hint = _small_button(_bottom, "RosterNavigation", "TAB · SHIFT TAB")
	_roster_hint.pressed.connect(func() -> void: hero_requested.emit(_hero.identity_id if _hero != null else -1))
	_reserve = _small_button(_bottom, "RosterCount", "0 / 40")
	_reserve.pressed.connect(_toggle_reserve)
	_slots.append(_ability)
	for index: int in range(1, 4):
		var button := _small_button(_bottom, "AbilitySlot%d" % (index + 1), "—\n%d" % (index + 1))
		button.disabled = true
		_slots.append(button)
	_record = _small_button(_bottom, "RecordAction", "Record\nR")
	_record.tooltip_text = "R records a two-minute staff for this hero in this arena."
	# Clicking Record drives exactly the same flow as the R key.
	_record.pressed.connect(func() -> void: record_requested.emit())
	_raid = _make_label(_bottom, "RaidDifficulty", "Raid: Normal", BODY_FONT, 11)
	for index: int in 9:
		var button := _small_button(_bottom, "ArenaCell%d" % index, "X")
		button.add_theme_font_size_override("font_size", 10)
		button.pressed.connect(func() -> void: arena_requested.emit(index))
		var style := StyleBoxFlat.new()
		_map_styles.append(style)
		button.add_theme_stylebox_override("normal", style)
		_map.append(button)
	_previous = _small_button(_bottom, "PreviousArena", "[ ←")
	_previous.pressed.connect(func() -> void: arena_requested.emit(posmod(_selected_arena - 1, 9)))
	_next = _small_button(_bottom, "NextArena", "→ ]")
	_next.pressed.connect(func() -> void: arena_requested.emit(posmod(_selected_arena + 1, 9)))
	_help = _small_button(_bottom, "ControlsHelp", "Controls  H")
	_help.pressed.connect(toggle_help)
	_help_panel = _make_panel(self, "ControlsGuide")
	_help_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_help_panel.add_theme_stylebox_override("panel", _bottom_style)
	_help_text = _make_label(_help_panel, "GuideText", "", BODY_FONT, 13)
	_help_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_help_panel.hide()
	_reserve_panel = _make_panel(self, "ReserveCharacters")
	_reserve_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_reserve_panel.add_theme_stylebox_override("panel", _bottom_style)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	_reserve_panel.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reserve_list = VBoxContainer.new()
	scroll.add_child(_reserve_list)
	_reserve_panel.hide()


func _small_button(parent: Control, node_name: String, text: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_override("font", BODY_FONT)
	button.add_theme_font_size_override("font_size", 11)
	for index: int in _toggle_styles.size():
		button.add_theme_stylebox_override(["normal", "hover", "pressed", "disabled"][index], _toggle_styles[index])
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	parent.add_child(button)
	return button


## `roster` is every guild member, wherever it stands. The strip shows the ones
## in the focused arena; the map counts them per arena, which is what its "X"
## and its numbers have always meant.
func set_run_context(world: ArenicWorldDefinition, hero: ArenicHeroState, selected_arena: int, health: Dictionary, effects: Array[Dictionary], roster: Array = []) -> void:
	_world = world
	_hero = hero
	_selected_arena = selected_arena
	_roster_entries.clear()
	_map_counts.clear()
	_map_present.clear()
	var guild: Array = roster if not roster.is_empty() else ([hero] if hero != null else [])
	for index: int in world.arenas.size():
		var present: int = 0
		for member: ArenicHeroState in guild:
			if member != null and member.arena_id == world.arenas[index].arena_id:
				present += 1
		_map_present.append(present)
		if _map_counts.size() <= index:
			_map_counts.append(0)
	var focused: String = world.arenas[selected_arena].arena_id
	for member: ArenicHeroState in guild:
		if member == null or member.arena_id != focused:
			continue
		var vitals: Dictionary = health if member == hero else _combat_health.call(member) if _combat_health.is_valid() else {}
		_roster_entries.append({
			"identity": member.identity_id, "name": member.display_name(),
			"class": member.definition.display_name,
			"initial": member.definition.display_name.left(1).to_upper(),
			"dead": int(vitals.get("health", 1)) <= 0,
			"ghost": bool(_ghost_check.call(member)) if _ghost_check.is_valid() else false,
		})
	_selected_identity = hero.identity_id if hero != null and hero.selected and _hero_here else -1
	if hero == null or not hero.selected:
		_vitals.clear_selection()
	else:
		_vitals.set_snapshot(hero.identity_id, hero.display_name(), hero.definition.display_name, hero.level, hero.experience, hero.experience_to_next_level, int(health.get("health", 1)), int(health.get("max_health", 1)), effects)
	_apply_roster_palette()
	_layout_hud()


## Lets the HUD read any guild member's health without owning the ledger.
func set_health_source(source: Callable) -> void:
	_combat_health = source


## And whether a member is folded into its arena's stream.
func set_ghost_source(source: Callable) -> void:
	_ghost_check = source


## Ghosts per arena, in world order. This is the map's "activity": an arena with
## members standing idle in it still reads as X, because nothing is running there.
func set_arena_activity(counts: PackedInt32Array) -> void:
	_map_counts.clear()
	for value: int in counts:
		_map_counts.append(value)
	if is_node_ready():
		_apply_roster_palette()


func _apply_roster_palette() -> void:
	if _vitals == null:
		return
	_vitals.set_visual_theme(_visual_theme)
	_roster.set_roster(_roster_entries, _selected_identity, _content_color, ArenicHudTokens.color("selection"))
	_reserve.text = "%d / 40" % _roster_entries.size() if _roster_entries.size() <= 40 else "+%d more" % (_roster_entries.size() - 40)
	_reserve.disabled = _roster_entries.size() <= 40
	for button: Button in [_roster_hint, _reserve, _record, _previous, _next, _help, _save_title] + _slots.slice(1):
		button.add_theme_color_override("font_color", _content_color)
		button.add_theme_color_override("font_hover_color", _content_color)
		button.add_theme_color_override("font_pressed_color", _primary_color)
		button.add_theme_color_override("font_disabled_color", Color(_content_color, 0.42))
	_raid.add_theme_color_override("font_color", _content_color)
	_help_text.add_theme_color_override("font_color", _content_color)
	for index: int in _map.size():
		var active: bool = index == _selected_arena
		var ghosts: int = _map_counts[index] if index < _map_counts.size() else 0
		var present: int = _map_present[index] if index < _map_present.size() else 0
		# The cell counts what is RUNNING there. An arena holding idle members
		# still reads X: the map answers "where is my guild working", and the
		# black fill alone says which arena you are looking at.
		_map[index].text = str(ghosts) if ghosts > 0 else "X"
		_map[index].tooltip_text = "%s · Normal · %d ghost%s · %d here" % [
			_world.arenas[index].display_name if _world != null else "Arena",
			ghosts, "" if ghosts == 1 else "s", present]
		_map[index].add_theme_color_override("font_color", ArenicHudTokens.color("selected_content") if active else _content_color)
		var style: StyleBoxFlat = _map_styles[index]
		style.bg_color = ArenicHudTokens.color("map_active") if active else _field_color
		style.border_color = Color(_content_color, 0.45)
		style.set_border_width_all(1)
		style.set_corner_radius_all(0)


## Damage earned toward the next guild roll, or that a roll is waiting. Reads as
## progress rather than a balance, because damage is never spent.
func set_recruitment(progress: Dictionary) -> void:
	if _recruit == null:
		return
	var available: int = int(progress.get("available", 0))
	if available > 0:
		_recruit.text = "%d roll%s ready   [N]" % [available, "" if available == 1 else "s"]
		_recruit.add_theme_color_override("font_color", ArenicHudTokens.color("xp", _visual_theme))
	elif int(progress.get("next_at", 0)) > 0:
		_recruit.text = "Next hero   %d / %d" % [int(progress.get("toward", 0)), int(progress.get("span", 1))]
		_recruit.add_theme_color_override("font_color", Color(_content_color, 0.7))
	else:
		_recruit.text = ""


## The record control doubles as the recording read-out: the cycle clock while a
## take is running, the countdown before it starts.
func set_recording_state(label: String, detail: String, active: bool) -> void:
	if _record == null:
		return
	_record.text = label
	_record.tooltip_text = detail
	_record.add_theme_color_override("font_color", ArenicHudTokens.color("negative") if active else _content_color)


func toggle_help() -> void:
	_help_text.text = "FIND YOUR WAY\n\nTab   Cycle the heroes in this arena\n[ / ]   Previous / next arena\nArrows   Move hero / select arena\nN   Claim a guild roll\nP / Enter / wheel   Overview and zoom\n1 / Space   Use or hold your starter ability\n2 / 3 / 4   Unassigned ability slots\nR   Record a two-minute staff · H   Close controls\n\nBlue: HP / selected and ghosts · Green: XP / gains"
	_help_panel.visible = not _help_panel.visible


func set_save_status(message: String) -> void:
	var failed: bool = not message in ["Saved", "Saving…", "Preview"]
	_save_title.text = "Save failed" if failed else message + " · Title"
	_save_title.tooltip_text = message if failed else "Save your game and return to the title screen"
	_save_error.text = message
	_save_error.visible = failed
	_reserve_panel.hide()


func _toggle_reserve() -> void:
	_reserve_panel.visible = not _reserve_panel.visible
	_help_panel.hide()
	for child: Node in _reserve_list.get_children():
		child.queue_free()
	for entry: Dictionary in _roster.hidden_entries():
		var button := _small_button(_reserve_list, "ReserveHero%d" % int(entry.identity), str(entry.name))
		button.disabled = bool(entry.get("dead", false))
		button.pressed.connect(func() -> void: hero_requested.emit(int(entry.identity)))
