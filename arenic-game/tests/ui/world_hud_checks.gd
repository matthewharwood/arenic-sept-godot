extends SceneTree
## Real shell input and persistent HUD state; overflow is an isolated fixture.
const SHELL_PATH: String = "res://scenes/game/game_shell.tscn"
const RETIRE_AUDIO: GDScript = preload("res://tests/support/audio_retirement.gd")
var checks: int = 0
var failed: bool = false
var shell: Variant # Resolve GameShell after the RunSetup autoload is ready.
var requested_identities: Array[int] = []


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("World HUD: " + message)


func _run() -> void:
	create_timer(30.0).timeout.connect(func():
		push_error("World HUD checks timed out")
		quit(1))
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var setup: Node = root.get_node("RunSetup")
	setup.begin_new_game()
	setup.intro_step = 6 # Established gameplay fixture; prologue is tested separately.
	setup.choose_class(load("res://data/classes/cardinal.tres"))
	var packed_shell := load(SHELL_PATH) as PackedScene
	shell = packed_shell.instantiate()
	root.add_child(shell)
	await process_frame
	await process_frame
	var hud: ArenicWorldHUD = shell.hud
	var hero: ArenicHeroState = shell.hero
	var roster := hud.get_node("BottomStrip/CharacterRoster") as ArenicRosterStrip
	check(hud.get_world_rect() == Rect2(13.0, 35.0, 1254.0, 589.0), "The 1280 layout preserves the 589px world band and 19px tile framing")
	check(hero == setup.get_hero() and hero.arena_id == "guild_house", "HUD consumes the real controlled Guild House hero")
	check(roster.CAPACITY == 40 and roster.entries.size() == 1, "Forty markers contain the sole real hero, without a live overflow fixture")
	check(int(roster.entries[0].identity) == hero.identity_id and roster.entries[0].name == hero.display_name(), "Roster identity and generated name come from authoritative hero state")
	check(roster.hidden_entries().is_empty(), "An ordinary run has no invented reserve characters")
	var empty_count: int = 0
	for slot: int in 40:
		if roster._entry_at(_slot_center(slot)) < 0:
			empty_count += 1
	check(empty_count == 39, "The other 39 roster positions are empty")
	_check_map(hud, 1)
	check(not shell.zoomed and not hero.selected and roster.selected_identity == -1, "Overworld begins without an active hero or roster selection")
	_check_overworld_slots(hud)
	_check_top_strip(hud, "Guild House")
	check((hud.get_node("BottomStrip/RaidDifficulty") as Label).text == "Raid: Normal", "Raid Normal is informational")
	check(hud.has_node("BottomStrip/GlobalChat"), "The global activity feed belongs to the persistent bottom HUD")

	press(KEY_BRACKETRIGHT)
	check(shell.selected_index == 2 and shell.hero == hero and hero.arena_id == "guild_house", "Right bracket changes the actual selected arena without moving or replacing the hero")
	_check_map(hud, 2)
	_check_top_strip(hud, "Sanctum")
	check(roster.entries.is_empty(), "An arena without the hero shows only empty roster positions")
	press(KEY_BRACKETLEFT)
	check(shell.selected_index == 1 and roster.entries.size() == 1, "Left bracket restores the real Guild House roster")
	click((hud.get_node("BottomStrip/ArenaCell4") as Button).get_global_rect().get_center())
	check(shell.selected_index == 4, "A real map pointer click selects the same world arena used by keyboard navigation")
	_check_map(hud, 4)
	click((hud.get_node("BottomStrip/PreviousArena") as Button).get_global_rect().get_center())
	check(shell.selected_index == 3, "Previous arena button follows bracket navigation")
	click((hud.get_node("BottomStrip/NextArena") as Button).get_global_rect().get_center())
	check(shell.selected_index == 4, "Next arena button follows bracket navigation")
	click((hud.get_node("BottomStrip/ArenaCell1") as Button).get_global_rect().get_center())
	click(roster.global_position + _slot_center(0))
	check(hero.selected and shell.zoomed and shell.selected_index == 1, "Clicking the real roster marker selects and focuses that hero")
	check(roster.selected_identity == hero.identity_id, "The selected marker follows the authoritative hero selection")
	_check_slots(hud)

	var guide := hud.get_node("ControlsLayer/ControlsGuide") as Control
	press(KEY_H)
	check(guide.visible and (guide.get_node("GuideText") as Label).text.contains("[ / ]"), "H opens a guide containing current bracket controls")
	var guide_text_rect: Rect2 = (guide.get_node("GuideText") as Label).get_rect()
	var guide_layout_fits: bool = Rect2(Vector2.ZERO, guide.size).encloses(guide_text_rect)
	for name: String in ["OverviewToggle", "SaveAndTitle", "CloseGuide"]:
		var action_rect: Rect2 = (guide.get_node(name) as Button).get_rect()
		guide_layout_fits = guide_layout_fits and Rect2(Vector2.ZERO, guide.size).encloses(action_rect) and not guide_text_rect.intersects(action_rect)
	check(guide_layout_fits, "The opened Controls panel contains its measured legend and footer actions without overlap")
	var zoomed_before: bool = shell.zoomed
	click((guide.get_node("OverviewToggle") as Button).get_global_rect().get_center())
	check(shell.zoomed != zoomed_before, "Overview remains a real pointer action inside the Controls panel")
	check(not hero.selected and roster.selected_identity == -1, "Switching to overworld clears both hero and roster highlights")
	if not guide.visible:
		press(KEY_H)
	click((guide.get_node("OverviewToggle") as Button).get_global_rect().get_center())
	check(shell.zoomed == zoomed_before, "Controls-panel navigation returns to the same view")
	press(KEY_TAB)
	check(hero.selected and roster.selected_identity == hero.identity_id, "Tab deliberately restores the remembered hero's selection after zooming back in")
	if not guide.visible:
		press(KEY_H)
	click((guide.get_node("CloseGuide") as Button).get_global_rect().get_center())
	check(not guide.visible, "Close dismisses the Controls panel through real pointer input")
	press(KEY_H)
	press(KEY_H)
	check(not guide.visible, "H closes the guide")
	var damage_before: int = shell.combat.damage_for_arena("guild_house")
	for code: Key in [KEY_2, KEY_3, KEY_4]:
		press(code)
	await physics_frame
	await physics_frame
	check(not shell.combat.is_channeling(shell.hero) and shell.combat.damage_for_arena("guild_house") == damage_before, "Unassigned slots 2-4 never cast or fabricate damage")
	# R now arms a real recording rather than explaining a reserved control.
	press(KEY_R)
	await physics_frame
	check(shell.session.is_counting_down(), "R arms the recording countdown")
	var record := hud.get_node("BottomStrip/RecordAction") as Button
	var record_feedback := record.get_node("Feedback") as Label
	check(record.text == "Record" and record_feedback.text.is_valid_int() and record_feedback.text.to_int() > 0, "The countdown appears inside Record without replacing its action title")
	check(shell.combat.damage_for_arena("guild_house") == damage_before, "Arming a recording deals no damage")
	press(KEY_R)
	await physics_frame
	check(shell.session.is_idle(), "R again aborts the countdown")
	check(record.text == "Record" and record_feedback.text.is_empty(), "Cancelling the countdown clears its in-button timer")
	await _check_ability_input()
	check(shell.hero == hero and roster.entries.size() == 1 and roster.hidden_entries().is_empty(), "HUD interactions never create extra gameplay heroes")
	shell.free()
	setup.begin_new_game()
	await process_frame
	await _check_cleanse_effect_fixture()
	await _check_recruitment_fixture()
	await _check_overworld_fixture()
	await _check_overflow_fixture()
	check(await RETIRE_AUDIO.wait_for_mixer(self), "Stopped audio resources retire before test exit")
	print("World HUD checks: %d assertions, %s." % [checks, "FAILED" if failed else "passed"])
	quit(1 if failed else 0)


