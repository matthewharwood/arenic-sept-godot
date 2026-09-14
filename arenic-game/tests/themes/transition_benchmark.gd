extends SceneTree
## Fresh-process, real-renderer benchmark; do not run beside another game instance.
## From the repository root:
## godot --path arenic-game --script res://tests/themes/transition_benchmark.gd
## Append -- --render-size=2560x1440 for a larger target (default: 1280x720).
## Width must be 320..7680 and height 180..4320; OS/window constraints may clamp it.
## Append --save after the same -- to also write user://transition_benchmark.json.
## This script changes only its own in-memory shell. No production files/cache edits.

const SHELL_PATH: String = "res://scenes/game/game_shell.tscn"
const SAVE_PATH: String = "user://transition_benchmark.json"
const SAMPLE_CAPACITY: int = 16384
const FRAME_BUDGET_MS: float = 16.67
const WATCHDOG_SECONDS: float = 15.0
## Begin at Labyrinth, then visit every other position, including long diagonals.
const CLOSE_ROUTE: PackedInt32Array = [8, 2, 6, 1, 7, 3, 5, 4]

# Deferred dynamic loading keeps RunSetup available before GameShell is parsed.
var _shell: Variant
var _rig: Variant
var _overlay: Variant
var _veil: ColorRect
var _copy: BackBufferCopy
var _control: bool = false
var _done: bool = false
var _save: bool = false
var _render_size := Vector2i(1280, 720)
var _argument_error: String = ""
var _started_usec: int = 0
var _deadline_usec: int = 0
var _last_usec: int = 0
var _count: int = 0
var _cold_phase: int = -1
var _cold_start_counters: Dictionary = {}
var _phases: Array[Dictionary] = []
var _frames_ms := PackedFloat64Array()
var _engine_fps := PackedFloat64Array()
var _draw_calls := PackedInt32Array()
var _phase_ids := PackedInt32Array()
var _motion_flags := PackedByteArray()
var _veil_flags := PackedByteArray()
var _copy_flags := PackedByteArray()
var _host: Dictionary = {}


func _initialize() -> void:
	_argument_error = _parse_arguments(OS.get_cmdline_user_args())
	_run.call_deferred()


func _parse_arguments(arguments: PackedStringArray) -> String:
	var size_seen: bool = false
	for argument: String in arguments:
		if argument == "--save":
			_save = true
		elif argument.begins_with("--render-size="):
			if size_seen:
				return "Specify --render-size only once."
			size_seen = true
			var dimensions: PackedStringArray = argument.trim_prefix("--render-size=").split("x")
			if dimensions.size() != 2 or dimensions[0].length() > 4 or dimensions[1].length() > 4:
				return "Use --render-size=WIDTHxHEIGHT (for example, 2560x1440)."
			if not dimensions[0].is_valid_int() or not dimensions[1].is_valid_int():
				return "Render width and height must be integers."
			var width: int = dimensions[0].to_int()
			var height: int = dimensions[1].to_int()
			if width < 320 or width > 7680 or height < 180 or height > 4320:
				return "Render size must be within 320..7680 pixels wide and 180..4320 high."
			_render_size = Vector2i(width, height)
		else:
			return "Unknown benchmark argument: " + argument
	return ""


