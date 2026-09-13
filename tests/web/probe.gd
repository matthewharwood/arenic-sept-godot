extends Node
## Test-only autoload. Installed only in an isolated QA export by prepare-probe.mjs.
## Reports data; normal flow remains real browser pointer/key input. F8 runs audio
## API checks (there is no shipping seek UI); F9 reads the actual framebuffer.
const PREFIX := "ARENIC_CI "
var _elapsed: float = 0.0
var _sequence: int = 0
var _busy: bool = false
var _capture: AudioEffectCapture
var _physics_seconds: float = 0.0
var _combat_presenter_id: int = 0
var _combat_assets: Dictionary = {}
var _sfx_capture: AudioEffectCapture
var _sfx_cues: Dictionary = {}
var _save_slots: Array[Dictionary] = []
var _save_refresh_msec: int = -1000

func _ready() -> void:
	if not OS.has_feature("web"):
		set_process(false)
		set_process_input(false)
		set_physics_process(false)

func _physics_process(delta: float) -> void:
	_physics_seconds += delta

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
	var result := {"center":_v2(control.get_global_transform_with_canvas() * (control.size * 0.5)),
		"rect":_rect(control.get_global_rect()), "visible":control.is_visible_in_tree()}
	if control is Button:
		result.merge({"disabled":control.disabled, "text":control.text})
	return result

func _shell() -> Variant:
	var scene: Node = get_tree().current_scene
	if scene != null and scene.scene_file_path.ends_with("/game_shell.tscn"):
		return scene
	return null

func _snapshot() -> Dictionary:
	var window := get_window()
	var scene: Node = get_tree().current_scene
	var result := {"scene":"loading", "window":_v2(Vector2(window.size)),
		"logical":_v2(window.get_visible_rect().size), "controls":{}, "saves":_save_snapshot()}
	if scene == null or not scene.is_node_ready():
		return result
	if scene.scene_file_path.ends_with("/title_scene.tscn"):
		result.scene = "title"
		result.controls = {"start":_control(scene.get_node("Start")), "continue":_control(scene.get_node("Continue"))}
		result.controls["manage"] = _control(scene.get_node("ManageSaves"))
		result["status"] = scene.get_node("Status").text
		result["picker"] = _save_picker_snapshot(scene)
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
				"identity":shell.hero.identity_id, "name":shell.hero.display_name(),
				"cell":_v2(Vector2(shell.hero.cell)), "facing":shell.hero.facing, "selected":shell.hero.selected}})
		result["combat"] = _combat_snapshot(shell)
		result["sound"] = _sound_snapshot(shell)
		result["hud"] = _hud_snapshot(shell.hud)
		result["recording"] = _recording_snapshot(shell)
		var ability := shell.hud.get_node("BottomStrip/AbilityAction") as Button
		var ability_control: Dictionary = _control(ability)
		ability_control.merge({"disabled":ability.disabled, "text":ability.text, "pressed":ability.is_pressed()})
		result.controls = {"toggle":_control(shell.hud.get_node("BottomStrip/OverviewToggle")), "ability":ability_control,
			"save_title":_control(shell.hud.get_node("TopStrip/SaveAndTitle"))}
	return result


# Observe the facade only. Cache decoded summaries for one second so this QA
# report does not parse every full recording ten times per second.
func _save_snapshot() -> Dictionary:
	var now: int = Time.get_ticks_msec()
	if now - _save_refresh_msec >= 1000:
		_save_refresh_msec = now
		_save_slots = SaveGames.list_slots()
	return {"ready":SaveGames.storage_ready, "active_slot":SaveGames.active_slot,
		"busy":SaveGames.is_busy(), "error":SaveGames.last_error,
		"revision":int(SaveGames._metadata.get("revision", 0)),
		"run_id":str(SaveGames._metadata.get("run_id", "")), "slots":_save_slots}


