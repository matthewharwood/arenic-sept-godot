class_name ArenicGameplayAudio
extends Node3D
## Typed cues consume authoritative events. Audio never decides damage or movement.
const VOICE_LIMIT: int = 12
const LOOP_SLOTS: int = 2
const BUS: StringName = &"ArenicSFX"
const REPLACE_FADE: float = 0.018
const PENDING_LIFETIME: float = 0.10
const ATTACK_SECONDS: float = 0.008

class Request:
	extends RefCounted
	var cue: ArenicSoundCue
	var arena: String
	var cell: Vector2
	var phase: String
	var cast_id: int
	var offset: float = 0.0
	var queued_at: float = 0.0

class Voice:
	extends RefCounted
	var player: AudioStreamPlayer3D
	var request: Request
	var pending: Request
	var age: float = 0.0
	var envelope: float = 0.0
	var retiring: bool = false
	var fade_seconds: float = REPLACE_FADE
	var serial: int = 0

var voices_started: int = 0
var requests_coalesced: int = 0
var requests_dropped: int = 0
var peak_voices: int = 0
var events_received: int = 0
var _voices: Array[Voice] = []
var _streams: Dictionary = {}
var _last_played: Dictionary = {}
var _stage: ArenicOverworldStage
var _hero: ArenicHeroState
var _combat: ArenicCombatState
var _profile: ArenicAbilitySoundProfile
var _movement: ArenicMovementSoundProfile
var _focused_arena: String = ""
var _foreground: bool = true
var _serial: int = 0

func _ready() -> void:
	_ensure_bus()
	for index: int in VOICE_LIMIT:
		var voice := Voice.new()
		voice.player = AudioStreamPlayer3D.new()
		voice.player.name = "SoundVoice%d" % index
		voice.player.bus = BUS
		voice.player.max_polyphony = 1
		voice.player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		voice.player.attenuation_filter_cutoff_hz = 20500.0
		voice.player.attenuation_filter_db = 0.0
		voice.player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		voice.player.panning_strength = 0.7
		# Share the existing arena listener, using Web's spatial-capable mixer.
		voice.player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		voice.player.finished.connect(_on_finished.bind(voice))
		add_child(voice.player)
		_voices.append(voice)
	set_process(false)

func configure(stage: ArenicOverworldStage, hero: ArenicHeroState, combat: ArenicCombatState, movement: ArenicMovementSoundProfile) -> void:
	clear()
	if _combat != null and _combat.ability_phase.is_connected(_on_ability_phase):
		_combat.ability_phase.disconnect(_on_ability_phase)
	_stage = stage
	_focused_arena = ""
	_hero = hero
	_combat = combat
	_movement = movement
	_profile = hero.definition.skills[0].audio_profile if not hero.definition.skills.is_empty() else null
	_streams.clear()
	_last_played.clear()
	if _profile != null:
		for phase: String in ["charge", "cast", "impact", "sustain", "end", "cancel"]:
			_prepare_stream(_profile.cue_for_phase(phase))
	if _movement != null:
		_prepare_stream(_movement.move)
		_prepare_stream(_movement.blocked)
	_combat.ability_phase.connect(_on_ability_phase)
	_restore_loop()

func set_focus(arena_id: String, focused: bool) -> void:
	var next: String = arena_id if focused else ""
	if next == _focused_arena:
		return
	_focused_arena = next
	for voice: Voice in _voices:
		if voice.request != null and voice.request.arena != _focused_arena:
			_retire(voice)
		if voice.pending != null and voice.pending.arena != _focused_arena:
			voice.pending = null
	_restore_loop()

func movement(arena_id: String, cell: Vector2i, collided: bool = false) -> void:
	if _movement != null:
		_request(_movement.blocked if collided else _movement.move, arena_id, Vector2(cell), "blocked" if collided else "move", 0)

func _on_ability_phase(ability_id: String, phase: String, arena_id: String, cell: Vector2, cast_id: int) -> void:
	events_received += 1
	if _profile == null or _hero.definition.skills[0].ability_id != ability_id:
		return
	if phase == "cast":
		_stop_cast_loops(cast_id, "charge")
	elif phase in ["end", "cancel"]:
		_stop_cast_loops(cast_id)
	_request(_profile.cue_for_phase(phase), arena_id, cell, phase, cast_id)

