extends SceneTree
## Each arena remembers who you last controlled there, and hands them back when
## you return. Godot --headless --path arenic-game --script res://tests/heroes/arena_selection_checks.gd

const SHELL_PATH: String = "res://scenes/game/game_shell.tscn"
const RETIRE_AUDIO: GDScript = preload("res://tests/support/audio_retirement.gd")
const GUILD: String = "guild_house"
const LABYRINTH: String = "labyrinth"
const SANCTUM: String = "sanctum"

var checks: int = 0
var failed: bool = false
var shell: Variant
var setup: Node
var founder: ArenicHeroState
var second: ArenicHeroState
var third: ArenicHeroState


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("Arena selection: " + message)


func _run() -> void:
	create_timer(40.0).timeout.connect(func():
		push_error("Arena selection checks timed out")
		quit(1))
	setup = root.get_node("RunSetup")
	setup.begin_new_game()
	setup.intro_step = 6 # Established gameplay fixture; prologue is tested separately.
	setup.choose_class(load("res://data/classes/hunter.tres"))
	shell = load(SHELL_PATH).instantiate()
	root.add_child(shell)
	await process_frame
	founder = shell.hero
	second = setup.recruit(load("res://data/classes/warrior.tres"))
	third = setup.recruit(load("res://data/classes/thief.tres"))
	await process_frame
	# Put two in the Labyrinth and leave the founder at the Guild House.
	second.arena_id = LABYRINTH
	second.cell = Vector2i(20, 10)
	third.arena_id = LABYRINTH
	third.cell = Vector2i(40, 20)
	await physics_frame
	await physics_frame
	check(not shell.zoomed and _no_selected_heroes(), "Established overview starts without an actively selected hero")
	check(setup.selected_identity == founder.identity_id and setup.selection_for(GUILD) == founder.identity_id,
		"Overview preserves the remembered founder without selecting it")
	check(_roster_selection() == -1, "Overview has no blue selected roster slot")

	await _check_first_visit()
	await _check_remembers()
	await _check_tab_cycles_and_caches()
	await _check_empty_arena_is_skipped()
	await _check_leaving_clears()
	await _check_ghost_still_asks()
	await _check_overview_and_save_selection()
	await _check_overworld_menu_lifecycle()
	await _finish()


## Arriving somewhere for the first time takes the first member standing there.
func _check_first_visit() -> void:
	check(shell.hero == founder, "The founder is controlled to begin with")
	shell.paginate_arena(shell.stage.world.index_for_id(LABYRINTH))
	await physics_frame
	check(shell.hero == second, "Arriving with no memory takes the first member found")
	check(setup.selection_for(LABYRINTH) == second.identity_id, "And the arena remembers them")
	check(setup.selection_for(GUILD) == founder.identity_id, "The arena left behind still remembers its own")
	check(_no_selected_heroes() and _roster_selection() == -1,
		"Overview arena adoption changes memory without selecting a hero")


## Coming back hands control to whoever you last had there.
func _check_remembers() -> void:
	shell.paginate_arena(shell.stage.world.index_for_id(GUILD))
	await physics_frame
	check(shell.hero == founder, "Returning to the Guild House restores its member")
	shell.paginate_arena(shell.stage.world.index_for_id(LABYRINTH))
	await physics_frame
	check(shell.hero == second, "And the Labyrinth restores its own rather than starting over")


