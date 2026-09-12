extends SceneTree
## The modal contract in isolation: one at a time, single-shot, keyboard-first.
## Godot --headless --path arenic-game --script res://tests/ui/modal_checks.gd

const THEME_PATH: String = "res://data/themes/labyrinth.tres"

var _modal: ArenicModal
var _theme: ArenicArenaTheme
var _heard: Array[Array] = []
var _checks: int = 0
var _failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_theme = load(THEME_PATH) as ArenicArenaTheme
	root.size = Vector2i(1280, 720)
	_modal = ArenicModal.new()
	root.add_child(_modal)
	_modal.chosen.connect(func(choice: String, context: Dictionary) -> void: _heard.append([choice, context]))
	await process_frame

	_check(not _modal.is_open() and not _modal.visible, "A modal starts closed and invisible.")
	_check_opening()
	await _check_keyboard()
	await _check_single_shot()
	await _check_escape()
	_check_context()
	_finish()


func _check_opening() -> void:
	var opened: bool = _open(["Commit", "Keep recording", "Discard"], 1)
	_check(opened and _modal.is_open() and _modal.visible, "Opening presents the decision.")
	_check(_modal.focused_choice() == ArenicModal.CANCEL, "The default option is focused, not simply the first.")
	_check(_modal.arena_id == "labyrinth", "A modal knows which arena it belongs to.")
	_check(not _open(["Yes", "No"], 0), "A second modal cannot stack on an open one.")
	_check(_modal.focused_choice() == ArenicModal.CANCEL, "The refused modal leaves the open one untouched.")
	var dialog := _modal.get_node("Dialog") as Panel
	_check(dialog.get_node("Option2").visible and not dialog.get_node("Option3").visible, "Only the offered options are shown.")
	_modal.close()
	_check(not _modal.is_open() and _heard.is_empty(), "Closing reports no decision; the caller already decided.")


## Arrows move, digits pick, and focus wraps at both ends.
func _check_keyboard() -> void:
	_open(["Commit", "Keep recording", "Discard"], 0)
	_check(_modal.focused_choice() == ArenicModal.COMMIT, "Focus starts on the default.")
	await _press(KEY_RIGHT)
	_check(_modal.focused_choice() == ArenicModal.CANCEL, "Right advances the focus.")
	await _press(KEY_DOWN)
	_check(_modal.focused_choice() == ArenicModal.DISCARD, "Down advances like Right.")
	await _press(KEY_RIGHT)
	_check(_modal.focused_choice() == ArenicModal.COMMIT, "Focus wraps past the last option.")
	await _press(KEY_LEFT)
	_check(_modal.focused_choice() == ArenicModal.DISCARD, "Left wraps back to the last option.")
	await _press(KEY_ENTER)
	_check(_heard.size() == 1 and _heard[0][0] == ArenicModal.DISCARD, "Enter takes the focused option.")
	_heard.clear()
	_open(["Commit", "Keep recording", "Discard"], 0)
	await _press(KEY_2)
	_check(_heard.size() == 1 and _heard[0][0] == ArenicModal.CANCEL, "A digit takes that option directly.")
	_heard.clear()


## A decision is single-shot: mashing cannot apply it twice.
func _check_single_shot() -> void:
	_open(["Commit", "Discard"], 0)
	await _press(KEY_ENTER)
	await _press(KEY_ENTER)
	await _press(KEY_1)
	_check(_heard.size() == 1, "A decision is reported exactly once however hard the key is mashed.")
	_check(not _modal.is_open(), "Taking a decision closes the modal.")
	_heard.clear()
	_modal.choose(0)
	_check(_heard.is_empty(), "A choice arriving after the modal closed is dropped.")


## Esc is the safe way out, whatever position the cancelling option sits in.
func _check_escape() -> void:
	_open(["Take control", "Restart arena", "Cancel"], 0)
	await _press(KEY_ESCAPE)
	_check(_heard.size() == 1 and _heard[0][0] == ArenicModal.CANCEL, "Esc cancels from anywhere in the list.")
	_heard.clear()
	# A modal with no cancelling option still has to be escapable.
	_modal.open("labyrinth", _theme, "Time's up", "The cycle is full", [["Commit", ArenicModal.COMMIT], ["Discard", ArenicModal.DISCARD]], 0)
	await _press(KEY_ESCAPE)
	_check(_heard.size() == 1 and _heard[0][0] == ArenicModal.DISCARD, "Without a cancel option Esc takes the last, least destructive one.")
	_heard.clear()


## A modal carries the caller's state so the handler needs no side channel.
func _check_context() -> void:
	_modal.open("gala", _theme, "Like the recording?", "Moving out cancels it",
		[["Continue", ArenicModal.CANCEL], ["Walk out", ArenicModal.DISCARD_AND_WALK]], 0,
		{"step": Vector2i.RIGHT, "identity": 7})
	_modal.choose(1)
	_check(_heard.size() == 1 and _heard[0][0] == ArenicModal.DISCARD_AND_WALK, "The taken choice is reported.")
	_check(_heard[0][1].get("step") == Vector2i.RIGHT and int(_heard[0][1].get("identity")) == 7, "Its context travels with it.")
	_heard.clear()


func _open(labels: Array, default_index: int) -> bool:
	var options: Array = []
	var ids: PackedStringArray = [ArenicModal.COMMIT, ArenicModal.CANCEL, ArenicModal.DISCARD, ArenicModal.TAKE_CONTROL]
	for index: int in labels.size():
		options.append([labels[index], ids[index]])
	return _modal.open("labyrinth", _theme, "Like the recording?", "Commit folds this draft into the arena", options, default_index)


func _press(key: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame


func _check(passed: bool, message: String) -> bool:
	_checks += 1
	if not passed:
		_failed = true
		print("Modal assertion failed: ", message)
	return passed


func _finish() -> void:
	if _failed:
		quit(1)
		return
	print("Modal checks passed: %d assertions; one at a time, single-shot, keyboard-first." % _checks)
	quit(0)
