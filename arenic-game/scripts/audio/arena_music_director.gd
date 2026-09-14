class_name ArenicArenaMusicDirector
extends Node3D
## Lives with GameShell, outside the replaceable stage. Encounter clocks own
## gameplay phase; the fixed voice pool decodes only music that can be heard.
const VOICE_LIMIT: int = 2
const DEBOUNCE_SECONDS: float = 0.10
const FADE_SECONDS: float = 0.65
const RETIRE_SECONDS: float = 0.09
const HUM_GAIN_DB: float = -26.0
const ORBIT_SECONDS: float = 48.0
const LISTENER_HEIGHT: float = 8.0
const SYNC_INTERVAL: float = 1.0
const SYNC_TOLERANCE: float = 0.12

class Voice:
	extends RefCounted
	var player: AudioStreamPlayer3D
	var arena_id: StringName = &""
	var weight: float = 0.0
	var gain_db: float = -12.0

## The encounter owns gameplay phase; an unbound director remains usable for
## isolated decoder/asset checks. Voices are always presentation, never authority.
var cycle_source: ArenicEncounterState
var suspension_lookup: Callable
var _cycle_ticks: Dictionary[StringName, int] = {}
var _cycle_seeks: Dictionary[StringName, int] = {}

var clocks: Dictionary[StringName, ArenicArenaMusicClock] = {}
var voices_started: int = 0
var sync_corrections: int = 0
var _sync_seconds: float = 0.0
var _voices: Array[Voice] = []
var _world: ArenicWorldDefinition
var _rig: ArenicCameraRig
var _listener: AudioListener3D
var _hum: AudioStreamPlayer3D
var _hum_weight: float = 0.0
var _orbit_time: float = 0.0
var _desired: StringName = &""
var _pending_seconds: float = 0.0

func _ready() -> void:
	_listener = AudioListener3D.new()
	_listener.name = "MusicListener"
	add_child(_listener)
	_listener.make_current()
	for index in VOICE_LIMIT:
		var voice := Voice.new()
		voice.player = _make_player("ArenaVoice%d" % index)
		_voices.append(voice)
	_hum = _make_player("OverworldHum")
	_hum.stream = ArenicOverworldHum.stream()

func _exit_tree() -> void:
	# Retire audio explicitly while the players still exist. A stage swap does
	# not reach this boundary; leaving the game shell does.
	for voice in _voices:
		voice.player.stop()
		voice.player.stream = null
	_hum.stop()
	_hum.stream = null
	_listener.clear_current()

func _make_player(node_name: String) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = node_name
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	player.attenuation_filter_cutoff_hz = 20500.0
	player.attenuation_filter_db = 0.0
	player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	player.max_polyphony = 1
	player.panning_strength = 0.7
	# Web's default Sample mixer lacks full spatial/effect support. Select the
	# engine stream mixer explicitly for these three bounded voices only.
	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	player.volume_linear = 0.0
	add_child(player)
	return player

func configure(stage: ArenicOverworldStage) -> void:
	_world = stage.world
	_rig = stage.camera_rig
	var next_clocks: Dictionary[StringName, ArenicArenaMusicClock] = {}
	for arena in _world.arenas:
		if arena.music == null or arena.music.id != StringName(arena.arena_id) or not arena.music.validation_errors().is_empty():
			push_error("Arena needs valid music data: " + arena.arena_id)
			continue
		var id := StringName(arena.arena_id)
		var clock: ArenicArenaMusicClock = clocks.get(id, ArenicArenaMusicClock.new())
		if not is_equal_approx(clock.duration_seconds, arena.music.loop_seconds):
			var was_running: bool = clock.running if clocks.has(id) else true
			clock.configure(arena.music.loop_seconds, clock.get_position())
			clock.running = was_running
		next_clocks[id] = clock
	clocks = next_clocks
	# Stage swaps preserve clocks while discarding obsolete playback positions.
	for voice in _voices:
		voice.player.stop()
		voice.arena_id = &""
		voice.weight = 0.0
	_desired = &""
	_pending_seconds = 0.0
	_sync_listener()

