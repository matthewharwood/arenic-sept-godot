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
		check(result.get("projectile_continued", false), "Active Auto Shot resumes without replay and hits once at its frozen arrival")
		check(result.get("hazard_sources_equal", false), "First post-restart hazard damage retains caster and attack")
		check(result.get("dots_continued", false), "Staggered Cleanse stacks retain exact source, tick debt, and independent expiry after process restart")
		check(result.get("gathering_continued", false), "Partial, full and half-unloaded bags resume exact deposits and 64-bit banks after process restart")
		check(result.get("advanced", false), "Continued simulation advances after restoration")
	if not failed:
		check(await _worker(directory, "legacy-reader"), "A fresh reader migrates a real v1 file and resumes without the prologue")
	if not failed:
		check(await _worker(directory, "legacy-two-reader"), "A fresh reader migrates a real v2 file with honestly unknown hazard sources")
	if not failed:
		check(await _worker(directory, "legacy-three-reader"), "A fresh reader migrates a real v3 projectile using its original fixed arrival")
	if not failed:
		check(await _worker(directory, "legacy-four-reader"), "A fresh reader migrates a real v4 file without inventing retrospective Cleanse stacks")
	if not failed:
		check(await _worker(directory, "legacy-five-reader"), "A fresh reader migrates a real v5 file with its actual DOTs and empty new gathering state")
	if not failed:
		check(await _worker(directory, "legacy-six-reader"), "A fresh reader preserves all schema6 work without inventing a pending restart at tick zero")
	if not failed:
		check(await _worker(directory, "intro-writer"), "A fresh writer commits an intermediate prologue beat")
	if not failed:
		check(await _worker(directory, "intro-reader"), "A fresh reader resumes the exact prologue beat without replaying the quote")
	if not failed:
		check(await _worker(directory, "pending-writer"), "A fresh writer saves after the real canonical reset without reversing banked progress")
	if not failed:
		check(await _worker(directory, "pending-reader"), "A fresh reader holds exactly 180 countdown ticks at zero, then advances without a second reset while other arenas continue")
	if not failed:
		check(await _worker(directory, "death-writer"), "A fresh process saves automatic draft cancellation and the uninterrupted arena clock")
	if not failed:
		check(await _worker(directory, "death-reader"), "A fresh process restores the cleared draft at home and continues the source arena")
	if not failed:
		check(await _worker(directory, "scope-writer"), "A native writer saves a viewed empty arena and independent cycle phase")
	if not failed:
		check(await _worker(directory, "scope-reader"), "A fresh process restores local deselection, synchronized music and first-recruit selection")
	if not failed:
		check(await _worker(directory, "cardinal-writer"), "Cardinal fonts, direct bonus and Confession commit through SaveGames")
	if not failed:
		check(await _worker(directory, "cardinal-reader"), "Fresh native process restores Cardinal at the exact delayed-wound boundary")
	if not failed:
		check(await _worker(directory, "channels-writer"), "Native writer saves two simultaneous Cardinal channels")
	if not failed:
		check(await _worker(directory, "channels-reader"), "A fresh native process restores both beams and cancels them independently")
	if not failed:
		check(await _worker(directory, "abilities-writer"), "A native writer saves simultaneous Fortune, Auto Shot and Acid Flask casts")
	if not failed:
		check(await _worker(directory, "abilities-reader"), "Fresh native hydration restores all cast visuals and cancels only one Merchant")
	if not failed:
		check(await _worker(directory, "loot-writer"), "A native writer saves claimed equipment, an unopened reward and partial-cycle work")
	if not failed:
		check(await _worker(directory, "loot-reader"), "A fresh native process preserves fixed card outcomes, exactly-once inventory and future cycle damage")
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
			break # The child may have published its result since the loop check.
		await process_frame
	if not FileAccess.file_exists(result_path):
		if OS.is_process_running(pid):
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
