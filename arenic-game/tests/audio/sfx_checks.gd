extends SceneTree
## Typed resources and real shell/model/audio integration; headless + Dummy is valid.
## Explicit model steps inspect policy, not subjective sound or device latency.
const SHELL_PATH: String = "res://scenes/game/game_shell.tscn"
const RETIRE_AUDIO: GDScript = preload("res://tests/support/audio_retirement.gd")
const IDS: PackedStringArray = ["auto_shot", "bash", "backstab", "acid_flask", "heal", "cleanse", "dig", "fortune"]
const CLASSES: PackedStringArray = ["hunter", "warrior", "thief", "alchemist", "cardinal", "bard", "forager", "merchant"]

var _shell: Variant # Deferred load: RunSetup exists before GameShell is parsed.
var _setup: Node
var _sound: ArenicGameplayAudio
var _hero: ArenicHeroState
var _combat: ArenicCombatState
var _movement: ArenicMovementSoundProfile
var _watchdog: Timer
var _checks: int = 0
var _failed: bool = false
var _done: bool = false
var _muted: bool = false
var _master_changed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_watchdog = Timer.new()
	_watchdog.one_shot = true
	_watchdog.wait_time = 25.0
	root.add_child(_watchdog)
	_watchdog.timeout.connect(func(): _finish(1, "SFX checks exceeded the 25-second watchdog."))
	_watchdog.start()
	_muted = AudioServer.is_bus_mute(0)
	_master_changed = true
	AudioServer.set_bus_mute(0, true)
	if not _resources():
		_finish(1, "SFX resources are invalid.")
		return
	_setup = root.get_node("RunSetup")
	_setup.begin_new_game()
	_setup.choose_class(load("res://data/classes/hunter.tres"))
	var packed := load(SHELL_PATH) as PackedScene
	_shell = packed.instantiate()
	root.add_child(_shell)
	_shell.set_physics_process(false)
	_shell.music.set_process(false)
	_choose("hunter", Vector2i(30, 15))
	_check_streams_and_bus()
	_check_charge_release_hit()
	_check_miss_and_movement()
	_check_cancel_fade()
	_check_focus_and_stage()
	await _check_pool()
	if not _done:
		await _check_pending_loop()
	if not _done:
		_finish(1 if _failed else 0, "SFX checks: %d assertions, %s; 22 cues, model phases, private loops, 12 bounded voices and lifecycle handoff." % [_checks, "FAILED" if _failed else "passed"])

