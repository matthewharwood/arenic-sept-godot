extends SceneTree
## Actual node poses and masks without simulation/replay mutation hooks.
var _checks: int = 0
var _failed: bool = false
var _fixture: Node3D
var _stage: ArenicOverworldStage

class ArenaFixture:
	extends ArenicArenaView
	func _ready() -> void:
		pass

func _initialize() -> void:
	_run.call_deferred()

func _check(value: bool, message: String) -> void:
	_checks += 1
	if not value:
		_failed = true
		push_error("Rewind: " + message)

func _sprite() -> AnimatedSprite3D:
	var frames := SpriteFrames.new()
	frames.add_frame(&"default", PlaceholderTexture2D.new())
	frames.add_frame(&"default", PlaceholderTexture2D.new())
	var sprite := AnimatedSprite3D.new()
	sprite.sprite_frames = frames
	sprite.pixel_size = ArenicGridMath.TILE_SIZE / 19.0
	sprite.rotation.x = -PI * 0.5
	return sprite

func _run() -> void:
	_fixture = Node3D.new()
	root.add_child(_fixture)
	# The unmounted registry starts no cameras/music/saves/simulation. Its real
	# get_arena and hero_views APIs point at the mounted presentation fixtures.
	_stage = ArenicOverworldStage.new()
	_stage.world = ArenicWorldDefinition.new()
	for index: int in 2:
		var definition := ArenicArenaDefinition.new()
		definition.arena_id = "first" if index == 0 else "second"
		definition.grid_slot = Vector2i(index, 0)
		definition.visual_theme = load("res://data/themes/guild_house.tres")
		_stage.world.arenas.append(definition)
		var arena := ArenaFixture.new()
		arena.definition = definition
		_fixture.add_child(arena)
		arena._boss = _sprite()
		arena.add_child(arena._boss)
		_stage._arenas.append(arena)
	var hero := ArenicHeroView.new()
	hero.state = ArenicHeroState.new()
	hero.state.identity_id = 0
	hero.state.arena_id = "first"
	hero.sprite = _sprite()
	hero.add_child(hero.sprite)
	_fixture.add_child(hero)
	_stage.hero_views[0] = hero
	var presentation := ArenicCombatPresentation.new()
	_fixture.add_child(presentation)
	presentation.set_process(false)
	for index: int in 2:
		var effect := ArenicCombatPresentation.Effect.new()
		effect.sprite = _sprite()
		effect.label = Label3D.new()
		presentation.add_child(effect.sprite)
		presentation.add_child(effect.label)
		effect.active = true
		effect.duration = 10.0
		effect.serial = index + 1
		effect.caster_identity = index
		effect.arena_id = "first" if index == 0 else "second"
		presentation._pool.append(effect)
	var rewind := ArenicArenaRewind.new()
	_fixture.add_child(rewind)
	rewind.configure(_stage, presentation)
	for tick: int in 61:
		hero.sprite.position.x = float(tick) / 10.0
		hero.sprite.frame = 1 if tick >= 30 else 0
		rewind.capture("first", tick)
	_check(rewind.snapshot("first").samples == 21, "Sixty-Hz callers capture exactly twenty Hz including endpoints.")
	rewind.begin("first", 60)
	_check(rewind.phase("first") == "rewind" and hero.sprite.layers == 0 and _stage._arenas[0]._boss.layers == 0, "Rewind masks affected actor and boss render layers.")
	_check(_stage._arenas[1]._boss.layers == 1 and presentation._pool[1].sprite.layers == 1, "Another arena remains unmasked.")
	_check(hero.sprite.visible and presentation._pool[0].sprite.visible, "Masks leave live visibility under existing owners.")
	rewind.advance(0.025)
	_check(is_equal_approx(rewind.display_tick("first"), 45.0), "Ten-times playback reverses fifteen ticks in 25ms.")
	var clones: Array = rewind._playing["first"].clones[0]
	_check(is_equal_approx(clones[0].global_position.x, 4.5) and is_equal_approx(clones[1].global_position.x, 5.4) and is_equal_approx(clones[2].global_position.x, 6.0), "Main pose and two trailing silhouettes follow the actual reverse trajectory.")
	_check(clones[0].texture == hero.sprite.sprite_frames.get_frame_texture(&"default", 1), "Sampled native frame/facing is retained.")
	_check(clones[0].texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST and clones[0].modulate.a > clones[1].modulate.a and clones[1].modulate.a > clones[2].modulate.a, "Native filtering and successively fainter trails remain explicit.")
	hero.sprite.hide()
	hero.sprite.frame = 0
	rewind.advance(0.075)
	_check(rewind.phase("first") == "countdown" and rewind.countdown_seconds("first") == 3 and rewind.snapshot("first").visible_clones == 0, "At the captured start, clones retire and the three-second countdown begins.")
	_check(hero.sprite.layers == 1 and not hero.sprite.visible, "Restored layers cannot resurrect canonically hidden actors.")
	_check(rewind.advance(2.99).is_empty() and rewind.is_active("first"), "Countdown waits its entire duration.")
	_check(rewind.advance(0.01) == ["first"] and not rewind.is_active("first") and rewind.snapshot("first").samples == 0, "Completion emits once and releases history.")
	_check(rewind.advance(10.0).is_empty(), "Finished arenas cannot emit twice.")
	hero.sprite.show()
	rewind.capture("first", 100)
	rewind.capture("first", 103)
	rewind.capture("first", 500)
	_check(rewind.snapshot("first").samples == 1 and rewind.snapshot("first").first_tick == 500, "A missing time interval starts a new contiguous segment.")
	rewind.capture("first", 503)
	rewind.begin("first", 503)
	rewind.advance(0.005)
	_check(rewind.phase("first") == "countdown", "A late load reverses only the three captured ticks.")
	rewind.configure(_stage, presentation)
	_check(not rewind.is_active("first") and hero.sprite.layers == 1 and rewind.snapshot("first").samples == 0, "Reconfigure restores masks and clears transient activity/history.")
	rewind.begin("second", 0, false)
	_check(rewind.phase("second") == "countdown" and _stage._arenas[1]._boss.layers == 1, "Restored pending state starts countdown with canonical actors visible.")
	_check(rewind.advance(3.0) == ["second"], "Countdown-only restoration uses the shared completion boundary.")
	rewind.rewind_speed = INF
	_check(rewind.rewind_speed == 10.0, "Invalid speed falls back to the configured default.")
	_check_history_bound()
	_check_global_pose_bound()
	_check_full_cycle(rewind, hero)
	_check_captured_span(rewind, hero)
	_check_frozen_speed(rewind, hero)
	_check_overshoot(rewind, hero)
	presentation.arena_paused_lookup = func(arena_id: String) -> bool: return arena_id == "first"
	presentation._process(0.25)
	_check(presentation._pool[0].age == 0.0 and presentation._pool[1].age == 0.25 and presentation._pool[0].sprite.speed_scale == 0.0, "Only paused-arena FX freeze both motion and native animation.")
	presentation.clear_arena("first", func(identity: int) -> bool: return identity == 1)
	_check(presentation._pool[0].active, "Caster filtering preserves a free performer's paused FX.")
	presentation.clear_arena("first", func(identity: int) -> bool: return identity == 0)
	_check(not presentation._pool[0].active and presentation._pool[1].active, "Retiring a reset caster does not affect the other arena.")
	rewind.configure(null, null)
	_fixture.free()
	_stage.free()
	print("Rewind checks: %d assertions %s." % [_checks, "FAILED" if _failed else "passed"])
	quit(1 if _failed else 0)