func _request(cue: ArenicSoundCue, arena: String, cell: Vector2, phase: String, cast_id: int, offset: float = 0.0) -> void:
	if cue == null or not _audible(arena) or not _streams.has(cue):
		return
	var now: float = _now()
	if not cue.loop and now - float(_last_played.get(cue, -1000.0)) < cue.min_interval_seconds:
		requests_coalesced += 1
		return
	var request := Request.new()
	request.cue = cue
	request.arena = arena
	request.cell = cell
	request.phase = phase
	request.cast_id = cast_id
	request.offset = offset
	request.queued_at = now
	var first: int = 0 if cue.loop else LOOP_SLOTS
	var last: int = LOOP_SLOTS if cue.loop else VOICE_LIMIT
	var oldest: Voice
	var free: Voice
	var victim: Voice
	var matching: int = 0
	for index: int in range(first, last):
		var voice: Voice = _voices[index]
		if voice.request == null:
			if free == null:
				free = voice
			continue
		var reserved: Request = voice.pending if voice.pending != null else voice.request
		if reserved.cue == cue:
			matching += 1
			if cue.loop and reserved.cast_id == cast_id and reserved.phase == phase and (voice.pending != null or not voice.retiring):
				return
			if oldest == null or voice.serial < oldest.serial:
				oldest = voice
		if victim == null or reserved.cue.priority < _reserved_priority(victim) or (reserved.cue.priority == _reserved_priority(victim) and voice.serial < victim.serial):
			victim = voice
	var chosen: Voice = oldest if matching >= cue.max_instances else free
	if chosen == null:
		chosen = victim
	if chosen == null or (chosen.request != null and _reserved_priority(chosen) > cue.priority and matching < cue.max_instances):
		requests_dropped += 1
		return
	_last_played[cue] = now
	if chosen.request != null:
		# At most one latest replacement per voice; fade once, never backlog hits.
		chosen.pending = request
		_retire(chosen, REPLACE_FADE)
	else:
		_start(chosen, request)
	set_process(true)

func _start(voice: Voice, request: Request) -> void:
	voice.player.stop()
	voice.request = request
	voice.pending = null
	voice.age = 0.0
	voice.envelope = 0.0
	voice.retiring = false
	_serial += 1
	voice.serial = _serial
	voice.player.stream = _streams[request.cue]
	voice.player.volume_linear = 0.0
	voice.player.global_position = _point(request.arena, request.cell)
	voice.player.play(request.offset)
	voices_started += 1
	peak_voices = maxi(peak_voices, _active_count())
	set_process(true)

func _process(delta: float) -> void:
	var active: bool = false
	for voice: Voice in _voices:
		if voice.request == null:
			continue
		active = true
		voice.age += delta
		if voice.retiring:
			voice.envelope = move_toward(voice.envelope, 0.0, delta / voice.fade_seconds)
			if voice.envelope <= 0.0:
				_finish(voice)
				continue
		else:
			voice.envelope = move_toward(voice.envelope, 1.0, delta / ATTACK_SECONDS)
		if voice.request.cue.loop and _hero != null:
			voice.request.arena = _hero.arena_id
			voice.request.cell = Vector2(_hero.cell)
			if not _audible(voice.request.arena):
				_retire(voice)
			else:
				voice.player.global_position = _point(voice.request.arena, voice.request.cell)
		voice.player.volume_linear = db_to_linear(voice.request.cue.volume_db) * voice.envelope
	set_process(active)

func _on_finished(voice: Voice) -> void:
	if voice.request != null and not voice.request.cue.loop:
		_finish(voice)

func _finish(voice: Voice) -> void:
	var pending: Request = voice.pending
	voice.player.stop()
	voice.player.stream = null
	voice.request = null
	voice.pending = null
	voice.retiring = false
	if pending != null:
		var current: bool = _refresh_pending_loop(pending) if pending.cue.loop else _now() - pending.queued_at <= PENDING_LIFETIME
		if current and _audible(pending.arena):
			_start(voice, pending)
		else:
			requests_dropped += 1

static func _reserved_priority(voice: Voice) -> int:
	var request: Request = voice.pending if voice.pending != null else voice.request
	return request.cue.priority

func _refresh_pending_loop(request: Request) -> bool:
	if _combat == null or _hero == null or _profile == null:
		return false
	var state: Dictionary = _combat.active_cast_snapshot()
	if state.is_empty() or int(state.cast_id) != request.cast_id or _profile.cue_for_phase(request.phase) != request.cue:
		return false
	var expected: String = "charge" if not state.released else ("sustain" if state.effect_kind in ["channel", "aura"] else "")
	if request.phase != expected:
		return false
	request.arena = _hero.arena_id
	request.cell = Vector2(_hero.cell)
	var elapsed: float = maxf(0.0, float(state.elapsed) - (float(state.release_seconds) if expected == "sustain" else 0.0))
	request.offset = fposmod(elapsed, request.cue.stream.get_length())
	return true