func _run() -> void:
	if not _argument_error.is_empty():
		_finish(false, _argument_error)
		return
	if DisplayServer.get_name() == "headless":
		_finish(false, "A real renderer is required; headless timing is not a frame-rate measurement.")
		return
	var setup: Node = root.get_node_or_null("RunSetup")
	if setup == null:
		_finish(false, "RunSetup autoload missing; run with --path pointing to arenic-game.")
		return
	setup.call("begin_new_game")
	setup.set("intro_step", 6) # Benchmark established gameplay, without the prologue.
	# The production Display autoload skips --script runs; this probe owns its size.
	root.size = _render_size
	var packed: PackedScene = load(SHELL_PATH) as PackedScene
	if packed == null:
		_finish(false, "Actual GameShell scene failed to load.")
		return
	_shell = packed.instantiate()
	root.add_child(_shell)
	# Prevent human navigation from changing the reproducible route in this process.
	_shell.set_process_unhandled_input(false)
	await process_frame
	await process_frame
	if not is_instance_valid(_shell.stage) or _shell.stage.world.arenas.size() != 9:
		_finish(false, "GameShell did not create nine arenas.")
		return
	_rig = _shell.stage.camera_rig
	_overlay = _shell.stage.transition
	if not is_instance_valid(_overlay):
		_finish(false, "Transition overlay unavailable.")
		return
	_veil = _overlay.get("_veil") as ColorRect
	_copy = _overlay.get("_copy") as BackBufferCopy
	if _veil == null or _copy == null:
		_finish(false, "Transition does not expose the expected veil/back-buffer copy controls.")
		return
	for values: PackedFloat64Array in [_frames_ms, _engine_fps]:
		# Packed arrays are values; resize the actual fields below, not loop copies.
		assert(values.is_empty())
	_frames_ms.resize(SAMPLE_CAPACITY)
	_engine_fps.resize(SAMPLE_CAPACITY)
	_draw_calls.resize(SAMPLE_CAPACITY)
	_phase_ids.resize(SAMPLE_CAPACITY)
	_motion_flags.resize(SAMPLE_CAPACITY)
	_veil_flags.resize(SAMPLE_CAPACITY)
	_copy_flags.resize(SAMPLE_CAPACITY)
	# Exactly one GPU readback, before the measured warm-up. In Godot 4.7.2,
	# root ViewportTexture.get_size() applies stretch again; use the actual image.
	await RenderingServer.frame_post_draw
	var framebuffer: Image = root.get_texture().get_image()
	if framebuffer == null or framebuffer.is_empty():
		_finish(false, "Could not verify the rendered framebuffer before sampling.")
		return
	var framebuffer_size: Vector2i = framebuffer.get_size()
	framebuffer = null
	var logical_size: Vector2 = root.get_visible_rect().size
	var stretch: Transform2D = root.get_stretch_transform()
	_host = {
		"os": OS.get_name(),
		"engine": Engine.get_version_info(),
		"display_server": DisplayServer.get_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"rendering_driver": RenderingServer.get_current_rendering_driver_name(),
		"requested_window_size": [_render_size.x, _render_size.y],
		"window_size": [root.size.x, root.size.y],
		"framebuffer_size": [framebuffer_size.x, framebuffer_size.y],
		"logical_size": [logical_size.x, logical_size.y],
		"content_scale_size": [root.content_scale_size.x, root.content_scale_size.y],
		"content_scale_mode": root.content_scale_mode,
		"content_scale_aspect": root.content_scale_aspect,
		"content_scale_stretch": root.content_scale_stretch,
		"scaling_3d_scale": root.scaling_3d_scale,
		"logical_to_render_transform": {
			"x": [stretch.x.x, stretch.x.y], "y": [stretch.y.x, stretch.y.y],
			"origin": [stretch.origin.x, stretch.origin.y],
		},
		"vsync_mode": DisplayServer.window_get_vsync_mode(),
		"engine_max_fps": Engine.max_fps,
		"time_scale": Engine.time_scale,
		"debug_build": OS.is_debug_build(),
	}
	if root.content_scale_size != Vector2i(1280, 720):
		_finish(false, "GameShell did not retain its 1280x720 logical viewport.")
		return
	_started_usec = Time.get_ticks_usec()
	_deadline_usec = _started_usec + int(WATCHDOG_SECONDS * 1000000.0)
	# Production startup has already rendered its one-frame identity overlay pass.
	# No animated camera call occurs before the first animated-effect sample.
	# All nine materials render in overview for 1.6s; focus completes the 2s warm-up.
	_snap(0, false)
	await _wait_unmeasured(1.2)
	if _done:
		return
	await _sample_window(0.4, _new_phase("static_overview", "baseline", "static"))
	if _done:
		return
	_snap(0, true)
	await _sample_window(0.4, _new_phase("static_focus", "baseline", "static"))
	if _done:
		return
	_snap(0, false)
	await _run_mode(false)
	if _done:
		return
	_snap(0, false)
	await _run_mode(true)
	if _done:
		return
	_rig.cancel_motion()
	_finish(true, "Completed identical effect/control camera routes.")


