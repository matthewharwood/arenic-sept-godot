extends SceneTree
## Capture-v2 adapter for frozen seed v1, copied into an isolated project.
## The real SaveGames facade and game shell own hydration and every simulation step.

const ARENA: String = "labyrinth"
const FPS: int = 60
const CAPTURE_SIZE := Vector2i(1280, 720)
const COUNTDOWN_FRAMES: int = 3 * FPS
const FORWARD_FRAMES: int = 120 * FPS
const REWIND_FRAMES: int = 5 * FPS
const REWIND_START_FRAME: int = COUNTDOWN_FRAMES + FORWARD_FRAMES
const FINAL_COUNTDOWN_FRAME: int = REWIND_START_FRAME + REWIND_FRAMES
const CYCLE_FRAMES: int = FINAL_COUNTDOWN_FRAME + COUNTDOWN_FRAMES
const MIN_PHYSICS_USEC: int = 16667
var _save: Node
var _shell: Variant
var _output: String
var _start_frame: int = -1
var _start_physics_frame: int = -1
var _last_draw_frame: int = -1
var _last_process_frame: int = -1
var _next_physics_usec: int = 0
var _start_usec: int = 0
var _started: bool = false
var _finished: bool = false
var _preview: bool = false
var _smoke_seconds: float = 0.0
var _last_phase: String = ""
var _seen_rewind: bool = false
var _seen_final_countdown: bool = false
var _transitions: Array[Dictionary] = []
var _samples: Array[Dictionary] = []
var _deaths: Array[Dictionary] = []
var _damage_by_class: Dictionary = {}
var _before_rewind: Dictionary = {}
var _source_checksum: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 3 or args[0] != "--capture-seed":
		_fail("Expected --capture-seed SAVE_JSON OUTPUT_DIRECTORY [--preview | --smoke=SECONDS].")
		return
	_output = args[2]
	for argument: String in args:
		if argument == "--preview":
			_preview = true
		elif argument.begins_with("--smoke="):
			_smoke_seconds = argument.trim_prefix("--smoke=").to_float()
	if not _preview:
		RenderingServer.frame_post_draw.connect(_after_draw)
	var source: String = FileAccess.get_file_as_string(args[1])
	var decoded: Dictionary = ArenicSaveDocument.decode(source, 0)
	if not decoded.ok:
		_fail(decoded.error)
		return
	_source_checksum = source.sha256_text()
	_save = root.get_node("SaveGames")
	if not _save.storage_ready:
		await _save.initialized
	_save.set_process(false)
	# This adapter writes a fresh, capture-owned store, never a player save slot.
	_save.backend = ArenicNativeSaveBackend.new(_output.path_join("store"))
	var written: Dictionary = await _save.backend.write_record(0, 0, source)
	if not written.ok or not await _save.refresh():
		_fail(str(written.get("error", _save.last_error)))
		return
	scene_changed.connect(_freeze_loaded_scene, CONNECT_ONE_SHOT)
	if not await _save.continue_game(0):
		_fail(_save.last_error)
		return
	await scene_changed
	if _shell == null or _shell.heroes.size() != 40 or not _shell.encounter.is_restart_pending(ARENA):
		_fail("Capture requires forty heroes and an initial pending Labyrinth countdown.")
		return
	if not _preview:
		_shell.combat.ally_defeated.connect(_on_death)
		_shell.combat.damage_reported.connect(_on_damage)
	# Allow the actual renderer to prepare its textures/shaders while gameplay
	# remains at its saved boundary. These startup frames are trimmed, not sped up.
	for frame: int in 30:
		await RenderingServer.frame_post_draw
	if root.size != CAPTURE_SIZE or Vector2i(root.get_texture().get_size()) != CAPTURE_SIZE:
		_fail("Capture needs a 1280x720 window and rendered texture without MovieWriter rescaling.")
		return
	if _shell.encounter.cycle_position(ARENA) != 0 or _phase() != "countdown" or _shell.arena_rewind.countdown_seconds(ARENA) != 3:
		_fail("The initial countdown advanced during startup preparation.")
		return
	_shell.set_process_unhandled_input(_preview)
	# With --render-thread safe, this is the zero-based MovieWriter frame about
	# to be written. Its pixels still show countdown=3; physics resumes next frame.
	_start_frame = Engine.get_process_frames()
	_start_physics_frame = Engine.get_physics_frames()
	_last_process_frame = _start_frame
	_last_draw_frame = Engine.get_frames_drawn()
	_start_usec = Time.get_ticks_usec()
	_next_physics_usec = _start_usec + MIN_PHYSICS_USEC
	_last_phase = "countdown"
	if not _preview:
		_transitions.append({"phase": "initial_countdown", "frame": 0, "seconds": 0.0, "tick": 0})
		physics_frame.connect(_pace_physics)
	_started = true
	paused = false
	print("CAPTURE_STARTED " + JSON.stringify({"start_frame": _start_frame, "framebuffer": [root.size.x, root.size.y], "seed_sha256": _source_checksum}))


