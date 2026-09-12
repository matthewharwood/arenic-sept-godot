extends SceneTree
## The whole loop in the real shell: record a hero, commit it, and watch the
## ghost replay the same path every cycle.
## Godot --headless --path arenic-game --script res://tests/encounters/recording_flow_checks.gd

const SHELL_PATH: String = "res://scenes/game/game_shell.tscn"
const RETIRE_AUDIO: GDScript = preload("res://tests/support/audio_retirement.gd")
const GUILD: String = "guild_house"

var checks: int = 0
var failed: bool = false
var shell: Variant
var setup: Node
var start_cell: Vector2i


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("Recording: " + message)


func _run() -> void:
	create_timer(60.0).timeout.connect(func():
		push_error("Recording flow timed out")
		quit(1))
	setup = root.get_node("RunSetup")
	setup.begin_new_game()
	setup.choose_class(load("res://data/classes/hunter.tres"))
	shell = load(SHELL_PATH).instantiate()
	root.add_child(shell)
	await process_frame
	shell.select_hero()
	await physics_frame
	check(shell.hero.selected and shell.zoomed, "The hero is focused before recording")

	await _check_countdown()
	await _check_capture()
	await _check_commit_makes_a_ghost()
	await _check_ghost_replays_every_cycle()
	await _check_ghost_refuses_input()
	await _check_record_over_a_ghost()
	await _check_ghost_casts()
	await _check_break_out()
	await _check_ghost_dies_in_place()
	await _check_travel_decisions()
	await _check_cap_and_readout()
	await _finish()


## R with no staff here goes straight to the countdown; the arena holds at zero.
func _check_countdown() -> void:
	check(shell.session.is_idle(), "No recording is in flight at rest")
	shell._handle_record_key()
	check(not shell.modal.is_open(), "A hero with no staff here is asked nothing")
	check(shell.session.is_counting_down(), "R arms the countdown")
	check(shell.encounter.cycle_position(GUILD) == 0, "The recording arena is held at the top of its cycle")
	check(shell.encounter.is_paused(GUILD), "Only that arena pauses")
	check(not shell.encounter.is_paused("labyrinth"), "The other arenas keep performing")
	var moved_before: Vector2i = shell.hero.cell
	await _arrow(KEY_RIGHT)
	check(shell.hero.cell == moved_before, "Input is ignored until capture begins")
	check(shell.session.events.is_empty(), "Nothing is captured during the countdown")
	# R again aborts: nothing has been captured, so it costs nothing.
	shell._handle_record_key()
	check(shell.session.is_idle() and not shell.encounter.is_paused(GUILD), "R during the countdown aborts it and resumes the arena")


## Capture is intent, written where the live effect happened.
func _check_capture() -> void:
	shell._handle_record_key()
	for frame: int in ArenicRecordingSession.COUNTDOWN_TICKS + 2:
		await physics_frame
	check(shell.session.is_recording(), "Capture begins when the countdown reaches zero")
	check(not shell.encounter.is_paused(GUILD), "The arena runs again once capture starts")
	start_cell = shell.hero.cell
	for step: int in 3:
		await _arrow(KEY_RIGHT)
	await _arrow(KEY_UP)
	check(shell.hero.cell == start_cell + Vector2i(3, 1), "The live steps applied")
	check(shell.session.events.size() == 4, "Each applied step is captured once")
	var ticks: Array = []
	for event: ArenicTimelineEvent in shell.session.events:
		ticks.append(event.tick)
	check(ticks == ticks.duplicate() and ticks[0] < ticks[3], "Events are stamped in ascending cycle ticks")
	check(shell.session.events[0].action_id == ArenicTimelineEvent.MOVE, "A step is captured as move intent")
	check(shell.session.start_cell == start_cell, "The staff remembers the tile it started from")


## Commit folds the staff in, caches it, and restarts the arena.
func _check_commit_makes_a_ghost() -> void:
	var events: int = shell.session.events.size()
	shell._handle_record_key()
	check(shell.modal.is_open(), "R mid-recording asks before anything is lost")
	shell.modal.choose(0)
	await physics_frame
	check(shell.session.is_idle(), "Committing ends the session")
	check(shell.hero.recordings.has(GUILD), "The staff is cached against the arena it was recorded in")
	check(shell.hero.recordings[GUILD].events.size() == events, "The cached staff holds every captured event")
	check(shell.encounter.is_ghost(shell.hero), "The hero is now a ghost")
	check(shell.encounter.timeline(GUILD).has(shell.hero.ally_id()), "Its staff is folded into the arena's stream")
	check(shell.hero.cell == start_cell, "Committing returns it to the tile its staff replays from")
	check(shell.encounter.cycle_position(GUILD) <= 1, "The arena restarts so the ghost plays from the top")


