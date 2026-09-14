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
signal recruitment_requested
signal loot_requested
signal overworld_action_requested(action: StringName)

const DISPLAY_FONT: Font = preload("res://assets/fonts/PPMigra-Extrabold.ttf")
const BODY_FONT: Font = preload("res://assets/fonts/Barlow-Regular.ttf")
const TOP_HEIGHT: float = 35.0
const BOTTOM_HEIGHT: float = 96.0 # Keep the 589px world band and native 19px tiles.
const DAMAGE_BAR_HEIGHT: float = 9.0
const ACTION_SIZE: float = 70.0
const ACTION_TEXT_WIDTH: float = ACTION_SIZE - 12.0

var _top: Panel
var _save_title: Button
var _save_error: Label
var _bottom: Panel
var _damage_bar: ArenicArenaDamageBar
var _arena_title: Label
var _encounter_cue: Label
var _boss_effects: RichTextLabel
var _boss_effect_snapshot: Array[Dictionary] = []
var _hero_label: Label
var _class_label: Label
var _hero_status: Label
var _arena_label: Label
var _subtitle: Label
var _ability: Button
var _ability_feedback: Label
var _key_hint: Label
var _secondary_hint: Label
var _toggle: Button
var _accent: ColorRect
var _hero_divider: ColorRect
var _total_damage: int = 0
var _phase_damage: int = 20
var _ability_title: String = "Ability"
var _ability_detail: String = "Choose a hero"
var _ability_feedback_text: String = "Select hero"
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
var _toggle_styles: Array[StyleBoxFlat] = [] # Normal, hover, pressed, disabled.
var _action_styles: Array[StyleBoxFlat] = []
var _action_hotkeys: Array[Label] = []
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
var _reserve: Button
var _reserve_panel: Panel
var _reserve_list: VBoxContainer
var _slots: Array[Button] = []
var _record: Button
var _record_feedback: Label
var _record_active: bool = false
var _record_title: String = "Record"
var _record_detail: String = "R records a two-minute staff for this hero in this arena."
var _record_readout: String = ""
var _chat: ArenicActivityFeedView
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
var _recruit_full_text: String = ""
var _recruit_compact_text: String = ""
var _roll_ready: Button
var _roll_count: int = 0
var _loot_ready: Button
var _loot_count: int = 0
var _top_layout_pending: bool = false
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
	if _arena != arena:
		_boss_effect_snapshot.clear()
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
func set_ability_context(title: String, detail: String, cooldown: float, active_remaining: float, enabled: bool, feedback: String = "") -> void:
	_ability_title = title if not title.is_empty() else "Ability"
	_ability_detail = detail
	_ability_feedback_text = feedback
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
	# Keep menu drawing and pointer input above the later Keeper overlay.
	var controls_layer := CanvasLayer.new()
	controls_layer.name = "ControlsLayer"
	var hud_layer: CanvasLayer = get_canvas_layer_node()
	controls_layer.layer = hud_layer.layer + 1 if hud_layer != null else 1
	add_child(controls_layer)
	_help_panel = _make_panel(controls_layer, "ControlsGuide")
	_help_panel.mouse_filter = Control.MOUSE_FILTER_STOP
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
	_damage_bar = ArenicArenaDamageBar.new()
	_damage_bar.name = "DamageBar"
	_top.add_child(_damage_bar)
	_arena_title = _make_label(_top, "ArenaTitle", "", BODY_FONT, 13)
	_arena_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_boss_effects = RichTextLabel.new()
	_boss_effects.name = "BossEffects"
	_boss_effects.bbcode_enabled = true
	_boss_effects.scroll_active = false
	_boss_effects.mouse_filter = Control.MOUSE_FILTER_PASS
	_boss_effects.add_theme_font_override("normal_font", BODY_FONT)
	_boss_effects.add_theme_font_size_override("normal_font_size", 11)
	_top.add_child(_boss_effects)
	_recruit = _make_label(_top, "GuildRolls", "", BODY_FONT, 12)
	_recruit.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_recruit.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_roll_ready = _small_button(_top, "RollsReady", "")
	_roll_ready.add_theme_font_size_override("font_size", 10)
	for state_name: String in ["normal", "hover", "pressed", "disabled"]:
		var ready_style := StyleBoxFlat.new()
		ready_style.set_border_width_all(1)
		ready_style.content_margin_left = 4.0
		ready_style.content_margin_right = 4.0
		ready_style.content_margin_top = 0.0
		ready_style.content_margin_bottom = 0.0
		_roll_ready.add_theme_stylebox_override(state_name, ready_style)
	_roll_ready.hide()
	_roll_ready.disabled = true
	_roll_ready.pressed.connect(func() -> void: recruitment_requested.emit())
	_loot_ready = _small_button(_top, "LootReady", "")
	_loot_ready.add_theme_font_size_override("font_size", 11)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.set_border_width_all(1)
		style.content_margin_left = 4.0
		style.content_margin_right = 4.0
		_loot_ready.add_theme_stylebox_override(state, style)
	_loot_ready.hide()
	_loot_ready.disabled = true
	_loot_ready.pressed.connect(func() -> void: loot_requested.emit())
	_save_error = _make_label(self, "SaveError", "", BODY_FONT, 13)
	_save_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_save_error.add_theme_color_override("font_color", Color(1.0, 0.8, 0.65))
	_save_error.hide()
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
	_toggle = Button.new()
	_toggle.name = "OverviewToggle"
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.mouse_filter = Control.MOUSE_FILTER_STOP
	_toggle.add_theme_font_override("font", BODY_FONT)
	_toggle.add_theme_font_size_override("font_size", 16)
	_toggle.pressed.connect(_on_toggle_pressed)
	_help_panel.add_child(_toggle)
	_key_hint = _make_label(_bottom, "NavigationHint", "", BODY_FONT, 13)
	_key_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_secondary_hint = _make_label(_bottom, "NavigationDetail", "", BODY_FONT, 12)
	_secondary_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_top_style = StyleBoxFlat.new()
	_bottom_style = StyleBoxFlat.new()
	_top.add_theme_stylebox_override("panel", _top_style)
	_bottom.add_theme_stylebox_override("panel", _bottom_style)
	for state_name: String in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		_toggle_styles.append(style)
		_toggle.add_theme_stylebox_override(state_name, style)
		var ability_style := StyleBoxFlat.new()
		ability_style.set_corner_radius_all(12)
		ability_style.content_margin_left = 6.0
		ability_style.content_margin_right = 6.0
		# Reserve separate rows below the centered title for feedback and the hotkey.
		ability_style.content_margin_top = 0.0
		ability_style.content_margin_bottom = 24.0
		_action_styles.append(ability_style)
	_toggle.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_ability.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_save_title = _small_button(_help_panel, "SaveAndTitle", "Save & Title")
	_save_title.pressed.connect(func() -> void: save_title_requested.emit())
	_build_roster_hud()
	for control: Control in [_arena_title, _recruit, _roll_ready, _loot_ready, _reserve]:
		control.minimum_size_changed.connect(_queue_top_layout)


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
	_arena_title.text = arena_name
	_arena_title.tooltip_text = arena_name
	_queue_top_layout()
	_toggle.text = "Overview     [P]" if _zoomed else "Zoom in     [P]"
	_toggle.disabled = _arena == null
	_hero_status.text = "Selected" if _hero_here and _hero_selected else ("Click to select" if _hero_here else "No hero here")
	if _zoomed and _hero_here:
		_key_hint.text = "ARROWS  Step · TAB  Select" if _hero_selected else "TAB  Select hero"
		_secondary_hint.text = "ESC  Overview · Click hero to select"
	elif _zoomed:
		_key_hint.text = "No hero in this arena"
		_secondary_hint.text = "[ ]  Cycle · ESC  Overview"
	else:
		_key_hint.text = "ARROWS  Select · ENTER  Zoom"
		_secondary_hint.text = "[ ]  Cycle · TAB  Hero · Wheel  Zoom"
	_apply_action_mode()
	_refresh_roster_selection()