func _pace_physics() -> void:
	# Fixed-fps MovieWriter bypasses --max-fps/--frame-delay. Keep wall-throttled
	# SFX from being suppressed by faster-than-real-time playback, without changing
	# game delta or code. Slow rendering waits zero; never catch up after a stall.
	if _finished:
		return
	var wait_usec: int = _next_physics_usec - Time.get_ticks_usec()
	if wait_usec > 0:
		OS.delay_usec(wait_usec)
	_next_physics_usec = Time.get_ticks_usec() + MIN_PHYSICS_USEC


func _freeze_loaded_scene() -> void:
	_shell = current_scene
	paused = true
	if _shell != null:
		_shell.set_process_unhandled_input(false)


func _phase() -> String:
	return _shell.arena_rewind.phase(ARENA)


func _totals() -> Dictionary:
	var run: Node = root.get_node("RunSetup")
	return {"damage": str(_shell.combat.damage_for_arena(ARENA)), "prospected": str(run.prospected),
		"wood": str(run.gathering.wood_total), "gold": str(run.gathering.gold_total)}


func _after_draw() -> void:
	if not _started or _finished or _shell == null or _preview:
		return
	var process_frame: int = Engine.get_process_frames()
	var draw_frame: int = Engine.get_frames_drawn()
	var relative_frame: int = process_frame - _start_frame
	if process_frame - _last_process_frame != 1 or draw_frame - _last_draw_frame != 1 or Engine.get_physics_frames() - _start_physics_frame != relative_frame:
		_fail("Capture requires one physics step and one rendered image per movie frame.")
		return
	_last_process_frame = process_frame
	_last_draw_frame = draw_frame
	if root.size != CAPTURE_SIZE or Vector2i(root.get_texture().get_size()) != CAPTURE_SIZE:
		_fail("The capture framebuffer changed size during playback.")
		return
	var phase: String = _phase()
	var tick: int = _shell.encounter.cycle_position(ARENA)
	if phase != _last_phase:
		var label: String = "play" if phase.is_empty() else phase
		if phase == "rewind":
			_seen_rewind = true
			_before_rewind = _totals()
		elif phase == "countdown" and _seen_rewind:
			_seen_final_countdown = true
			label = "final_countdown"
		elif phase.is_empty() and _seen_final_countdown:
			label = "complete"
		var transition: Dictionary = {"phase": label, "frame": relative_frame,
			"seconds": float(relative_frame) / FPS, "tick": tick}
		_transitions.append(transition)
		print("CAPTURE_PHASE " + JSON.stringify(transition))
		_last_phase = phase
	if relative_frame % FPS == 0:
		var alive: int = 0
		for hero: ArenicHeroState in _shell.heroes:
			if not _shell.combat.ally_defeated_at(hero.arena_id, hero.ally_id()):
				alive += 1
		_samples.append({"frame": relative_frame, "phase": phase, "tick": tick,
			"alive": alive, "totals": _totals(), "rewind": _shell.arena_rewind.snapshot(ARENA)})
	if _smoke_seconds > 0.0 and relative_frame >= roundi(_smoke_seconds * FPS):
		_finish(false, "smoke")
	elif _seen_final_countdown and phase.is_empty():
		_finish(_totals() == _before_rewind, "complete")
	elif relative_frame > 150 * FPS:
		_fail("The complete arena cycle exceeded the bounded 150-second capture window.")


