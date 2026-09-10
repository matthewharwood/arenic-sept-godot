extends SceneTree
## Real-renderer regression for the actual transition at native and letterboxed sizes.
## godot --path arenic-game --script res://tests/world/transition_render_checks.gd
## Run with no other game instance. Headless cannot verify back-buffer pixels.

const SHELL_PATH: String = "res://scenes/game/game_shell.tscn"
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3436, 1932), Vector2i(2560, 1600)]
const FRACTIONS: Array[float] = [0.02, 0.2, 0.4, 0.6, 0.8, 0.98]
const DURATION: float = 0.55
var _shell: Variant
var _rig: ArenicCameraRig
var _overlay: ArenicArenaTransition
var _fixture: CanvasLayer
var _panels: Array[ColorRect] = []
var _checks: int = 0
var _done: bool = false
var _watchdog: Timer
var _cases: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_finish(1, "This regression requires a real renderer, not --headless.")
		return
	_watchdog = Timer.new()
	_watchdog.one_shot = true
	_watchdog.wait_time = 20.0
	root.add_child(_watchdog)
	_watchdog.timeout.connect(func(): _finish(1, "Twenty-second rendering watchdog exceeded."))
	_watchdog.start()
	var packed: PackedScene = load(SHELL_PATH) as PackedScene
	if not _check(packed != null, "Actual game shell loads."):
		return
	_shell = packed.instantiate()
	root.add_child(_shell)
	_shell.set_process_unhandled_input(false)
	await process_frame
	_rig = _shell.stage.camera_rig
	_overlay = _shell.stage.transition
	# A stationary, opaque test pattern covers the world behind the real effect.
	# This isolates capture coverage from moving sprites and animated atmosphere.
	_fixture = CanvasLayer.new()
	_fixture.layer = _overlay.layer - 1
	root.add_child(_fixture)
	var theme: ArenicArenaTheme = _shell.stage.world.arenas[2].visual_theme
	for token: String in ["primary", "secondary", "accent", "base_content"]:
		var panel := ColorRect.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.color = theme.color(token)
		_fixture.add_child(panel)
		_panels.append(panel)
	for requested: Vector2i in SIZES:
		root.size = requested
		await process_frame
		await process_frame
		if _done:
			return
		var world_rect: Rect2 = _shell.hud.get_world_rect()
		# A physical resize need not emit the HUD logical-rect signal.
		# The transition must update its copied pixel rect independently.
		_place_pattern(world_rect)
		_shell.select_arena(0)
		_shell.set_zoomed(true)
		_rig.frame_bounds(ArenicGridMath.arena_rect(_shell.stage.world.arenas[0].grid_slot), false)
		await _draw_twice()
		var baseline: Image = root.get_texture().get_image()
		if not _check(baseline != null and not baseline.is_empty(), "Baseline framebuffer is available."):
			return
		var result: Dictionary = {
			"requested": [requested.x, requested.y],
			"window": [root.size.x, root.size.y],
			"framebuffer": [baseline.get_width(), baseline.get_height()],
		}
		_cases.append(result)
		_shell.select_arena(8) # Focused arena -> focused arena, with the actual rig.
		_rig._motion.pause()
		await _draw_twice()
		if _done:
			return
		var identity: Image = root.get_texture().get_image()
		if not _check_samples(baseline, identity, world_rect, true, "identity pass"):
			return
		_rig._motion.custom_step(DURATION * 0.4)
		await _draw_twice()
		if _done:
			return
		var midpoint: Image = root.get_texture().get_image()
		if not _check_samples(baseline, midpoint, world_rect, false, "mid-pan fog"):
			return
		var envelope_before: float = _overlay.current_envelope()
		_shell.select_arena(2)
		_rig._motion.pause()
		if not _check(is_equal_approx(envelope_before, _overlay.current_envelope()), "Rapid retarget preserves fog density."):
			return
		_rig._motion.custom_step(DURATION * 0.12)
		await _draw_twice()
		if _done:
			return
		var retarget: Image = root.get_texture().get_image()
		if not _check_samples(baseline, retarget, world_rect, false, "rapid retarget"):
			return
		_rig._motion.custom_step(DURATION)
		if not _check(not _overlay.active and not _overlay._veil.visible and _overlay._copy.copy_mode == BackBufferCopy.COPY_MODE_DISABLED, "Settling disables the veil and screen copy."):
			return
		result["passed"] = true
	_finish(0, "Native transition coverage, identity, fog and retarget checks passed.")


func _place_pattern(rect: Rect2) -> void:
	var half: Vector2 = rect.size * 0.5
	for index: int in range(4):
		_panels[index].position = rect.position + half * Vector2(index % 2, index / 2)
		_panels[index].size = half


func _draw_twice() -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw


func _check_samples(baseline: Image, rendered: Image, rect: Rect2, identity: bool, phase: String) -> bool:
	if not _check(rendered != null and rendered.get_size() == baseline.get_size(), phase + " retains framebuffer size."):
		return false
	var to_pixels: Transform2D = root.get_stretch_transform()
	for u: float in FRACTIONS:
		for v: float in FRACTIONS:
			var point: Vector2i = Vector2i((to_pixels * (rect.position + rect.size * Vector2(u, v))).floor())
			var expected: Color = baseline.get_pixelv(point)
			var actual: Color = rendered.get_pixelv(point)
			if not _check(expected.r + expected.g + expected.b > 0.15, "Fixture covers every world sample with a nonblack color."):
				return false
			if identity:
				var difference: float = absf(expected.r - actual.r) + absf(expected.g - actual.g) + absf(expected.b - actual.b)
				if not _check(difference < 0.04, "%s preserves screen content at %s; expected %s, got %s." % [phase, point, expected, actual]):
					return false
			elif not _check(actual.r + actual.g + actual.b > 0.035, "%s has scene/fog coverage at %s instead of an uncopied black region." % [phase, point]):
				return false
	return true


func _check(condition: bool, message: String) -> bool:
	if _done:
		return false
	_checks += 1
	if not condition:
		_finish(1, message)
	return condition


func _finish(code: int, message: String) -> void:
	if _done:
		return
	_done = true
	if is_instance_valid(_watchdog):
		_watchdog.stop()
	print("TRANSITION_RENDER_CHECKS " + JSON.stringify({"passed": code == 0, "checks": _checks, "message": message, "cases": _cases}))
	quit(code)
