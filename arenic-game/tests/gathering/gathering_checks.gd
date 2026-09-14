extends SceneTree
## Pure gathering rules: no scene, renderer, audio or independent clock.

var _checks: int = 0
var _failures := PackedStringArray()


func _initialize() -> void:
	_check_definition()
	_check_fill_and_deposit()
	_check_partial_and_movement()
	_check_frozen_rules()
	_check_death_restart_and_heroes()
	_check_bounds_and_saturation()
	if _failures.is_empty():
		print("Gathering checks passed: %d assertions." % _checks)
		quit(0)
	else:
		for failure: String in _failures:
			push_error(failure)
		print("Gathering checks failed: %d of %d assertions." % [_failures.size(), _checks])
		quit(1)


func _fixture() -> Dictionary:
	var world := ArenicWorldDefinition.new()
	for id: String in ["guild_house", "sanctum"]:
		var arena := ArenicArenaDefinition.new()
		arena.arena_id = id
		world.arenas.append(arena)
	var combat := ArenicCombatState.new()
	combat.configure(world)
	var definition := load("res://data/guild/gathering.tres").duplicate(true) as ArenicGatheringDefinition
	var hero := ArenicHeroState.new()
	hero.definition = ArenicClassDefinition.new()
	hero.cell = definition.wood_sources[0]
	combat.register_ally(hero.arena_id, hero.ally_id(), hero.cell)
	var state := ArenicGatheringState.new()
	state.configure(definition)
	return {"state": state, "definition": definition, "hero": hero, "combat": combat}


func _step(state: ArenicGatheringState, heroes: Array[ArenicHeroState], combat: ArenicCombatState, ticks: int) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	for _tick: int in range(ticks):
		events.append_array(state.advance(heroes, combat))
	return events


func _check_definition() -> void:
	var fixture: Dictionary = _fixture()
	var definition: ArenicGatheringDefinition = fixture.definition
	var state: ArenicGatheringState = fixture.state
	_expect(definition.validation_errors().is_empty(), "Authored gathering data passes its shared preflight.")
	_expect(definition.wood_sources == [Vector2i(12, 9), Vector2i(12, 23)] and definition.gold_sources == [Vector2i(7, 24), Vector2i(56, 7)], "Two wood sites and the upper-left/lower-right clearing mines use authored Guild House cells.")
	_expect(definition.wood_dropoff == Vector2i(23, 21) and definition.gold_dropoff == Vector2i(42, 21), "Wood and gold dropoffs flank the clearing tavern at their authored cells.")
	var authored_gold_dropoff: Vector2i = definition.gold_dropoff
	_expect(definition.source_kind_at(Vector2i(14, 9)) == "wood" and definition.source_kind_at(Vector2i(14, 11)).is_empty(), "Work uses an inclusive circular radius, not a square corner.")
	_expect(definition.source_at(Vector2i(56, 7)).id == "gold:1", "Derived site IDs identify the actual source without stored site authority.")
	definition.wood_sources.append(Vector2i(1, 1))
	_expect(not state.configure(definition) and state.definition.wood_sources.size() == 2, "Wrong site counts reject without replacing the last valid definition.")
	definition.wood_sources.pop_back()
	definition.gold_dropoff = definition.wood_dropoff
	_expect(not state.configure(definition), "Overlapping site centers reject authored ambiguity.")
	definition.gold_dropoff = Vector2i(66, 8)
	_expect(not state.configure(definition), "Sites outside the arena reject.")
	definition.gold_dropoff = authored_gold_dropoff
	definition.radius_tiles = NAN
	_expect(not state.configure(definition), "Nonfinite radii cannot enter work calculations.")
	definition.radius_tiles = 2.0
	definition.fill_seconds = 0.0
	_expect(not state.configure(definition), "Zero fill duration cannot create division or free-resource loops.")
	definition.fill_seconds = 5.0
	definition.unload_seconds = 11.0
	_expect(not state.configure(definition), "Unload timing remains bounded.")
	definition.unload_seconds = 1.0
	definition.capacity_units = 1001
	_expect(not state.configure(definition), "Bag capacity remains bounded.")


