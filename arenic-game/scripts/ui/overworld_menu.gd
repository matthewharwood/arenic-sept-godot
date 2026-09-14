class_name ArenicOverworldMenu
extends Control
## Transient overworld tabs. The caller owns availability and simulation;
## this view owns input only while open and never reads or writes a saved run.

signal closed
signal loot_requested

const DISPLAY_FONT: Font = preload("res://assets/fonts/PPMigra-Extrabold.ttf")
const BODY_FONT: Font = preload("res://assets/fonts/Barlow-Regular.ttf")
const MAX_PANEL: Vector2 = Vector2(900.0, 540.0)
const OUTER_MARGIN: float = 24.0

var _theme: ArenicArenaTheme
var _open: bool = false
var _active: int = -1
var _previous_focus: WeakRef
var _shade: ColorRect
var _panel: Panel
var _title: Label
var _close: Button
var _tabs: HBoxContainer
var _buttons: Array[Button] = []
var _footer: Label
var _panel_style: StyleBoxFlat
var _normal_style: StyleBoxFlat
var _hover_style: StyleBoxFlat
var _active_style: StyleBoxFlat
var _focus_style: StyleBoxFlat
var _body: Control
var _loot_rows: Array[Dictionary] = []
var _loot_pending: int = 0

func set_loot_inventory(rows: Array[Dictionary], pending: int = 0) -> void:
	_loot_rows = rows.duplicate(true)
	_loot_pending = maxi(0, pending)
	if is_node_ready():
		_rebuild_loot_body()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_force_pass_scroll_events = false
	focus_mode = Control.FOCUS_ALL
	_build()
	resized.connect(_layout)
	if _theme != null:
		_apply_theme()
	_layout()
	set_process_input(false)
	set_process_unhandled_input(false)
	hide()

func configure(arena_theme: ArenicArenaTheme) -> void:
	if arena_theme == null:
		return
	_theme = arena_theme
	if is_node_ready():
		_apply_theme()

func open_action(action: StringName) -> bool:
	var index: int = ArenicOverworldActions.index_for(action)
	if index < 0 or _theme == null or not is_node_ready():
		return false
	if not _open:
		var previous: Control = get_viewport().gui_get_focus_owner()
		_previous_focus = weakref(previous) if previous != null else null
	_open = true
	_select(index)
	show()
	set_process_input(true)
	set_process_unhandled_input(true)
	grab_focus()
	return true

func close() -> void:
	if not _open:
		return
	_open = false
	_active = -1
	hide()
	set_process_input(false)
	set_process_unhandled_input(false)
	if _previous_focus != null:
		var previous: Control = _previous_focus.get_ref() as Control
		if is_instance_valid(previous) and previous.is_visible_in_tree() and previous.focus_mode != Control.FOCUS_NONE:
			previous.grab_focus()
	_previous_focus = null
	closed.emit()

func is_open() -> bool:
	return _open

func active_action() -> StringName:
	return ArenicOverworldActions.action_for_slot(_active) if _open else &""

func _input(event: InputEvent) -> void:
	if not _open:
		return
	# Pointer events must first reach this view's own tabs/close button. Its full
	# viewport shield consumes them at the GUI boundary, including wheel events.
	if event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag:
		return
	get_viewport().set_input_as_handled()
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	match key:
		KEY_ESCAPE:
			close()
		KEY_LEFT:
			_select(posmod(_active - 1, ArenicOverworldActions.COUNT))
		KEY_RIGHT:
			_select(posmod(_active + 1, ArenicOverworldActions.COUNT))
		KEY_TAB:
			_select(posmod(_active + (-1 if event.shift_pressed else 1), ArenicOverworldActions.COUNT))
		_:
			# Shift+digits are symbols rather than shortcuts. R follows the same
			# unmodified rule so shell recording bindings cannot leak through.
			if not event.shift_pressed:
				var action: StringName = ArenicOverworldActions.action_for_key(key)
				if not action.is_empty():
					_select(ArenicOverworldActions.index_for(action))

func _gui_input(_event: InputEvent) -> void:
	if _open:
		accept_event()

func _unhandled_input(_event: InputEvent) -> void:
	if _open:
		get_viewport().set_input_as_handled()

func _select(index: int) -> void:
	_active = index
	_title.text = ArenicOverworldActions.title(ArenicOverworldActions.action_for_slot(index))
	for at: int in _buttons.size():
		var selected: bool = at == index
		_buttons[at].add_theme_stylebox_override("normal", _active_style if selected else _normal_style)
		_buttons[at].add_theme_color_override("font_color", _theme.color("accent" if selected else "base_content"))
		_buttons[at].set_pressed_no_signal(selected)
	_rebuild_loot_body()