func _apply_palette() -> void:
	_surface_color = _color("base_100")
	_content_color = _color("base_content")
	_primary_color = _color("primary")
	_deep_color = _color("base_300")
	_field_color = _color("base_200")
	var content: Color = _color("base_content")
	var primary: Color = _color("primary")
	for label: Label in [_arena_title, _hero_label, _arena_label]:
		label.add_theme_color_override("font_color", content)
	for label: Label in [_hero_status, _subtitle, _secondary_hint, _ability_feedback]:
		label.add_theme_color_override("font_color", _color("base_content", 0.78))
	_class_label.add_theme_color_override("font_color", primary)
	_key_hint.add_theme_color_override("font_color", content)
	_damage_bar.set_visual_theme(_visual_theme)
	_accent.color = primary
	_border_width = maxi(1, roundi(_visual_theme.border)) if _visual_theme != null else 1
	for button: Button in [_toggle, _ability]:
		button.add_theme_color_override("font_color", content)
		button.add_theme_color_override("font_hover_color", content)
		button.add_theme_color_override("font_pressed_color", primary)
		button.add_theme_color_override("font_disabled_color", _color("base_content", 0.38))
	for hotkey: Label in _action_hotkeys:
		hotkey.add_theme_color_override("font_color", _color("accent"))
	var sheen: Color = content.lerp(primary, 0.18)
	_sheen_gradient.colors = PackedColorArray([
		Color(sheen, 0.13), Color(sheen, 0.035), Color(sheen, 0.0),
	])
	_apply_surfaces()
	_apply_roster_palette()
	_apply_recruitment_palette()
	_boss_effects.add_theme_color_override("default_color", content)
	_refresh_boss_effects()


