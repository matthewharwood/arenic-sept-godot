extends SceneTree
## Run only after the visible game stops:
## Godot --headless --path arenic-game --script res://tests/world/transition_checks.gd
## Actual scene state and manually stepped tweens; rendered blur/FPS require separate QA.

const SHELL_PATH: String = "res://scenes/game/game_shell.tscn"
const DURATION: float = 0.55
const WATCHDOG_SECONDS: float = 5.0
const TOP_DOWN: Vector3 = Vector3(-PI * 0.5, 0.0, 0.0)

var _shell: Variant
var _stage: ArenicOverworldStage
var _rig: ArenicCameraRig
var _overlay: CanvasLayer
var _copy: BackBufferCopy
var _veil: ColorRect
var _watchdog: Timer
var _started_ms: int
var _checks: int = 0
var _starts: int = 0
var _settles: int = 0
var _done: bool = false
var _arena_ids: Array[int] = []
var _hud_id: int


func _initialize() -> void:
	_started_ms = Time.get_ticks_msec()
	_run.call_deferred()


func _run() -> void:
	_watchdog = Timer.new()
	_watchdog.one_shot = true
	_watchdog.wait_time = WATCHDOG_SECONDS
	root.add_child(_watchdog)
	_watchdog.timeout.connect(func(): _finish(1, "Transition checks exceeded the five-second watchdog."))
	_watchdog.start()
	root.size = Vector2i(1280, 720)
	var packed := load(SHELL_PATH) as PackedScene
	if not _check(packed != null, "Actual shell resource loads."):
		return
	_shell = packed.instantiate()
	root.add_child(_shell)
	await process_frame
	await process_frame
	if _done:
		return
	_stage = _shell.stage
	_rig = _stage.camera_rig
	_overlay = _stage.transition
	if not _check(_overlay != null, "Stage owns its transition layer."):
		return
	_copy = _overlay.get_node_or_null("WorldCopy") as BackBufferCopy
	_veil = _overlay.get_node_or_null("FogDissolve") as ColorRect
	if not _check(_copy != null and _veil != null, "Transition creates its regional copy and veil."):
		return
	if not _check(_overlay.layer > (_stage.get_node("Labels") as CanvasLayer).layer and _overlay.layer < (_shell.get_node("HUD") as CanvasLayer).layer, "World transition lies above labels and below the persistent HUD."):
		return
	for index: int in range(9):
		_arena_ids.append(_stage.get_arena(index).get_instance_id())
	_hud_id = _shell.hud.get_instance_id()
	_rig.motion_started.connect(func(_duration: float): _starts += 1)
	_rig.settled.connect(func(): _settles += 1)
	_shell.select_arena(0)
	_shell.set_zoomed(true)
	_rig.frame_bounds(_bounds(0), false)
	_refresh()
	if not _check_idle() or not _check(_visible_count() == 1 and _stage.get_arena(0).visible, "Settled native close view shows exactly its current arena."):
		return
	var starts_before: int = _starts
	_rig.frame_bounds(_bounds(0), true)
	_refresh()
	if not _check(_starts == starts_before, "An already-framed target does not start a transition.") or not _check_idle():
		return
	if not _check_retarget_and_cancel() or not _check_zoom_reversal() or not _check_sequence_handoff():
		return
	# A logical viewport resize exercises projection fitting, not OS window scaling.
	root.content_scale_size = Vector2i.ZERO
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1024, 768)
	await process_frame
	await process_frame
	if _done:
		return
	_stage.set_view_rect(_shell.hud.get_world_rect())
	_shell.select_arena(4)
	_pause_motion()
	_rig._motion.custom_step(DURATION * 0.5)
	_refresh()
	if not _check_overlay_rect() or not _check(_visible_count() == 9, "Resize during motion keeps all nine arenas available.") or not _check_coverage():
		return
	_complete_motion()
	if not _check_idle() or not _check_coverage():
		return
	if not _check_resized_neighbor_click():
		return
	_shell.select_arena(4)
	_complete_motion()
	root.size = Vector2i(1280, 720)
	await process_frame
	await process_frame
	if _done:
		return
	_stage.set_view_rect(_shell.hud.get_world_rect())
	_rig.frame_bounds(_bounds(4), false)
	_refresh()
	if not _check(_visible_count() == 1 and _stage.get_arena(4).visible, "Native close view returns to one arena after resize."):
		return
	for index: int in range(9):
		if not _check(_stage.get_arena(index).get_instance_id() == _arena_ids[index], "Camera transitions preserve arena %d and its resources." % index):
			return
	if not _check(_shell.hud.get_instance_id() == _hud_id, "Camera transitions preserve the HUD instance."):
		return
	_finish(0, "Transition checks passed: %d assertions; retarget, cancel, zoom reversal, sequence ownership, resize, coverage and idle overlay." % _checks)


