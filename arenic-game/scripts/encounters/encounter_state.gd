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
signal score_event_resolved(arena_id: String, event_id: String)

signal beat_resolved(arena_id: String, action_id: String, center: Vector2, radius_tiles: float)
## A tile was broken and paid out. The run banks the yield; the view marks it.
signal tile_dug(arena_id: String, cell: Vector2i, value: int)
## The same clock boundary drives arena-local work, including off-camera work.
signal arena_advanced(arena_id: String)
## Only natural forward wraps award completion rewards. Manual restarts never
## emit this, even if they happen to be requested at the end of the score.
signal arena_cycle_completed(arena_id: String)
## Observe the completed forward poses before any authoritative reset mutation.
signal arena_restarting(arena_id: String, end_tick: int, rewind: bool)
signal arena_restarted(arena_id: String)

const DEFAULT_DIFFICULTY: String = "normal"
## Ghosts one arena can hold. The roster strip has shown forty slots since long
## before ghosts existed; this is the rule those slots were always describing.
const MAX_GHOSTS_PER_ARENA: int = 40

var difficulty: String = DEFAULT_DIFFICULTY
var beats_resolved: int = 0
## Maps a performer key to the hero it drives. The conductor stays node-free;
## the shell owns the guild and supplies the lookup.
var performer_lookup: Callable = Callable()
## Every physical hero, including free heroes outside the focused arena.
var roster_lookup: Callable = Callable()
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
	if combat != null:
		combat.enemy_pose_lookup = _weak_enemy_pose_lookup(weakref(self))
		combat.arena_paused_lookup = _weak_pause_lookup(weakref(self))
		combat.direct_bonus_lookup = _weak_bonus_lookup(weakref(self))
	if world == null or catalog == null:
		return
	for arena: ArenicArenaDefinition in world.arenas:
		if arena == null:
			continue
		# EVERY arena runs a cycle, scored or not: a hero records against its
		# arena's clock wherever it stands, and pausing one arena for a modal
		# only means something if that arena has a clock to pause.
		var score: ArenicEncounterScore = catalog.score_for(arena.arena_id, tier, combat.encounter_effects.ruleset if combat != null else ArenicActorEffects.LEGACY)
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
## Live movement is captured before this call. All recorded movement and contact
## resolve before the optional live-cast/combat callback and score effects.
func tick(combat: ArenicCombatState, steps: int = 1, movement_snapshot: Dictionary = {}, before_effects: Callable = Callable()) -> void:
	if combat == null or steps <= 0:
		return
	for step: int in steps:
		var heroes: Array = _contact_roster(combat)
		var before: Dictionary = movement_snapshot if step == 0 and not movement_snapshot.is_empty() else ArenicHeroContact.capture(heroes, combat)
		var due: Dictionary = {}
		for arena_id: String in arena_ids():
			var clock: ArenicCycleClock = _clocks[arena_id]
			if not is_paused(arena_id):
				due[arena_id] = _timelines[arena_id].due(clock.tick)
		for arena_id: String in due:
			for event: ArenicTimelineEvent in due[arena_id]:
				if event.action_id == ArenicTimelineEvent.MOVE:
					_resolve_move(event, combat)
		var contacts: Array[Dictionary] = resolve_contacts(combat, before)
		var defeated: Dictionary = {}
		for contact: Dictionary in contacts:
			defeated[contact.actor] = true
		for arena_id: String in due:
			var mask_score: ArenicMaskScore = _scores.get(arena_id) as ArenicMaskScore
			if mask_score != null:
				combat.encounter_effects.enter_fonts(mask_score, combat)
		if before_effects.is_valid():
			before_effects.call()
		for arena_id: String in due:
			var clock: ArenicCycleClock = _clocks[arena_id]
			if clock.restart_pending:
				continue
			# V2 support/direct actions precede boss impacts regardless of fold order.
			# Legacy staves retain their released performer ordering.
			for event: ArenicTimelineEvent in due[arena_id]:
				if event.action_id not in [ArenicTimelineEvent.MOVE, ArenicTimelineEvent.BOSS_MASK] and not defeated.has(event.performer):
					_resolve(arena_id, event, combat)
			for event: ArenicTimelineEvent in due[arena_id]:
				if event.action_id == ArenicTimelineEvent.BOSS_MASK:
					_resolve_mask(arena_id, event.score_event, combat)
			combat.encounter_effects.advance(arena_id, clock.tick, combat)
			combat.advance_enemy_dots(arena_id)
			_advance_ground(arena_id, combat)
			arena_advanced.emit(arena_id)
			if not is_paused(arena_id) and clock.tick == clock.cycle_ticks - 1:
				arena_cycle_completed.emit(arena_id)
				# An unscored clearing has nothing to replay until workers are
				# folded in. Its resource/music clock still wraps normally.
				arena_restarting.emit(arena_id, clock.cycle_ticks, _scores.get(arena_id) != null or ghost_count(arena_id) > 0)
			if clock.step():
				# A cycle restart is a rewind of the whole arena: the stream
				# returns to the top and every ghost to the tile its staff
				# replays from, or intent would resume mid-path.
				var reset_before: Dictionary = ArenicHeroContact.capture(_contact_roster(combat), combat)
				_timelines[arena_id].restart()
				snap_ghosts(arena_id)
				_roll_cycle_effects(arena_id, reset_before)


