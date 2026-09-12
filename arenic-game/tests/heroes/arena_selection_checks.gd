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

	await _check_first_visit()
	await _check_remembers()
	await _check_tab_cycles_and_caches()
	await _check_empty_arena_is_skipped()
	await _check_leaving_clears()
	await _check_ghost_still_asks()
	await _finish()


## Arriving somewhere for the first time takes the first member standing there.
func _check_first_visit() -> void:
	check(shell.hero == founder, "The founder is controlled to begin with")
	shell.paginate_arena(shell.stage.world.index_for_id(LABYRINTH))
	await physics_frame
	check(shell.hero == second, "Arriving with no memory takes the first member found")
	check(setup.selection_for(LABYRINTH) == second.identity_id, "And the arena remembers them")
	check(setup.selection_for(GUILD) == founder.identity_id, "The arena left behind still remembers its own")


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


## An arena with nobody in it changes nothing.
func _check_empty_arena_is_skipped() -> void:
	var before: ArenicHeroState = shell.hero
	check(setup.heroes_in(SANCTUM).is_empty(), "The Sanctum has no members")
	shell.paginate_arena(shell.stage.world.index_for_id(SANCTUM))
	await physics_frame
	check(shell.hero == before, "Paginating to an empty arena keeps the hero you had")
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


func _finish() -> void:
	shell.free()
	await process_frame
	check(await RETIRE_AUDIO.wait_for_mixer(self), "Stopped audio resources retire before test exit")
	print("Arena selection checks: %d assertions, %s." % [checks, "FAILED" if failed else "passed"])
	quit(1 if failed else 0)
