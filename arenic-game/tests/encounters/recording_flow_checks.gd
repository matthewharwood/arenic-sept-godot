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
	setup.intro_step = 6 # Established gameplay fixture; prologue is tested separately.
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
	await _check_dead_ghost_choices()
	await _check_travel_decisions()
	await _check_cap_and_readout()
	await _check_recorded_channel_input()
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
	_complete_restart(GUILD)


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
	_complete_restart(GUILD)
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
	_complete_restart(GUILD)

	# Now stand back. The ghost should fight without any input at all.
	var before_ghost: int = shell.combat.damage_for_arena(GUILD)
	for frame: int in cast_tick + 80:
		await physics_frame
	var after_first: int = shell.combat.damage_for_arena(GUILD)
	check(after_first > before_ghost, "The ghost cast on its own, with no player input")

	# And it must do exactly the same thing on the next cycle.
	shell.encounter.restart(GUILD)
	_complete_restart(GUILD)
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
	_complete_restart(GUILD)
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
	_complete_restart(GUILD)
	await physics_frame
	check(shell.encounter.is_ghost(shell.hero), "Folded back in for the death check")
	var ghost: ArenicHeroState = shell.hero
	var home: String = ghost.arena_id
	var fell_at: Vector2i = ghost.cell
	var view: ArenicHeroView = shell.stage.hero_views[ghost.identity_id]
	var selection := view.get_node("Selection") as Sprite3D
	var fallen_world: Vector3 = view.global_position
	check(view.sprite.visible and selection.visible, "The focused living ghost has a visible body and its normal selection brackets")
	shell.combat.apply_blast(GUILD, Vector2(ghost.cell), 0.4)
	var death := view.get_node_or_null("GhostDeath") as AnimatedSprite3D
	check(death != null, "A real blast defeat signal creates the ghost's death effect")
	if death == null:
		shell.encounter.restart(GUILD)
		_complete_restart(GUILD)
		return
	check(death.visible and death.animation == &"burst" and death.is_playing() and not view.sprite.visible and not selection.visible, "The fresh defeat starts one burst and immediately hides the body and selection")
	await physics_frame
	await physics_frame
	check(ghost.arena_id == home, "A struck ghost is NOT walked home; that would replay its intent in the wrong arena")
	check(ghost.cell == fell_at, "It lies where it fell")
	check(shell.combat.ally_defeated_at(GUILD, ghost.ally_id()), "And stays down")
	check(shell.encounter.is_ghost(ghost), "Death does not unfold it")
	# Its staff stops: no further movement while it is down.
	var down_at: Vector2i = ghost.cell
	for frame: int in 12:
		await physics_frame
	check(death.animation == &"burst" and death.frame > 0, "The one-shot burst advances while the defeated ledger remains unchanged")
	var burst_frame: int = death.frame
	var burst_progress: float = death.frame_progress
	for sync_index: int in 3:
		shell.stage.sync_heroes(ghost.identity_id, true, shell._is_ghost, shell._is_defeated_ghost)
	check(death.frame == burst_frame and is_equal_approx(death.frame_progress, burst_progress) and not view.sprite.visible and not selection.visible, "Repeated dead-hero synchronization neither restarts the burst nor reveals the hidden actor")
	for frame: int in 108:
		await physics_frame
	check(ghost.cell == down_at, "A fallen ghost neither moves nor casts for the rest of the cycle")
	check(death.visible and death.animation == &"spirit" and death.is_playing() and view.global_position.is_equal_approx(fallen_world), "After the burst, the lingering spirit stays at the actual death position")
	check(not view.sprite.visible and not selection.visible, "The lingering spirit keeps the defeated body and focus brackets hidden")
	# A replaced view derives defeat from the ledger without replaying the burst.
	var restored_view := ArenicHeroView.new()
	restored_view.configure(ghost)
	root.add_child(restored_view)
	restored_view.set_ghost(true)
	restored_view.set_defeated(true)
	restored_view.sync(shell.stage.get_arena(shell.stage.world.index_for_id(GUILD)).definition, true)
	var restored_death := restored_view.get_node_or_null("GhostDeath") as AnimatedSprite3D
	check(restored_death != null and restored_death.animation == &"spirit" and restored_death.visible and restored_death.is_playing(), "Mounting an already defeated ghost restores its spirit directly without a new death burst")
	check(not restored_view.sprite.visible and not (restored_view.get_node("Selection") as Sprite3D).visible and restored_view.global_position.is_equal_approx(fallen_world), "Quiet restoration hides the body and selection at the same authoritative tile")
	restored_view.free()
	# The cycle restarts and it rises at its start tile.
	shell.encounter.restart(GUILD)
	await physics_frame
	check(not shell.combat.ally_defeated_at(GUILD, ghost.ally_id()), "The next cycle revives it")
	check(ghost.cell == staff.start_cell, "It rises at the tile its staff replays from")
	_complete_restart(GUILD)
	await process_frame
	check(view.sprite.visible and selection.visible and not death.visible and not death.is_playing(), "Cycle restart restores the focused body and selection while stopping and hiding the death effect")
	# Scrub only the setup; the real next physics step owns wrap and revival.
	shell.combat.apply_blast(GUILD, Vector2(ghost.cell), 0.4)
	check(death.visible and death.animation == &"burst" and not view.sprite.visible, "A fresh defeat after revival can start a new burst")
	shell.encounter.seek(GUILD, ArenicCycleClock.CYCLE_TICKS - 1)
	await physics_frame
	await physics_frame
	check(shell.encounter.cycle_position(GUILD) < 3 and not shell.combat.ally_defeated_at(GUILD, ghost.ally_id()) and ghost.cell == staff.start_cell, "Natural clock wrap revives the fallen ghost at its recorded start tile")
	_complete_restart(GUILD)
	await process_frame
	check(view.sprite.visible and selection.visible and not death.visible and not death.is_playing(), "Natural clock wrap also removes death presentation and restores the focused actor")