func _save_picker_snapshot(scene: Node) -> Dictionary:
	var picker := scene.get_node_or_null("SaveSlots") as ArenicSaveSlotPicker
	if picker == null or not picker.is_inside_tree() or not picker.is_node_ready():
		return {"visible":false}
	var rows: Array[Dictionary] = []
	for line: Node in picker._rows.get_children():
		rows.append({"slot":int(String(line.name).trim_prefix("Slot")),
			"choose":_control(line.get_node("Choose")), "remove":_control(line.get_node("Remove"))})
	return {"visible":picker.is_visible_in_tree(), "rows":rows,
		"confirm":_control(picker._confirm), "back":_control(picker.find_child("Back", true, false)),
		"detail":picker._detail.text, "working":picker._working}


# Read actual HUD controls and roster state. No extra heroes, input commands,
# timer advancement, or state mutation are introduced by this browser probe.
func _hud_snapshot(hud: ArenicWorldHUD) -> Dictionary:
	var roster := hud.get_node("BottomStrip/CharacterRoster") as ArenicRosterStrip
	var roster_state: Dictionary = _control(roster)
	var entries: Array[Dictionary] = []
	for slot: int in roster.CAPACITY:
		var point := Vector2(float(slot % 10) * roster.CELL + 7.0, floorf(float(slot) / 10.0) * roster.CELL + 7.0)
		var index: int = roster._entry_at(point)
		if index < 0:
			continue
		var entry: Dictionary = roster.entries[index]
		entries.append({"identity":int(entry.identity), "name":str(entry.name), "dead":bool(entry.get("dead", false)),
			"center":_v2(roster.get_global_transform_with_canvas() * point)})
	roster_state.merge({"capacity":roster.CAPACITY, "count":roster.entries.size(), "entries":entries,
		"selected_identity":roster.selected_identity, "hidden_count":roster.hidden_entries().size()})
	var slots: Array[Dictionary] = []
	for slot: int in range(1, 5):
		var node_name: String = "AbilityAction" if slot == 1 else "AbilitySlot%d" % slot
		var button := hud.get_node("BottomStrip/" + node_name) as Button
		var control: Dictionary = _control(button)
		control.merge({"slot":slot, "text":button.text, "disabled":button.disabled})
		slots.append(control)
	var arenas: Array[Dictionary] = []
	for index: int in 9:
		var button := hud.get_node("BottomStrip/ArenaCell%d" % index) as Button
		var control: Dictionary = _control(button)
		var style := button.get_theme_stylebox("normal") as StyleBoxFlat
		control.merge({"index":index, "text":button.text,
			"active":style.bg_color.is_equal_approx(ArenicHudTokens.color("map_active"))})
		arenas.append(control)
	var guide := hud.get_node("ControlsGuide") as Control
	var guide_state: Dictionary = _control(guide)
	guide_state["text"] = guide.get_node("GuideText").text
	return {"roster":roster_state, "slots":slots, "arenas":arenas, "guide":guide_state,
		"previous":_control(hud.get_node("BottomStrip/PreviousArena")),
		"next":_control(hud.get_node("BottomStrip/NextArena")),
		"help":_control(hud.get_node("BottomStrip/ControlsHelp")),
		"record":_control(hud.get_node("BottomStrip/RecordAction")),
		"raid":hud.get_node("BottomStrip/RaidDifficulty").text}

# Read the recording session and folded ghosts. This observes state; it never
# arms, captures, commits or advances anything.
func _recording_snapshot(shell: Variant) -> Dictionary:
	var session: ArenicRecordingSession = shell.session
	var names: PackedStringArray = ["idle", "countdown", "recording"]
	var ghosts: Array[Dictionary] = []
	for member: ArenicHeroState in shell.heroes:
		if shell.encounter.is_ghost(member):
			ghosts.append({"identity":member.identity_id, "arena":member.arena_id, "cell":_v2(Vector2(member.cell))})
	return {"state":names[int(session.state)], "countdown":session.countdown_left,
		"captured":session.events.size(), "arena":session.arena_id,
		"ghosts":ghosts, "modal_open":shell.modal.is_open(),
		"cycle":shell.encounter.cycle_position(shell.hero.arena_id)}


