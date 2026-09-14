class_name ArenicActivityFeedView
extends Control
## A passive, bounded projection of session events. C opens a scrollable history.

const BODY_FONT: Font = preload("res://assets/fonts/Barlow-Regular.ttf")
const VISIBLE_LINES: int = 4
const HISTORY_SIZE: Vector2 = Vector2(520, 280)

var _feed: ArenicActivityFeed
var _visual_theme: ArenicArenaTheme
var _panel: Panel
var _header: Button
var _hotkey: Label
var _lines: Array[Label] = []
var _expanded_panel: Panel
var _history: RichTextLabel
var _filter: OptionButton
var _close: Button
var _title: Label
var _panel_style := StyleBoxFlat.new()
var _header_styles: Array[StyleBoxFlat] = []
var _expanded: bool = false
var _refresh_queued: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = Panel.new()
	_panel.name = "Body"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", _panel_style)
	add_child(_panel)
	for index: int in VISIBLE_LINES:
		var line := _label(_panel, "Line%d" % index, 11)
		_lines.append(line)
	_header = _button(self, "Header", "Global Chat", toggle_expanded)
	_header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header.tooltip_text = "C · Open recent activity from every arena"
	_hotkey = _label(_header, "Hotkey", 12)
	_hotkey.text = "C"
	_hotkey.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_expanded_panel = Panel.new()
	_expanded_panel.name = "Expanded"
	_expanded_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_expanded_panel.add_theme_stylebox_override("panel", _panel_style)
	# Draw above neighboring HUD children while leaving the modal layer on top.
	_expanded_panel.z_index = 1
	add_child(_expanded_panel)
	_title = _label(_expanded_panel, "Title", 16)
	_title.text = "Global Chat"
	_filter = OptionButton.new()
	_filter.name = "Filter"
	_filter.focus_mode = Control.FOCUS_NONE
	_filter.add_theme_font_override("font", BODY_FONT)
	_filter.add_theme_font_size_override("font_size", 12)
	for label: String in ["All activity", "Notices", "Warnings +", "Important"]:
		_filter.add_item(label)
	_filter.item_selected.connect(func(_index: int) -> void: _refresh())
	_expanded_panel.add_child(_filter)
	_close = _button(_expanded_panel, "Close", "Close · C", toggle_expanded)
	_history = RichTextLabel.new()
	_history.name = "History"
	_history.focus_mode = Control.FOCUS_NONE
	_history.mouse_filter = Control.MOUSE_FILTER_STOP
	_history.scroll_active = true
	_history.scroll_following = true
	_history.selection_enabled = true
	_history.add_theme_font_override("normal_font", BODY_FONT)
	_history.add_theme_font_size_override("normal_font_size", 13)
	_history.add_theme_constant_override("line_separation", 5)
	_expanded_panel.add_child(_history)
	_expanded_panel.hide()
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		style.content_margin_left = 7
		style.content_margin_right = 7
		_header_styles.append(style)
		for button: Button in [_header, _close, _filter]:
			button.add_theme_stylebox_override(state, style)
			button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	resized.connect(_layout)
	_apply_palette()
	_layout()
	_refresh()


func set_feed(value: ArenicActivityFeed) -> void:
	if _feed == value:
		return
	if _feed != null and _feed.changed.is_connected(_queue_refresh):
		_feed.changed.disconnect(_queue_refresh)
	_feed = value
	if _feed != null:
		_feed.changed.connect(_queue_refresh)
	if is_node_ready():
		_refresh()


func set_visual_theme(value: ArenicArenaTheme) -> void:
	if _visual_theme == value:
		return
	_visual_theme = value
	if is_node_ready():
		_apply_palette()
		_refresh()


func is_expanded() -> bool:
	return _expanded


func toggle_expanded() -> void:
	_expanded = not _expanded
	_expanded_panel.visible = _expanded
	_header.tooltip_text = "C · Close recent activity" if _expanded else "C · Open recent activity from every arena"
	if _expanded:
		_refresh()


func snapshot() -> Dictionary:
	var lines: PackedStringArray = []
	for line: Label in _lines:
		lines.append(line.text)
	return {"entries": _feed.entries.duplicate(true) if _feed != null else [], "expanded": _expanded, "lines": lines}


func _queue_refresh() -> void:
	if not _refresh_queued:
		_refresh_queued = true
		_refresh.call_deferred()


