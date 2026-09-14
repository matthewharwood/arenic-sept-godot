class_name ArenicInteractionMarker
extends Button
## A transient, camera-projected interaction affordance. The owner validates and
## handles pressed; drawing or clicking a marker never advances quest state.
enum State { HIDDEN, LOCKED, AVAILABLE, ACCEPTED, READY }
const Kind = ArenicInteractionMarkerDefinition.Kind
const FONT: Font = preload("res://assets/fonts/Rajdhani-Bold.ttf")
const MARKER_SIZE: Vector2 = Vector2(36, 44)
var definition: ArenicInteractionMarkerDefinition:
	set(value):
		if definition != null and definition.changed.is_connected(_refresh):
			definition.changed.disconnect(_refresh)
		definition = value
		if definition != null:
			definition.changed.connect(_refresh)
		_refresh()
var state: State = State.HIDDEN
var _glyph: Label
var _palette := ArenicArenaTheme.new()

func _ready() -> void:
	custom_minimum_size = MARKER_SIZE
	size = MARKER_SIZE
	focus_mode = Control.FOCUS_NONE
	for style: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(style, StyleBoxEmpty.new())
	_palette.palette = {"gold": Vector3(0.9, 0.17, 92), "blue": Vector3(0.73, 0.17, 248), "silver": Vector3(0.67, 0.009, 260), "orange": Vector3(0.77, 0.17, 57), "red": Vector3(0.65, 0.22, 27), "green": Vector3(0.81, 0.2, 141), "outline": Vector3(0.19, 0.017, 74), "crest": Vector3(0.36, 0.063, 67)}
	_glyph = Label.new()
	_glyph.name = "Symbol"
	_glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glyph.add_theme_font_override("font", FONT)
	_glyph.add_theme_font_size_override("font_size", 40)
	_glyph.add_theme_constant_override("outline_size", 4)
	_glyph.add_theme_color_override("font_outline_color", _palette.color("outline"))
	add_child(_glyph)
	_refresh()

func set_state(value: State) -> void:
	if state != value:
		state = value
		_refresh()

func glyph() -> String:
	match state:
		State.LOCKED, State.AVAILABLE: return "!"
		State.ACCEPTED, State.READY: return "?"
	return ""

func status_text() -> String:
	match state:
		State.LOCKED: return "Unavailable"
		State.AVAILABLE: return "Available"
		State.ACCEPTED: return "In progress"
		State.READY: return "Ready to complete"
	return ""

func marker_color() -> Color:
	var token: String = "gold"
	if state in [State.LOCKED, State.ACCEPTED]:
		token = "silver"
	elif definition != null:
		match definition.kind:
			Kind.REPEATABLE: token = "blue"
			Kind.SPECIAL: token = "orange"
			Kind.URGENT: token = "red"
			Kind.TRAVEL: token = "green"
	return _palette.color(token)

func _refresh() -> void:
	if not is_node_ready():
		return
	_glyph.text = glyph()
	_glyph.add_theme_color_override("font_color", marker_color())
	if state == State.HIDDEN or definition == null:
		visible = false
	tooltip_text = "%s · %s" % [definition.display_name, status_text()] if definition != null else ""
	queue_redraw()

func _draw() -> void:
	if definition == null or not definition.campaign_frame or definition.kind != Kind.CAMPAIGN or state == State.HIDDEN:
		return
	var crest := PackedVector2Array([Vector2(3, 5), Vector2(33, 5), Vector2(32, 31), Vector2(18, 42), Vector2(4, 31)])
	draw_colored_polygon(crest, _palette.color("crest"))
	crest.append(crest[0])
	draw_polyline(crest, _palette.color("outline"), 2.0, true)

## world_rect uses viewport canvas coordinates, as supplied by the HUD. Convert
## projected screen coordinates to our parent's canvas before placing the view.
## Cull rather than pinning a remote marker onto an unrelated screen edge.
func project_to(anchor: Node3D, camera: Camera3D, world_rect: Rect2, present: bool, actionable: bool) -> void:
	if not present or state == State.HIDDEN or definition == null or not is_instance_valid(anchor) or not is_instance_valid(camera):
		_hide_marker()
		return
	if camera.is_position_behind(anchor.global_position):
		_hide_marker()
		return
	var projected: Vector2 = camera.unproject_position(anchor.global_position)
	var parent_canvas: Transform2D = get_global_transform() * get_transform().affine_inverse()
	position = parent_canvas.affine_inverse() * projected - Vector2(size.x * 0.5, definition.head_offset + size.y)
	visible = world_rect.encloses(get_global_rect())
	disabled = not visible or not actionable or state == State.LOCKED
	mouse_filter = Control.MOUSE_FILTER_STOP if visible and not disabled else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not disabled else Control.CURSOR_ARROW
	tooltip_text = "%s · %s%s" % [definition.display_name, status_text(), " · Space or click" if not disabled else ""]

func _hide_marker() -> void:
	visible = false
	disabled = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func snapshot() -> Dictionary:
	var center: Vector2 = get_global_rect().get_center()
	return {"state": State.keys()[state].to_lower(), "kind": Kind.keys()[definition.kind].to_lower() if definition != null else "", "glyph": glyph(), "visible": is_visible_in_tree(), "actionable": not disabled, "center": [center.x, center.y]}