func _check_map(hud: ArenicWorldHUD, selected: int) -> void:
	var cells: int = 0
	var active: int = 0
	for child: Node in hud.get_node("BottomStrip").get_children():
		if not str(child.name).begins_with("ArenaCell"):
			continue
		cells += 1
		var button := child as Button
		var style := button.get_theme_stylebox("normal") as StyleBoxFlat
		if style.bg_color.is_equal_approx(ArenicHudTokens.color("map_active")):
			active += 1
			check(button.name == "ArenaCell%d" % selected, "The black map cell matches the shell's active arena")
	check(cells == 9 and active == 1, "The map retains exactly nine cells and one active arena")


func _check_top_strip(hud: ArenicWorldHUD, arena_name: String) -> void:
	var top := hud.get_node("TopStrip") as Control
	var title := top.get_node("ArenaTitle") as Label
	var effects := top.get_node("BossEffects") as RichTextLabel
	check(title.text == arena_name and Rect2(Vector2.ZERO, top.size).encloses(title.get_rect()), "The top strip contains only the selected arena name as its title")
	check(effects.text.is_empty() and not effects.visible, "An unaffected boss leaves the effect readout empty")
	var removed: bool = true
	for old_name: String in ["Wordmark", "StatusDivider", "DamageLabel", "PhaseLabel", "ViewContext", "ArenaHotkey", "OverviewToggle", "ControlsHelp", "SaveAndTitle"]:
		removed = removed and not top.has_node(old_name)
	check(removed and not hud.has_node("BottomStrip/RosterNavigation"), "Obsolete top chrome and the roster navigation caption are removed")
	var guide := hud.get_node("ControlsLayer/ControlsGuide") as Control
	for name: String in ["OverviewToggle", "SaveAndTitle", "CloseGuide"]:
		var button := guide.get_node(name) as Button
		check(Rect2(Vector2.ZERO, guide.size).encloses(button.get_rect()), "%s stays inside the Controls panel" % name)


