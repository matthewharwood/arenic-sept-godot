extends Control

signal start_requested
signal continue_requested

## Optional destination for Start. A game coordinator can instead handle start_requested.
@export var new_game_scene: PackedScene

@onready var _start: Button = %Start
@onready var _continue: Button = %Continue
@onready var _status: Label = %Status


func _ready() -> void:
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	get_window().content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	get_window().content_scale_size = Vector2i(1440, 1024)
	_start.pressed.connect(_request_start)
	_continue.pressed.connect(_request_continue)
	_connect_focus(_start, _continue)
	_connect_focus(_continue, _start)


func _unhandled_key_input(event: InputEvent) -> void:
	if get_viewport().gui_get_focus_owner() != null:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_down"):
		_start.grab_focus()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_up"):
		_continue.grab_focus()
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
	_status.text = ""
	if new_game_scene != null:
		RunSetup.begin_new_game()
		var error := get_tree().change_scene_to_packed(new_game_scene)
		if error != OK:
			push_error("Could not start the game: %s" % error_string(error))
			_status.text = "The arena could not be opened."
	elif start_requested.get_connections().is_empty():
		_status.text = "The arena is not connected yet."
	else:
		start_requested.emit()


func _request_continue() -> void:
	_status.text = ""
	if continue_requested.get_connections().is_empty():
		_status.text = "No saved game is connected yet."
	else:
		continue_requested.emit()