## A defeated ghost must recover before becoming a controllable free hero.
func _check_dead_ghost_choices() -> void:
	var battlefield := "labyrinth"
	var ghost: ArenicHeroState = shell.hero
	var staff := ArenicRecording.create(Vector2i(5, 5), [])
	ghost.recordings[battlefield] = staff
	var defeats: Array[ArenicGameEvent] = []
	var observe_defeat: Callable = func(event: ArenicGameEvent) -> void:
		if event.event_type == &"hero.defeated" and event.payload.get("hero_id", -1) == ghost.identity_id:
			defeats.append(event)
	check(shell.events.subscribe(observe_defeat), "The lifecycle check observes real defeat activity")
	for choice: String in [ArenicModal.TAKE_CONTROL, ArenicModal.START_RECORDING]:
		if shell.encounter.is_ghost(ghost):
			shell.encounter.unfold_ghost(ghost)
		ghost.arena_id = battlefield
		ghost.cell = staff.start_cell
		shell.select_arena(shell.stage.world.index_for_id(battlefield))
		shell.encounter.fold_ghost(ghost, staff)
		_complete_restart(battlefield)
		await physics_frame
		shell.encounter.seek(battlefield, 600)
		defeats.clear()
		shell.combat.apply_blast(battlefield, Vector2(ghost.cell), 0.4)
		check(shell.combat.ally_defeated_at(battlefield, ghost.ally_id()) and defeats.size() == 1, "%s starts from a real defeated ghost with one activity event" % choice)
		if choice == ArenicModal.TAKE_CONTROL:
			await _arrow(KEY_LEFT)
		else:
			shell._handle_record_key()
		check(shell.modal.is_open(), "%s remains an explicit choice for a defeated ghost" % choice)
		shell.modal.choose(0)
		await physics_frame
		var health: Dictionary = shell.combat.ally_status(ghost.arena_id, ghost.ally_id())
		check(not shell.encounter.is_ghost(ghost) and int(health.get("health", 0)) > 0 and health.get("health") == health.get("max_health"), "%s unfolds the ghost with full health instead of leaving an invulnerable zero-HP actor" % choice)
		check(defeats.size() == 1 and ghost.recordings[battlefield] == staff and not shell.encounter.timeline(battlefield).has(ghost.ally_id()), "%s preserves the cached staff without replaying defeat activity or leaving it folded" % choice)
		var view: ArenicHeroView = shell.stage.hero_views[ghost.identity_id]
		var death := view.get_node("GhostDeath") as AnimatedSprite3D
		check(view.sprite.visible and is_equal_approx(view.sprite.modulate.a, 1.0) and (view.get_node("Selection") as Sprite3D).visible and not death.visible and not death.is_playing(), "%s clears the spirit and restores the focused free-hero body" % choice)
		if choice == ArenicModal.TAKE_CONTROL:
			check(ghost.arena_id == shell.RESPAWN_ARENA and ghost.cell == shell.RESPAWN_CELL and ghost.facing == shell.RESPAWN_FACING, "Taking control of a defeated ghost uses the existing Guild House respawn")
			check(not shell.encounter.is_paused(battlefield) and shell.encounter.cycle_position(battlefield) >= 600 and shell.session.is_idle(), "Dead-ghost take control resumes the original arena without rewinding or starting a take")
		else:
			check(ghost.arena_id == battlefield and ghost.cell == staff.start_cell and shell.session.is_counting_down() and shell.session.arena_id == battlefield and shell.session.start_cell == ghost.cell, "Recording over a defeated ghost starts a healthy take in the same arena")
			check(shell.encounter.is_paused(battlefield) and shell.encounter.cycle_position(battlefield) == 0 and shell.combat.cooldown_remaining(ghost) == 0.0, "The replacement take uses its normal paused cycle-zero countdown and clean cast state")
			shell._handle_record_key()
			check(shell.session.is_idle() and not shell.encounter.is_paused(battlefield), "Cancelling that countdown leaves a healthy free hero and resumes its arena")
	check(shell.events.unsubscribe(observe_defeat), "The lifecycle observer is released after both choices")
	ghost.arena_id = GUILD
	ghost.cell = shell.RESPAWN_CELL
	shell.select_arena(shell.stage.world.index_for_id(GUILD))
	await physics_frame


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
	var tick: int = shell.encounter.cycle_position(GUILD)
	await _arrow(KEY_LEFT)
	check(shell.session.is_idle(), "Walking out immediately discards the take")
	check(shell.hero.arena_id != GUILD, "The accepted exit moves the hero to its neighbour")
	check(not shell.encounter.is_paused(GUILD) and (not shell.modal.is_open() or shell.modal.arena_id != GUILD), "Walking out leaves the old arena running; any cached-staff offer belongs to the destination")
	check(shell.encounter.cycle_position(GUILD) > tick, "Leaving continues the fight timestamp without resetting it")