func _check_cleanse_effect_fixture() -> void:
	# The shell is retired: presentation receives a frozen model-shaped snapshot,
	# while combat/encounter tests own actual stack creation and expiry.
	var fixture := ArenicWorldHUD.new()
	root.add_child(fixture)
	var world := load("res://data/world/arenia.tres") as ArenicWorldDefinition
	var arena: ArenicArenaDefinition = world.arenas[world.index_for_id("labyrinth")]
	fixture.set_context(arena, "Marcus", "Bard", true)
	await process_frame
	await process_frame
	var effects := fixture.get_node("TopStrip/BossEffects") as RichTextLabel
	var observed: Array[Dictionary] = [{"id": "cleanse", "name": "Cleanse", "remaining_seconds": 4.1,
		"stacks": 2, "beneficial": false, "detail": "Independent stacks; timer shows the next stack expiry."}]
	fixture.set_boss_effects(observed)
	check(effects.visible and effects.get_parsed_text() == "Cleanse ×2 [5s]", "Cleanse displays its actual stack count and rounds the next expiry up to readable seconds")
	var negative: String = ArenicHudTokens.color("negative", arena.visual_theme).to_html(false)
	check(effects.text.begins_with("[color=#%s]" % negative), "Cleanse uses the current arena's debuff color rather than a beneficial boss color")
	check(effects.tooltip_text.contains("Independent stacks") and effects.tooltip_text.contains("next stack expiry"), "The tooltip explains independent stacks and the timer's next-expiry meaning")
	observed[0].remaining_seconds = 1.0 / 60.0
	fixture.set_boss_effects(observed)
	check(effects.get_parsed_text() == "Cleanse ×2 [1s]", "The final live tick remains visible without claiming an expired zero-second effect")
	observed[0].stacks = 1
	observed[0].remaining_seconds = 3.0
	fixture.set_boss_effects(observed)
	check(effects.get_parsed_text() == "Cleanse [3s]", "After the first independent stack expires the remaining stack keeps its own timer without a stale multiplier")
	fixture.set_boss_effects([])
	check(not effects.visible and effects.text.is_empty() and effects.tooltip_text.is_empty(), "The last expiry clears both the Cleanse chip and its tooltip")
	fixture.free()


