extends SceneTree
## Run with a real renderer after the visible game stops:
## Godot --path arenic-game --script res://tests/themes/overworld_checks.gd
## Contract checks for persistent glass chrome, camera handoff and a seekable sky clock.

const SHELL_PATH: String = "res://scenes/game/game_shell.tscn"
const SAFE_RECT: Rect2 = Rect2(13.0, 35.0, 1254.0, 589.0)
const WATCHDOG_SECONDS: float = 10.0

# Defer GameShell loading until its RunSetup autoload exists.
var _shell: Variant
var _stage: ArenicOverworldStage
var _watchdog: Timer
var _started_ms: int
var _checks: int = 0
var _done: bool = false


func _initialize() -> void:
	_started_ms = Time.get_ticks_msec()
	_run.call_deferred()


func _run() -> void:
	_watchdog = Timer.new()
	_watchdog.one_shot = true
	_watchdog.wait_time = WATCHDOG_SECONDS
	_watchdog.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_watchdog)
	_watchdog.timeout.connect(func(): _finish(1, "Overworld checks exceeded the ten-second watchdog."))
	_watchdog.start()
	if not _check(DisplayServer.get_name() != "headless", "Use a real renderer for the actual canvas and camera integration."):
		return
	var packed := load(SHELL_PATH) as PackedScene
	if not _check(packed != null, "Actual persistent game shell loads."):
		return
	root.size = Vector2i(1280, 720)
	_shell = packed.instantiate()
	root.add_child(_shell)
	await process_frame
	await process_frame
	if _done:
		return
	_stage = _shell.stage
	if not _check(_stage != null and _stage.world.arenas.size() == 9 and _stage.atmosphere != null, "Stage mounts nine regions and the dedicated overworld atmosphere."):
		return
	# Drive deterministic seeks ourselves; there is no wall-clock wait for a tween.
	_stage.set_process(false)
	_stage.atmosphere.set_process(false)
	_stage.atmosphere.atmosphere_playing = false
	for index: int in range(9):
		(_stage.get_arena(index).get_node("EnvironmentLayers") as Node).set_process(false)
	if not _check_hud() or not _check_sky_clock() or not _check_stage_handoff() or not _check_projected_coast():
		return
	for physical_size: Vector2i in [Vector2i(1600, 900), Vector2i(1024, 768)]:
		root.size = physical_size
		await process_frame
		await process_frame
		if _done:
			return
		_stage.atmosphere.sync_projection()
		if not _check_sky_rects() or not _check(_shell.hud.get_world_rect().is_equal_approx(SAFE_RECT), "Resizing retains the logical 1280 by 720 HUD safe area."):
			return
	var old_stage: WeakRef = weakref(_stage)
	var old_atmosphere: WeakRef = weakref(_stage.atmosphere)
	var old_foreground: WeakRef = weakref(_stage.atmosphere.get_node("ForegroundClouds"))
	var hud_id: int = _shell.hud.get_instance_id()
	var style_id: int = _hud_styles()[0].get_instance_id()
	_shell.replace_stage(_shell.stage_scene)
	_stage = _shell.stage
	await process_frame
	await process_frame
	if _done:
		return
	if not _check(old_stage.get_ref() == null and old_atmosphere.get_ref() == null and old_foreground.get_ref() == null, "Stage replacement frees both old sky layers and their clock owner."):
		return
	if not _check(_shell.hud.get_instance_id() == hud_id and _hud_styles()[0].get_instance_id() == style_id and _shell.get_node("ContentSlot").get_child_count() == 1, "Replacing a stage retains the same HUD and style resources with one active stage."):
		return
	if not _check(is_equal_approx(_stage.overview_mix, 1.0) and is_equal_approx(_hud_styles()[0].bg_color.a, 0.78), "Replacement stage reconnects presentation to the persistent glass HUD."):
		return
	_finish(0, "Overworld checks passed: %d assertions; persistent glass controls, logical sky projection, a periodic seekable clock, camera/input handoff and stage cleanup." % _checks)


