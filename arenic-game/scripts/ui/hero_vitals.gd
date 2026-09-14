class_name ArenicHeroVitals
extends Control
## A compact view of authoritative hero state. It never advances effects or combat.

const DISPLAY_FONT: Font = preload("res://assets/fonts/PPMigra-Extrabold.ttf")
const BODY_FONT: Font = preload("res://assets/fonts/Barlow-Regular.ttf")
const MAX_POPUPS: int = 8
const POPUP_SECONDS: float = 1.25
const BAR_SECONDS: float = 0.24
const ROW_FONT_SIZE: int = 10

var _identity: int = 0
var _has_snapshot: bool = false
var _hero_name: String = ""
var _class_label: String = ""
var _level: int = 1
var _xp: int = 0
var _xp_max: int = 1
var _hp: int = 0
var _hp_max: int = 1
var _effects: Array[Dictionary] = []
var _visual_theme: ArenicArenaTheme
var _name_label: Label
var _class_name: Label
var _xp_label: Label
var _hp_label: Label
var _xp_track: ColorRect
var _hp_track: ColorRect
var _xp_fill: ColorRect
var _hp_fill: ColorRect
var _debuffs: RichTextLabel
var _buffs: RichTextLabel
var _feedback_layer: Control
var _feedback: Array[Dictionary] = []
var _display_xp: float = 0.0
var _display_hp: float = 0.0
var _from_xp: float = 0.0
var _from_hp: float = 0.0
var _target_xp: float = 0.0
var _target_hp: float = 0.0
var _bar_elapsed: float = BAR_SECONDS


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(252.0, 80.0)
	_build()
	resized.connect(_layout)
	_apply_palette()
	_refresh_labels()
	_snap_bars()
	_layout()
	set_process(false)


func set_visual_theme(value: ArenicArenaTheme) -> void:
	if _visual_theme == value:
		return
	_visual_theme = value
	if is_node_ready():
		_apply_palette()
		_refresh_effects()


func set_snapshot(identity: int, hero_name: String, class_label: String, level: int, xp: int, xp_max: int, hp: int, hp_max: int, effects: Array[Dictionary]) -> void:
	var next_xp: int = maxi(0, xp)
	var next_hp_max: int = maxi(1, hp_max)
	var next_hp: int = clampi(hp, 0, next_hp_max)
	var same_hero: bool = _has_snapshot and identity == _identity
	var stats_changed: bool = next_xp != _xp or next_hp != _hp or maxi(1, xp_max) != _xp_max or next_hp_max != _hp_max
	if same_hero and not stats_changed and hero_name == _hero_name and class_label == _class_label and maxi(1, level) == _level and effects == _effects:
		return
	var xp_delta: int = next_xp - _xp
	var hp_delta: int = next_hp - _hp
	_identity = identity
	_has_snapshot = true
	_hero_name = hero_name
	_class_label = class_label
	_level = maxi(1, level)
	_xp = next_xp
	_xp_max = maxi(1, xp_max)
	_hp = next_hp
	_hp_max = next_hp_max
	_effects = effects.duplicate(true)
	if not is_node_ready():
		return
	_refresh_labels()
	if same_hero:
		if stats_changed:
			_animate_bars()
		if xp_delta > 0:
			_add_feedback("+%d XP" % xp_delta, "xp", _xp_label.position.y, -1.0)
		if hp_delta != 0:
			_add_feedback("%+d HP" % hp_delta, "positive" if hp_delta > 0 else "negative", _hp_label.position.y, 1.0)
	else:
		_clear_feedback()
		_snap_bars()
	_layout()


func clear_selection() -> void:
	_has_snapshot = false
	_hero_name = ""
	_class_label = ""
	_xp = 0
	_hp = 0
	_effects.clear()
	if is_node_ready():
		_clear_feedback()
		_refresh_labels()
		_snap_bars()
		_layout()
		set_process(false)


func _build() -> void:
	_class_name = _label("ClassName", BODY_FONT, 9)
	_class_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_name_label = _label("HeroName", DISPLAY_FONT, 18)
	_xp_label = _label("ExperienceLabel", BODY_FONT, 10)
	_hp_label = _label("HealthLabel", BODY_FONT, 10)
	_xp_track = _rect("ExperienceTrack")
	_hp_track = _rect("HealthTrack")
	_xp_fill = _rect("ExperienceFill")
	_hp_fill = _rect("HealthFill")
	_debuffs = _effect_row("Debuffs")
	_buffs = _effect_row("Buffs")
	_feedback_layer = Control.new()
	_feedback_layer.name = "FeedbackLayer"
	_feedback_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_feedback_layer)


