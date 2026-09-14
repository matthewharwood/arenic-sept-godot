extends SceneTree
## Godot --headless --path arenic-game --script res://tests/audio/music_checks.gd
## Real stream/scene integration, with deterministic director steps and short
## mixer waits. This process mutes Master; audible quality is a separate review.

const SHELL_PATH: String = "res://scenes/game/game_shell.tscn"
const WATCHDOG_SECONDS: float = 25.0
const SEEK_TOLERANCE: float = 0.30

var _shell: Variant # GameShell is loaded only after RunSetup has initialized.
var _stage: ArenicOverworldStage
var _music: ArenicArenaMusicDirector
var _watchdog: Timer
var _started_ms: int
var _checks: int = 0
var _done: bool = false
var _ids: Array[StringName] = []
var _player_ids := PackedInt64Array()
var _master_was_muted: bool = false
var _master_changed: bool = false


func _initialize() -> void:
	_started_ms = Time.get_ticks_msec()
	_run.call_deferred()


func _run() -> void:
	_watchdog = Timer.new()
	_watchdog.one_shot = true
	_watchdog.wait_time = WATCHDOG_SECONDS
	_watchdog.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_watchdog)
	_watchdog.timeout.connect(func(): _finish(1, "Music checks exceeded the 25-second watchdog."))
	_watchdog.start()
	_master_was_muted = AudioServer.is_bus_mute(0)
	_master_changed = true
	AudioServer.set_bus_mute(0, true)
	root.get_node("RunSetup").intro_step = 6 # Established-world presentation fixture.
	var packed := load(SHELL_PATH) as PackedScene
	if not _check(packed != null, "Actual game shell loads after music imports."):
		return
	_shell = packed.instantiate()
	root.add_child(_shell)
	_stage = _shell.stage
	_music = _shell.music
	_music.cycle_source = null
	if not _check(_stage != null and _music != null, "Persistent shell owns the configured arena music director."):
		return
	_music.set_process(false) # Before the first frame: observe the shared zero start.
	if not _check_resources_and_initial_state():
		return
	await process_frame
	await process_frame
	if _done:
		return
	if not _step(0.70):
		return
	var hum := _music.get_node("OverworldHum") as AudioStreamPlayer3D
	if not _check(_music.snapshot().hum_weight == 1.0 and hum.playing and _playing_music_count() == 0, "Overview fades in only the bounded hum while all music decoders remain stopped."):
		return
	if not _check_initial_burst():
		return
	var expected: float = _music.clocks[_ids[1]].get_position()
	if not await _wait_for_position(_voice_player(_ids[1]), expected):
		return
	if not _step(0.70):
		return
	if not _check(_active_arena_ids() == [_ids[1]] and _music.snapshot().hum_weight == 0.0 and not hum.playing, "Focused music completes its fade and stops the overview hum."):
		return
	var silent_phase: float = _music.clocks[_ids[0]].get_position()
	if not _check(silent_phase > 0.0 and is_equal_approx(silent_phase, _music.clocks[_ids[1]].get_position()), "A never-audible arena advances alongside the focused arena."):
		return
	_music.set_focus(_ids[0], true)
	if not _step(0.11) or not _step(0.70) or not _step(3.0):
		return
	if not _check(_active_arena_ids() == [_ids[0]], "Leaving an arena retires its player without discarding its clock."):
		return
	_music.set_focus(_ids[1], true)
	if not _step(0.11):
		return
	expected = _music.clocks[_ids[1]].get_position()
	if not _check(expected > 5.0, "The returning arena's independent phase includes its silent time."):
		return
	if not await _wait_for_position(_voice_player(_ids[1]), expected):
		return
	if not _check_rapid_retarget() or not _check_hum_handoff():
		return
	if not await _check_independent_seek_and_pause():
		return
	if not await _check_paused_destination():
		return
	if not _check_spatial_sources():
		return
	if not await _check_stage_reconfigure():
		return
	_finish(0, "Arena music integration checks passed: %d assertions; nine v3 loops, silent clocks, real seeks, two bounded music voices, burst coalescing, hum handoff, independent pause, spatial sources and persistent stage clocks." % _checks)


