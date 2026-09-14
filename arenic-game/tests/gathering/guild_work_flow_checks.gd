extends SceneTree
## Actual shell, run roster, contact callbacks and arena-driven Guild House work.

const SHELL_PATH: String = "res://scenes/game/game_shell.tscn"
const RETIRE_AUDIO: GDScript = preload("res://tests/support/audio_retirement.gd")
const GUILD: String = "guild_house"
const STEP_SECONDS: float = 1.0 / 60.0

var _checks: int = 0
var _failed: bool = false
var shell: Variant
var setup: Node
var members: Array[ArenicHeroState] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	create_timer(60.0).timeout.connect(func():
		push_error("Guild work flow timed out")
		quit(1))
	setup = root.get_node("RunSetup")
	setup.begin_new_game()
	setup.intro_step = 6 # Established gameplay; onboarding is covered separately.
	setup.choose_class(load("res://data/classes/forager.tres"))
	shell = load(SHELL_PATH).instantiate()
	shell.entry_sequence = null
	root.add_child(shell)
	# Drive the real physics method one whole tick at a time, independent of
	# renderer/audio scheduling. No alternate simulation is used by this fixture.
	shell.set_physics_process(false)
	await process_frame
	for index: int in 3:
		_check(setup.recruit(load("res://data/classes/forager.tres")) != null, "A real recruit joins the shell roster with an empty spawn cell.")
	members = setup.get_heroes()
	_check(shell.gathering == setup.get_gathering() and shell.heroes.size() == 4, "Shell gathering and roster share the authoritative RunSetup models.")
	_check(_living_cells_unique(), "Recruitment places every living member in a distinct cell.")
	_check_stationary_victim()
	_check_selected_ghost()
	_check_countdown()
	_check_banks_and_resets()
	_check_dropoff_death()
	_check_recorded_routes()
	shell.free()
	await process_frame
	_check(await RETIRE_AUDIO.wait_for_mixer(self), "Stopped shell audio retires before native test exit.")
	print("Guild work flow checks: %d assertions %s." % [_checks, "FAILED" if _failed else "passed"])
	quit(1 if _failed else 0)


func _reset_members() -> void:
	shell.modal.close()
	shell.session.clear()
	shell._hero_input.clear()
	shell._cancel_cast_input()
	for arena: String in shell.encounter.arena_ids():
		shell.encounter.set_paused(arena, false)
		if shell.encounter.is_restart_pending(arena):
			_complete_restart(arena)
	for index: int in members.size():
		var member: ArenicHeroState = members[index]
		if shell.encounter.is_ghost(member):
			shell.encounter.unfold_ghost(member)
		member.recordings.clear()
		member.arena_id = GUILD
		member.cell = Vector2i(4 + index * 3, 3)
		member.selected = false
		shell.combat.respawn_hero_ally(member)
		shell.combat.reset_caster(member)
		shell.gathering.clear_hero(member.identity_id)
	_focus(0)


func _place(index: int, cell: Vector2i, arena: String = GUILD) -> void:
	members[index].arena_id = arena
	members[index].cell = cell
	shell.combat.sync_allies(members)


func _focus(index: int) -> void:
	shell.select_arena(shell.stage.world.index_for_id(members[index].arena_id))
	shell.set_zoomed(true)
	shell._select_identity(members[index].identity_id)
	shell._update_hud()


func _ticks(count: int) -> void:
	for index: int in count:
		shell._physics_process(STEP_SECONDS)


func _complete_restart(arena: String) -> void:
	_check(shell.encounter.is_restart_pending(arena) and shell.arena_rewind.phase(arena) in ["rewind", "countdown"], "The reset enters its real rewind/countdown before work resumes.")
	var bank: Array[int] = [shell.gathering.wood_total, shell.gathering.gold_total]
	var held: bool = true
	var counted: bool = false
	for tick: int in 902:
		if not shell.encounter.is_restart_pending(arena):
			break
		counted = counted or shell.arena_rewind.phase(arena) == "countdown"
		_ticks(1)
		held = held and shell.encounter.cycle_position(arena) == 0
	_check(held and counted and not shell.encounter.is_restart_pending(arena), "Actual shell physics completes the visual hold at canonical tick zero.")
	_check([shell.gathering.wood_total, shell.gathering.gold_total] == bank and shell.gathering._bags.is_empty(), "Restart presentation neither gathers nor deposits before forward Guild House ticks.")


