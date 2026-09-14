extends SceneTree
## Authored scores and pure conductor logic. No stage, renderer, or audio.
## Godot --headless --path arenic-game --script res://tests/encounters/score_checks.gd

const CATALOG_PATH: String = "res://data/encounters/catalog.tres"
const WORLD_PATH: String = "res://data/world/arenia.tres"
const LABYRINTH: String = "labyrinth"
const CENTRE_ORIGIN: Vector2i = Vector2i(30, 12)
const STATIONS: Array[Vector2i] = [Vector2i(30, 20), Vector2i(30, 4), Vector2i(54, 12), Vector2i(6, 12)]

var _checks: int = 0
var _failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var catalog := load(CATALOG_PATH) as ArenicEncounterCatalog
	if not _check(catalog != null, "The authored encounter catalogue loads."):
		return _finish()
	if not _check(catalog.validation_errors().is_empty(), "Every authored score satisfies its own contract: %s" % ", ".join(catalog.validation_errors())):
		return _finish()
	var score := catalog.score_for(LABYRINTH, "normal")
	if not _check(score != null, "The Labyrinth has a Normal score."):
		return _finish()
	_check_shape(score)
	_check_index(score)
	_check_rejections()
	_check_staff(score)
	_check_placement(score)
	_check_collision_pose()
	_check_boss_effects()
	_check_cleanse_clock()
	_check_world(catalog)
	_finish()


## The staff the design asks for: open at the centre, then four laps of 1-2-3-4.
func _check_shape(score: ArenicEncounterScore) -> void:
	_check(score.cycle_ticks == 7200, "The cycle is two minutes of whole simulation ticks.")
	_check(score.beats.size() == 17, "One opening beat plus four laps of four stations: %d." % score.beats.size())
	_check(score.beats[0].at_tick == 0 and score.beats[0].boss_origin_cell == CENTRE_ORIGIN, "The cycle opens at the arena centre.")
	for index: int in range(1, score.beats.size()):
		var beat: ArenicEncounterBeat = score.beats[index]
		var expected_at: int = 480 + 420 * (index - 1)
		var expected_cell: Vector2i = STATIONS[(index - 1) % STATIONS.size()]
		if not _check(beat.at_tick == expected_at and beat.boss_origin_cell == expected_cell,
				"Beat %d lands on station %d at tick %d." % [index, (index - 1) % 4 + 1, expected_at]):
			return
	var last: ArenicEncounterBeat = score.beats[score.beats.size() - 1]
	_check(score.cycle_ticks - last.at_tick == 420, "The final station holds one station length before the cycle wraps.")
	for beat: ArenicEncounterBeat in score.beats:
		if not _check(beat.blast_radius_tiles > 0.0 and beat.travel_ticks > 0 and beat.lift_tiles > 0.0, "Every landing blasts and every jump has an arc with lift."):
			return


## Positions resolve to the beat the boss is standing on, including before the
## first beat of a wrapped cycle.
func _check_index(score: ArenicEncounterScore) -> void:
	_check(score.index_at(0) == 0, "Cycle zero stands on the opening beat.")
	_check(score.index_at(479) == 0, "The opening beat holds until the first jump lands.")
	_check(score.index_at(480) == 1, "Landing exactly on a beat stands on it.")
	_check(score.index_at(7199) == 16, "The last beat holds to the end of the cycle.")
	_check(score.index_at(-1) == 16, "A tick before zero wraps onto the final beat.")
	_check(score.index_at(7680) == 1, "A tick past the cycle wraps into it.")


