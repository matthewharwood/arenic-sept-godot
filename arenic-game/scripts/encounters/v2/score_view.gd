class_name ArenicScoreView
extends Node3D
## A bounded set of exact rectangle meshes, with non-color identity cues. These
## are derived warnings, never collisions. Rebuild geometry only at cue changes.
const WARNING_SHADER: Shader = preload("res://shaders/encounters/mask_warning.gdshader")
const FONT: Font = preload("res://assets/fonts/Barlow-Regular.ttf")
const SUN: Color = Color(1.0, 0.77, 0.25)
const MOON: Color = Color(0.57, 0.74, 1.0)
const PHYSICAL: Color = Color(1.0, 0.40, 0.40)
var _score: ArenicMaskScore
var _signature: String = ""
var _warnings: Node3D
var _materials: Array[Dictionary] = []
var _labels: Array[Dictionary] = []

func configure(score: ArenicMaskScore) -> void:
	if score == _score:
		return
	_score = score
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_warnings = Node3D.new()
	add_child(_warnings)
	_signature = ""
	if score == null:
		return
	# Ordinary aisle ornament is deliberately faint and does not use hazard ink.
	for x: int in [28, 36]:
		var lane := ArenicGroundOverlay.new()
		add_child(lane)
		lane.set_elevation(1)
		var cells := PackedInt32Array()
		var colors := PackedColorArray()
		for y: int in range(5, 27):
			for dx: int in 2:
				cells.append(ArenicDigField.index_of(Vector2i(x + dx, y)))
				colors.append(Color(0.80, 0.82, 0.74, 0.10))
		lane.set_cells(cells, colors)
	for element: String in ["sun", "moon"]:
		var cell: Vector2i = score.sun_font if element == "sun" else score.moon_font
		var marker := ArenicGroundOverlay.new()
		add_child(marker)
		marker.set_elevation(3)
		marker.set_cells(PackedInt32Array([ArenicDigField.index_of(cell)]), PackedColorArray([SUN if element == "sun" else MOON]))
		_label(self, "[+] SUN" if element == "sun" else "[o] MOON", Vector2(cell) + Vector2(0, 1.2), SUN if element == "sun" else MOON, 14)

func sync(tick: int) -> void:
	if _score == null:
		return
	var events: Array[ArenicScoreEvent] = _score.visible_events(tick)
	var keys: PackedStringArray = []
	for event: ArenicScoreEvent in events:
		keys.append(event.event_id + (":warn" if tick < event.at_tick else ":hit"))
	var signature: String = "/".join(keys)
	if signature != _signature:
		_signature = signature
		_rebuild(events, tick)
	for item: Dictionary in _materials:
		var event: ArenicScoreEvent = item.event
		item.material.set_shader_parameter("urgency", clampf(float(tick - event.cue_tick) / maxi(1, event.at_tick - event.cue_tick), 0.0, 1.0))
	for item: Dictionary in _labels:
		var event: ArenicScoreEvent = item.event
		item.label.text = "%s  %.1fs" % [item.caption, float(maxi(0, event.at_tick - tick)) / 60.0]

func _rebuild(events: Array[ArenicScoreEvent], tick: int) -> void:
	for child: Node in _warnings.get_children():
		_warnings.remove_child(child)
		child.queue_free()
	_materials.clear()
	_labels.clear()
	for event: ArenicScoreEvent in events:
		if event.kind == "window":
			if tick < event.at_tick:
				var old: ArenicEncounterBeat = _score.beats[_score.index_at(event.at_tick - 1)]
				_rectangle(Rect2i(old.boss_origin_cell, Vector2i(6, 6)), PHYSICAL, 2, event, "TURN / TRANSFER")
				if old.boss_origin_cell != event.boss_origin:
					_rectangle(Rect2i(event.boss_origin, Vector2i(6, 6)), PHYSICAL, 2, event, "ARRIVAL / CRUSH")
			continue
		for index: int in event.masks.size():
			var element: String = event.mask_elements[index] if not event.mask_elements.is_empty() else ""
			var tint: Color = SUN if element == "sun" else MOON if element == "moon" else PHYSICAL
			var motif: int = 0 if element == "sun" else 1 if element == "moon" else 3 if "projectile" in event.tags else 2
			var caption: String = ("[+] " if element == "sun" else "[o] " if element == "moon" else "[!] ") + event.display_name
			if not element.is_empty():
				caption += " / " + element.to_upper()
			_rectangle(event.masks[index], tint, motif, event, caption)

func _rectangle(mask: Rect2i, tint: Color, motif: int, event: ArenicScoreEvent, caption: String) -> void:
	var material := ShaderMaterial.new()
	material.shader = WARNING_SHADER
	material.render_priority = -3
	material.set_shader_parameter("ink", tint)
	material.set_shader_parameter("cells", Vector2(mask.size))
	material.set_shader_parameter("motif", motif)
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(mask.size) * ArenicGridMath.TILE_SIZE
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var center: Vector2 = Vector2(mask.position) + Vector2(mask.size - Vector2i.ONE) * 0.5
	instance.position = ArenicArenaTiles.tile_point(center) + Vector3(0, 0.009, 0)
	_warnings.add_child(instance)
	_materials.append({"material": material, "event": event})
	var label: Label3D = _label(_warnings, caption, Vector2(center.x, mask.end.y - 1), tint, 12)
	_labels.append({"label": label, "event": event, "caption": caption})

func _label(parent: Node, caption: String, cell: Vector2, tint: Color, font_size: int) -> Label3D:
	var label := Label3D.new()
	label.text = caption
	label.font = FONT
	label.font_size = font_size
	label.pixel_size = ArenicGridMath.TILE_SIZE / 19.0
	label.modulate = tint
	label.outline_modulate = Color(0.02, 0.025, 0.04)
	label.outline_size = 4
	label.rotation.x = -PI * 0.5
	label.position = ArenicArenaTiles.tile_point(cell) + Vector3(0, 0.016, 0)
	label.no_depth_test = true
	label.render_priority = 2
	parent.add_child(label)
	return label
