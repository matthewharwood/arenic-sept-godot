class_name ArenicSaveSlotPicker
extends Control
## Slot UI has no storage implementation; all platforms use SaveGames.
signal closed
var _rows: VBoxContainer
var _detail: Label
var _confirm: Button
var _pending_delete: int = -1
var _reviewed_token: Dictionary = {}
var _working: bool = false


func _ready() -> void:
	theme = preload("res://scenes/title/save_slots_theme.tres")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.08, 0.07, 0.06, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = -340
	panel.offset_bottom = 340
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.965, 0.953, 0.941)
	style.border_color = Color(0.11, 0.11, 0.11)
	style.set_border_width_all(2)
	style.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)
	var heading := Label.new()
	heading.text = "Your saved games"
	heading.add_theme_font_size_override("font_size", 36)
	content.add_child(heading)
	_detail = Label.new()
	_detail.name = "Detail"
	_detail.text = SaveGames.last_error if not SaveGames.last_error.is_empty() else "Eight local slots. Choose a guild to continue."
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size.y = 48
	_detail.add_theme_font_size_override("font_size", 18)
	content.add_child(_detail)
	_rows = VBoxContainer.new()
	_rows.name = "Rows"
	_rows.add_theme_constant_override("separation", 8)
	content.add_child(_rows)
	_confirm = Button.new()
	_confirm.name = "ConfirmDelete"
	_confirm.text = "Remove this save permanently"
	_confirm.custom_minimum_size.y = 42
	_confirm.pressed.connect(_remove_confirmed)
	_confirm.hide()
	content.add_child(_confirm)
	var back := Button.new()
	back.name = "Back"
	back.text = "Back"
	back.custom_minimum_size.y = 42
	back.pressed.connect(_back)
	content.add_child(back)
	SaveGames.slots_changed.connect(_refresh)
	_refresh()
	back.grab_focus()


func _refresh() -> void:
	if _pending_delete >= 0 and SaveGames.slot_token(_pending_delete) != _reviewed_token:
		_pending_delete = -1
		_confirm.hide()
		_detail.text = "That slot changed. Review it again before removing it."
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	for row: Dictionary in SaveGames.list_slots():
		var line := HBoxContainer.new()
		line.name = "Slot%d" % row.slot
		_rows.add_child(line)
		var choose := Button.new()
		choose.name = "Choose"
		choose.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choose.custom_minimum_size.y = 44
		choose.add_theme_font_size_override("font_size", 19)
		choose.text = "%d   %s" % [row.slot + 1, row.label]
		choose.disabled = row.state != "ready"
		choose.tooltip_text = row.error
		choose.pressed.connect(_choose.bind(row.slot))
		line.add_child(choose)
		var remove := Button.new()
		remove.name = "Remove"
		remove.text = "Remove"
		remove.custom_minimum_size.x = 100
		remove.add_theme_font_size_override("font_size", 18)
		remove.disabled = row.state == "empty"
		remove.pressed.connect(_ask_remove.bind(row.slot, row.error))
		line.add_child(remove)


func _choose(slot: int) -> void:
	if _working:
		return
	_working = true
	_detail.text = "Opening saved game…"
	if not await SaveGames.continue_game(slot):
		_detail.text = SaveGames.last_error
	_working = false


func _ask_remove(slot: int, error: String) -> void:
	if _working:
		return
	_pending_delete = slot
	_reviewed_token = SaveGames.slot_token(slot)
	_detail.text = "Remove slot %d? This cannot be undone." % (slot + 1)
	if not error.is_empty():
		_detail.text += " " + error
	_confirm.show()
	_confirm.grab_focus()


func _remove_confirmed() -> void:
	if _working or _pending_delete < 0:
		return
	_working = true
	if await SaveGames.remove_slot(_pending_delete, int(_reviewed_token.revision), str(_reviewed_token.run_id)):
		_detail.text = "Slot removed. Start creates a new game in an empty slot."
		_pending_delete = -1
		_confirm.hide()
	else:
		_detail.text = SaveGames.last_error
	_working = false


func _back() -> void:
	if _working:
		return
	if _pending_delete >= 0:
		_pending_delete = -1
		_confirm.hide()
		_detail.text = "Eight local slots. Choose a guild to continue."
		return
	closed.emit()
	queue_free()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()
