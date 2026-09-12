extends Node
## The only application-facing persistence interface. Domain models never
## choose a platform or touch storage. Acknowledgements mean committed bytes.
signal initialized
signal slots_changed
signal status_changed(message: String)
signal operation_finished

const AUTOSAVE_SECONDS: float = 5.0
const TITLE_SCENE: String = "res://scenes/title/title_scene.tscn"
const CLASS_SCENE: String = "res://scenes/character_creation/class_selection.tscn"
const GAME_SCENE: String = "res://scenes/game/game_shell.tscn"
var backend: ArenicSaveBackend
var storage_ready: bool = false
var active_slot: int = -1
var selection_index: int = 0
var last_error: String = ""
var last_warning: String = ""
var last_saved_at: int = 0
var _records: Dictionary = {}
var _metadata: Dictionary = {}
var _pending_payload: Dictionary = {}
var _last_checksum: String = ""
var _shell: WeakRef
var _busy: bool = false
var _elapsed: float = 0.0
var _closing: bool = false
var _seeding: bool = false
var _returning: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().auto_accept_quit = false
	var development_seed: int = _development_seed()
	if backend == null:
		if OS.has_feature("web"):
			backend = ArenicBrowserSaveBackend.new("arenic-saves-dev" if development_seed > 0 else "arenic-saves")
		else:
			backend = ArenicNativeSaveBackend.new("user://dev-saves" if development_seed > 0 else "user://saves")
	await refresh()
	if development_seed > 0 and _records.is_empty() and last_error.is_empty():
		await _seed_development_game(development_seed)
	storage_ready = true
	initialized.emit()


func is_busy() -> bool:
	return _busy


func refresh() -> bool:
	if _busy:
		return false
	_busy = true
	var result: Dictionary = await backend.read_all()
	if result.ok:
		_records = result.records
		last_error = ""
		last_warning = "\n".join(result.get("warnings", []))
	else:
		_fail(result.error)
	_finish()
	slots_changed.emit()
	return result.ok


func list_slots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot: int in ArenicSaveBackend.SLOT_COUNT:
		var row := {"slot": slot, "state": "empty", "label": "Empty slot", "error": ""}
		if _records.has(str(slot)):
			var decoded := ArenicSaveDocument.decode(_records[str(slot)], slot)
			row.state = decoded.state
			row.error = decoded.error
			row.label = "Unavailable save"
			if decoded.ok:
				var run: Dictionary = decoded.payload.run
				var class_id: String = str(run.get("selected_class", ""))
				row.label = "Choose your founder" if decoded.payload.scene == "class_selection" else class_id.capitalize() + " guild"
				row["run_id"] = decoded.metadata.run_id
				row["updated_at"] = int(decoded.metadata.updated_at)
				row["revision"] = int(decoded.metadata.revision)
		result.append(row)
	return result


func has_saves() -> bool:
	for row: Dictionary in list_slots():
		if row.state == "ready":
			return true
	return false


func has_records() -> bool:
	return not _records.is_empty()


## A confirmation retains this token, so refreshing a list cannot broaden it.
func slot_token(slot: int) -> Dictionary:
	var record: String = _records.get(str(slot), "")
	return {"revision": ArenicSaveBackend.record_revision(record), "fingerprint": record.sha256_text(),
		"run_id": ArenicSaveBackend.record_run_id(record)}