func _run_mode(control: bool) -> void:
	_control = control
	var mode: String = "control" if control else "effect"
	var initial_phase: int = _new_phase(mode + "_initial_zoom", mode, "initial_zoom")
	if not control:
		_cold_phase = initial_phase
		_cold_start_counters = _pipeline_counts()
	# Start the clock BEFORE the first animated effect-triggering call. The next
	# process interval includes that veil render and any remaining lazy compile.
	_last_usec = Time.get_ticks_usec()
	_shell.select_arena(0)
	_shell.set_zoomed(true)
	_suppress_control()
	await _sample_motion(initial_phase)
	if _done:
		return
	_phases[initial_phase]["pipeline_after"] = _pipeline_counts()
	for destination: int in CLOSE_ROUTE:
		var phase: int = _new_phase(mode + "_close_" + str(destination), mode, "close")
		_phases[phase]["destination"] = destination
		_last_usec = Time.get_ticks_usec()
		_shell.select_arena(destination)
		_suppress_control()
		await _sample_motion(phase)
		if _done:
			return
	# Four 0.1s windows deliberately interrupt 0.55s tweens. Both passes execute
	# the same close retarget, zoom-out and reversal; no synthetic custom_step.
	var rapid: int = _new_phase(mode + "_rapid_retarget_and_zoom_reversal", mode, "rapid")
	_last_usec = Time.get_ticks_usec()
	_shell.select_arena(8)
	await _sample_window(0.1, rapid, false)
	if _done:
		return
	_last_usec = Time.get_ticks_usec()
	_shell.select_arena(0)
	await _sample_window(0.1, rapid, false)
	if _done:
		return
	_last_usec = Time.get_ticks_usec()
	_shell.set_zoomed(false)
	await _sample_window(0.1, rapid, false)
	if _done:
		return
	_last_usec = Time.get_ticks_usec()
	_shell.set_zoomed(true)
	await _sample_window(0.1, rapid, false)
	_rig.cancel_motion()
	_suppress_control()


func _snap(index: int, zoomed: bool) -> void:
	# Benchmark-only instant setup through the shell's existing framing path.
	# Avoid set_zoomed(), since even an immediately cancelled tween could warm the veil.
	_rig.cancel_motion()
	_shell.zoomed = false
	_shell.select_arena(index)
	_shell.zoomed = zoomed
	_shell.call("_frame", false)
	_shell.call("_update_hud")
	_suppress_control()


func _suppress_control() -> void:
	if _control and _veil != null and _copy != null:
		# Hide immediately after start and after each frame. _advance changes only
		# uniforms; the next _begin can re-enable these, so every new call is covered.
		_veil.visible = false
		_copy.copy_mode = BackBufferCopy.COPY_MODE_DISABLED


func _new_phase(label: String, mode: String, kind: String) -> int:
	_phases.append({"label": label, "mode": mode, "kind": kind})
	return _phases.size() - 1


func _wait_unmeasured(seconds: float) -> void:
	var end_usec: int = Time.get_ticks_usec() + int(seconds * 1000000.0)
	while Time.get_ticks_usec() < end_usec and not _done:
		await process_frame
		_check_deadline()


func _sample_window(seconds: float, phase: int, reset_clock: bool = true) -> void:
	if reset_clock:
		_last_usec = Time.get_ticks_usec()
	var end_usec: int = _last_usec + int(seconds * 1000000.0)
	while Time.get_ticks_usec() < end_usec and not _done:
		_suppress_control()
		await process_frame
		_record_frame(phase)
		_suppress_control()
		_check_deadline()