func _apply_surfaces() -> void:
	# Mutate existing style resources; never rebuild controls while blending.
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
	var hover: Color = _deep_color.lerp(_primary_color, 0.12 * _overview_mix)
	hover.a = lerpf(1.0, 0.88, _overview_mix)
	for index: int in range(_toggle_styles.size()):
		for style: StyleBoxFlat in [_toggle_styles[index], _action_styles[index]]:
			style.bg_color = field if index == 0 else (fill if index == 3 else hover)
			style.border_color = _edge_color if index == 3 else Color(_primary_color, 0.65 if index == 0 else 1.0)
			style.set_border_width_all(_border_width + (1 if index == 2 else 0))
	_rail_color = Color(_field_color, lerpf(1.0, 0.50, _overview_mix))
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
	var value: float = 1.0 if token in ["base_content", "primary", "accent"] else 0.0
	return Color(value, value, value, alpha)


func _layout_hud() -> void:
	_place(_top, 0.0, 0.0, size.x, TOP_HEIGHT)
	_place(_bottom, 0.0, size.y - BOTTOM_HEIGHT, size.x, BOTTOM_HEIGHT)
	_place(_top_sheen, 0.0, 0.0, size.x, 17.0)
	_place(_bottom_sheen, 0.0, 1.0, size.x, 42.0)
	_place(_damage_bar, 0.0, 0.0, size.x, DAMAGE_BAR_HEIGHT)
	_place(_save_error, size.x - 510.0, TOP_HEIGHT + 8.0, 480.0, 72.0)
	# Preserve the existing 96px strip so the world and native 19px sprites keep their framing.
	for legacy: Control in [_accent, _class_label, _hero_label, _hero_status, _subtitle, _arena_label, _secondary_hint]:
		legacy.hide()
	_layout_roster_status()
	_place(_roster, 13, 25, 160, 64)
	_place(_hero_divider, 185, 12, 1, 72)
	_place(_vitals, 200, 7, 255, 82)
	for index: int in 4:
		_place(_slots[index], 478 + index * 76, 13, ACTION_SIZE, ACTION_SIZE)
	_place(_record, 782, 13, ACTION_SIZE, ACTION_SIZE)
	_place(_chat, 864, 4, maxf(270.0, size.x - 1010.0), 88)
	_place(_raid, size.x - 130, 5, 117, 15)
	for index: int in _map.size():
		var slot: Vector2i = _world.arenas[index].grid_slot if _world != null else Vector2i(index % 3, index / 3)
		_place(_map[index], size.x - 130 + slot.x * 26, 26 + slot.y * 19, 23, 16)
	_place(_previous, size.x - 46, 26, 32, 23)
	_place(_next, size.x - 46, 54, 32, 23)
	_toggle.add_theme_font_size_override("font_size", 11)
	_layout_top_status()
	_key_hint.hide()
	_place(_reserve_panel, 13, size.y - BOTTOM_HEIGHT - 192, 254, 184)
	_place(_reserve_list, 8, 8, 238, 168)
	_layout_controls_guide()