## Authoring mistakes must fail loudly rather than silently drop a beat.
func _check_rejections() -> void:
	var unordered := ArenicEncounterScore.new()
	unordered.arena_id = "labyrinth"
	unordered.beats = [_beat(600, Vector2i(30, 12)), _beat(300, Vector2i(30, 12))]
	_check(not unordered.validation_errors().is_empty(), "Out-of-order beats are rejected.")
	var outside := ArenicEncounterScore.new()
	outside.arena_id = "labyrinth"
	outside.beats = [_beat(7800, Vector2i(30, 12))]
	_check(not outside.validation_errors().is_empty(), "A beat past the cycle is rejected.")
	var off_grid := ArenicEncounterScore.new()
	off_grid.arena_id = "labyrinth"
	off_grid.beats = [_beat(60, Vector2i(63, 12))]
	_check(not off_grid.validation_errors().is_empty(), "A footprint hanging off the arena edge is rejected.")
	var nameless := ArenicEncounterScore.new()
	nameless.beats = [_beat(60, Vector2i(30, 12))]
	_check(not nameless.validation_errors().is_empty(), "A score without an arena is rejected.")
	var overlapping := ArenicEncounterScore.new()
	overlapping.arena_id = "labyrinth"
	var early := _beat(60, Vector2i(30, 12))
	var crowded := _beat(90, Vector2i(30, 20))
	crowded.travel_ticks = 180
	overlapping.beats = [early, crowded]
	_check(not overlapping.validation_errors().is_empty(), "A jump that leaves before the previous beat resolves is rejected.")


## The authored score converts to a performer's staff, so the boss folds into
## the merged stream exactly like a recorded hero will.
func _check_staff(score: ArenicEncounterScore) -> void:
	var staff: ArenicRecording = score.to_recording(Vector2i(6, 6))
	_check(staff.events.size() == score.beats.size(), "Every authored beat becomes one staff event.")
	_check(staff.start_cell == CENTRE_ORIGIN, "The staff starts where the cycle opens.")
	_check(staff.last_tick() == 6780, "The staff ends on the final authored beat.")
	var ordered: bool = true
	for index: int in staff.events.size():
		var event: ArenicTimelineEvent = staff.events[index]
		if event.action_id != ArenicTimelineEvent.BOSS_JUMP or event.beat != score.beats[index] or event.tick != score.beats[index].at_tick:
			ordered = false
	_check(ordered, "Each staff event carries its authored beat at its authored tick.")
	var timeline := ArenicArenaTimeline.new()
	timeline.fold("boss:labyrinth", staff)
	_check(timeline.events.size() == score.beats.size(), "Folding the boss staff merges every beat into the stream.")
	_check(timeline.due(0).size() == 1, "The opening landing is due on tick zero, like any other tick.")


## Rendered motion is derived purely from position: same input, same arc.
func _check_placement(score: ArenicEncounterScore) -> void:
	var state := ArenicEncounterState.new()
	var world := load(WORLD_PATH) as ArenicWorldDefinition
	state.configure(world, load(CATALOG_PATH) as ArenicEncounterCatalog, ArenicCombatState.new())
	state.seek(LABYRINTH, 240)
	var resting: Dictionary = state.boss_placement(LABYRINTH)
	_check(not bool(resting["airborne"]) and is_zero_approx(float(resting["lift"])), "A boss between jumps rests on the floor.")
	_check(Vector2(resting["center"]).is_equal_approx(Vector2(32.5, 14.5)), "It rests on the centre of its authored footprint.")
	_check(Vector2(resting["target"]).is_equal_approx(Vector2(32.5, 22.5)), "It already knows the ground it will strike next.")
	state.seek(LABYRINTH, 480 - 36)
	var apex: Dictionary = state.boss_placement(LABYRINTH)
	_check(bool(apex["airborne"]) and is_equal_approx(float(apex["progress"]), 0.5), "Half the arc has elapsed at half the travel time.")
	_check(is_equal_approx(float(apex["lift"]), 6.0), "The arc peaks at its authored lift, toward the camera.")
	_check(Vector2(apex["center"]).is_equal_approx(Vector2(32.5, 18.5)), "Mid-flight it is halfway between both stations.")
	state.seek(LABYRINTH, 479)
	var landing: Dictionary = state.boss_placement(LABYRINTH)
	_check(float(landing["lift"]) < 0.4, "The arc is nearly back on the floor one tick before it lands.")
	state.seek(LABYRINTH, 7194)
	var wrapping: Dictionary = state.boss_placement(LABYRINTH)
	_check(bool(wrapping["airborne"]) and Vector2(wrapping["target"]).is_equal_approx(Vector2(32.5, 14.5)), "The last jump of the cycle arcs across the wrap back to the centre.")
	_check(state.boss_placement("sanctum").is_empty(), "An arena without a score reports no placement rather than a default one.")