func _sample_motion(phase: int) -> void:
	if not _rig.motion_active:
		_finish(false, "Expected an active 0.55s camera move in " + str(_phases[phase]["label"]))
		return
	var frames_before: int = _count
	while _rig.motion_active and not _done:
		_suppress_control()
		await process_frame
		_record_frame(phase)
		_suppress_control()
		_check_deadline()
	if not _done and _count == frames_before:
		_finish(false, "No process frame was observed during the requested move.")


func _record_frame(phase: int) -> void:
	if _done:
		return
	if _count >= SAMPLE_CAPACITY:
		_finish(false, "Preallocated sample capacity exceeded.")
		return
	var now_usec: int = Time.get_ticks_usec()
	_frames_ms[_count] = float(now_usec - _last_usec) / 1000.0
	_last_usec = now_usec
	_engine_fps[_count] = Engine.get_frames_per_second()
	_draw_calls[_count] = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_phase_ids[_count] = phase
	_motion_flags[_count] = int(bool(_rig.motion_active))
	_veil_flags[_count] = int(_veil.visible)
	_copy_flags[_count] = int(_copy.copy_mode != BackBufferCopy.COPY_MODE_DISABLED)
	_count += 1


func _check_deadline() -> void:
	if not _done and Time.get_ticks_usec() > _deadline_usec:
		_finish(false, "15-second sampling watchdog reached; report is partial.")


func _pipeline_counts() -> Dictionary:
	return {
		"canvas": int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_CANVAS)),
		"draw": int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_DRAW)),
		"surface": int(Performance.get_monitor(Performance.PIPELINE_COMPILATIONS_SURFACE)),
	}


func _indices_for(mode: String, kind: String = "") -> PackedInt32Array:
	var indices := PackedInt32Array()
	for index: int in range(_count):
		var phase: Dictionary = _phases[_phase_ids[index]]
		if phase["mode"] == mode and (kind.is_empty() or phase["kind"] == kind):
			indices.append(index)
	return indices


func _summary(indices: PackedInt32Array) -> Dictionary:
	if indices.is_empty():
		return {"frames": 0}
	var times := PackedFloat64Array()
	times.resize(indices.size())
	var over_budget: int = 0
	var over_20: int = 0
	var over_33: int = 0
	var draw_sum: int = 0
	var draw_max: int = 0
	var fps_min: float = INF
	var fps_max: float = 0.0
	var total_ms: float = 0.0
	var active_frames: int = 0
	var veil_frames: int = 0
	var copy_frames: int = 0
	for at: int in range(indices.size()):
		var index: int = indices[at]
		var ms: float = _frames_ms[index]
		times[at] = ms
		total_ms += ms
		over_budget += int(ms > FRAME_BUDGET_MS)
		over_20 += int(ms > 20.0)
		over_33 += int(ms > 33.34)
		draw_sum += _draw_calls[index]
		draw_max = maxi(draw_max, _draw_calls[index])
		fps_min = minf(fps_min, _engine_fps[index])
		fps_max = maxf(fps_max, _engine_fps[index])
		active_frames += _motion_flags[index]
		veil_frames += _veil_flags[index]
		copy_frames += _copy_flags[index]
	times.sort()
	return {
		"frames": indices.size(), "observed_seconds": total_ms / 1000.0,
		"p50_ms": _percentile(times, 0.50), "p95_ms": _percentile(times, 0.95),
		"p99_ms": _percentile(times, 0.99), "max_ms": times[times.size() - 1],
		"mean_ms": total_ms / float(times.size()),
		"frames_over_16_67_ms": over_budget,
		"percent_over_16_67_ms": 100.0 * float(over_budget) / float(times.size()),
		"frames_over_20_ms": over_20, "frames_over_33_34_ms": over_33,
		"engine_fps_min": fps_min, "engine_fps_max": fps_max,
		"engine_fps_last": _engine_fps[indices[indices.size() - 1]],
		"draw_calls_sum_across_samples": draw_sum, "draw_calls_max": draw_max,
		"motion_active_samples": active_frames,
		"veil_visible_samples": veil_frames, "copy_enabled_samples": copy_frames,
	}


