class_name ArenicArenaTransition
extends CanvasLayer
## Event-driven navigation veil. No idle processing, readback, mipmaps or new viewports.
const SHADER: Shader = preload("res://shaders/themes/arena_transition.gdshader")
var active: bool = false
var view_rect := Rect2()
var _rig: ArenicCameraRig
var _copy: BackBufferCopy
var _veil: ColorRect
var _material: ShaderMaterial
var _next_ink: Color
var _rest_ink: Color
var _from_ink: Color
var _to_ink: Color
var _progress: float = 1.0
var _warmed: bool = false
var _warming: bool = false
var _initial_envelope: float = 0.0
var _rest_envelope: float = 0.0
var _from_flow := Vector2.ZERO
var _rest_flow := Vector2.ZERO


func configure(rig: ArenicCameraRig, theme: ArenicArenaTheme) -> void:
	layer = 6 # Above map labels (5); the persistent HUD is outside our clipped rect.
	_rig = rig
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_copy = BackBufferCopy.new()
	_copy.name = "WorldCopy"
	_copy.copy_mode = BackBufferCopy.COPY_MODE_DISABLED
	add_child(_copy)
	_veil = ColorRect.new()
	_veil.name = "FogDissolve"
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.material = _material
	_veil.visible = false
	add_child(_veil)
	set_process(false)
	set_theme(theme)
	_rest_ink = _next_ink
	_from_ink = _next_ink
	_to_ink = _next_ink
	_rig.motion_started.connect(_begin)
	_rig.motion_advanced.connect(_advance)
	_rig.motion_cancelled.connect(_cancel)
	_rig.settled.connect(_settle)
	get_viewport().size_changed.connect(_update_copy_rect)


func set_theme(theme: ArenicArenaTheme) -> void:
	if theme != null:
		# Mist belongs to the arena's dark surface; no white flash or bright wash.
		_next_ink = theme.color("base_300").lerp(theme.color("primary"), 0.065)


func set_view_rect(rectangle: Rect2) -> void:
	view_rect = rectangle
	if _veil == null:
		return
	_veil.position = rectangle.position
	_veil.size = rectangle.size.max(Vector2.ZERO)
	_update_copy_rect()
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if viewport_size.x > 0.0 and viewport_size.y > 0.0 and rectangle.has_area():
		# Clamp samples inside the copied world, excluding HUD and undefined borders.
		var first := rectangle.position / viewport_size
		var last := rectangle.end / viewport_size
		_material.set_shader_parameter("logical_viewport_size", viewport_size)
		_material.set_shader_parameter("sample_rect", Vector4(first.x, first.y, last.x, last.y))
	_update_visibility()
	if rectangle.has_area() and not _warmed:
		_warm_pipeline()


func _update_copy_rect() -> void:
	if _copy == null:
		return
	# Godot 4.7.2's RD and Compatibility renderers consume the raw copy rect in
	# render-target pixels, although the veil remains in logical canvas units.
	# Letterbox margins belong to the window, not the viewport's screen texture.
	var pixels: Rect2 = get_viewport().get_stretch_transform() * view_rect
	var first: Vector2 = pixels.position.floor()
	var last: Vector2 = pixels.end.ceil()
	_copy.rect = Rect2(first, last - first)


func _warm_pipeline() -> void:
	_warmed = true
	if DisplayServer.get_name() == "headless" or active:
		return
	# Render an identity pass during world loading so the first navigation does
	# not lazily compile a GPU pipeline. One frame only, with no visual change.
	_warming = true
	_advance(0.0)
	_update_visibility()
	await RenderingServer.frame_post_draw
	_warming = false
	if not active:
		_advance(1.0)
	_update_visibility()


func _begin(_duration: float) -> void:
	_from_ink = _rest_ink
	_to_ink = _next_ink
	_material.set_shader_parameter("from_ink", _from_ink)
	_material.set_shader_parameter("to_ink", _to_ink)
	_initial_envelope = _rest_envelope
	_from_flow = _rest_flow
	_material.set_shader_parameter("initial_envelope", _initial_envelope)
	_material.set_shader_parameter("flow_origin", _from_flow)
	active = true
	_advance(0.0)
	_update_visibility()


func _advance(value: float) -> void:
	_progress = value
	_material.set_shader_parameter("progress", value)


func _cancel() -> void:
	# Retarget from the visible ink, with no retained tween/capture allocation.
	_rest_ink = _from_ink.lerp(_to_ink, smoothstep(0.15, 0.85, _progress))
	_rest_envelope = current_envelope()
	_rest_flow = _from_flow + Vector2(0.7, -0.35) * _progress
	active = false
	_update_visibility()
	_clear_cancelled_pose.call_deferred()


func _clear_cancelled_pose() -> void:
	# An immediate replacement keeps continuity; a cancelled idle view stays clear.
	if not active:
		_rest_envelope = 0.0
		_rest_flow = Vector2.ZERO


func current_envelope() -> float:
	var wave: float = sin(clampf(_progress, 0.0, 1.0) * PI)
	return wave + _initial_envelope * (1.0 - smoothstep(0.0, 0.5, _progress)) * (1.0 - wave)


func _settle() -> void:
	_rest_envelope = 0.0
	_rest_flow = Vector2.ZERO
	_rest_ink = _next_ink
	_progress = 1.0
	active = false
	_update_visibility()


func _update_visibility() -> void:
	var show_effect: bool = (active or _warming) and view_rect.has_area()
	_veil.visible = show_effect
	_copy.copy_mode = BackBufferCopy.COPY_MODE_RECT if show_effect else BackBufferCopy.COPY_MODE_DISABLED