## Tab cycles the members present, and each stop updates what is remembered.
func _check_tab_cycles_and_caches() -> void:
	shell.set_zoomed(true)
	await physics_frame
	check(shell.hero == second, "Cycling starts from the member in control")
	check(not shell.hero.selected, "Plain zoom does not select the remembered hero")
	shell.select_hero()
	await physics_frame
	check(shell.hero == second and shell.hero.selected, "The first Tab focuses the remembered hero without cycling")
	shell.select_hero()
	await physics_frame
	check(shell.hero == third, "Tab advances to the next member in this arena")
	check(setup.selection_for(LABYRINTH) == third.identity_id, "Cycling updates what the arena remembers")
	shell.select_hero()
	await physics_frame
	check(shell.hero == second, "Tab wraps around the members present")
	check(setup.selection_for(LABYRINTH) == second.identity_id, "And the memory follows the wrap")
	# Leave and return: the arena hands back the one cycling left selected.
	shell.select_hero()
	await physics_frame
	check(shell.hero == third, "Cycled to the third member")
	shell.paginate_arena(shell.stage.world.index_for_id(GUILD))
	await physics_frame
	shell.paginate_arena(shell.stage.world.index_for_id(LABYRINTH))
	await physics_frame
	check(shell.hero == third, "Returning restores the member cycling left in control")


## An empty arena preserves identity memory without retaining active selection.
func _check_empty_arena_is_skipped() -> void:
	var before: ArenicHeroState = shell.hero
	check(setup.heroes_in(SANCTUM).is_empty(), "The Sanctum has no members")
	shell.paginate_arena(shell.stage.world.index_for_id(SANCTUM))
	await physics_frame
	check(shell.hero == before and not before.selected, "An empty arena retains identity memory but no remote selection")
	check(setup.selection_for(SANCTUM) == -1, "And leaves it with nothing to remember")


## A member walking out takes that arena's memory with it.
func _check_leaving_clears() -> void:
	shell.paginate_arena(shell.stage.world.index_for_id(LABYRINTH))
	await physics_frame
	check(shell.hero == third and setup.selection_for(LABYRINTH) == third.identity_id, "The Labyrinth remembers the third member")
	# Another member leaving must NOT erase a memory that is still valid.
	second.arena_id = SANCTUM
	shell._relocate_selection(second, LABYRINTH)
	check(setup.selection_for(LABYRINTH) == third.identity_id, "Someone else leaving does not erase a memory still pointing at a member who is there")
	# The remembered member leaving does.
	var left_from: String = third.arena_id
	third.arena_id = SANCTUM
	shell._relocate_selection(third, left_from)
	check(setup.selection_for(LABYRINTH) == -1, "The remembered member leaving clears that arena's memory")
	check(setup.selection_for(SANCTUM) == third.identity_id, "And the arena they walked into remembers them instead")
	# The Labyrinth is empty now, so it hands over nobody.
	shell.paginate_arena(shell.stage.world.index_for_id(GUILD))
	await physics_frame
	shell.paginate_arena(shell.stage.world.index_for_id(LABYRINTH))
	await physics_frame
	check(shell.hero == founder, "An arena emptied of members hands control to nobody")


## Selecting a ghost is fine; moving or recording it still asks first.
func _check_ghost_still_asks() -> void:
	third.arena_id = GUILD
	third.cell = Vector2i(28, 15)
	await physics_frame
	await physics_frame
	shell.paginate_arena(shell.stage.world.index_for_id(GUILD))
	shell.set_zoomed(true)
	await physics_frame
	var staff := ArenicRecording.create(third.cell, [ArenicTimelineEvent.move(30, Vector2i.RIGHT)] as Array[ArenicTimelineEvent])
	third.recordings[GUILD] = staff
	shell.encounter.fold_ghost(third, staff)
	_complete_restart(GUILD)
	await physics_frame
	check(shell.encounter.is_ghost(third), "The third member is a ghost in the Guild House")
	# Paginate away and back: the arena may hand control to a ghost freely.
	shell.paginate_arena(shell.stage.world.index_for_id(LABYRINTH))
	await physics_frame
	setup.remember_selection(GUILD, third.identity_id)
	shell.paginate_arena(shell.stage.world.index_for_id(GUILD))
	await physics_frame
	check(shell.hero == third, "An arena hands control to a remembered ghost without asking anything")
	check(not shell.modal.is_open(), "Selecting a ghost opens no modal")
	# But moving it does.
	var event := InputEventKey.new()
	event.physical_keycode = KEY_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	# A parsed event is dispatched on an idle frame; wait for one before the
	# physics step that would consume it, or a loaded runner can race past it.
	await process_frame
	await physics_frame
	await physics_frame
	check(shell.modal.is_open(), "Moving a selected ghost still asks before breaking it out")
	shell.modal.choose(2)
	await physics_frame
	# And so does recording over it.
	shell._handle_record_key()
	check(shell.modal.is_open(), "Recording over a selected ghost still asks first")
	shell.modal.choose(1)
	await physics_frame


