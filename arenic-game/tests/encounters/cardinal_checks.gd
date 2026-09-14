extends SceneTree
const SCORE: ArenicMaskScore = preload("res://data/encounters/v2/cardinal_normal_1.tres")
const WORLD: ArenicWorldDefinition = preload("res://data/world/arenia.tres")
const CATALOG: ArenicEncounterCatalog = preload("res://data/encounters/catalog.tres")
const CodecTests = preload("res://tests/persistence/save_codec_checks.gd")
var checks: int = 0
var failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("Cardinal: " + description)

func model(count: int = 0, only_sanctum: bool = false) -> Dictionary:
	var combat := ArenicCombatState.new()
	combat.encounter_effects.ruleset = ArenicActorEffects.RULESET
	var world: ArenicWorldDefinition = WORLD
	if only_sanctum:
		world = ArenicWorldDefinition.new()
		world.arenas = [WORLD.arenas[WORLD.index_for_id("sanctum")]]
	combat.configure(world)
	var encounter := ArenicEncounterState.new()
	encounter.configure(world, CATALOG, combat)
	for index: int in count:
		combat.register_ally("sanctum", "actor:%d" % index, Vector2i(3 + (index % 20) * 3, 2 if index < 20 else 28), 4, 4)
	return {"combat": combat, "encounter": encounter}

func _run() -> void:
	check(SCORE.validation_errors().is_empty(), "Authored score validates: " + str(SCORE.validation_errors()))
	_parity()
	_boundaries()
	_damage()
	_windows()
	_walking()
	_replay()
	_persistence()
	print("Cardinal checks: %d assertions, %s." % [checks, "FAILED" if failed else "passed"])
	quit(1 if failed else 0)

func _parity() -> void:
	var reference: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/encounters/fixtures/cardinal_reference.json"))
	check(SCORE.events.size() == 25, "All 25 events are present, including the overlap")
	for index: int in SCORE.events.size():
		var event: ArenicScoreEvent = SCORE.events[index]
		var source: Dictionary = reference.events[index]
		var masks: Array = []
		for mask: Rect2i in event.masks:
			masks.append([mask.position.x, mask.position.y, mask.size.x, mask.size.y])
		check(event.event_id == source.event_id and event.action_id == source.action and event.cue_tick == source.cue_tick and event.at_tick == source.at_tick and event.end_tick == source.end_tick and event.damage == source.damage and masks == source.masks.map(func(r: Array) -> Array: return r.map(func(n: Variant) -> int: return int(n))) and Array(event.mask_elements) == source.get("mask_elements", []) and Array(event.tags) == source.tags, "Source/resource parity: " + event.event_id)
	for index: int in SCORE.beats.size():
		var beat: ArenicEncounterBeat = SCORE.beats[index]
		var source: Dictionary = reference.pose_track[index]
		check(beat.at_tick == source.tick and beat.boss_origin_cell == Vector2i(int(source.origin[0]), int(source.origin[1])) and beat.facing == source.facing, "Source/pose parity")
	var invalid: ArenicMaskScore = SCORE.duplicate(true)
	invalid.events[0].masks[0] = Rect2i(0, 0, 10, 10)
	check(not invalid.validation_errors().is_empty(), "Recovery perimeter violation is rejected")
	invalid = SCORE.duplicate(true)
	invalid.events[1].event_id = invalid.events[0].event_id
	check(not invalid.validation_errors().is_empty(), "Duplicate event IDs rejected")
	invalid = SCORE.duplicate(true)
	invalid.events[0].mask_elements.clear()
	check(invalid.content_hash() != SCORE.content_hash(), "Semantic changes produce a different content hash")

