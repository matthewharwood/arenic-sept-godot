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
	if not _check_layout():
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
	var long_name := "Alexandria the Unreasonably Well Documented Adventurer"
	var long_class := "Keeper of the Ancient Violet Observatory"
	_vitals.set_snapshot(3, long_name, long_class, 999, 123456789012345, 987654321098765, 123456789012345, 987654321098765, effects)
	if not _check_layout():
		return
	var name_label := _vitals.get_node("HeroName") as Label
	var class_label := _vitals.get_node("ClassName") as Label
	var xp_label := _vitals.get_node("ExperienceLabel") as Label
	var hp_label := _vitals.get_node("HealthLabel") as Label
	for label: Label in [name_label, class_label]:
		var natural_width: float = label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
		if not _check(natural_width > label.size.x and label.clip_text and label.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, "%s keeps oversized text inside its measured row with an ellipsis." % label.name):
			return
	if not _check(name_label.tooltip_text == long_name and class_label.tooltip_text == long_class and xp_label.tooltip_text == "LVL 999 · XP 123456789012345/987654321098765" and hp_label.tooltip_text == "HP 123456789012345/987654321098765", "Identity and stat rows retain exact authored names and values in their tooltips."):
		return
	_vitals.clear_selection()
	if not _check(not xp.visible and feedback.get_child_count() == 0 and (_vitals.get_node("HeroName") as Label).text == "No hero selected", "Clearing selection removes stale vitals, effects, and feedback."):
		return
	_finish(0, "Hero vitals checks passed: %d assertions; snapshots, bounds, effect ordering, animation and semantic palette." % _checks)


func _check_layout() -> bool:
	var name_label := _vitals.get_node("HeroName") as Label
	var class_label := _vitals.get_node("ClassName") as Label
	var name_baseline: float = name_label.position.y + name_label.get_theme_font("font").get_ascent(name_label.get_theme_font_size("font_size"))
	var class_baseline: float = class_label.position.y + class_label.get_theme_font("font").get_ascent(class_label.get_theme_font_size("font_size"))
	if not _check(is_equal_approx(name_baseline, class_baseline) and name_label.get_rect().end.x + 12.0 <= class_label.position.x, "Name and class share a baseline with a clear horizontal gutter."):
		return false
	var previous_end: float = maxf(name_label.get_rect().end.y, class_label.get_rect().end.y)
	for node_name: String in ["ExperienceLabel", "ExperienceTrack", "HealthLabel", "HealthTrack", "Debuffs", "Buffs"]:
		var row := _vitals.get_node(node_name) as Control
		if not _check(row.position.y >= previous_end and Rect2(Vector2.ZERO, _vitals.size).encloses(row.get_rect()), "%s fits inside the HUD without overlapping the preceding row." % node_name):
			return false
		if row is Label:
			if not _check(row.size.y >= row.get_theme_font("font").get_height(row.get_theme_font_size("font_size")), "%s reserves the full font line height, including descenders." % node_name):
				return false
		previous_end = row.get_rect().end.y
	return true


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