func _check_fill_and_deposit() -> void:
	var fixture: Dictionary = _fixture()
	var state: ArenicGatheringState = fixture.state
	var hero: ArenicHeroState = fixture.hero
	var combat: ArenicCombatState = fixture.combat
	_expect(state.wood_total == 0 and state.gold_total == 0 and state.snapshot_for(hero).phase == "idle", "A new gathering model has no banked or carried resources.")
	var events: Array[Dictionary] = _step(state, [hero], combat, 299)
	var status: Dictionary = state.snapshot_for(hero)
	_expect(events.is_empty() and status.phase == "gathering" and status.fill_ticks == 299 and status.amount == 9 and status.source_id == "wood:0", "A bag is still filling one tick before its authored five-second endpoint.")
	state.advance([hero], combat)
	status = state.snapshot_for(hero)
	_expect(status.phase == "full" and status.fill_ticks == 300 and status.amount == 10 and status.progress == 1.0, "Exactly 300 arena ticks fill the bag with ten units.")
	_step(state, [hero], combat, 120)
	_expect(state.snapshot_for(hero).fill_ticks == 300 and state.wood_total == 0, "Remaining at the source cannot overfill or automatically bank a full bag.")
	hero.cell = state.definition.gold_dropoff
	_step(state, [hero], combat, 60)
	_expect(state.snapshot_for(hero).unload_ticks == 0 and state.wood_total == 0 and state.gold_total == 0, "The wrong resource dropoff accepts nothing.")
	hero.cell = state.definition.wood_dropoff
	events = _step(state, [hero], combat, 59)
	status = state.snapshot_for(hero)
	_expect(events.is_empty() and status.phase == "unloading" and status.unload_ticks == 59 and status.dropoff_id == "wood_dropoff", "Matching dropoff waits for the full authored unload second.")
	events = state.advance([hero], combat)
	_expect(events == [{"kind": "deposited", "hero_id": 0, "resource": "wood", "amount": 10}], "The sixtieth unload tick emits exactly one attributed ten-unit deposit.")
	_expect(state.wood_total == 10 and state.gold_total == 0 and state.snapshot_for(hero).phase == "idle", "Completed unloading clears the bag and changes only its bank.")
	_expect(_step(state, [hero], combat, 120).is_empty() and state.wood_total == 10, "An empty hero at a dropoff cannot repeat the deposit.")
	hero.cell = state.definition.gold_sources[1]
	_step(state, [hero], combat, 300)
	hero.cell = state.definition.gold_dropoff
	events = _step(state, [hero], combat, 60)
	_expect(events.size() == 1 and events[0].resource == "gold" and state.gold_total == 10 and state.wood_total == 10, "Gold mining and its dropoff use a separate resource bank.")


func _check_partial_and_movement() -> void:
	var fixture: Dictionary = _fixture()
	var state: ArenicGatheringState = fixture.state
	var hero: ArenicHeroState = fixture.hero
	var combat: ArenicCombatState = fixture.combat
	_step(state, [hero], combat, 90)
	hero.cell = state.definition.wood_sources[0] + Vector2i(2, 0)
	_step(state, [hero], combat, 60)
	_expect(state.snapshot_for(hero).fill_ticks == 150, "Moving within the inclusive source radius continues filling.")
	hero.cell = state.definition.wood_dropoff
	_step(state, [hero], combat, 60)
	_expect(state.snapshot_for(hero).phase == "carrying" and state.snapshot_for(hero).fill_ticks == 150 and state.snapshot_for(hero).unload_ticks == 0 and state.wood_total == 0, "A partial bag is retained but cannot unload early.")
	hero.cell = state.definition.gold_sources[0]
	_step(state, [hero], combat, 60)
	_expect(state.snapshot_for(hero).kind == "wood" and state.snapshot_for(hero).fill_ticks == 150, "Another resource cannot mix into a partial bag.")
	hero.arena_id = "sanctum"
	hero.cell = state.definition.wood_sources[0]
	_step(state, [hero], combat, 60)
	_expect(state.snapshot_for(hero).fill_ticks == 150, "Identical coordinates in another arena do not gather Guild House resources.")
	hero.arena_id = "guild_house"
	hero.cell = state.definition.wood_sources[1]
	_step(state, [hero], combat, 150)
	_expect(state.snapshot_for(hero).phase == "full", "The second source of the same resource resumes the existing bag.")
	hero.cell = state.definition.wood_dropoff
	_step(state, [hero], combat, 30)
	hero.cell += Vector2i(2, 0)
	_step(state, [hero], combat, 10)
	_expect(state.snapshot_for(hero).unload_ticks == 40, "Movement within the dropoff radius retains unloading progress.")
	hero.cell += Vector2i(1, 0)
	state.advance([hero], combat)
	_expect(state.snapshot_for(hero).phase == "full" and state.snapshot_for(hero).unload_ticks == 0, "Leaving the dropoff interrupts unloading without losing the full bag.")
	hero.cell = state.definition.wood_dropoff
	_expect(_step(state, [hero], combat, 59).is_empty(), "Returning must perform a complete unload again.")
	_expect(state.advance([hero], combat).size() == 1, "A fresh uninterrupted unload completes normally.")


