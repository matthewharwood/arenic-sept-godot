class_name ArenicHeroInput
extends RefCounted
## At most four pressed-direction flags per physics tick, never an unbounded queue.
## Echo is deliberately ignored: original movement is one tile per NEW press.
var _pressed: Vector4i = Vector4i.ZERO # Left, right, up, down.

func accept(event: InputEventKey) -> bool:
	if not event.pressed or event.echo or event.ctrl_pressed or event.meta_pressed or event.alt_pressed:
		return false
	var key := event.physical_keycode if event.physical_keycode != 0 else event.keycode
	match key:
		KEY_LEFT: _pressed.x = 1
		KEY_RIGHT: _pressed.y = 1
		KEY_UP: _pressed.z = 1
		KEY_DOWN: _pressed.w = 1
		_: return false
	return true

func consume() -> Vector2i:
	var direction := Vector2i(_pressed.y - _pressed.x, _pressed.z - _pressed.w)
	clear()
	return direction

func clear() -> void:
	_pressed = Vector4i.ZERO