func _check_collision_pose() -> void:
	var world := load(WORLD_PATH) as ArenicWorldDefinition
	var combat := ArenicCombatState.new()
	combat.configure(world)
	var state := ArenicEncounterState.new()
	state.configure(world, load(CATALOG_PATH) as ArenicEncounterCatalog, combat)
	var boss_id: String = ArenicCombatState.boss_enemy_id(LABYRINTH)
	var centre := Rect2i(CENTRE_ORIGIN, Vector2i(6, 6))
	var station_one := Rect2i(STATIONS[0], Vector2i(6, 6))
	state.seek(LABYRINTH, 407)
	var grounded: Dictionary = combat.enemy_pose_lookup.call(LABYRINTH, boss_id)
	_check(grounded.footprint == centre and not grounded.airborne, "The last tick before takeoff still has grounded collision.")
	for tick: int in [408, 444, 479]:
		state.seek(LABYRINTH, tick)
		var pose: Dictionary = combat.enemy_pose_lookup.call(LABYRINTH, boss_id)
		_check(pose.airborne and pose.footprint == centre and state.boss_placement(LABYRINTH).airborne, "Collision and visible jump agree throughout takeoff, apex and final airborne tick: %d." % tick)
		_check(not combat.is_occupied(LABYRINTH, CENTRE_ORIGIN) and combat.enemies_in(LABYRINTH, centre).is_empty(), "An airborne boss occupies no ground hitbox at tick %d." % tick)
	state.seek(LABYRINTH, 480)
	_check(combat._arenas[LABYRINTH].enemies[boss_id].footprint == centre, "Seeking does not mutate the last resolved landing ledger.")
	grounded = combat.enemy_pose_lookup.call(LABYRINTH, boss_id)
	_check(grounded.footprint == station_one and not grounded.airborne, "The exact landing tick uses the new scored footprint even before its beat resolves.")
	_check(not combat.is_occupied(LABYRINTH, CENTRE_ORIGIN) and combat.is_occupied(LABYRINTH, STATIONS[0]), "Landing collision cannot linger at the old station for one combat tick.")
	state.seek(LABYRINTH, 7199)
	_check(combat.enemy_pose_lookup.call(LABYRINTH, boss_id).airborne, "The final jump stays airborne across the cycle boundary.")
	state.restart(LABYRINTH)
	grounded = combat.enemy_pose_lookup.call(LABYRINTH, boss_id)
	_check(grounded.footprint == centre and not grounded.airborne, "Restart immediately derives the grounded opening pose.")
	_check(combat.enemy_pose_lookup.call("sanctum", ArenicCombatState.boss_enemy_id("sanctum")).is_empty() and combat.enemy_pose_lookup.call(LABYRINTH, "fixture").is_empty(), "Unscored bosses and ordinary targets defer to their stored footprints.")
	var caster := ArenicHeroState.new()
	caster.definition = load("res://data/classes/hunter.tres")
	caster.arena_id = LABYRINTH
	caster.cell = Vector2i(25, 14)
	var reports: Array = []
	var impacts: Array = []
	var progress: Array = []
	combat.damage_reported.connect(func(owner: String, ability: String, arena: String, enemy: String, amount: int): reports.append([owner, ability, arena, enemy, amount]))
	combat.ability_phase.connect(func(_owner: String, _ability: String, phase: String, _arena: String, _cell: Vector2, _cast: int):
		if phase == "impact":
			impacts.append(phase))
	combat.progress_changed.connect(func(arena: String): progress.append(arena))
	state.seek(LABYRINTH, 240)
	_check(combat.try_cast(caster).is_empty(), "A grounded Hunter boss can be aimed at.")
	combat.tick(100.0)
	_check(combat.total_damage() == 1 and reports.size() == 1 and impacts.size() == 1 and progress.size() == 1, "A stationary grounded impact reports and credits exactly one hit.")
	reports.clear()
	impacts.clear()
	progress.clear()
	state.seek(LABYRINTH, 407)
	_check(combat.try_cast(caster).is_empty(), "A shot can be launched immediately before the Hunter jumps.")
	state.seek(LABYRINTH, 444)
	combat.tick(100.0)
	_check(combat.total_damage() == 1 and reports.is_empty() and impacts.is_empty() and progress.is_empty(), "A shot reaching an airborne Hunter misses without impact, report or damage credit.")
	state.seek(LABYRINTH, 240)
	_check(combat.try_cast(caster).is_empty(), "Another grounded shot captures its original aim cell.")
	state.seek(LABYRINTH, 480)
	combat.tick(100.0)
	_check(combat.total_damage() == 1 and reports.is_empty() and impacts.is_empty() and progress.is_empty(), "Landing elsewhere before arrival cannot retarget an arrow or credit a hit through the stale ledger.")
	# Exercise the real shell order, not only poses established by seeking:
	# combat advances first, then one encounter tick exposes the next pose.
	state.seek(LABYRINTH, 407)
	_check(combat.try_cast(caster).is_empty(), "A fixed-tick shot launches on the final grounded tick before takeoff.")
	var arrival_tick: int = -1
	var airborne_on_arrival: bool = false
	for step: int in 120:
		var collision_tick: int = state.cycle_position(LABYRINTH)
		combat.tick(1.0 / ArenicCycleClock.TICKS_PER_SECOND)
		var ended: bool = combat.active_remaining(caster) <= 0.0
		if ended:
			arrival_tick = collision_tick
			airborne_on_arrival = bool(state.enemy_pose(LABYRINTH, boss_id).airborne)
		state.tick(combat)
		if ended:
			break
	_check(arrival_tick >= 408 and arrival_tick < 480 and airborne_on_arrival and combat._arenas[LABYRINTH].enemies[boss_id].footprint == centre, "Fixed shell-order ticks resolve the arriving shot in the air while the raw ledger still holds the old ground footprint.")
	_check(combat.total_damage() == 1 and reports.is_empty() and impacts.is_empty() and progress.is_empty(), "The integrated airborne shot misses without hit feedback or credit.")
	var owner_ref: WeakRef = weakref(state)
	var lookup: Callable = combat.enemy_pose_lookup
	state = null
	_check(owner_ref.get_ref() == null and lookup.call(LABYRINTH, boss_id).is_empty(), "The derived-pose hook does not retain a retired encounter or create a combat reference cycle.")