func _layout_controls_guide() -> void:
	_place(_help_text, 14, 12, 332, maxf(216.0, _help_text.get_combined_minimum_size().y))
	var footer_y: float = _help_text.get_rect().end.y + 12.0
	var panel_height: float = footer_y + 40.0
	_place(_help_panel, size.x - 373, size.y - BOTTOM_HEIGHT - 8.0 - panel_height, 360, panel_height)
	_place(_toggle, 14, footer_y, 104, 26)
	_place(_save_title, 126, footer_y, 124, 26)
	_place(_help, 258, footer_y, 88, 26)


func _queue_top_layout() -> void:
	if _top_layout_pending or not is_node_ready():
		return
	_top_layout_pending = true
	_remeasure_top.call_deferred()


func _remeasure_top() -> void:
	_top_layout_pending = false
	if is_node_ready():
		_layout_top_status()
		_layout_roster_status()


func _text_width(control: Control, text: String) -> float:
	return ceilf(control.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, control.get_theme_font_size("font_size")).x)


func _layout_top_status() -> void:
	# Reward actions anchor to the right edge. Conditions use only the remaining
	# middle band and keep their complete readout available in the tooltip.
	var right: float = size.x - 13.0
	for button: Button in [_loot_ready, _roll_ready]:
		if not button.visible:
			continue
		var width: float = maxf(40.0, _text_width(button, button.text) + 12.0)
		_place(button, right - width, DAMAGE_BAR_HEIGHT + 3.0, width, 20.0)
		right -= width + 8.0
	if _recruit.get_theme_font_size("font_size") < 12:
		_recruit.add_theme_font_size_override("font_size", 12)
	var counter: String = _recruit_full_text
	var counter_width: float = _text_width(_recruit, counter)
	var budget: float = minf(188.0, size.x * 0.28)
	if counter_width > budget:
		counter = "Next hero " + _recruit_compact_text if _recruit_full_text.begins_with("Next hero") else _recruit_compact_text
		counter_width = minf(budget, _text_width(_recruit, counter))
	_recruit.text = counter
	_place(_recruit, right - counter_width, DAMAGE_BAR_HEIGHT, counter_width, TOP_HEIGHT - DAMAGE_BAR_HEIGHT)
	var status_end: float = _recruit.position.x - 22.0
	var title_width: float = minf(_text_width(_arena_title, _arena_title.text), minf(size.x * 0.25, maxf(0.0, status_end - 13.0)))
	_place(_arena_title, 13.0, DAMAGE_BAR_HEIGHT, title_width, TOP_HEIGHT - DAMAGE_BAR_HEIGHT)
	var effects_x: float = _arena_title.get_rect().end.x + 20.0
	_place(_boss_effects, effects_x, DAMAGE_BAR_HEIGHT + 5.0, maxf(0.0, status_end - effects_x), 18.0)
	_refresh_boss_effects()


func _layout_roster_status() -> void:
	var reserve_width: float = maxf(36.0, _reserve.get_combined_minimum_size().x)
	_place(_reserve, 178.0 - reserve_width, 3.0, reserve_width, 18.0)


## Presentation observes live boss state; it never advances or manufactures effects.
func set_boss_effects(effects: Array[Dictionary]) -> void:
	if effects == _boss_effect_snapshot:
		return
	_boss_effect_snapshot = effects.duplicate(true)
	if is_node_ready():
		_refresh_boss_effects()


