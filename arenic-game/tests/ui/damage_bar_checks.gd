extends SceneTree
## Focused HUD checks; no game shell, audio playback, or renderer dependency.

const ARENAS: PackedStringArray = ["labyrinth", "guild_house", "sanctum", "mountain", "bastion", "pawnshop", "crucible", "casino", "gala"]

var _hud: ArenicWorldHUD
var _watchdog: Timer
var _checks: int = 0
var _requests: int = 0
var _releases: int = 0
var _done: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_watchdog = Timer.new()
	_watchdog.one_shot = true
	_watchdog.wait_time = 5.0
	root.add_child(_watchdog)
	_watchdog.timeout.connect(func(): _finish(1, "HUD checks exceeded the five-second watchdog."))
	_watchdog.start()
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	_hud = ArenicWorldHUD.new()
	_hud.set_damage_progress(20, 20)
	root.add_child(_hud)
	await process_frame
	if _done:
		return
	var bar := _hud.get_node("TopStrip/DamageBar") as ArenicArenaDamageBar
	var bar_material := bar.material as ShaderMaterial
	var toggle := _hud.get_node("BottomStrip/OverviewToggle") as Button
	if not _check(_hud.get_world_rect() == Rect2(13.0, 35.0, 1254.0, 589.0) and toggle.get_rect() == Rect2(1012.0, 12.0, 151.0, 30.0), "Damage presentation preserves the native world band and the compact Overview hitbox."):
		return
	if not _check(bar.get_rect() == Rect2(0.0, 0.0, 1280.0, 9.0) and bar.mouse_filter == Control.MOUSE_FILTER_IGNORE, "The thin strip reaches both viewport edges and cannot intercept input."):
		return
	if not _check(bar.completed_phases == 1 and bar.current_damage == 0 and bar_material.get_shader_parameter("has_foundation") == true, "A completed phase supplied before readiness keeps its full-width foundation."):
		return
	for index: int in ARENAS.size():
		var arena := ArenicArenaDefinition.new()
		arena.arena_id = ARENAS[index]
		arena.display_name = ARENAS[index]
		arena.visual_theme = load("res://data/themes/%s.tres" % ARENAS[index]) as ArenicArenaTheme
		_hud.set_context(arena, "Dean", "Hunter", index % 2 == 0)
		if not _check(bar.visible and bar.material == bar_material and bar_material.get_shader_parameter("pattern_id") == index, "Each selected arena changes the same strip to its unique pattern."):
			return
		var primary: Color = bar_material.get_shader_parameter("primary_color")
		if not _check(primary.is_equal_approx(arena.visual_theme.color("primary")), "Damage color comes from the selected arena's shared theme resource."):
			return
	for total: int in [0, 19, 20, 21, 40, 47]:
		_hud.set_damage_progress(total, 20)
		var expected_phase: int = floori(float(total) / 20.0)
		if not _check(bar.total_damage == total and bar.completed_phases == expected_phase and bar.current_damage == total % 20 and bar_material.get_shader_parameter("has_foundation") == (total >= 20), "Cumulative damage retains completed phases and wraps only the current fill."):
			return
		var fill: float = bar_material.get_shader_parameter("fill_fraction")
		if not _check(is_equal_approx(fill, float(total % 20) / 20.0), "Every layer uses the same proportional fill mask."):
			return
	_hud.set_damage_progress(-10, 0)
	if not _check(bar.total_damage == 0 and bar.phase_damage == 1 and bar.completed_phases == 0, "Invalid display inputs remain bounded."):
		return
	var ability := _hud.get_node("BottomStrip/AbilityAction") as Button
	var status := _hud.get_node("BottomStrip/AbilityStatus") as Label
	_hud.ability_requested.connect(func(): _requests += 1)
	_hud.ability_released.connect(func(): _releases += 1)
	_hud.set_ability_context("Sacrifice", "Ready", 0.0, 0.0, true)
	if not _check(not ability.disabled and ability.focus_mode == Control.FOCUS_NONE and ability.mouse_filter == Control.MOUSE_FILTER_STOP and toggle.focus_mode == Control.FOCUS_NONE, "The ability accepts pointer input without stealing map keyboard focus."):
		return
	_pointer(ability, true)
	if not _check(_requests == 1, "A real pointer press requests the ability immediately, before release."):
		return
	_hud.set_ability_context("Sacrifice", "", 0.0, INF, false)
	if not _check(not ability.disabled and ability.is_pressed() and status.text == "Channeling · release to stop", "A held channel stays enabled through context updates and never displays infinity."):
		return
	_pointer(ability, false)
	if not _check(_releases == 1, "Pointer release ends a held ability."):
		return
	_hud.set_ability_context("Arrow", "", 1.25, 0.0, false)
	_pointer(ability, true)
	_pointer(ability, false)
	if not _check(ability.disabled and _requests == 1 and status.text == "%.1fs cooldown" % 1.25, "Cooldown disables ordinary pointer casts and shows finite remaining time."):
		return
	for state_name: String in ["normal", "hover", "pressed", "disabled"]:
		var style := ability.get_theme_stylebox(state_name) as StyleBoxFlat
		if not _check(style != null and style.corner_radius_top_left == 0 and style.corner_radius_bottom_right == 0 and style.shadow_size == 0, "Every ability surface keeps square corners without a shadow."):
			return
	_finish(0, "Damage HUD checks passed: %d assertions; cumulative phases, nine palettes, geometry and pointer hold/release." % _checks)


func _pointer(button: Button, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = button.get_global_rect().get_center()
	event.global_position = event.position
	root.push_input(event, true)


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_finish(1, message)
		return false
	_checks += 1
	return true


func _finish(code: int, message: String) -> void:
	if _done:
		return
	_done = true
	print(message)
	if is_instance_valid(_hud):
		_hud.free()
	if is_instance_valid(_watchdog):
		_watchdog.free()
	quit(code)