func _check_boss_effects() -> void:
	var world := load(WORLD_PATH) as ArenicWorldDefinition
	var combat := ArenicCombatState.new()
	combat.configure(world)
	var state := ArenicEncounterState.new()
	_check(state.boss_effects(LABYRINTH).is_empty(), "An unconfigured encounter has no invented boss effects.")
	state.configure(world, load(CATALOG_PATH) as ArenicEncounterCatalog, combat)
	state.seek(LABYRINTH, 240)
	_check(state.boss_effects(LABYRINTH).is_empty() and state.boss_effects("unknown").is_empty(), "A grounded boss without hazards and an unknown arena have no effects.")
	var rules := load("res://data/classes/alchemist_primary.tres") as ArenicClassAbility
	var acid: ArenicAcidField = state.acid_field(LABYRINTH)
	acid.spawn(Rect2i(CENTRE_ORIGIN, Vector2i.ONE), rules)
	acid.spawn(Rect2i(CENTRE_ORIGIN, Vector2i(2, 1)), rules)
	acid._pools[1].ticks_left = 120
	acid.spawn(Rect2i(0, 0, 1, 1), rules)
	var ground: ArenicDigField = state.dig_field(LABYRINTH)
	ground.dig(CENTRE_ORIGIN)
	ground.dig(CENTRE_ORIGIN + Vector2i.RIGHT)
	ground.dig(Vector2i.ZERO)
	var effects: Array[Dictionary] = state.boss_effects(LABYRINTH)
	_check(effects.size() == 2 and effects[0].id == "acid" and effects[1].id == "broken_ground", "Only hazards touching the grounded boss appear in stable order.")
	_check(effects[0].stacks == 2 and effects[0].remaining_seconds == 2.0 and not effects[0].beneficial, "Acid counts overlapping pools and reports the earliest expiry, not the longest pool.")
	_check(effects[1].stacks == 2 and effects[1].remaining_seconds == -1.0 and not effects[1].beneficial, "Broken ground counts affecting tiles without inventing a duration or Bleed status.")
	_check(effects[0].detail.contains("pool") and effects[1].detail.contains("tile"), "Effect details explain what their stack counts mean.")
	effects[0].name = "Changed presentation copy"
	_check(state.boss_effects(LABYRINTH)[0].name == "Acid" and state.cycle_position(LABYRINTH) == 240 and acid._pools[1].ticks_left == 120 and acid._pools[1].debt == 0 and combat.total_damage() == 0, "Reading or editing returned effects cannot advance or mutate the simulation.")
	state.set_paused(LABYRINTH, true)
	_check(state.boss_effects(LABYRINTH)[0].remaining_seconds == 2.0, "Paused boss effect readouts remain simulation-clock values.")
	state.seek(LABYRINTH, 408)
	effects = state.boss_effects(LABYRINTH)
	_check(effects.size() == 1 and effects[0].id == "airborne" and effects[0].beneficial and effects[0].stacks == 1, "Airborne ground immunity replaces ground hazards during a jump.")
	_check(is_equal_approx(effects[0].remaining_seconds, 1.2), "Airborne expiry is the actual authored landing countdown.")
	state.seek(LABYRINTH, 480)
	_check(state.boss_effects(LABYRINTH).is_empty(), "Landing away from old hazards clears the derived conditions immediately.")
	state.restart(LABYRINTH)
	_check(state.boss_effects(LABYRINTH).is_empty(), "Cycle restart clears the source hazards and therefore their readouts.")
	var training_id: String = ArenicCombatState.boss_enemy_id("guild_house")
	combat.register_enemy("guild_house", training_id, Rect2i(35, 15, 1, 1))
	state.acid_field("guild_house").spawn(Rect2i(35, 15, 1, 1), rules)
	state.seek("guild_house", 7190)
	effects = state.boss_effects("guild_house")
	_check(effects.size() == 1 and effects[0].id == "acid" and is_equal_approx(effects[0].remaining_seconds, 10.0 / 60.0), "Unscored training targets use the ledger, with acid expiry capped by the actual cycle reset.")