func set_focus(arena_id: StringName, focused: bool) -> void:
	var desired: StringName = arena_id if focused and clocks.has(arena_id) else &""
	if desired == _desired:
		return
	_desired = desired
	_pending_seconds = DEBOUNCE_SECONDS if not desired.is_empty() else 0.0

## Future choreography may offset or pause one arena without touching the others.
func seek_arena(arena_id: StringName, seconds: float) -> void:
	if not clocks.has(arena_id) or not is_finite(seconds):
		return
	clocks[arena_id].seek(seconds)
	for voice in _voices:
		if voice.arena_id == arena_id:
			_restart_voice(voice)

func set_clock_running(arena_id: StringName, running: bool) -> void:
	if not clocks.has(arena_id) or clocks[arena_id].running == running:
		return
	clocks[arena_id].running = running
	for voice in _voices:
		if voice.arena_id == arena_id:
			_restart_voice(voice)

func _process(delta: float) -> void:
	if _world == null or not is_instance_valid(_rig):
		return
	if cycle_source != null:
		synchronize_cycles()
	else:
		for id in clocks:
			clocks[id].advance(delta)
	_orbit_time = fposmod(_orbit_time + delta, ORBIT_SECONDS)
	_sync_listener()
	_pending_seconds = maxf(0.0, _pending_seconds - delta)
	var selected: int = _find_voice(_desired) if not _desired.is_empty() else -1
	var retiring: int = -1
	if not _desired.is_empty() and _pending_seconds == 0.0 and selected < 0:
		for index in _voices.size():
			if _voices[index].weight == 0.0:
				_start_voice(index, _desired)
				selected = index
				break
		if selected < 0:
			# A third destination never creates a third decoder. Fade the quieter
			# voice to silence before reusing it; latest requested arena wins.
			retiring = 0 if _voices[0].weight <= _voices[1].weight else 1
	for index in _voices.size():
		var voice := _voices[index]
		var target: float = voice.weight
		var duration: float = FADE_SECONDS
		if _desired.is_empty():
			target = 0.0
		elif selected >= 0 and _pending_seconds == 0.0:
			target = 1.0 if index == selected else 0.0
		elif retiring >= 0:
			target = 0.0 if index == retiring else 1.0
			duration = RETIRE_SECONDS if index == retiring else FADE_SECONDS
		voice.weight = move_toward(voice.weight, target, delta / duration)
		if voice.weight == 0.0 and target == 0.0:
			voice.player.stop()
			voice.arena_id = &""
	_hum_weight = move_toward(_hum_weight, 1.0 if _desired.is_empty() else 0.0, delta / FADE_SECONDS)
	_apply_mix()
	_sync_seconds += delta
	if _sync_seconds >= SYNC_INTERVAL:
		_sync_seconds = 0.0
		_sync_playheads()

func _sync_playheads() -> void:
	# Recover from browser audio suspension, background tabs or a long frame.
	# Clocks follow game time; decoder playheads never become timing authority.
	for voice in _voices:
		if voice.arena_id.is_empty() or not voice.player.playing:
			continue
		var clock: ArenicArenaMusicClock = clocks[voice.arena_id]
		if not clock.running:
			continue
		var actual: float = fposmod(voice.player.get_playback_position() + AudioServer.get_time_since_last_mix() * voice.player.pitch_scale, clock.duration_seconds)
		var difference: float = absf(actual - clock.get_position())
		difference = minf(difference, clock.duration_seconds - difference)
		if difference > SYNC_TOLERANCE:
			_restart_voice(voice)
			sync_corrections += 1

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_sync_seconds = SYNC_INTERVAL

func _start_voice(index: int, arena_id: StringName) -> void:
	var arena := _world.arenas[_world.index_for_id(String(arena_id))]
	var voice := _voices[index]
	voice.arena_id = arena_id
	voice.gain_db = arena.music.gain_db
	voice.player.stream = arena.music.stream
	voice.player.global_position = ArenicGridMath.arena_center(arena.grid_slot)
	voice.player.volume_linear = 0.0
	_restart_voice(voice)
	voices_started += 1

