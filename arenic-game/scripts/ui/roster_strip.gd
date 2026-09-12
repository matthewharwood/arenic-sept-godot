class_name ArenicRosterStrip
extends Control
## Forty visible positions; stored overflow never hides the selected identity.
signal character_requested(identity: int)
const CAPACITY: int = 40
const CELL: float = 16.0
const FONT: Font = preload("res://assets/fonts/Barlow-Regular.ttf")
var entries: Array[Dictionary] = []
var selected_identity: int = -1
var content: Color
var selected_color: Color
var _visible_indices: Array[int] = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func set_roster(value: Array[Dictionary], selected: int, ink: Color, blue: Color) -> void:
	entries = value
	selected_identity = selected
	content = ink
	selected_color = blue
	_visible_indices.clear()
	for index: int in mini(CAPACITY, entries.size()):
		_visible_indices.append(index)
	for index: int in range(CAPACITY, entries.size()):
		if int(entries[index].get("identity", -1)) == selected:
			_visible_indices[CAPACITY - 1] = index
			break
	queue_redraw()

func hidden_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in entries.size():
		if index not in _visible_indices:
			result.append(entries[index])
	return result

func _draw() -> void:
	for slot: int in CAPACITY:
		var center := Vector2(float(slot % 10) * CELL + 7.0, float(slot / 10) * CELL + 7.0)
		if slot >= _visible_indices.size():
			draw_string(FONT, center + Vector2(-5.0, 4.0), "X", HORIZONTAL_ALIGNMENT_CENTER, 10.0, 10, Color(content, 0.38))
			continue
		var entry: Dictionary = entries[_visible_indices[slot]]
		var active: bool = int(entry.get("identity", -1)) == selected_identity
		var dead: bool = bool(entry.get("dead", false))
		if active:
			draw_circle(center, 6.5, selected_color)
		else:
			draw_circle(center, 6.5, Color(content, 0.65), false, 1.0, true)
		# The same blue ring a ghost wears in the world, so a selected ghost
		# reads as both at once rather than one state hiding the other.
		if bool(entry.get("ghost", false)):
			draw_circle(center, 7.4, selected_color, false, 1.2, true)
		var ink: Color = ArenicHudTokens.color("selected_content") if active else content
		if dead:
			draw_circle(center + Vector2(0, -1), 3.5, ink)
			draw_rect(Rect2(center + Vector2(-2, 1), Vector2(4, 3)), ink)
			var cutout: Color = selected_color if active else ArenicHudTokens.color("map_active")
			draw_circle(center + Vector2(-1.5, -1), 0.9, cutout)
			draw_circle(center + Vector2(1.5, -1), 0.9, cutout)
		else:
			draw_string(FONT, center + Vector2(-5, 4), str(entry.get("initial", "?")), HORIZONTAL_ALIGNMENT_CENTER, 10, 10, ink)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var index: int = _entry_at(event.position)
		if index >= 0 and not bool(entries[index].get("dead", false)):
			character_requested.emit(int(entries[index].get("identity", -1)))
		accept_event()

func _get_tooltip(at_position: Vector2) -> String:
	var index: int = _entry_at(at_position)
	if index < 0:
		return "Empty character slot"
	var entry: Dictionary = entries[index]
	var state: String = " · Fallen" if bool(entry.get("dead", false)) else (" · Ghost" if bool(entry.get("ghost", false)) else "")
	return "%s · %s%s" % [str(entry.get("name", "Character")), str(entry.get("class", "")), state]

func _entry_at(point: Vector2) -> int:
	if point.x < 0 or point.x >= CELL * 10 or point.y < 0 or point.y >= CELL * 4:
		return -1
	var slot: int = int(point.y / CELL) * 10 + int(point.x / CELL)
	return _visible_indices[slot] if slot < _visible_indices.size() else -1
