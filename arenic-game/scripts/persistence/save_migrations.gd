class_name ArenicSaveMigrations
extends RefCounted
## Pure, sequential payload upgrades. Add each released vN -> vN+1 function
## here and retain fixtures for both versions. Never hydrate an unknown shape.
const CURRENT_VERSION: int = 11
const STEPS: Dictionary = {}
## Released schema-3 arrival totals. Never derive historical simulation timing
## from editable current resources; new ability IDs need an explicit migration.
const V3_RESOLVE_SECONDS: Dictionary = {
	"auto_shot": 0.75, "bash": 0.35, "backstab": 0.2, "acid_flask": 0.8,
	"heal": 0.0, "fortune": 20.0, "cleanse": 0.0, "dig": 0.0,
}


static func upgrade(payload: Dictionary, target: int = CURRENT_VERSION, steps: Dictionary = STEPS) -> Dictionary:
	var version: Variant = payload.get("schema_version")
	if not version is float and not version is int:
		return {"ok": false, "error": "Missing save schema version."}
	if not is_finite(float(version)) or float(version) != floorf(float(version)) or version < 1 or version > target:
		return {"ok": false, "error": "This save needs a different game version."}
	var upgraded := payload.duplicate(true)
	for source: int in range(int(version), target):
		var result: Variant
		if steps.is_empty() and source == 1:
			result = _version_one_to_two(upgraded)
		elif steps.is_empty() and source == 2:
			result = _version_two_to_three(upgraded)
		elif steps.is_empty() and source == 3:
			result = _version_three_to_four(upgraded)
		elif steps.is_empty() and source == 4:
			result = _version_four_to_five(upgraded)
		elif steps.is_empty() and source == 5:
			result = _version_five_to_six(upgraded)
		elif steps.is_empty() and source == 6:
			result = _version_six_to_seven(upgraded)
		elif steps.is_empty() and source == 7:
			result = _version_seven_to_eight(upgraded)
		elif steps.is_empty() and source == 8:
			result = _version_eight_to_nine(upgraded)
		elif steps.is_empty() and source == 9:
			result = _version_nine_to_ten(upgraded)
		elif steps.is_empty() and source == 10:
			result = _version_ten_to_eleven(upgraded)
		elif steps.has(source) and steps[source] is Callable:
			result = steps[source].call(upgraded)
		else:
			return {"ok": false, "error": "No migration exists for this older save. You can remove its slot."}
		if not result is Dictionary or result.get("schema_version") != source + 1:
			return {"ok": false, "error": "Save migration failed; the original is preserved."}
		upgraded = result
	if steps.is_empty() and int(version) < target:
		# Validate every retained field against the current contract. For callers
		# requesting historical boundaries, validate a disposable current candidate.
		var candidate: Dictionary = _version_two_to_three(upgraded) if target == 2 else upgraded
		if candidate.get("schema_version") == 3:
			candidate = _version_three_to_four(candidate)
		if candidate.get("schema_version") == 4:
			candidate = _version_four_to_five(candidate)
		if candidate.get("schema_version") == 5:
			candidate = _version_five_to_six(candidate)
		if candidate.get("schema_version") == 6:
			candidate = _version_six_to_seven(candidate)
		if candidate.get("schema_version") == 7:
			candidate = _version_seven_to_eight(candidate)
		if candidate.get("schema_version") == 8:
			candidate = _version_eight_to_nine(candidate)
		if candidate.get("schema_version") == 9:
			candidate = _version_nine_to_ten(candidate)
		if candidate.get("schema_version") == 10:
			candidate = _version_ten_to_eleven(candidate)
		if not ArenicSaveCodec.validate(candidate).is_empty():
			return {"ok": false, "error": "Save migration failed validation; the original is preserved."}
	return {"ok": true, "payload": upgraded}


static func _version_one_to_two(payload: Dictionary) -> Dictionary:
	if payload.get("schema_version") != 1 or not payload.get("run") is Dictionary or payload.run.has("intro_step"):
		return {}
	var candidate := payload.duplicate(true)
	candidate.schema_version = 2
	# Legacy guilds, including an older unfinished class selection, existed before
	# the prologue contract. Never trap their continuing run behind new dialogue.
	candidate.run.intro_step = ArenicSaveCodec.INTRO_COMPLETE
	return candidate


static func _version_four_to_five(payload: Dictionary) -> Dictionary:
	if payload.get("schema_version") != 4 or not payload.get("run") is Dictionary or not payload.run.get("combat") is Dictionary:
		return {}
	if payload.run.combat.has("enemy_dots"):
		return {} # A released v4 record cannot already carry a future field.
	var candidate := payload.duplicate(true)
	candidate.schema_version = 5
	if not candidate.run.combat.is_empty():
		# Never replay a historical Cleanse or infer a stack from old damage.
		candidate.run.combat.enemy_dots = []
	return candidate