func _refresh_boss_effects() -> void:
	var parts: PackedStringArray = []
	var details: PackedStringArray = []
	var used: float = 0.0
	for index: int in _boss_effect_snapshot.size():
		var effect: Dictionary = _boss_effect_snapshot[index]
		var name: String = str(effect.get("name", "Effect")).replace("\n", " ").left(40)
		var seconds: float = float(effect.get("remaining_seconds", -1.0))
		var stacks: int = maxi(1, int(effect.get("stacks", 1)))
		var value: String = " ×%d" % stacks if stacks > 1 else ""
		if is_finite(seconds) and seconds >= 0.0:
			value += " [%ds]" % ceili(seconds)
		var plain: String = name + value
		details.append(plain + (" · " + str(effect.detail) if effect.has("detail") else ""))
		var width: float = BODY_FONT.get_string_size(plain, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		var reserve: float = 26.0 if index < _boss_effect_snapshot.size() - 1 else 0.0
		if used + width + reserve <= _boss_effects.size.x:
			var color: String = ArenicHudTokens.color("positive" if bool(effect.get("beneficial", false)) else "negative", _visual_theme).to_html(false)
			parts.append("[color=#%s]%s[/color]" % [color, plain.replace("[", "[lb]")])
			used += width + 16.0
		else:
			# Keep full details in the tooltip when a narrow viewport needs a count.
			var hidden: int = _boss_effect_snapshot.size() - index
			parts.append("+%d" % hidden)
			for hidden_index: int in range(index + 1, _boss_effect_snapshot.size()):
				var hidden_effect: Dictionary = _boss_effect_snapshot[hidden_index]
				details.append(str(hidden_effect.get("name", "Effect")) + " · " + str(hidden_effect.get("detail", "")))
			break
	_boss_effects.text = "    ".join(parts)
	_boss_effects.tooltip_text = "\n".join(details)
	_boss_effects.visible = not parts.is_empty()


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
	_damage_bar.tooltip_text = "%d damage taken in this arena" % _total_damage


func _apply_ability() -> void:
	if not _zoomed:
		return
	var channeling: bool = is_inf(_ability_active) and _ability_active > 0.0
	if _ability.text != _ability_title:
		_ability.text = _ability_title
		_fit_action_text(_ability, _ability_title, 10, 13)
	_ability.disabled = not (_ability_enabled or channeling)
	var feedback: String = _ability_feedback_text
	if channeling:
		feedback = "Channeling"
	elif _ability_active > 0.0:
		feedback = "Active %.1fs" % _ability_active
	elif _ability_cooldown > 0.0:
		feedback = "CD %.1fs" % _ability_cooldown
	elif feedback.is_empty():
		feedback = "Ready" if _ability_enabled else "Not ready"
	_set_action_feedback(_ability_feedback, feedback)
	var detail: String = "Release to stop" if channeling else _ability_detail
	_ability.tooltip_text = "%s · 1 / Space · %s" % [_ability_title, feedback]
	if not detail.is_empty():
		_ability.tooltip_text += "\n" + detail
	for index: int in range(1, 4):
		_slots[index].text = "—"
		_slots[index].disabled = true
		_slots[index].tooltip_text = "Unassigned ability slot %d" % (index + 1)


func _apply_action_mode() -> void:
	_ability_feedback.visible = _zoomed
	_record_feedback.visible = _zoomed
	for index: int in ArenicOverworldActions.COUNT:
		var button: Button = _slots[index] if index < _slots.size() else _record
		button.autowrap_mode = TextServer.AUTOWRAP_OFF if _zoomed else TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 13)
		if not _zoomed:
			var action: StringName = ArenicOverworldActions.action_for_slot(index)
			button.text = ArenicOverworldActions.title(action)
			_action_hotkeys[index].text = ArenicOverworldActions.hotkey(action)
			button.tooltip_text = button.text
			button.disabled = false
		else:
			_action_hotkeys[index].text = str(index + 1) if index < _slots.size() else "R"
	if _zoomed:
		_apply_ability()
		_fit_action_text(_ability, _ability_title, 10, 13)
		_apply_recording()
	_apply_record_palette()
	# Autowrap changes can defer the native Button's text repaint across frames.
	_record.queue_redraw()


func _on_ability_down() -> void:
	if _zoomed:
		ability_requested.emit()


func _on_ability_up() -> void:
	if _zoomed:
		ability_released.emit()


