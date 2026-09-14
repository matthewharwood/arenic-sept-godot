extends SceneTree
## Real input dispatch into the empty tabbed modal; no world/save dependencies.

class InputWitness extends Node:
	var keys: int = 0
	var pointers: int = 0
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey:
			keys += 1
		elif event is InputEventMouseButton:
			pointers += 1

var menu: ArenicOverworldMenu
var witness: InputWitness
var closed_count: int = 0
var checks: int = 0
var failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	witness = InputWitness.new()
	root.add_child(witness)
	menu = ArenicOverworldMenu.new()
	menu.configure(load("res://data/themes/labyrinth.tres"))
	root.add_child(menu)
	menu.closed.connect(func(): closed_count += 1)
	await process_frame
	_check(not menu.is_open() and not menu.visible and menu.active_action().is_empty(), "Starts closed with no active action")
	_check(not menu.open_action(&"unknown") and not menu.is_open(), "Unknown IDs cannot open an invented tab")
	_check(menu.open_action(&"rotate_selected"), "The first catalog action opens")
	await process_frame
	await _key(KEY_LEFT)
	_check(menu.active_action() == &"craft", "Left wraps first to last")
	await _key(KEY_RIGHT)
	_check(menu.active_action() == &"rotate_selected", "Right wraps last to first")
	await _key(KEY_TAB)
	_check(menu.active_action() == &"roster", "Tab advances one tab")
	await _key(KEY_TAB, true)
	_check(menu.active_action() == &"rotate_selected", "Shift Tab moves back")
	for index: int in ArenicOverworldActions.COUNT:
		await _key(ArenicOverworldActions.KEYS[index])
		_check(menu.active_action() == ArenicOverworldActions.action_for_slot(index), "The displayed shortcut selects its exact stable action")
	await _key(KEY_2, false, true)
	await _key(KEY_LEFT, false, false, true)
	await _key(KEY_1, true)
	_check(menu.active_action() == &"craft", "Modified shortcuts and repeats do not switch tabs")
	for key: int in [KEY_UP, KEY_DOWN, KEY_H, KEY_P, KEY_SPACE]:
		await _key(key)
	_check(witness.keys == 0, "Gameplay/navigation keys never reach unhandled input while open")
	await _click((menu.get_node("Panel/Layout/Tabs/loot") as Button).get_global_rect().get_center())
	_check(menu.active_action() == &"loot", "A real pointer click switches tabs")
	await _click(Vector2(8, 8))
	_check(menu.is_open() and witness.pointers == 0, "Outside pointer input hits the shield without dismissing or leaking")
	var wheel := InputEventMouseButton.new()
	wheel.position = Vector2(8,8)
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	root.push_input(wheel, true)
	await process_frame
	_check(witness.pointers == 0, "Wheel navigation is contained by the input shield")
	for dimensions: Vector2i in [Vector2i(1280,720), Vector2i(960,600)]:
		root.size = dimensions
		await process_frame
		await process_frame
		var panel := menu.get_node("Panel") as Panel
		var tabs := menu.get_node("Panel/Layout/Tabs") as HBoxContainer
		_check(Rect2(Vector2.ZERO,menu.size).encloses(panel.get_rect()), "Centered frame remains inside the viewport")
		var prior_right: float = -1.0
		for button: Button in tabs.get_children():
			_check(panel.get_global_rect().encloses(button.get_global_rect()) and button.position.x >= prior_right, "Content-measured tab titles fit without overlap")
			prior_right = button.position.x + button.size.x
		_check(menu.get_node("Panel/Layout/Body").get_child_count() == 0, "The tab body contains no invented content or flow")
		var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
		_check(style.corner_radius_top_left == 0 and style.border_width_left == 1 and style.shadow_size == 0, "Modal retains the square thin frame")
	menu.configure(load("res://data/themes/guild_house.tres"))
	_check(menu.active_action() == &"loot", "Retheming keeps the selected tab")
	await _key(KEY_ESCAPE)
	_check(not menu.is_open() and closed_count == 1, "Escape closes exactly once")
	menu.close()
	_check(closed_count == 1, "Repeated close is silent")
	menu.open_action(&"auction")
	await process_frame
	await _click((menu.get_node("Panel/Layout/Header/Close") as Button).get_global_rect().get_center())
	_check(not menu.is_open() and closed_count == 2, "The real close button emits one close")
	var entries: Array[Dictionary] = ArenicOverworldActions.entries()
	entries[0].title = "changed outside"
	_check(ArenicOverworldActions.title(&"rotate_selected") == "Rotate selected", "Consumers cannot mutate the shared catalog through returned rows")
	menu.free()
	witness.free()
	print("Overworld menu checks %s: %d assertions; empty tabs, keyboard/pointer containment, frame layout and catalog isolation." % ["failed" if failed else "passed", checks])
	quit(1 if failed else 0)

func _key(code: int, shift: bool = false, control: bool = false, repeated: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	event.shift_pressed = shift
	event.ctrl_pressed = control
	event.echo = repeated
	Input.parse_input_event(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	event.echo = false
	Input.parse_input_event(event)
	await process_frame

func _click(point: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	# Control geometry is in viewport-local coordinates, including after resize.
	root.push_input(event, true)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame

func _check(value: bool, detail: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error("Overworld menu: " + detail)