func _check_history_bound() -> void:
	var history := ArenicRewindHistory.new()
	for tick: int in 2500:
		var frame := ArenicRewindHistory.Frame.new()
		frame.tick = tick * 3
		frame.tracks.append(0)
		history.append(frame)
	_check(history.count == 2401 and history.poses == 2401 and history.first().tick == 297 and history.last().tick == 7497, "Packed ring retains its bounded newest window.")
	_check(history.at(history.floor_index(301.5)).tick == 300, "Fractional playback finds the preceding sample.")
	history.clear()
	_check(history.count == 0 and history.poses == 0 and history.first() == null, "Clear releases every frame and pose reference.")

func _check_full_cycle(rewind: ArenicArenaRewind, hero: ArenicHeroView) -> void:
	for speed: float in [1.0, 10.0, 20.0, 30.0]:
		rewind.rewind_speed = speed
		_capture_span(rewind, hero, 0, 7200)
		var state: Dictionary = rewind.snapshot("first")
		_check(state.samples == 2401 and state.first_tick == 0 and state.last_tick == 7200, "A full 120-second played cycle retains all 2401 bounded pose samples.")
		rewind.begin("first", 7200)
		var frames: int = 240 if speed == 30.0 else 300
		var tick_step: float = 30.0 if speed == 30.0 else 24.0
		var reverse_completed: Array[String] = []
		var contiguous: bool = true
		for frame: int in frames - 1:
			reverse_completed.append_array(rewind.advance(1.0 / 60.0))
			var expected_tick: float = 7200.0 - (frame + 1) * tick_step
			var clones: Array = rewind._playing["first"].clones[0]
			contiguous = contiguous and rewind.phase("first") == "rewind" and is_equal_approx(rewind.display_tick("first"), expected_tick) and is_equal_approx(clones[0].position.x, expected_tick / 60.0)
		_check(contiguous and reverse_completed.is_empty() and rewind.snapshot("first").samples == 2401, "Every reverse frame traverses the entire retained trajectory without truncating history or skipping to its start at configured %sx." % speed)
		_check(rewind.advance(1.0 / 60.0).is_empty() and rewind.phase("first") == "countdown" and rewind.countdown_seconds("first") == 3, "A full cycle begins its fresh countdown at frame %d: at most five seconds, or four at 30x." % frames)
		var completed: Array[String] = []
		for tick: int in 179:
			completed.append_array(rewind.advance(1.0 / 60.0))
		_check(completed.is_empty() and rewind.is_active("first"), "The full-cycle countdown stays pending through 179 physics steps.")
		completed.append_array(rewind.advance(1.0 / 60.0))
		_check(completed == ["first"] and not rewind.is_active("first") and rewind.advance(1.0 / 60.0).is_empty(), "Physics step 180 completes the full-cycle countdown exactly once.")
	rewind.rewind_speed = 10.0