func _press(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	shell._unhandled_input(event)


func _bag(index: int) -> Dictionary:
	return shell.gathering.snapshot_for(members[index])


func _living_cells_unique() -> bool:
	var occupied: Dictionary = {}
	for member: ArenicHeroState in members:
		if shell.combat.ally_defeated_at(member.arena_id, member.ally_id()):
			continue
		var key: String = "%s:%d:%d" % [member.arena_id, member.cell.x, member.cell.y]
		if occupied.has(key):
			return false
		occupied[key] = true
	return true


func _check_stationary_victim() -> void:
	_reset_members()
	_place(0, Vector2i(9, 9)) # Just outside the authored wood radius.
	_place(1, Vector2i(10, 9))
	_place(2, Vector2i(30, 15)) # Occupy the usual respawn center.
	_focus(0)
	_ticks(7)
	_check(_bag(0).phase == "idle" and _bag(1).fill_ticks == 7, "Only the stationary member inside the authored wood radius gathers.")
	_press(KEY_RIGHT)
	_ticks(1)
	_check(members[0].cell == Vector2i(10, 9) and _bag(0).fill_ticks == 1, "Live movement wins contact before gathering starts on the newly entered source tile.")
	_check(members[1].arena_id == GUILD and members[1].cell != Vector2i(10, 9) and members[1].cell != Vector2i(30, 15), "The stationary victim respawns in an empty Guild House cell, avoiding the occupied center.")
	_check(not shell.combat.ally_defeated_at(GUILD, members[1].ally_id()) and _living_cells_unique(), "The free victim is restored alive without creating a second collision.")
	_check(_bag(1).phase == "idle" and _bag(1).fill_ticks == 0, "The actual defeat callback clears the victim's partial bag before arena work.")
	_check(shell.hero == members[0] and shell._contact_deaths.is_empty(), "A nonselected death preserves current control and consumes contact provenance once.")


func _check_selected_ghost() -> void:
	_reset_members()
	_place(0, Vector2i(10, 9))
	_place(1, Vector2i(12, 9))
	_place(2, Vector2i(30, 15))
	var first := ArenicRecording.create(members[0].cell, [ArenicTimelineEvent.move(8, Vector2i.RIGHT), ArenicTimelineEvent.ability(8, 1)])
	var second := ArenicRecording.create(members[1].cell, [ArenicTimelineEvent.move(8, Vector2i.LEFT), ArenicTimelineEvent.move(10, Vector2i.UP)])
	members[0].recordings[GUILD] = first
	members[1].recordings[GUILD] = second
	shell.encounter.fold_ghost(members[0], first)
	shell.encounter.fold_ghost(members[1], second)
	_complete_restart(GUILD)
	_focus(0)
	_ticks(8)
	_check(shell.encounter.is_ghost(members[0]) and _bag(0).fill_ticks == 8 and _bag(1).fill_ticks == 8, "Both real folded ghosts gather while their recorded moves are still pending.")
	var casts_before: int = shell.combat._cast_serial
	_press(KEY_1)
	_check(shell._cast_queued, "The input adapter queues the selected ghost's live cast before the contested step.")
	_ticks(1)
	_check(not shell.encounter.is_ghost(members[0]) and members[0].recordings.get(GUILD) == first, "The selected ghost contact victim unfolds while retaining the exact cached staff.")
	_check(members[0].arena_id == GUILD and members[0].cell != Vector2i(11, 9) and members[0].cell != Vector2i(30, 15), "The selected ghost comes home in a vacant cell.")
	_check(not shell.combat.ally_defeated_at(GUILD, members[0].ally_id()) and _bag(0).phase == "idle", "Selected ghost contact restores health and discards its bag.")
	_check(shell.encounter.is_ghost(members[1]) and members[1].cell == Vector2i(11, 9) and _bag(1).fill_ticks == 9, "The other simultaneous mover remains a working ghost on the contested tile.")
	_check(not shell._cast_queued and shell.combat._cast_serial == casts_before, "Neither the queued live cast nor the victim's due recorded ability executes after contact.")
	_check(_living_cells_unique() and shell._contact_deaths.is_empty(), "The final shell state contains no living overlap or stale contact cause.")
	_ticks(1)
	_check(members[1].cell == Vector2i(11, 9), "Unfolding the contact victim mid-tick does not replay the survivor's already-consumed move on the next tick.")
	_ticks(1)
	_check(members[1].cell == Vector2i(11, 8), "The survivor's later recorded move still resolves once at its original tick.")


func _check_countdown() -> void:
	_reset_members()
	_place(0, Vector2i(5, 5), "sanctum")
	_place(1, shell.gathering.definition.wood_sources[0])
	_focus(0)
	shell._handle_record_key()
	_check(shell.session.is_counting_down() and shell.encounter.is_paused("sanctum"), "The real record action starts the selected arena's countdown.")
	var guild_before: int = shell.encounter.cycle_position(GUILD)
	var labyrinth_before: int = shell.encounter.cycle_position("labyrinth")
	_ticks(7)
	_check(shell.encounter.cycle_position("sanctum") == 0 and shell.session.is_counting_down(), "The recorder's own arena stays at tick zero during countdown.")
	_check(shell.encounter.cycle_position(GUILD) == guild_before + 7 and _bag(1).fill_ticks == 7, "Off-camera Guild House gathering continues through another arena's countdown.")
	_check(shell.encounter.cycle_position("labyrinth") == labyrinth_before + 7, "Other encounter clocks continue through countdown as well.")
	shell._handle_record_key()
	_check(shell.session.is_idle() and not shell.encounter.is_paused("sanctum"), "Aborting the countdown releases its arena normally.")


func _check_banks_and_resets() -> void:
	_reset_members()
	_place(0, shell.gathering.definition.wood_sources[0])
	_place(1, shell.gathering.definition.gold_sources[0])
	_ticks(300)
	_check(_bag(0).fill_ticks == 300 and _bag(1).fill_ticks == 300, "Authored five-second wood and gold bags fill through the shell's arena clock.")
	_place(0, shell.gathering.definition.wood_dropoff)
	_place(1, shell.gathering.definition.gold_dropoff)
	_ticks(59)
	_check(_bag(0).unload_ticks == 59 and _bag(1).unload_ticks == 59 and shell.gathering.wood_total == 0 and shell.gathering.gold_total == 0, "Both bags retain exact unload progress without early bank credit.")
	_ticks(1)
	_check(shell.gathering.wood_total == 10 and shell.gathering.gold_total == 10 and _bag(0).phase == "idle" and _bag(1).phase == "idle", "The matching dropoffs deposit both full bags on the exact final tick.")
	_place(0, shell.gathering.definition.wood_sources[0])
	_place(1, Vector2i(4, 3))
	_ticks(300)
	_place(1, shell.gathering.definition.gold_sources[0])
	_ticks(17)
	_check(_bag(0).fill_ticks == 300 and _bag(1).fill_ticks == 17, "The explicit-reset fixture has one full bag and one partial bag.")
	shell.encounter.restart(GUILD)
	_check(_bag(0).phase == "idle" and _bag(1).phase == "idle", "Explicit arena restart clears both full and partial bags through the shell callback.")
	_check(shell.gathering.wood_total == 10 and shell.gathering.gold_total == 10, "Explicit restart preserves both banked totals.")
	_complete_restart(GUILD)
	_place(1, Vector2i(4, 3))
	_ticks(300)
	_place(1, shell.gathering.definition.gold_sources[0])
	_ticks(17)
	_check(_bag(0).fill_ticks == 300 and _bag(1).fill_ticks == 17, "The natural-reset fixture again contains full and partial bags.")
	shell.encounter.seek(GUILD, ArenicCycleClock.CYCLE_TICKS - 1)
	_ticks(1)
	_check(shell.encounter.cycle_position(GUILD) == 0 and _bag(0).phase == "idle" and _bag(1).phase == "idle", "The real final physics tick wraps the cycle and clears both bags.")
	_check(shell.gathering.wood_total == 10 and shell.gathering.gold_total == 10, "Natural cycle wrap also preserves all banked resources.")


func _check_dropoff_death() -> void:
	_reset_members()
	_place(1, shell.gathering.definition.wood_sources[0])
	_ticks(300)
	var dropoff: Vector2i = shell.gathering.definition.wood_dropoff
	_place(1, dropoff)
	_place(0, dropoff + Vector2i.LEFT)
	_focus(0)
	_ticks(59)
	_check(_bag(1).unload_ticks == 59, "A stationary dropoff worker is one tick away from depositing.")
	var bank_before: int = shell.gathering.wood_total
	_press(KEY_RIGHT)
	_ticks(1)
	_check(members[1].cell != dropoff and _bag(1).phase == "idle", "Contact at the dropoff defeats the stationary worker and clears its full bag.")
	_check(shell.gathering.wood_total == bank_before, "The worker cannot deposit on the same tick it was defeated.")
	_check(_living_cells_unique(), "Dropoff contact and respawn leave the whole living roster separated.")


## Exercise both complete work routes and a second loop without waiting for
## real time. Use the real shell/conductor/gathering pipeline, not a mock clock.
func _check_recorded_routes() -> void:
	_reset_members()
	var definition: ArenicGatheringDefinition = shell.gathering.definition
	var starts: Array[Vector2i] = [definition.wood_sources[0] + Vector2i(2, 0), definition.gold_sources[1] - Vector2i(2, 0)]
	var stops: Array[Vector2i] = [definition.wood_dropoff - Vector2i(2, 0), definition.gold_dropoff + Vector2i(2, 0)]
	var before: Array[int] = [shell.gathering.wood_total, shell.gathering.gold_total]
	for index: int in 2:
		_place(index, starts[index])
		var events: Array[ArenicTimelineEvent] = []
		var cell: Vector2i = starts[index]
		var tick: int = 300
		for axis: int in 2:
			while cell[axis] != stops[index][axis]:
				var delta := Vector2i.ZERO
				delta[axis] = signi(stops[index][axis] - cell[axis])
				events.append(ArenicTimelineEvent.move(tick, delta))
				cell += delta
				tick += 10
		var recording := ArenicRecording.create(starts[index], events)
		members[index].recordings[GUILD] = recording
		shell.encounter.fold_ghost(members[index], recording)
	_complete_restart(GUILD)
	_ticks(299)
	_check(_bag(0).fill_ticks == 299 and _bag(1).fill_ticks == 299, "Both recorded routes retain partial bags on the penultimate fill tick.")
	_ticks(1)
	_check(_bag(0).fill_ticks == 300 and _bag(1).fill_ticks == 300, "Both recorded workers fill on exactly tick 300 before their first moves.")
	_ticks(300)
	_check(members[0].cell == stops[0] and members[1].cell == stops[1], "The real conductor executes every wood and gold route move.")
	_check(shell.gathering.wood_total == before[0] + 10 and shell.gathering.gold_total == before[1] + 10, "Both complete recorded routes deposit exactly one load.")
	shell.encounter.seek(GUILD, ArenicCycleClock.CYCLE_TICKS - 1)
	_ticks(1)
	_complete_restart(GUILD)
	_ticks(600)
	_check(shell.gathering.wood_total == before[0] + 20 and shell.gathering.gold_total == before[1] + 20, "Natural restart replays both routes and banks a second load without live input.")


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failed = true
		push_error("Guild work flow: " + message)
