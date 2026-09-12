class_name ArenicEncounterState
extends RefCounted
## Performs authored scores: the conductor for every arena's battle sequence.
##
## Pure logic. It owns no node, art, tween or audio, and never reads wall time
## at all: the shell advances it one whole tick per physics step. Rendered boss
## motion is DERIVED from cycle position, never stored, so a seek, a stage swap,
## or a dropped frame cannot desynchronize the sequence from the ledger.
##
## Every arena runs its own two-minute cycle, including unfocused ones, so a
## battle sequence is never something that only happens where the camera looks.

## Defeat is the ledger's event, not the score's: observers connect to
## `ArenicCombatState.ally_defeated` so there is exactly one authority for it.
signal beat_resolved(arena_id: String, action_id: String, center: Vector2, radius_tiles: float)
## A tile was broken and paid out. The run banks the yield; the view marks it.
signal tile_dug(arena_id: String, cell: Vector2i, value: int)

const DEFAULT_DIFFICULTY: String = "normal"
## Ghosts one arena can hold. The roster strip has shown forty slots since long
## before ghosts existed; this is the rule those slots were always describing.
const MAX_GHOSTS_PER_ARENA: int = 40

var difficulty: String = DEFAULT_DIFFICULTY
var beats_resolved: int = 0
## Maps a performer key to the hero it drives. The conductor stays node-free;
## the shell owns the guild and supplies the lookup.
var performer_lookup: Callable = Callable()
## The ledger the conductor performs against, kept from configure so a restart
## can return its ghosts to a clean cast state without threading it through.
var _combat: ArenicCombatState
## Diggable ground, one field per arena, rolled fresh each cycle.
var _dig_fields: Dictionary[String, ArenicDigField] = {}
## Pools of acid, one field per arena. Cycle state, like broken ground.
var _acid_fields: Dictionary[String, ArenicAcidField] = {}
## How much a dig is worth beyond its roll. Upgrades raise this.
var dig_bonus: int = 0

var _scores: Dictionary[String, ArenicEncounterScore] = {}
## Integer cycle positions. The music director keeps its own float clock for
## playback; a recorded ghost has to match this pattern tick for tick, so the
## simulation counts whole ticks and never seconds.
var _clocks: Dictionary[String, ArenicCycleClock] = {}
## One merged stream per arena. The authored boss staff is folded in at
## configure; recorded hero staves join it later through the same door.
var _timelines: Dictionary[String, ArenicArenaTimeline] = {}
var _sizes: Dictionary[String, Vector2i] = {}