func _check_cleanse_clock() -> void:
	var world := load(WORLD_PATH) as ArenicWorldDefinition
	var combat := ArenicCombatState.new()
	combat.configure(world)
	var state := ArenicEncounterState.new()
	state.configure(world, load(CATALOG_PATH) as ArenicEncounterCatalog, combat)
	var bard := ArenicHeroState.new()
	bard.definition = load("res://data/classes/bard.tres")
	bard.arena_id = LABYRINTH
	bard.cell = CENTRE_ORIGIN - Vector2i.ONE
	state.seek(LABYRINTH, 407)
	_check(combat.try_cast(bard).is_empty(), "Cleanse attaches on the final grounded tick before the boss jumps.")
	var effects: Array[Dictionary] = state.boss_effects(LABYRINTH)
	_check(effects.size() == 1 and effects[0].name == "Cleanse" and effects[0].remaining_seconds == 5.0, "The boss bar exposes the fresh five-second attached debuff.")
	state.tick(combat)
	effects = state.boss_effects(LABYRINTH)
	_check(effects.size() == 2 and effects[0].name == "Cleanse" and effects[1].id == "airborne", "A jumping boss displays both attached Cleanse and its Airborne condition.")
	state.set_paused(LABYRINTH, true)
	state.tick(combat, 120)
	_check(combat._enemy_dots[0].remaining_ticks == 299 and combat.damage_for_arena(LABYRINTH) == 1, "Pausing the owning arena freezes DOT lifetime and damage together.")
	state.set_paused(LABYRINTH, false)
	state.tick(combat, 59)
	_check(combat.damage_for_arena(LABYRINTH) == 2 and state.boss_placement(LABYRINTH).airborne, "The first attached tick damages the airborne boss, independent of ground contact.")
	state.tick(combat, 240)
	_check(combat.damage_for_arena(LABYRINTH) == 6 and combat._enemy_dots.is_empty(), "Five real encounter seconds add exactly five delayed damage through jump and landing, then remove the stack.")
	_check(state.boss_effects(LABYRINTH).is_empty(), "Expired Cleanse disappears from the boss progress bar.")
	state.seek(LABYRINTH, 240)
	combat.reset_caster(bard)
	_check(combat.try_cast(bard).is_empty(), "A later ground cast starts a new independent effect.")
	state.configure(world, load(CATALOG_PATH) as ArenicEncounterCatalog, combat)
	_check(combat._enemy_dots.size() == 1, "Replacing the stage or configuring a retained encounter preserves active DOTs.")
	state.restart(LABYRINTH)
	_check(combat._enemy_dots.is_empty() and state.boss_effects(LABYRINTH).is_empty(), "Explicit arena restart clears DOT state and its derived readout.")
	var training := ArenicHeroState.new()
	training.identity_id = 1
	training.definition = bard.definition
	training.arena_id = "guild_house"
	training.cell = Vector2i(10, 10)
	combat.register_enemy("guild_house", ArenicCombatState.boss_enemy_id("guild_house"), Rect2i(10, 10, 1, 1))
	_check(combat.try_cast(training).is_empty(), "Unscored arenas attach the same Cleanse effect.")
	state.set_paused(LABYRINTH, true)
	state.tick(combat, 60)
	_check(combat.damage_for_arena("guild_house") == 2 and combat._enemy_dots[0].remaining_ticks == 240, "Another arena's pause does not stop this arena's damage or timer.")
	state.seek("guild_house", 7199)
	_check(is_equal_approx(float(state.boss_effects("guild_house")[0].remaining_seconds), 1.0 / 60.0), "The bar caps its countdown at the actual next cycle reset.")
	state.tick(combat)
	_check(combat._enemy_dots.is_empty() and state.boss_effects("guild_house").is_empty(), "Natural cycle wrap clears lingering stacks as well as explicit restart.")