func _check_resources_and_initial_state() -> bool:
	if not _check(_stage.world.arenas.size() == 9 and _music.clocks.size() == 9, "All nine arena resources own independent music clocks."):
		return false
	var streams: Dictionary = {}
	var clocks: Dictionary = {}
	for arena: ArenicArenaDefinition in _stage.world.arenas:
		var definition: ArenicArenaMusicDefinition = arena.music
		var id := StringName(arena.arena_id)
		_ids.append(id)
		if not _check(definition != null and definition.id == id and definition.version == 3 and definition.validation_errors().is_empty(), "Arena binds valid music version three with the matching stable identity: " + String(id)):
			return false
		var stream := definition.stream as AudioStreamMP3
		if not _check(stream != null and stream.loop and stream.loop_offset == 0.0 and stream.resource_path.ends_with("_v3.mp3"), "Version-three MP3 uses its native loop from the beginning."):
			return false
		if not _check(stream.get_length() > 0.0 and absf(stream.get_length() - definition.loop_seconds) <= ArenicArenaMusicDefinition.LENGTH_TOLERANCE_SECONDS, "Clock duration follows actual per-track metadata, including non-120-second tracks."):
			return false
		var clock: ArenicArenaMusicClock = _music.clocks[id]
		if not _check(clock.get_position() == 0.0 and clock.running and clock.duration_seconds == definition.loop_seconds and not clocks.has(clock.get_instance_id()) and not streams.has(stream.get_instance_id()), "Every independent loop starts at zero with its own clock and stream."):
			return false
		clocks[clock.get_instance_id()] = true
		streams[stream.get_instance_id()] = true
	var players: Array[Node] = _music.find_children("*", "AudioStreamPlayer3D", false, false)
	if not _check(players.size() == 3, "Exactly two arena players and one hum player are allocated."):
		return false
	for player: AudioStreamPlayer3D in players:
		_player_ids.append(player.get_instance_id())
		if not _check(player.max_polyphony == 1 and player.playback_type == AudioServer.PLAYBACK_TYPE_STREAM and player.attenuation_model == AudioStreamPlayer3D.ATTENUATION_DISABLED and player.doppler_tracking == AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED, "Each spatial voice uses one bounded stream-mixer playback without distance or Doppler gain changes."):
			return false
	var hum := _music.get_node("OverworldHum") as AudioStreamPlayer3D
	var waveform := hum.stream as AudioStreamWAV
	if not _check(waveform != null and waveform.loop_mode == AudioStreamWAV.LOOP_FORWARD and is_equal_approx(waveform.get_length(), ArenicOverworldHum.LOOP_SECONDS), "Overview hum has a valid short native PCM loop."):
		return false
	return _check(_music.voices_started == 0 and _playing_music_count() == 0, "Overview configuration opens no arena decoders.")


func _check_initial_burst() -> bool:
	var starts: int = _music.voices_started
	for index: int in [0, 2, 4, 1]:
		_music.set_focus(_ids[index], true)
		if not _step(0.04):
			return false
		if not _check(_music.voices_started == starts, "Sub-100ms requests do not start discarded destination decoders."):
			return false
	if not _step(0.11):
		return false
	return _check(_music.voices_started == starts + 1 and _music.snapshot().desired == _ids[1] and _active_arena_ids() == [_ids[1]], "The latest settled request starts exactly one correct arena stream.")


func _check_rapid_retarget() -> bool:
	if not _check(_playing_music_count() == 2, "A normal crossfade has two active arena voices before interruption."):
		return false
	var starts: int = _music.voices_started
	for index: int in [2, 3, 4, 5, 6, 7, 8, 2]:
		_music.set_focus(_ids[index], true)
		if not _step(0.03):
			return false
		if not _check(_music.voices_started == starts, "An interrupted burst reuses the two current decoders throughout the debounce window."):
			return false
	if not _step(0.11):
		return false
	if not _check(_music.voices_started == starts, "A third destination first retires a quiet voice instead of opening a third decoder."):
		return false
	if not _step(0.01) or not _step(0.70):
		return false
	return _check(_music.voices_started == starts + 1 and _music.snapshot().desired == _ids[2] and _active_arena_ids() == [_ids[2]], "The latest burst destination wins and all discarded requests remain unopened.")


func _check_hum_handoff() -> bool:
	var hum := _music.get_node("OverworldHum") as AudioStreamPlayer3D
	_music.set_focus(_ids[2], false)
	if not _step(0.325):
		return false
	var state: Dictionary = _music.snapshot()
	if not _check(state.hum_weight > 0.0 and state.hum_weight < 1.0 and hum.playing and _playing_music_count() == 1, "Overview hum fades in while the outgoing arena fades out."):
		return false
	if not _step(0.70):
		return false
	if not _check(_music.snapshot().hum_weight == 1.0 and _playing_music_count() == 0 and _active_arena_ids().is_empty(), "Completed overview handoff stops both music voices."):
		return false
	_music.set_focus(_ids[0], true)
	if not _step(0.11) or not _step(0.70):
		return false
	return _check(_music.snapshot().hum_weight == 0.0 and not hum.playing and _active_arena_ids() == [_ids[0]], "Returning to an arena fades out and stops the hum.")


