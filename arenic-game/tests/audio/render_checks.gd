extends SceneTree
## Real mixer verification: run with a working audio driver, not Dummy.
var shell: Node
var capture: AudioEffectCapture
var results: Dictionary = {}
var failed: bool = false
var recording := PackedVector2Array()
var director_times: Array[float] = []
var output_dir: String = "user://audio-validation"

func _process(delta: float) -> bool:
	if is_instance_valid(shell):
		var start: int = Time.get_ticks_usec()
		shell.music._process(delta)
		director_times.append(float(Time.get_ticks_usec() - start) / 1000.0)
	return false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var requested: String = OS.get_environment("ARENIC_AUDIO_TEST_OUTPUT")
	if not requested.is_empty():
		output_dir = requested
	DirAccess.make_dir_recursive_absolute(output_dir)
	capture = AudioEffectCapture.new()
	capture.buffer_length = 0.25
	AudioServer.add_bus_effect(0, capture)
	root.get_node("RunSetup").intro_step = 6 # Established-world presentation fixture.
	shell = load("res://scenes/game/game_shell.tscn").instantiate()
	root.add_child(shell)
	shell.music.set_process(false)
	shell.music.cycle_source = null
	await create_timer(0.85).timeout
	results["hum"] = await _measure(1.0)
	if results.hum.rms < 0.0001:
		failed = true
	shell.set_zoomed(true)
	await create_timer(0.85).timeout
	results["guild_house"] = await _measure(1.0)
	if results.guild_house.rms < 0.0001:
		failed = true
	# Measure directional balance using the same musical segment on both sides.
	var center: Vector3 = ArenicGridMath.arena_center(shell.stage.world.arenas[1].grid_slot)
	for direction in [-1, 1]:
		shell.stage.camera_rig.cancel_motion()
		shell.stage.camera_rig.focus_world = center + Vector3(direction * 12.0, 0.0, 0.0)
		shell.music.seek_arena(&"guild_house", 40.0)
		await create_timer(0.25).timeout
		results["pan_%d" % direction] = await _measure(0.6)
	var left_ratio: float = results["pan_1"].left_rms / maxf(0.000001, results["pan_1"].right_rms)
	var right_ratio: float = results["pan_-1"].left_rms / maxf(0.000001, results["pan_-1"].right_rms)
	if left_ratio < right_ratio * 1.2:
		failed = true
	# Exercise every real MP3 across its own encoded endpoint.
	var loops: Array[Dictionary] = []
	for index in 9:
		shell.select_arena(index)
		await create_timer(0.85).timeout
		var id := StringName(shell.stage.world.arenas[index].arena_id)
		shell.music.seek_arena(id, shell.music.clocks[id].duration_seconds - 0.30)
		await create_timer(0.80).timeout
		var state: Dictionary = shell.music.snapshot()
		for voice: Dictionary in state.voices:
			if voice.arena_id == id:
				var passed: bool = voice.playing and voice.position < 1.5
				loops.append({"arena": id, "wrapped_position": voice.position, "passed": passed})
				failed = failed or not passed
	results["native_loops"] = loops
	# A 50-input burst faster than the debounce must not open discarded streams.
	var before: int = shell.music.voices_started
	var burst_peak: float = 0.0
	var max_voices: int = 0
	capture.clear_buffer()
	for index in 50:
		shell.select_arena(index % 9)
		await create_timer(0.025).timeout
		var active: int = 0
		for voice: Dictionary in shell.music.snapshot().voices:
			active += 1 if voice.playing else 0
		max_voices = maxi(max_voices, active)
		for sample in capture.get_buffer(capture.get_frames_available()):
			burst_peak = maxf(burst_peak, maxf(absf(sample.x), absf(sample.y)))
	results["burst_peak"] = burst_peak
	results["max_burst_voices"] = max_voices
	failed = failed or burst_peak >= 0.95 or max_voices > 2
	results["burst_starts"] = shell.music.voices_started - before
	await create_timer(1.0).timeout
	results["final"] = shell.music.snapshot()
	results["burst_mix"] = await _measure(1.0)
	failed = failed or results.burst_starts != 0 or results.final.desired != "bastion"
	shell.set_zoomed(false)
	await create_timer(0.85).timeout
	results["overview_return"] = shell.music.snapshot()
	director_times.sort()
	results["director_cpu_ms"] = {"frames": director_times.size(), "p95": director_times[int(director_times.size() * 0.95)], "p99": director_times[int(director_times.size() * 0.99)], "max": director_times.back()}
	results["driver"] = AudioServer.get_driver_name()
	results["passed"] = not failed
	var file := FileAccess.open(output_dir.path_join("native-mix.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "  "))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = true
	wav.mix_rate = int(AudioServer.get_mix_rate())
	var pcm := PackedByteArray()
	pcm.resize(recording.size() * 4)
	for index in recording.size():
		pcm.encode_s16(index * 4, int(clampf(recording[index].x, -1.0, 1.0) * 32767.0))
		pcm.encode_s16(index * 4 + 2, int(clampf(recording[index].y, -1.0, 1.0) * 32767.0))
	wav.data = pcm
	wav.save_to_wav(output_dir.path_join("native-mix.wav"))
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
	shell.free()
	shell = null
	capture = null
	file.close()
	# Let the audio thread retire stopped playbacks before engine teardown.
	await create_timer(0.10).timeout
	print("Native music mixer checks passed: ", not failed)
	quit(1 if failed else 0)

func _measure(seconds: float) -> Dictionary:
	capture.clear_buffer()
	var sum_left: float = 0.0
	var sum_right: float = 0.0
	var peak: float = 0.0
	var count: int = 0
	var end: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < end:
		await create_timer(0.04).timeout
		var samples: PackedVector2Array = capture.get_buffer(capture.get_frames_available())
		recording.append_array(samples)
		for sample in samples:
			sum_left += sample.x * sample.x
			sum_right += sample.y * sample.y
			peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
		count += samples.size()
	return {"frames": count, "rms": sqrt((sum_left + sum_right) / maxf(1.0, count * 2.0)),
		"left_rms": sqrt(sum_left / maxf(1.0, count)), "right_rms": sqrt(sum_right / maxf(1.0, count)), "peak": peak}