func _resources() -> bool:
	var paths: Dictionary = {}
	for index: int in IDS.size():
		var profile := load("res://data/audio/abilities/%s.tres" % IDS[index]) as ArenicAbilitySoundProfile
		if not _check(profile != null and profile.validation_errors().is_empty(), "Each starter profile validates with its real imported sounds."):
			return false
		var definition := load("res://data/classes/%s.tres" % CLASSES[index]) as ArenicClassDefinition
		_check(definition.skills[0].audio_profile == profile, "The starter ability references its explicit shared profile.")
		_check(profile.end == null and profile.cancel == null and profile.cue_for_phase("unknown") == null, "Optional endings and unknown phases have no inferred clip.")
		_check((profile.charge != null) == (IDS[index] in ["auto_shot", "acid_flask"]), "Only genuine windups have charge loops.")
		_check((profile.sustain != null) == (IDS[index] in ["heal", "fortune"]), "Only the channel and aura have sustain loops.")
		for phase: String in ["charge", "cast", "impact", "sustain"]:
			var cue: ArenicSoundCue = profile.cue_for_phase(phase)
			if cue == null:
				continue
			paths[cue.stream.resource_path] = true
			_check(cue.stream is AudioStreamWAV and cue.stream.resource_path == "res://assets/audio/sfx/%s/%s.wav" % [IDS[index], phase], "Typed phases resolve the intended runtime WAV, not a filename-derived event.")
			_check(is_equal_approx(cue.fade_out_seconds, 0.035), "Every authored cue uses the explicit 35ms stop fade.")
			var charge_gain: float = -3.0 if IDS[index] == "auto_shot" else 6.0
			var sustain_gain: float = 1.0 if IDS[index] == "heal" else 0.0
			var expected: Array = {"cast":[2.0, 2, 60, false], "impact":[3.0, 3, 80, false], "charge":[charge_gain, 1, 45, true], "sustain":[sustain_gain, 1, 40, true]}[phase]
			_check(cue.volume_db == expected[0] and cue.max_instances == expected[1] and cue.priority == expected[2] and cue.loop == expected[3] and is_equal_approx(cue.min_interval_seconds, 0.045), "Starter admission policy matches its authored phase.")
	_movement = load("res://data/audio/movement.tres") as ArenicMovementSoundProfile
	if not _check(_movement != null and _movement.validation_errors().is_empty(), "Both shared movement cues validate."):
		return false
	for cue: ArenicSoundCue in [_movement.move, _movement.blocked]:
		paths[cue.stream.resource_path] = true
		_check(cue.stream is AudioStreamWAV and is_equal_approx(cue.stream.get_length(), 0.5), "Movement and blocked recordings are exactly half a second.")
		_check(not cue.loop and cue.max_instances == 1, "Movement cues are individually bounded one-shots.")
	_check(_movement.move.volume_db == 1.0 and is_equal_approx(_movement.move.min_interval_seconds, 0.065) and _movement.move.priority == 20, "Move gain/rate/priority are explicit.")
	_check(_movement.blocked.volume_db == 0.0 and is_equal_approx(_movement.blocked.min_interval_seconds, 0.1) and _movement.blocked.priority == 15, "Blocked gain/rate/priority are explicit.")
	_check(paths.size() == 22, "Exactly twenty ability and two movement WAVs are referenced.")
	var invalid := ArenicSoundCue.new()
	_check(not invalid.validation_errors().is_empty(), "A missing source is rejected.")
	invalid.stream = _movement.move.stream
	invalid.volume_db = NAN
	_check(not invalid.validation_errors().is_empty(), "Nonfinite authored gain is rejected.")
	invalid.volume_db = -8.0
	invalid.loop = true
	invalid.fade_out_seconds = 0.0
	_check(not invalid.validation_errors().is_empty(), "Loop teardown cannot request a zero fade.")
	return not _failed

func _choose(class_id: String, cell: Vector2i) -> void:
	_setup.begin_new_game()
	_setup.choose_class(load("res://data/classes/%s.tres" % class_id))
	_shell.replace_stage(_shell.stage_scene)
	_shell.set_physics_process(false)
	_shell.music.set_process(false)
	_hero = _shell.hero
	_hero.cell = cell
	_combat = _shell.combat
	_sound = _shell.sound
	_shell.select_hero()
	_shell.stage.camera_rig.cancel_motion()
	_sound.set_process(false)

func _step(seconds: float) -> void:
	_sound._process(seconds)
	_sound.set_process(false)

func _phases(loop_only: bool = false) -> PackedStringArray:
	var result: PackedStringArray = []
	for voice: Dictionary in _sound.snapshot().voices:
		if not loop_only or voice.loop:
			result.append(voice.phase)
	return result

