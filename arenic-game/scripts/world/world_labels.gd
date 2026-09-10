class_name ArenicWorldLabels
extends Control
## UI anchors are projected from the same world bounds used by camera fitting/picking.
const DISPLAY_FONT: Font = preload("res://assets/fonts/PPMigra-Extrabold.ttf")
const BODY_FONT: Font = preload("res://assets/fonts/Barlow-Regular.ttf")
var world: ArenicWorldDefinition
var rig: ArenicCameraRig
var selected_index: int = 0
var clip_rectangle := Rect2()
var _cards: Array[Control] = []
var _selection_style: StyleBoxFlat

func configure(definition: ArenicWorldDefinition, camera_rig: ArenicCameraRig) -> void:
	world = definition
	rig = camera_rig
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_style = StyleBoxFlat.new()
	_selection_style.bg_color = Color(1, 1, 1, 0)
	_selection_style.border_color = Color(0.12, 0.12, 0.12)
	_selection_style.set_border_width_all(1)
	_selection_style.set_corner_radius_all(24)
	for arena in world.arenas:
		var card := Control.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(card)
		_cards.append(card)
		_label(card, arena.class_label, BODY_FONT, 16, 0.0, 25.0)
		_label(card, arena.display_name, DISPLAY_FONT, 48, 20.0, 62.0)
		var badge := _label(card, arena.hotkey, BODY_FONT, 16, 84.0, 23.0)
		badge.name = "Hotkey"
		badge.add_theme_color_override("font_color", Color(0.16, 0.42, 0.88))
		var style := StyleBoxFlat.new()
		style.bg_color = Color.WHITE
		style.border_color = Color(0.16, 0.16, 0.16)
		style.set_border_width_all(1)
		style.set_corner_radius_all(7)
		badge.add_theme_stylebox_override("normal", style)

func _label(parent: Control, text_value: String, font: Font, font_size: int, top: float, height: float) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = Vector2(0, top)
	label.size = Vector2(400, height)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.16, 0.16, 0.16))
	parent.add_child(label)
	return label

func _process(_delta: float) -> void:
	if rig == null or world == null:
		return
	var overview_alpha := clampf(inverse_lerp(22.0, 44.0, rig.view_span.x), 0.0, 1.0)
	for index in _cards.size():
		var arena := world.arenas[index]
		var center := ArenicGridMath.arena_center(arena.grid_slot)
		var rectangle := _projected_rect(ArenicGridMath.arena_rect(arena.grid_slot))
		var card := _cards[index]
		if not rectangle.has_area():
			card.visible = false
			continue
		var width := rectangle.size.x
		card.position = rig.world_to_screen(center) - Vector2(width * 0.5, 50)
		card.size = Vector2(width, 110)
		card.modulate.a = overview_alpha
		card.visible = rectangle.intersects(clip_rectangle) and overview_alpha > 0.01
		for child in card.get_children():
			var label := child as Label
			if label.name == "Hotkey":
				label.position.x = (width - 27.0) * 0.5
				label.size.x = 27.0
			else:
				label.size.x = width
				if label.get_theme_font("font") == DISPLAY_FONT:
					label.add_theme_font_size_override("font_size", mini(48, floori(width / 8.4)))
	queue_redraw()

func _projected_rect(bounds: Rect2) -> Rect2:
	var points := PackedVector2Array()
	for corner: Vector2 in [bounds.position, bounds.end, Vector2(bounds.position.x, bounds.end.y), Vector2(bounds.end.x, bounds.position.y)]:
		var point := rig.world_to_screen(Vector3(corner.x, 0, corner.y))
		if not point.is_finite():
			return Rect2()
		points.append(point)
	var rectangle := Rect2(points[0], Vector2.ZERO)
	for point in points:
		rectangle = rectangle.expand(point)
	return rectangle

func _draw() -> void:
	if rig == null or world == null or selected_index < 0:
		return
	if rig.view_span.x <= ArenicGridMath.ARENA_WIDTH + 0.01:
		return # Keep the native tile canvas unobstructed in arena view.
	var selected := _projected_rect(ArenicGridMath.arena_rect(world.arenas[selected_index].grid_slot))
	if selected.has_area():
		draw_style_box(_selection_style, selected.grow(-4))
	var bounds := ArenicGridMath.world_rect()
	for column: int in [1, 2]:
		var x := bounds.position.x + column * ArenicGridMath.ARENA_WIDTH
		var start := rig.world_to_screen(Vector3(x, 0, bounds.position.y))
		var end := rig.world_to_screen(Vector3(x, 0, bounds.end.y))
		if not start.is_finite() or not end.is_finite():
			continue
		draw_dashed_line(start, end, Color(0.4, 0.4, 0.4, 0.55), 1.0, 2.0)
