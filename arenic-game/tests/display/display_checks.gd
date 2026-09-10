extends SceneTree
## Real-renderer integration check; stop the visible game before running.
## Godot --path arenic-game --script res://tests/display/display_checks.gd
## Uses native frame readback, logical/physical viewport input, and actual scene controls.

const SHELL_PATH: String = "res://scenes/game/game_shell.tscn"
const LOGICAL_SIZE: Vector2 = Vector2(1280.0, 720.0)
const WORLD_RECT: Rect2 = Rect2(13.0, 35.0, 1254.0, 589.0)
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(1600, 1200)]
const EXPECTED_IMAGES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(1600, 900)]
const WATCHDOG_SECONDS: float = 10.0
const EPSILON: float = 0.01

var _shell: Variant
var _rig: ArenicCameraRig
var _toggle: Button
var _watchdog: Timer
var _checks: int = 0
var _gui_presses: int = 0
var _started_ms: int
var _done: bool = false


func _initialize() -> void:
	_started_ms = Time.get_ticks_msec()
	_run.call_deferred()


func _run() -> void:
	_watchdog = Timer.new()
	_watchdog.one_shot = true
	_watchdog.wait_time = WATCHDOG_SECONDS
	root.add_child(_watchdog)
	_watchdog.timeout.connect(func(): _finish(1, "Display checks exceeded the ten-second watchdog."))
	_watchdog.start()
	if not _check(DisplayServer.get_name() != "headless", "Native framebuffer checks require a real renderer."):
		return
	if not _check(root.get_node_or_null("DisplayPolicy") != null, "Display autoload is available before the game shell."):
		return
	if not _check_policy():
		return
	var packed := load(SHELL_PATH) as PackedScene
	if not _check(packed != null, "Actual game shell loads."):
		return
	_shell = packed.instantiate()
	root.add_child(_shell)
	_rig = _shell.stage.camera_rig
	_toggle = _shell.hud.get_node("BottomStrip/OverviewToggle") as Button
	_toggle.pressed.connect(func(): _gui_presses += 1)
	for case_index: int in range(SIZES.size()):
		root.size = SIZES[case_index]
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		if _done:
			return
		_shell.stage.set_view_rect(_shell.hud.get_world_rect())
		_shell.set_zoomed(true)
		_rig.frame_bounds(_selected_bounds(), false)
		_shell.stage._process(0.0)
		if not _check_layout_and_projection(SIZES[case_index]):
			return
		if not _check_gui_input():
			return
		# Compare the identical paused scene: translucent HUD borders can reveal the
		# moving world, so a pre-zoom frame is not a valid control for the fog.
		_shell.set_zoomed(true)
		_rig.frame_bounds(_selected_bounds(), false)
		_rig.frame_bounds(ArenicGridMath.world_rect(), true)
		_rig._motion.pause()
		_rig._motion.custom_step(0.275)
		_shell.stage._process(0.0)
		_shell.stage.atmosphere.atmosphere_playing = false
		# Bosses can pass behind the translucent HUD during this paused camera
		# pose. Freeze their animation too so only the fog differs in the pair.
		for sprite: AnimatedSprite3D in _shell.stage.find_children("*", "AnimatedSprite3D", true, false):
			sprite.pause()
		for arena_index: int in range(9):
			var environment := _shell.stage.get_arena(arena_index).get_node("EnvironmentLayers") as ArenicArenaEnvironment
			environment.atmosphere_playing = false
		var leave := InputEventMouseMotion.new()
		leave.position = Vector2(-1.0, -1.0)
		leave.global_position = leave.position
		root.push_input(leave, true)
		var overlay: ArenicArenaTransition = _shell.stage.transition
		var veil := overlay.get_node("FogDissolve") as ColorRect
		var copy := overlay.get_node("WorldCopy") as BackBufferCopy
		veil.visible = false
		copy.copy_mode = BackBufferCopy.COPY_MODE_DISABLED
		await process_frame
		await RenderingServer.frame_post_draw
		if _done:
			return
		var before: Image = root.get_texture().get_image()
		if not _check(before != null and not before.is_empty() and before.get_size() == EXPECTED_IMAGES[case_index], "Window %s renders an actual %s framebuffer." % [SIZES[case_index], EXPECTED_IMAGES[case_index]]):
			return
		overlay._update_visibility()
		await process_frame
		await RenderingServer.frame_post_draw
		if _done:
			return
		var during: Image = root.get_texture().get_image()
		if not _check(during != null and during.get_size() == before.get_size(), "Transition preserves native framebuffer dimensions."):
			return
		if not _check_fog_and_hud(before, during):
			return
		_rig.frame_bounds(_selected_bounds(), false)
		_shell.stage._process(0.0)
	_finish(0, "Display checks passed: %d assertions; four native sizes, logical projection/picking, GUI input, framebuffer readback and sharp HUD during fog." % _checks)