func _refresh() -> void:
	_refresh_queued = false
	if not is_node_ready():
		return
	var entries: Array[Dictionary] = []
	if _feed != null:
		entries = _feed.entries
	var recent: Array[Dictionary] = []
	var attention: Dictionary = _feed.attention if _feed != null else {}
	if not attention.is_empty():
		recent.append(attention)
	var tail: Array[Dictionary] = []
	for index: int in range(entries.size() - 1, -1, -1):
		# Current attention is the only compact recruitment reminder. Historical
		# availability remains in expanded history even after the last roll is claimed.
		if entries[index].get("event_type") == &"recruit.ready":
			continue
		tail.push_front(entries[index])
		if tail.size() >= VISIBLE_LINES - recent.size():
			break
	recent.append_array(tail)
	for index: int in VISIBLE_LINES:
		var line: Label = _lines[index]
		if index < recent.size():
			line.text = _entry_text(recent[index])
			line.tooltip_text = line.text
			line.add_theme_color_override("font_color", _entry_color(recent[index]))
		else:
			line.text = ":: Raid activity will appear here" if entries.is_empty() and index == 0 else ""
			line.tooltip_text = ""
			line.add_theme_color_override("font_color", ArenicHudTokens.color("debug", _visual_theme))
	if not _expanded:
		return
	var bar: VScrollBar = _history.get_v_scroll_bar()
	var previous_scroll: float = bar.value
	var follow: bool = previous_scroll >= bar.max_value - bar.page - 2.0
	_history.scroll_following = follow
	_history.clear()
	var shown: int = 0
	for entry: Dictionary in entries:
		if not _matches_filter(entry):
			continue
		_history.push_color(_entry_color(entry))
		_history.add_text(_entry_text(entry) + "\n")
		_history.pop()
		shown += 1
	if shown == 0:
		_history.add_text("No activity in this view yet.")
	if not follow:
		bar.set_value.call_deferred(previous_scroll)


func _matches_filter(entry: Dictionary) -> bool:
	var severity: int = int(entry.get("severity", ArenicGameEvent.Severity.INFO))
	match _filter.selected:
		1: return severity >= ArenicGameEvent.Severity.INFO
		2: return severity >= ArenicGameEvent.Severity.WARNING
		3: return int(entry.get("importance", ArenicGameEvent.Importance.NORMAL)) == ArenicGameEvent.Importance.HIGH
	return true


func _entry_color(entry: Dictionary) -> Color:
	var severity: int = int(entry.get("severity", ArenicGameEvent.Severity.INFO))
	if severity == ArenicGameEvent.Severity.ERROR:
		return ArenicHudTokens.color("alert", _visual_theme)
	if severity == ArenicGameEvent.Severity.WARNING:
		return ArenicHudTokens.color("warning", _visual_theme)
	if int(entry.get("importance", ArenicGameEvent.Importance.NORMAL)) == ArenicGameEvent.Importance.HIGH:
		return ArenicHudTokens.color("alert", _visual_theme)
	if severity == ArenicGameEvent.Severity.DEBUG:
		return ArenicHudTokens.color("debug", _visual_theme)
	return ArenicHudTokens.color("content", _visual_theme)


func _entry_text(entry: Dictionary) -> String:
	var severity: int = int(entry.get("severity", ArenicGameEvent.Severity.INFO))
	var prefix: String = ":: "
	if severity == ArenicGameEvent.Severity.ERROR:
		prefix = "Error · "
	elif severity == ArenicGameEvent.Severity.WARNING:
		prefix = "! "
	elif int(entry.get("importance", ArenicGameEvent.Importance.NORMAL)) == ArenicGameEvent.Importance.HIGH:
		prefix = "! "
	return prefix + str(entry.get("text", ""))


func _apply_palette() -> void:
	var content: Color = ArenicHudTokens.color("content", _visual_theme)
	var surface: Color = _visual_theme.color("base_100") if _visual_theme != null else ArenicHudTokens.color("map_active")
	var accent: Color = _visual_theme.color("accent") if _visual_theme != null else content
	_panel_style.bg_color = surface
	_panel_style.border_color = Color(content, 0.45)
	_panel_style.set_border_width_all(1)
	_panel_style.set_corner_radius_all(12)
	for index: int in _header_styles.size():
		_header_styles[index].bg_color = surface.lerp(accent, 0.08 if index in [1, 2] else 0.0)
		_header_styles[index].border_color = Color(content, 0.65)
	for button: Button in [_header, _close, _filter]:
		button.add_theme_color_override("font_color", content)
		button.add_theme_color_override("font_hover_color", content)
		button.add_theme_color_override("font_pressed_color", accent)
	_hotkey.add_theme_color_override("font_color", accent)
	_title.add_theme_color_override("font_color", content)
	_history.add_theme_color_override("default_color", content)


func _layout() -> void:
	_panel.position = Vector2(0, 9)
	_panel.size = Vector2(size.x, size.y - 9)
	_header.position = Vector2.ZERO
	_header.size = Vector2(148, 20)
	_hotkey.position = Vector2(120, 0)
	_hotkey.size = Vector2(19, 20)
	for index: int in VISIBLE_LINES:
		_lines[index].position = Vector2(8, 14 + index * 15)
		_lines[index].size = Vector2(size.x - 16, 15)
	_expanded_panel.position = Vector2(size.x - HISTORY_SIZE.x, -HISTORY_SIZE.y - 8)
	_expanded_panel.size = HISTORY_SIZE
	_title.position = Vector2(14, 10)
	_title.size = Vector2(162, 26)
	_filter.position = Vector2(202, 10)
	_filter.size = Vector2(204, 26)
	_close.position = Vector2(418, 10)
	_close.size = Vector2(88, 26)
	_history.position = Vector2(14, 45)
	_history.size = HISTORY_SIZE - Vector2(28, 59)


func _label(parent: Node, node_name: String, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_override("font", BODY_FONT)
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _button(parent: Node, node_name: String, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", BODY_FONT)
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(action)
	parent.add_child(button)
	return button
