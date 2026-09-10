extends Node
## Test-only autoload. Installed only in an isolated QA export by prepare-probe.mjs.
## Reports data; normal flow remains real browser pointer/key input. F8 runs audio
## API checks (there is no shipping seek UI); F9 reads the actual framebuffer.
const PREFIX := "ARENIC_CI "
var _elapsed: float = 0.0
var _sequence: int = 0
var _busy: bool = false
var _capture: AudioEffectCapture

func _ready() -> void:
	if not OS.has_feature("web"):
		set_process(false)
		set_process_input(false)

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= 0.1:
		_elapsed = 0.0
		_emit("state", _snapshot())

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or _busy:
		return
	if event.keycode == KEY_F8:
		get_viewport().set_input_as_handled()
		_audio_suite.call_deferred()
	elif event.keycode == KEY_F9:
		get_viewport().set_input_as_handled()
		_framebuffer.call_deferred()

func _emit(kind: String, data: Dictionary) -> void:
	_sequence += 1
	print(PREFIX, JSON.stringify({"kind":kind, "sequence":_sequence, "data":data}))

func _v2(value: Vector2) -> Array:
	return [value.x, value.y]

func _v3(value: Vector3) -> Array:
	return [value.x, value.y, value.z]

func _rect(value: Rect2) -> Array:
	return [value.position.x, value.position.y, value.size.x, value.size.y]

func _control(control: Control) -> Dictionary:
	return {"center":_v2(control.get_global_transform_with_canvas() * (control.size * 0.5)),
		"rect":_rect(control.get_global_rect()), "visible":control.is_visible_in_tree()}

func _shell() -> Variant:
	var scene: Node = get_tree().current_scene
	if scene != null and scene.scene_file_path.ends_with("/game_shell.tscn"):
		return scene
	return null

func _snapshot() -> Dictionary:
	var window := get_window()
	var scene: Node = get_tree().current_scene
	var result := {"scene":"loading", "window":_v2(Vector2(window.size)),
		"logical":_v2(window.get_visible_rect().size), "controls":{}}
	if scene == null or not scene.is_node_ready():
		return result
	if scene.scene_file_path.ends_with("/title_scene.tscn"):
		result.scene = "title"
		result.controls = {"start":_control(scene.get_node("Start")), "continue":_control(scene.get_node("Continue"))}
	elif scene.scene_file_path.ends_with("/class_selection.tscn"):
		result.scene = "classes"
		result.selected_index = scene.selected_index
		result.controls = {"confirm":_control(scene.get_node("Confirm")), "back":_control(scene.get_node("Back"))}
		var cards: Array[Dictionary] = []
		for card: ArenicClassCard in scene.get_node("Cards").get_children():
			var definition: ArenicClassDefinition = card.definition
			var entry := _control(card)
			entry.merge({"id":definition.class_id, "character":definition.character_name,
				"portrait":definition.portrait != null, "frames":definition.world_sprite_frames != null})
			cards.append(entry)
		result.cards = cards
		result.character = scene.get_node("Nameplate/CharacterName").text
	else:
		var shell: Variant = _shell()
		if shell == null or not is_instance_valid(shell.stage):
			return result
		result.scene = "world"
		var rig: ArenicCameraRig = shell.stage.camera_rig
		var arena: ArenicArenaDefinition = shell.stage.world.arenas[shell.selected_index]
		var center: Vector3 = ArenicGridMath.arena_center(arena.grid_slot)
		var screen: Vector2 = rig.world_to_screen(center)
		result.merge({"selected_index":shell.selected_index, "arena":arena.arena_id,
			"zoomed":shell.zoomed, "motion_active":rig.motion_active,
			"focus":_v3(rig.focus_world), "span":_v2(rig.view_span),
			"projected_center":_v2(screen),
			"tile_pixels":screen.distance_to(rig.world_to_screen(center + Vector3(ArenicGridMath.TILE_SIZE, 0.0, 0.0))),
			"world_rect":_rect(shell.hud.get_world_rect()), "music":shell.music.snapshot(),
			"hero":{"class_id":shell.hero.definition.class_id, "arena":shell.hero.arena_id,
				"cell":_v2(Vector2(shell.hero.cell)), "facing":shell.hero.facing, "selected":shell.hero.selected}})
		result.controls = {"toggle":_control(shell.hud.get_node("BottomStrip/OverviewToggle"))}
	return result

func _framebuffer() -> void:
	_busy = true
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var result := _snapshot()
	result["framebuffer"] = _v2(Vector2(image.get_size())) if image != null else [0, 0]
	var nonblack: int = 0
	if image != null and not image.is_empty():
		for y: float in [0.1, 0.5, 0.9]:
			for x: float in [0.1, 0.5, 0.9]:
				var pixel: Color = image.get_pixel(int(x * image.get_width()), int(y * image.get_height()))
				if pixel.r + pixel.g + pixel.b > 0.01:
					nonblack += 1
	result["nonblack_samples"] = nonblack
	_emit("framebuffer", result)
	_busy = false

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _pcm() -> Dictionary:
	_capture.clear_buffer()
	await _wait(0.2)
	var samples: PackedVector2Array = _capture.get_buffer(_capture.get_frames_available())
	var energy := Vector2.ZERO
	var peak: float = 0.0
	for sample: Vector2 in samples:
		energy += sample * sample
		peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	return {"frames":samples.size(), "peak":peak,
		"left_rms":sqrt(energy.x / maxf(1.0, samples.size())),
		"right_rms":sqrt(energy.y / maxf(1.0, samples.size())),
		"passed":samples.size() > 0 and peak > 0.00001 and peak < 0.95}