func _boundaries() -> void:
	var m: Dictionary = model()
	for event: ArenicScoreEvent in SCORE.events:
		check(event not in SCORE.visible_events(event.cue_tick - 1), "No early cue: " + event.event_id)
		check(event in SCORE.visible_events(event.cue_tick) and event in SCORE.visible_events(event.at_tick - 1), "Warning includes exact cue and pre-impact ticks")
		check(event in SCORE.visible_events(event.at_tick) and event not in SCORE.visible_events(event.end_tick), "Half-open impact/window interval")
		if event.kind == "window":
			m.encounter.seek("sanctum", event.at_tick)
			var pose: Dictionary = m.encounter.boss_placement("sanctum")
			check(not pose.airborne and pose.footprint.position == event.boss_origin and pose.facing == event.boss_facing, "Pose changes on transfer tick before effects")
		else:
			m.combat.register_ally("sanctum", "victim", event.masks[0].position, 4, 4)
			m.encounter.seek("sanctum", event.at_tick - 1)
			m.encounter.tick(m.combat)
			check(m.combat.ally_status("sanctum", "victim").health == 4, "Cue never deals damage")
			m.encounter.tick(m.combat)
			var after: int = m.combat.ally_status("sanctum", "victim").health
			m.encounter.tick(m.combat)
			check(m.combat.ally_status("sanctum", "victim").health == after, "Instant hit does not repeat next tick")

func _damage() -> void:
	var m: Dictionary = model()
	m.combat.register_ally("sanctum", "sun", SCORE.sun_font, 4, 4)
	m.combat.register_ally("sanctum", "moon", SCORE.moon_font, 4, 4)
	m.encounter.tick(m.combat)
	m.combat.move_ally("sanctum", "sun", Vector2i(39, 8))
	m.combat.move_ally("sanctum", "moon", Vector2i(40, 8))
	m.encounter.seek("sanctum", 2190)
	m.encounter.tick(m.combat)
	check(m.combat.ally_status("sanctum", "sun").health == 4 and m.combat.ally_status("sanctum", "moon").health == 3, "Mirrored Sun stays Sun; adjacent opposite tags never chain")
	m.combat.register_ally("sanctum", "exposed", Vector2i(24, 8), 4, 4)
	m.encounter.seek("sanctum", 1170)
	m.encounter.tick(m.combat)
	check(m.combat.ally_status("sanctum", "exposed").health == 3, "Confession wounds once immediately")
	m.combat.move_ally("sanctum", "exposed", Vector2i(29, 4))
	m.encounter.seek("sanctum", 1409)
	m.encounter.tick(m.combat)
	check(m.combat.ally_status("sanctum", "exposed").health == 3, "Exposure cannot fire early")
	m.encounter.tick(m.combat)
	check(m.combat.ally_status("sanctum", "exposed").health == 2, "Exposure deals one wound exactly +240 ticks")
	m.encounter.tick(m.combat)
	check(m.combat.encounter_effects.state("sanctum", "exposed").exposures.is_empty(), "Exposure removed at +241")
	m.combat.register_ally("sanctum", "overlap", Vector2i(24, 8), 4, 4)
	var order: Array[String] = []
	m.encounter.score_event_resolved.connect(func(_arena: String, id: String) -> void: order.append(id))
	m.encounter.seek("sanctum", 6570)
	m.encounter.tick(m.combat)
	check(order == ["cardinal.4.4", "cardinal.4.overlap"] and m.combat.ally_status("sanctum", "overlap").health == 2, "Simultaneous Confession and Sun are independent ordered wounds")
	m.combat.register_ally("sanctum", "crushed", Vector2i(30, 18), 4, 4)
	m.encounter.seek("sanctum", 3300)
	m.encounter.tick(m.combat)
	check(m.combat.ally_status("sanctum", "crushed").health == 0, "Arriving grounded footprint crushes")
	# Use the real instant Bard cast as the before-effects callback on the exact deadline.
	var bard := ArenicHeroState.new()
	bard.identity_id = 0
	bard.definition = load("res://data/classes/bard.tres")
	bard.arena_id = "sanctum"
	bard.cell = Vector2i(29, 12)
	m.combat.sync_allies([bard])
	m.combat.encounter_effects.state("sanctum", bard.ally_id()).attunement = "moon"
	m.combat.encounter_effects.expose(SCORE, SCORE.event_for("cardinal.1.4"), bard.ally_id())
	m.encounter.seek("sanctum", 1410)
	m.encounter.tick(m.combat, 1, {}, func() -> void: m.combat.try_cast(bard))
	check(m.combat.ally_status("sanctum", bard.ally_id()).health == 4 and m.combat.encounter_effects.state("sanctum", bard.ally_id()).exposures.is_empty(), "Real Cleanse on damage tick removes Exposure first")
	check(m.combat.encounter_effects.attunement("sanctum", bard.ally_id()) == "moon", "Cleanse cannot remove polarity")
	var channeler := ArenicHeroState.new()
	channeler.identity_id = 2
	channeler.definition = load("res://data/classes/cardinal.tres")
	channeler.arena_id = "sanctum"
	channeler.cell = Vector2i(29, 14)
	m.combat.sync_allies([channeler])
	m.combat.try_cast(channeler)
	m.combat.encounter_effects.expose(SCORE, SCORE.event_for("cardinal.1.4"), channeler.ally_id())
	m.combat.damage_allies_in("sanctum", Rect2i(channeler.cell, Vector2i.ONE), 4)
	check(not m.combat.is_channeling(channeler) and m.combat.encounter_effects.state("sanctum", channeler.ally_id()).exposures.is_empty(), "Friendly-fire defeat cancels channel and Exposure without requiring a shell listener")