func _on_action_pressed(index: int) -> void:
	if not _zoomed:
		overworld_action_requested.emit(ArenicOverworldActions.action_for_slot(index))
	elif index == ArenicOverworldActions.COUNT - 1:
		record_requested.emit()


func _on_toggle_pressed() -> void:
	_help_panel.hide()
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


func _make_panel(parent: Node, node_name: String) -> Panel:
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
	_reserve = _small_button(_bottom, "RosterCount", "0/40")
	_reserve.add_theme_font_size_override("font_size", 10)
	_reserve.tooltip_text = "Heroes in this arena · Tab / Shift-Tab cycles heroes"
	_reserve.pressed.connect(_toggle_reserve)
	_slots.append(_ability)
	for index: int in range(1, 4):
		var button := _small_button(_bottom, "AbilitySlot%d" % (index + 1), "—")
		button.disabled = true
		_slots.append(button)
	for index: int in _slots.size():
		_style_action_button(_slots[index], str(index + 1))
		_slots[index].pressed.connect(_on_action_pressed.bind(index))
	_ability_feedback = _make_action_feedback(_ability)
	_record = _small_button(_bottom, "RecordAction", "Record")
	_style_action_button(_record, "R")
	_record_feedback = _make_action_feedback(_record)
	_record.tooltip_text = "R records a two-minute staff for this hero in this arena."
	# Clicking Record drives exactly the same flow as the R key.
	_record.pressed.connect(_on_action_pressed.bind(ArenicOverworldActions.COUNT - 1))
	_chat = ArenicActivityFeedView.new()
	_chat.name = "GlobalChat"
	_bottom.add_child(_chat)
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
	_help = _small_button(_help_panel, "CloseGuide", "Close H")
	_help.pressed.connect(toggle_help)
	_help_panel.add_theme_stylebox_override("panel", _bottom_style)
	_help_text = _make_label(_help_panel, "GuideText", "", BODY_FONT, 13)
	_help_text.minimum_size_changed.connect(_layout_controls_guide)
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


## All five action controls share geometry and pointer-transparent hotkeys.
func _style_action_button(button: Button, key: String) -> void:
	button.size = Vector2(ACTION_SIZE, ACTION_SIZE)
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 13)
	for state: int in _action_styles.size():
		button.add_theme_stylebox_override(["normal", "hover", "pressed", "disabled"][state], _action_styles[state])
	var hotkey := _make_label(button, "Hotkey", key, BODY_FONT, 12)
	hotkey.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hotkey.offset_left = -21.0
	hotkey.offset_top = -21.0
	hotkey.offset_right = -7.0
	hotkey.offset_bottom = -5.0
	hotkey.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hotkey.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_action_hotkeys.append(hotkey)


func _make_action_feedback(button: Button) -> Label:
	var feedback := _make_label(button, "Feedback", "", BODY_FONT, 10)
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(feedback, 6.0, 35.0, ACTION_TEXT_WIDTH, 14.0)
	return feedback


func _set_action_feedback(label: Label, text: String) -> void:
	if label.text == text:
		return
	label.text = text
	_fit_action_text(label, text, 9, 10)


func _fit_action_text(control: Control, text: String, minimum: int, maximum: int) -> void:
	var font_size: int = maximum
	while font_size > minimum and BODY_FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > ACTION_TEXT_WIDTH:
		font_size -= 1
	control.add_theme_font_size_override("font_size", font_size)


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
	_refresh_roster_selection()
	if hero == null or hero.arena_id != focused:
		_vitals.clear_selection()
	else:
		_vitals.set_snapshot(hero.identity_id, hero.display_name(), hero.definition.display_name, hero.level, hero.experience, hero.experience_to_next_level, int(health.get("health", 1)), int(health.get("max_health", 1)), effects)
	_apply_roster_palette()
	_layout_hud()