func _check_slots(hud: ArenicWorldHUD) -> void:
	var first := hud.get_node("BottomStrip/AbilityAction") as Button
	check(first.text == "Sacrifice" and (first.get_node("Hotkey") as Label).text == "1", "The chosen class's starter occupies fixed slot 1 with its separate hotkey")
	for slot: int in range(2, 5):
		var button := hud.get_node("BottomStrip/AbilitySlot%d" % slot) as Button
		check(button.disabled and button.text == "—" and (button.get_node("Hotkey") as Label).text == str(slot), "Unassigned ability slot %d remains present and disabled with its separate hotkey" % slot)
	check(not hud.has_node("BottomStrip/AbilitySlot5"), "There is no fifth ability slot")
	check(not hud.has_node("BottomStrip/AbilityStatus"), "No detached ability hint remains below the action buttons")
	for node_name: String in ["AbilityAction", "AbilitySlot2", "AbilitySlot3", "AbilitySlot4", "RecordAction"]:
		var button := hud.get_node("BottomStrip/" + node_name) as Button
		var feedback := button.get_node_or_null("Feedback") as Label
		var hotkey := button.get_node("Hotkey") as Label
		check(button.size == Vector2(70, 70), "%s keeps the shared square action footprint" % node_name)
		check(hotkey.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s leaves its hotkey transparent to pointer input" % node_name)
		if node_name in ["AbilityAction", "RecordAction"]:
			check(feedback != null and Rect2(Vector2.ZERO, button.size).encloses(feedback.get_rect()) and not feedback.get_rect().intersects(hotkey.get_rect()) and feedback.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s contains feedback above its hotkey without intercepting pointer input" % node_name)
		for state_name: String in ["normal", "hover", "pressed", "disabled"]:
			var style := button.get_theme_stylebox(state_name) as StyleBoxFlat
			check(style.corner_radius_top_left == 12 and style.corner_radius_top_right == 12 and style.corner_radius_bottom_left == 12 and style.corner_radius_bottom_right == 12, "%s retains 12-pixel corners in its %s state" % [node_name, state_name])


func _check_overworld_slots(hud: ArenicWorldHUD) -> void:
	var paths: Array[String] = ["AbilityAction", "AbilitySlot2", "AbilitySlot3", "AbilitySlot4", "RecordAction"]
	for index: int in paths.size():
		var button := hud.get_node("BottomStrip/" + paths[index]) as Button
		var action: StringName = ArenicOverworldActions.action_for_slot(index)
		var hotkey := button.get_node("Hotkey") as Label
		check(not button.disabled and button.text == ArenicOverworldActions.title(action) and button.tooltip_text == button.text and hotkey.text == ArenicOverworldActions.hotkey(action), "Overworld slot %d displays the shared catalog action and hotkey" % index)
		var text_size: Vector2 = button.get_theme_font("font").get_multiline_string_size(button.text, HORIZONTAL_ALIGNMENT_CENTER, ArenicWorldHUD.ACTION_TEXT_WIDTH, button.get_theme_font_size("font_size"))
		check(button.size == Vector2(70, 70) and text_size.x <= ArenicWorldHUD.ACTION_TEXT_WIDTH and text_size.y <= 46.0 and hotkey.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Overworld slot %d fits its native wrapped title above the unchanged accent hotkey" % index)
		var feedback := button.get_node_or_null("Feedback") as Label
		check(feedback == null or not feedback.visible, "Overworld slot %d hides combat and recording feedback" % index)


func _check_overworld_fixture() -> void:
	var fixture := ArenicWorldHUD.new()
	root.add_child(fixture)
	var world := load("res://data/world/arenia.tres") as ArenicWorldDefinition
	var arena: ArenicArenaDefinition = world.arenas[world.index_for_id("guild_house")]
	var hero := ArenicHeroState.new()
	hero.identity_id = 101
	hero.definition = load("res://data/classes/cardinal.tres")
	hero.selected = true
	fixture.set_context(arena, hero.display_name(), hero.definition.display_name, true)
	fixture.set_hero_control(true, true)
	fixture.set_run_context(world, hero, world.index_for_id("guild_house"), {"health": 1, "max_health": 1}, [])
	fixture.set_ability_context("Sacrifice", "Hold to channel", 0.0, INF, true)
	fixture.set_recording_state("REC", "A real take is active", true, "0:21")
	var roster := fixture.get_node("BottomStrip/CharacterRoster") as ArenicRosterStrip
	check(roster.selected_identity == hero.identity_id, "The focused fixture starts with its actual selected hero")
	fixture.set_context(arena, hero.display_name(), hero.definition.display_name, false)
	check(roster.selected_identity == -1, "Overworld removes the roster highlight immediately, before another run snapshot")
	hero.selected = false
	fixture.set_hero_control(false, false)
	fixture.set_run_context(world, hero, world.index_for_id("guild_house"), {"health": 1, "max_health": 1}, [])
	check((fixture.get_node("BottomStrip/HeroVitals/HeroName") as Label).text == hero.display_name(), "Remembered hero vitals remain navigation context without a selected roster marker")
	# Background combat updates must remain cached while overworld labels are shown.
	fixture.set_ability_context("Sacrifice", "Cooling down", 0.7, 0.0, false)
	fixture.set_recording_state("REC", "A real take is active", true, "0:22")
	await process_frame
	_check_overworld_slots(fixture)
	var overworld: Array[StringName] = []
	var combat: Array[String] = []
	fixture.overworld_action_requested.connect(func(action: StringName) -> void: overworld.append(action))
	fixture.ability_requested.connect(func() -> void: combat.append("down"))
	fixture.ability_released.connect(func() -> void: combat.append("up"))
	fixture.record_requested.connect(func() -> void: combat.append("record"))
	for path: String in ["AbilityAction", "AbilitySlot2", "AbilitySlot3", "AbilitySlot4", "RecordAction"]:
		click((fixture.get_node("BottomStrip/" + path) as Button).get_global_rect().get_center())
	check(overworld == [&"rotate_selected", &"roster", &"loot", &"auction", &"craft"] and combat.is_empty(), "Five real pointer clicks emit only their ordered overworld actions")
	var record := fixture.get_node("BottomStrip/RecordAction") as Button
	check(record.get_theme_color("font_color").is_equal_approx(arena.visual_theme.color("base_content")), "A cached active recording does not tint Craft as if it were recording")
	fixture.set_context(arena, hero.display_name(), hero.definition.display_name, true)
	var ability := fixture.get_node("BottomStrip/AbilityAction") as Button
	check(ability.text == "Sacrifice" and ability.disabled and (ability.get_node("Feedback") as Label).visible and (ability.get_node("Feedback") as Label).text == "CD 0.7s", "Zoom restores the latest cached combat title, availability and cooldown feedback")
	check(record.text == "REC" and (record.get_node("Feedback") as Label).visible and (record.get_node("Feedback") as Label).text == "0:22" and record.tooltip_text == "A real take is active", "Zoom restores the latest recording title, timer and tooltip")
	check(roster.selected_identity == -1, "Zooming alone does not highlight an unselected remembered hero")
	hero.selected = true
	fixture.set_hero_control(true, true)
	fixture.set_ability_context("Sacrifice", "Hold to channel", 0.0, 0.0, true)
	check(roster.selected_identity == hero.identity_id, "An explicit hero selection restores the roster highlight")
	click(ability.get_global_rect().get_center())
	click(record.get_global_rect().get_center())
	check(combat == ["down", "up", "record"] and overworld.size() == 5, "Focused combat controls restore their existing press, release and Record signals")
	fixture.free()


func _check_ability_input() -> void:
	key(KEY_1, true)
	await physics_frame
	await physics_frame
	check(shell.combat.is_channeling(shell.hero), "Physical 1 starts the real Cardinal channel")
	await create_timer(1.1).timeout
	check(shell.combat.damage_for_arena("guild_house") > 0, "Holding slot 1 reaches an authoritative channel damage tick")
	key(KEY_SPACE, true)
	key(KEY_1, false)
	await physics_frame
	await physics_frame
	check(shell.combat.is_channeling(shell.hero), "Releasing 1 keeps the channel alive while the Space alias is held")
	key(KEY_SPACE, false)
	check(not shell.combat.is_channeling(shell.hero), "Releasing the final held binding stops the channel")
	await create_timer(1.05).timeout
	key(KEY_SPACE, true)
	await physics_frame
	await physics_frame
	check(shell.combat.is_channeling(shell.hero), "Space independently starts the same starter ability")
	key(KEY_1, false)
	check(shell.combat.is_channeling(shell.hero), "An unrelated 1 release cannot cancel held Space")
	key(KEY_SPACE, false)
	check(not shell.combat.is_channeling(shell.hero), "Space release ends its channel")
	await create_timer(1.05).timeout
	key(KEY_1, true)
	await physics_frame
	await physics_frame
	press(KEY_BRACKETRIGHT)
	check(not shell.combat.is_channeling(shell.hero) and shell.selected_index == 2, "Arena navigation cancels slot 1 ownership")
	key(KEY_1, false)
	press(KEY_TAB)
	await physics_frame
	await physics_frame
	check(shell.selected_index == 2 and not shell.hero.selected, "Tab leaves an empty arena without controlling its remote hero")
	shell.select_arena(1)
	check(not shell.combat.is_channeling(shell.hero), "Returning to the hero cannot resume stale held input")


func _check_recruitment_fixture() -> void:
	# The shell is already retired: live model refreshes cannot replace these
	# deliberate threshold and font-size cases while the deferred layout settles.
	var fixture := ArenicWorldHUD.new()
	root.add_child(fixture)
	await process_frame
	var recruitment := ArenicRecruitmentState.new()
	recruitment.configure(load("res://data/guild/recruitment.tres"), 320)
	var counter := fixture.get_node("TopStrip/GuildRolls") as Label
	var ready := fixture.get_node("TopStrip/RollsReady") as Button
	var toggle := fixture.get_node("ControlsLayer/ControlsGuide/OverviewToggle") as Button
	var toggle_rect: Rect2 = toggle.get_rect()
	var cases: Array = [
		[0, "Next hero 0/40", 0], [39, "Next hero 39/40", 0],
		[40, "Next hero 0/64", 1], [50, "Next hero 10/64", 1],
		[104, "Next hero 0/102", 2], [120, "Next hero 16/102", 2],
	]
	for entry: Array in cases:
		fixture.set_recruitment(recruitment.progress(int(entry[0])))
		await process_frame
		await process_frame
		check(counter.visible and counter.text == entry[1], "Earnings %d retain the exact next-unearned-hero counter" % entry[0])
		var available: int = int(entry[2])
		check(ready.visible == (available > 0) and ready.disabled == (available == 0), "Earnings %d independently control ready-button availability" % entry[0])
		if available > 0:
			check(ready.text == "%d [N]" % available, "The separate ready button shows the banked count and keyboard action")
		_check_recruitment_geometry(fixture, "earnings %d" % entry[0])
		check(toggle.get_rect() == toggle_rect, "Recruitment progress leaves the Controls-panel Overview hitbox unchanged")
	for remaining: int in [1, 0]:
		recruitment.claim()
		fixture.set_recruitment(recruitment.progress(120))
		await process_frame
		await process_frame
		check(counter.visible and counter.text == "Next hero 16/102", "Claiming at 120 earnings never spends or replaces next-hero progress")
		check(ready.visible == (remaining > 0) and ready.disabled == (remaining == 0), "Claiming changes the separate ready action from two rolls to one to none")
		if remaining > 0:
			check(ready.text == "1 [N]", "Claiming the first banked roll leaves exactly one ready")
		_check_recruitment_geometry(fixture, "%d banked rolls remaining" % remaining)
	# The current linear tail reaches guild capacity below one billion damage.
	# Check its real final boundary separately from long-label layout fixtures.
	var final_threshold: int = recruitment.curve.total_for(recruitment.max_rolls)
	var final_span: int = recruitment.curve.cost_of(recruitment.max_rolls - 1)
	var final_progress: Dictionary = recruitment.progress(final_threshold - 1)
	fixture.set_recruitment(final_progress)
	await process_frame
	await process_frame
	check(int(final_progress.next_at) == final_threshold and int(final_progress.span) == final_span and int(final_progress.toward) == final_span - 1, "The current curve preserves its exact last unearned recruitment boundary")
	check(counter.tooltip_text.begins_with("Next hero %d / %d" % [final_span - 1, final_span]), "The final recruitment counter retains the current curve's exact values")
	_check_recruitment_geometry(fixture, "current final recruitment threshold")
	# Deliberately model-shaped presentation inputs cover long counters without
	# coupling the HUD to an obsolete curve. The final case exceeds the width
	# budget even after moving recruitment into the wider top navigation band.
	var compact_progress: Dictionary = {"available": 319, "claimed": 0, "toward": 9_000_000_000_000_000_001, "span": 9_000_000_000_000_000_002, "next_at": 9_200_000_000_000_000_000}
	var long_cases: Array[Dictionary] = [
		{"available": 317, "claimed": 2, "toward": 70_802_156, "span": 557_518_630, "next_at": 1_486_716_474},
		compact_progress,
	]
	for progress: Dictionary in long_cases:
		fixture.set_damage_progress(1_000_000_000)
		fixture.set_recruitment(progress)
		await process_frame
		await process_frame
		check(counter.tooltip_text.begins_with("Next hero %d / %d" % [int(progress.toward), int(progress.span)]), "Long next-hero progress preserves its exact native integers in the tooltip")
		if progress == compact_progress:
			check(counter.text.contains("Q"), "A counter that exceeds the wider top band uses its compact suffix")
		var bar := fixture.get_node("TopStrip/DamageBar") as ArenicArenaDamageBar
		check(bar.total_damage == 1_000_000_000 and bar.tooltip_text.contains("1000000000"), "The retained damage bar preserves the exact cumulative total without a separate label")
		_check_recruitment_geometry(fixture, "long-counter presentation %d" % int(progress.toward))
	fixture.set_recruitment(recruitment.progress(9223372036854775807))
	await process_frame
	await process_frame
	check(counter.visible and counter.text == "All rolls earned" and not counter.text.contains("/"), "Exhausted thresholds retain a terminal counter without a huge numerator or zero denominator")
	check(ready.visible and not ready.disabled, "Exhausting the table preserves unclaimed banked rolls")
	_check_recruitment_geometry(fixture, "all thresholds earned")
	# Changing the font alone must remeasure; do not call a setter/layout method
	# that could conceal a missing minimum-size/theme notification connection.
	fixture.set_damage_progress(0)
	var fresh := ArenicRecruitmentState.new()
	fresh.configure(load("res://data/guild/recruitment.tres"), 320)
	fixture.set_recruitment(fresh.progress(120))
	await process_frame
	await process_frame
	counter.add_theme_font_size_override("font_size", 16)
	ready.add_theme_font_size_override("font_size", 14)
	await process_frame
	await process_frame
	check(counter.tooltip_text.begins_with("Next hero 16 / 102") and toggle.get_rect() == toggle_rect, "Larger requested fonts preserve exact progress and never displace menu controls")
	_check_recruitment_geometry(fixture, "larger recruitment fonts")
	# A compact label may have reduced its font during an earlier presentation.
	# Returning to a short counter must recover the normal reading size.
	counter.add_theme_font_size_override("font_size", 8)
	ready.add_theme_font_size_override("font_size", 10)
	fixture.set_recruitment(fresh.progress(0))
	await process_frame
	await process_frame
	check(counter.text == "Next hero 0/40" and counter.get_theme_font_size("font_size") == 12, "A short replacement recovers the normal counter font after a compact presentation")
	_check_recruitment_geometry(fixture, "recovered normal font")
	# Exercise the actual HUD header at both the first overflow and guild bound,
	# independently of the standalone roster's entry-selection checks below.
	var world := load("res://data/world/arenia.tres") as ArenicWorldDefinition
	var definition := load("res://data/classes/cardinal.tres") as ArenicClassDefinition
	var guild: Array[ArenicHeroState] = []
	for index: int in 320:
		var member := ArenicHeroState.new()
		member.identity_id = index
		member.definition = definition
		guild.append(member)
	var reserve := fixture.get_node("BottomStrip/RosterCount") as Button
	var roster := fixture.get_node("BottomStrip/CharacterRoster") as ArenicRosterStrip
	var large_progress: Dictionary = compact_progress.duplicate()
	fixture.set_recruitment(large_progress)
	for count: int in [41, 320]:
		fixture.set_run_context(world, guild[0], world.index_for_id("guild_house"), {}, [], guild.slice(0, count))
		await process_frame
		await process_frame
		check(reserve.text == "+%d" % (count - 40) and not reserve.disabled and reserve.tooltip_text.contains("Show %d more heroes" % (count - 40)), "The overflow control keeps a compact count and the exact hidden roster size")
		check(reserve.get_rect().end.x <= 178.0 and roster.hidden_entries().size() == count - 40, "Overflow stays inside the header and retains every hidden hero")
		check(counter.text.contains("Q") and counter.tooltip_text.begins_with("Next hero %d / %d" % [int(large_progress.toward), int(large_progress.span)]), "Overflow and a compact progress readout preserve exact recruitment details together")
		_check_recruitment_geometry(fixture, "%d-hero header" % count)
	var loot_requested: Array[bool] = []
	fixture.loot_requested.connect(func(): loot_requested.append(true))
	fixture.set_loot(3)
	await process_frame
	await process_frame
	var loot := fixture.get_node("TopStrip/LootReady") as Button
	check(loot.visible and not loot.disabled and loot.text == "Loot 3", "The ready loot count is a separate top-right action")
	_check_recruitment_geometry(fixture, "pending loot and recruitment")
	click(loot.get_global_rect().get_center())
	check(loot_requested == [true], "The ready loot action requests the actual pending reward view")
	fixture.set_loot(0)
	check(not loot.visible and loot.disabled, "An empty reward queue hides and disables the loot action")
	fixture.free()


func _check_recruitment_geometry(hud: ArenicWorldHUD, context: String) -> void:
	var top := hud.get_node("TopStrip") as Control
	var counter := top.get_node("GuildRolls") as Label
	var ready := top.get_node("RollsReady") as Button
	var loot := top.get_node("LootReady") as Button
	var controls: Array[Control] = [counter, top.get_node("ArenaTitle")]
	for button: Button in [ready, loot]:
		if button.visible:
			controls.append(button)
	var measured: float = counter.get_theme_font("font").get_string_size(counter.text, HORIZONTAL_ALIGNMENT_LEFT, -1, counter.get_theme_font_size("font_size")).x
	check(counter.size.x >= measured, "The next-hero counter fits its actual font metrics: " + context)
	var fits: bool = true
	var separate: bool = true
	for index: int in controls.size():
		var rect: Rect2 = controls[index].get_rect()
		fits = fits and Rect2(Vector2.ZERO, top.size).encloses(rect)
		for later: int in range(index + 1, controls.size()):
			separate = separate and not rect.intersects(controls[later].get_rect())
	check(fits and separate, "Arena title and right-aligned reward controls fit without overlap: " + context)
	check(counter.position.x > hud.size.x * 0.5 and not hud.has_node("BottomStrip/GuildRolls") and not hud.has_node("BottomStrip/RollsReady"), "Recruitment belongs to the top-right navigation: " + context)


func _check_overflow_fixture() -> void:
	var fixture := ArenicRosterStrip.new()
	fixture.position = Vector2(200.0, 100.0)
	fixture.size = Vector2(160.0, 64.0)
	root.add_child(fixture)
	var entries: Array[Dictionary] = []
	for index: int in 41:
		entries.append({"identity": 1000 + index, "name": "Fixture %d" % index, "class": "Warrior", "initial": "W", "dead": index == 0})
	fixture.set_roster(entries, 1040, ArenicHudTokens.color("content"), ArenicHudTokens.color("selection"))
	fixture.character_requested.connect(func(identity: int): requested_identities.append(identity))
	await process_frame
	check(fixture._visible_indices.size() == 40 and fixture._entry_at(_slot_center(39)) == 40, "A selected 41st identity occupies the last visible marker")
	var hidden: Array[Dictionary] = fixture.hidden_entries()
	check(hidden.size() == 1 and int(hidden[0].identity) == 1039, "Overflow exposes the displaced identity instead of losing it")
	check(fixture._get_tooltip(_slot_center(0)).contains("Fallen"), "Dead markers identify their fallen state without relying only on color")
	click(fixture.global_position + _slot_center(0))
	check(requested_identities.is_empty(), "A dead roster marker rejects pointer selection")
	click(fixture.global_position + _slot_center(39))
	check(requested_identities == [1040], "The selected overflow marker requests its real identity through pointer hit testing")
	check(fixture._entry_at(Vector2(-1.0, 0.0)) == -1 and fixture._entry_at(Vector2(160.0, 0.0)) == -1 and fixture._entry_at(Vector2(0.0, 64.0)) == -1, "Roster hit testing excludes every outer boundary")
	fixture.set_roster(entries, 1001, ArenicHudTokens.color("content"), ArenicHudTokens.color("selection"))
	hidden = fixture.hidden_entries()
	check(hidden.size() == 1 and int(hidden[0].identity) == 1040, "Selecting a normal marker returns the 41st identity to overflow")
	fixture.free()


func _slot_center(slot: int) -> Vector2:
	return Vector2(float(slot % 10) * 16.0 + 7.0, floorf(float(slot) / 10.0) * 16.0 + 7.0)


func press(code: Key) -> void:
	key(code, true)
	key(code, false)


func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	root.push_input(event, true)


func click(position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	event.global_position = position
	root.push_input(event, true)
	var released := event.duplicate() as InputEventMouseButton
	released.pressed = false
	root.push_input(released, true)