## The catalogue must address arenas that actually exist, with footprints that
## fit the gameplay size those arenas authored.
func _check_world(catalog: ArenicEncounterCatalog) -> void:
	var world := load(WORLD_PATH) as ArenicWorldDefinition
	if not _check(world != null and world.validation_errors().is_empty(), "The authored world loads for cross-checking."):
		return
	for score: ArenicEncounterScore in catalog.scores:
		var index: int = world.index_for_id(score.arena_id)
		if not _check(index >= 0, "Score '%s' addresses a real arena." % score.arena_id):
			continue
		var arena: ArenicArenaDefinition = world.arenas[index]
		for beat: ArenicEncounterBeat in score.beats:
			var footprint: Rect2i = beat.footprint(arena.boss_combat_size)
			if not _check(ArenicGridMath.tile_valid(footprint.position) and ArenicGridMath.tile_valid(footprint.end - Vector2i.ONE),
					"Every beat of '%s' fits that arena's authored boss size." % score.arena_id):
				return
		var opening: ArenicEncounterBeat = score.beats[score.index_at(0)]
		if score is ArenicMaskScore:
			continue # V2 derives its opening; legacy static placement is deliberately retained.
		_check(opening.boss_origin_cell == arena.boss_origin_cell, "Arena '%s' rests where its score opens, so nothing jumps on the first frame." % score.arena_id)


static func _beat(at: int, cell: Vector2i) -> ArenicEncounterBeat:
	var beat := ArenicEncounterBeat.new()
	beat.at_tick = at
	beat.boss_origin_cell = cell
	return beat


func _check(passed: bool, message: String) -> bool:
	_checks += 1
	if not passed:
		_failed = true
		print("Score assertion failed: ", message)
	return passed


func _finish() -> void:
	if _failed:
		quit(1)
		return
	print("Score checks passed: %d assertions; authored staff, ordering, folding and derived motion." % _checks)
	quit(0)