func _refresh_roster_selection() -> void:
	var next_identity: int = _hero.identity_id if _zoomed and _hero != null and _hero.selected and _hero_here and _hero_selected else -1
	if next_identity == _selected_identity:
		return
	_selected_identity = next_identity
	if _roster != null:
		_roster.set_roster(_roster_entries, _selected_identity, _content_color, ArenicHudTokens.color("selection"))


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
	_chat.set_visual_theme(_visual_theme)
	_roster.set_roster(_roster_entries, _selected_identity, _content_color, ArenicHudTokens.color("selection"))
	_reserve.text = "%d/40" % _roster_entries.size() if _roster_entries.size() <= 40 else "+%d" % (_roster_entries.size() - 40)
	_reserve.tooltip_text = "%d heroes · Tab / Shift+Tab to focus" % _roster_entries.size()
	if _roster_entries.size() > 40:
		_reserve.tooltip_text += "\nShow %d more heroes" % (_roster_entries.size() - 40)
	_reserve.disabled = _roster_entries.size() <= 40
	for button: Button in [_reserve, _previous, _next, _help, _save_title] + _slots.slice(1):
		button.add_theme_color_override("font_color", _content_color)
		button.add_theme_color_override("font_hover_color", _content_color)
		button.add_theme_color_override("font_pressed_color", _primary_color)
		button.add_theme_color_override("font_disabled_color", Color(_content_color, 0.42))
	_apply_record_palette()
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


## Progress to the next unearned threshold and banked rolls are independent.
## Claiming a roll changes only the small ready action, never the counter.
func set_recruitment(progress: Dictionary) -> void:
	if _recruit == null:
		return
	var available: int = maxi(0, int(progress.get("available", 0)))
	var counter: String = "Next hero %d/%d" % [int(progress.get("toward", 0)), int(progress.get("span", 1))] if int(progress.get("next_at", 0)) > 0 else "All rolls earned"
	if counter == _recruit_full_text and available == _roll_count:
		return
	_recruit_full_text = counter
	_recruit_compact_text = "%s/%s" % [_compact_count(int(progress.get("toward", 0))), _compact_count(int(progress.get("span", 1)))] if int(progress.get("next_at", 0)) > 0 else "All earned"
	_recruit.tooltip_text = "Damage earned toward the next hero roll; claiming a banked roll does not spend damage." if int(progress.get("next_at", 0)) > 0 else "Every recruitment threshold has been earned. Banked rolls remain available."
	_recruit.tooltip_text = ("Next hero %d / %d" % [int(progress.get("toward", 0)), int(progress.get("span", 1))] if int(progress.get("next_at", 0)) > 0 else counter) + "\n" + _recruit.tooltip_text
	_roll_count = available
	_roll_ready.text = "%d [N]" % available
	_roll_ready.tooltip_text = "%d banked roll%s ready. Click or press N to choose a hero." % [available, "" if available == 1 else "s"]
	_roll_ready.visible = available > 0
	_roll_ready.disabled = available <= 0
	_apply_recruitment_palette()
	_queue_top_layout()


## Only the authoritative reward queue determines this count.
func set_loot(available: int) -> void:
	_loot_count = maxi(0, available)
	if _loot_ready == null:
		return
	_loot_ready.text = "Loot %s" % _compact_count(_loot_count)
	_loot_ready.tooltip_text = "%d arena reward%s ready. Open three concealed cards and reveal one piece of equipment." % [_loot_count, "" if _loot_count == 1 else "s"]
	_loot_ready.visible = _loot_count > 0
	_loot_ready.disabled = _loot_count <= 0
	_apply_recruitment_palette()
	_queue_top_layout()


static func _compact_count(value: int) -> String:
	var amount: float = float(value)
	var suffixes: Array[String] = ["", "K", "M", "B", "T", "Q"]
	var index: int = 0
	while amount >= 1000.0 and index < suffixes.size() - 1:
		amount /= 1000.0
		index += 1
	return str(value) if index == 0 else "%.1f%s" % [amount, suffixes[index]]


