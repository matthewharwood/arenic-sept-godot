class_name ArenicTitleMusic
extends AudioStreamPlayer
## One non-spatial voice owned by the title scene, never an autoload.
## A future settings UI can apply a replacement through configure().

@export var definition: ArenicTitleMusicDefinition
var _fade: Tween
var _awaiting_gesture: bool = false


func _ready() -> void:
	max_polyphony = 1
	# Keep the five-minute score compressed; use the same stream mixer as music
	# in the world instead of decoding an entire Web Audio sample up front.
	playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	configure(definition)


func configure(value: ArenicTitleMusicDefinition) -> void:
	stop()
	_stop_fade()
	stream = null
	definition = value
	_awaiting_gesture = false
	set_process_input(false)
	if not is_inside_tree() or definition == null:
		return
	var errors := definition.validation_errors()
	if not errors.is_empty():
		push_error("Invalid title music: " + "; ".join(errors))
		return
	if not definition.enabled:
		return
	stream = definition.make_stream()
	_awaiting_gesture = OS.has_feature("web")
	set_process_input(_awaiting_gesture)
	if not _awaiting_gesture:
		_start_music()


func _input(event: InputEvent) -> void:
	if not _awaiting_gesture:
		return
	var pressed_key: bool = event is InputEventKey and event.pressed and not event.echo
	var pressed_pointer: bool = event is InputEventMouseButton and event.pressed
	var pressed_touch: bool = event is InputEventScreenTouch and event.pressed
	if pressed_key or pressed_pointer or pressed_touch:
		_awaiting_gesture = false
		set_process_input(false)
		_start_music()
	# Do not consume input: Start, Continue and keyboard focus still work normally.


func _start_music() -> void:
	volume_linear = 0.0 if definition.fade_in_seconds > 0.0 else db_to_linear(definition.gain_db)
	play()
	if definition.fade_in_seconds > 0.0:
		_fade = create_tween()
		_fade.tween_property(self, "volume_linear", db_to_linear(definition.gain_db), definition.fade_in_seconds)


func _stop_fade() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = null


func _exit_tree() -> void:
	_stop_fade()
	stop()
	stream = null
