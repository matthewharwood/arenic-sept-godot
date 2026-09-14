extends SceneTree
## Recording death/exit must never stop the arena's surviving performers.
var failed: bool = false
var checks: int = 0
var shell: Variant
var run: Node

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failed = true
		push_error("Recording cancellation: " + message)

func _run() -> void:
	run = root.get_node("RunSetup")
	run.begin_new_game()
	run.intro_step = 6
	run.choose_class(load("res://data/classes/cardinal.tres"))
	shell = load("res://scenes/game/game_shell.tscn").instantiate()
	root.add_child(shell)
	shell.set_physics_process(false)
	await process_frame
	var recorder: ArenicHeroState = shell.hero
	var cached := ArenicRecording.create(Vector2i(29, 4), [ArenicTimelineEvent.move(60, Vector2i.UP)])
	recorder.recordings["sanctum"] = cached
	_prepare(recorder, "sanctum", Vector2i(14, 8), 390)
	shell.combat._arenas.sanctum.allies[recorder.ally_id()].health = 1
	shell._physics_process(1.0 / 60.0) # Real Sun Seal, with no other hero present.
	check(shell.session.is_idle() and shell.session.events.is_empty(), "The first recorder's real Cardinal hit immediately discards its draft")
	check(recorder.arena_id == "guild_house" and recorder.selected and shell.zoomed, "Death returns the selected hero and close camera to the Guild House")
	check(shell.encounter.cycle_position("sanctum") == 391 and not shell.encounter.is_paused("sanctum"), "The fatal tick finishes once and Sanctum keeps its timestamp")
	check(not shell.modal.is_open() and not shell.encounter.is_restart_pending("sanctum"), "Death opens no decision and starts no rewind")
	check(recorder.recordings.sanctum == cached and not shell.encounter.is_ghost(recorder), "Only the draft is lost; the older take stays cached and unfolded")
	check(shell.combat.ally_status("guild_house", recorder.ally_id()).health == 4, "Respawn restores vitality")
	check(ArenicSaveCodec.validate(ArenicSaveCodec.capture_run(run, shell)).is_empty(), "Post-death state is immediately saveable")

	var resident: ArenicHeroState = run.recruit(load("res://data/classes/hunter.tres"))
	resident.arena_id = "sanctum"
	resident.cell = Vector2i(37, 4)
	var worker := ArenicRecording.create(resident.cell, [ArenicTimelineEvent.move(3600, Vector2i.DOWN), ArenicTimelineEvent.move(3601, Vector2i.DOWN)])
	resident.recordings["sanctum"] = worker
	shell.encounter.fold_ghost(resident, worker)
	shell.encounter.set_restart_pending("sanctum", false)
	shell.arena_rewind.configure(shell.stage, shell.combat_presentation)
	_prepare(recorder, "sanctum", Vector2i(29, 10), 3600)
	var damage: int = shell.combat.damage_for_arena("sanctum")
	shell.combat.wound_ally("sanctum", recorder.ally_id(), 4, "test.fatal")
	check(shell.session.is_idle() and shell.encounter.cycle_position("sanctum") == 3600, "A death at 60 seconds does not reset or advance the fight itself")
	shell._physics_process(1.0 / 60.0)
	shell._physics_process(1.0 / 60.0)
	check(resident.cell == Vector2i(37, 6) and shell.encounter.is_ghost(resident), "An already-recorded survivor executes both next intents after the recorder goes home")
	check(shell.encounter.cycle_position("sanctum") == 3602 and shell.combat.damage_for_arena("sanctum") == damage, "Clock and banked damage survive cancellation")
	check(shell.encounter.timeline("sanctum").has(resident.ally_id()) and resident.recordings.sanctum == worker, "The survivor's fold and cached staff are untouched")

	_prepare(recorder, "sanctum", Vector2i(0, 15), 3600)
	var destination: String = recorder.crossing_arena(Vector2i.LEFT, shell.stage.world)
	check(not destination.is_empty(), "The exit fixture uses an actual neighbouring arena")
	_arrow(KEY_LEFT)
	check(recorder.arena_id == destination and shell.session.is_idle(), "An accepted portal step discards immediately and performs the exit")
	check(not shell.modal.is_open() and not shell.encounter.is_paused("sanctum") and shell.encounter.cycle_position("sanctum") == 3601, "Walking out neither prompts, pauses nor rewinds the source arena")
	_prepare(recorder, "labyrinth", Vector2i(0, 15), 3600)
	_arrow(KEY_LEFT)
	check(shell.session.owns(recorder) and recorder.arena_id == "labyrinth", "The outer world boundary is a blocked step, not an exit")
	shell.select_arena(shell.stage.world.index_for_id("guild_house"))
	check(shell.session.is_idle() and not shell.encounter.is_paused("labyrinth") and shell.encounter.cycle_position("labyrinth") == 3601, "Navigating away cancels without changing the fight time")
	_prepare(recorder, "sanctum", Vector2i(29, 4), 3600)
	recorder.arena_id = "guild_house" # Non-input relocation must use the same guard.
	recorder.cell = Vector2i(20, 15)
	shell.combat.sync_allies(shell.heroes)
	shell._physics_process(1.0 / 60.0)
	check(shell.session.is_idle() and shell.encounter.cycle_position("sanctum") == 3601, "External relocation is reconciled before any more capture")
	_prepare(recorder, "sanctum", Vector2i(29, 4), 0)
	shell.session.state = ArenicRecordingSession.State.COUNTDOWN
	shell.session.events.clear()
	shell.session.countdown_left = 180
	shell.encounter.set_paused("sanctum", true)
	shell.select_arena(shell.stage.world.index_for_id("guild_house"))
	check(shell.session.is_idle() and not shell.encounter.is_paused("sanctum"), "Leaving a recording countdown releases its pause")

	_prepare(recorder, "sanctum", Vector2i(29, 4), 3600)
	shell.combat.wound_ally("sanctum", resident.ally_id(), 4, "test.other")
	check(shell.session.owns(recorder) and resident.arena_id == "sanctum" and shell.encounter.is_ghost(resident), "A different ghost dying does not cancel the living recorder")
	# A valid old save may contain the former You Lose decision. Hydration must
	# retire it without replaying the fatal hit or resetting the survivor's staff.
	shell.combat._arenas.sanctum.allies[recorder.ally_id()].health = 0
	shell._open_modal("sanctum", "You Lose", "Legacy decision", [["Commit Recording", ArenicModal.COMMIT_DEATH], ["Give Up", ArenicModal.RETURN_HOME]], 0)
	var legacy: Dictionary = ArenicSaveCodec.capture_run(run, shell)
	check(ArenicSaveCodec.validate(legacy).is_empty(), "The previous saved death decision remains accepted input")
	check(ArenicSaveCodec.restore_shell(legacy, shell), "Legacy death state hydrates through the shared codec")
	check(shell.session.is_idle() and not shell.modal.is_open() and recorder.arena_id == "guild_house", "Hydration cancels the old death decision and returns the owner home")
	check(shell.encounter.cycle_position("sanctum") == 3600 and not shell.encounter.is_paused("sanctum") and shell.encounter.is_ghost(resident), "Hydration resumes the exact source clock and retains other folds")
	check(ArenicSaveCodec.validate(ArenicSaveCodec.capture_run(run, shell)).is_empty(), "The normalized continuation can be saved again")
	root.remove_child(shell)
	shell.free()
	await preload("res://tests/support/audio_retirement.gd").wait_for_mixer(self)
	print("Recording cancellation checks: %d assertions, %s." % [checks, "FAILED" if failed else "passed"])
	quit(1 if failed else 0)

func _prepare(recorder: ArenicHeroState, arena: String, cell: Vector2i, tick: int) -> void:
	shell._cancel_active_recording("Fixture reset")
	run.forget_selection(recorder.arena_id, recorder.identity_id)
	recorder.arena_id = arena
	recorder.cell = cell
	shell.combat.respawn_hero_ally(recorder)
	run.remember_selection(arena, recorder.identity_id)
	shell._select_identity(recorder.identity_id)
	shell.select_arena(shell.stage.world.index_for_id(arena))
	shell.set_zoomed(true)
	shell.stage.camera_rig.cancel_motion()
	shell.session.arm(recorder)
	shell.session.state = ArenicRecordingSession.State.RECORDING
	shell.session.countdown_left = 0
	shell.session.capture(ArenicTimelineEvent.ability(120, 1))
	shell.encounter.set_paused(arena, false)
	shell.encounter.seek(arena, tick)

func _arrow(key: Key) -> void:
	var input := InputEventKey.new()
	input.physical_keycode = key
	input.pressed = true
	shell._hero_input.accept(input)
	shell._physics_process(1.0 / 60.0)
