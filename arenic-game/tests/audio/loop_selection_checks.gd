extends SceneTree
## Actual shell boundaries: recording reset, scoped input and first arrival.
var failures: int = 0
var checks: int = 0

class ObservedMusic:
	extends ArenicArenaMusicDirector
	var restarts: int = 0

	func _restart_voice(voice: ArenicArenaMusicDirector.Voice) -> void:
		restarts += 1
		super._restart_voice(voice)

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	var setup: Node = root.get_node("RunSetup")
	setup.begin_new_game()
	setup.intro_step = 6
	setup.choose_class(load("res://data/classes/hunter.tres"))
	var shell: Variant = load("res://scenes/game/game_shell.tscn").instantiate()
	root.add_child(shell)
	shell.set_physics_process(false)
	shell.music.set_process(false)
	await process_frame
	var founder: ArenicHeroState = shell.hero
	shell.select_hero()
	shell.encounter.seek("guild_house", 3600)
	shell.encounter.seek("labyrinth", 1200)
	shell.music.synchronize_cycles()
	var music: ArenicArenaMusicDirector = shell.music
	check(is_equal_approx(music.clocks[&"guild_house"].get_position(), music.clocks[&"guild_house"].duration_seconds * 0.5), "Music follows half of the actual arena loop")
	var other: float = music.clocks[&"labyrinth"].get_position()
	shell._handle_record_key()
	check(shell.session.is_counting_down() and music.clocks[&"guild_house"].get_position() == 0.0, "Starting a recording resets its music immediately")
	check(not music.clocks[&"guild_house"].running, "The recording countdown holds the opening of the track")
	check(music.clocks[&"labyrinth"].get_position() == other, "Resetting one arena does not reset another track")
	for tick: int in ArenicRecordingSession.COUNTDOWN_TICKS:
		shell._physics_process(1.0 / 60.0)
	music.synchronize_cycles()
	check(shell.session.is_recording() and music.clocks[&"guild_house"].running and music.clocks[&"guild_house"].get_position() == 0.0, "Capture and music resume together at zero")
	for tick: int in 60:
		shell._physics_process(1.0 / 60.0)
	music.synchronize_cycles()
	check(is_equal_approx(music.clocks[&"guild_house"].get_position(), music.clocks[&"guild_house"].duration_seconds / 120.0), "One simulation second maps to the matching track phase")
	shell._handle_record_key()
	music.synchronize_cycles()
	check(not music.clocks[&"guild_house"].running, "A recording decision also pauses its music")
	shell.modal.choose(2)
	shell.encounter.seek("guild_house", 7199)
	music.synchronize_cycles()
	shell._physics_process(1.0 / 60.0)
	music.synchronize_cycles()
	check(music.clocks[&"guild_house"].get_position() == 0.0, "Natural loop completion resets the music too")
	# A hero in another arena is identity memory, never an active control target.
	founder.arena_id = "labyrinth"
	founder.cell = Vector2i(20, 10)
	shell._relocate_selection(founder, "guild_house")
	shell.combat.respawn_hero_ally(founder)
	shell.select_arena(0)
	shell._select_identity(founder.identity_id)
	shell.select_arena(shell.stage.world.index_for_id("guild_house"))
	check(not founder.selected, "Visiting an empty arena deselects the remote hero")
	shell.select_hero()
	check(shell.stage.world.arenas[shell.selected_index].arena_id == "guild_house" and not founder.selected, "Tab in an empty arena cannot jump to a remote hero")
	var cell: Vector2i = founder.cell
	shell._queue_cast()
	check(not shell._cast_queued, "An empty arena cannot queue a remote cast")
	var second: ArenicHeroState = setup.recruit(load("res://data/classes/warrior.tres"))
	check(shell.hero == second and second.selected and not founder.selected, "The first arrival in the viewed empty Guild House is selected")
	check(founder.cell == cell, "Spawning and selecting another member never moves the remote hero")
	var third: ArenicHeroState = setup.recruit(load("res://data/classes/thief.tres"))
	check(shell.hero == second and not third.selected, "Later arrivals preserve the arena's existing selection")
	shell.select_arena(0)
	check(shell.hero == founder and founder.selected, "Returning to the Labyrinth restores only its remembered selection")
	shell.select_arena(shell.stage.world.index_for_id("guild_house"))
	check(shell.hero == second and second.selected, "Guild House keeps its own remembered selection")
	var saved: Dictionary = ArenicSaveCodec.capture_run(setup, shell)
	check(ArenicSaveCodec.validate(saved).is_empty(), "Scoped selection and cycle-derived music form a valid save")
	_check_slow_music_frames(shell)
	shell.free()
	await preload("res://tests/support/audio_retirement.gd").wait_for_mixer(self)
	print("Loop and selection checks: %d assertions, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check_slow_music_frames(shell: Variant) -> void:
	var observed := ObservedMusic.new()
	root.add_child(observed)
	observed.configure(shell.stage)
	observed.cycle_source = shell.encounter
	observed.set_process(false)
	shell.encounter.set_paused("labyrinth", false)
	shell.encounter.set_restart_pending("labyrinth", false)
	shell.encounter.seek("labyrinth", 300)
	observed.synchronize_cycles()
	observed.set_focus(&"labyrinth", true)
	observed._process(0.11)
	var started: int = observed.restarts
	check(started == 1, "A focused arena starts exactly one music decoder")
	for frame: int in 4:
		# Twelve genuine fixed ticks between rendered frames: five FPS, not a seek.
		shell.encounter.tick(shell.combat, 12)
		observed._process(0.2)
	check(observed.restarts == started, "Slow rendered frames do not continually stop the arena music decoder")
	var clock: ArenicArenaMusicClock = observed.clocks[&"labyrinth"]
	check(is_equal_approx(clock.get_position(), float(shell.encounter.cycle_position("labyrinth")) / shell.encounter.cycle_ticks("labyrinth") * clock.duration_seconds), "Slow frames still derive exact music phase from the arena clock")
	shell.encounter.seek("labyrinth", 1200)
	observed.synchronize_cycles()
	var sought: int = observed.restarts
	check(sought == started + 1, "An explicit forward seek restarts the decoder immediately")
	shell.encounter.seek("labyrinth", 0)
	observed.synchronize_cycles()
	check(observed.restarts == sought + 1 and clock.get_position() == 0.0, "A backward reset still restarts at the track opening")
	shell.encounter.set_paused("labyrinth", true)
	observed.synchronize_cycles()
	check(not observed._voices[0].player.playing and not clock.running, "An arena pause still stops its decoder")
	shell.encounter.set_paused("labyrinth", false)
	observed.synchronize_cycles()
	check(clock.running and observed.restarts == sought + 3, "The paused decoder resumes exactly once")
	observed.free()
	shell.music._listener.make_current()
