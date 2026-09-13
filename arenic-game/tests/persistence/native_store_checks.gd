extends SceneTree
## Real disk, restart, interrupted write, corruption, and independent-process CAS.
var checks: int = 0
var failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("Native saves: " + message)


func _run() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() == 3 and arguments[0] == "--store-worker":
		await _worker(arguments[1], arguments[2])
		return
	create_timer(30.0).timeout.connect(func():
		push_error("Native save checks timed out")
		quit(1))
	var temporary := DirAccess.create_temp("arenic-store-checks-")
	check(temporary != null, "The test uses a disposable directory")
	if temporary == null:
		quit(1)
		return
	var directory := temporary.get_current_dir()
	var backend: ArenicSaveBackend = ArenicNativeSaveBackend.new(directory)
	var first := _record(1, "first")
	var second := _record(2, "second")
	var third := _record(3, "third")
	var result: Dictionary = await backend.read_all()
	check(result.ok and result.records.is_empty(), "A new store is empty")
	check(ArenicSaveBackend.MAX_RECORD_BYTES == 64 * 1024 * 1024, "Slot capacity is explicitly bounded at 64 MiB")
	check(not (await backend.write_record(-1, 0, first)).ok, "Negative slots are rejected")
	check(not (await backend.write_record(8, 0, first)).ok, "A ninth slot is rejected")
	check(not (await backend.write_record(0, 0, second)).ok, "Skipped revisions are rejected")
	check(not (await backend.write_record(0, 0, '{"revision":1.5}')).ok, "Fractional revisions are rejected")
	check(not (await backend.write_record(0, 0, '{"revision":1,"payload_json":"x","checksum":"wrong"}')).ok, "Damaged checksums are rejected")
	check((await backend.write_record(0, 0, first)).ok, "A first revision is committed")
	check(not (await backend.write_record(0, 0, first)).ok, "A stale creator cannot overwrite the slot")
	check((await backend.write_record(0, 1, second)).ok, "A matching revision updates the slot")
	backend = ArenicNativeSaveBackend.new(directory)
	result = await backend.read_all()
	check(result.ok and result.records.get("0") == second, "A fresh backend restores exact committed bytes")
	check(not (await backend.delete_record(0, 1)).ok, "Stale deletion does not remove a newer save")
	_write(directory.path_join("slot-0.json.tmp"), third)
	check((await backend.read_all()).records.get("0") == second, "An uncommitted temporary write is ignored")
	_write(directory.path_join("slot-0.json"), '{"revision":2,"payload_json":"broken","checksum":"wrong"}')
	result = await backend.read_all()
	check(result.ok and result.records.get("0") == first, "A checksum-damaged primary recovers the previous committed record")
	check(result.warnings.size() == 1, "Recovery is reported instead of silently rolling back")
	check((await backend.write_record(0, 1, second)).ok, "Recovered revision can resume saving")
	check((await backend.delete_record(0, 2)).ok, "Matching revision explicitly deletes a slot")
	_write(directory.path_join("slot-0.json.bak"), second)
	check((await backend.read_all()).records.is_empty(), "A deletion tombstone prevents a leftover backup from resurrecting")
	check((await backend.write_record(0, 0, first)).ok, "Deleted slots can create a new first revision")
	check(not FileAccess.file_exists(directory.path_join("slot-0.json.bak")), "A new game cannot inherit the deleted game's backup")
	_write(directory.path_join("slot-1.json"), "not json")
	result = await backend.read_all()
	check(result.ok and result.records.get("1") == "not json", "Malformed data stays visible for explicit reset")
	check(not (await backend.write_record(1, 0, first)).ok, "Malformed occupied data is not overwritten as an empty slot")
	check((await backend.delete_record(1, -1)).ok, "Malformed data can be explicitly deleted")
	check(not (await backend.delete_record(0, -1)).ok, "Corruption reset cannot delete a currently valid record")
	var oversized := FileAccess.open(directory.path_join("slot-1.json"), FileAccess.WRITE)
	oversized.seek(ArenicSaveBackend.MAX_RECORD_BYTES)
	oversized.store_8(1)
	oversized.close()
	result = await backend.read_all()
	check(result.ok and ArenicSaveBackend.record_revision(result.records["1"]) == -1, "An oversized file is quarantined without reading it into memory")
	check((await backend.delete_record(1, -1)).ok, "An oversized file can be reset through the same interface")
	for slot: int in range(1, 8):
		check((await backend.write_record(slot, 0, first)).ok, "Each of the eight slots is independently writable")
	check((await backend.read_all()).records.size() == 8, "The store holds exactly eight populated slots")
	await _check_identity(directory.path_join("identity"))
	await _check_processes(directory.path_join("processes"))
	check(not (await ArenicBrowserSaveBackend.new("isolated-native-test").read_all()).ok, "Browser backend fails explicitly on native instead of falling back")
	print("Native save checks: %d assertions, %s." % [checks, "FAILED" if failed else "passed"])
	quit(1 if failed else 0)