## Allocate before entering class selection, so even an unfinished run resumes.
func create_game(seed_value: int = 0) -> bool:
	if _busy or (not storage_ready and not _seeding):
		return false
	if not await refresh():
		return false
	var slot: int = -1
	for index: int in ArenicSaveBackend.SLOT_COUNT:
		if not _records.has(str(index)):
			slot = index
			break
	if slot < 0:
		return _fail("All eight slots are full. Remove a save from the slots screen first.")
	var random_bytes := Crypto.new().generate_random_bytes(32)
	if random_bytes.size() != 32:
		return _fail("Could not create a unique save identity.")
	var old_payload := ArenicSaveCodec.capture_run(RunSetup)
	RunSetup.begin_new_game()
	RunSetup.run_seed = seed_value if seed_value >= 1 and seed_value <= 2147483647 else maxi(1, int(random_bytes.decode_u32(0) & 0x7fffffff))
	var timestamp := int(Time.get_unix_time_from_system())
	var metadata := {"slot": slot, "run_id": random_bytes.hex_encode(), "seed": RunSetup.run_seed,
		"revision": 1, "created_at": timestamp, "updated_at": timestamp}
	var payload := ArenicSaveCodec.capture_run(RunSetup)
	payload["selection_index"] = 0
	var errors := ArenicSaveCodec.validate(payload)
	if not errors.is_empty():
		ArenicSaveCodec.restore_run(old_payload, RunSetup)
		return _fail(errors[0])
	var record := ArenicSaveDocument.encode(metadata, payload)
	_busy = true
	var result: Dictionary = await backend.write_record(slot, 0, record)
	if result.ok:
		active_slot = slot
		_metadata = metadata
		selection_index = 0
		_pending_payload.clear()
		_shell = null
		_commit(record, payload)
	else:
		ArenicSaveCodec.restore_run(old_payload, RunSetup)
		_fail(result.error)
	_finish()
	return result.ok


## Validate the complete candidate before replacing any live domain object.
func continue_game(slot: int) -> bool:
	if _busy or not await refresh():
		return false
	if not _records.has(str(slot)):
		return _fail("That save slot is empty.")
	var decoded := ArenicSaveDocument.decode(_records[str(slot)], slot)
	if not decoded.ok:
		return _fail(decoded.error)
	if not ArenicSaveCodec.restore_run(decoded.payload, RunSetup):
		return _fail("The save could not be restored.")
	active_slot = slot
	_metadata = decoded.metadata
	_pending_payload = decoded.payload
	selection_index = int(decoded.payload.get("selection_index", 0))
	_last_checksum = str(decoded.metadata.checksum)
	_shell = null
	var destination: String = CLASS_SCENE if decoded.payload.scene == "class_selection" else GAME_SCENE
	var error := get_tree().change_scene_to_file(destination)
	if error != OK:
		return _fail("Could not open the saved game: " + error_string(error))
	return true


## Called after world construction, before its first simulation step.
func attach_shell(shell: ArenicGameShell) -> bool:
	if active_slot < 0:
		return true # Standalone editor/test scenes are deliberately unsaved.
	if not _pending_payload.is_empty() and _pending_payload.scene == "game":
		if not ArenicSaveCodec.restore_shell(_pending_payload, shell):
			return _fail("The saved world could not be restored.")
	_pending_payload.clear()
	_shell = weakref(shell)
	checkpoint.call_deferred()
	return true


func checkpoint() -> bool:
	if active_slot < 0 or not storage_ready:
		return true
	if _busy:
		return false
	var shell: ArenicGameShell = _shell.get_ref() as ArenicGameShell if _shell != null else null
	var scene: Node = get_tree().current_scene
	if shell == null and (scene == null or scene.scene_file_path != CLASS_SCENE):
		return true
	var payload := ArenicSaveCodec.capture_run(RunSetup, shell)
	payload["selection_index"] = selection_index
	var errors := ArenicSaveCodec.validate(payload)
	if not errors.is_empty():
		return _fail("Saving paused: " + errors[0])
	var checksum := JSON.stringify(payload, "", true, true).sha256_text()
	if checksum == _last_checksum:
		return true
	var metadata := _metadata.duplicate(true)
	metadata.revision = int(_metadata.revision) + 1
	metadata.updated_at = int(Time.get_unix_time_from_system())
	var record := ArenicSaveDocument.encode(metadata, payload)
	_busy = true
	status_changed.emit("Saving…")
	var result: Dictionary = await backend.write_record(active_slot, int(_metadata.revision), record)
	if result.ok:
		_metadata = metadata
		_commit(record, payload)
	else:
		_fail(result.error)
	_finish()
	return result.ok


func flush() -> bool:
	while _busy:
		await operation_finished
	return await checkpoint()


