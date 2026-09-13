extends SceneTree
## Test-only process entry point; exports exclude the complete tests directory.
var directory: String
var mode: String
var save: Node
var run: Node
var snapshot: Dictionary = {}
var shell: Variant


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() != 3 or arguments[0] != "--restart-worker":
		quit(2)
		return
	directory = arguments[1]
	mode = arguments[2]
	save = root.get_node("SaveGames")
	run = root.get_node("RunSetup")
	if not save.storage_ready:
		await save.initialized
	save.set_process(false)
	save.backend = ArenicNativeSaveBackend.new(directory.path_join("store"))
	if not await save.refresh():
		_finish(false, save.last_error)
		return
	if mode == "writer":
		await _write_game()
	elif mode == "reader":
		await _read_game()
	else:
		_finish(false, "Unknown worker mode")


func _freeze_scene() -> void:
	if current_scene != null and current_scene.scene_file_path == save.GAME_SCENE:
		shell = current_scene
		shell.set_physics_process(false)
		shell.music.set_process(false)
		snapshot = ArenicSaveCodec.capture_run(run, shell)
		snapshot.selection_index = save.selection_index


func _write_game() -> void:
	if not await save.create_game(42):
		_finish(false, save.last_error)
		return
	if change_scene_to_file(save.CLASS_SCENE) != OK:
		_finish(false, "Class scene failed")
		return
	await scene_changed
	var classes: Variant = current_scene
	if classes == null:
		_finish(false, "Expected the actual class selection scene")
		return
	classes._select_class(1, false)
	scene_changed.connect(_freeze_scene, CONNECT_ONE_SHOT)
	classes._confirm_class()
	await scene_changed
	if shell == null:
		_finish(false, "Class confirmation did not construct the game shell")
		return
	# Make real progress through the owning models. All points remain in the
	# Guild House, avoiding a renderer or an enemy footprint as a test input.
	shell.hero.step(Vector2i(1, 0), shell.stage.world)
	shell.hero.gain_experience(37)
	shell.hero.selected = false
	shell.combat.sync_allies(shell.heroes)
	run.prospected = 107
	shell.set_zoomed(true)
	shell.encounter.seek("guild_house", 1234)
	shell.encounter.dig_field("guild_house").dig(Vector2i(30, 15))
	shell.music.seek_arena(&"guild_house", 34.125)
	shell._open_modal("guild_house", "Continue this run?", "A pending decision survives a process restart.", [["Continue", ArenicModal.CANCEL]])
	if not await save.flush():
		_finish(false, save.last_error)
		return
	var readback: Dictionary = await save.backend.read_all()
	var decoded: Dictionary = ArenicSaveDocument.decode(readback.records["0"], 0)
	if not decoded.ok:
		_finish(false, decoded.error)
		return
	_write_json(directory.path_join("expected.json"), {"run_id": decoded.metadata.run_id, "payload": decoded.payload})
	await _retire_scene()
	_finish(true)


func _read_game() -> void:
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("expected.json")))
	if not expected is Dictionary or not save.has_saves():
		_finish(false, "Fresh process did not discover the written slot")
		return
	scene_changed.connect(_freeze_scene, CONNECT_ONE_SHOT)
	if not await save.continue_game(0):
		_finish(false, save.last_error)
		return
	await scene_changed
	if shell == null:
		_finish(false, "Continue did not open the game shell")
		return
	var continued_id: String = save._metadata.run_id
	var equal: bool = _canonical(snapshot) == _canonical(expected.payload)
	var before: int = shell.encounter.cycle_position("guild_house")
	# The restored modal owns the paused arena. Choosing its real button action
	# must release that pause before the next simulation tick.
	if not shell.modal.is_open():
		_finish(false, "The pending decision was not restored")
		return
	shell.modal.choose(0)
	shell.set_physics_process(true)
	await physics_frame
	await physics_frame
	shell.set_physics_process(false)
	var advanced: bool = shell.encounter.cycle_position("guild_house") > before
	await _retire_scene()
	_finish(equal and advanced and continued_id == expected.run_id,
		"Restored snapshot or resumed simulation differs" if not equal or not advanced else "",
		{"written_run_id": expected.run_id, "continued_run_id": continued_id, "payload_equal": equal, "advanced": advanced})


func _canonical(value: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value, "", true, true)), "", true, true)


func _retire_scene() -> void:
	# Release audio voices through the same scene-exit lifecycle as gameplay.
	save.active_slot = -1
	save._shell = null
	if current_scene != null:
		var old: Node = current_scene
		current_scene = null
		root.remove_child(old)
		old.free()
	for frame: int in 3:
		await process_frame


func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "", true, true))
	file.close()


func _finish(ok: bool, error: String = "", extra: Dictionary = {}) -> void:
	var result: Dictionary = {"ok": ok, "error": error}
	result.merge(extra)
	_write_json(directory.path_join(mode + "-result.json"), result)
	quit(0 if ok else 1)
