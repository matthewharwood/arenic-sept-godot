class_name ArenicWorldLabels
extends Control
## Palette-tinted titles. Static views reuse measured text and projected layout.

const DISPLAY_FONT: Font = preload("res://assets/fonts/PPMigra-Extrabold.ttf")
const BODY_FONT: Font = preload("res://assets/fonts/Barlow-Regular.ttf")
const CARD_HEIGHT: float = 116.0

var world: ArenicWorldDefinition
var rig: ArenicCameraRig
var selected_index: int = 0:
	set(value):
		if selected_index == value:
			return
		selected_index = value
		queue_redraw()
var clip_rectangle := Rect2():
	set(value):
		if clip_rectangle == value:
			return
		clip_rectangle = value
		_layout_dirty = true
var _cards: Array[Control] = []
var _titles: Array[Label] = []
var _classes: Array[Label] = []
var _keys: Array[Label] = []
var _backplates: Array[TextureRect] = []
var _natural_widths: PackedFloat32Array = []
var _layout_widths: PackedFloat32Array = []
var _font_sizes: PackedInt32Array = []
var _projected_bounds: Array[Rect2] = []
var _camera: Camera3D
var _layout_dirty: bool = true
var _overview_visible: bool = false
var _cached_focus: Vector3
var _cached_span: Vector2
var _cached_camera_transform: Transform3D
var _cached_camera_size: float = -1.0
var _cached_viewport_size: Vector2