func _check_policy() -> bool:
	for density: float in [1.0, 1.25, 2.0]:
		var expected := Vector2i(Vector2(LOGICAL_SIZE) * density)
		if not _check(ArenicDisplayPolicy.initial_window_size(Vector2i(4000, 2400), density) == expected, "Unconstrained initial size respects density %s." % density):
			return false
	for usable: Vector2i in [Vector2i(1920, 1080), Vector2i(1800, 1000), Vector2i(800, 1200)]:
		var fitted: Vector2i = ArenicDisplayPolicy.initial_window_size(usable, 2.0)
		if not _check(fitted.x * 9 == fitted.y * 16 and Vector2(fitted).x <= usable.x * 0.9 and Vector2(fitted).y <= usable.y * 0.9, "Initial size preserves exact 16:9 and fits the usable-area allowance."):
			return false
	return _check(ArenicDisplayPolicy.initial_window_size(Vector2i(4000, 2400), NAN) == Vector2i(1280, 720), "Unavailable density falls back to the logical base size.")


func _check_layout_and_projection(window_size: Vector2i) -> bool:
	if not _check(root.size == window_size, "Native window accepts the requested test size."):
		return false
	if not _check(root.content_scale_mode == Window.CONTENT_SCALE_MODE_CANVAS_ITEMS and root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_KEEP and root.content_scale_stretch == Window.CONTENT_SCALE_STRETCH_FRACTIONAL, "Game shell uses native canvas rendering with fractional KEEP scaling."):
		return false
	if not _check(root.content_scale_size == Vector2i(1280, 720) and root.get_visible_rect().size.is_equal_approx(LOGICAL_SIZE), "Logical canvas stays 1280x720 independent of framebuffer size."):
		return false
	if not _check(_shell.hud.size.is_equal_approx(LOGICAL_SIZE) and _shell.hud.get_world_rect().is_equal_approx(WORLD_RECT), "HUD and map band retain their logical dimensions."):
		return false
	var slot: Vector2i = _shell.stage.world.arenas[_shell.selected_index].grid_slot
	var world_center: Vector3 = ArenicGridMath.arena_center(slot)
	var center: Vector2 = _rig.world_to_screen(world_center)
	var next: Vector2 = _rig.world_to_screen(world_center + Vector3(ArenicGridMath.TILE_SIZE, 0.0, 0.0))
	if not _check(center.distance_to(WORLD_RECT.get_center()) < EPSILON and absf(center.distance_to(next) - 19.0) < EPSILON, "Camera centers the map and preserves nineteen logical units per tile."):
		return false
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(65, 30), Vector2i(32, 15)]:
		var world: Vector3 = ArenicGridMath.tile_to_world(slot, cell)
		var logical: Vector2 = _rig.world_to_screen(world)
		var picked: Vector3 = _rig.screen_to_world(logical)
		if not _check(picked.distance_to(world) < EPSILON and ArenicGridMath.world_to_tile(slot, picked) == cell and _shell.stage.arena_at_screen(logical) == _shell.selected_index, "Logical camera projection and picking agree at cell %s." % cell):
			return false
	return true


func _check_gui_input() -> bool:
	var logical: Vector2 = _toggle.get_global_rect().get_center()
	var before: int = _gui_presses
	var zoomed_before: bool = _shell.zoomed
	_click(logical, true)
	if not _check(_gui_presses == before + 1 and _shell.zoomed != zoomed_before, "Logical viewport coordinates hit the native HUD button through GUI dispatch."):
		return false
	# push_input(false) accepts viewport pixels, not global desktop coordinates.
	# Window/OS letterbox offsets are handled outside this viewport-local boundary.
	var native_pixel: Vector2 = root.get_final_transform() * logical
	_click(native_pixel, false)
	return _check(_gui_presses == before + 2 and _shell.zoomed == zoomed_before, "Stretched viewport pixels convert back to the same logical HUD target exactly once.")