func _build() -> void:
	_shade = ColorRect.new()
	_shade.name = "InputShade"
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shade)
	_panel = Panel.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel.mouse_force_pass_scroll_events = false
	add_child(_panel)
	var stack := VBoxContainer.new()
	stack.name = "Layout"
	stack.add_theme_constant_override("separation", 16)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(stack)
	stack.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.offset_left = 24.0
	stack.offset_top = 20.0
	stack.offset_right = -24.0
	stack.offset_bottom = -20.0
	var header := HBoxContainer.new()
	header.name = "Header"
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 18)
	stack.add_child(header)
	_title = Label.new()
	_title.name = "Title"
	_title.add_theme_font_override("font", DISPLAY_FONT)
	_title.add_theme_font_size_override("font_size", 28)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_title)
	_close = _button("Close", "×")
	_close.add_theme_font_size_override("font_size", 22)
	_close.custom_minimum_size = Vector2(36.0, 36.0)
	_close.tooltip_text = "Close · Esc"
	_close.pressed.connect(close)
	header.add_child(_close)
	_tabs = HBoxContainer.new()
	_tabs.name = "Tabs"
	_tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tabs.add_theme_constant_override("separation", 6)
	stack.add_child(_tabs)
	for entry: Dictionary in ArenicOverworldActions.entries():
		var button := _button(str(entry.id), "%s  %s" % [entry.hotkey, entry.title])
		button.toggle_mode = true
		button.custom_minimum_size.y = 38.0
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(open_action.bind(entry.id))
		_tabs.add_child(button)
		_buttons.append(button)
	_body = Control.new()
	_body.name = "Body"
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(_body)
	_footer = Label.new()
	_footer.name = "KeyboardGuide"
	_footer.text = "Left / Right / Tab / Shift+Tab  Change tab     1–4 / R  Select     Esc  Close"
	_footer.add_theme_font_override("font", BODY_FONT)
	_footer.add_theme_font_size_override("font_size", 12)
	_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_footer)
	_panel_style = _style()
	_normal_style = _style()
	_hover_style = _style()
	_active_style = _style()
	_focus_style = _style()
	_panel.add_theme_stylebox_override("panel", _panel_style)
	for button: Button in _buttons + [_close]:
		button.add_theme_stylebox_override("normal", _normal_style)
		button.add_theme_stylebox_override("hover", _hover_style)
		button.add_theme_stylebox_override("pressed", _active_style)
		button.add_theme_stylebox_override("hover_pressed", _active_style)
		button.add_theme_stylebox_override("focus", _focus_style)

func _button(node_name: String, text: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_force_pass_scroll_events = false
	button.add_theme_font_override("font", BODY_FONT)
	button.add_theme_font_size_override("font_size", 15)
	return button

func _style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_border_width_all(1)
	style.set_content_margin_all(12.0)
	style.corner_detail = 1
	return style

func _apply_theme() -> void:
	var accent: Color = _theme.color("accent")
	var content: Color = _theme.color("base_content")
	var background: Color = _theme.color("base_300")
	_shade.color = _theme.color("base_300", 0.70)
	_panel_style.bg_color = background
	_panel_style.border_color = accent
	_normal_style.bg_color = _theme.color("base_200")
	_normal_style.border_color = _theme.color("base_content", 0.25)
	_hover_style.bg_color = background.lerp(accent, 0.10)
	_hover_style.border_color = accent
	_active_style.bg_color = background.lerp(accent, 0.15)
	_active_style.border_color = accent
	_focus_style.bg_color = _theme.color("base_300", 0.0)
	_focus_style.border_color = accent
	_title.add_theme_color_override("font_color", content)
	_footer.add_theme_color_override("font_color", _theme.color("base_content", 0.65))
	for button: Button in _buttons + [_close]:
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
			button.add_theme_color_override(state, content)
	if _active >= 0:
		_select(_active)

func _layout() -> void:
	if _panel == null:
		return
	_panel.size = Vector2(minf(MAX_PANEL.x, maxf(0.0, size.x - OUTER_MARGIN * 2.0)), minf(MAX_PANEL.y, maxf(0.0, size.y - OUTER_MARGIN * 2.0)))
	_panel.position = (size - _panel.size) * 0.5


## Inventory rows are a projection of the run's bounded item-count ledger.
## The view never equips, rolls, spends or retains a second equipment state.
func _rebuild_loot_body() -> void:
	if _body == null:
		return
	for child: Node in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	if _active < 0 or ArenicOverworldActions.action_for_slot(_active) != &"loot" or (_loot_rows.is_empty() and _loot_pending == 0):
		return
	var scroll := ScrollContainer.new()
	scroll.name = "EquipmentCollection"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var list := VBoxContainer.new()
	list.name = "Equipment"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	if _loot_pending > 0:
		var reveal := _button("RevealLoot", "Reveal loot · %d ready" % _loot_pending)
		reveal.add_theme_stylebox_override("normal", _normal_style)
		reveal.add_theme_stylebox_override("hover", _hover_style)
		reveal.add_theme_color_override("font_color", _theme.color("base_content"))
		reveal.pressed.connect(func() -> void: loot_requested.emit())
		list.add_child(reveal)
	for item: Dictionary in _loot_rows:
		var row := HBoxContainer.new()
		row.name = str(item.id)
		row.add_theme_constant_override("separation", 12)
		list.add_child(row)
		var label := Label.new()
		label.text = str(item.name)
		label.tooltip_text = "%s\n%s" % [item.name, item.get("description", "")]
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.add_theme_font_override("font", BODY_FONT)
		label.add_theme_font_size_override("font_size", 17)
		label.add_theme_color_override("font_color", _theme.color("base_content"))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var detail := Label.new()
		detail.text = "%s · %s · %d power    ×%d" % [str(item.rarity).capitalize(), str(item.slot).capitalize(), int(item.power), int(item.count)]
		detail.add_theme_font_override("font", BODY_FONT)
		detail.add_theme_font_size_override("font_size", 14)
		detail.add_theme_color_override("font_color", _theme.color("base_content", 0.68))
		row.add_child(detail)