func configure(definition: ArenicWorldDefinition, camera_rig: ArenicCameraRig) -> void:
	for card: Control in _cards:
		card.free()
	_cards.clear()
	_titles.clear()
	_classes.clear()
	_keys.clear()
	_backplates.clear()
	_natural_widths.clear()
	_layout_widths.clear()
	_font_sizes.clear()
	_projected_bounds.clear()
	world = definition
	rig = camera_rig
	_camera = rig.get_node_or_null("Camera3D") as Camera3D
	_layout_dirty = true
	_overview_visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for arena: ArenicArenaDefinition in world.arenas:
		var card := Control.new()
		card.name = arena.arena_id.to_pascal_case() + "Label"
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.visible = false
		add_child(card)
		_cards.append(card)
		_projected_bounds.append(Rect2())
		_natural_widths.append(DISPLAY_FONT.get_string_size(arena.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x)
		_layout_widths.append(-1.0)
		_font_sizes.append(38)
		_backplates.append(_backplate(card, arena.visual_theme))
		var class_label := _label(card, "ClassName", arena.class_label.to_upper(), BODY_FONT, 13)
		class_label.add_theme_color_override("font_color", _color(arena.visual_theme, "primary"))
		_classes.append(class_label)
		var title := _label(card, "ArenaName", arena.display_name, DISPLAY_FONT, 38)
		title.add_theme_color_override("font_color", title_ink(arena.visual_theme))
		title.add_theme_color_override("font_shadow_color", _color(arena.visual_theme, "base_300", 0.68))
		title.add_theme_constant_override("shadow_offset_x", 0)
		title.add_theme_constant_override("shadow_offset_y", 1)
		_titles.append(title)
		var key := _label(card, "Hotkey", arena.hotkey, BODY_FONT, 14)
		key.add_theme_color_override("font_color", _color(arena.visual_theme, "primary_content"))
		var key_style := StyleBoxFlat.new()
		key_style.bg_color = _color(arena.visual_theme, "primary")
		key_style.set_corner_radius_all(0)
		key.add_theme_stylebox_override("normal", key_style)
		_keys.append(key)


## Keep the palette's hue dominant; small sRGB token mixes soften neon extremes.
## Casino consequently reads as warm Rose Pine gold rather than near-white text.
static func title_ink(visual_theme: ArenicArenaTheme) -> Color:
	if visual_theme == null:
		return Color.WHITE
	return visual_theme.color("primary").lerp(visual_theme.color("base_content"), 0.14).lerp(visual_theme.color("secondary"), 0.08)


func _process(_delta: float) -> void:
	if rig == null or world == null or _camera == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if not _layout_dirty and rig.focus_world == _cached_focus and rig.view_span == _cached_span \
			and _camera.global_transform == _cached_camera_transform \
			and _camera.size == _cached_camera_size and viewport_size == _cached_viewport_size:
		return
	var overview_alpha: float = _overview_alpha()
	if overview_alpha <= 0.01:
		if _overview_visible:
			for card: Control in _cards:
				card.visible = false
			_overview_visible = false
			queue_redraw()
		_remember_projection(viewport_size)
		return
	_overview_visible = true
	for index: int in range(_cards.size()):
		var arena: ArenicArenaDefinition = world.arenas[index]
		var rectangle: Rect2 = _projected_rect(ArenicGridMath.arena_rect(arena.grid_slot))
		_projected_bounds[index] = rectangle
		var card: Control = _cards[index]
		if not rectangle.has_area():
			card.visible = false
			continue
		var width: float = floorf(minf(340.0, maxf(0.0, rectangle.size.x - 28.0)))
		if width != _layout_widths[index]:
			_layout_card(index, width)
		# Orthographic projection preserves the center of these world rectangles.
		var position_on_screen: Vector2 = (rectangle.get_center() - card.size * 0.5).round()
		if card.position != position_on_screen:
			card.position = position_on_screen
		if card.modulate.a != overview_alpha:
			card.modulate.a = overview_alpha
		card.visible = width > 0.0 and clip_rectangle.encloses(Rect2(card.position, card.size))
	_remember_projection(viewport_size)
	queue_redraw()


func _layout_card(index: int, width: float) -> void:
	_layout_widths[index] = width
	_cards[index].size = Vector2(width, CARD_HEIGHT)
	_backplates[index].size = _cards[index].size
	_classes[index].position = Vector2(0.0, 12.0)
	_classes[index].size = Vector2(width, 19.0)
	_titles[index].position = Vector2(12.0, 31.0)
	_titles[index].size = Vector2(maxf(0.0, width - 24.0), 49.0)
	var font_size: int = clampi(floori(38.0 * minf(1.0, (width - 30.0) / maxf(_natural_widths[index], 1.0))), 20, 38)
	if font_size != _font_sizes[index]:
		_font_sizes[index] = font_size
		_titles[index].add_theme_font_size_override("font_size", font_size)
	_keys[index].position = Vector2(floorf((width - 28.0) * 0.5), 86.0)
	_keys[index].size = Vector2(28.0, 24.0)


func _remember_projection(viewport_size: Vector2) -> void:
	_layout_dirty = false
	_cached_focus = rig.focus_world
	_cached_span = rig.view_span
	_cached_camera_transform = _camera.global_transform
	_cached_camera_size = _camera.size
	_cached_viewport_size = viewport_size


func _overview_alpha() -> float:
	return clampf(inverse_lerp(22.0, 44.0, rig.view_span.x), 0.0, 1.0)


func _projected_rect(bounds: Rect2) -> Rect2:
	var points := PackedVector2Array()
	for corner: Vector2 in [bounds.position, bounds.end, Vector2(bounds.position.x, bounds.end.y), Vector2(bounds.end.x, bounds.position.y)]:
		var point: Vector2 = rig.world_to_screen(Vector3(corner.x, 0.0, corner.y))
		if not point.is_finite():
			return Rect2()
		points.append(point)
	var rectangle := Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		rectangle = rectangle.expand(point)
	return rectangle


func _draw() -> void:
	if rig == null or world == null or not _overview_visible or selected_index < 0 or selected_index >= _projected_bounds.size():
		return
	var alpha: float = _overview_alpha()
	if alpha <= 0.01:
		return # Leave the native tile canvas clear in arena view.
	var arena: ArenicArenaDefinition = world.arenas[selected_index]
	# Selection belongs to the destination label, never a rectangular arena frame.
	var card: Control = _cards[selected_index]
	if not card.visible:
		return
	var center := card.position + Vector2(card.size.x * 0.5, 116.0)
	var accent: Color = _color(arena.visual_theme, "primary", alpha * 0.85)
	draw_line(center - Vector2(18.0, 0.0), center + Vector2(18.0, 0.0), accent, 2.0, true)
	draw_circle(center - Vector2(18.0, 0.0), 1.0, accent)
	draw_circle(center + Vector2(18.0, 0.0), 1.0, accent)

func _label(parent: Control, node_name: String, text_value: String, font: Font, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _backplate(parent: Control, visual_theme: ArenicArenaTheme) -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([
		_color(visual_theme, "base_100", 0.82),
		_color(visual_theme, "base_100", 0.48),
		_color(visual_theme, "base_100", 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.width = 512
	texture.height = 192
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var plate := TextureRect.new()
	plate.name = "SoftBackplate"
	plate.texture = texture
	plate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	plate.stretch_mode = TextureRect.STRETCH_SCALE
	plate.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(plate)
	return plate


func _color(visual_theme: ArenicArenaTheme, token: String, alpha: float = 1.0) -> Color:
	if visual_theme != null:
		return visual_theme.color(token, alpha)
	var value: float = 1.0 if token in ["base_content", "primary"] else 0.0
	return Color(value, value, value, alpha)