# Read existing gameplay/presentation state only. Infinity is represented by null
# plus is_channeling, keeping every report valid JSON without advancing a timer.
func _combat_snapshot(shell: Variant) -> Dictionary:
	var combat: ArenicCombatState = shell.combat
	if combat == null or not is_instance_valid(shell.combat_presentation):
		return {}
	var totals: Dictionary = {}
	var targets: Dictionary = {}
	for arena: ArenicArenaDefinition in shell.stage.world.arenas:
		totals[arena.arena_id] = combat.damage_for_arena(arena.arena_id)
		targets[arena.arena_id] = combat.damage_for_enemy(arena.arena_id, "boss:" + arena.arena_id)
	var bar := shell.hud.get_node("TopStrip/DamageBar") as ArenicArenaDamageBar
	var bar_material := bar.material as ShaderMaterial
	var active: Dictionary = combat.active_cast_snapshot(shell.hero)
	var remaining: float = combat.active_remaining(shell.hero)
	var hero_view: ArenicHeroView = shell.stage.hero_view
	var presenter: ArenicCombatPresentation = shell.combat_presentation
	if _combat_presenter_id != presenter.get_instance_id():
		_combat_presenter_id = presenter.get_instance_id()
		_combat_assets = _combat_asset_snapshot(presenter)
	return {
		"totals":totals, "targets":targets, "physics_seconds":_physics_seconds,
		"cooldown":combat.cooldown_remaining(shell.hero), "active":not active.is_empty(),
		"active_remaining":remaining if is_finite(remaining) else null,
		"active_elapsed":float(active.get("elapsed", 0.0)), "is_channeling":combat.is_channeling(shell.hero),
		"active_fx_count":presenter.active_effect_count(),
		"starter_ability_id":shell.hero.definition.skills[0].ability_id,
		"hero_ability_id":hero_view._ability_id,
		"hero_animation":String(hero_view.sprite.animation),
		"hero_animation_ready":hero_view.sprite.sprite_frames != null and hero_view.sprite.sprite_frames.has_animation(hero_view.sprite.animation),
		"bar":{"total":bar.total_damage, "current":bar.current_damage, "completed":bar.completed_phases,
			"phase_damage":bar.phase_damage, "foundation":bar_material.get_shader_parameter("has_foundation"),
			"fill":bar_material.get_shader_parameter("fill_fraction"), "rect":_rect(bar.get_global_rect()),
			"phase_label":shell.hud.get_node("TopStrip/PhaseLabel").text},
		"ability_status":shell.hud.get_node("BottomStrip/AbilityStatus").text,
		"assets":_combat_assets,
	}

func _combat_asset_snapshot(presenter: ArenicCombatPresentation) -> Dictionary:
	var errors: PackedStringArray = []
	var actors: Dictionary = {}
	for id: String in ["auto_shot", "bash", "backstab", "acid_flask", "heal", "cleanse", "dig", "fortune"]:
		var path := "res://assets/abilities/%s/actor_frames.tres" % id
		var frames := load(path) as SpriteFrames
		var tags: PackedStringArray = []
		for direction: String in ["n", "e", "s", "w"]:
			if id == "heal":
				for phase: String in ["connect", "channel", "release"]:
					tags.append(direction + "_" + phase)
			else:
				tags.append(id + "_" + direction)
		actors[id] = _animations_ready(frames, tags)
		if not actors[id]:
			errors.append("actor:" + id)
	var expected: Dictionary = {
		"auto_shot/projectile":["flight_e"], "auto_shot/impact":["impact"], "bash/impact":["impact"],
		"backstab/slash":["slash_n", "slash_e", "slash_s", "slash_w"],
		"acid_flask/flask":["flight"], "acid_flask/shatter":["shatter"],
		"heal/healing_aura":["restore"], "heal/life_stream":["transfer"], "heal/receiving_glow":["receive"],
		"cleanse/wave":["purify"], "cleanse/cleansed":["cleansed"], "dig/excavate":["excavate"],
		"fortune/fortune":["fortune_loop"], "fortune/prosperity":["prosperity"],
	}
	for key: String in expected:
		var frames: SpriteFrames = presenter._frames.get(key)
		if not _animations_ready(frames, PackedStringArray(expected[key])):
			errors.append("effect:" + key)
	return {"actors":actors, "effects_checked":expected.size(), "errors":errors}