func _check_retarget_and_cancel() -> bool:
	_shell.select_arena(8)
	if not _check(_rig.motion_active and _visible_count() == 9, "A long pan immediately retains every arena before the first tween frame."):
		return false
	_pause_motion()
	var old_motion: Tween = _rig._motion
	old_motion.custom_step(DURATION * 0.45)
	_refresh()
	if not _check(_rig.motion_progress > 0.4 and _rig.motion_progress < 0.5, "Public progress follows elapsed time through the eased camera move.") or not _check(_veil.visible and _copy.copy_mode == BackBufferCopy.COPY_MODE_RECT and not _overlay.is_processing(), "Active transition draws its regional effect without polling.") or not _check_coverage():
		return false
	var veil_material: ShaderMaterial = _veil.material as ShaderMaterial
	var envelope_before: float = float(_overlay.call("current_envelope"))
	var flow_before: Vector2 = veil_material.get_shader_parameter("flow_origin")
	flow_before += Vector2(0.7, -0.35) * _rig.motion_progress
	if not _check(envelope_before > 0.0, "Retarget fixture interrupts visible fog rather than an empty endpoint."):
		return false
	var crossed_screen: Vector2 = _rig.world_to_screen(ArenicGridMath.arena_center(_stage.world.arenas[4].grid_slot))
	if not _click_visible_arena(4, crossed_screen, "mid-pan crossed arena"):
		return false
	var envelope_after: float = float(_overlay.call("current_envelope"))
	var flow_after: Vector2 = veil_material.get_shader_parameter("flow_origin")
	flow_after += Vector2(0.7, -0.35) * _rig.motion_progress
	if not _check(absf(envelope_after - envelope_before) < 0.00001, "Mouse retarget preserves the displayed fog density without a clear-frame pop."):
		return false
	if not _check(flow_after.distance_to(flow_before) < 0.00001, "Mouse retarget preserves the displayed cloud origin."):
		return false
	old_motion = _rig._motion
	var intermediate_focus: Vector3 = _rig.focus_world
	var settles_before: int = _settles
	_shell.select_arena(2)
	if not _check(not old_motion.is_valid() and _rig.motion_active, "Rapid retarget kills the old tween and starts one replacement."):
		return false
	if not _check(_rig.focus_world.is_equal_approx(intermediate_focus), "Retarget starts at the displayed focus without snapping to the prior endpoint."):
		return false
	_pause_motion()
	_rig._motion.custom_step(DURATION * 0.35)
	_refresh()
	if not _check(_visible_count() == 9, "Replacement motion retains the crossed arenas.") or not _check_coverage():
		return false
	var canceled_motion: Tween = _rig._motion
	_rig.cancel_motion()
	_refresh()
	if not _check(not canceled_motion.is_valid() and _settles == settles_before, "Cancellation invalidates motion without a stale settled callback.") or not _check_idle() or not _check_coverage():
		return false
	_shell.select_arena(8)
	_complete_motion()
	return _check(_settles == settles_before + 1, "Only the final replacement settles.") and _check(_stage.get_arena(8).visible and _visible_count() == 1, "Long-distance pan settles on one destination arena.") and _check_idle()


func _check_zoom_reversal() -> bool:
	_shell.set_zoomed(false)
	_pause_motion()
	_rig._motion.custom_step(DURATION * 0.4)
	_refresh()
	if not _check(_visible_count() == 9, "Zoom-out keeps the full world available.") or not _check_coverage():
		return false
	var old_motion: Tween = _rig._motion
	_shell.set_zoomed(true)
	if not _check(not old_motion.is_valid(), "Zoom reversal cancels the outgoing motion."):
		return false
	_complete_motion()
	if not _check(_visible_count() == 1 and _stage.get_arena(8).visible, "Reversed zoom returns to the selected arena.") or not _check_idle():
		return false
	_shell.set_zoomed(false)
	_complete_motion()
	if not _check(_visible_count() == 9, "Completed overview shows all nine arenas.") or not _check_idle() or not _check_coverage():
		return false
	_shell.set_zoomed(true)
	_complete_motion()
	return _check_idle()


func _check_sequence_handoff() -> bool:
	_shell.select_arena(0)
	_pause_motion()
	_rig._motion.custom_step(DURATION * 0.25)
	var old_motion: Tween = _rig._motion
	if not _check(_rig.acquire_sequence(), "Sequence takes camera ownership during navigation."):
		return false
	_rig.focus_world = ArenicGridMath.arena_center(_stage.world.arenas[6].grid_slot)
	_rig.view_span = _bounds(6).size
	_rig.rotation = Vector3(-1.1, 0.15, 0.05)
	_refresh()
	if not _check(not old_motion.is_valid() and _visible_count() == 9, "Sequence cancels navigation and can show any arena regardless of selection.") or not _check_idle():
		return false
	var focus_before: Vector3 = _rig.focus_world
	var span_before: Vector2 = _rig.view_span
	var starts_before: int = _starts
	_rig.frame_bounds(_bounds(2), true)
	if not _check(_rig.focus_world == focus_before and _rig.view_span == span_before and _starts == starts_before, "Navigation framing cannot interrupt a sequence or start its overlay."):
		return false
	_rig.release_sequence()
	if not _check(_rig.focus_world == focus_before and _rig.rotation.is_equal_approx(TOP_DOWN), "Release keeps sequence focus and restores navigation orientation."):
		return false
	_shell.select_arena(0)
	_complete_motion()
	return _check(_visible_count() == 1 and _stage.get_arena(0).visible, "Navigation can return from a sequence to a single arena.") and _check_idle()


