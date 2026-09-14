@tool
class_name ArenicMaskScore
extends ArenicEncounterScore
## A versioned extension of the existing score. Beats supply the grounded pose
## track; events supply the staff, including independently ordered overlaps.
@export var revision: String = "cardinal-normal-1"
@export var title: String = "The Twofold Witness"
@export var events: Array[ArenicScoreEvent] = []
@export var sun_font: Vector2i = Vector2i(22, 4)
@export var moon_font: Vector2i = Vector2i(43, 4)
@export var exposure_delay_ticks: int = 240
@export var exposure_damage: int = 1
@export var bonus_damage: int = 1

func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = super.validation_errors()
	if cycle_ticks != 7200 or revision.is_empty() or events.is_empty() or events.size() > 64 or beats.size() > 16:
		errors.append("Invalid revision or bounded v2 score.")
	if exposure_delay_ticks < 1 or exposure_delay_ticks > 600 or exposure_damage < 1 or exposure_damage > 4 or bonus_damage < 1 or bonus_damage > 4:
		errors.append("Invalid Exposure or bonus tuning.")
	if sun_font == moon_font or not ArenicGridMath.tile_valid(sun_font) or not ArenicGridMath.tile_valid(moon_font):
		errors.append("Fonts must occupy distinct valid cells.")
	var prior: ArenicScoreEvent
	var ids: Dictionary = {}
	var windows: int = 0
	for event: ArenicScoreEvent in events:
		if event == null:
			errors.append("Null score event.")
			continue
		for error: String in event.validation_errors():
			errors.append(event.event_id + ": " + error)
		if ids.has(event.event_id) or (prior != null and (event.at_tick < prior.at_tick or (event.at_tick == prior.at_tick and event.event_id <= prior.event_id))):
			errors.append("Events require unique IDs ordered by (tick, event ID).")
		ids[event.event_id] = true
		prior = event
		for mask: Rect2i in event.masks:
			if mask.has_point(sun_font) or mask.has_point(moon_font):
				errors.append("Fonts must remain outside attack masks.")
		if event.kind == "window":
			windows += 1
			var index: int = index_at(event.at_tick)
			if index < 0 or beats[index].at_tick != event.at_tick or beats[index].boss_origin_cell != event.boss_origin or beats[index].facing != event.boss_facing:
				errors.append("Transfer must match the pose track exactly.")
	if windows > 4:
		errors.append("At most four personal windows per cycle.")
	for beat: ArenicEncounterBeat in beats:
		if beat != null and (beat.travel_ticks != 0 or beat.blast_radius_tiles != 0 or beat.lift_tiles != 0):
			errors.append("V2 poses stay grounded and do not create radial blasts.")
	if not beats.is_empty() and (beats[0].at_tick != 0 or beats[-1].boss_origin_cell != beats[0].boss_origin_cell or beats[-1].facing != beats[0].facing):
		errors.append("Pose track must begin at zero and close its seam.")
	# At every application boundary, count worst-case outstanding Exposure.
	for event: ArenicScoreEvent in events:
		if event == null:
			continue
		var outstanding: int = 0
		for other: ArenicScoreEvent in events:
			if other != null and "expose" in other.tags and other.at_tick <= event.at_tick and other.at_tick + exposure_delay_ticks >= event.at_tick:
				outstanding += 1
		if outstanding > 4:
			errors.append("Authored Exposure exceeds the four-stack bound.")
	return errors

func to_recording(_boss_size: Vector2i) -> ArenicRecording:
	var recording := ArenicRecording.new()
	recording.start_cell = beats[0].boss_origin_cell
	for authored: ArenicScoreEvent in events:
		var event := ArenicTimelineEvent.new()
		event.tick = authored.at_tick
		event.action_id = ArenicTimelineEvent.BOSS_MASK
		event.score_event = authored
		recording.events.append(event)
	return recording

func content_hash() -> String:
	var notes: Array = []
	for event: ArenicScoreEvent in events:
		notes.append(event.canonical())
	var poses: Array = []
	for beat: ArenicEncounterBeat in beats:
		poses.append([beat.at_tick, beat.boss_origin_cell.x, beat.boss_origin_cell.y, beat.facing])
	return JSON.stringify([revision, arena_id, difficulty, cycle_ticks, notes, poses, sun_font.x, sun_font.y, moon_font.x, moon_font.y, exposure_delay_ticks, exposure_damage, bonus_damage]).sha256_text()

func event_for(id: String) -> ArenicScoreEvent:
	for event: ArenicScoreEvent in events:
		if event.event_id == id:
			return event
	return null

func visible_events(tick: int) -> Array[ArenicScoreEvent]:
	var result: Array[ArenicScoreEvent] = []
	for event: ArenicScoreEvent in events:
		if event.cue_tick <= tick and tick < event.end_tick:
			result.append(event)
	return result