## The whole point: the same path, every cycle, without the player.
func _check_ghost_replays_every_cycle() -> void:
	var ghost: ArenicHeroState = shell.hero
	shell.encounter.seek(GUILD, 0)
	shell.encounter.snap_ghosts(GUILD)
	var last_tick: int = ghost.recordings[GUILD].last_tick()
	for frame: int in last_tick + 4:
		await physics_frame
	var first_pass: Vector2i = ghost.cell
	check(first_pass == start_cell + Vector2i(3, 1), "The ghost walked the recorded path on its own")
	# Wrap the cycle and confirm it does exactly the same thing again.
	shell.encounter.seek(GUILD, shell.encounter.cycle_ticks(GUILD) - 2)
	await physics_frame
	await physics_frame
	await physics_frame
	check(ghost.cell == start_cell, "Wrapping the cycle returns the ghost to its start tile")
	for frame: int in last_tick + 4:
		await physics_frame
	check(ghost.cell == first_pass, "The second cycle reproduces the first exactly")


## Arrows never drive a ghost — they ask whether to take it out of the score.
func _check_ghost_refuses_input() -> void:
	var held: Vector2i = shell.hero.cell
	await _arrow(KEY_LEFT)
	check(shell.hero.cell == held, "Arrow input does not move a ghost directly")
	check(shell.modal.is_open(), "It asks about breaking out instead")
	shell.modal.choose(2) # Cancel
	await physics_frame
	check(shell.encounter.is_ghost(shell.hero) and shell.hero.cell == held, "Declining leaves the ghost folded and still")


## R on a ghost offers to record over it; doing so unfolds the old staff first.
func _check_record_over_a_ghost() -> void:
	shell._handle_record_key()
	check(shell.modal.is_open(), "R on a ghost asks before discarding its staff")
	shell.modal.choose(0)
	await physics_frame
	check(not shell.encounter.is_ghost(shell.hero), "Recording anew takes the old staff out of the stream")
	check(shell.session.is_counting_down(), "It then starts a fresh countdown")
	check(shell.hero.recordings.has(GUILD), "The cached staff survives until a new one replaces it")
	shell._handle_record_key()
	check(shell.session.is_idle(), "Aborting leaves the hero free rather than half-folded")


## The point of a ghost: it fights on its own, every cycle, with no input.
func _check_ghost_casts() -> void:
	# Record a single Auto Shot at the Guild House target.
	shell._handle_record_key()
	shell.modal.choose(0) # Record new
	for frame: int in ArenicRecordingSession.COUNTDOWN_TICKS + 2:
		await physics_frame
	check(shell.session.is_recording(), "A fresh take is running")
	var before_live: int = shell.combat.damage_for_arena(GUILD)
	shell._queue_cast()
	for frame: int in 70:
		await physics_frame
	check(shell.combat.damage_for_arena(GUILD) > before_live, "The live cast landed on the target")
	var casts: int = 0
	var cast_tick: int = -1
	for event: ArenicTimelineEvent in shell.session.events:
		if event.action_id == ArenicTimelineEvent.ABILITY:
			casts += 1
			cast_tick = event.tick
	check(casts == 1 and cast_tick >= 0, "The accepted cast is captured once, at the tick it was accepted")

	shell._handle_record_key()
	shell.modal.choose(0) # Commit
	await physics_frame
	check(shell.encounter.is_ghost(shell.hero), "The hero is a ghost again")
	check(shell.combat.cooldown_remaining(shell.hero) == 0.0, "Committing clears the cooldown, so the first replayed cycle matches every later one")

	# Now stand back. The ghost should fight without any input at all.
	var before_ghost: int = shell.combat.damage_for_arena(GUILD)
	for frame: int in cast_tick + 80:
		await physics_frame
	var after_first: int = shell.combat.damage_for_arena(GUILD)
	check(after_first > before_ghost, "The ghost cast on its own, with no player input")

	# And it must do exactly the same thing on the next cycle.
	shell.encounter.restart(GUILD)
	for frame: int in cast_tick + 80:
		await physics_frame
	check(shell.combat.damage_for_arena(GUILD) - after_first == after_first - before_ghost, "The second cycle deals exactly the same damage as the first")