func _check_streams_and_bus() -> void:
	var profile: ArenicAbilitySoundProfile = _hero.definition.skills[0].audio_profile
	for cue: ArenicSoundCue in [profile.charge, profile.cast, profile.impact, _movement.move, _movement.blocked]:
		var source := cue.stream as AudioStreamWAV
		var before: Vector3i = Vector3i(source.loop_mode, source.loop_begin, source.loop_end)
		var playback: AudioStreamWAV = _sound._streams[cue]
		_check(playback != source and playback.data == source.data, "Playback owns loop metadata without replacing the source PCM.")
		_check(playback.loop_mode == (AudioStreamWAV.LOOP_FORWARD if cue.loop else AudioStreamWAV.LOOP_DISABLED), "Each private stream obeys explicit loop policy.")
		_check(Vector3i(source.loop_mode, source.loop_begin, source.loop_end) == before, "Preparing a private loop preserves imported source metadata.")
		if cue.loop:
			_check(playback.loop_begin == 0 and playback.loop_end == roundi(playback.get_length() * playback.mix_rate), "Loop markers cover the complete decoded recording.")
	_check(_sound.get_child_count() == 12 and _sound.find_children("*", "AudioListener3D", true, false).is_empty(), "Twelve reusable players share the existing music listener.")
	var bus: int = AudioServer.get_bus_index(ArenicGameplayAudio.BUS)
	_check(bus >= 0 and AudioServer.get_bus_send(bus) == &"Master", "SFX routes through its own bus to Master.")
	var limiter := AudioServer.get_bus_effect(bus, 0) as AudioEffectLimiter
	_check(limiter != null and limiter.ceiling_db == -3.0, "New SFX bus limits peaks at -3dB.")
	for child: Node in _sound.get_children():
		var player := child as AudioStreamPlayer3D
		_check(player.max_polyphony == 1 and player.playback_type == AudioServer.PLAYBACK_TYPE_STREAM and player.bus == ArenicGameplayAudio.BUS, "Every spatial voice has bounded streamed playback.")

func _check_charge_release_hit() -> void:
	_check(_combat.try_cast(_hero).is_empty(), "Hunter accepts an in-range cast.")
	_check(_phases(true) == PackedStringArray(["charge"]), "Accepted windup starts only its charge loop.")
	_step(0.008)
	_combat.tick(1.0, _hero) # Release, actual hit and end in one model step.
	_check(_phases().has("cast") and _phases().has("impact") and _combat.damage_for_arena("guild_house") == 1, "A fast charge/release/hit sequence retains both real one-shots.")
	_step(0.035)
	_check(_phases(true).is_empty() and _phases().has("impact"), "Natural completion fades the charge without swallowing its impact.")
	var before: int = _sound.voices_started
	_check(not _combat.try_cast(_hero).is_empty() and _sound.voices_started == before, "Cooldown rejection emits no additional sound.")

func _check_miss_and_movement() -> void:
	_choose("warrior", Vector2i(30, 21))
	_check(_combat.try_cast(_hero).is_empty(), "Adjacent melee fixture casts.")
	_hero.cell = Vector2i(0, 0)
	_combat.tick(0.5, _hero)
	_check(_combat.damage_for_arena("guild_house") == 0 and not _phases().has("impact"), "Moving out of reach before impact produces no impact sound.")
	_sound.clear()
	var starts: int = _sound.voices_started
	_sound.movement("guild_house", _hero.cell)
	_sound.movement("guild_house", _hero.cell)
	_sound.movement("guild_house", _hero.cell, true)
	_check(_sound.voices_started == starts + 2 and _phases().has("move") and _phases().has("blocked"), "Move and blocked outcomes have distinct one-shots; rapid identical steps coalesce.")

func _check_cancel_fade() -> void:
	_choose("cardinal", Vector2i(30, 15))
	_check(_combat.try_cast(_hero).is_empty() and _phases(true).has("sustain"), "Held channel starts its sustain from a real model event.")
	_step(0.008)
	_combat.cancel_channel(_hero)
	var fading: bool = false
	for voice: Dictionary in _sound.snapshot().voices:
		if voice.loop:
			fading = fading or voice.retiring
	_check(fading, "Cancellation marks the loop for a fade rather than detaching it immediately.")
	_step(0.0175)
	for voice: Dictionary in _sound.snapshot().voices:
		if voice.loop:
			_check(voice.gain > 0.0 and voice.gain < db_to_linear(1.0), "Cancelled loop passes through an intermediate gain.")
	_step(0.0175)
	_check(_phases(true).is_empty(), "The authored fade completes and releases the channel slot.")