func _hud_styles() -> Array[StyleBoxFlat]:
	var top := _shell.hud.get_node("TopStrip") as Panel
	var bottom := _shell.hud.get_node("BottomStrip") as Panel
	var toggle := bottom.get_node("OverviewToggle") as Button
	var result: Array[StyleBoxFlat] = [top.get_theme_stylebox("panel") as StyleBoxFlat, bottom.get_theme_stylebox("panel") as StyleBoxFlat, (top.get_node("ArenaHotkey") as Label).get_theme_stylebox("normal") as StyleBoxFlat]
	for state_name: String in ["normal", "hover", "pressed", "disabled"]:
		result.append(toggle.get_theme_stylebox(state_name) as StyleBoxFlat)
	return result


func _check_hud() -> bool:
	var hud: ArenicWorldHUD = _shell.hud
	var top := hud.get_node("TopStrip") as Panel
	var bottom := hud.get_node("BottomStrip") as Panel
	var toggle := bottom.get_node("OverviewToggle") as Button
	var top_sheen := top.get_node("GlassSheen") as TextureRect
	var bottom_sheen := bottom.get_node("GlassSheen") as TextureRect
	var original_rects: Dictionary = {}
	for child: Node in hud.find_children("*", "Control", true, false):
		original_rects[child.get_path()] = (child as Control).get_rect()
	var original_styles: Array[StyleBoxFlat] = _hud_styles()
	if not _check(hud.get_world_rect().is_equal_approx(SAFE_RECT) and toggle.get_rect().is_equal_approx(Rect2(1087.0, 12.0, 180.0, 37.0)), "Glass retains the exact safe area and actionable button hitbox."):
		return false
	if not _check(top.get_rect().is_equal_approx(Rect2(0.0, 0.0, hud.size.x, 35.0)) and bottom.get_rect().is_equal_approx(Rect2(0.0, hud.size.y - 96.0, hud.size.x, 96.0)), "Both HUD strips fill the viewport width and meet its outer edges without margins."):
		return false
	if not _check(top_sheen.position.x == 0.0 and bottom_sheen.position.x == 0.0 and top_sheen.size.x == hud.size.x and bottom_sheen.size.x == hud.size.x, "Sheen spans the full width of each hard-edged strip."):
		return false
	if not _check(top_sheen.texture == bottom_sheen.texture and top_sheen.texture.get_size() == Vector2(4.0, 64.0), "Two narrow sheen draws share one tiny native gradient texture."):
		return false
	if not _check(top_sheen.mouse_filter == Control.MOUSE_FILTER_IGNORE and bottom_sheen.mouse_filter == Control.MOUSE_FILTER_IGNORE and toggle.mouse_filter == Control.MOUSE_FILTER_STOP, "Glass decoration leaves the existing input boundary intact."):
		return false
	for arena_index: int in range(9):
		var definition: ArenicArenaDefinition = _stage.world.arenas[arena_index]
		hud.set_context(definition, "Dean", "Hunter", false)
		hud.set_overview_mix(2.0)
		var styles: Array[StyleBoxFlat] = _hud_styles()
		if not _check(is_equal_approx(styles[0].bg_color.a, 0.78) and styles[0].bg_color.is_equal_approx(styles[1].bg_color), "All nine overview palettes use matching translucent glass strips."):
			return false
		for style: StyleBoxFlat in styles:
			if not _check(style.corner_radius_top_left == 0 and style.corner_radius_top_right == 0 and style.corner_radius_bottom_left == 0 and style.corner_radius_bottom_right == 0 and style.shadow_size == 0 and style.shadow_offset.is_zero_approx(), "Overview strips, hotkey badge and every button state keep square corners without shadows."):
				return false
		if not _check(styles[0].border_width_top == 0 and styles[0].border_width_left == 0 and styles[0].border_width_right == 0 and styles[0].border_width_bottom == 1 and styles[1].border_width_bottom == 0 and styles[1].border_width_left == 0 and styles[1].border_width_right == 0 and styles[1].border_width_top == 1, "HUD strips retain only their inner separators, with no outer frame."):
			return false
		if not _check(top_sheen.visible and bottom_sheen.visible and hud.material == null and top.material == null and bottom.material == null, "Overview glass uses native styles and a sheen, with no screen-reading material."):
			return false
		hud.set_overview_mix(0.5)
		if not _check(styles[0].bg_color.a > 0.78 and styles[0].bg_color.a < 1.0, "The chrome accepts a smooth intermediate overview blend."):
			return false
		hud.set_overview_mix(-1.0)
		if not _check(styles[0].bg_color.is_equal_approx(definition.visual_theme.color("base_100")) and styles[1].bg_color.is_equal_approx(styles[0].bg_color), "Focused chrome restores the source palette with full opacity."):
			return false
		if not _check(styles[0].corner_radius_top_left == 0 and styles[1].corner_radius_top_left == 0 and styles[0].border_width_bottom == 1 and styles[1].border_width_top == 1 and styles[0].border_width_left == 0 and not top_sheen.visible and not bottom_sheen.visible, "Focused chrome restores square inner rules and removes both sheen draws."):
			return false
		for index: int in range(styles.size()):
			if not _check(styles[index] == original_styles[index], "Palette and overview updates reuse the same style resources."):
				return false
		for child_path: NodePath in original_rects:
			if not _check((hud.get_node(child_path) as Control).get_rect().is_equal_approx(original_rects[child_path]), "Blending and retheming leave every HUD control rectangle unchanged."):
				return false
	return true


