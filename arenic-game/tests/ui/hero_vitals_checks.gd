extends SceneTree
## Deterministic view checks: no game shell, combat mutation, renderer or audio.

var _vitals: ArenicHeroVitals
var _checks: int = 0
var _done: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_vitals = ArenicHeroVitals.new()
	_vitals.size = Vector2(255.0, 80.0)
	_vitals.set_snapshot(1, "Dean", "Hunter", 3, 20, 100, 80, 100, [])
	root.add_child(_vitals)
	await process_frame
	var xp := _vitals.get_node("ExperienceFill") as ColorRect
	var hp := _vitals.get_node("HealthFill") as ColorRect
	var feedback := _vitals.get_node("FeedbackLayer") as Control
	if not _check(feedback.get_child_count() == 0 and is_equal_approx(xp.size.x, 51.0) and is_equal_approx(hp.size.x, 204.0), "The first real snapshot snaps to bounded bars without inventing gains."):
		return
	if not _check(_vitals.mouse_filter == Control.MOUSE_FILTER_IGNORE and feedback.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Vitals and floating feedback preserve world input."):
		return
	for child: Node in _vitals.get_children():
		if child is Control and child != feedback:
			if not _check(child.get_rect().end.y <= 80.0, "All compact vitals rows fit the 80px HUD area."):
				return
	var effects: Array[Dictionary] = [
		{"name": "Haste", "beneficial": true, "remaining_seconds": 4.0, "stacks": 1},
		{"name": "Bleed", "beneficial": false, "remaining_seconds": 39.0, "stacks": 1},
		{"name": "Frost", "beneficial": false, "remaining_seconds": 3.0, "stacks": 2},
		{"name": "Curse", "beneficial": false, "remaining_seconds": -1.0, "stacks": 1},
	]
	_vitals.set_snapshot(1, "Dean", "Hunter", 3, 29, 100, 71, 100, effects)
	_vitals.set_process(false)
	var debuffs := _vitals.get_node("Debuffs") as RichTextLabel
	var buffs := _vitals.get_node("Buffs") as RichTextLabel
	if not _check(debuffs.get_parsed_text().begins_with("Frost ×2 (3s)") and buffs.get_parsed_text() == "Haste (4s)", "Debuffs and buffs have separate rows with shortest expiry first and stack counts."):
		return
	if not _check(debuffs.tooltip_text.ends_with("Curse") and not debuffs.tooltip_text.contains("-1"), "Untimed model effects keep their names without fabricated durations."):
		return
	if not _check(feedback.get_child_count() == 2 and is_equal_approx(hp.size.x, 204.0), "A real XP/HP update starts two feedback labels and animates from the previous bar."):
		return
	var xp_popup := feedback.get_child(0) as Label
	var hp_popup := feedback.get_child(1) as Label
	var xp_origin: float = xp_popup.position.y
	var hp_origin: float = hp_popup.position.y
	_vitals._process(0.12)
	if not _check(xp_popup.text == "+9 XP" and hp_popup.text == "-9 HP" and xp_popup.position.y < xp_origin and hp_popup.position.y > hp_origin, "Signed stat feedback rises for XP and descends for HP."):
		return
	if not _check(hp.size.x < 204.0 and hp.size.x > 181.05 and xp_popup.modulate.a < 1.0, "Health interpolates toward its new value while feedback fades."):
		return
	_vitals._process(0.12)
	if not _check(is_equal_approx(hp.size.x, 181.05), "The short HP animation reaches the exact latest snapshot."):
		return
	for index: int in 20:
		_vitals.set_snapshot(1, "Dean", "Hunter", 3, 30 + index, 100, 70 - index, 100, effects)
	if not _check(feedback.get_child_count() == ArenicHeroVitals.MAX_POPUPS, "A burst of real changes sheds only visual labels at the eight-popup bound."):
		return
	_vitals._process(2.0)
	if not _check(feedback.get_child_count() == 0 and not _vitals.is_processing() and is_equal_approx(hp.size.x, 130.05), "Feedback expires, the latest HP still wins under pressure, and idle processing stops."):
		return
	_vitals.set_snapshot(2, "King", "Warrior", 1, 0, 100, 100, 100, [])
	if not _check(feedback.get_child_count() == 0 and is_equal_approx(hp.size.x, 255.0), "Changing heroes resets the view without presenting another hero's stats as gains."):
		return
	_vitals.set_snapshot(2, "King", "Warrior", 1, 0, 100, 110, 100, [])
	if not _check(feedback.get_child_count() == 0, "HP is clamped before comparing snapshots, avoiding phantom healing above maximum."):
		return
	var dark_theme := load("res://data/themes/labyrinth.tres") as ArenicArenaTheme
	_vitals.set_visual_theme(dark_theme)
	if not _check(xp.color.is_equal_approx(ArenicHudTokens.color("xp", dark_theme)) and hp.color.is_equal_approx(ArenicHudTokens.color("hp", dark_theme)), "Both bars use the shared semantic palette under arena theme changes."):
		return
	if not _check(ArenicHudTokens.color("selected_content").a == 1.0 and ArenicHudTokens.color("map_active").get_luminance() < 0.001, "Selected roster text is opaque and the active arena token is black."):
		return
	_vitals.clear_selection()
	if not _check(not xp.visible and feedback.get_child_count() == 0 and (_vitals.get_node("HeroName") as Label).text == "No hero selected", "Clearing selection removes stale vitals, effects, and feedback."):
		return
	_finish(0, "Hero vitals checks passed: %d assertions; snapshots, bounds, effect ordering, animation and semantic palette." % _checks)


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
	if is_instance_valid(_vitals):
		_vitals.free()
	quit(code)
