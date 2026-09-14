class_name ArenicDialogueFrame
extends Control
## Resolution-independent dialogue ornament. Artwork, text and input stay in
## separate nodes; this frame has no timer or gameplay responsibility.
var palette: ArenicArenaTheme
var nameplate_rect: Rect2:
	set(value):
		if nameplate_rect != value:
			nameplate_rect = value
			queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	if palette == null or size.x < 200.0 or size.y < 80.0:
		return
	var border: PackedVector2Array = _chamfer(Rect2(Vector2.ZERO, size), 16.0)
	draw_colored_polygon(border, palette.color("ink"))
	draw_colored_polygon(_chamfer(Rect2(Vector2(4, 4), size - Vector2(8, 8)), 13.0), palette.color("violet"))
	_outline(_chamfer(Rect2(Vector2(7, 7), size - Vector2(14, 14)), 11.0), palette.color("gold"), 1.0)
	draw_colored_polygon(_chamfer(Rect2(Vector2(15, 14), size - Vector2(30, 28)), 7.0), palette.color("paper_edge"))
	draw_colored_polygon(_chamfer(Rect2(Vector2(18, 17), size - Vector2(36, 34)), 5.0), palette.color("paper"))
	# Two small stitch returns at each end form the corner ornament without
	# imposing a raster texture or rounded corners on the dialogue surface.
	for x: float in [29.0, size.x - 29.0]:
		var inward: float = 1.0 if x < size.x * 0.5 else -1.0
		for y: float in [28.0, size.y - 28.0]:
			var vertical: float = 1.0 if y < size.y * 0.5 else -1.0
			var corner := PackedVector2Array([
				Vector2(x, y + 15.0 * vertical), Vector2(x, y),
				Vector2(x + 19.0 * inward, y), Vector2(x + 19.0 * inward, y + 5.0 * vertical)])
			draw_polyline(corner, palette.color("gold"), 1.0, true)
			_diamond(Vector2(x + 7.0 * inward, y + 7.0 * vertical), 3.0, palette.color("gold"))
	# A narrow stitched rail and its eightfold clasp echo the Keeper's costume.
	draw_line(Vector2(69, size.y * 0.5), Vector2(121, size.y * 0.5), palette.color("gold"), 1.0, true)
	_diamond(Vector2(58, size.y * 0.5), 9.0, palette.color("gold"), false)
	_diamond(Vector2(58, size.y * 0.5), 4.0, palette.color("gold"))
	_diamond(Vector2(size.x - 29, size.y * 0.5), 5.0, palette.color("gold"), false)
	# The clipped nameplate sits above the parchment and remains attached to it
	# as the viewport resizes. Labels are ordinary accessible Godot controls.
	var nameplate: Rect2 = nameplate_rect
	draw_colored_polygon(_chamfer(nameplate, 12.0), palette.color("ink"))
	draw_colored_polygon(_chamfer(nameplate.grow(-4.0), 9.0), palette.color("violet"))
	_outline(_chamfer(nameplate.grow(-6.0), 7.0), palette.color("gold"), 1.0)
	draw_line(Vector2(nameplate.position.x + 27.0, nameplate.end.y - 4.0), nameplate.end - Vector2(22, 4), palette.color("gold_light"), 1.0, true)
	var clasp := Vector2(nameplate.position.x - 6.0, nameplate.get_center().y)
	_diamond(clasp, 12.0, palette.color("ink"))
	_diamond(clasp, 8.0, palette.color("gold"), false)
	_diamond(clasp, 3.0, palette.color("gold_light"))


func _diamond(center: Vector2, radius: float, color: Color, filled: bool = true) -> void:
	var points := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)])
	if filled:
		draw_colored_polygon(points, color)
	else:
		_outline(points, color, 1.0)


func _outline(points: PackedVector2Array, color: Color, width: float) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, color, width, true)


static func _chamfer(rect: Rect2, cut: float) -> PackedVector2Array:
	var x: float = rect.position.x
	var y: float = rect.position.y
	var right: float = rect.end.x
	var bottom: float = rect.end.y
	return PackedVector2Array([Vector2(x + cut, y), Vector2(right - cut, y), Vector2(right, y + cut), Vector2(right, bottom - cut), Vector2(right - cut, bottom), Vector2(x + cut, bottom), Vector2(x, bottom - cut), Vector2(x, y + cut)])