func _restart_voice(voice: Voice) -> void:
	# Godot 3D play queues until the next physics tick; seek/pause on that
	# pending playback can be ignored. Stop + play sets the latest phase even
	# in that same frame. Paused clocks retain no decoder until resumed.
	voice.player.stop()
	voice.player.pitch_scale = clocks[voice.arena_id].duration_seconds / (float(cycle_source.cycle_ticks(String(voice.arena_id))) / ArenicCycleClock.TICKS_PER_SECOND) if cycle_source != null else 1.0
	var clock: ArenicArenaMusicClock = clocks[voice.arena_id]
	if clock.running:
		voice.player.play(clock.get_position())

func _find_voice(arena_id: StringName) -> int:
	for index in _voices.size():
		if _voices[index].arena_id == arena_id:
			return index
	return -1

func _sync_listener() -> void:
	# Match screen axes while bringing the listener closer than the render
	# camera's arbitrary 60-unit height. Arena centers remain true world sources.
	_listener.global_basis = _rig.global_basis
	_listener.global_position = _rig.focus_world + _rig.global_basis.z * LISTENER_HEIGHT
	var angle: float = TAU * _orbit_time / ORBIT_SECONDS
	_hum.global_position = _listener.global_position + _listener.global_basis * Vector3(
		cos(angle) * 5.0, sin(angle) * 2.0, -6.0 + sin(angle) * 1.5)

func _apply_mix() -> void:
	# Equal-power weights; normalize interrupted fades so rapid navigation never
	# boosts the combined music bed above a single full-weight track.
	var total: float = _hum_weight
	for voice in _voices:
		total += voice.weight
	var divisor: float = maxf(1.0, total)
	for voice in _voices:
		voice.player.volume_linear = db_to_linear(voice.gain_db) * sqrt(voice.weight / divisor)
	if _hum_weight > 0.0:
		if not _hum.playing:
			_hum.play(fposmod(_orbit_time, ArenicOverworldHum.LOOP_SECONDS))
		_hum.volume_linear = db_to_linear(HUM_GAIN_DB) * sqrt(_hum_weight / divisor)
	else:
		_hum.stop()

## Small readback for diagnostics, tests, and future audio controls.
func snapshot() -> Dictionary:
	var phases: Dictionary = {}
	var durations: Dictionary = {}
	var running: Dictionary = {}
	for id in clocks:
		phases[id] = clocks[id].get_position()
		durations[id] = clocks[id].duration_seconds
		running[id] = clocks[id].running
	var voices: Array[Dictionary] = []
	for voice in _voices:
		voices.append({"arena_id": voice.arena_id, "weight": voice.weight,
			"playing": voice.player.playing, "position": voice.player.get_playback_position(),
			"source": voice.player.global_position})
	return {"desired": _desired, "pending_seconds": _pending_seconds,
		"clocks": phases, "durations": durations, "running": running, "voices": voices, "hum_weight": _hum_weight,
		"voices_started": voices_started, "sync_corrections": sync_corrections}


## Map each complete track to one complete encounter cycle, including files
## with encoder padding or slightly shorter durations. Never seek every frame.
func synchronize_cycles() -> void:
	if cycle_source == null:
		return
	for id: StringName in clocks:
		var arena_id := String(id)
		var tick: int = cycle_source.cycle_position(arena_id)
		var clock: ArenicArenaMusicClock = clocks[id]
		var phase: float = float(tick) / cycle_source.cycle_ticks(arena_id) * clock.duration_seconds
		var running: bool = not cycle_source.is_paused(arena_id) and not (suspension_lookup.is_valid() and suspension_lookup.call())
		var seek_revision: int = cycle_source.cycle_seek_revision(arena_id)
		# A slow frame can contain many legitimate fixed ticks. Its elapsed phase
		# is not a seek: restarting here repeatedly can starve queued Web audio.
		var discontinuity: bool = tick < _cycle_ticks.get(id, tick) or seek_revision != _cycle_seeks.get(id, seek_revision)
		var changed: bool = running != clock.running
		clock.seek(phase)
		clock.running = running
		_cycle_ticks[id] = tick
		_cycle_seeks[id] = seek_revision
		if discontinuity or changed:
			for voice: Voice in _voices:
				if voice.arena_id == id:
					_restart_voice(voice)