func _sky_materials() -> Array[ShaderMaterial]:
	return [(_stage.atmosphere.get_node("CoastAndSky") as ColorRect).material as ShaderMaterial, (_stage.atmosphere.get_node("ForegroundClouds/DriftingClouds") as ColorRect).material as ShaderMaterial]


func _check_sky_clock() -> bool:
	var atmosphere: ArenicOverworldAtmosphere = _stage.atmosphere
	var sky := atmosphere.get_node("CoastAndSky") as ColorRect
	var clouds := atmosphere.get_node("ForegroundClouds/DriftingClouds") as ColorRect
	var foreground := clouds.get_parent() as CanvasLayer
	var hud_layer := _shell.hud.get_parent() as CanvasLayer
	if not _check(atmosphere.layer < hud_layer.layer and foreground.layer > hud_layer.layer, "Coast stays behind chrome while the light foreground clouds may overlap it."):
		return false
	if not _check(sky.mouse_filter == Control.MOUSE_FILTER_IGNORE and clouds.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Neither sky surface intercepts world or HUD interaction."):
		return false
	atmosphere.set_overview_mix(2.0)
	if not _check(is_equal_approx(atmosphere.overview_mix, 1.0) and sky.visible and clouds.visible and atmosphere.is_processing(), "Overview clamps to one and enables both sky layers and its clock."):
		return false
	atmosphere.set_process(false)
	atmosphere.atmosphere_playing = false
	var materials: Array[ShaderMaterial] = _sky_materials()
	var texture: Variant = materials[0].get_shader_parameter("cloud_noise")
	if not _check(texture is NoiseTexture2D and texture == materials[1].get_shader_parameter("cloud_noise") and texture.width == 256 and texture.height == 256 and texture.seamless, "Coast and foreground reuse one bounded seamless noise texture."):
		return false
	if not _check(is_equal_approx(atmosphere.cloud_period_seconds, 360.0), "The default authored cloud period is six minutes."):
		return false
	for time: float in [0.0, 360.0, 720.0, -360.0]:
		atmosphere.atmosphere_time = time
		atmosphere._process(0.0)
		for material: ShaderMaterial in materials:
			if not _check(is_zero_approx(float(material.get_shader_parameter("cloud_phase"))), "Exact cycle boundaries seek to the same cloud phase, including negative time."):
				return false
	for time: float in [90.0, 450.0, -270.0]:
		atmosphere.atmosphere_time = time
		atmosphere._process(0.0)
		for material: ShaderMaterial in materials:
			if not _check(is_equal_approx(float(material.get_shader_parameter("cloud_phase")), 0.25), "Paused seeks upload the same periodic phase to both cloud materials."):
				return false
	var held_time: float = atmosphere.atmosphere_time
	atmosphere._process(17.0)
	if not _check(is_equal_approx(atmosphere.atmosphere_time, held_time), "Paused sky clock holds even when processing is explicitly requested."):
		return false
	atmosphere.atmosphere_time = 359.5
	atmosphere.atmosphere_playing = true
	atmosphere._process(1.0)
	if not _check(is_equal_approx(atmosphere.atmosphere_time, 0.5), "Resuming wraps the explicit clock without a phase discontinuity."):
		return false
	atmosphere.atmosphere_playing = false
	for material: ShaderMaterial in materials:
		if not _check(is_equal_approx(float(material.get_shader_parameter("cloud_phase")), 0.5 / 360.0), "Resumed phase reaches both the coast and foreground cloud shader."):
			return false
	atmosphere.set_overview_mix(-1.0)
	if not _check(is_zero_approx(atmosphere.overview_mix) and not sky.visible and not clouds.visible and not atmosphere.is_processing(), "Sharp arena focus disables both full-window sky draws and their processing."):
		return false
	return true


func _check_stage_handoff() -> bool:
	var rig: ArenicCameraRig = _stage.camera_rig
	var hud: ArenicWorldHUD = _shell.hud
	for index: int in range(9):
		_shell.select_arena(index)
		_shell.set_zoomed(true)
		rig.frame_bounds(ArenicGridMath.arena_rect(_stage.world.arenas[index].grid_slot), false)
		_stage._process(0.0)
		if not _check(is_zero_approx(_stage.overview_mix) and is_zero_approx(_stage.atmosphere.overview_mix) and not _stage.atmosphere.is_processing(), "Every focused camera endpoint removes overview presentation synchronously."):
			return false
		if not _check(_hud_styles()[0].bg_color.is_equal_approx(_stage.world.arenas[index].visual_theme.color("base_100")), "Stage-to-HUD signal restores the focused palette after navigation."):
			return false
		var definition: ArenicArenaDefinition = _stage.world.arenas[index]
		var center: Vector3 = ArenicGridMath.tile_to_world(definition.grid_slot, Vector2i(32, 15))
		if not _check(absf(rig.world_to_screen(center).distance_to(rig.world_to_screen(center + Vector3(0.25, 0.0, 0.0))) - 19.0) < 0.01, "Overview presentation preserves the exact nineteen-pixel focused tile size."):
			return false
	_shell.set_zoomed(false)
	rig.frame_bounds(ArenicGridMath.world_rect(), false)
	_stage._process(0.0)
	if not _check(is_equal_approx(_stage.overview_mix, 1.0) and is_equal_approx(_stage.atmosphere.overview_mix, 1.0) and is_equal_approx(_hud_styles()[0].bg_color.a, 0.78), "Overview endpoint synchronizes the arena, sky and persistent glass HUD."):
		return false
	if not _check_sky_rects():
		return false
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	var world_bounds: Rect2 = ArenicGridMath.world_rect()
	var corner: Vector2 = world_bounds.position + Vector2.ONE * 0.25
	click.position = rig.world_to_screen(Vector3(corner.x, 0.0, corner.y))
	if not _check(_stage.labels.clip_rectangle.has_point(click.position) and not _stage.atmosphere.contains_land_point(click.position) and _stage.arena_at_screen(click.position) == -1, "A former rectangular board corner is visible sky and cannot select an arena."):
		return false
	var selected_before: int = _shell.selected_index
	_shell._unhandled_input(click)
	if not _check(_shell.selected_index == selected_before and not _shell.zoomed, "Clicking the rounded-away coast preserves selection and zoom state."):
		return false
	for index: int in range(9):
		var center: Vector2 = rig.world_to_screen(ArenicGridMath.arena_center(_stage.world.arenas[index].grid_slot))
		if not _check(_stage.atmosphere.contains_land_point(center) and _stage.arena_at_screen(center) == index, "All nine arena centers remain selectable inside the rounded coast."):
			return false
	click.position = rig.world_to_screen(ArenicGridMath.arena_center(_stage.world.arenas[2].grid_slot))
	_shell._unhandled_input(click)
	if not _check(_shell.selected_index == 2 and not _shell.zoomed, "Overview presentation preserves arena click selection."):
		return false
	click.double_click = true
	_shell._unhandled_input(click)
	if not _check(_shell.selected_index == 2 and _shell.zoomed, "Double-click navigation remains available through the noninteractive sky layers."):
		return false
	_shell.set_zoomed(false)
	rig.frame_bounds(ArenicGridMath.world_rect(), false)
	if not _check(rig.acquire_sequence(), "A cinematic can acquire the existing camera authority."):
		return false
	rig.view_span = Vector2(34.0, 16.0)
	_stage._process(0.0)
	if not _check(is_equal_approx(_stage.overview_mix, 0.5) and is_equal_approx(_stage.atmosphere.overview_mix, 0.5) and is_equal_approx(_hud_styles()[0].bg_color.a, 0.89), "Cinematic camera seeks derive the shared presentation mix from actual scale."):
		return false
	rig.view_span = Vector2(22.01, 10.5)
	_stage._process(0.0)
	if not _check(_stage.overview_mix > 0.0 and _stage.overview_mix < 0.00001 and float(hud.get("_overview_mix")) > 0.0, "A tiny nonzero camera blend reaches the HUD before the focused endpoint."):
		return false
	rig.view_span = Vector2(16.5, 7.75)
	_stage._process(0.0)
	if not _check(_stage.overview_mix == 0.0 and _stage.atmosphere.overview_mix == 0.0 and float(hud.get("_overview_mix")) == 0.0, "Focused endpoints propagate exact zero even after a sub-epsilon blend."):
		return false
	if not _check(_hud_styles()[0].bg_color.a == 1.0 and _hud_styles()[0].border_width_left == 0 and not _stage.atmosphere.is_processing(), "Exact focus restores opaque chrome, square edges and a disabled sky clock."):
		return false
	rig.release_sequence()
	rig.frame_bounds(ArenicGridMath.world_rect(), false)
	_stage._process(0.0)
	_stage.atmosphere.set_process(false)
	return _check(hud.get_world_rect().is_equal_approx(SAFE_RECT), "Camera ownership and presentation changes preserve the native play area.")


func _check_projected_coast() -> bool:
	var rig: ArenicCameraRig = _stage.camera_rig
	var atmosphere: ArenicOverworldAtmosphere = _stage.atmosphere
	var sky := atmosphere.get_node("CoastAndSky") as ColorRect
	var clouds := atmosphere.get_node("ForegroundClouds/DriftingClouds") as ColorRect
	var material: ShaderMaterial = sky.material as ShaderMaterial
	var bounds: Rect2 = ArenicGridMath.world_rect()
	if not _check(rig.acquire_sequence(), "Coast projection test owns the cinematic camera."):
		return false
	# Keep scale/mix unchanged: orientation alone must invalidate the projection.
	for rotation_value: Vector3 in [Vector3(-PI * 0.5, 0.0, 0.33), Vector3(-PI * 0.35, 0.17, 0.21)]:
		rig.rotation = rotation_value
		_stage._process(0.0)
		if not _check(atmosphere.get("_coast_valid") == true and sky.visible and _stage.overview_mix == 1.0, "Rotated or tilted orthographic land keeps a valid coast at the unchanged overview mix."):
			return false
		if not _check_sky_rects():
			return false
		var origin: Vector2 = material.get_shader_parameter("land_origin")
		var axis_u: Vector2 = material.get_shader_parameter("land_u")
		var axis_v: Vector2 = material.get_shader_parameter("land_v")
		for uv: Vector2 in [Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN, Vector2.ONE, Vector2(0.5, 0.5), Vector2(0.17, 0.81)]:
			var flat: Vector2 = bounds.position + bounds.size * uv
			var screen: Vector2 = rig.world_to_screen(Vector3(flat.x, 0.0, flat.y))
			var relative: Vector2 = screen - origin
			var reconstructed := Vector2(relative.dot(axis_u), relative.dot(axis_v))
			if not _check(reconstructed.distance_to(uv) < 0.00005, "Shader affine coordinates recover world-normalized land coordinates under tilt and rotation."):
				return false
		var middle: Vector2 = bounds.get_center()
		if not _check(atmosphere.contains_land_point(rig.world_to_screen(Vector3(middle.x, 0.0, middle.y))) and not atmosphere.contains_land_point(origin), "Coast picking keeps its land center and excludes its corner under the same affine projection."):
			return false
	rig.rotation = Vector3.ZERO
	_stage._process(0.0)
	if not _check(atmosphere.get("_coast_valid") == false and not sky.visible and clouds.visible, "An edge-on ground plane disables the invalid coast while retaining the independent cloud veil."):
		return false
	rig.release_sequence()
	rig.frame_bounds(bounds, false)
	_stage._process(0.0)
	if not _check(atmosphere.get("_coast_valid") == true and sky.visible, "Returning to top-down projection restores the coast without changing overview strength."):
		return false
	atmosphere.set_process(false)
	return true


func _check_sky_rects() -> bool:
	var atmosphere: ArenicOverworldAtmosphere = _stage.atmosphere
	atmosphere.sync_projection()
	var viewport_size: Vector2 = root.get_visible_rect().size
	for rectangle: ColorRect in [atmosphere.get_node("CoastAndSky"), atmosphere.get_node("ForegroundClouds/DriftingClouds")]:
		if not _check(rectangle.position.is_zero_approx() and rectangle.size.is_equal_approx(viewport_size), "Sky rectangles use logical viewport dimensions without a Retina multiplier."):
			return false
	var material: ShaderMaterial = _sky_materials()[0]
	if not _check((material.get_shader_parameter("viewport_size") as Vector2).is_equal_approx(viewport_size), "Coast shader receives the same logical dimensions as its canvas."):
		return false
	var bounds: Rect2 = ArenicGridMath.world_rect()
	var expected := Rect2(_stage.camera_rig.world_to_screen(Vector3(bounds.position.x, 0.0, bounds.position.y)), Vector2.ZERO)
	for point: Vector2 in [bounds.end, Vector2(bounds.position.x, bounds.end.y), Vector2(bounds.end.x, bounds.position.y)]:
		expected = expected.expand(_stage.camera_rig.world_to_screen(Vector3(point.x, 0.0, point.y)))
	var actual: Vector4 = material.get_shader_parameter("land_rect")
	return _check(actual.is_equal_approx(Vector4(expected.position.x, expected.position.y, expected.size.x, expected.size.y)), "Coast bounds follow the projected world instead of physical window pixels.")


func _check(condition: bool, message: String) -> bool:
	if _done:
		return false
	if Time.get_ticks_msec() - _started_ms >= int(WATCHDOG_SECONDS * 1000.0):
		_finish(1, "Overworld checks exceeded the ten-second watchdog.")
		return false
	_checks += 1
	if not condition:
		_finish(1, "Overworld assertion failed: " + message)
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
	if not await preload("res://tests/support/audio_retirement.gd").wait_for_mixer(self):
		code = 1
		message = "Audio mixer retirement failed after overworld checks."
	print(message)
	quit(code)
