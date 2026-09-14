extends SceneTree
## Derived marker state and camera projection; no game model, renderer or save mutation.

var _checks: int = 0
var _done: bool = false
var _fixture: Node
var _viewport: SubViewport
var _camera: Camera3D
var _anchor: Node3D
var _canvas: Control


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if not _check_definitions():
		return
	_fixture = Node.new()
	root.add_child(_fixture)
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1280, 720)
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_fixture.add_child(_viewport)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = 20.0
	_camera.position = Vector3(0, 0, 10)
	_viewport.add_child(_camera)
	_camera.current = true
	_anchor = Node3D.new()
	_viewport.add_child(_anchor)
	_canvas = Control.new()
	_canvas.position = Vector2(40, 20)
	_canvas.scale = Vector2(1.25, 1.25)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport.add_child(_canvas)
	await process_frame
	# The same marker contract applies to real world anchors of either target kind.
	for target_kind: int in [ArenicInteractionMarkerDefinition.TargetKind.NPC, ArenicInteractionMarkerDefinition.TargetKind.ENVIRONMENT]:
		if not _check_marker(target_kind):
			return
	_finish(0, "Interaction marker checks passed: %d assertions; bounded definitions, shared target states and native camera/canvas culling." % _checks)


func _definition(target_kind: int = ArenicInteractionMarkerDefinition.TargetKind.NPC) -> ArenicInteractionMarkerDefinition:
	var definition := ArenicInteractionMarkerDefinition.new()
	definition.marker_id = "test_marker"
	definition.target_id = "test_anchor"
	definition.display_name = "Interaction marker fixture"
	definition.set("target_kind", target_kind)
	return definition


func _check_definitions() -> bool:
	var definition := _definition()
	if not _check(definition.validation_errors().is_empty(), "A complete marker definition is valid without inventing a quest."):
		return false
	for kind: int in 6:
		definition.set("kind", kind)
		for target_kind: int in 2:
			definition.set("target_kind", target_kind)
			if not _check(definition.validation_errors().is_empty(), "Every authored kind accepts NPC and environment targets."):
				return false
	for property: String in ["marker_id", "target_id"]:
		for value: String in ["", "x".repeat(65)]:
			var candidate := _definition()
			candidate.set(property, value)
			if not _check(not candidate.validation_errors().is_empty(), "Empty and oversized marker identities are rejected: " + property):
				return false
		var maximum := _definition()
		maximum.set(property, "x".repeat(64))
		if not _check(maximum.validation_errors().is_empty(), "An identity at the explicit 64-character limit remains valid."):
			return false
	for value: String in ["", "   ", "x".repeat(97)]:
		var candidate := _definition()
		candidate.display_name = value
		if not _check(not candidate.validation_errors().is_empty(), "Display names must be nonempty and bounded."):
			return false
	var maximum_name := _definition()
	maximum_name.display_name = "x".repeat(96)
	if not _check(maximum_name.validation_errors().is_empty(), "A display name at its 96-character bound is valid."):
		return false
	for offset: float in [8.0, 96.0]:
		var candidate := _definition()
		candidate.head_offset = offset
		if not _check(candidate.validation_errors().is_empty(), "Both inclusive head-offset boundaries are valid."):
			return false
	for offset: float in [7.99, 96.01, NAN, INF, -INF]:
		var candidate := _definition()
		candidate.head_offset = offset
		if not _check(not candidate.validation_errors().is_empty(), "Nonfinite or out-of-range projection offsets are rejected."):
			return false
	for invalid: Array in [["kind", -1], ["kind", 6], ["target_kind", -1], ["target_kind", 2]]:
		var candidate := _definition()
		candidate.set(invalid[0], invalid[1])
		if not _check(not candidate.validation_errors().is_empty(), "Unknown marker or target enum values are rejected."):
			return false
	return true