func _check_independent_seek_and_pause() -> bool:
	var id: StringName = _ids[0]
	var other: StringName = _ids[1]
	var player: AudioStreamPlayer3D = _voice_player(id)
	_music.seek_arena(id, 30.0)
	if not await _wait_for_position(player, 30.0):
		return false
	_music.set_clock_running(id, false)
	if not _check(not _music.clocks[id].running and not player.playing, "Pausing an audible arena holds its clock and releases active playback."):
		return false
	_music.seek_arena(id, 45.0)
	if not _check(_music.clocks[id].get_position() == 45.0 and not player.playing, "A paused seek updates the saved phase without starting a decoder."):
		return false
	var other_before: float = _music.clocks[other].get_position()
	if not _step(2.0):
		return false
	if not _check(_music.clocks[id].get_position() == 45.0 and is_equal_approx(_music.clocks[other].get_position(), fposmod(other_before + 2.0, _music.clocks[other].duration_seconds)), "A paused seek holds while a silent arena continues advancing."):
		return false
	_music.set_clock_running(id, true)
	if not await _wait_for_position(player, 45.0):
		return false
	if not _step(0.5):
		return false
	if not _check(_music.clocks[id].get_position() == 45.5 and player.playing, "Resume continues from the independent saved offset."):
		return false
	_music.seek_arena(other, -3.0)
	if not _check(is_equal_approx(_music.clocks[other].get_position(), _music.clocks[other].duration_seconds - 3.0) and _music.clocks[id].get_position() == 45.5, "A silent arena accepts a signed seek without disturbing the audible arena."):
		return false
	_music.seek_arena(id, 46.0)
	if not await _wait_for_position(player, 46.0):
		return false
	# Simulate a suspended decoder while leaving the game clock authoritative.
	player.seek(0.0)
	if not await _wait_for_position(player, 0.0):
		return false
	var corrections: int = _music.sync_corrections
	var starts: int = _music.voices_started
	if not _step(1.1):
		return false
	if not _check(_music.sync_corrections > corrections and _music.voices_started == starts, "Periodic drift recovery seeks an existing decoder without opening another voice."):
		return false
	return await _wait_for_position(player, _music.clocks[id].get_position())


func _check_paused_destination() -> bool:
	var id: StringName = _ids[4]
	_music.set_clock_running(id, false)
	_music.seek_arena(id, 27.25)
	_music.set_focus(id, true)
	if not _step(0.11) or not _step(0.70):
		return false
	await create_timer(0.06).timeout
	await process_frame
	if _done:
		return false
	var player: AudioStreamPlayer3D = _voice_player(id)
	if not _check(player != null and not player.playing and _playing_music_count() == 0 and _music.clocks[id].get_position() == 27.25, "Focusing a pre-paused silent arena cannot lose its pause during deferred 3D audio startup."):
		return false
	_music.set_clock_running(id, true)
	if not await _wait_for_position(player, 27.25):
		return false
	_music.set_focus(_ids[0], true)
	if not _step(0.11) or not _step(0.70):
		return false
	return _check(_active_arena_ids() == [_ids[0]], "A resumed paused destination still participates in the bounded crossfade pool.")


func _check_spatial_sources() -> bool:
	var rig: ArenicCameraRig = _stage.camera_rig
	var listener := _music.get_node("MusicListener") as AudioListener3D
	var hum := _music.get_node("OverworldHum") as AudioStreamPlayer3D
	var player: AudioStreamPlayer3D = _voice_player(_ids[0])
	var source: Vector3 = ArenicGridMath.arena_center(_stage.world.arenas[0].grid_slot)
	if not _check(player != null and player.global_position.is_equal_approx(source), "Music source is anchored at its arena's true world center."):
		return false
	var before: Vector3 = listener.global_position
	rig.frame_bounds(ArenicGridMath.arena_rect(_stage.world.arenas[6].grid_slot), false)
	if not _step(0.0):
		return false
	var expected: Vector3 = rig.focus_world + rig.global_basis.z * ArenicArenaMusicDirector.LISTENER_HEIGHT
	if not _check(not listener.global_position.is_equal_approx(before) and listener.global_position.is_equal_approx(expected) and listener.global_basis.is_equal_approx(rig.global_basis) and player.global_position.is_equal_approx(source), "Listener follows camera focus and axes while the arena source remains fixed."):
		return false
	var hum_relative: Vector3 = hum.global_position - listener.global_position
	if not _step(12.0):
		return false
	return _check(not (hum.global_position - listener.global_position).is_equal_approx(hum_relative) and hum.global_position.is_finite(), "The hum source moves on its bounded independent spatial orbit.")