func _capture_span(rewind: ArenicArenaRewind, hero: ArenicHeroView, first: int, last: int) -> void:
	for tick: int in range(first, last + 1, 3):
		hero.sprite.position.x = float(tick) / 60.0
		hero.sprite.frame = 0 if tick < 3600 else 1
		rewind.capture("first", tick)

func _check_captured_span(rewind: ArenicArenaRewind, hero: ArenicHeroView) -> void:
	# A late load has only thirty observed seconds, although its clock reads 120.
	for span: Array in [[0, 1800], [5400, 7200]]:
		_capture_span(rewind, hero, span[0], span[1])
		rewind.begin("first", span[1])
		rewind.advance(1.0)
		var state: Dictionary = rewind.snapshot("first")
		_check(state.samples == 601 and state.first_tick == span[0] and state.last_tick == span[1] and is_equal_approx(state.display_tick, float(span[1] - 600)), "Short and partially captured histories retain their exact endpoints and the configured 10x rate.")
		rewind.advance(1.999)
		_check(rewind.phase("first") == "rewind" and rewind.display_tick("first") > span[0], "A thirty-second observed span lasts three seconds even at a late cycle position.")
		rewind.advance(0.001)
		_check(rewind.phase("first") == "countdown" and rewind.countdown_seconds("first") == 3, "The cap does not lengthen a shorter rewind or change its countdown.")
		_check(rewind.advance(3.0) == ["first"], "A short rewind completes through the shared countdown boundary.")
	# Even a slow Inspector value cannot stretch six observed seconds past five.
	rewind.rewind_speed = 1.0
	_capture_span(rewind, hero, 6000, 6360)
	rewind.begin("first", 6360)
	rewind.advance(4.0)
	_check(is_equal_approx(rewind.display_tick("first"), 6072.0) and rewind.snapshot("first").samples == 121, "A slow configured rate accelerates only as needed for the actual captured span.")
	rewind.advance(1.0)
	_check(rewind.phase("first") == "countdown" and rewind.countdown_seconds("first") == 3, "A six-second partial span at configured 1x meets the same five-second maximum.")
	_check(rewind.advance(3.0) == ["first"], "The capped partial span retains all three countdown seconds.")
	rewind.rewind_speed = 10.0