func _check_marker(target_kind: int) -> bool:
	var marker := ArenicInteractionMarker.new()
	marker.definition = _definition(target_kind)
	_canvas.add_child(marker)
	var other := ArenicInteractionMarker.new()
	other.definition = _definition(target_kind)
	other.set_state(ArenicInteractionMarker.State.ACCEPTED)
	_canvas.add_child(other)
	var symbol := marker.get_node("Symbol") as Label
	var original_font: Font = symbol.get_theme_font("font")
	if not _check(marker.size == Vector2(36, 44) and marker.focus_mode == Control.FOCUS_NONE and marker.text.is_empty() and symbol.mouse_filter == Control.MOUSE_FILTER_IGNORE, "The compact shared symbol owns one transparent pointer target without stealing keyboard focus."):
		return false
	for style: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		if not _check(marker.get_theme_stylebox(style) is StyleBoxEmpty, "Marker state never introduces a native button background: " + style):
			return false
	var full_rect := Rect2(0, 0, 1280, 720)
	var state_names: PackedStringArray = ["hidden", "locked", "available", "accepted", "ready"]
	var glyphs: PackedStringArray = ["", "!", "!", "?", "?"]
	var statuses: PackedStringArray = ["", "Unavailable", "Available", "In progress", "Ready to complete"]
	for value: int in state_names.size():
		marker.set_state(value)
		marker.project_to(_anchor, _camera, full_rect, true, true)
		var snapshot: Dictionary = marker.snapshot()
		if not _check(snapshot.state == state_names[value] and snapshot.kind == "standard" and snapshot.glyph == glyphs[value] and marker.status_text() == statuses[value] and symbol.text == glyphs[value], "Both target kinds expose the same truthful state, symbol and status: " + state_names[value]):
			return false
		if not _check(snapshot.visible == (value != ArenicInteractionMarker.State.HIDDEN) and marker.disabled == (value in [ArenicInteractionMarker.State.HIDDEN, ArenicInteractionMarker.State.LOCKED]), "Hidden/locked states do not accept pointer interaction; derived actionable states do."):
			return false
		if not _check(symbol.get_theme_font("font") == original_font and symbol.get_theme_font_size("font_size") == 40, "Available, accepted, ready and disabled symbols retain the same font geometry."):
			return false
		if value != ArenicInteractionMarker.State.HIDDEN and not _check(marker.tooltip_text.begins_with(marker.definition.display_name + " · " + statuses[value]), "Hover wording exposes the definition and current interaction status."):
			return false
	if not _check_colors(marker, other):
		return false
	marker.set_state(ArenicInteractionMarker.State.AVAILABLE)
	_anchor.position = Vector3.ZERO
	marker.project_to(_anchor, _camera, full_rect, true, true)
	var projected: Vector2 = _camera.unproject_position(_anchor.global_position)
	# Head offset is the authored local gap below the marker. Its bottom-center
	# follows the anchor after converting through the actual parent transform.
	var expected_bottom: Vector2 = projected - _canvas.get_global_transform().y * marker.definition.head_offset
	var actual_rect: Rect2 = marker.get_global_rect()
	if not _check((actual_rect.position + Vector2(actual_rect.size.x * 0.5, actual_rect.size.y)).is_equal_approx(expected_bottom) and actual_rect.size.is_equal_approx(Vector2(45, 55)), "An offset/scaled parent preserves the world anchor and scales the complete marker plus its authored gap."):
		return false
	var snapshot: Dictionary = marker.snapshot()
	if not _check(Vector2(snapshot.center[0], snapshot.center[1]).is_equal_approx(actual_rect.get_center()), "The passive marker snapshot reports its actual global canvas center."):
		return false
	if not _check_culling(marker):
		return false
	_anchor.position = Vector3.ZERO
	marker.project_to(_anchor, _camera, full_rect, true, false)
	if not _check(marker.visible and marker.disabled and marker.mouse_filter == Control.MOUSE_FILTER_IGNORE and not marker.snapshot().actionable, "A present but nonactionable marker remains readable while passing world input through."):
		return false
	marker.set_state(ArenicInteractionMarker.State.READY)
	marker.project_to(_anchor, _camera, full_rect, true, true)
	if not _check(marker.visible and not marker.disabled and marker.mouse_filter == Control.MOUSE_FILTER_STOP and marker.glyph() == "?", "A ready interaction accepts input when its owner says it is actionable."):
		return false
	marker.project_to(_anchor, _camera, full_rect, false, true)
	if not _check(not marker.visible and marker.disabled and marker.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Absent targets remove their pointer hit area."):
		return false
	marker.project_to(null, _camera, full_rect, true, true)
	if not _check(not marker.visible, "A missing world anchor is safely culled."):
		return false
	marker.project_to(_anchor, null, full_rect, true, true)
	if not _check(not marker.visible, "A missing projection camera is safely culled."):
		return false
	_anchor.position = Vector3(0, 0, 12)
	marker.project_to(_anchor, _camera, full_rect, true, true)
	if not _check(not marker.visible and marker.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Targets behind the actual camera cannot leave an interactive screen marker."):
		return false
	_anchor.position = Vector3.ZERO
	marker.definition = null
	marker.project_to(_anchor, _camera, full_rect, true, true)
	if not _check(not marker.visible and marker.disabled, "Removing an authored definition clears the prior visible marker."):
		return false
	marker.free()
	other.free()
	return true


func _check_colors(marker: ArenicInteractionMarker, other: ArenicInteractionMarker) -> bool:
	var palette := ArenicArenaTheme.new()
	palette.palette = {"gold": Vector3(0.9, 0.17, 92), "blue": Vector3(0.73, 0.17, 248), "silver": Vector3(0.67, 0.009, 260), "orange": Vector3(0.77, 0.17, 57), "red": Vector3(0.65, 0.22, 27), "green": Vector3(0.81, 0.2, 141)}
	var tokens: PackedStringArray = ["gold", "gold", "blue", "orange", "red", "green"]
	var names: PackedStringArray = ["standard", "campaign", "repeatable", "special", "urgent", "travel"]
	var other_color: Color = other.marker_color()
	for kind: int in tokens.size():
		marker.definition.set("kind", kind)
		marker.definition.emit_changed()
		for value: int in [ArenicInteractionMarker.State.AVAILABLE, ArenicInteractionMarker.State.READY]:
			marker.set_state(value)
			var symbol := marker.get_node("Symbol") as Label
			if not _check(marker.marker_color().is_equal_approx(palette.color(tokens[kind])) and symbol.get_theme_color("font_color").is_equal_approx(marker.marker_color()) and marker.snapshot().kind == names[kind], "Available/ready symbols project the authored semantic color: " + names[kind]):
				return false
		for value: int in [ArenicInteractionMarker.State.LOCKED, ArenicInteractionMarker.State.ACCEPTED]:
			marker.set_state(value)
			if not _check(marker.marker_color().is_equal_approx(palette.color("silver")), "Locked and in-progress interactions remain gray for every presentation kind."):
				return false
	if not _check(other.state == ArenicInteractionMarker.State.ACCEPTED and other.definition.kind == ArenicInteractionMarkerDefinition.Kind.STANDARD and other.marker_color() == other_color, "Changing one marker's state and authored kind cannot mutate another instance."):
		return false
	return true


func _check_culling(marker: ArenicInteractionMarker) -> bool:
	var world_rect := Rect2(100, 80, 1000, 540)
	var half: Vector2 = marker.get_global_rect().size * 0.5
	var middle: Vector2 = world_rect.get_center()
	var gap: Vector2 = _canvas.get_global_transform().y * (marker.definition.head_offset + marker.size.y * 0.5)
	# On all four boundaries, one pixel inside is visible and one pixel beyond
	# is culled. Testing the whole rectangle catches offscreen hit areas.
	for edge: int in 4:
		for inside: bool in [true, false]:
			var inset: float = 1.0 if inside else -1.0
			var center: Vector2 = middle
			match edge:
				0: center.x = world_rect.position.x + half.x + inset
				1: center.x = world_rect.end.x - half.x - inset
				2: center.y = world_rect.position.y + half.y + inset
				3: center.y = world_rect.end.y - half.y - inset
			_anchor.global_position = _camera.project_position(center + gap, 10.0)
			marker.project_to(_anchor, _camera, world_rect, true, true)
			if not _check(marker.visible == inside and marker.disabled == (not inside) and marker.snapshot().actionable == inside and (marker.mouse_filter == Control.MOUSE_FILTER_STOP) == inside, "Full marker bounds control drawing, actionability and pointer capture at edge %d." % edge):
				return false
	return true


func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_finish(1, "Interaction marker assertion failed: " + message)
	return condition


func _finish(code: int, message: String) -> void:
	if _done:
		return
	_done = true
	if is_instance_valid(_fixture):
		_fixture.free()
	print(message)
	quit(code)