## Also resolves incoming live movement against occupants of paused arenas.
## Returns frozen victims even when a listener immediately respawns one.
func resolve_contacts(combat: ArenicCombatState, before: Dictionary = {}, include_crossings: bool = true) -> Array[Dictionary]:
	var heroes: Array = _contact_roster(combat)
	combat.sync_allies(heroes)
	var contacts: Array[Dictionary] = ArenicHeroContact.resolve(before, heroes, combat, include_crossings)
	combat.defeat_hero_contacts(contacts)
	return contacts


func _contact_roster(combat: ArenicCombatState) -> Array:
	if roster_lookup.is_valid():
		return roster_lookup.call()
	var heroes: Array = []
	if combat != null and performer_lookup.is_valid():
		for arena_id: String in arena_ids():
			for actor_id: String in combat.ally_ids(arena_id):
				var hero: ArenicHeroState = performer_lookup.call(actor_id)
				if hero != null and hero not in heroes:
					heroes.append(hero)
			for actor_id: String in _timelines[arena_id].performers():
				var hero: ArenicHeroState = performer_lookup.call(actor_id)
				if hero != null and hero not in heroes:
					heroes.append(hero)
	return heroes


## Restarts one arena: the clock returns to tick zero and the stream rewinds.
## Commit, replay and record-new all take this path; breaking a performer out
## deliberately does not, so the other performers keep playing uninterrupted.
func restart(arena_id: String, rewind: bool = true) -> void:
	var clock: ArenicCycleClock = _clocks.get(arena_id)
	var timeline: ArenicArenaTimeline = _timelines.get(arena_id)
	if clock == null or timeline == null:
		return
	arena_restarting.emit(arena_id, clock.tick, rewind)
	clock.seek(0)
	clock.paused = false
	clock.restart_pending = false
	timeline.restart()
	var before: Dictionary = ArenicHeroContact.capture(_contact_roster(_combat), _combat)
	snap_ghosts(arena_id)
	# A restart is a new cycle: fresh ground, and every previous dig cleared.
	_roll_cycle_effects(arena_id, before)


## Broken ground damages whoever is standing on it, through the ledger.
func _advance_ground(arena_id: String, combat: ArenicCombatState) -> void:
	var field: ArenicDigField = _dig_fields.get(arena_id)
	if field != null:
		for hazard: Array in field.advance_hazards(combat):
			combat.apply_hazard_damage(arena_id, str(hazard[0]), int(hazard[1]), str(hazard[2]), "dig")
	var acid: ArenicAcidField = _acid_fields.get(arena_id)
	if acid != null:
		for burn: Array in acid.advance():
			var area: Rect2i = burn[0]
			var amount: int = int(burn[1])
			for enemy_id: String in combat.enemies_in(arena_id, area):
				combat.apply_hazard_damage(arena_id, enemy_id, amount, str(burn[2]), "acid_flask")
			# Acid has no allegiance: a hero standing in a pool burns too.
			combat.damage_allies_in(arena_id, area, amount)


