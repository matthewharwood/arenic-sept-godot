extends SceneTree
## Headless geometry/native-camera checks; no rendering or project data.
## Tween.custom_step exercises completion/cancellation without timing assumptions.

const Rig = preload("res://scripts/world/camera_rig.gd")
const EPSILON: float = 0.002
const ARENA: Rect2 = Rect2(-0.125, -7.625, 16.5, 7.75)
const WORLD: Rect2 = Rect2(-0.125, -7.625, 49.5, 23.25)


func _init() -> void:
	_watchdog.call_deferred()
	var native_viewport: Vector2 = Vector2(1280.0, 720.0)
	var native_rect: Rect2 = _safe_rect(native_viewport)
	var native_size: float = Rig.fit_size(ARENA.size, native_viewport, native_rect)
	assert(absf(0.25 * native_viewport.y / native_size - 19.0) < EPSILON)
	assert(absf(native_size - 9.473684210526315) < EPSILON)
	for viewport_size: Vector2 in [
		native_viewport, Vector2(1920.0, 1080.0), Vector2(1024.0, 768.0),
		Vector2(720.0, 1280.0), Vector2(2560.0, 1080.0), Vector2(640.0, 360.0)
	]:
		for bounds: Rect2 in [ARENA, WORLD, Rect2(32.875, 7.875, 16.5, 7.75)]:
			_check_frame(bounds, viewport_size)
	_check_rotated_round_trip()
	_check_sequence_ownership()
	_check_native_camera.call_deferred()


func _safe_rect(viewport_size: Vector2) -> Rect2:
	return Rect2(Vector2(13.0, 35.0), viewport_size - Vector2(26.0, 131.0))


func _check_frame(bounds: Rect2, viewport_size: Vector2) -> void:
	var rect: Rect2 = _safe_rect(viewport_size)
	var center: Vector2 = bounds.get_center()
	var focus: Vector3 = Vector3(center.x, 0.0, center.y)
	var axes: Basis = Basis(Vector3.RIGHT, -PI * 0.5)
	var size: float = Rig.fit_size(bounds.size, viewport_size, rect)
	var pivot: Vector3 = Rig.fit_position(focus, axes, viewport_size, rect, size)
	var camera: Transform3D = Transform3D(axes, pivot + axes.z * 60.0)
	var projection: Projection = _projection(size, viewport_size)
	var screen_center: Vector2 = _project(focus, camera, projection, viewport_size)
	assert(screen_center.distance_to(rect.get_center()) < EPSILON)
	for corner: Vector2 in [
		bounds.position, bounds.end,
		Vector2(bounds.position.x, bounds.end.y), Vector2(bounds.end.x, bounds.position.y)
	]:
		var point: Vector3 = Vector3(corner.x, 0.0, corner.y)
		var screen: Vector2 = _project(point, camera, projection, viewport_size)
		assert(rect.grow(EPSILON).has_point(screen), "A world corner escaped the HUD interior.")
		assert(_unproject_floor(screen, camera, projection, viewport_size).distance_to(point) < EPSILON)
	var projected_tile: Vector2 = _project(focus + Vector3(0.25, 0.0, 0.0), camera, projection, viewport_size)
	assert(absf(projected_tile.distance_to(screen_center) - 0.25 * viewport_size.y / size) < EPSILON)


func _check_rotated_round_trip() -> void:
	var viewport_size: Vector2 = Vector2(1280.0, 720.0)
	var rect: Rect2 = Rect2(51.0, 35.0, 1190.0, 590.0)
	var focus: Vector3 = Vector3(24.625, 0.0, 4.0)
	var axes: Basis = Basis.from_euler(Vector3(-1.1, 0.2, 0.1))
	var size: float = 28.5
	var pivot: Vector3 = Rig.fit_position(focus, axes, viewport_size, rect, size)
	var camera: Transform3D = Transform3D(axes, pivot + axes.z * 60.0)
	var projection: Projection = _projection(size, viewport_size)
	assert(_project(focus, camera, projection, viewport_size).distance_to(rect.get_center()) < EPSILON)
	for point: Vector3 in [focus, Vector3(-0.125, 0.0, -7.625), Vector3(49.375, 0.0, 15.625)]:
		var screen: Vector2 = _project(point, camera, projection, viewport_size)
		assert(_unproject_floor(screen, camera, projection, viewport_size).distance_to(point) < EPSILON)


func _check_sequence_ownership() -> void:
	var rig = Rig.new()
	rig.frame_bounds(ARENA, false)
	var original_focus: Vector3 = rig.focus_world
	assert(rig.acquire_sequence())
	assert(not rig.acquire_sequence())
	rig.frame_bounds(WORLD, false)
	assert(rig.focus_world == original_focus and rig.view_span == ARENA.size)
	rig.release_sequence()
	rig.frame_bounds(WORLD, false)
	assert(rig.focus_world == Vector3(24.625, 0.0, 4.0))
	rig.free()