func _retire(voice: Voice, fade: float = -1.0) -> void:
	if voice.request == null:
		return
	if not voice.retiring:
		voice.fade_seconds = maxf(0.005, fade if fade > 0.0 else voice.request.cue.fade_out_seconds)
		voice.retiring = true
	set_process(true)

func _stop_cast_loops(cast_id: int, phase: String = "") -> void:
	for index: int in LOOP_SLOTS:
		var voice: Voice = _voices[index]
		if voice.request != null and voice.request.cast_id == cast_id and (phase.is_empty() or voice.request.phase == phase):
			_retire(voice)
		if voice.pending != null and voice.pending.cast_id == cast_id and (phase.is_empty() or voice.pending.phase == phase):
			voice.pending = null

func _restore_loop() -> void:
	if _combat == null or _hero == null or _profile == null or not _audible(_hero.arena_id):
		return
	var state: Dictionary = _combat.active_cast_snapshot()
	if state.is_empty():
		return
	var phase: String = ""
	if not state.released:
		phase = "charge"
	elif state.effect_kind in ["channel", "aura"]:
		phase = "sustain"
	if phase.is_empty():
		return
	var cue: ArenicSoundCue = _profile.cue_for_phase(phase)
	if cue != null and _streams.has(cue):
		var elapsed: float = maxf(0.0, float(state.elapsed) - (float(state.release_seconds) if phase == "sustain" else 0.0))
		var offset: float = fposmod(elapsed, cue.stream.get_length())
		_request(cue, _hero.arena_id, Vector2(_hero.cell), phase, int(state.cast_id), offset)

func clear() -> void:
	for voice: Voice in _voices:
		voice.pending = null
		_finish(voice)

func _exit_tree() -> void:
	clear()
	if _combat != null and _combat.ability_phase.is_connected(_on_ability_phase):
		_combat.ability_phase.disconnect(_on_ability_phase)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_foreground = false
		for voice: Voice in _voices:
			voice.pending = null
			_retire(voice)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_foreground = true
		_restore_loop()

func _prepare_stream(cue: ArenicSoundCue) -> void:
	if cue == null:
		return
	var errors: PackedStringArray = cue.validation_errors()
	if not errors.is_empty():
		push_error("Invalid sound cue: " + "; ".join(errors))
		return
	var stream: AudioStream = cue.stream.duplicate() as AudioStream
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if cue.loop else AudioStreamWAV.LOOP_DISABLED
		stream.loop_begin = 0
		stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
	elif stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
		stream.loop = cue.loop
	elif cue.loop:
		push_error("Loop cue needs a WAV, MP3 or Ogg stream.")
		return
	_streams[cue] = stream

func _audible(arena: String) -> bool:
	return _foreground and not _focused_arena.is_empty() and arena == _focused_arena and is_instance_valid(_stage)

func _point(arena_id: String, cell: Vector2) -> Vector3:
	var index: int = _stage.world.index_for_id(arena_id)
	if index < 0:
		return Vector3.ZERO
	return ArenicGridMath.arena_origin(_stage.world.arenas[index].grid_slot) + Vector3(cell.x * ArenicGridMath.TILE_SIZE, 0.05, -cell.y * ArenicGridMath.TILE_SIZE)

static func _now() -> float:
	return float(Time.get_ticks_usec()) / 1000000.0

func _active_count() -> int:
	var count: int = 0
	for voice: Voice in _voices:
		if voice.request != null:
			count += 1
	return count

static func _ensure_bus() -> void:
	if AudioServer.get_bus_index(BUS) >= 0:
		return # Preserve an existing mixer layout and user gain/effects.
	var index: int = AudioServer.bus_count
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, BUS)
	AudioServer.set_bus_send(index, &"Master")
	var limiter := AudioEffectLimiter.new()
	limiter.ceiling_db = -3.0
	limiter.threshold_db = -3.0
	AudioServer.add_bus_effect(index, limiter)

func snapshot() -> Dictionary:
	var voices: Array[Dictionary] = []
	var pending: int = 0
	for voice: Voice in _voices:
		if voice.pending != null:
			pending += 1
		if voice.request != null:
			voices.append({"phase": voice.request.phase, "cast_id": voice.request.cast_id,
				"arena": voice.request.arena, "loop": voice.request.cue.loop,
				"playing": voice.player.playing, "retiring": voice.retiring,
				"position": voice.player.global_position, "gain": voice.player.volume_linear})
	return {"active": voices.size(), "pending": pending, "limit": VOICE_LIMIT,
		"peak": peak_voices, "started": voices_started, "coalesced": requests_coalesced,
		"dropped": requests_dropped, "events": events_received, "voices": voices}