func _check_stage_reconfigure() -> bool:
	var original_clocks: Dictionary = {}
	var original_phases: Dictionary = {}
	_music.set_clock_running(_ids[0], false)
	for id: StringName in _ids:
		original_clocks[id] = _music.clocks[id].get_instance_id()
		original_phases[id] = _music.clocks[id].get_position()
	var director_id: int = _music.get_instance_id()
	var old_stage: WeakRef = weakref(_stage)
	_shell.replace_stage(_shell.stage_scene)
	_stage = _shell.stage
	if not _check(_shell.music == _music and _music.get_instance_id() == director_id and _music.snapshot().desired == &"" and _playing_music_count() == 0, "Stage replacement preserves the director and retires obsolete active playback."):
		return false
	for id: StringName in _ids:
		if not _check(_music.clocks[id].get_instance_id() == original_clocks[id] and _music.clocks[id].get_position() == original_phases[id], "Stage reconfiguration preserves each independent clock and phase."):
			return false
	if not _check(not _music.clocks[_ids[0]].running, "A deliberate per-arena pause survives stage replacement."):
		return false
	await process_frame
	await process_frame
	if _done:
		return false
	if not _check(old_stage.get_ref() == null, "Replacing the world frees the old stage without owning its persistent music clocks."):
		return false
	if not _step(0.70):
		return false
	var listener := _music.get_node("MusicListener") as AudioListener3D
	var expected: Vector3 = _stage.camera_rig.focus_world + _stage.camera_rig.global_basis.z * ArenicArenaMusicDirector.LISTENER_HEIGHT
	return _check(_music.snapshot().hum_weight == 1.0 and listener.global_position.is_equal_approx(expected), "Overview hum and listener resume against the replacement stage's camera.")


func _step(delta: float) -> bool:
	_music._process(delta)
	var state: Dictionary = _music.snapshot()
	if not _check(state.voices.size() == 2 and _playing_music_count() <= 2, "No navigation state exceeds the two music voice limit."):
		return false
	var players: Array[Node] = _music.find_children("*", "AudioStreamPlayer3D", false, false)
	if not _check(players.size() == _player_ids.size(), "Music transitions allocate no extra player nodes."):
		return false
	for index: int in range(players.size()):
		if not _check(players[index].get_instance_id() == _player_ids[index], "The fixed voice pool is reused through navigation and stage replacement."):
			return false
	return true


func _playing_music_count() -> int:
	var count: int = 0
	for voice: Dictionary in _music.snapshot().voices:
		if voice.playing:
			count += 1
	return count


func _active_arena_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for voice: Dictionary in _music.snapshot().voices:
		if not StringName(voice.arena_id).is_empty():
			result.append(StringName(voice.arena_id))
	return result


func _voice_player(id: StringName) -> AudioStreamPlayer3D:
	var state: Dictionary = _music.snapshot()
	for index: int in range(state.voices.size()):
		if state.voices[index].arena_id == id:
			return _music.get_node("ArenaVoice%d" % index) as AudioStreamPlayer3D
	return null


func _wait_for_position(player: AudioStreamPlayer3D, expected: float) -> bool:
	if not _check(player != null, "Requested arena has an allocated playback voice."):
		return false
	# Allow the real audio mixer to accept play/seek before reading its playhead.
	await create_timer(0.06).timeout
	await process_frame
	if _done:
		return false
	var actual: float = player.get_playback_position()
	var duration: float = player.stream.get_length()
	var distance: float = absf(actual - expected)
	distance = minf(distance, absf(duration - distance))
	return _check(player.playing and is_finite(actual) and distance <= SEEK_TOLERANCE, "Actual stream resumes/seeks near the authoritative phase (expected %.3f, got %.3f)." % [expected, actual])


func _check(condition: bool, message: String) -> bool:
	if _done:
		return false
	if Time.get_ticks_msec() - _started_ms >= int(WATCHDOG_SECONDS * 1000.0):
		_finish(1, "Music checks exceeded the 25-second watchdog.")
		return false
	_checks += 1
	if not condition:
		_finish(1, "Music assertion failed: " + message)
		return false
	return true


func _finish(code: int, message: String) -> void:
	if _done:
		return
	_done = true
	if is_instance_valid(_watchdog):
		_watchdog.stop()
	_cleanup.call_deferred(code, message)


func _cleanup(code: int, message: String) -> void:
	if is_instance_valid(_shell):
		_shell.free()
	if is_instance_valid(_watchdog):
		_watchdog.free()
	# Let the mixer retire stopped voices while this test remains muted.
	await create_timer(0.10).timeout
	# Complete main-loop cleanup even if one slow frame consumed the timer.
	await process_frame
	await process_frame
	if _master_changed:
		AudioServer.set_bus_mute(0, _master_was_muted)
	print(message)
	quit(code)