func _check_native_camera() -> void:
	# Headless Camera3D checks exercise the engine API without drawing a frame.
	var viewport: Window = root
	viewport.content_scale_size = Vector2i.ZERO
	viewport.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	viewport.size = Vector2i(1280, 720)
	var rig = Rig.new()
	var camera: Camera3D = Camera3D.new()
	camera.name = "Camera3D"
	rig.add_child(camera)
	viewport.add_child(rig)
	rig.set_view_rect(_safe_rect(Vector2(viewport.size)))
	rig.frame_bounds(ARENA, false)
	var center_screen: Vector2 = rig.world_to_screen(rig.focus_world)
	assert(center_screen.distance_to(Vector2(640.0, 329.5)) < EPSILON)
	var next_tile: Vector2 = rig.world_to_screen(rig.focus_world + Vector3(0.25, 0.0, 0.0))
	assert(absf(next_tile.x - center_screen.x - 19.0) < EPSILON)
	assert(rig.screen_to_world(center_screen).distance_to(rig.focus_world) < EPSILON)
	assert(camera.projection == Camera3D.PROJECTION_ORTHOGONAL)
	assert(camera.keep_aspect == Camera3D.KEEP_HEIGHT)
	var original_focus: Vector3 = rig.focus_world
	viewport.size = Vector2i(1024, 768)
	center_screen = rig.world_to_screen(original_focus)
	assert(center_screen.distance_to(_safe_rect(Vector2(viewport.size)).get_center()) < EPSILON)
	assert(rig.focus_world == original_focus)
	var completions: Array[int] = []
	rig.settled.connect(func() -> void: completions.append(1))
	rig.frame_bounds(WORLD, true, 0.25)
	var replaced_motion: Tween = rig._motion
	replaced_motion.custom_step(0.1)
	rig.frame_bounds(ARENA, true, 0.03)
	assert(not replaced_motion.is_valid(), "Replacing a move must kill its tween.")
	rig._motion.custom_step(0.04)
	assert(completions.size() == 1, "Only the replacement tween may settle.")
	assert(rig.focus_world.distance_to(original_focus) < EPSILON)
	rig.frame_bounds(WORLD, true, 0.03)
	var canceled_motion: Tween = rig._motion
	assert(rig.acquire_sequence())
	assert(not canceled_motion.is_valid(), "Acquiring a sequence must kill navigation.")
	assert(completions.size() == 1, "Acquiring a sequence must cancel navigation completion.")
	rig.rotation = Vector3(-1.1, 0.2, 0.1)
	center_screen = rig.world_to_screen(rig.focus_world)
	assert(center_screen.distance_to(_safe_rect(Vector2(viewport.size)).get_center()) < EPSILON)
	assert(rig.screen_to_world(center_screen).distance_to(rig.focus_world) < EPSILON)
	var sequence_focus: Vector3 = rig.focus_world
	rig.release_sequence()
	assert(rig.rotation.is_equal_approx(Vector3(-PI * 0.5, 0.0, 0.0)))
	assert(rig.focus_world == sequence_focus, "Releasing a sequence must retain its logical focus.")
	rig.free()
	print("Camera checks passed: exact 19px cells, 18 inset fits, numerical/native round trips, resize focus, custom_step tween replacement, sequence ownership and rotation reset.")
	quit(0)


func _projection(size: float, viewport_size: Vector2) -> Projection:
	var half_width: float = size * viewport_size.x / viewport_size.y * 0.5
	return Projection.create_orthogonal(-half_width, half_width, -size * 0.5, size * 0.5, 0.05, 150.0)


func _project(point: Vector3, camera: Transform3D, projection: Projection, viewport_size: Vector2) -> Vector2:
	var local: Vector3 = camera.affine_inverse() * point
	var clip: Vector4 = projection * Vector4(local.x, local.y, local.z, 1.0)
	return Vector2(clip.x / clip.w + 1.0, 1.0 - clip.y / clip.w) * viewport_size * 0.5


func _unproject_floor(screen: Vector2, camera: Transform3D, projection: Projection, viewport_size: Vector2) -> Vector3:
	var ndc: Vector2 = Vector2(2.0 * screen.x / viewport_size.x - 1.0, 1.0 - 2.0 * screen.y / viewport_size.y)
	var local: Vector4 = projection.inverse() * Vector4(ndc.x, ndc.y, -1.0, 1.0)
	var origin: Vector3 = camera * (Vector3(local.x, local.y, local.z) / local.w)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, -camera.basis.z)
	assert(hit is Vector3)
	return hit


func _watchdog() -> void:
	await create_timer(5.0).timeout
	push_error("Camera checks did not complete.")
	quit(1)