func _roll_cycle_effects(arena_id: String, before: Dictionary = {}) -> void:
	if _combat != null:
		_combat.encounter_effects.actors.erase(arena_id)
		if _scores.get(arena_id) is ArenicMaskScore:
			for actor: String in _combat.ally_ids(arena_id):
				_combat.revive_ally(arena_id, actor)
			for hero: ArenicHeroState in _contact_roster(_combat):
				if hero.arena_id == arena_id:
					_combat.reset_caster(hero)
	if _combat != null:
		_combat.clear_enemy_dots(arena_id)
	var field: ArenicDigField = _dig_fields.get(arena_id)
	if field != null:
		field.regenerate(field.cycle + 1, dig_bonus)
	# A pool laid last cycle has no business burning in this one: everything the
	# cycle put on the ground goes with it, or replay would not start level.
	var acid: ArenicAcidField = _acid_fields.get(arena_id)
	if acid != null:
		acid.clear()
	if _combat != null:
		# Rewound ghosts rise before contact. Their old smoke must not exclude
		# them, and a teleport does not collide with cells crossed in between.
		for old: Dictionary in before.values():
			old.alive = true
		resolve_contacts(_combat, before, false)
	arena_restarted.emit(arena_id)


## Something landed on an arena's floor. Live casts and ghost playback both
## arrive here, because both go through the ledger.
##
## The SHELL relays this rather than the conductor subscribing itself: the ledger
## outlives every shell, and a signal connected to a RefCounted holds it alive
## forever — one immortal conductor, and everything it references, per stage swap.
func apply_landing(ability_id: String, arena_id: String, area: Rect2i, rules: ArenicClassAbility, caster_id: String = "") -> void:
	match ability_id:
		"dig":
			var field: ArenicDigField = _dig_fields.get(arena_id)
			if field == null:
				return
			var value: int = field.dig(area.position, caster_id)
			# Ground already broken yields nothing; the cast still happened.
			if value > 0:
				tile_dug.emit(arena_id, area.position, value)
		"acid_flask":
			var acid: ArenicAcidField = _acid_fields.get(arena_id)
			if acid != null:
				acid.spawn(area, rules, caster_id)
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


## Transient seek identity for presentation; ordinary fixed ticks do not change it.
func cycle_seek_revision(arena_id: String) -> int:
	var clock: ArenicCycleClock = _clocks.get(arena_id)
	return clock.seek_revision if clock != null else 0


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
	return clock != null and (clock.paused or clock.restart_pending)


func set_restart_pending(arena_id: String, pending: bool) -> bool:
	var clock: ArenicCycleClock = _clocks.get(arena_id)
	if clock == null or (pending and clock.tick != 0):
		return false
	clock.restart_pending = pending
	return true


func is_restart_pending(arena_id: String) -> bool:
	var clock: ArenicCycleClock = _clocks.get(arena_id)
	return clock != null and clock.restart_pending


static func _weak_pause_lookup(reference: WeakRef) -> Callable:
	return func(arena_id: String) -> bool:
		var encounter: ArenicEncounterState = reference.get_ref()
		return encounter != null and encounter.is_paused(arena_id)


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
## `footprint` is the latest scored landing; while airborne it cannot be struck
## on the ground. This is derived even before the due landing moves the ledger.
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
		"facing": landed.facing, "center": from_center, "lift": 0.0, "airborne": false, "progress": 0.0,
		"footprint": landed.footprint(size),
		"target": to_center, "radius": upcoming.blast_radius_tiles,
		"until": until, "travel": upcoming.travel_ticks,
	}
	if not score is ArenicMaskScore:
		grounded.erase("facing") # Legacy facing changes only when its landing resolves.
	# One beat, a teleport, or any position outside the arc keeps the boss down.
	if next_index == landed_index or upcoming.travel_ticks <= 0 or until <= 0 or until > upcoming.travel_ticks:
		return grounded
	var progress: float = clampf(1.0 - float(until) / float(upcoming.travel_ticks), 0.0, 1.0)
	return {
		"center": from_center.lerp(to_center, progress),
		"footprint": landed.footprint(size),
		# A symmetric parabola: the apex is mid-flight, both ends touch the floor.
		"lift": upcoming.lift_tiles * 4.0 * progress * (1.0 - progress),
		"airborne": true, "progress": progress,
		"target": to_center, "radius": upcoming.blast_radius_tiles,
		"until": until, "travel": upcoming.travel_ticks,
	}