func _record(revision: int, value: String, run_id: String = "") -> String:
	var payload := JSON.stringify({"value": value})
	var document := {"revision": revision, "payload_json": payload, "checksum": payload.sha256_text()}
	if not run_id.is_empty():
		document["run_id"] = run_id
	return JSON.stringify(document)


func _check_identity(directory: String) -> void:
	var backend := ArenicNativeSaveBackend.new(directory)
	var first_id := "a".repeat(64)
	var replacement_id := "b".repeat(64)
	var replacement := _record(1, "replacement", replacement_id)
	check((await backend.write_record(0, 0, _record(1, "first", first_id))).ok, "ABA test creates the first game")
	check((await backend.delete_record(0, 1, first_id)).ok, "The reviewed identity can be deleted")
	check((await backend.write_record(0, 0, replacement)).ok, "A replacement game reuses revision one")
	check(not (await backend.write_record(0, 1, _record(2, "stale", first_id))).ok, "A stale game's autosave cannot overwrite the replacement at the same revision")
	check((await backend.read_all()).records.get("0") == replacement, "ABA write rejection preserves the replacement bytes")
	check(not (await backend.delete_record(0, 1, first_id)).ok, "A stale confirmation cannot delete the replacement at the same revision")
	check(not (await backend.delete_record(0, 1)).ok, "An empty reviewed identity cannot erase an identified replacement")
	check((await backend.read_all()).records.get("0") == replacement, "ABA deletion rejection preserves the replacement bytes")
	check((await backend.write_record(0, 1, _record(2, "continue replacement", replacement_id))).ok, "The replacement's own next revision still commits")
	check((await backend.delete_record(0, 2, replacement_id)).ok, "The replacement's reviewed identity remains deletable")


func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(content)
	file.close()


func _spawn(directory: String, mode: String) -> int:
	return OS.create_process(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"), "--audio-driver", "Dummy",
		"--disable-file-logging", "--script", "res://tests/persistence/native_store_checks.gd",
		"--", "--store-worker", directory, mode]))


func _wait_file(path: String) -> bool:
	var deadline := Time.get_ticks_msec() + 10000
	while not FileAccess.file_exists(path) and Time.get_ticks_msec() < deadline:
		await process_frame
	return FileAccess.file_exists(path)


func _check_processes(directory: String) -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var holder := _spawn(directory, "hold")
	check(holder > 0, "An independent lock-holder process starts")
	if holder <= 0:
		return
	var ready := await _wait_file(directory.path_join("hold-ready"))
	check(ready, "An independent process acquired the native lock")
	if not ready:
		_stop_child(holder)
		return
	var backend := ArenicNativeSaveBackend.new(directory)
	check(not (await backend.write_record(0, 0, _record(1, "blocked"))).ok, "A live process's lock prevents a second writer")
	check(OS.kill(holder) == OK, "The test hard-stops only its own lock-holder child")
	# OS.kill waits/reaps on native hosts; querying that reaped PID is invalid.
	check((await backend.read_all()).ok, "Hard process exit releases the lock without manual repair")
	var first := _spawn(directory, "first")
	var second := _spawn(directory, "second")
	check(first > 0 and second > 0, "Two independent contenders started")
	if first <= 0 or second <= 0:
		_stop_child(first)
		_stop_child(second)
		return
	ready = await _wait_file(directory.path_join("first-ready")) and await _wait_file(directory.path_join("second-ready"))
	check(ready, "Both contenders wait at the same start barrier")
	if not ready:
		_stop_child(first)
		_stop_child(second)
		return
	_write(directory.path_join("go"), "go")
	ready = await _wait_file(directory.path_join("first-result")) and await _wait_file(directory.path_join("second-result"))
	check(ready, "Both independent writes return a result")
	if not ready:
		_stop_child(first)
		_stop_child(second)
		return
	var first_result: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("first-result")))
	var second_result: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("second-result")))
	check(int(first_result.ok) + int(second_result.ok) == 1, "Exactly one contender commits revision one")
	var saved: Dictionary = await backend.read_all()
	check(saved.ok and ArenicSaveBackend.record_revision(saved.records.get("0", "")) == 1, "The concurrent commit remains readable and complete")
	for pid: int in [first, second]:
		var deadline := Time.get_ticks_msec() + 3000
		while OS.is_process_running(pid) and Time.get_ticks_msec() < deadline:
			await process_frame


func _stop_child(pid: int) -> void:
	if pid > 0 and OS.is_process_running(pid):
		OS.kill(pid)


func _worker(directory: String, mode: String) -> void:
	var backend := ArenicNativeSaveBackend.new(directory)
	if mode == "hold":
		var locked := backend._acquire_lock()
		if not locked.ok:
			quit(2)
			return
		_write(directory.path_join("hold-ready"), "ready")
		while true:
			await process_frame
	_write(directory.path_join(mode + "-ready"), "ready")
	if not await _wait_file(directory.path_join("go")):
		quit(3)
		return
	var result := await backend.write_record(0, 0, _record(1, mode))
	_write(directory.path_join(mode + "-result"), JSON.stringify(result))
	quit(0)
