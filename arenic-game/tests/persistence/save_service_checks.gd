extends SceneTree
## End-to-end facade and scene lifecycle in an isolated native storage folder.
var _checks: int = 0
var _failed: bool = false
var _saves: Node
var _directory: String

class FlakyBackend:
	extends ArenicNativeSaveBackend
	var fail_next: bool = false
	var delay_seconds: float = 0.0
	var terminal_save_was_paused: bool = false
	func _init(directory: String) -> void:
		super(directory)
	func write_record(slot: int, revision: int, record: String) -> Dictionary:
		if delay_seconds > 0.0:
			var tree := Engine.get_main_loop() as SceneTree
			terminal_save_was_paused = tree.paused
			await tree.create_timer(delay_seconds).timeout
			terminal_save_was_paused = terminal_save_was_paused and tree.paused
		if fail_next:
			fail_next = false
			return failure("Injected full disk; the prior save is intact.")
		return await super.write_record(slot, revision, record)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_saves = root.get_node("SaveGames")
	if not _saves.storage_ready:
		await _saves.initialized
	_saves.set_process(false)
	_directory = "user://save-service-checks-%d" % Time.get_ticks_usec()
	var backend := FlakyBackend.new(_directory)
	_saves.backend = backend
	await _saves.refresh()
	_check(not _saves.has_saves(), "Empty storage offers no Continue")
	_check(await _saves.create_game(42), "New game commits before class selection")
	var id: String = _saves.list_slots()[0].run_id
	_check(id.length() == 64 and _saves.active_slot == 0, "New game receives unique hash and first slot")
	var result := ArenicSaveDocument.decode(_saves._records["0"], 0)
	_check(result.ok and result.payload.scene == "class_selection", "Pending class selection is durable")
	_check(await _saves.continue_game(0), "Pending game can Continue")
	await _scene_ready("class_selection.tscn")
	current_scene._select_class(3, false)
	_check(await _saves.flush(), "Selected card checkpoint commits")
	result = ArenicSaveDocument.decode(_saves._records["0"], 0)
	_check(result.payload.selection_index == 3, "Class selection survives a checkpoint")
	current_scene._confirm_class()
	await _scene_ready("game_shell.tscn")
	var shell: Variant = current_scene
	shell.set_physics_process(false)
	shell.music.set_process(false)
	shell.set_zoomed(true)
	root.get_node("RunSetup").prospected = 1234
	_check(await _saves.flush(), "Whole initialized world commits")
	result = ArenicSaveDocument.decode(_saves._records["0"], 0)
	_check(result.ok and result.payload.run.prospected == "1234" and result.payload.world.zoomed, "World snapshot contains live authoritative state")
	var previous: String = _saves._records["0"]
	backend.fail_next = true
	root.get_node("RunSetup").prospected = 5678
	_check(not await _saves.flush(), "Failed storage commit reports failure")
	_check(_saves._records["0"] == previous and not _saves.last_error.is_empty(), "Failure preserves acknowledged data and exposes status")
	_check(await _saves.flush(), "Dirty state retries successfully")
	result = ArenicSaveDocument.decode(_saves._records["0"], 0)
	_check(result.payload.run.prospected == "5678" and _saves.last_error.is_empty(), "Retry persists latest state and clears error")
	var revision: int = int(result.metadata.revision)
	root.get_node("RunSetup").prospected = 9999
	_saves.set_process(true)
	await create_timer(_saves.AUTOSAVE_SECONDS + 0.4).timeout
	_saves.set_process(false)
	result = ArenicSaveDocument.decode(_saves._records["0"], 0)
	_check(int(result.metadata.revision) > revision and result.payload.run.prospected == "9999", "Scheduled loop saves without explicit UI action")
	backend.delay_seconds = 0.2
	shell.set_physics_process(true)
	root.get_node("RunSetup").prospected = 9999
	_saves._last_checksum = "force-final-checkpoint"
	_check(await _saves.return_to_title(), "Save and title flushes before leaving")
	_check(backend.terminal_save_was_paused and not paused, "Terminal save freezes gameplay during delayed commit and restores pause state")
	backend.delay_seconds = 0.0
	await _scene_ready("title_scene.tscn")
	_check(current_scene.get_node("Continue").visible, "Title shows Continue only after hydration")
	_check(await _saves.continue_game(0), "Gameplay slot resumes")
	await _scene_ready("game_shell.tscn")
	shell = current_scene
	shell.set_physics_process(false)
	_check(shell.hero.definition.class_id == "warrior" and shell.zoomed and root.get_node("RunSetup").prospected == 9999, "Resumed scene applies chosen class, navigation and progression")
	_check(_saves.list_slots()[0].run_id == id, "Continue retains run identity")
	await _saves.return_to_title()
	await _scene_ready("title_scene.tscn")
	var identities: Dictionary = {id: true}
	for index: int in range(1, 8):
		_check(await _saves.create_game(index + 100), "Slot %d creates" % (index + 1))
		var next_id: String = _saves.list_slots()[index].run_id
		_check(not identities.has(next_id), "Each new game has an independent identity")
		identities[next_id] = true
	_check(not await _saves.create_game(), "Ninth game refuses to overwrite a slot")
	_check(_saves.list_slots().size() == 8 and _saves._records.size() == 8, "Storage exposes exactly eight slots")
	_check(await _saves.remove_slot(7), "Explicit removal frees one slot")
	_check(await _saves.create_game(), "Freed slot accepts a fresh identity")
	var decoded := ArenicSaveDocument.decode(_saves._records["7"], 7)
	var tampered: Dictionary = JSON.parse_string(_saves._records["7"])
	tampered.payload_json += " "
	_check(not ArenicSaveDocument.decode(JSON.stringify(tampered), 7).ok, "Checksum catches modified payload")
	tampered = JSON.parse_string(_saves._records["7"])
	tampered.content_version = 999
	_check(ArenicSaveDocument.decode(JSON.stringify(tampered), 7).state == "incompatible", "Future content remains incompatible rather than hydrated")
	var migrated := ArenicSaveMigrations.upgrade({"schema_version": 1, "old": 12}, 2, {1: func(old: Dictionary) -> Dictionary: return {"schema_version": 2, "new": old.old}})
	_check(migrated.ok and migrated.payload.new == 12, "Pure sequential migrations transform versioned data")
	_check(not ArenicSaveMigrations.upgrade({"schema_version": 1}, 2).ok, "Missing migration fails closed")
	_check(not ArenicSaveMigrations.upgrade({"schema_version": 3}, 2).ok, "Future schema is never downgraded")
	_check(decoded.ok, "Untampered slot remains valid")
	_check(not ArenicSaveSeed.valid_definition({"version": 1, "roster_size": 3, "prospected": "120", "starting_cell": [999, 15]}), "Invalid development positions fail before mutating a run")
	var run: Node = root.get_node("RunSetup")
	_check(ArenicSaveSeed.apply(run, 42).is_empty(), "Development seed uses runtime validation")
	var fixture := JSON.stringify(ArenicSaveCodec.capture_run(run), "", true, true)
	ArenicSaveSeed.apply(run, 42)
	_check(fixture == JSON.stringify(ArenicSaveCodec.capture_run(run), "", true, true), "Equal seeds produce equal domain state")
	ArenicSaveSeed.apply(run, 43)
	_check(fixture != JSON.stringify(ArenicSaveCodec.capture_run(run), "", true, true), "Different seeds produce distinct fixtures")
	for slot: int in 8:
		await _saves.remove_slot(slot)
	_check(not _saves.has_saves(), "Removing all slots removes Continue eligibility")
	_remove_tree(ProjectSettings.globalize_path(_directory))
	if current_scene != null:
		current_scene.queue_free()
	await create_timer(0.1).timeout # Allow the title mixer to retire its stopped stream.
	print("Save service checks: %d passed" % _checks if not _failed else "Save service checks failed")
	quit(1 if _failed else 0)


func _scene_ready(suffix: String) -> void:
	for frame: int in 180:
		await process_frame
		if current_scene != null and current_scene.scene_file_path.ends_with(suffix) and current_scene.is_node_ready():
			await process_frame
			return
	_check(false, "Scene timeout: " + suffix)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failed = true
		push_error(message)


func _remove_tree(path: String) -> void:
	for file: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	for directory: String in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(directory))
	DirAccess.remove_absolute(path)
