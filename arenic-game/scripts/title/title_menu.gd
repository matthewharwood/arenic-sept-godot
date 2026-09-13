extends Control

signal start_requested
signal continue_requested

## Optional destination for Start. A game coordinator can instead handle start_requested.
@export var new_game_scene: PackedScene

@onready var _start: Button = %Start
@onready var _continue: Button = %Continue
@onready var _status: Label = %Status
var _working: bool = false
var _picker: ArenicSaveSlotPicker
var _manage: Button


func _ready() -> void:
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	get_window().content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	get_window().content_scale_size = Vector2i(1440, 1024)
	_start.pressed.connect(_request_start)
	_continue.pressed.connect(_request_continue)
	_connect_focus(_start, _continue)
	_connect_focus(_continue, _start)
	_manage = Button.new()
	_manage.theme = preload("res://scenes/title/save_slots_theme.tres")
	_manage.name = "ManageSaves"
	_manage.text = "Save slots"
	_manage.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_manage.position = Vector2(-204, -80)
	_manage.size = Vector2(172, 48)
	_manage.add_theme_font_size_override("font_size", 20)
	_manage.pressed.connect(_request_continue)
	add_child(_manage)
	_start.disabled = true
	_continue.hide()
	_manage.hide()
	SaveGames.slots_changed.connect(_refresh_saves)
	if not SaveGames.storage_ready:
		await SaveGames.initialized
	_refresh_saves()


func _refresh_saves() -> void:
	_start.disabled = not SaveGames.storage_ready or _working
	_continue.visible = SaveGames.has_saves()
	_manage.visible = SaveGames.has_records()
	_status.text = SaveGames.last_error if not SaveGames.last_error.is_empty() else SaveGames.last_warning
	_connect_focus(_start, _continue if _continue.visible else _start)


func _unhandled_key_input(event: InputEvent) -> void:
	if is_instance_valid(_picker):
		return
	if get_viewport().gui_get_focus_owner() != null:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		_start.grab_focus()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		(_continue if _continue.visible else _start).grab_focus()
		get_viewport().set_input_as_handled()


func _connect_focus(button: Button, neighbor: Button) -> void:
	var path := button.get_path_to(neighbor)
	button.focus_next = path
	button.focus_previous = path
	button.focus_neighbor_left = path
	button.focus_neighbor_right = path
	button.focus_neighbor_top = path
	button.focus_neighbor_bottom = path


func _request_start() -> void:
	if _working or is_instance_valid(_picker):
		return
	_status.text = ""
	if new_game_scene != null:
		_working = true
		_start.disabled = true
		if not await SaveGames.create_game():
			_working = false
			_refresh_saves()
			if SaveGames.has_records():
				_request_continue()
			return
		var error := get_tree().change_scene_to_packed(new_game_scene)
		if error != OK:
			push_error("Could not start the game: %s" % error_string(error))
			_status.text = "The arena could not be opened."
		_working = false
	elif start_requested.get_connections().is_empty():
		_status.text = "The arena is not connected yet."
	else:
		start_requested.emit()


func _request_continue() -> void:
	if _working or is_instance_valid(_picker):
		return
	_status.text = ""
	if not continue_requested.get_connections().is_empty():
		continue_requested.emit()
		return
	_picker = ArenicSaveSlotPicker.new()
	_picker.name = "SaveSlots"
	add_child(_picker)
	_picker.closed.connect(func() -> void: _start.grab_focus())