func _click(position: Vector2, local_coordinates: bool) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion, local_coordinates)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		event.global_position = position
		root.push_input(event, local_coordinates)


func _check_fog_and_hud(before: Image, during: Image) -> bool:
	var overlay: ArenicArenaTransition = _shell.stage.transition
	var veil := overlay.get_node("FogDissolve") as ColorRect
	var copy := overlay.get_node("WorldCopy") as BackBufferCopy
	if not _check(veil.visible and copy.copy_mode == BackBufferCopy.COPY_MODE_RECT and not overlay.is_processing(), "Fog is active through one regional copy without per-frame polling."):
		return false
	var pixels: Rect2 = root.get_stretch_transform() * WORLD_RECT
	var expected_copy := Rect2(pixels.position.floor(), pixels.end.ceil() - pixels.position.floor())
	if not _check(copy.rect.is_equal_approx(expected_copy) and veil.get_global_rect().is_equal_approx(WORLD_RECT), "Fog copies native pixels while drawing inside the logical world band."):
		return false
	var material := veil.material as ShaderMaterial
	var shader_logical_size: Vector2 = material.get_shader_parameter("logical_viewport_size")
	if not _check(shader_logical_size.is_equal_approx(LOGICAL_SIZE), "Fog blur radius uses logical dimensions at every framebuffer density."):
		return false
	var sample_rect: Vector4 = material.get_shader_parameter("sample_rect")
	var minimum: Vector2 = WORLD_RECT.position / LOGICAL_SIZE
	var maximum: Vector2 = WORLD_RECT.end / LOGICAL_SIZE
	if not _check(sample_rect.x >= minimum.x - 0.000001 and sample_rect.y >= minimum.y - 0.000001 and sample_rect.z <= maximum.x + 0.000001 and sample_rect.w <= maximum.y + 0.000001, "Fog sample clamp never crosses the normalized HUD boundary."):
		return false
	var native_size: Vector2i = before.get_size()
	var scale_y: float = float(native_size.y) / LOGICAL_SIZE.y
	var top_height: int = floori(WORLD_RECT.position.y * scale_y)
	var bottom_start: int = ceili(WORLD_RECT.end.y * scale_y)
	var top := Rect2i(0, 0, native_size.x, top_height)
	var bottom := Rect2i(0, bottom_start, native_size.x, native_size.y - bottom_start)
	var unchanged: bool = before.get_region(top).get_data() == during.get_region(top).get_data() and before.get_region(bottom).get_data() == during.get_region(bottom).get_data()
	if not unchanged:
		_report_hud_difference(before, during, [top, bottom])
	return _check(unchanged, "Native HUD pixels remain unchanged and sharp while the world fog is drawn.")


func _report_hud_difference(before: Image, during: Image, regions: Array[Rect2i]) -> void:
	var first := Vector2i(-1, -1)
	var sampled_differences: int = 0
	for region: Rect2i in regions:
		for y: int in range(region.position.y, region.end.y):
			for x: int in range(region.position.x, region.end.x):
				if before.get_pixel(x, y) != during.get_pixel(x, y):
					if first.x < 0:
						first = Vector2i(x, y)
					sampled_differences += 1
					if sampled_differences >= 256:
						break
			if sampled_differences >= 256:
				break
		if sampled_differences >= 256:
			break
	print("HUD pixel mismatch: framebuffer=%s first=%s differences_sampled=%d before=%s during=%s" % [before.get_size(), first, sampled_differences, before.get_pixelv(first), during.get_pixelv(first)])


func _selected_bounds() -> Rect2:
	return ArenicGridMath.arena_rect(_shell.stage.world.arenas[_shell.selected_index].grid_slot)


func _check(condition: bool, message: String) -> bool:
	if _done:
		return false
	_checks += 1
	if Time.get_ticks_msec() - _started_ms >= int(WATCHDOG_SECONDS * 1000.0):
		_finish(1, "Display checks exceeded the ten-second watchdog.")
		return false
	if not condition:
		_finish(1, "Display assertion failed: " + message)
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
	await create_timer(0.1).timeout
	print(message)
	quit(code)