## Old overview saves remain valid, while a close-view save retains explicit
## selection or deselection through the shell's temporary overview mount.
func _check_overview_and_save_selection() -> void:
	shell.free()
	await process_frame
	setup.begin_new_game()
	setup.intro_step = 6
	setup.choose_class(load("res://data/classes/hunter.tres"))
	founder = setup.get_hero()
	second = setup.recruit(load("res://data/classes/warrior.tres"))
	second.cell = Vector2i(31, 15)
	shell = load(SHELL_PATH).instantiate()
	root.add_child(shell)
	shell.set_physics_process(false)
	await process_frame
	check(not shell.zoomed and _no_selected_heroes(), "Fresh shell mount normalizes the founder's default selected flag")
	await _tab()
	check(shell.zoomed and shell.hero == founder and founder.selected, "Real Tab from overview zooms and focuses the remembered founder")
	await _tab()
	check(shell.hero == second and second.selected, "The next real Tab cycles the focused roster")
	var identity: int = setup.selected_identity
	var memories: Dictionary = setup.arena_selection.duplicate()
	shell.set_zoomed(false)
	check(_no_selected_heroes() and _roster_selection() == -1, "Returning to overview clears model and roster selection")
	check(setup.selected_identity == identity and setup.arena_selection == memories,
		"Returning to overview retains identity and every arena memory")
	shell.set_zoomed(true)
	check(_no_selected_heroes(), "Zooming in alone leaves the roster unselected")
	await _tab()
	check(shell.hero == second and second.selected, "First Tab after zoom focuses the remembered member rather than cycling")

	shell.set_zoomed(false)
	await _click_roster(0)
	check(shell.zoomed and shell.hero == founder and founder.selected,
		"A real roster click from overview zooms before explicitly selecting that member")
	check(_roster_selection() == founder.identity_id, "The clicked member receives the selected roster fill")
	shell.combat.sync_allies(shell.heroes)
	var selected_payload: Dictionary = ArenicSaveCodec.capture_run(setup, shell)
	check(ArenicSaveCodec.validate(selected_payload).is_empty(), "The selected close-view checkpoint is valid")
	await _restore_selection(selected_payload)
	check(shell.zoomed and shell.hero.selected and _roster_selection() == shell.hero.identity_id,
		"A selected close-view checkpoint survives initial overview construction")

	var deselected_payload: Dictionary = selected_payload.duplicate(true)
	for member: Dictionary in deselected_payload.run.heroes:
		member.selected = false
	check(ArenicSaveCodec.validate(deselected_payload).is_empty(), "Explicit close-view deselection remains a valid saved state")
	await _restore_selection(deselected_payload)
	check(shell.zoomed and _no_selected_heroes() and _roster_selection() == -1,
		"A deselected close-view checkpoint never silently selects its remembered hero")

	var legacy_overview: Dictionary = selected_payload.duplicate(true)
	legacy_overview.schema_version = 4
	legacy_overview.run.erase("loot")
	legacy_overview.run.combat.erase("encounter")
	legacy_overview.run.erase("gathering")
	legacy_overview.run.combat.erase("enemy_dots")
	for arena: Dictionary in legacy_overview.world.arenas.values():
		arena.erase("restart_pending")
	legacy_overview.world.zoomed = false
	var migrated: Dictionary = ArenicSaveMigrations.upgrade(legacy_overview)
	check(migrated.ok and migrated.payload.schema_version == ArenicSaveCodec.SCHEMA_VERSION
		and ArenicSaveCodec.validate(migrated.payload).is_empty(),
		"Existing schema-4 overview saves with a selected flag migrate through the current contract")
	if not migrated.ok:
		return
	await _restore_selection(migrated.payload)
	check(not shell.zoomed and _no_selected_heroes() and _roster_selection() == -1,
		"Legacy overview selection normalizes after restoration")
	check(setup.selected_identity == int(legacy_overview.run.selected_identity)
		and setup.arena_selection == legacy_overview.run.arena_selection,
		"Legacy normalization preserves all remembered identities")
	var normalized: Dictionary = ArenicSaveCodec.capture_run(setup, shell)
	check(ArenicSaveCodec.validate(normalized).is_empty(), "Normalized overview captures through the unchanged save codec")
	for member: Dictionary in normalized.run.heroes:
		check(not member.selected, "Every hero is unselected in the next overview checkpoint")
	await _tab()
	check(shell.zoomed and shell.hero.selected, "Tab can select the restored overview's remembered hero")
	var before_replace: int = setup.selected_identity
	shell.replace_stage(shell.stage_scene)
	check(not shell.zoomed and _no_selected_heroes() and _roster_selection() == -1,
		"Stage replacement consistently returns to an unselected overview")
	check(setup.selected_identity == before_replace, "Stage replacement keeps the remembered member")


