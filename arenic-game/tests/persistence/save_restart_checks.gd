extends SceneTree
## Two fresh engine processes exercise the production service, actual scenes,
## codec, and disk store. The parent never loads the child's in-memory run.
var failed: bool = false
var checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("Save restart: " + message)


func _run() -> void:
	var temporary := DirAccess.create_temp("arenic-restart-checks-")
	if temporary == null:
		push_error("Could not create isolated restart-test directory")
		quit(1)
		return
	var directory: String = temporary.get_current_dir()
	check(await _worker(directory, "writer"), "Fresh writer commits an actual playable game")
	if not failed:
		check(await _worker(directory, "reader"), "Fresh reader continues the committed game exactly")
	if not failed:
		var result: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("reader-result.json")))
		check(result.get("continued_run_id", "") == result.get("written_run_id", "missing"), "Continue retains the unique game hash across processes")
		check(result.get("payload_equal", false), "Complete declared state survives a native process restart")
		check(result.get("advanced", false), "Continued simulation advances after restoration")
	print("Save restart checks: %d assertions, %s." % [checks, "FAILED" if failed else "passed"])
	quit(1 if failed else 0)


func _worker(directory: String, mode: String) -> bool:
	var pid: int = OS.create_process(OS.get_executable_path(), PackedStringArray([
		"--headless", "--path", ProjectSettings.globalize_path("res://"), "--audio-driver", "Dummy",
		"--disable-file-logging", "--script", "res://tests/persistence/save_restart_worker.gd",
		"--", "--restart-worker", directory, mode]))
	if pid <= 0:
		return false
	var result_path: String = directory.path_join(mode + "-result.json")
	var deadline: int = Time.get_ticks_msec() + 35000
	while not FileAccess.file_exists(result_path) and Time.get_ticks_msec() < deadline:
		if not OS.is_process_running(pid):
			return false
		await process_frame
	if not FileAccess.file_exists(result_path):
		OS.kill(pid)
		return false
	var result: Variant = JSON.parse_string(FileAccess.get_file_as_string(result_path))
	if not result is Dictionary:
		return false
	if not result.get("ok", false):
		push_error("Restart worker: " + str(result.get("error", "unknown failure")))
	var exit_deadline: int = Time.get_ticks_msec() + 5000
	while OS.is_process_running(pid) and Time.get_ticks_msec() < exit_deadline:
		await process_frame
	if OS.is_process_running(pid):
		OS.kill(pid)
		return false
	return result.get("ok", false)
