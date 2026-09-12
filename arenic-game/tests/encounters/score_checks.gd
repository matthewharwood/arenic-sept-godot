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
