class_name ArenicCameraRig
extends Node3D
## One owner derives the camera transform from a world focus and visible span.
## AnimationPlayer may animate focus_world, view_span, and this rig's rotation
## after acquire_sequence(). Do not animate the Camera3D child or rig position.

signal settled

@export var focus_world: Vector3 = Vector3.ZERO:
	set(value):
		if not value.is_finite():
			push_error("Camera focus must be finite.")
			return
		focus_world = value
		_queue_projection()

@export var view_span: Vector2 = Vector2(49.5, 23.25):
	set(value):
		if not value.is_finite() or value.x <= 0.0 or value.y <= 0.0:
			push_error("Camera span must be finite and positive.")
			return
		view_span = value
		_queue_projection()

var sequence_owned: bool:
	get:
		return _sequence_owned

var _camera: Camera3D
var _sequence_owned: bool = false
var _motion: Tween
var _motion_generation: int = 0
var _projection_queued: bool = false
var _projection_basis: Basis = Basis.IDENTITY
var _view_insets: Vector4 = Vector4.ZERO # Left, top, right, bottom.


func _ready() -> void:
	_camera = get_node_or_null("Camera3D") as Camera3D
	if _camera == null:
		push_error("ArenicCameraRig requires a direct Camera3D child named Camera3D.")
		assert(false, "Missing ArenicCameraRig/Camera3D")
		return
	rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	scale = Vector3.ONE
	_camera.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, 0.0, 60.0))
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	_camera.near = 0.05
	_camera.far = 150.0
	_camera.h_offset = 0.0
	_camera.v_offset = 0.0
	_camera.make_current()
	set_notify_transform(true)
	get_viewport().size_changed.connect(_queue_projection)
	_apply_projection()


func _exit_tree() -> void:
	cancel_motion()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED and is_node_ready():
		# Translation is derived below; only orientation changes require refitting.
		if not global_basis.is_equal_approx(_projection_basis):
			_queue_projection()


## The rect uses this camera's viewport coordinates. Retain its pixel insets
## across resizing; the HUD can call again whenever its own layout changes.
func set_view_rect(rect: Rect2) -> void:
	if not rect.position.is_finite() or not rect.size.is_finite():
		push_error("Camera view rectangle must be finite.")
		return
	if not is_inside_tree():
		push_error("Set the camera view rectangle after entering the scene tree.")
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	_view_insets = Vector4(
		rect.position.x, rect.position.y,
		viewport_size.x - rect.end.x, viewport_size.y - rect.end.y
	)
	_queue_projection()


## Rect2 stores world X/Z bounds, including the half-tile outer footprint.
func frame_bounds(bounds: Rect2, animated: bool = true, duration: float = 0.55) -> void:
	if _sequence_owned:
		return
	if not bounds.position.is_finite() or not bounds.size.is_finite() \
			or bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		push_error("Camera bounds must be finite and positive.")
		return
	cancel_motion()
	var center: Vector2 = bounds.get_center()
	var target: Vector3 = Vector3(center.x, 0.0, center.y)
	if not animated or duration <= 0.0 or not is_node_ready():
		focus_world = target
		view_span = bounds.size
		_apply_projection()
		settled.emit()
		return
	_motion = create_tween().set_parallel(true)
	_motion.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_motion.tween_property(self, "focus_world", target, duration)
	_motion.tween_property(self, "view_span", bounds.size, duration)
	_motion.finished.connect(_finish_motion.bind(_motion_generation))


func cancel_motion() -> void:
	_motion_generation += 1
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = null


func acquire_sequence() -> bool:
	if _sequence_owned:
		return false
	cancel_motion()
	_sequence_owned = true
	return true


func release_sequence() -> void:
	_sequence_owned = false
	rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	_queue_projection()


## Returns non-finite coordinates for an unavailable camera or a point behind it.
func world_to_screen(world: Vector3) -> Vector2:
	_apply_projection()
	if _camera == null or not world.is_finite() or _camera.is_position_behind(world):
		return Vector2(INF, INF)
	return _camera.unproject_position(world)


## The caller rejects HUD/outside-grid clicks; no clamping happens here.
## A ray parallel to, or pointing away from, Y=0 returns non-finite coordinates.
func screen_to_world(screen: Vector2) -> Vector3:
	_apply_projection()
	if _camera == null or not screen.is_finite():
		return Vector3(INF, INF, INF)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(
		_camera.project_ray_origin(screen), _camera.project_ray_normal(screen)
	)
	if hit is Vector3:
		return hit
	return Vector3(INF, INF, INF)


static func fit_size(span: Vector2, viewport_size: Vector2, rect: Rect2) -> float:
	assert(viewport_size.y > 0.0 and rect.size.x > 0.0 and rect.size.y > 0.0)
	return viewport_size.y * maxf(span.x / rect.size.x, span.y / rect.size.y)


static func fit_position(focus: Vector3, orientation: Basis, viewport_size: Vector2,
		rect: Rect2, size: float) -> Vector3:
	var delta: Vector2 = viewport_size * 0.5 - rect.get_center()
	var units_per_pixel: float = size / viewport_size.y
	var axes: Basis = orientation.orthonormalized()
	return focus + (axes.x * delta.x - axes.y * delta.y) * units_per_pixel


func _queue_projection() -> void:
	if not is_node_ready() or _projection_queued:
		return
	_projection_queued = true
	_apply_projection.call_deferred()


func _apply_projection() -> void:
	_projection_queued = false
	if not is_inside_tree() or _camera == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var rect: Rect2 = Rect2(
		Vector2(_view_insets.x, _view_insets.y),
		viewport_size - Vector2(_view_insets.x + _view_insets.z, _view_insets.y + _view_insets.w)
	)
	if viewport_size.y <= 0.0 or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return # A minimized/tiny viewport cannot contain the HUD and world.
	_projection_basis = global_basis
	_camera.size = fit_size(view_span, viewport_size, rect)
	global_position = fit_position(focus_world, _projection_basis, viewport_size, rect, _camera.size)


func _finish_motion(generation: int) -> void:
	if generation != _motion_generation or _sequence_owned:
		return
	_motion = null
	_apply_projection()
	settled.emit()