## Break-out is the one path that does not rewind the arena.
func _check_break_out() -> void:
	check(shell.encounter.is_ghost(shell.hero), "The hero is a ghost before breaking out")
	shell.encounter.seek(GUILD, 900)
	await physics_frame
	await _arrow(KEY_LEFT)
	check(shell.modal.is_open(), "An arrow on a ghost asks before pulling it out of the score")
	check(shell.encounter.is_paused(GUILD), "The decision pauses only that arena")
	# Cancel changes nothing.
	shell.modal.choose(2)
	await physics_frame
	check(shell.encounter.is_ghost(shell.hero) and not shell.encounter.is_paused(GUILD), "Cancelling leaves it folded and resumes the arena")
	# Restart rewinds but keeps the hero folded.
	await _arrow(KEY_LEFT)
	shell.modal.choose(1)
	await physics_frame
	check(shell.encounter.cycle_position(GUILD) <= 2, "Restart rewinds the arena to the top of the cycle")
	check(shell.encounter.is_ghost(shell.hero), "And the hero stays a ghost")
	# Take control unfolds without rewinding.
	shell.encounter.seek(GUILD, 1800)
	await physics_frame
	await _arrow(KEY_LEFT)
	shell.modal.choose(0)
	await physics_frame
	check(not shell.encounter.is_ghost(shell.hero), "Take control unfolds the hero")
	check(shell.encounter.cycle_position(GUILD) > 1700, "And the arena keeps playing rather than restarting")
	check(not shell.encounter.timeline(GUILD).has(shell.hero.ally_id()), "Its events left the stream")
	check(shell.hero.recordings.has(GUILD), "The cached staff survives a break-out")
	var held: Vector2i = shell.hero.cell
	await _arrow(KEY_LEFT)
	check(shell.hero.cell == held + Vector2i.LEFT, "A freed hero moves under arrow input again")


## A struck ghost lies where it fell and rises with the cycle.
func _check_ghost_dies_in_place() -> void:
	var staff: ArenicRecording = shell.hero.recordings[GUILD]
	shell.encounter.fold_ghost(shell.hero, staff)
	await physics_frame
	check(shell.encounter.is_ghost(shell.hero), "Folded back in for the death check")
	var ghost: ArenicHeroState = shell.hero
	var home: String = ghost.arena_id
	var fell_at: Vector2i = ghost.cell
	shell.combat.apply_blast(GUILD, Vector2(ghost.cell), 0.4)
	await physics_frame
	await physics_frame
	check(ghost.arena_id == home, "A struck ghost is NOT walked home; that would replay its intent in the wrong arena")
	check(ghost.cell == fell_at, "It lies where it fell")
	check(shell.combat.ally_defeated_at(GUILD, ghost.ally_id()), "And stays down")
	check(shell.encounter.is_ghost(ghost), "Death does not unfold it")
	# Its staff stops: no further movement while it is down.
	var down_at: Vector2i = ghost.cell
	for frame: int in 120:
		await physics_frame
	check(ghost.cell == down_at, "A fallen ghost neither moves nor casts for the rest of the cycle")
	# The cycle restarts and it rises at its start tile.
	shell.encounter.restart(GUILD)
	await physics_frame
	check(not shell.combat.ally_defeated_at(GUILD, ghost.ally_id()), "The next cycle revives it")
	check(ghost.cell == staff.start_cell, "It rises at the tile its staff replays from")