func _check_frozen_rules() -> void:
	var fixture: Dictionary = _fixture()
	var state: ArenicGatheringState = fixture.state
	var definition: ArenicGatheringDefinition = fixture.definition
	var hero: ArenicHeroState = fixture.hero
	var combat: ArenicCombatState = fixture.combat
	_step(state, [hero], combat, 150)
	definition.fill_seconds = 1.0
	definition.unload_seconds = 2.0
	definition.capacity_units = 20
	_expect(state.configure(definition), "Valid Inspector rule changes can be applied without resetting progress.")
	var status: Dictionary = state.snapshot_for(hero)
	_expect(status.fill_ticks == 150 and status.fill_duration_ticks == 300 and status.unload_duration_ticks == 60 and status.capacity_units == 10, "A started bag keeps all accepted rules through reconfiguration.")
	status.fill_ticks = 299
	status.kind = "gold"
	_expect(state.snapshot_for(hero).fill_ticks == 150 and state.snapshot_for(hero).kind == "wood", "Snapshot mutation cannot change a real bag.")
	for _read: int in range(100):
		state.snapshot_for(hero)
	_expect(state.snapshot_for(hero).fill_ticks == 150, "Readout and paused frames do not advance work.")
	_step(state, [hero], combat, 150)
	hero.cell = state.definition.wood_dropoff
	_step(state, [hero], combat, 60)
	hero.cell = state.definition.wood_sources[0]
	state.advance([hero], combat)
	status = state.snapshot_for(hero)
	_expect(status.fill_duration_ticks == 60 and status.unload_duration_ticks == 120 and status.capacity_units == 20 and state.wood_total == 10, "A new bag receives the new rules after the old bag deposits under its original rules.")


func _check_death_restart_and_heroes() -> void:
	var fixture: Dictionary = _fixture()
	var state: ArenicGatheringState = fixture.state
	var first: ArenicHeroState = fixture.hero
	var combat: ArenicCombatState = fixture.combat
	var second := ArenicHeroState.new()
	second.identity_id = 8
	second.cell = state.definition.gold_sources[1]
	second.selected = false
	combat.register_ally(second.arena_id, second.ally_id(), second.cell)
	_step(state, [second, first], combat, 10)
	_expect(state.snapshot_for(first).kind == "wood" and state.snapshot_for(second).kind == "gold" and state.snapshot_for(second).fill_ticks == 10, "Every living hero works from its authoritative cell, regardless of selected or ghost presentation.")
	combat.apply_blast(first.arena_id, Vector2(first.cell), 1.0)
	state.advance([first, second], combat)
	_expect(state.snapshot_for(first).phase == "idle" and state.snapshot_for(second).fill_ticks == 11, "A real combat death discards only the defeated hero's carried work.")
	_step(state, [first], combat, 300)
	_expect(state.snapshot_for(first).phase == "idle", "A defeated hero cannot gather again before revival.")
	combat.revive_ally(first.arena_id, first.ally_id())
	state.advance([first], combat)
	_expect(state.snapshot_for(first).fill_ticks == 1, "Revival starts a fresh bag rather than restoring dropped work.")
	second.arena_id = "sanctum"
	state.wood_total = 10
	state.restart([first, second])
	_expect(state.snapshot_for(first).phase == "idle" and state.snapshot_for(second).fill_ticks == 11 and state.wood_total == 10, "A Guild House cycle restart clears participating bags while preserving banks and remote bags.")
	state.clear_hero(second.identity_id)
	_expect(state.snapshot_for(second).phase == "idle", "Explicit defeat cleanup can clear a carried bag outside the Guild House.")


func _check_bounds_and_saturation() -> void:
	var fixture: Dictionary = _fixture()
	var state: ArenicGatheringState = fixture.state
	var hero: ArenicHeroState = fixture.hero
	var combat: ArenicCombatState = fixture.combat
	_expect(state.advance([hero, hero], combat).is_empty() and state._bags.is_empty(), "Duplicate identities reject the whole tick instead of doubling work.")
	var invalid := ArenicHeroState.new()
	invalid.identity_id = 320
	invalid.cell = hero.cell
	_expect(state.advance([hero, invalid], combat).is_empty() and state._bags.is_empty(), "Out-of-range hero identity rejects without partially advancing earlier heroes.")
	var oversized: Array[ArenicHeroState] = []
	oversized.resize(321)
	oversized.fill(hero)
	_expect(state.advance(oversized, combat).is_empty() and state._bags.is_empty(), "Oversized hero batches cannot exceed the bounded tick workload.")
	var definition: ArenicGatheringDefinition = fixture.definition
	definition.fill_seconds = 0.05
	definition.unload_seconds = 0.05
	state.configure(definition)
	hero.identity_id = 9
	var earlier := ArenicHeroState.new()
	earlier.identity_id = 2
	earlier.cell = hero.cell
	_step(state, [hero, earlier], combat, 3)
	hero.cell = definition.wood_dropoff
	earlier.cell = definition.wood_dropoff
	state.wood_total = ArenicGatheringState.MAX_TOTAL - 3
	var events: Array[Dictionary] = _step(state, [hero, earlier], combat, 3)
	_expect(events == [{"kind": "deposited", "hero_id": 2, "resource": "wood", "amount": 3}], "Saturating deposits report only accepted units in stable hero-identity order.")
	_expect(state.wood_total == ArenicGatheringState.MAX_TOTAL and state.gold_total == 0 and state._bags.is_empty(), "Full banks never overflow or report a zero-unit deposit after unloading.")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