func _refresh_labels() -> void:
	_class_name.text = _class_label.to_upper() if _has_snapshot else "HERO"
	_class_name.tooltip_text = _class_label
	_name_label.text = _hero_name if _has_snapshot else "No hero selected"
	_name_label.tooltip_text = _hero_name
	_xp_label.text = "LVL %d · XP %d/%d" % [_level, _xp, _xp_max] if _has_snapshot else "Select a hero to view vitals"
	_hp_label.text = "HP %d/%d" % [_hp, _hp_max] if _has_snapshot else ""
	_xp_label.tooltip_text = _xp_label.text
	_hp_label.tooltip_text = _hp_label.text
	for item: Control in [_xp_track, _hp_track, _xp_fill, _hp_fill]:
		item.visible = _has_snapshot
	_refresh_effects()


func _refresh_effects() -> void:
	var sorted: Array[Dictionary] = _effects.duplicate()
	sorted.sort_custom(_effect_before)
	_render_effect_row(_debuffs, sorted, false)
	_render_effect_row(_buffs, sorted, true)


static func _effect_before(left: Dictionary, right: Dictionary) -> bool:
	var left_good: bool = bool(left.get("beneficial", false))
	var right_good: bool = bool(right.get("beneficial", false))
	if left_good != right_good:
		return not left_good
	var left_time: float = _effect_seconds(left)
	var right_time: float = _effect_seconds(right)
	left_time = INF if left_time < 0.0 else left_time
	right_time = INF if right_time < 0.0 else right_time
	return str(left.get("name", "")) < str(right.get("name", "")) if left_time == right_time else left_time < right_time


static func _effect_seconds(effect: Dictionary) -> float:
	var seconds: float = float(effect.get("remaining_seconds", 0.0))
	return seconds if is_finite(seconds) and seconds >= 0.0 else -1.0


func _render_effect_row(row: RichTextLabel, effects: Array[Dictionary], beneficial: bool) -> void:
	var entries: Array[Dictionary] = []
	var details: PackedStringArray = []
	for effect: Dictionary in effects:
		if bool(effect.get("beneficial", false)) == beneficial:
			entries.append(effect)
			details.append(_effect_plain(effect))
	row.tooltip_text = " · ".join(details)
	var parts: PackedStringArray = []
	var used_width: float = 0.0
	var duration_color: String = ArenicHudTokens.color("positive" if beneficial else "negative", _visual_theme).to_html(false)
	for index: int in entries.size():
		var effect: Dictionary = entries[index]
		var plain: String = _effect_plain(effect)
		var width: float = BODY_FONT.get_string_size(plain + "   ", HORIZONTAL_ALIGNMENT_LEFT, -1, ROW_FONT_SIZE).x
		var reserve: float = 22.0 if index < entries.size() - 1 else 0.0
		if used_width + width + reserve > maxf(0.0, size.x):
			parts.append("+%d" % (entries.size() - index))
			break
		used_width += width
		var effect_name: String = _effect_name(effect).replace("[", "[lb]")
		var stacks: int = maxi(1, int(effect.get("stacks", 1)))
		var stack_label: String = " ×%d" % stacks if stacks > 1 else ""
		var remaining: float = _effect_seconds(effect)
		var duration: String = " [color=#%s](%ds)[/color]" % [duration_color, ceili(remaining)] if remaining >= 0.0 else ""
		parts.append(effect_name + stack_label + duration)
	row.text = "   ".join(parts)


static func _effect_name(effect: Dictionary) -> String:
	return str(effect.get("name", "Effect")).replace("\n", " ").left(40)


static func _effect_plain(effect: Dictionary) -> String:
	var stacks: int = maxi(1, int(effect.get("stacks", 1)))
	var remaining: float = _effect_seconds(effect)
	var duration: String = " (%ds)" % ceili(remaining) if remaining >= 0.0 else ""
	return "%s%s%s" % [_effect_name(effect), " ×%d" % stacks if stacks > 1 else "", duration]


func _apply_palette() -> void:
	for label: Label in [_name_label, _xp_label, _hp_label]:
		label.add_theme_color_override("font_color", ArenicHudTokens.color("content", _visual_theme))
	_class_name.add_theme_color_override("font_color", ArenicHudTokens.color("muted", _visual_theme))
	for row: RichTextLabel in [_debuffs, _buffs]:
		row.add_theme_color_override("default_color", ArenicHudTokens.color("content", _visual_theme))
	_xp_track.color = ArenicHudTokens.color("track", _visual_theme)
	_hp_track.color = _xp_track.color
	_xp_fill.color = ArenicHudTokens.color("xp", _visual_theme)
	_hp_fill.color = ArenicHudTokens.color("hp", _visual_theme)
	for popup: Dictionary in _feedback:
		var label: Label = popup["label"]
		label.add_theme_color_override("font_color", ArenicHudTokens.color(popup["token"], _visual_theme))


func _snap_bars() -> void:
	_display_xp = clampf(float(_xp) / float(_xp_max), 0.0, 1.0)
	_display_hp = clampf(float(_hp) / float(_hp_max), 0.0, 1.0)
	_target_xp = _display_xp
	_target_hp = _display_hp
	_bar_elapsed = BAR_SECONDS