func _restore_selection(payload: Dictionary) -> void:
	# Exercise the JSON boundary and the same run→scene→world hydration order as
	# Continue; no storage adapter or extra save format is needed for UI selection.
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(payload))
	shell.free()
	await process_frame
	check(ArenicSaveCodec.restore_run(parsed, setup), "Selection fixture restores its complete run")
	shell = load(SHELL_PATH).instantiate()
	root.add_child(shell)
	shell.set_physics_process(false)
	check(not shell.zoomed and _no_selected_heroes(), "Hydration begins with a neutral overview scene")
	check(ArenicSaveCodec.restore_shell(parsed, shell), "Selection fixture restores its complete world")
	await process_frame


func _check_overworld_menu_lifecycle() -> void:
	var ghost: ArenicHeroState = setup.hero_for(1)
	var start: Vector2i = ghost.cell
	var staff := ArenicRecording.create(start, [ArenicTimelineEvent.move(3, Vector2i.RIGHT)] as Array[ArenicTimelineEvent])
	ghost.recordings[GUILD] = staff
	shell.encounter.fold_ghost(ghost, staff)
	_complete_restart(GUILD)
	# Model the pending device intent that an opening overlay must retire before
	# the next simulation step; the actual menu opening goes through its hotkey.
	var pending := InputEventKey.new()
	pending.physical_keycode = KEY_LEFT
	pending.pressed = true
	shell._hero_input.accept(pending)
	shell._cast_queued = true
	shell._space_held = true
	shell._slot_held = true
	shell._button_held = true
	await _menu_key(KEY_3)
	check(shell.overworld_menu.is_open() and shell.overworld_menu.active_action() == &"loot",
		"An overview hotkey opens the corresponding tools tab")
	check(shell._hero_input.consume() == Vector2i.ZERO and not shell._cast_queued
		and not shell._space_held and not shell._slot_held and not shell._button_held,
		"Opening tools clears pending movement, cast intent, and held controls")
	check(not paused and not shell.encounter.is_paused(GUILD) and not shell.encounter.is_paused(LABYRINTH),
		"The tools overlay does not pause the scene or arena clocks")
	var identity: int = setup.selected_identity
	await _menu_key(KEY_TAB)
	await _menu_key(KEY_SPACE)
	await _menu_key(KEY_R)
	await _click_roster(1)
	check(setup.selected_identity == identity and _no_selected_heroes() and not shell.zoomed,
		"Menu keyboard and real roster pointer input cannot select or control heroes behind it")
	check(shell.session.is_idle() and not shell._cast_queued,
		"Menu shortcuts do not start recording or queue combat")
	var tick: int = shell.encounter.cycle_position(GUILD)
	var remote_tick: int = shell.encounter.cycle_position(LABYRINTH)
	var music_time: float = shell.music.clocks[&"guild_house"].elapsed_seconds
	shell.set_physics_process(true)
	for frame: int in 8:
		await physics_frame
	shell.set_physics_process(false)
	await process_frame
	check(shell.encounter.cycle_position(GUILD) > tick and shell.encounter.cycle_position(LABYRINTH) > remote_tick,
		"Focused and remote encounter clocks continue while tools are open")
	check(ghost.cell == start + Vector2i.RIGHT, "A real folded ghost executes its recorded movement behind tools")
	check(shell.music.clocks[&"guild_house"].elapsed_seconds > music_time,
		"Music time also continues while tools are open")
	var open_payload: Dictionary = ArenicSaveCodec.capture_run(setup, shell)
	check(ArenicSaveCodec.validate(open_payload).is_empty() and open_payload.world.modal.is_empty(),
		"Saving with tools open captures a valid continuing world without a gameplay decision")
	await _restore_selection(open_payload)
	check(not shell.overworld_menu.is_open(), "Continue reconstructs transient tools closed")

	# Advance a real recording session to its final tick, so the shell's normal
	# automatic full-take branch, rather than a direct modal call, owns the test.
	shell.session.arm(shell.hero)
	for frame: int in ArenicRecordingSession.COUNTDOWN_TICKS:
		shell.session.advance_countdown()
	shell.encounter.seek(GUILD, shell.encounter.cycle_ticks(GUILD) - 2)
	await _menu_key(KEY_2)
	check(shell.overworld_menu.is_open() and shell.session.is_recording(),
		"Tools can be open while an existing recording reaches its capacity")
	shell.set_physics_process(true)
	await physics_frame
	await physics_frame
	shell.set_physics_process(false)
	await process_frame
	check(shell.modal.is_open() and not shell.overworld_menu.is_open(),
		"An automatically full take closes tools before displaying its real decision")
	check(shell.encounter.is_paused(GUILD) and not shell.encounter.is_paused(LABYRINTH),
		"Only the real decision's recording arena pauses")
	shell.modal.choose(1) # Discard the test draft and resume its arena.