## Places every scored boss on the beat its cycle currently stands on, without
## resolving that beat: configuring an encounter may never strike anything.
##
## Cycle positions survive a stage swap, exactly as the music director preserves
## its own clocks. Restarting them here would let a replaced stage drift a battle
## sequence permanently out of step with the arena it is playing against.
func configure(world: ArenicWorldDefinition, catalog: ArenicEncounterCatalog, combat: ArenicCombatState, tier: String = DEFAULT_DIFFICULTY) -> void:
	var retained: Dictionary = _clocks.duplicate()
	var retained_fields: Dictionary = _dig_fields.duplicate()
	var retained_acid: Dictionary = _acid_fields.duplicate()
	_dig_fields.clear()
	_acid_fields.clear()
	var retained_timelines: Dictionary = _timelines.duplicate()
	_scores.clear()
	_clocks.clear()
	_sizes.clear()
	_timelines.clear()
	difficulty = tier
	_combat = combat
	if world == null or catalog == null:
		return
	for arena: ArenicArenaDefinition in world.arenas:
		if arena == null:
			continue
		# EVERY arena runs a cycle, scored or not: a hero records against its
		# arena's clock wherever it stands, and pausing one arena for a modal
		# only means something if that arena has a clock to pause.
		var score: ArenicEncounterScore = catalog.score_for(arena.arena_id, tier)
		if score != null and not score.validation_errors().is_empty():
			push_error("Arena '%s' has an invalid %s score; it will run without one." % [arena.arena_id, tier])
			score = null
		var length: int = score.cycle_ticks if score != null else ArenicCycleClock.CYCLE_TICKS
		_sizes[arena.arena_id] = arena.boss_combat_size
		var clock: ArenicCycleClock = retained.get(arena.arena_id)
		if clock == null:
			clock = ArenicCycleClock.new()
			clock.configure(length)
		elif clock.cycle_ticks != length:
			# A re-authored cycle length keeps its phase rather than snapping to zero.
			clock.configure(length, clock.tick)
		clock.paused = false
		_clocks[arena.arena_id] = clock
		# Retaining the timeline keeps every folded performer across a stage
		# swap; only the authored boss staff is re-derived from the score.
		var timeline: ArenicArenaTimeline = retained_timelines.get(arena.arena_id)
		if timeline == null:
			timeline = ArenicArenaTimeline.new()
		_timelines[arena.arena_id] = timeline
		var field: ArenicDigField = retained_fields.get(arena.arena_id)
		if field == null:
			field = ArenicDigField.new()
			field.configure(arena.arena_id)
		_dig_fields[arena.arena_id] = field
		var acid: ArenicAcidField = retained_acid.get(arena.arena_id)
		if acid == null:
			acid = ArenicAcidField.new()
			acid.configure(arena.arena_id)
		_acid_fields[arena.arena_id] = acid
		if score == null:
			continue
		_scores[arena.arena_id] = score
		timeline.fold(ArenicCombatState.boss_enemy_id(arena.arena_id), score.to_recording(arena.boss_combat_size))
		timeline.seek_to(clock.tick)
		var standing: int = score.index_at(clock.tick)
		if standing >= 0 and combat != null:
			var beat: ArenicEncounterBeat = score.beats[standing]
			combat.register_enemy(arena.arena_id, ArenicCombatState.boss_enemy_id(arena.arena_id), beat.footprint(arena.boss_combat_size), beat.facing)


## Advances every unpaused cycle and resolves the merged stream as it goes.
##
## Each tick resolves the events stamped for it, then the clock advances; on the
## wrap the cursor returns to the top so tick zero replays like any other tick.
## One physics step is one tick; `steps` exists so a test or a future scrub can
## cover a longer span deliberately, and it advances tick by tick rather than
## jumping, because a lap that really elapsed really did resolve its events.
## Call it after `ArenicCombatState.tick`, which syncs ally positions first.
func tick(combat: ArenicCombatState, steps: int = 1) -> void:
	if combat == null or steps <= 0:
		return
	for arena_id: String in arena_ids():
		var clock: ArenicCycleClock = _clocks[arena_id]
		if clock.paused:
			continue
		var timeline: ArenicArenaTimeline = _timelines[arena_id]
		for step: int in steps:
			for event: ArenicTimelineEvent in timeline.due(clock.tick):
				_resolve(arena_id, event, combat)
			_advance_ground(arena_id, combat)
			if clock.step():
				# A cycle restart is a rewind of the whole arena: the stream
				# returns to the top and every ghost to the tile its staff
				# replays from, or intent would resume mid-path.
				timeline.restart()
				snap_ghosts(arena_id)
				_roll_ground(arena_id)


## Restarts one arena: the clock returns to tick zero and the stream rewinds.
## Commit, replay and record-new all take this path; breaking a performer out
## deliberately does not, so the other performers keep playing uninterrupted.
func restart(arena_id: String) -> void:
	var clock: ArenicCycleClock = _clocks.get(arena_id)
	var timeline: ArenicArenaTimeline = _timelines.get(arena_id)
	if clock == null or timeline == null:
		return
	clock.seek(0)
	clock.paused = false
	timeline.restart()
	snap_ghosts(arena_id)
	# A restart is a new cycle: fresh ground, and every previous dig cleared.
	_roll_ground(arena_id)


## Broken ground damages whoever is standing on it, through the ledger.
func _advance_ground(arena_id: String, combat: ArenicCombatState) -> void:
	var field: ArenicDigField = _dig_fields.get(arena_id)
	if field != null:
		for hazard: Array in field.advance_hazards(combat):
			combat.apply_hazard_damage(arena_id, str(hazard[0]), int(hazard[1]))
	var acid: ArenicAcidField = _acid_fields.get(arena_id)
	if acid != null:
		for burn: Array in acid.advance():
			var area: Rect2i = burn[0]
			var amount: int = int(burn[1])
			for enemy_id: String in combat.enemies_in(arena_id, area):
				combat.apply_hazard_damage(arena_id, enemy_id, amount)
			# Acid has no allegiance: a hero standing in a pool burns too.
			combat.damage_allies_in(arena_id, area, amount)


