@tool
class_name ArenicEncounterScore
extends Resource
## One arena's authored staff for one difficulty: a looping two-minute cycle of
## beats. The score is data only. It reads like sheet music and holds no runtime
## cursor, node, timer, or audio dependency; `ArenicEncounterState` performs it.
##
## Beats are strictly ordered and every position is inside `[0, cycle_ticks)`,
## so a cycle wraps without a seam. The beat at or before position zero is where
## the boss stands when the cycle restarts.

const DIFFICULTIES: PackedStringArray = ["normal", "heroic", "mythic"]
## The authored boss footprint every score is written against. The runtime uses
## each arena's own `boss_combat_size`; this keeps data validation self-contained
## rather than making a score resource depend on a view or world resource.
const FOOTPRINT_TILES: Vector2i = Vector2i(6, 6)

@export var arena_id: String = ""
@export_enum("normal", "heroic", "mythic") var difficulty: String = "normal"
## Every arena shares the two-minute cycle, counted in whole simulation ticks.
@export_range(1, 216000, 1) var cycle_ticks: int = ArenicCycleClock.CYCLE_TICKS
@export var beats: Array[ArenicEncounterBeat] = []


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if arena_id.is_empty() or arena_id != arena_id.strip_edges():
		errors.append("Score arena ID must be nonempty and have no surrounding whitespace.")
	if difficulty not in DIFFICULTIES:
		errors.append("Unknown difficulty: %s." % difficulty)
	if cycle_ticks <= 0:
		errors.append("Cycle duration must be a positive tick count.")
	if beats.is_empty():
		errors.append("A score needs at least one beat.")
	var previous: int = -1
	for index: int in beats.size():
		var beat: ArenicEncounterBeat = beats[index]
		if beat == null:
			errors.append("Beat %d is null." % index)
			continue
		for error: String in beat.validation_errors():
			errors.append("Beat %d: %s" % [index, error])
		if beat.at_tick <= previous:
			errors.append("Beat %d repeats or precedes an earlier cycle position." % index)
		if cycle_ticks > 0 and beat.at_tick >= cycle_ticks:
			errors.append("Beat %d falls outside the cycle." % index)
		previous = beat.at_tick
	_validate_geometry(errors)
	_validate_arcs(errors)
	return errors


## Footprints are gameplay occupancy, so every beat must land fully in the arena.
func _validate_geometry(errors: PackedStringArray) -> void:
	for index: int in beats.size():
		var beat: ArenicEncounterBeat = beats[index]
		if beat == null:
			continue
		if not ArenicGridMath.tile_valid(beat.boss_origin_cell):
			errors.append("Beat %d starts its footprint outside the arena." % index)
		elif not ArenicGridMath.tile_valid(beat.boss_origin_cell + FOOTPRINT_TILES - Vector2i.ONE):
			errors.append("Beat %d extends its footprint past the arena edge." % index)


## An arc may not begin before the previous beat resolved, or two landings would
## overlap in the air and the rendered boss would jump from nowhere.
func _validate_arcs(errors: PackedStringArray) -> void:
	if beats.size() < 2 or cycle_ticks <= 0:
		return
	for index: int in beats.size():
		var beat: ArenicEncounterBeat = beats[index]
		var earlier: ArenicEncounterBeat = beats[(index - 1 + beats.size()) % beats.size()]
		if beat == null or earlier == null:
			continue
		var gap: int = posmod(beat.at_tick - earlier.at_tick, cycle_ticks)
		# A single-beat wrap measures the whole cycle; equal positions cannot happen
		# here because ordering is already validated above.
		if beat.travel_ticks > gap:
			errors.append("Beat %d leaves before beat %d resolves." % [index, (index - 1 + beats.size()) % beats.size()])


## Index of the most recent beat at or before `position`, wrapping the cycle.
## Returns -1 only when the score has no beats.
func index_at(position: int) -> int:
	if beats.is_empty() or cycle_ticks <= 0:
		return -1
	var cursor: int = posmod(position, cycle_ticks)
	var result: int = beats.size() - 1 # Before the first beat, the cycle wrapped.
	for index: int in beats.size():
		var beat: ArenicEncounterBeat = beats[index]
		if beat != null and beat.at_tick <= cursor:
			result = index
	return result


## The score as a performer's staff, so an authored boss folds into an arena's
## master timeline exactly like a recorded hero does. One playback path, one
## ordering rule, and nothing special about being the boss.
func to_recording(boss_size: Vector2i) -> ArenicRecording:
	var staff: Array[ArenicTimelineEvent] = []
	for beat: ArenicEncounterBeat in beats:
		if beat != null:
			staff.append(ArenicTimelineEvent.boss_jump(beat))
	var opening: int = index_at(0)
	var start: Vector2i = beats[opening].boss_origin_cell if opening >= 0 else Vector2i.ZERO
	var recording := ArenicRecording.create(start, staff)
	# The start cell is the footprint origin, not a tile the boss walks from;
	# boss stations are absolute, so nothing derives a path from it.
	recording.start_cell = start
	return recording


func _get_validation_conditions() -> Array:
	return ArenicDoctorConditions.from_errors(validation_errors())