func _check_focus_and_stage() -> void:
	_choose("merchant", Vector2i(30, 20))
	_check(_combat.try_cast(_hero).is_empty(), "Fortune starts from the real model.")
	_combat.tick(2.25, _hero)
	_step(0.008)
	_sound.set_focus("", false)
	_step(0.035)
	_check(_sound.snapshot().active == 0, "Overview retires every SFX voice.")
	var before: int = _sound.voices_started
	_sound.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_sound.set_focus("guild_house", true)
	_check(_sound.snapshot().active == 0, "A background application cannot restore a loop.")
	var remaining: float = _combat.active_remaining(_hero)
	_sound.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	_check(_phases() == PackedStringArray(["sustain"]) and _sound.voices_started == before + 1 and _combat.active_remaining(_hero) == remaining, "Foreground restores only the existing active loop without replaying cast/impact or time.")
	var music: ArenicArenaMusicDirector = _shell.music
	var listener_id: int = music.get_node("MusicListener").get_instance_id()
	var clocks: Dictionary = {}
	for id: StringName in music.clocks:
		clocks[id] = [music.clocks[id].get_instance_id(), music.clocks[id].get_position()]
	var audio_id: int = _sound.get_instance_id()
	_shell.replace_stage(_shell.stage_scene)
	_sound.set_process(false)
	_check(_shell.sound.get_instance_id() == audio_id and _sound.snapshot().active == 0 and _combat.active_remaining(_hero) == remaining, "Stage replacement preserves the director/model and starts quietly in overview.")
	_shell.select_hero()
	_sound.set_process(false)
	_check(_phases() == PackedStringArray(["sustain"]), "Refocusing the replacement stage restores only the continuing aura loop.")
	_check(_shell.music == music and music.get_node("MusicListener").get_instance_id() == listener_id, "SFX lifecycle preserves the music director and its sole listener.")
	for id: StringName in music.clocks:
		_check(music.clocks[id].get_instance_id() == clocks[id][0] and music.clocks[id].get_position() == clocks[id][1], "SFX handoff preserves independent music clocks.")

func _emit(phase: String, cast_id: int) -> void:
	_combat.ability_phase.emit(_hero.ally_id(), _hero.definition.skills[0].ability_id, phase, "guild_house", Vector2(_hero.cell), cast_id)
	_sound.set_process(false)