func _roll_ground(arena_id: String) -> void:
	var field: ArenicDigField = _dig_fields.get(arena_id)
	if field != null:
		field.regenerate(field.cycle + 1, dig_bonus)
	# A pool laid last cycle has no business burning in this one: everything the
	# cycle put on the ground goes with it, or replay would not start level.
	var acid: ArenicAcidField = _acid_fields.get(arena_id)
	if acid != null:
		acid.clear()


## Something landed on an arena's floor. Live casts and ghost playback both
## arrive here, because both go through the ledger.
##
## The SHELL relays this rather than the conductor subscribing itself: the ledger
## outlives every shell, and a signal connected to a RefCounted holds it alive
## forever — one immortal conductor, and everything it references, per stage swap.
func apply_landing(ability_id: String, arena_id: String, area: Rect2i, rules: ArenicClassAbility) -> void:
	match ability_id:
		"dig":
			var field: ArenicDigField = _dig_fields.get(arena_id)
			if field == null:
				return
			var value: int = field.dig(area.position)
			# Ground already broken yields nothing; the cast still happened.
			if value > 0:
				tile_dug.emit(arena_id, area.position, value)
		"acid_flask":
			var acid: ArenicAcidField = _acid_fields.get(arena_id)
			if acid != null:
				acid.spawn(area, rules)
		_:
			pass


## One arena's diggable ground, for the floor markers and for tests.
func dig_field(arena_id: String) -> ArenicDigField:
	return _dig_fields.get(arena_id)


## One arena's pools of acid.
func acid_field(arena_id: String) -> ArenicAcidField:
	return _acid_fields.get(arena_id)


## The merged stream for an arena, for folding performers into it.
func timeline(arena_id: String) -> ArenicArenaTimeline:
	return _timelines.get(arena_id)


## Folds a hero's staff into its arena and restarts that arena. Commit and
## replay-previous both take this path, so the two can never drift.
func fold_ghost(hero: ArenicHeroState, recording: ArenicRecording) -> void:
	var timeline: ArenicArenaTimeline = _timelines.get(hero.arena_id)
	if timeline == null or recording == null:
		return
	timeline.fold(hero.ally_id(), recording)
	hero.cell = recording.start_cell
	restart(hero.arena_id)


## Takes a hero out of its arena's stream WITHOUT restarting: the arena keeps
## playing from exactly where it was, and the hero is free at its current tile.
## This is break-out, and it is the only path that does not rewind.
func unfold_ghost(hero: ArenicHeroState) -> void:
	var timeline: ArenicArenaTimeline = _timelines.get(hero.arena_id)
	var clock: ArenicCycleClock = _clocks.get(hero.arena_id)
	if timeline == null or clock == null:
		return
	timeline.unfold(hero.ally_id(), clock.tick)


## Guild members folded into an arena's stream. The boss is a performer too, so
## it is counted out: the cap is about recorded heroes.
func ghost_count(arena_id: String) -> int:
	var timeline: ArenicArenaTimeline = _timelines.get(arena_id)
	if timeline == null or not performer_lookup.is_valid():
		return 0
	var total: int = 0
	for performer: String in timeline.performers():
		if performer_lookup.call(performer) != null:
			total += 1
	return total


## Whether this hero may be folded into the arena it stands in. A hero already
## folded there may always refold: replacing a staff does not grow the arena.
func can_fold_ghost(hero: ArenicHeroState) -> bool:
	if hero == null:
		return false
	return is_ghost(hero) or ghost_count(hero.arena_id) < MAX_GHOSTS_PER_ARENA