func _complete_restart(arena_id: String) -> void:
	var automatic: bool = shell.is_physics_processing()
	shell.set_physics_process(false)
	check(shell.encounter.is_restart_pending(arena_id), "Folding a replay first holds its arena for the cosmetic restart")
	var held: bool = true
	var counted: bool = false
	for tick: int in 902:
		if not shell.encounter.is_restart_pending(arena_id):
			break
		counted = counted or shell.arena_rewind.phase(arena_id) == "countdown"
		shell._physics_process(1.0 / 60.0)
		held = held and shell.encounter.cycle_position(arena_id) == 0
	check(held and counted and not shell.encounter.is_restart_pending(arena_id), "The real countdown completes before testing forward replay input")
	shell.set_physics_process(automatic)


func _menu_key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	await process_frame


func _no_selected_heroes() -> bool:
	for member: ArenicHeroState in shell.heroes:
		if member.selected:
			return false
	return true


func _roster_selection() -> int:
	return shell.hud.get_node("BottomStrip/CharacterRoster").selected_identity


func _tab() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_TAB
	event.physical_keycode = KEY_TAB
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	await process_frame


func _click_roster(slot: int) -> void:
	var roster: Control = shell.hud.get_node("BottomStrip/CharacterRoster")
	var point: Vector2 = roster.get_global_rect().position + Vector2(slot * ArenicRosterStrip.CELL + 7.0, 7.0)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		# The point comes from logical Control geometry. Push it through the
		# actual viewport GUI dispatch without treating it as native window pixels.
		root.push_input(event, true)
		await process_frame
		await process_frame


func _finish() -> void:
	shell.free()
	await process_frame
	check(await RETIRE_AUDIO.wait_for_mixer(self), "Stopped audio resources retire before test exit")
	print("Arena selection checks: %d assertions, %s." % [checks, "FAILED" if failed else "passed"])
	quit(1 if failed else 0)