func _windows() -> void:
	var m: Dictionary = model()
	var hero := ArenicHeroState.new()
	hero.identity_id = 1
	hero.definition = load("res://data/classes/bard.tres")
	hero.arena_id = "sanctum"
	hero.cell = Vector2i(29, 12)
	m.combat.sync_allies([hero])
	m.combat.encounter_effects.state("sanctum", hero.ally_id()).attunement = "sun"
	m.encounter.seek("sanctum", 1500)
	check(m.combat.try_cast(hero).is_empty(), "Real direct cast accepted inside window")
	check(m.combat.damage_for_arena("sanctum") == 2, "Matching first direct hit gets exactly +1")
	m.combat.reset_caster(hero)
	m.combat.try_cast(hero)
	check(m.combat.damage_for_arena("sanctum") == 3, "Second direct hit keeps ordinary damage")
	m.combat.apply_hazard_damage("sanctum", "boss:sanctum", 1, hero.ally_id(), "acid_flask")
	check(m.combat.damage_for_arena("sanctum") == 4, "Periodic damage cannot multiply the window")
	m.combat.respawn_hero_ally(hero)
	check(m.combat.encounter_effects.state("sanctum", hero.ally_id()).claims == ["cardinal.1.6"], "Respawn cannot grant a second claim in the same window")
	m.encounter.seek("sanctum", 1800)
	check(m.combat.direct_bonus_lookup.call("sanctum", "boss:sanctum", "fresh") == 0, "Window end is exclusive")
	m.encounter.restart("sanctum", false)
	check(m.combat.encounter_effects.actors.get("sanctum", {}).is_empty(), "Cycle reset clears tags, claims and Exposure")
	check(m.combat.damage_for_arena("sanctum") == 4, "Cycle cleanup retains cumulative damage")

func _walking() -> void:
	var route: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/encounters/fixtures/cardinal_walking.json"))
	var m: Dictionary = model()
	var hero := ArenicHeroState.new()
	hero.identity_id = 0
	hero.definition = load("res://data/classes/warrior.tres")
	hero.arena_id = "sanctum"
	hero.cell = Vector2i(29, 2)
	var previous: Vector2i = hero.cell
	var moves: Array[ArenicTimelineEvent] = []
	for step: Dictionary in route.movement_witness:
		var cell := Vector2i(int(step.cell[0]), int(step.cell[1]))
		if cell != previous:
			moves.append(ArenicTimelineEvent.move(int(step.tick), cell - previous))
		previous = cell
	m.encounter.performer_lookup = func(id: String) -> ArenicHeroState: return hero if id == hero.ally_id() else null
	m.encounter.roster_lookup = func() -> Array: return [hero]
	m.combat.sync_allies([hero])
	m.encounter.fold_ghost(hero, ArenicRecording.create(hero.cell, moves))
	for tick: int in 7200:
		m.encounter.tick(m.combat)
		for checkpoint: Dictionary in route.checkpoint_rears:
			if tick == int(checkpoint.tick):
				check(hero.cell == Vector2i(int(checkpoint.cell[0]), int(checkpoint.cell[1])), "Untuned solo recording reaches the published rear at %d" % tick)
	check(m.combat.ally_status("sanctum", hero.ally_id()).health == 4, "Published neutral route survives a full real replay without wounds")
	check(hero.cell == Vector2i(29, 2), "Walking recording returns to its start at the seam")