static func _version_two_to_three(payload: Dictionary) -> Dictionary:
	if payload.get("schema_version") != 2 or not payload.get("world") is Dictionary:
		return {}
	var candidate := payload.duplicate(true)
	candidate.schema_version = 3
	if candidate.world.is_empty():
		return candidate
	var arenas: Variant = candidate.world.get("arenas")
	if not arenas is Dictionary or arenas.size() > ArenicSaveCodec.WORLD.arenas.size():
		return {}
	for arena: Variant in arenas.values():
		if not arena is Dictionary or not arena.get("ground") is Dictionary:
			return {}
		var dug: Variant = arena.ground.get("dug")
		var pools: Variant = arena.get("pools")
		if not dug is Array or dug.size() > ArenicDigField.CELLS or not pools is Array or pools.size() > ArenicSaveCodec.MAX_POOLS:
			return {}
		for tile: Variant in dug:
			if not tile is Array or tile.size() != 2:
				return {}
			# The released ground format knew only a tile and its overlap debt.
			tile.append("")
		for pool: Variant in pools:
			if not pool is Dictionary or pool.has("caster_id"):
				return {}
			pool.caster_id = ""
	# Keep all other fields, including unexpected ones: the final whole-model
	# validation must reject malformed old records instead of sanitizing them.
	return candidate


static func _version_three_to_four(payload: Dictionary) -> Dictionary:
	if payload.get("schema_version") != 3 or not payload.get("run") is Dictionary:
		return {}
	var candidate := payload.duplicate(true)
	candidate.schema_version = 4
	var run: Dictionary = candidate.run
	if not run.get("combat") is Dictionary or not run.get("heroes") is Array or run.heroes.size() > ArenicSaveCodec.MAX_HEROES:
		return {}
	if run.combat.is_empty():
		return candidate
	var casts: Variant = run.combat.get("casts")
	if not casts is Dictionary or casts.size() > ArenicSaveCodec.MAX_HEROES:
		return {}
	var definitions: Dictionary = {}
	for hero: Variant in run.heroes:
		if not hero is Dictionary or not hero.get("class_id") is String or not ArenicSaveDocument._integer(hero.get("identity"), 0, ArenicSaveCodec.MAX_HEROES - 1):
			return {}
		var definition: ArenicClassDefinition = ArenicSaveCodec._class_for(hero.class_id)
		var key: String = ArenicCombatState.hero_ally_id(int(hero.identity))
		if definition == null or definitions.has(key):
			return {}
		definitions[key] = definition
	for caster: Variant in casts:
		var cast: Variant = casts[caster]
		if not caster is String or not definitions.has(caster) or not cast is Dictionary or cast.has("resolve_seconds") or not cast.get("ability_id") is String:
			return {}
		var ability: ArenicClassAbility = ArenicSaveCodec._ability_for(definitions[caster], cast.ability_id)
		if ability == null or not V3_RESOLVE_SECONDS.has(cast.ability_id):
			return {}
		# Catalog lookup validates identity only; released timing is immutable.
		cast.resolve_seconds = V3_RESOLVE_SECONDS[cast.ability_id]
	return candidate


static func _version_five_to_six(payload: Dictionary) -> Dictionary:
	if payload.get("schema_version") != 5 or not payload.get("run") is Dictionary or payload.run.has("gathering"):
		return {}
	var candidate := payload.duplicate(true)
	candidate.schema_version = 6
	candidate.run.gathering = {"wood_total": "0", "gold_total": "0", "bags": []}
	# Old recruits shared one spawn tile. Separate those existing bodies without
	# awarding resources, killing heroes on load, or rewriting their recordings.
	if not candidate.run.get("heroes") is Array or candidate.run.heroes.size() > ArenicSaveCodec.MAX_HEROES or not candidate.run.get("combat") is Dictionary:
		return {}
	var ordered: Dictionary = {}
	for hero: Variant in candidate.run.heroes:
		if not hero is Dictionary or not _legacy_integer(hero.get("identity"), 0, 319) or ordered.has(int(hero.identity)) or not hero.get("arena_id") is String or ArenicSaveCodec.WORLD.index_for_id(hero.arena_id) < 0:
			return {}
		if not hero.get("cell") is Array or hero.cell.size() != 2 or not _legacy_integer(hero.cell[0], 0, 65) or not _legacy_integer(hero.cell[1], 0, 30):
			return {}
		ordered[int(hero.identity)] = hero
	var ids: Array = ordered.keys()
	ids.sort()
	var occupied: Dictionary = {}
	for identity: int in ids:
		var hero: Dictionary = ordered[identity]
		var actor: String = ArenicCombatState.hero_ally_id(identity)
		var arenas: Variant = candidate.run.combat.get("arenas", {})
		if not arenas is Dictionary:
			return {}
		var ledger: Variant = arenas.get(hero.arena_id, {})
		if not ledger is Dictionary or not ledger.get("allies", {}) is Dictionary:
			return {}
		var ally: Variant = ledger.get("allies", {}).get(actor, {})
		if not ally is Dictionary:
			return {}
		if not ally.is_empty():
			# Separation may update a valid shared position, but must not repair
			# malformed or contradictory legacy data before validation sees it.
			var original_cell: Variant = ally.get("cell")
			if not original_cell is Array or original_cell.size() != 2 or not _legacy_integer(original_cell[0], 0, 65) or not _legacy_integer(original_cell[1], 0, 30):
				return {}
			if int(original_cell[0]) != int(hero.cell[0]) or int(original_cell[1]) != int(hero.cell[1]):
				return {}
		if not ally.is_empty() and ally.get("health") == "0":
			continue # Ghost smoke is not a body.
		if not occupied.has(hero.arena_id):
			occupied[hero.arena_id] = {}
		var cell := Vector2i(int(hero.cell[0]), int(hero.cell[1]))
		if occupied[hero.arena_id].has(cell):
			var blocked: Array[Rect2i] = ArenicHeroPlacement.obstacles(hero.arena_id)
			cell = ArenicHeroPlacement.nearest_free(cell, occupied[hero.arena_id], blocked)
			if cell == ArenicHeroPlacement.NONE:
				return {}
			hero.cell = [cell.x, cell.y]
			if not ally.is_empty():
				ally.cell = hero.cell.duplicate()
		occupied[hero.arena_id][cell] = true
	return candidate