## True while this hero is folded into its arena's stream: playback drives it and
## direct input is refused. Derived, never stored, so the two cannot disagree.
func is_ghost(hero: ArenicHeroState) -> bool:
	var timeline: ArenicArenaTimeline = _timelines.get(hero.arena_id) if hero != null else null
	return timeline != null and timeline.has(hero.ally_id())


## Returns every ghost in an arena to the tile its staff replays from, and to a
## clean cast state. Position alone is not enough: a ghost carrying a cooldown
## or a projectile in flight across the seam would play its second cycle
## differently from its first, and replay has to be identical every time.
func snap_ghosts(arena_id: String, except_identity: int = -1) -> void:
	var timeline: ArenicArenaTimeline = _timelines.get(arena_id)
	if timeline == null or not performer_lookup.is_valid():
		return
	for performer: String in timeline.performers():
		var hero: ArenicHeroState = performer_lookup.call(performer)
		if hero == null or hero.identity_id == except_identity:
			continue
		var staff: ArenicRecording = timeline.staff(performer)
		if staff != null:
			hero.cell = staff.start_cell
		if _combat != null:
			_combat.reset_caster(hero)
			# A ghost struck last cycle rises with the cycle. Its death was
			# derived from its own intent against a fixed pattern, so it will
			# happen again at the same tick unless the staff is re-recorded.
			_combat.revive_ally(hero.arena_id, hero.ally_id())


## Every arena the conductor runs a cycle for, in a stable order independent of
## authoring order, so two runs resolve simultaneous events identically.
func arena_ids() -> PackedStringArray:
	var ids: Array = _clocks.keys()
	ids.sort()
	return PackedStringArray(ids)


## The arenas that actually have an authored battle sequence today.
func scored_arena_ids() -> PackedStringArray:
	var ids: Array = _scores.keys()
	ids.sort()
	return PackedStringArray(ids)


func cycle_position(arena_id: String) -> int:
	var clock: ArenicCycleClock = _clocks.get(arena_id)
	return clock.tick if clock != null else 0


## Read from the clock, not the score: every arena runs a cycle, and most of
## them have no authored score to read a length from.
func cycle_ticks(arena_id: String) -> int:
	var clock: ArenicCycleClock = _clocks.get(arena_id)
	return clock.cycle_ticks if clock != null else 0


## `m:ss` of an arena's cycle, for the HUD read-out.
func cycle_label(arena_id: String) -> String:
	var clock: ArenicCycleClock = _clocks.get(arena_id)
	return clock.format() if clock != null else "0:00"


## Pauses one arena. Only the arena that owns a modal or a countdown pauses;
## there is no global pause, and the other eight keep performing.
func set_paused(arena_id: String, paused: bool) -> void:
	var clock: ArenicCycleClock = _clocks.get(arena_id)
	if clock != null:
		clock.paused = paused


func is_paused(arena_id: String) -> bool:
	var clock: ArenicCycleClock = _clocks.get(arena_id)
	return clock != null and clock.paused


## Moves an arena to an exact cycle tick without resolving anything between,
## resyncing the cursor so the events AT that tick are still pending.
## Tests and future authoring tools scrub with this; gameplay never calls it.
func seek(arena_id: String, at_tick: int) -> void:
	var clock: ArenicCycleClock = _clocks.get(arena_id)
	if clock == null:
		return
	clock.seek(at_tick)
	var timeline: ArenicArenaTimeline = _timelines.get(arena_id)
	if timeline != null:
		timeline.seek_to(clock.tick)