func _check_overlay_rect() -> bool:
	var copies: Array[Node] = _overlay.find_children("*", "BackBufferCopy", true, false)
	var fills: Array[Node] = _overlay.find_children("*", "ColorRect", true, false)
	if not _check(copies.size() == 1 and fills.size() == 1, "Transition has one regional copy and one overlay surface."):
		return false
	var copy: BackBufferCopy = copies[0] as BackBufferCopy
	var fill: ColorRect = fills[0] as ColorRect
	var expected: Rect2 = _shell.hud.get_world_rect()
	var pixel_rect: Rect2 = root.get_stretch_transform() * expected
	var first: Vector2 = pixel_rect.position.floor()
	pixel_rect = Rect2(first, pixel_rect.end.ceil() - first)
	return _check(copy.rect.is_equal_approx(pixel_rect) and fill.get_global_rect().is_equal_approx(expected), "Resize confines the pixel capture and logical effect to the current world band.") and _check(fill.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Overlay leaves game input available for retargeting.")


func _check_coverage() -> bool:
	var rect: Rect2 = _shell.hud.get_world_rect()
	for u: float in [0.01, 0.25, 0.5, 0.75, 0.99]:
		for v: float in [0.01, 0.25, 0.5, 0.75, 0.99]:
			var point: Vector3 = _rig.screen_to_world(rect.position + rect.size * Vector2(u, v))
			if not _check(point.is_finite(), "World-band sample reaches the ground plane."):
				return false
			for index: int in range(9):
				if _bounds(index).has_point(Vector2(point.x, point.z)) and not _check(_stage.get_arena(index).is_visible_in_tree(), "Arena %d under the current camera is visible." % index):
					return false
	return true


func _check_resized_neighbor_click() -> bool:
	var rect: Rect2 = _shell.hud.get_world_rect()
	# The taller fitted world band exposes parts of the row above or below.
	for vertical_fraction: float in [0.02, 0.98]:
		var screen: Vector2 = rect.position + rect.size * Vector2(0.5, vertical_fraction)
		var point: Vector3 = _rig.screen_to_world(screen)
		for index: int in range(9):
			if index != _shell.selected_index and _bounds(index).has_point(Vector2(point.x, point.z)):
				return _click_visible_arena(index, screen, "resized fitted neighbor")
	return _check(false, "Resize fixture exposes a neighboring arena inside the world band.")


func _click_visible_arena(index: int, screen: Vector2, context: String) -> bool:
	if not _check(index != _shell.selected_index and _stage.get_arena(index).is_visible_in_tree() and _shell.hud.get_world_rect().has_point(screen), context + " is visible and differs from the selected destination."):
		return false
	if not _check(_stage.arena_at_screen(screen) == index, context + " resolves to its actual arena under the pointer."):
		return false
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = screen
	_shell._unhandled_input(click)
	return _check(_shell.selected_index == index and _stage.selected_index == index, context + " mouse press retargets navigation.")


func _check_idle() -> bool:
	return _check(not _rig.motion_active and is_equal_approx(_rig.motion_progress, 1.0), "Idle camera exposes completed progress.") and _check(not _veil.visible and _copy.copy_mode == BackBufferCopy.COPY_MODE_DISABLED and not _overlay.is_processing(), "Idle or sequence-owned camera disables overlay drawing, capture and processing.")


func _bounds(index: int) -> Rect2:
	return ArenicGridMath.arena_rect(_stage.world.arenas[index].grid_slot)


func _visible_count() -> int:
	var count: int = 0
	for index: int in range(9):
		if _stage.get_arena(index).is_visible_in_tree():
			count += 1
	return count


func _pause_motion() -> void:
	if _rig._motion != null:
		_rig._motion.pause()


func _complete_motion() -> void:
	if _rig._motion != null:
		_pause_motion()
		_rig._motion.custom_step(DURATION + 0.01)
	_refresh()


func _refresh() -> void:
	_stage._process(0.0)


func _check(condition: bool, message: String) -> bool:
	if _done:
		return false
	_checks += 1
	if Time.get_ticks_msec() - _started_ms >= int(WATCHDOG_SECONDS * 1000.0):
		_finish(1, "Transition checks exceeded the five-second watchdog.")
		return false
	if not condition:
		_finish(1, "Transition assertion failed: " + message)
		return false
	return true


func _finish(code: int, message: String) -> void:
	if _done:
		return
	_done = true
	if is_instance_valid(_watchdog):
		_watchdog.stop()
	_cleanup.call_deferred(code, message)


func _cleanup(code: int, message: String) -> void:
	if is_instance_valid(_shell):
		_shell.free()
	if is_instance_valid(_watchdog):
		_watchdog.free()
	# Stopped audio is retired by the mixer, then released on the main thread.
	await create_timer(0.10).timeout
	# Complete main-loop cleanup even if one slow frame consumed the timer.
	await process_frame
	await process_frame
	print(message)
	quit(code)
