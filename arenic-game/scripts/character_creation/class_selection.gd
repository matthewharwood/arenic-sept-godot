extends Control

signal class_confirmed(definition: ArenicClassDefinition)

const GRID_ROWS := 14
const GRID_COLUMNS := 12
const GRID_MARGIN := 32.0
const GRID_GUTTER := 12.0
const REFERENCE_SIZE := Vector2i(1280, 768)
const TITLE_SCENE := "res://scenes/title/title_scene.tscn"

@export var catalog: ArenicClassCatalog
## Class confirmation stores RunSetup before opening this application scene.
@export var next_scene: PackedScene

var selected_index := 0
var confirmed_class_id := ""
var _cards: Array[ArenicClassCard] = []
var _portrait_tween: Tween

@onready var _portrait: TextureRect = %Portrait
@onready var _skill_heading: Label = %SkillHeading
@onready var _skill_body: RichTextLabel = %SkillBody
@onready var _character_name: Label = %CharacterName
@onready var _confirm: Button = %Confirm
@onready var _back: Button = %Back
@onready var _status: Label = %SelectionStatus


func _ready() -> void:
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	get_window().content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	get_window().content_scale_size = REFERENCE_SIZE
	for child in $Cards.get_children():
		if child is ArenicClassCard:
			_cards.append(child)
	if catalog == null or catalog.classes.is_empty() or catalog.classes.size() > _cards.size():
		push_error("Class selection needs a valid catalog fitting the eight-card grid.")
		_confirm.disabled = true
		return
	for index in _cards.size():
		var card := _cards[index]
		card.visible = index < catalog.classes.size()
		if not card.visible:
			continue
		card.definition = catalog.classes[index]
		card.pressed.connect(_select_class.bind(index))
		card.focus_entered.connect(_select_class.bind(index))
		_wire_card_focus(index)
	_confirm.pressed.connect(_confirm_class)
	_back.pressed.connect(_return_to_title)
	var last_card := _cards[catalog.classes.size() - 1]
	_confirm.focus_neighbor_left = _confirm.get_path_to(last_card)
	_confirm.focus_neighbor_top = _confirm.get_path_to(last_card)
	_confirm.focus_next = _confirm.get_path_to(_back)
	_confirm.focus_previous = _confirm.get_path_to(last_card)
	_back.focus_next = _back.get_path_to(_cards.front())
	_back.focus_previous = _back.get_path_to(_confirm)
	resized.connect(_layout_grid)
	_select_class(0, false)
	_layout_grid.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_return_to_title()
	elif get_viewport().gui_get_focus_owner() == null and (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right")):
		_cards[selected_index].grab_focus()
		get_viewport().set_input_as_handled()


func grid_rect(column: int, row: int, columns: int, rows: int) -> Rect2:
	var usable := size - Vector2.ONE * (GRID_MARGIN * 2.0)
	var cell := (usable - Vector2(GRID_COLUMNS - 1, GRID_ROWS - 1) * GRID_GUTTER) / Vector2(GRID_COLUMNS, GRID_ROWS)
	return Rect2(Vector2.ONE * GRID_MARGIN + Vector2(column, row) * (cell + Vector2.ONE * GRID_GUTTER), Vector2(columns, rows) * cell + Vector2(columns - 1, rows - 1) * GRID_GUTTER)


func _place(control: Control, rectangle: Rect2) -> void:
	control.position = rectangle.position
	control.size = rectangle.size


func _layout_grid() -> void:
	if not is_node_ready() or _cards.is_empty():
		return
	var heading_rect := grid_rect(0, 0, 7, 2)
	# Align the visible Migra capitals with the 32-pixel margin.
	heading_rect.position.y -= 8.0
	_place($Heading, heading_rect)
	for index in _cards.size():
		_place(_cards[index], grid_rect((index % 2) * 2, 2 + floori(index / 2.0) * 3, 2, 3))
	_place($Information, grid_rect(8, 2, 4, 4))
	var center := grid_rect(4, 0, 4, GRID_ROWS)
	_place($Nameplate, Rect2(Vector2(center.position.x, size.y - GRID_MARGIN - 58.0), Vector2(center.size.x, 58.0)))
	var confirm_area := grid_rect(10, 13, 2, 1)
	_place(_confirm, Rect2(Vector2(confirm_area.position.x, size.y - GRID_MARGIN - 58.0), Vector2(confirm_area.size.x, 58.0)))
	_place(_status, Rect2(Vector2(grid_rect(8, 0, 4, 1).position.x, size.y - GRID_MARGIN - 98.0), Vector2(grid_rect(8, 0, 4, 1).size.x, 28.0)))
	_place(_back, Rect2(Vector2(size.x - GRID_MARGIN - 104.0, GRID_MARGIN), Vector2(104.0, 40.0)))
	var definition := catalog.classes[selected_index]
	var portrait_height := (size.y - 20.0) * definition.portrait_height
	var portrait_width := minf(580.0, center.size.x + 110.0)
	var texture_size := definition.portrait.get_size() if definition.portrait != null else Vector2(2.0, 3.0)
	var art_scale := minf(portrait_width / texture_size.x, portrait_height / texture_size.y)
	var art_size := texture_size * art_scale
	var art_rect := Rect2(Vector2(center.get_center().x - art_size.x * 0.5, size.y - art_size.y), art_size)
	art_rect.position += definition.portrait_offset
	_place(_portrait, art_rect)


func _wire_card_focus(index: int) -> void:
	var card := _cards[index]
	var count := catalog.classes.size()
	var horizontal := index + (1 if index % 2 == 0 else -1)
	card.focus_neighbor_left = card.get_path_to(_cards[clampi(horizontal, 0, count - 1)])
	card.focus_neighbor_right = card.focus_neighbor_left
	card.focus_neighbor_top = card.get_path_to(_cards[maxi(index - 2, index % 2)])
	card.focus_neighbor_bottom = card.get_path_to(_cards[index + 2] if index + 2 < count else _confirm)
	card.focus_next = card.get_path_to(_cards[index + 1] if index + 1 < count else _confirm)
	card.focus_previous = card.get_path_to(_cards[index - 1] if index > 0 else _back)


func _select_class(index: int, animate: bool = true) -> void:
	if index < 0 or index >= catalog.classes.size():
		return
	var changed := selected_index != index
	selected_index = index
	var definition := catalog.classes[index]
	for card_index in _cards.size():
		_cards[card_index].set_pressed_no_signal(card_index == index)
		_cards[card_index]._update_tint(card_index == index)
	_portrait.texture = definition.portrait
	_character_name.text = definition.character_name
	_skill_heading.text = "%s Skills" % definition.display_name
	var paragraphs := PackedStringArray()
	for skill in definition.skills:
		paragraphs.append("[b]%s:[/b] %s" % [_plain_text(skill.title), _plain_text(skill.description)])
	_skill_body.text = "\n\n".join(paragraphs)
	_skill_body.scroll_to_line(0)
	_confirm.disabled = confirmed_class_id == definition.class_id
	_confirm.text = "Selected" if _confirm.disabled else "Start"
	_status.text = "%s selected." % definition.character_name if _confirm.disabled else ""
	_layout_grid()
	if changed and animate:
		if _portrait_tween != null:
			_portrait_tween.kill()
		_portrait.modulate.a = 0.75
		_portrait_tween = create_tween()
		_portrait_tween.tween_property(_portrait, "modulate:a", 1.0, 0.12)


func _plain_text(value: String) -> String:
	return value.replace("[", "[lb]")


func _confirm_class() -> void:
	if not confirmed_class_id.is_empty() and confirmed_class_id == catalog.classes[selected_index].class_id:
		return
	var definition := catalog.classes[selected_index]
	RunSetup.choose_class(definition)
	confirmed_class_id = definition.class_id
	class_confirmed.emit(definition)
	if not is_inside_tree():
		return
	if next_scene != null:
		var error := get_tree().change_scene_to_packed(next_scene)
		if error == OK:
			return
		push_error("Could not open the next scene: %s" % error_string(error))
	_select_class(selected_index, false)


func _return_to_title() -> void:
	var error := get_tree().change_scene_to_file(TITLE_SCENE)
	if error != OK:
		push_error("Could not return to the title: %s" % error_string(error))