func _percentile(sorted: PackedFloat64Array, fraction: float) -> float:
	var index: int = clampi(ceili(fraction * float(sorted.size())) - 1, 0, sorted.size() - 1)
	return sorted[index]


func _finish(completed: bool, message: String) -> void:
	if _done:
		return
	_done = true
	var phases: Array[Dictionary] = []
	for phase_id: int in range(_phases.size()):
		var indices := PackedInt32Array()
		for index: int in range(_count):
			if _phase_ids[index] == phase_id:
				indices.append(index)
		var entry: Dictionary = _phases[phase_id].duplicate()
		entry["metrics"] = _summary(indices)
		phases.append(entry)
	var cold: Dictionary = {"shader_cache_deleted": false, "cache_coldness_guaranteed": false}
	if _cold_phase >= 0:
		var intervals := PackedFloat64Array()
		for index: int in range(_count):
			if _phase_ids[index] == _cold_phase and intervals.size() < 8:
				intervals.append(_frames_ms[index])
		cold["first_8_frame_intervals_ms"] = intervals
		if not intervals.is_empty():
			cold["first_frame_ms"] = intervals[0]
		cold["pipeline_before"] = _cold_start_counters
		var after: Dictionary = _phases[_cold_phase].get("pipeline_after", {})
		cold["pipeline_after"] = after
		if not after.is_empty():
			cold["pipeline_delta"] = {
				"canvas": int(after["canvas"]) - int(_cold_start_counters["canvas"]),
				"draw": int(after["draw"]) - int(_cold_start_counters["draw"]),
				"surface": int(after["surface"]) - int(_cold_start_counters["surface"]),
			}
	var groups: Dictionary = {}
	for mode: String in ["effect", "control"]:
		groups[mode + "_all_motion"] = _summary(_indices_for(mode))
		groups[mode + "_close_route"] = _summary(_indices_for(mode, "close"))
		groups[mode + "_rapid"] = _summary(_indices_for(mode, "rapid"))
	var elapsed: float = float(Time.get_ticks_usec() - _started_usec) / 1000000.0 if _started_usec > 0 else 0.0
	var report: Dictionary = {
		"schema": "arenic-transition-benchmark-v1", "completed": completed,
		"message": message, "sampling_wall_seconds": elapsed, "host": _host,
		"nominal_transition_seconds": 0.55, "warmup_seconds": 2.0,
		"route": [0, 8, 2, 6, 1, 7, 3, 5, 4],
		"mode_order": ["effect", "control"], "sample_count": _count,
		"first_animated_effect_use": cold, "phases": phases, "groups": groups,
		"notes": [
			"Intervals are process-frame wall-clock pacing, not isolated GPU execution time.",
			"Render-size requests set the window client size; OS constraints and content scaling can change actual output.",
			"Framebuffer dimensions come from one image readback before warm-up; no GPU readback occurs during timed sampling.",
			"The first animated overview-to-focus zoom is sampled, including the first interval and pipeline counters.",
			"Production startup renders one identity overlay frame before sampling; first animated use follows that prewarm.",
			"Disk/driver caches are unchanged. This measures first navigation after production prewarming, not an empty shader cache.",
			"Baseline focus/overview samples occupy the last 0.8s of the 2s material warm-up.",
			"Control keeps the same scene, culling, tweens, uniform updates and route; only the veil draw and back-buffer copy are disabled.",
			"Engine FPS and Performance monitors may lag by up to one second; use interval percentiles for segment timing.",
			"Nearest-rank percentiles; >16.67ms is reported without jitter tolerance. VSync can cause small threshold crossings.",
			"Effect runs first to preserve its first-use sample. Warm close-route groups exclude the initial zoom in both passes.",
			"This is a short, local-host benchmark; no portable performance guarantee follows from a pass.",
		],
	}
	if _save:
		var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(report, "\t"))
			file.close()
			report["saved_path"] = ProjectSettings.globalize_path(SAVE_PATH)
		else:
			report["save_error"] = FileAccess.get_open_error()
	print("TRANSITION_BENCHMARK_JSON " + JSON.stringify(report))
	quit(0 if completed else 1)
