class_name ArenicNativeSaveBackend
extends ArenicSaveBackend
## Flush + rename commits one slot. The previous committed record is recoverable.
## Locks span reads and writes, so compare-and-swap also protects two app instances.
const DELETED: String = '{"_arenic_deleted":true}'
var directory: String
var _process_lock: TCPServer


func _init(save_directory: String = "user://saves") -> void:
	directory = ProjectSettings.globalize_path(save_directory)


func read_all() -> Dictionary:
	var locked := _acquire_lock()
	if not locked.ok:
		return locked
	var records: Dictionary = {}
	var warnings: Array[String] = []
	for slot: int in range(SLOT_COUNT):
		var current := _read_slot(slot)
		if not current.ok:
			_release_lock()
			return current
		if not current.record.is_empty():
			records[str(slot)] = current.record
		if not current.warning.is_empty():
			warnings.append(current.warning)
	_release_lock()
	return {"ok": true, "records": records, "warnings": warnings, "error": ""}


func write_record(slot: int, expected_revision: int, record: String) -> Dictionary:
	var invalid := write_error(slot, expected_revision, record)
	if not invalid.is_empty():
		return failure(invalid)
	var locked := _acquire_lock()
	if not locked.ok:
		return locked
	var result := _write_locked(slot, expected_revision, record)
	_release_lock()
	return result


func delete_record(slot: int, expected_revision: int, expected_run_id: String = "") -> Dictionary:
	var invalid := delete_error(slot, expected_revision)
	if not invalid.is_empty():
		return failure(invalid)
	var locked := _acquire_lock()
	if not locked.ok:
		return locked
	var current := _read_slot(slot)
	var result: Dictionary
	if not current.ok:
		result = current
	elif record_revision(current.record) != expected_revision or record_run_id(current.record) != expected_run_id:
		result = failure("This slot changed in another game. Reload the slot list before deleting.")
	else:
		# A committed tombstone prevents a crash from resurrecting the backup.
		result = _replace_file(_slot_path(slot), DELETED)
		if result.ok:
			_remove_if_present(_slot_path(slot) + ".bak")
	_release_lock()
	return result


func _write_locked(slot: int, expected_revision: int, record: String) -> Dictionary:
	var current := _read_slot(slot)
	if not current.ok:
		return current
	if record_revision(current.record) != expected_revision:
		return failure("This slot changed in another game. Reload it before saving; your progress remains in memory.")
	if expected_revision > 0 and record_run_id(current.record) != record_run_id(record):
		return failure("This slot now belongs to a different game. Reload the slot list; your progress remains in memory.")
	var primary := _slot_path(slot)
	if not current.record.is_empty():
		var backup := _replace_file(primary + ".bak", current.record)
		if not backup.ok:
			return backup
	else:
		var cleanup := _remove_if_present(primary + ".bak")
		if cleanup != OK:
			return failure("Could not clear this empty slot's old backup: " + error_string(cleanup))
	return _replace_file(primary, record)


func _read_slot(slot: int) -> Dictionary:
	var primary := _read_file(_slot_path(slot))
	if not primary.ok:
		return primary
	if primary.record == DELETED:
		return {"ok": true, "record": "", "warning": ""}
	if record_revision(primary.record) > 0:
		return {"ok": true, "record": primary.record, "warning": ""}
	var backup := _read_file(_slot_path(slot) + ".bak")
	if not backup.ok:
		return backup
	if record_revision(backup.record) > 0:
		return {"ok": true, "record": backup.record,
			"warning": "Slot %d recovered its previous committed save after an interrupted or damaged write." % (slot + 1)}
	# Keep malformed contents visible to the service, which owns quarantine/reset UI.
	return {"ok": true, "record": primary.record if not primary.record.is_empty() else backup.record, "warning": ""}


func _read_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": true, "record": ""}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return failure("Cannot read save file %s: %s" % [path, error_string(FileAccess.get_open_error())])
	if file.get_length() > MAX_RECORD_BYTES:
		file.close()
		return {"ok": true, "record": "{invalid-oversized-save"}
	var content := file.get_as_text()
	var result := file.get_error()
	file.close()
	if result != OK and result != ERR_FILE_EOF:
		return failure("Cannot read complete save file %s: %s" % [path, error_string(result)])
	# A zero-byte existing file is damaged, not a free slot.
	return {"ok": true, "record": content if not content.is_empty() else " "}


func _replace_file(path: String, content: String) -> Dictionary:
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return failure("Cannot create save write at %s: %s" % [temporary, error_string(FileAccess.get_open_error())])
	file.store_string(content)
	file.flush()
	var result := file.get_error()
	file.close()
	if result != OK:
		_remove_if_present(temporary)
		return failure("Save write failed; the committed save is unchanged: " + error_string(result))
	result = DirAccess.rename_absolute(temporary, path)
	if result != OK:
		_remove_if_present(temporary)
		return failure("Cannot commit save at %s: %s" % [path, error_string(result)])
	return {"ok": true, "error": ""}


func _slot_path(slot: int) -> String:
	return directory.path_join("slot-%d.json" % slot)


func _acquire_lock() -> Dictionary:
	if _process_lock != null:
		return failure("A native save operation is already in progress. Retry after it completes.")
	var result := DirAccess.make_dir_recursive_absolute(directory)
	if result != OK:
		return failure("Cannot open save directory %s: %s" % [directory, error_string(result)])
	# Binding an OS resource provides an exclusive process lock which the OS
	# releases even after a hard crash. No PID assumptions or stale files remain.
	# This socket never accepts connections or transmits any game data.
	var port := 16000 + (directory.sha256_text().substr(0, 8).hex_to_int() % 48000)
	var candidate := TCPServer.new()
	result = candidate.listen(port, "127.0.0.1")
	if result != OK:
		candidate.stop()
		return failure("Native save storage is busy or its local lock is unavailable (127.0.0.1:%d). Close other Arenic instances and retry: %s" % [port, error_string(result)])
	_process_lock = candidate
	return {"ok": true, "error": ""}


func _release_lock() -> void:
	if _process_lock != null:
		_process_lock.stop()
		_process_lock = null


func _remove_if_present(path: String) -> Error:
	return DirAccess.remove_absolute(path) if FileAccess.file_exists(path) else OK