func _animations_ready(frames: SpriteFrames, tags: PackedStringArray) -> bool:
	if frames == null:
		return false
	for tag: String in tags:
		if not frames.has_animation(tag) or frames.get_frame_count(tag) == 0:
			return false
		for index: int in frames.get_frame_count(tag):
			if frames.get_frame_texture(tag, index) == null:
				return false
	return true

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
		# Production clocks follow game delta, which Godot clamps on very slow
		# software-rendered frames. Observe actual playback wrap for up to 2.5
		# advancing game seconds, with an independent 20s real-time failure cap.
		var loop_started: int = Time.get_ticks_msec()
		var clock: ArenicArenaMusicClock = music.clocks[id]
		var previous_phase: float = clock.get_position()
		var advanced_seconds: float = 0.0
		row["loop_passed"] = false
		while advanced_seconds < 2.5 and Time.get_ticks_msec() - loop_started < 20000 and not row.loop_passed:
			await _wait(0.1)
			var phase: float = clock.get_position()
			advanced_seconds += fposmod(phase - previous_phase, clock.duration_seconds)
			previous_phase = phase
			for voice: Dictionary in music.snapshot().voices:
				if voice.arena_id == id:
					row["loop_position"] = voice.position
					row["loop_passed"] = voice.playing and voice.position >= 0.0 and voice.position < 2.5
		row["loop_wait_ms"] = Time.get_ticks_msec() - loop_started
		row["loop_game_seconds"] = advanced_seconds
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


# Passive SFX-bus tap: music stays connected and is excluded from this meter.
func _sound_snapshot(shell: Variant) -> Dictionary:
	var result: Dictionary = shell.sound.snapshot()
	var bus: int = AudioServer.get_bus_index(ArenicGameplayAudio.BUS)
	if _sfx_capture == null and bus >= 0:
		_sfx_capture = AudioEffectCapture.new()
		_sfx_capture.buffer_length = 0.5
		AudioServer.add_bus_effect(bus, _sfx_capture)
	var peak: float = 0.0
	var energy := Vector2.ZERO
	var count: int = 0
	if _sfx_capture != null:
		var frames: PackedVector2Array = _sfx_capture.get_buffer(_sfx_capture.get_frames_available())
		count = frames.size()
		for sample: Vector2 in frames:
			peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
			energy += sample * sample
	result.pcm = {"frames":count, "peak":peak, "left_rms":sqrt(energy.x / maxf(1.0, count)), "right_rms":sqrt(energy.y / maxf(1.0, count))}
	if _sfx_cues.is_empty():
		var errors: PackedStringArray = []
		var count_cues: int = 0
		for id: String in ["auto_shot", "bash", "backstab", "acid_flask", "heal", "cleanse", "dig", "fortune"]:
			var profile := load("res://data/audio/abilities/%s.tres" % id) as ArenicAbilitySoundProfile
			if profile == null:
				errors.append(id + ": missing profile")
				continue
			errors.append_array(profile.validation_errors())
			for phase: String in ["charge", "cast", "impact", "sustain", "end", "cancel"]:
				var cue: ArenicSoundCue = profile.cue_for_phase(phase)
				if cue != null:
					count_cues += 1
		var movement := load("res://data/audio/movement.tres") as ArenicMovementSoundProfile
		errors.append_array(movement.validation_errors())
		_sfx_cues = {"count":count_cues + 2, "errors":errors, "move_seconds":movement.move.stream.get_length()}
	result.cues = _sfx_cues
	return result