func _replay() -> void:
	var empty: Dictionary = model(0, true)
	var full: Dictionary = model(40, true)
	var a: Array[String] = []
	var b: Array[String] = []
	empty.encounter.score_event_resolved.connect(func(_arena: String, id: String) -> void: a.append(id))
	full.encounter.score_event_resolved.connect(func(_arena: String, id: String) -> void: b.append(id))
	var start: int = Time.get_ticks_usec()
	for cycle: int in 100:
		empty.encounter.tick(empty.combat, 7200)
		full.encounter.tick(full.combat, 7200)
		check(a == b and a.size() == 25, "Cycle %d: empty/full roster emits identical 25-event staff" % cycle)
		a.clear()
		b.clear()
	print("Cardinal 100-cycle empty/full model benchmark: %.2fs" % (float(Time.get_ticks_usec() - start) / 1000000.0))
	full = model(40)
	full.encounter.set_paused("sanctum", true)
	full.encounter.tick(full.combat, 300)
	check(full.encounter.cycle_position("sanctum") == 0 and full.encounter.cycle_position("labyrinth") == 300, "Pausing Sanctum leaves other clocks independent")

func _persistence() -> void:
	var run := CodecTests.RunFixture.new()
	run.selected_class = load("res://data/classes/warrior.tres")
	run.selected_identity = 0
	run._next_identity = 1
	run.intro_step = 6
	var hero := ArenicHeroState.new()
	hero.identity_id = 0
	hero.definition = run.selected_class
	hero.arena_id = "sanctum"
	hero.cell = Vector2i(29, 12)
	run.heroes.append(hero)
	run.combat = model().combat
	run.combat.sync_allies(run.heroes)
	var personal: Dictionary = run.combat.encounter_effects.state("sanctum", hero.ally_id())
	personal.attunement = "moon"
	personal.claims.append("cardinal.1.6")
	run.combat.encounter_effects.expose(SCORE, SCORE.event_for("cardinal.2.4"), hero.ally_id())
	var payload: Dictionary = ArenicSaveCodec.capture_run(run)
	check(ArenicSaveCodec.validate(payload).is_empty(), "Save accepts bounded personal state: " + str(ArenicSaveCodec.validate(payload)))
	var restored := CodecTests.RunFixture.new()
	check(ArenicSaveCodec.restore_run(JSON.parse_string(JSON.stringify(payload)), restored), "Personal state restores through JSON and the shared codec")
	check(ArenicSaveCodec.capture_run(restored) == payload, "Attunement, deadline, claim, vitality and fingerprint round trip exactly")
	var bad: Dictionary = payload.duplicate(true)
	bad.run.combat.encounter.fingerprint = "changed"
	check(not ArenicSaveCodec.restore_run(bad, restored) and ArenicSaveCodec.capture_run(restored) == payload, "Unavailable tuning rejects before mutating the live run")
	bad = payload.duplicate(true)
	bad.run.combat.encounter.actors.sanctum[hero.ally_id()].exposures[0].due_tick += 1
	check(not ArenicSaveCodec.validate(bad).is_empty(), "Forged Exposure deadline rejected")
	bad = payload.duplicate(true)
	bad.schema_version = 9
	bad.run.erase("loot") # Schema 9 predates the equipment ledger.
	bad.run.combat.erase("encounter")
	var migrated: Dictionary = ArenicSaveMigrations.upgrade(bad)
	check(migrated.ok and migrated.payload.run.combat.encounter.ruleset == ArenicActorEffects.LEGACY, "Schema 9 preserves static Sanctum instead of silently activating Cardinal")
	run.free()
	restored.free()