## Forty ghosts to an arena, and a map that says where the guild is working.
func _check_cap_and_readout() -> void:
	# Walk the hero home and fold its staff back in so there is one real ghost.
	shell.hero.arena_id = GUILD
	shell.hero.cell = Vector2i(30, 15)
	shell.select_arena(shell.stage.world.index_for_id(GUILD))
	await physics_frame
	shell.encounter.fold_ghost(shell.hero, shell.hero.recordings[GUILD])
	_complete_restart(GUILD)
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
		timeline.fold("hero:%d" % (900 + index), ArenicRecording.create(Vector2i(2 + index, 5), filler))
	check(shell.encounter.ghost_count(GUILD) == 1, "Staves with no guild member behind them are not counted as ghosts")
	# Now make them real by pointing the lookup at actual members.
	var extras: Array[ArenicHeroState] = []
	for index: int in ArenicEncounterState.MAX_GHOSTS_PER_ARENA - 1:
		var member := ArenicHeroState.new()
		member.definition = shell.hero.definition
		member.identity_id = 900 + index
		member.arena_id = GUILD
		member.cell = Vector2i(2 + index, 5)
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


## Device input belongs to the controlled hero, never to a recorded channel.
func _check_recorded_channel_input() -> void:
	# Use a fresh real shell after the capacity fixture, with three actual guild
	# members and a folded staff. Playback, signals and presentation run normally.
	shell.free()
	await process_frame
	setup.begin_new_game()
	setup.intro_step = 6
	setup.choose_class(load("res://data/classes/hunter.tres"))
	var hunter: ArenicHeroState = setup.get_hero()
	var warrior: ArenicHeroState = setup.recruit(load("res://data/classes/warrior.tres"))
	var cardinal: ArenicHeroState = setup.recruit(load("res://data/classes/cardinal.tres"))
	hunter.cell = Vector2i(27, 20)
	warrior.cell = Vector2i(28, 20)
	cardinal.cell = Vector2i(28, 21)
	shell = load(SHELL_PATH).instantiate()
	root.add_child(shell)
	await process_frame
	shell.set_zoomed(true)
	shell.select_hero() # Plain zoom leaves the remembered hero unselected.
	var events: Array[ArenicTimelineEvent] = [ArenicTimelineEvent.ability(1, 1)]
	var staff := ArenicRecording.create(cardinal.cell, events)
	cardinal.recordings[GUILD] = staff
	shell.encounter.fold_ghost(cardinal, staff)
	_complete_restart(GUILD)
	for frame: int in 4:
		await physics_frame
	await process_frame
	check(shell.hero == hunter and shell.encounter.is_ghost(cardinal), "A different hero controls the arena while Cardinal's staff plays")
	_check_recorded_beam(cardinal, "Recorded ability starts")
	var cast_id: int = shell.combat.active_cast_snapshot(cardinal).get("cast_id", -1)

	await _channel_key(KEY_TAB, true)
	check(shell.hero == warrior, "Real Tab moves from Hunter to Warrior")
	_check_recorded_beam(cardinal, "Tab between other heroes")
	await _channel_key(KEY_TAB, true)
	check(shell.hero == cardinal, "Real Tab selects the recorded Cardinal")
	_check_recorded_beam(cardinal, "Selecting the ghost")
	# Release adapters run in _input even when a GUI consumed the matching press.
	await _channel_key(KEY_SPACE, false)
	_check_recorded_beam(cardinal, "Space release on the ghost")
	await _channel_key(KEY_1, false)
	_check_recorded_beam(cardinal, "Slot release on the ghost")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	Input.parse_input_event(release)
	await physics_frame
	await process_frame
	await process_frame
	_check_recorded_beam(cardinal, "Pointer release on the ghost")
	await _channel_key(KEY_TAB, true)
	check(shell.hero == hunter, "Real Tab leaves the recorded Cardinal")
	_check_recorded_beam(cardinal, "Tab away from the ghost")
	check(cast_id > 0 and shell.combat.active_cast_snapshot(cardinal).get("cast_id", -1) == cast_id,
		"Input preserves the original channel rather than starting a replacement")

	# Stop physics so this proves the presenter's own process observes the actual
	# caster's cancellation without relying on the selected hero's HUD sync.
	shell.set_physics_process(false)
	shell.combat.cancel_channel(cardinal)
	check(not shell.combat.is_channeling(cardinal), "Explicit model cancellation still ends recorded Sacrifice")
	await process_frame
	await process_frame
	check(not shell.combat_presentation._channels.has(cardinal.identity_id),
		"The next presentation process removes a genuinely cancelled channel")
	check(shell.combat_presentation.channel_snapshots().is_empty(), "Model cancellation releases every beam strip")