## Where the boss reads as being right now, derived purely from cycle position.
## `center` and `target` are tile coordinates; `lift` is tiles toward the camera.
## Returns an empty dictionary for an arena without a score.
func boss_placement(arena_id: String) -> Dictionary:
	var score: ArenicEncounterScore = _scores.get(arena_id)
	var clock: ArenicCycleClock = _clocks.get(arena_id)
	if score == null or clock == null or score.beats.is_empty():
		return {}
	var size: Vector2i = _sizes[arena_id]
	var position: int = clock.tick
	var landed_index: int = score.index_at(position)
	var next_index: int = (landed_index + 1) % score.beats.size()
	var landed: ArenicEncounterBeat = score.beats[landed_index]
	var upcoming: ArenicEncounterBeat = score.beats[next_index]
	var from_center: Vector2 = landed.center_cell(size)
	var to_center: Vector2 = upcoming.center_cell(size)
	var until: int = posmod(upcoming.at_tick - position, score.cycle_ticks)
	var grounded: Dictionary = {
		"center": from_center, "lift": 0.0, "airborne": false, "progress": 0.0,
		"target": to_center, "radius": upcoming.blast_radius_tiles,
		"until": until, "travel": upcoming.travel_ticks,
	}
	# One beat, a teleport, or any position outside the arc keeps the boss down.
	if next_index == landed_index or upcoming.travel_ticks <= 0 or until <= 0 or until > upcoming.travel_ticks:
		return grounded
	var progress: float = clampf(1.0 - float(until) / float(upcoming.travel_ticks), 0.0, 1.0)
	return {
		"center": from_center.lerp(to_center, progress),
		# A symmetric parabola: the apex is mid-flight, both ends touch the floor.
		"lift": upcoming.lift_tiles * 4.0 * progress * (1.0 - progress),
		"airborne": true, "progress": progress,
		"target": to_center, "radius": upcoming.blast_radius_tiles,
		"until": until, "travel": upcoming.travel_ticks,
	}


## Applies one merged-stream event. Every action the vocabulary grows gains an
## arm here; nothing else in playback changes.
func _resolve(arena_id: String, event: ArenicTimelineEvent, combat: ArenicCombatState) -> void:
	match event.action_id:
		ArenicTimelineEvent.BOSS_JUMP:
			_resolve_boss_jump(arena_id, event.beat, combat)
		ArenicTimelineEvent.MOVE:
			_resolve_move(event, combat)
		ArenicTimelineEvent.ABILITY:
			_resolve_ability(event, combat)
		_:
			pass


## A recorded cast, resolved through exactly the same door a live cast uses, so
## a ghost's ability can never drift from the player's. Each caster owns its own
## cast and cooldown, so a refusal here is the ghost's own state — never a
## collision with the player or with another ghost.
func _resolve_ability(event: ArenicTimelineEvent, combat: ArenicCombatState) -> void:
	if not performer_lookup.is_valid() or event.slot != 1:
		return # Slots 2-4 are recorded but unassigned on both sides.
	var hero: ArenicHeroState = performer_lookup.call(event.performer)
	if hero != null and not _is_down(hero, combat):
		combat.try_cast(hero)


## A fallen ghost is inert for the rest of the cycle: it stops where it was
## struck and neither moves nor casts until the arena restarts. Death is never a
## recorded event, so this is the only thing that stops a staff mid-cycle.
func _is_down(hero: ArenicHeroState, combat: ArenicCombatState) -> bool:
	return combat.ally_defeated_at(hero.arena_id, hero.ally_id())


## A recorded step. It obeys the same rules the live step did — clamped at the
## arena edge, and blocked by a target's footprint — so replay cannot reach
## ground the take could not.
func _resolve_move(event: ArenicTimelineEvent, combat: ArenicCombatState) -> void:
	if not performer_lookup.is_valid():
		return
	var hero: ArenicHeroState = performer_lookup.call(event.performer)
	if hero == null or _is_down(hero, combat):
		return
	var previous: Vector2i = hero.cell
	if hero.step_within_arena(event.delta) and combat.is_occupied(hero.arena_id, hero.cell):
		hero.cell = previous


func _resolve_boss_jump(arena_id: String, beat: ArenicEncounterBeat, combat: ArenicCombatState) -> void:
	if beat == null:
		return
	var size: Vector2i = _sizes[arena_id]
	var center: Vector2 = beat.center_cell(size)
	# The footprint moves before the blast resolves, so the landing and the
	# ground it now occupies are one event for anything reading the ledger.
	combat.register_enemy(arena_id, ArenicCombatState.boss_enemy_id(arena_id), beat.footprint(size), beat.facing)
	beats_resolved += 1
	if beat.blast_radius_tiles > 0.0:
		combat.apply_blast(arena_id, center, beat.blast_radius_tiles)
	beat_resolved.emit(arena_id, beat.action_id, center, beat.blast_radius_tiles)