## The combat ledger keeps cumulative damage and the last resolved landing.
## Collision reads the score at the current simulation tick, including the
## landing tick before its merged-stream event has run. Ordinary enemies have
## no derived pose and keep the ledger's authored footprint.
func enemy_pose(arena_id: String, enemy_id: String) -> Dictionary:
	if enemy_id != ArenicCombatState.boss_enemy_id(arena_id):
		return {}
	var placement: Dictionary = boss_placement(arena_id)
	if placement.is_empty():
		return {}
	return placement


## Current conditions affecting this arena's boss, derived without advancing it.
## Timers measure existing simulation ticks, never wall time. A negative timer
## means no fixed duration; stacks count physical pools/tiles, not a new stat.
## Fresh value-only entries cannot mutate the score, ledger, or hazard fields.
func boss_effects(arena_id: String) -> Array[Dictionary]:
	var effects: Array[Dictionary] = []
	var clock: ArenicCycleClock = _clocks.get(arena_id)
	if _combat == null or clock == null:
		return effects
	var boss_id: String = ArenicCombatState.boss_enemy_id(arena_id)
	if not _combat._enemy_ids(arena_id).has(boss_id):
		return effects
	# Attached debuffs survive a jump; only ground-contact effects disappear.
	for effect: Dictionary in _combat.enemy_dot_effects(arena_id, boss_id):
		effect.remaining_seconds = minf(float(effect.remaining_seconds), float(clock.cycle_ticks - clock.tick) / ArenicCycleClock.TICKS_PER_SECOND)
		effect.detail += " Arena restart clears remaining stacks."
		effects.append(effect)
	var placement: Dictionary = boss_placement(arena_id)
	if not placement.is_empty() and placement.airborne:
		effects.append({"id": "airborne", "name": "Airborne", "remaining_seconds": float(placement.until) / ArenicCycleClock.TICKS_PER_SECOND,
			"stacks": 1, "beneficial": true, "detail": "Ground attacks cannot hit the boss until it lands."})
		return effects
	var footprint: Rect2i = _combat.enemy_footprint(arena_id, boss_id)
	if not footprint.has_area():
		return effects
	var acid: ArenicAcidField = _acid_fields.get(arena_id)
	var pools: int = 0
	var next_expiry: int = clock.cycle_ticks - clock.tick
	if acid != null:
		for pool: ArenicAcidField.Pool in acid._pools:
			if pool.ticks_left > 0 and pool.area.intersects(footprint):
				pools += 1
				next_expiry = mini(next_expiry, pool.ticks_left)
	if pools > 0:
		effects.append({"id": "acid", "name": "Acid", "remaining_seconds": float(next_expiry) / ArenicCycleClock.TICKS_PER_SECOND,
			"stacks": pools, "beneficial": false, "detail": "%d overlapping acid pool%s. Timer shows the next pool expiry or cycle reset; leaving the ground ends contact." % [pools, "" if pools == 1 else "s"]})
	var ground: ArenicDigField = _dig_fields.get(arena_id)
	var tiles: int = 0
	if ground != null:
		for index: int in ground._dug:
			var cell: Vector2i = ArenicDigField.cell_of(index)
			if footprint.has_point(cell) and _combat.enemy_at(arena_id, cell) == boss_id:
				tiles += 1
	if tiles > 0:
		effects.append({"id": "broken_ground", "name": "Broken ground", "remaining_seconds": -1.0,
			"stacks": tiles, "beneficial": false, "detail": "%d dug tile%s beneath the boss. Damage uses banked overlap time; this is a tile count, not effect strength." % [tiles, "" if tiles == 1 else "s"]})
	return effects


## A static closure captures only the weak reference. A bound encounter method
## would create combat -> encounter -> combat ownership and leak old runs.
static func _weak_enemy_pose_lookup(reference: WeakRef) -> Callable:
	return func(arena_id: String, enemy_id: String) -> Dictionary:
		var conductor: ArenicEncounterState = reference.get_ref()
		return conductor.enemy_pose(arena_id, enemy_id) if conductor != null else {}


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