func _check_pool() -> void:
	_choose("hunter", Vector2i(30, 15))
	# Test-only profile copies allow an adversarial burst without changing any
	# authored resource or waiting for gameplay cooldowns. Signals remain public.
	var definition := _hero.definition.duplicate() as ArenicClassDefinition
	definition.skills = definition.skills.duplicate()
	var ability := definition.skills[0].duplicate() as ArenicClassAbility
	var profile := ability.audio_profile.duplicate() as ArenicAbilitySoundProfile
	profile.cast = profile.cast.duplicate() as ArenicSoundCue
	profile.impact = profile.impact.duplicate() as ArenicSoundCue
	profile.sustain = profile.charge.duplicate() as ArenicSoundCue
	profile.end = profile.cast.duplicate() as ArenicSoundCue
	profile.end.max_instances = 2
	profile.end.min_interval_seconds = 0.0
	for cue: ArenicSoundCue in [profile.cast, profile.impact]:
		cue.max_instances = 8
		cue.min_interval_seconds = 0.0
	profile.impact.max_instances = 1
	ability.audio_profile = profile
	definition.skills[0] = ability
	_hero.definition = definition
	_sound.configure(_shell.stage, _hero, _combat, _movement)
	_sound.set_focus("guild_house", true)
	_emit("charge", 1)
	_emit("sustain", 2)
	for index: int in 8:
		_emit("cast", 100 + index)
	for index: int in 2:
		_emit("end", 200 + index)
	_step(0.008)
	_check(_sound.snapshot().active == 12 and _phases(true).size() == 2 and _phases().size() - _phases(true).size() == 10, "Pool reaches exactly two loop and ten one-shot slots.")
	_emit("impact", 300)
	_check(_sound.snapshot().pending == 1, "A full pool keeps a single pending replacement on its chosen voice.")
	await create_timer(0.13).timeout
	if _done:
		return
	var dropped: int = _sound.requests_dropped
	_step(0.02)
	_check(_sound.snapshot().pending == 0 and _sound.requests_dropped == dropped + 1, "A replacement older than the 100ms deadline is discarded.")
	_emit("cast", 400) # Fill the slot released by the expired request.
	_step(0.008)
	var starts: int = _sound.voices_started
	for index: int in 100:
		_emit("impact", 500 + index)
	_check(_sound.snapshot().active <= 12 and _sound.snapshot().pending == 1 and _sound.get_child_count() == 12, "Pending admission counts the cue cap: a hundred impacts keep only one replacement.")
	_emit("cast", 700)
	var impact_pending: bool = false
	for voice: ArenicGameplayAudio.Voice in _sound._voices:
		if voice.pending != null and voice.pending.cast_id == 599:
			impact_pending = true
	_check(impact_pending, "A lower-priority cast cannot overwrite an already admitted impact replacement.")
	var admitted: int = _sound.snapshot().pending
	_step(0.018)
	var found_latest: bool = false
	for voice: Dictionary in _sound.snapshot().voices:
		found_latest = found_latest or voice.cast_id == 599
	_check(found_latest and _sound.voices_started == starts + admitted and _sound.snapshot().pending == 0 and _phases().count("impact") == 1, "Only the latest impact and admitted lower-priority request start after one 18ms fade.")
	_check(_sound.peak_voices <= 12, "Peak simultaneous SFX remains bounded.")
	_sound.clear()

func _check_pending_loop() -> void:
	_choose("cardinal", Vector2i(30, 15))
	_check(_combat.try_cast(_hero).is_empty(), "Pending-loop fixture starts a real held channel.")
	_step(0.008)
	_sound.set_focus("", false)
	_sound.set_focus("guild_house", true)
	_sound.set_process(false)
	_check(_sound.snapshot().pending == 1, "Immediate refocus queues one sustain while the outgoing voice fades.")
	await create_timer(0.13).timeout
	if _done:
		return
	_combat.tick(0.75, _hero)
	_step(0.035)
	_check(_phases(true) == PackedStringArray(["sustain"]), "A still-active loop survives a stall longer than the one-shot deadline.")
	for voice: ArenicGameplayAudio.Voice in _sound._voices:
		if voice.request != null and voice.request.cue.loop:
			_check(is_equal_approx(voice.request.offset, fposmod(0.75, voice.request.cue.stream.get_length())), "Pending loop restoration seeks the current model phase after the stall.")
	_step(0.008)
	_sound.set_focus("", false)
	_sound.set_focus("guild_house", true)
	_sound.set_process(false)
	_combat.cancel_channel(_hero)
	_step(0.035)
	_check(_phases(true).is_empty() and _sound.snapshot().pending == 0, "Cancelling the model invalidates any pending loop restoration.")

func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_failed = true
		push_error("SFX check: " + message)
	return condition

func _finish(code: int, message: String) -> void:
	if _done:
		return
	_done = true
	if is_instance_valid(_watchdog):
		_watchdog.stop()
	_cleanup.call_deferred(code, message)

func _cleanup(code: int, message: String) -> void:
	if is_instance_valid(_shell):
		_shell.free()
	_sound = null
	_hero = null
	_combat = null
	if is_instance_valid(_watchdog):
		_watchdog.free()
	if not await RETIRE_AUDIO.wait_for_mixer(self):
		code = 1
	if _master_changed:
		AudioServer.set_bus_mute(0, _muted)
	print(message)
	quit(code)