func _on_death(arena: String, actor: String) -> void:
	if arena == ARENA and _started and not _finished:
		_deaths.append({"actor": actor, "tick": _shell.encounter.cycle_position(ARENA), "frame": Engine.get_process_frames() - _start_frame})


func _on_damage(caster: String, ability: String, arena: String, _enemy: String, amount: int) -> void:
	if arena != ARENA or not _started or _finished:
		return
	_damage_by_class[ability] = int(_damage_by_class.get(ability, 0)) + amount
	if caster.is_empty():
		push_warning("Capture received unattributed damage.")


func _finish(passed: bool, reason: String) -> void:
	if _finished:
		return
	_finished = true
	# The completion image is an exclusive end boundary. It may be written to
	# the raw AVI during graceful shutdown, but is not part of the final clip.
	var end_frame: int = Engine.get_process_frames()
	var frames: int = end_frame - _start_frame
	if reason == "complete":
		passed = passed and frames == CYCLE_FRAMES and _valid_boundaries()
	var result: Dictionary = {"passed": passed, "reason": reason, "fps": FPS,
		"frames": frames, "seconds": float(frames) / FPS, "start_frame": _start_frame,
		"end_frame": end_frame, "wall_seconds": float(Time.get_ticks_usec() - _start_usec) / 1000000.0,
		"seed_sha256": _source_checksum, "transitions": _transitions, "samples": _samples,
		"deaths": _deaths, "damage_by_ability": _damage_by_class, "final_totals": _totals(),
		"totals_before_rewind": _before_rewind}
	var file := FileAccess.open(_output.path_join("capture.json"), FileAccess.WRITE)
	if file == null:
		_fail("Cannot write capture verification metadata.")
		return
	file.store_string(JSON.stringify(result, "\t", true, true) + "\n")
	file.close()
	print("CAPTURE_FINISHED " + JSON.stringify({"passed": passed, "reason": reason, "frames": frames, "deaths": _deaths.size(), "totals": _totals()}))
	# MovieWriter closes the current rendered frame and audio before shutdown.
	_shutdown.call_deferred(0 if passed or reason == "smoke" else 1)


func _valid_boundaries() -> bool:
	var phases: Array[String] = ["initial_countdown", "play", "rewind", "final_countdown", "complete"]
	var frames: Array[int] = [0, COUNTDOWN_FRAMES, REWIND_START_FRAME, FINAL_COUNTDOWN_FRAME, CYCLE_FRAMES]
	if _transitions.size() != phases.size():
		return false
	for index: int in phases.size():
		if _transitions[index].phase != phases[index] or int(_transitions[index].frame) != frames[index]:
			return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	_finished = true
	_shutdown.call_deferred(1)


func _shutdown(code: int) -> void:
	# The movie interval has already ended. Retire the actual shell and mixer
	# before closing MovieWriter; any teardown images stay outside the trim.
	paused = false
	if is_instance_valid(_save):
		_save.active_slot = -1
		_save._shell = null
	if is_instance_valid(_shell):
		current_scene = null
		root.remove_child(_shell)
		_shell.free()
		_shell = null
	if not await preload("res://tests/support/audio_retirement.gd").wait_for_mixer(self):
		code = 1
	quit(code)