func _apply_recruitment_palette() -> void:
	if _roll_ready == null:
		return
	_recruit.add_theme_color_override("font_color", Color(_content_color, 0.78))
	if _loot_ready != null:
		var loot_accent: Color = _color("accent")
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			var style := _loot_ready.get_theme_stylebox(state) as StyleBoxFlat
			style.bg_color = _field_color.lerp(loot_accent, 0.08 if state == "normal" else 0.16)
			style.border_color = Color(loot_accent, 0.65)
			_loot_ready.add_theme_color_override("font_color" if state == "normal" else "font_%s_color" % state, loot_accent)
	var ready: Color = ArenicHudTokens.color("xp", _visual_theme)
	for state_name: String in ["normal", "hover", "pressed", "disabled"]:
		var style := _roll_ready.get_theme_stylebox(state_name) as StyleBoxFlat
		style.bg_color = _field_color.lerp(ready, 0.08 if state_name == "normal" else 0.16)
		style.border_color = Color(ready, 0.65)
		style.content_margin_left = 4.0
		style.content_margin_right = 4.0
		_roll_ready.add_theme_color_override("font_color" if state_name == "normal" else "font_%s_color" % state_name, ready)


## The record control doubles as the recording read-out: the cycle clock while a
## take is running, the countdown before it starts.
func set_recording_state(label: String, detail: String, active: bool, readout: String = "") -> void:
	_record_title = label
	_record_detail = detail
	_record_readout = readout
	_record_active = active
	if _record != null:
		_apply_recording()


func _apply_recording() -> void:
	if not _zoomed:
		return
	_record.text = _record_title
	_fit_action_text(_record, _record_title, 10, 13)
	_set_action_feedback(_record_feedback, _record_readout)
	_record.tooltip_text = _record_detail
	_apply_record_palette()


func _apply_record_palette() -> void:
	var color: Color = ArenicHudTokens.color("negative") if _zoomed and _record_active else _content_color
	_record_feedback.add_theme_color_override("font_color", color)
	for state_name: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		_record.add_theme_color_override(state_name, color)


func set_activity_feed(feed: ArenicActivityFeed) -> void:
	_chat.set_feed(feed)


func is_chat_expanded() -> bool:
	return _chat.is_expanded()


func toggle_chat() -> void:
	_help_panel.hide()
	_reserve_panel.hide()
	_chat.toggle_expanded()


func toggle_help() -> void:
	if _chat.is_expanded():
		_chat.toggle_expanded()
	var actions := "1 / Space   Use or hold your starter ability\n2 / 3 / 4   Unassigned ability slots\nR   Record a two-minute staff"
	if not _zoomed:
		actions = ""
		for entry: Dictionary in ArenicOverworldActions.entries():
			actions += "%s   %s\n" % [entry.hotkey, entry.title]
		actions = actions.trim_suffix("\n")
	_help_text.text = "FIND YOUR WAY\n\nTab   Cycle the heroes in this arena\n[ / ]   Previous / next arena\nArrows   Move hero / select arena\nN   Claim a guild roll\nP / Enter / wheel   Overview and zoom\n%s\nC   Global Chat · H   Close controls\n\nBlue: HP / selection · Green: XP / gains" % actions
	_help_panel.visible = not _help_panel.visible
	_layout_controls_guide()


## Other modal owners can dismiss HUD popovers without touching gameplay state.
func hide_overlays() -> void:
	_help_panel.hide()
	_reserve_panel.hide()
	if _chat.is_expanded():
		_chat.toggle_expanded()


func set_save_status(message: String) -> void:
	var failed: bool = not message in ["Saved", "Saving…", "Preview"]
	_save_title.text = "Retry & Title" if failed else "Save & Title"
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


func set_encounter_cue(text: String) -> void:
	if _encounter_cue == null:
		_encounter_cue = Label.new()
		_encounter_cue.name = "EncounterCue"
		_encounter_cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_encounter_cue.add_theme_font_override("font", BODY_FONT)
		_encounter_cue.add_theme_font_size_override("font_size", 13)
		_encounter_cue.add_theme_color_override("font_color", Color(0.97, 0.96, 0.88))
		_encounter_cue.add_theme_color_override("font_shadow_color", Color(0.02, 0.025, 0.04))
		_encounter_cue.add_theme_constant_override("shadow_offset_x", 1)
		_encounter_cue.add_theme_constant_override("shadow_offset_y", 1)
		add_child(_encounter_cue)
	_encounter_cue.position = Vector2(13, TOP_HEIGHT + 8)
	_encounter_cue.text = text
	_encounter_cue.visible = not text.is_empty()