## Drive the actual shell's cosmetic wait without spending wall-clock seconds.
## No phase flag is cleared by the test, and no forward event is skipped.
func _complete_restart(arena_id: String) -> void:
	var automatic: bool = shell.is_physics_processing()
	shell.set_physics_process(false)
	check(shell.encounter.is_restart_pending(arena_id) and shell.arena_rewind.phase(arena_id) in ["rewind", "countdown"], "A real reset enters its visual rewind/countdown before forward replay")
	var damage: int = shell.combat.damage_for_arena(arena_id)
	var saw_countdown: bool = false
	var held_zero: bool = true
	for tick: int in 902:
		if not shell.encounter.is_restart_pending(arena_id):
			break
		saw_countdown = saw_countdown or shell.arena_rewind.phase(arena_id) == "countdown"
		shell._physics_process(1.0 / 60.0)
		held_zero = held_zero and shell.encounter.cycle_position(arena_id) == 0
	check(saw_countdown and held_zero and not shell.encounter.is_restart_pending(arena_id) and shell.combat.damage_for_arena(arena_id) == damage, "Actual rewind and countdown finish at canonical zero without replay damage")
	shell.set_physics_process(automatic)


func _check_recorded_beam(cardinal: ArenicHeroState, context: String) -> void:
	check(shell.combat.is_channeling(cardinal), context + ": the recorded model channel survives")
	check(shell.combat_presentation._channels.has(cardinal.identity_id) and shell.combat_presentation._channels[cardinal.identity_id].visible,
		context + ": the recorded beam remains visible")
	check(shell.combat_presentation._channels[cardinal.identity_id].caster_identity == cardinal.identity_id,
		context + ": presentation keeps the original caster")


func _channel_key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame
	await physics_frame
	await process_frame
	await process_frame


func _arrow(key: int) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	# Input dispatches on an idle frame; the physics step consumes it after.
	await process_frame
	await physics_frame
	await physics_frame


func _finish() -> void:
	shell.free()
	await process_frame
	check(await RETIRE_AUDIO.wait_for_mixer(self), "Stopped audio resources retire before test exit")
	print("Recording flow checks: %d assertions, %s." % [checks, "FAILED" if failed else "passed"])
	quit(1 if failed else 0)