func mask_score(arena_id: String) -> ArenicMaskScore:
	return _scores.get(arena_id) as ArenicMaskScore


func _resolve_mask(arena_id: String, event: ArenicScoreEvent, combat: ArenicCombatState) -> void:
	var score: ArenicMaskScore = mask_score(arena_id)
	if score == null:
		return
	beats_resolved += 1
	if event.kind == "window":
		combat.register_enemy(arena_id, ArenicCombatState.boss_enemy_id(arena_id), Rect2i(event.boss_origin, _sizes[arena_id]), event.boss_facing)
	for actor: String in combat.ally_ids(arena_id):
		var ally: Dictionary = combat.ally_status(arena_id, actor)
		if ally.is_empty() or int(ally.health) <= 0:
			continue
		if event.kind == "window":
			if Rect2i(event.boss_origin, _sizes[arena_id]).has_point(ally.cell):
				combat.wound_ally(arena_id, actor, int(ally.health), event.event_id + ".crush")
		elif event.wounds(ally.cell, combat.encounter_effects.attunement(arena_id, actor)):
			if "expose" in event.tags:
				combat.encounter_effects.expose(score, event, actor)
			combat.wound_ally(arena_id, actor, event.damage, event.event_id)
	score_event_resolved.emit(arena_id, event.event_id)


static func _weak_bonus_lookup(reference: WeakRef) -> Callable:
	return func(arena_id: String, enemy_id: String, actor: String) -> int:
		var conductor: ArenicEncounterState = reference.get_ref()
		if conductor == null or enemy_id != ArenicCombatState.boss_enemy_id(arena_id):
			return 0
		var score: ArenicMaskScore = conductor.mask_score(arena_id)
		return conductor._combat.encounter_effects.claim(score, conductor.cycle_position(arena_id), actor) if score != null else 0


func score_readout(arena_id: String) -> String:
	var score: ArenicMaskScore = mask_score(arena_id)
	if score == null:
		return ""
	var tick: int = cycle_position(arena_id)
	var phrase: String = ["A", "A′", "B", "A″"][mini(3, tick / 1800)]
	var current: PackedStringArray = []
	for event: ArenicScoreEvent in score.visible_events(tick):
		if tick < event.at_tick:
			current.append("%s %.1fs" % [event.display_name, float(event.at_tick - tick) / 60.0])
		elif event.kind == "window":
			current.append("Reconciliation · %s +%d · %.1fs" % [event.attunement_bonus.to_upper(), score.bonus_damage, float(event.end_tick - tick) / 60.0])
	var upcoming: PackedStringArray = []
	for event: ArenicScoreEvent in score.events:
		if event.at_tick > tick and event.cue_tick > tick:
			upcoming.append("%s %.1fs" % [event.display_name, float(event.at_tick - tick) / 60.0])
			if upcoming.size() == 2:
				break
	return "%s · %s · %s / 2:00\n%s\nNext: %s" % [score.title, phrase, cycle_label(arena_id), "  +  ".join(current) if not current.is_empty() else "Neutral aisles open · Sun/Moon fonts are optional", "  →  ".join(upcoming) if not upcoming.is_empty() else "Cycle returns to Sun"]


func actor_effects(arena_id: String, actor: String) -> Array[Dictionary]:
	var effects: Array[Dictionary] = []
	if _combat == null:
		return effects
	var attunement: String = _combat.encounter_effects.attunement(arena_id, actor)
	if not attunement.is_empty():
		effects.append({"id": "attunement", "name": attunement.capitalize(), "beneficial": true, "stacks": 1, "remaining_seconds": -1.0, "detail": "Matching labeled seals are harmless. Cleanse keeps attunement. Resets with this arena."})
	for source: String in _combat.encounter_effects.actors:
		var personal: Dictionary = _combat.encounter_effects.actors[source].get(actor, {})
		for stack: Dictionary in personal.get("exposures", []):
			effects.append({"id": stack.event_id, "name": "Exposure", "beneficial": false, "stacks": 1, "remaining_seconds": float(maxi(0, int(stack.due_tick) - cycle_position(source))) / 60.0, "detail": "One delayed personal wound. Cleanse before the countdown ends."})
	return effects