## Walking out of a take, and walking back into a staff.
func _check_travel_decisions() -> void:
	# Free the hero and put it on the Guild House western edge.
	if shell.encounter.is_ghost(shell.hero):
		shell.encounter.unfold_ghost(shell.hero)
	shell.hero.cell = Vector2i(0, 15)
	shell._handle_record_key()
	if shell.modal.is_open():
		shell.modal.choose(0) # Record new
	for frame: int in ArenicRecordingSession.COUNTDOWN_TICKS + 2:
		await physics_frame
	check(shell.session.is_recording(), "A take is running at the arena edge")
	await _arrow(KEY_LEFT)
	check(shell.modal.is_open(), "Stepping out of the arena mid-take asks first")
	check(shell.hero.arena_id == GUILD, "And does not move the hero while it asks")
	shell.modal.choose(0) # Continue recording
	await physics_frame
	check(shell.session.is_recording() and shell.hero.arena_id == GUILD, "Continuing keeps the take and abandons the step")
	await _arrow(KEY_LEFT)
	shell.modal.choose(1) # Cancel & walk out
	await physics_frame
	check(shell.session.is_idle(), "Walking out discards the take")
	check(shell.hero.arena_id != GUILD, "And then performs the step that interrupted it")


## Forty ghosts to an arena, and a map that says where the guild is working.
func _check_cap_and_readout() -> void:
	# Walk the hero home and fold its staff back in so there is one real ghost.
	shell.hero.arena_id = GUILD
	shell.hero.cell = Vector2i(30, 15)
	shell.select_arena(shell.stage.world.index_for_id(GUILD))
	await physics_frame
	shell.encounter.fold_ghost(shell.hero, shell.hero.recordings[GUILD])
	for frame: int in 12:
		await physics_frame
	check(shell.encounter.ghost_count(GUILD) == 1, "The arena counts one ghost, not the boss beside it")
	check(shell.encounter.ghost_count("labyrinth") == 0, "An arena with an authored boss but no staves has no ghosts")
	var guild_cell := shell.hud.get_node("BottomStrip/ArenaCell%d" % shell.stage.world.index_for_id(GUILD)) as Button
	var labyrinth_cell := shell.hud.get_node("BottomStrip/ArenaCell%d" % shell.stage.world.index_for_id("labyrinth")) as Button
	check(guild_cell.text == "1", "The map reports the working arena")
	check(labyrinth_cell.text == "X", "And reads X where nothing of the guild is running")
	check(guild_cell.tooltip_text.contains("1 ghost"), "Its tooltip names the activity: %s" % guild_cell.tooltip_text)
	var strip := shell.hud.get_node("BottomStrip/CharacterRoster") as ArenicRosterStrip
	check(strip.entries.size() == 1 and bool(strip.entries[0].get("ghost", false)), "The roster marks the member as folded")

	# Fill the arena to its cap with fixture staves, then refuse the next fold.
	var timeline: ArenicArenaTimeline = shell.encounter.timeline(GUILD)
	var filler: Array[ArenicTimelineEvent] = [ArenicTimelineEvent.move(30, Vector2i.RIGHT)]
	for index: int in ArenicEncounterState.MAX_GHOSTS_PER_ARENA:
		timeline.fold("hero:%d" % (900 + index), ArenicRecording.create(Vector2i(20, 10), filler))
	check(shell.encounter.ghost_count(GUILD) == 1, "Staves with no guild member behind them are not counted as ghosts")
	# Now make them real by pointing the lookup at actual members.
	var extras: Array[ArenicHeroState] = []
	for index: int in ArenicEncounterState.MAX_GHOSTS_PER_ARENA - 1:
		var member := ArenicHeroState.new()
		member.definition = shell.hero.definition
		member.identity_id = 900 + index
		member.arena_id = GUILD
		extras.append(member)
	shell.heroes.append_array(extras)
	await physics_frame
	check(shell.encounter.ghost_count(GUILD) == ArenicEncounterState.MAX_GHOSTS_PER_ARENA, "Forty staves with members behind them are forty ghosts")
	check(not shell.encounter.can_fold_ghost(extras[0]) or shell.encounter.is_ghost(extras[0]), "A member already folded may always refold")
	var newcomer := ArenicHeroState.new()
	newcomer.definition = shell.hero.definition
	newcomer.identity_id = 2000
	newcomer.arena_id = GUILD
	check(not shell.encounter.can_fold_ghost(newcomer), "A forty-first ghost is refused")
	check(shell.encounter.can_fold_ghost(shell.hero), "The member already folded there is still allowed to re-record")


func _arrow(key: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await physics_frame
	await physics_frame


func _finish() -> void:
	shell.free()
	await process_frame
	check(await RETIRE_AUDIO.wait_for_mixer(self), "Stopped audio resources retire before test exit")
	print("Recording flow checks: %d assertions, %s." % [checks, "FAILED" if failed else "passed"])
	quit(1 if failed else 0)