static func _legacy_integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= minimum and value <= maximum


static func _version_six_to_seven(payload: Dictionary) -> Dictionary:
	if payload.get("schema_version") != 6 or not payload.get("world") is Dictionary:
		return {}
	var candidate := payload.duplicate(true)
	candidate.schema_version = 7
	if candidate.world.is_empty():
		return candidate
	var arenas: Variant = candidate.world.get("arenas")
	if not arenas is Dictionary or arenas.size() > ArenicSaveCodec.WORLD.arenas.size():
		return {}
	for arena: Variant in arenas.values():
		if not arena is Dictionary or arena.has("restart_pending"):
			return {}
		# A historical tick zero does not imply a replay or countdown was pending.
		arena.restart_pending = false
	return candidate


static func _version_seven_to_eight(payload: Dictionary) -> Dictionary:
	if payload.get("schema_version") != 7:
		return {}
	var candidate := payload.duplicate(true)
	# New decision actions change semantics, not payload shape. Never fabricate a death.
	candidate.schema_version = 8
	return candidate


static func _version_eight_to_nine(payload: Dictionary) -> Dictionary:
	if payload.get("schema_version") != 8:
		return {}
	var candidate := payload.duplicate(true)
	# Retain and validate the entire old record. Hydration derives music from
	# cycle ticks and clears selection outside the viewed arena. No game tick,
	# recording, hero identity or arena memory is rewritten.
	candidate.schema_version = 9
	return candidate


static func _version_nine_to_ten(payload: Dictionary) -> Dictionary:
	if payload.get("schema_version") != 9 or not payload.get("run") is Dictionary or not payload.run.get("combat") is Dictionary or payload.run.combat.has("encounter"):
		return {}
	var candidate := payload.duplicate(true)
	candidate.schema_version = 10
	if not candidate.run.combat.is_empty():
		candidate.run.combat.encounter = {"ruleset": ArenicActorEffects.LEGACY, "fingerprint": ArenicActorEffects.LEGACY, "actors": {}}
	return candidate


static func _version_ten_to_eleven(payload: Dictionary) -> Dictionary:
	if payload.get("schema_version") != 10 or not payload.get("run") is Dictionary or payload.run.has("loot") or not payload.run.get("combat") is Dictionary or not payload.get("world") is Dictionary:
		return {}
	var candidate := payload.duplicate(true)
	var loot := ArenicLootState.new()
	var ledgers: Variant = candidate.run.combat.get("arenas", {})
	var arenas: Variant = candidate.world.get("arenas", {})
	if not ledgers is Dictionary or not arenas is Dictionary:
		return {}
	for identity: String in ArenicLootState.ARENAS:
		var ledger: Variant = ledgers.get(identity, {})
		var arena: Variant = arenas.get(identity, {})
		if not ledger is Dictionary or not arena is Dictionary or not arena.get("ground", {}) is Dictionary:
			return {}
		var damage: Variant = ledger.get("damage", "0")
		var cycle: Variant = arena.get("ground", {}).get("cycle", "0")
		var validator := ArenicSaveCodec.Validator.new()
		if not validator.decimal(damage) or not validator.decimal(cycle):
			return {}
		# Never turn historic damage or an old partial loop into a reward on load.
		loot.reset_cycle(identity, int(damage), int(cycle))
	candidate.run.loot = loot.snapshot()
	candidate.schema_version = 11
	return candidate