func _check_frozen_speed(rewind: ArenicArenaRewind, hero: ArenicHeroView) -> void:
	for speeds: Array in [[10.0, 1.0], [1.0, 30.0]]:
		rewind.rewind_speed = speeds[0]
		_capture_span(rewind, hero, 0, 7200)
		rewind.begin("first", 7200)
		rewind.advance(2.0)
		_check(is_equal_approx(rewind.display_tick("first"), 4320.0), "A full captured cycle accepts a five-second playback at begin.")
		rewind.rewind_speed = speeds[1]
		rewind.advance(2.0)
		_check(rewind.phase("first") == "rewind" and is_equal_approx(rewind.display_tick("first"), 1440.0), "Changing the Inspector rate during playback neither delays nor accelerates the accepted trajectory.")
		rewind.advance(1.0)
		_check(rewind.phase("first") == "countdown" and rewind.countdown_seconds("first") == 3, "The frozen rate reaches its original five-second deadline after an Inspector edit.")
		_check(rewind.advance(3.0) == ["first"], "An Inspector edit does not alter countdown completion.")
		_capture_span(rewind, hero, 0, 60)
		rewind.begin("first", 60)
		rewind.advance(1.0 / float(speeds[1]))
		_check(rewind.phase("first") == "countdown" and rewind.countdown_seconds("first") == 3, "The next playback accepts the edited configured rate.")
		rewind.advance(3.0)
	rewind.rewind_speed = 10.0

func _check_overshoot(rewind: ArenicArenaRewind, hero: ArenicHeroView) -> void:
	_capture_span(rewind, hero, 0, 7200)
	rewind.begin("first", 7200)
	_check(rewind.advance(5.5).is_empty() and rewind.phase("first") == "countdown", "A large frame crosses the five-second rewind boundary into countdown.")
	_check(is_equal_approx(rewind._playing["first"].countdown, 2.5), "The remaining half-second is consumed by countdown instead of being discarded.")
	_check(rewind.advance(2.499).is_empty() and rewind.is_active("first"), "Countdown does not complete early after a boundary-crossing frame.")
	_check(rewind.advance(0.001) == ["first"] and rewind.advance(1.0).is_empty(), "The total eight-second transition completes exactly once despite overshoot.")
	_capture_span(rewind, hero, 0, 7200)
	rewind.begin("first", 7200)
	_check(rewind.advance(8.25) == ["first"] and not rewind.is_active("first") and rewind.snapshot("first").samples == 0, "One delayed frame can finish both phases and release the full history without a second completion.")

func _check_global_pose_bound() -> void:
	var controller := ArenicArenaRewind.new()
	# Eviction only reads the packed identity metadata; these frames are never
	# rendered. Two frozen histories exactly occupy the global pose allowance.
	for entry: Array in [["frozen_a", 320], ["frozen_b", 25], ["new_capture", 2]]:
		var arena_id: String = entry[0]
		var tracks := PackedInt32Array()
		for identity: int in int(entry[1]):
			tracks.append(identity)
		var history := ArenicRewindHistory.new()
		var samples: int = 1 if arena_id == "new_capture" else ArenicRewindHistory.MAX_SAMPLES
		for sample: int in samples:
			var frame := ArenicRewindHistory.Frame.new()
			frame.tick = sample * 3
			frame.serial = sample
			frame.tracks = tracks
			history.append(frame)
		controller._histories[arena_id] = history
		if arena_id != "new_capture":
			controller._playing[arena_id] = ArenicArenaRewind.Playback.new()
	var total: int = 0
	var old_guard_has_candidate: bool = false
	for arena_id: String in controller._histories:
		var history: ArenicRewindHistory = controller._histories[arena_id]
		total += history.poses
		old_guard_has_candidate = old_guard_has_candidate or (not controller.is_active(arena_id) and history.count >= 2)
	_check(total == ArenicArenaRewind.MAX_POSES + 2, "The boundary fixture contains 828345 frozen poses plus a new two-pose sample.")
	_check(not old_guard_has_candidate, "A guard excluding one-sample histories would leave this concrete overflow without an eviction candidate.")
	controller._bound_history()
	total = 0
	for history: ArenicRewindHistory in controller._histories.values():
		total += history.poses
	_check(total == ArenicArenaRewind.MAX_POSES and controller._histories["new_capture"].count == 0, "The current guard evicts the single inactive frame and enforces the exact global pose limit.")
	_check(controller._histories["frozen_a"].count == 2401 and controller._histories["frozen_b"].count == 2401, "Global eviction preserves both histories currently being played.")
	controller.free()
