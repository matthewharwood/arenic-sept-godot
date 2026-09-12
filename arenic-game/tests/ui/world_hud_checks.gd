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
	_check_slots(hud)
	check((hud.get_node("BottomStrip/RaidDifficulty") as Label).text == "Raid: Normal", "Raid Normal is informational")
	check(not hud.has_node("GlobalChat") and not hud.has_node("BottomStrip/GlobalChat"), "This iteration has no global chat")

	press(KEY_BRACKETRIGHT)
	check(shell.selected_index == 2 and shell.hero == hero and hero.arena_id == "guild_house", "Right bracket changes the actual selected arena without moving or replacing the hero")
	_check_map(hud, 2)
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

	var guide := hud.get_node("ControlsGuide") as Control
	press(KEY_H)
	check(guide.visible and (guide.get_node("GuideText") as Label).text.contains("[ / ]"), "H opens a guide containing current bracket controls")
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
	check(shell.combat.damage_for_arena("guild_house") == damage_before, "Arming a recording deals no damage")
	press(KEY_R)
	await physics_frame
	check(shell.session.is_idle(), "R again aborts the countdown")
	await _check_ability_input()
	check(shell.hero == hero and roster.entries.size() == 1 and roster.hidden_entries().is_empty(), "HUD interactions never create extra gameplay heroes")
	shell.free()
	setup.begin_new_game()
	await process_frame
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


func _check_slots(hud: ArenicWorldHUD) -> void:
	var first := hud.get_node("BottomStrip/AbilityAction") as Button
	check(first.text == "Sacrifice\n1", "The chosen class's starter occupies fixed slot 1")
	for slot: int in range(2, 5):
		var button := hud.get_node("BottomStrip/AbilitySlot%d" % slot) as Button
		check(button.disabled and button.text == "—\n%d" % slot, "Unassigned ability slot %d remains present and disabled" % slot)
	check(not hud.has_node("BottomStrip/AbilitySlot5"), "There is no fifth ability slot")


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
	check(not shell.combat.is_channeling(shell.hero), "Returning to the hero cannot resume stale held input")


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