func _animate_bars() -> void:
	_from_xp = _display_xp
	_from_hp = _display_hp
	_target_xp = clampf(float(_xp) / float(_xp_max), 0.0, 1.0)
	_target_hp = clampf(float(_hp) / float(_hp_max), 0.0, 1.0)
	_bar_elapsed = 0.0
	set_process(true)


func _add_feedback(text: String, token: String, y: float, direction: float) -> void:
	if _feedback.size() >= MAX_POPUPS:
		return # Only transient labels are shed; snapshots always update the bars.
	var label: Label = _label("StatFeedback", BODY_FONT, 11)
	label.reparent(_feedback_layer)
	label.text = text
	label.clip_text = false
	label.add_theme_color_override("font_color", ArenicHudTokens.color(token, _visual_theme))
	var origin := Vector2(maxf(0.0, size.x - 60.0), y - float(_feedback.size() % 4) * 3.0)
	label.position = origin
	label.size = Vector2(60.0, 14.0)
	_feedback.append({"label": label, "age": 0.0, "origin": origin, "direction": direction, "token": token})
	set_process(true)


func _clear_feedback() -> void:
	for popup: Dictionary in _feedback:
		var label: Label = popup["label"]
		label.free()
	_feedback.clear()


func _process(delta: float) -> void:
	if _bar_elapsed < BAR_SECONDS:
		_bar_elapsed = minf(BAR_SECONDS, _bar_elapsed + delta)
		var progress: float = _bar_elapsed / BAR_SECONDS
		var eased: float = 1.0 - pow(1.0 - progress, 3.0)
		_display_xp = lerpf(_from_xp, _target_xp, eased)
		_display_hp = lerpf(_from_hp, _target_hp, eased)
		_layout_bars()
	for index: int in range(_feedback.size() - 1, -1, -1):
		var popup: Dictionary = _feedback[index]
		var label: Label = popup["label"]
		var age: float = float(popup["age"]) + delta
		if age >= POPUP_SECONDS:
			label.free()
			_feedback.remove_at(index)
			continue
		popup["age"] = age
		var progress: float = age / POPUP_SECONDS
		label.position = Vector2(popup["origin"]) + Vector2(0.0, float(popup["direction"]) * 18.0 * progress)
		label.modulate.a = 1.0 - progress
	if _bar_elapsed >= BAR_SECONDS and _feedback.is_empty():
		set_process(false)


func _layout() -> void:
	if not is_node_ready():
		return
	# One identity row leaves room for real line heights, bars, and both effect rows.
	var name_height: float = _name_label.get_combined_minimum_size().y
	var class_height: float = _class_name.get_combined_minimum_size().y
	var class_width: float = minf(size.x * 0.4, ceilf(BODY_FONT.get_string_size(_class_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x))
	var class_y: float = maxf(0.0, DISPLAY_FONT.get_ascent(18) - BODY_FONT.get_ascent(9))
	_place(_name_label, 0.0, 0.0, maxf(0.0, size.x - class_width - 12.0), name_height)
	_place(_class_name, size.x - class_width, class_y, class_width, class_height)
	var row_y: float = maxf(name_height, class_y + class_height) + 1.0
	_place(_xp_label, 0.0, row_y, size.x, _xp_label.get_combined_minimum_size().y)
	row_y = _xp_label.get_rect().end.y + 5.0 # One-pixel gaps around the 3px bar.
	_place(_hp_label, 0.0, row_y, size.x, _hp_label.get_combined_minimum_size().y)
	row_y = _hp_label.get_rect().end.y + 5.0
	var effect_height: float = BODY_FONT.get_height(ROW_FONT_SIZE)
	_place(_debuffs, 0.0, row_y, size.x, effect_height)
	_place(_buffs, 0.0, row_y + effect_height, size.x, effect_height)
	_layout_bars()
	_refresh_effects()


func _layout_bars() -> void:
	var xp_y: float = _xp_label.get_rect().end.y + 1.0
	var hp_y: float = _hp_label.get_rect().end.y + 1.0
	_place(_xp_track, 0.0, xp_y, size.x, 3.0)
	_place(_hp_track, 0.0, hp_y, size.x, 3.0)
	_place(_xp_fill, 0.0, xp_y, size.x * _display_xp, 3.0)
	_place(_hp_fill, 0.0, hp_y, size.x * _display_hp, 3.0)


func _label(node_name: String, font: Font, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	add_child(label)
	return label


func _rect(node_name: String) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = node_name
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


func _effect_row(node_name: String) -> RichTextLabel:
	var row := RichTextLabel.new()
	row.name = node_name
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.bbcode_enabled = true
	row.scroll_active = false
	row.add_theme_font_override("normal_font", BODY_FONT)
	row.add_theme_font_size_override("normal_font_size", ROW_FONT_SIZE)
	row.add_theme_constant_override("line_separation", 0)
	add_child(row)
	return row


func _place(control: Control, x: float, y: float, width: float, height: float) -> void:
	control.position = Vector2(x, y)
	control.size = Vector2(maxf(0.0, width), height)