func return_to_title() -> bool:
	if _returning:
		return false
	_returning = true
	var was_paused: bool = get_tree().paused
	get_tree().paused = true
	if not await flush():
		get_tree().paused = was_paused
		_returning = false
		return false
	var error := get_tree().change_scene_to_file(TITLE_SCENE)
	if error == OK:
		_shell = null
		active_slot = -1
		_pending_payload.clear()
	get_tree().paused = was_paused
	_returning = false
	return error == OK or _fail("Could not return to the title: " + error_string(error))


## Call only after the user chooses and confirms a specific slot. CAS protects
## another tab's newer write; it is never an unscoped browser/filesystem wipe.
func remove_slot(slot: int, reviewed_revision: int = -2, reviewed_run_id: String = "") -> bool:
	if _busy or slot < 0 or slot >= ArenicSaveBackend.SLOT_COUNT:
		return false
	if not _records.has(str(slot)):
		return true
	var record: String = _records[str(slot)]
	var revision: int = ArenicSaveBackend.record_revision(record) if reviewed_revision == -2 else reviewed_revision
	var run_id: String = reviewed_run_id
	if reviewed_revision == -2:
		run_id = ArenicSaveBackend.record_run_id(record)
	_busy = true
	var result: Dictionary = await backend.delete_record(slot, revision, run_id)
	if result.ok:
		_records.erase(str(slot))
		if active_slot == slot:
			active_slot = -1
			_shell = null
			_pending_payload.clear()
		last_error = ""
		slots_changed.emit()
	else:
		_fail(result.error)
	_finish()
	return result.ok


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= AUTOSAVE_SECONDS:
		_elapsed = 0.0
		if not _busy and not _returning and not _closing:
			checkpoint()


func _notification(what: int) -> void:
	if not storage_ready:
		return
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not OS.has_feature("web"):
		_close_after_save.call_deferred()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		flush.call_deferred()


func _close_after_save() -> void:
	if _closing:
		return
	_closing = true
	var was_paused: bool = get_tree().paused
	get_tree().paused = true
	if await flush():
		get_tree().quit()
	get_tree().paused = was_paused
	_closing = false


func _commit(record: String, payload: Dictionary) -> void:
	_records[str(active_slot)] = record
	_last_checksum = JSON.stringify(payload, "", true, true).sha256_text()
	last_saved_at = int(_metadata.updated_at)
	last_error = ""
	_elapsed = 0.0
	status_changed.emit("Saved")
	slots_changed.emit()


func _finish() -> void:
	_busy = false
	operation_finished.emit()


func _fail(message: String) -> bool:
	last_error = message
	status_changed.emit(message)
	return false


func _development_seed() -> int:
	var value: String = ""
	if OS.has_feature("web"):
		# Explicit localhost fixture only; release hosts never expose dev seeding.
		value = str(JavaScriptBridge.eval("(['localhost','127.0.0.1','[::1]'].includes(location.hostname) ? new URL(location.href).searchParams.get('dev_seed') || '' : '')"))
	elif OS.is_debug_build():
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--dev-seed="):
				value = argument.trim_prefix("--dev-seed=")
	return int(value) if value.is_valid_int() and int(value) >= 1 and int(value) <= 2147483647 else 0


func _seed_development_game(seed_value: int) -> void:
	_seeding = true
	if await create_game(seed_value):
		var errors := ArenicSaveSeed.apply(RunSetup, seed_value)
		if errors.is_empty():
			var payload := ArenicSaveCodec.capture_run(RunSetup)
			var metadata := _metadata.duplicate(true)
			metadata.revision = int(metadata.revision) + 1
			var record := ArenicSaveDocument.encode(metadata, payload)
			_busy = true
			var result: Dictionary = await backend.write_record(active_slot, int(_metadata.revision), record)
			if result.ok:
				_metadata = metadata
				_commit(record, payload)
			else:
				_fail(result.error)
			_finish()
		else:
			_fail(errors[0])
	active_slot = -1
	RunSetup.begin_new_game()
	_seeding = false