func _active(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for voice: Dictionary in state.voices:
		if voice.playing:
			result.append(voice)
	return result

func _audio_suite() -> void:
	var shell: Variant = _shell()
	if shell == null:
		_emit("audio", {"passed":false, "error":"Enter the real game first."})
		return
	_busy = true
	var music: ArenicArenaMusicDirector = shell.music
	_capture = AudioEffectCapture.new()
	_capture.buffer_length = 0.5
	var effect_index: int = AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, _capture)
	var report: Dictionary = {"passed":true, "tracks":[], "driver":AudioServer.get_driver_name()}
	shell.set_zoomed(false)
	await _wait(0.85)
	report.hum = await _pcm()
	report.passed = report.passed and report.hum.passed
	shell.set_zoomed(true)
	for index: int in shell.stage.world.arenas.size():
		var id := StringName(shell.stage.world.arenas[index].arena_id)
		shell.select_arena(index)
		await _wait(0.85)
		music.seek_arena(id, 20.0)
		await _wait(0.25)
		var row: Dictionary = await _pcm()
		row["arena"] = id
		row["middle_clock"] = music.clocks[id].get_position()
		music.seek_arena(id, music.clocks[id].duration_seconds - 0.3)
		# The browser mixer and game frame clocks are asynchronous. Observe the
		# actual wrap within a bounded window instead of assuming one 0.8s sample
		# lands after it under a contended software renderer.
		var loop_started: int = Time.get_ticks_msec()
		row["loop_passed"] = false
		while Time.get_ticks_msec() - loop_started < 2500 and not row.loop_passed:
			await _wait(0.1)
			for voice: Dictionary in music.snapshot().voices:
				if voice.arena_id == id:
					row["loop_position"] = voice.position
					row["loop_passed"] = voice.playing and voice.position >= 0.0 and voice.position < 2.5
		row["loop_wait_ms"] = Time.get_ticks_msec() - loop_started
		report.tracks.append(row)
		report.passed = report.passed and row.passed and row.loop_passed
		_emit("audio_progress", row)
	# Independent pause and offset while another, silent clock continues.
	var id: StringName = &"gala"
	var other: StringName = &"guild_house"
	music.set_clock_running(id, false)
	music.seek_arena(id, 45.0)
	var other_before: float = music.clocks[other].get_position()
	await _wait(0.3)
	var pause_passed: bool = is_equal_approx(music.clocks[id].get_position(), 45.0) and music.clocks[other].get_position() > other_before
	music.set_clock_running(id, true)
	await _wait(0.3)
	var resume_passed: bool = false
	for voice: Dictionary in music.snapshot().voices:
		if voice.arena_id == id:
			resume_passed = voice.playing and absf(voice.position - 45.3) < 0.5
	report["independent_pause_seek"] = {"paused":pause_passed, "resumed":resume_passed}
	report.passed = report.passed and pause_passed and resume_passed
	# Observe a real overlap, then coalesce requests without allocating more voices.
	shell.select_arena(0)
	await _wait(0.85)
	shell.select_arena(1)
	await _wait(0.2)
	var overlap: Array[Dictionary] = _active(music.snapshot())
	var starts: int = music.voices_started
	for index: int in 50:
		shell.select_arena(index % 9)
	await _wait(1.0)
	var after: Dictionary = music.snapshot()
	report["crossfade"] = {"overlap_count":overlap.size(), "final_count":_active(after).size(),
		"final_arena":after.desired, "new_starts":music.voices_started - starts}
	report.passed = report.passed and overlap.size() == 2 and _active(after).size() == 1 and after.desired == "bastion" and music.voices_started - starts <= 1
	# Use the same stereo segment for left/right listener displacement.
	shell.select_arena(1)
	await _wait(0.85)
	var center: Vector3 = ArenicGridMath.arena_center(shell.stage.world.arenas[1].grid_slot)
	var pans: Array[Dictionary] = []
	for direction: int in [-1, 1]:
		shell.stage.camera_rig.cancel_motion()
		shell.stage.camera_rig.focus_world = center + Vector3(direction * 12.0, 0.0, 0.0)
		music.seek_arena(&"guild_house", 40.0)
		await _wait(0.25)
		pans.append(await _pcm())
	var right_ratio: float = pans[0].left_rms / maxf(0.000001, pans[0].right_rms)
	var left_ratio: float = pans[1].left_rms / maxf(0.000001, pans[1].right_rms)
	report["panning"] = {"right_ratio":right_ratio, "left_ratio":left_ratio, "passed":left_ratio > right_ratio * 1.2}
	report.passed = report.passed and report.panning.passed
	shell.set_zoomed(false)
	await _wait(0.85)
	report["final"] = music.snapshot()
	report.passed = report.passed and _active(report.final).is_empty() and report.final.hum_weight == 1.0
	AudioServer.remove_bus_effect(0, effect_index)
	_capture = null
	_emit("audio", report)
	_busy = false
