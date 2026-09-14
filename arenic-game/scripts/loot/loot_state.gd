class_name ArenicLootState
extends RefCounted
## Earned equipment is independent of transient card animation and arena pauses.
## Fixed buckets bound storage even when unattended loops bank years of rewards.
const TABLE: ArenicLootTable = preload("res://data/loot/catalog_v1.tres")
const ARENAS: Array[String] = ["labyrinth", "sanctum", "mountain", "bastion", "pawnshop", "crucible", "casino", "gala"]
const BAND_COUNT: int = 6
const MAX_COUNTER: int = 9223372036854775807
const MAX_REWARDS: int = 1000000000000
const MAX_CYCLE_WORK: int = 7200 * 320
var completed_damage: int = 0
var completed_hero_ticks: int = 0
var completed_full_ticks: int = 0
var completed_cycles: int = 0
var _arenas: Dictionary = {}
var _inventory: Dictionary = {}

func _init() -> void:
	for arena: String in ARENAS:
		_arenas[arena] = {"baseline": 0, "cycle": 0, "hero_ticks": 0, "full_ticks": 0,
			"full_deployment": false, "earned": [0, 0, 0, 0, 0, 0], "claimed": [0, 0, 0, 0, 0, 0]}

## Called only for actual unpaused simulation ticks, after damage resolves.
## Work in an abandoned/manual-reset cycle never becomes progression.
func observe_cycle_progress(arena_id: String, total_damage: int, participating_heroes: int, full_deployment: bool, ticks: int = 1) -> void:
	if not _arenas.has(arena_id) or ticks < 1 or ticks > 7200 or participating_heroes < 0 or participating_heroes > 320:
		return
	var arena: Dictionary = _arenas[arena_id]
	if total_damage < arena.baseline:
		push_error("Loot damage cannot move behind its cycle baseline.")
		return
	var work: int = participating_heroes * ticks
	if arena.hero_ticks > MAX_CYCLE_WORK - work:
		push_error("Loot cycle work exceeded the bounded two-minute cycle.")
		return
	arena.hero_ticks += work
	arena.full_deployment = full_deployment
	if full_deployment:
		arena.full_ticks += work

## Incoming cycle serial is the ground cycle + 1, before the canonical reset.
## The serial makes duplicate natural-boundary delivery harmless.
func complete_cycle(arena_id: String, total_damage: int, cycle_serial: int) -> Dictionary:
	if not _arenas.has(arena_id):
		return {}
	var arena: Dictionary = _arenas[arena_id]
	if cycle_serial <= arena.cycle or total_damage < arena.baseline:
		return {}
	var damage: int = total_damage - int(arena.baseline)
	var work: int = int(arena.hero_ticks)
	var full_work: int = int(arena.full_ticks)
	var full: bool = arena.full_deployment
	if damage > 0 and work > 0:
		if completed_cycles >= MAX_REWARDS or completed_damage > MAX_COUNTER - damage or completed_hero_ticks > MAX_COUNTER - work or completed_full_ticks > MAX_COUNTER - full_work:
			push_error("Loot progression reached its explicit saved counter bound.")
			return {}
		completed_damage += damage
		completed_hero_ticks += work
		completed_full_ticks += full_work
		completed_cycles += 1
		var band: int = quality_band(full)
		arena.earned[band] += 1
		reset_cycle(arena_id, total_damage, cycle_serial)
		return {"arena_id": arena_id, "band": band, "damage": damage, "pending": pending_count()}
	reset_cycle(arena_id, total_damage, cycle_serial)
	return {}

## Reset/commit/re-record routes call this without complete_cycle: no reward.
func reset_cycle(arena_id: String, total_damage: int, cycle_serial: int) -> void:
	if not _arenas.has(arena_id) or total_damage < 0 or cycle_serial < 0:
		return
	var arena: Dictionary = _arenas[arena_id]
	arena.baseline = total_damage
	arena.cycle = cycle_serial
	arena.hero_ticks = 0
	arena.full_ticks = 0
	arena.full_deployment = false

func quality_band(full_deployment: bool = false) -> int:
	var result: int = 0
	for index: int in TABLE.bands.size():
		var band: Dictionary = TABLE.bands[index]
		if completed_damage < band.damage or completed_hero_ticks < band.hero_ticks or completed_full_ticks < band.full_ticks:
			continue
		if band.full_ticks > 0 and not full_deployment:
			continue # The best tier still requires every arena staffed at this finish.
		result = index
	return result

func pending_count() -> int:
	return completed_cycles - claimed_count()

func claimed_count() -> int:
	var count: int = 0
	for arena: Dictionary in _arenas.values():
		for value: int in arena.claimed:
			count += value
	return count

## Three concealed outcomes from a frozen earned band. An arena preference only
## selects a bank; it never changes the candidates of any existing reward token.
func peek(seed: int, preferred_arena: String = "") -> Dictionary:
	var order: Array[String] = ARENAS.duplicate()
	if preferred_arena in order:
		order.erase(preferred_arena)
		order.push_front(preferred_arena)
	for arena_id: String in order:
		var arena: Dictionary = _arenas[arena_id]
		for band: int in BAND_COUNT:
			if arena.earned[band] > arena.claimed[band]:
				var token: String = "%s:%s:%d:%d" % [TABLE.revision, arena_id, band, arena.claimed[band]]
				return {"token": token, "arena_id": arena_id, "band": band, "cards": _draw(token, band, seed)}
	return {}

func claim(token: String, index: int, seed: int) -> Dictionary:
	if index < 0 or index > 2:
		return {}
	var parts: PackedStringArray = token.split(":")
	if parts.size() != 4 or parts[0] != TABLE.revision or not _arenas.has(parts[1]) or not parts[2].is_valid_int() or not parts[3].is_valid_int():
		return {}
	var band: int = parts[2].to_int()
	var ordinal: int = parts[3].to_int()
	if band < 0 or band >= BAND_COUNT or ordinal < 0 or str(band) != parts[2] or str(ordinal) != parts[3]:
		return {}
	var arena: Dictionary = _arenas[parts[1]]
	if arena.claimed[band] != ordinal or arena.earned[band] <= ordinal:
		return {}
	var item: Dictionary = _draw(token, band, seed)[index]
	arena.claimed[band] += 1
	_inventory[item.id] = int(_inventory.get(item.id, 0)) + 1
	return item

func _draw(token: String, band: int, seed: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var weights: Array = TABLE.bands[band].weights
	for index: int in 3:
		# SHA-256 text input is stable across engine/target RNG implementations.
		var key: String = "%d|%s|%d" % [seed, token, index]
		var roll: int = _number(key + "|rarity") % 10000
		var rarity: int = 0
		while rarity < weights.size() - 1 and roll >= int(weights[rarity]):
			roll -= int(weights[rarity])
			rarity += 1
		var available: Array[Dictionary] = []
		for item: Dictionary in TABLE.items:
			if item.rarity == ArenicLootTable.RARITIES[rarity] and not result.any(func(chosen: Dictionary) -> bool: return chosen.id == item.id):
				available.append(item)
		result.append(available[_number(key + "|item") % available.size()].duplicate(true))
	return result

static func _number(text: String) -> int:
	# Fifteen hex digits fit signed64 on native and Web; no JSON floating math.
	return text.sha256_text().substr(0, 15).hex_to_int()

func inventory_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for item: Dictionary in TABLE.items:
		if _inventory.has(item.id):
			var row: Dictionary = item.duplicate(true)
			row.count = _inventory[item.id]
			rows.append(row)
	return rows

func snapshot() -> Dictionary:
	var arenas: Dictionary = {}
	for identity: String in ARENAS:
		var arena: Dictionary = _arenas[identity]
		var saved: Dictionary = {}
		for key: String in ["baseline", "cycle", "hero_ticks", "full_ticks"]:
			saved[key] = str(arena[key])
		saved.full_deployment = arena.full_deployment
		for key: String in ["earned", "claimed"]:
			saved[key] = []
			for value: int in arena[key]:
				saved[key].append(str(value))
		arenas[identity] = saved
	var inventory: Dictionary = {}
	for identity: String in _inventory:
		inventory[identity] = str(_inventory[identity])
	return {"revision": TABLE.revision, "damage": str(completed_damage), "hero_ticks": str(completed_hero_ticks),
		"full_ticks": str(completed_full_ticks), "cycles": str(completed_cycles), "arenas": arenas, "inventory": inventory}

## Codec validates the complete candidate before this method mutates live state.
func restore(data: Dictionary) -> void:
	completed_damage = int(data.damage)
	completed_hero_ticks = int(data.hero_ticks)
	completed_full_ticks = int(data.full_ticks)
	completed_cycles = int(data.cycles)
	_inventory.clear()
	for identity: String in data.inventory:
		_inventory[identity] = int(data.inventory[identity])
	for identity: String in ARENAS:
		var saved: Dictionary = data.arenas[identity]
		var arena: Dictionary = _arenas[identity]
		for key: String in ["baseline", "cycle", "hero_ticks", "full_ticks"]:
			arena[key] = int(saved[key])
		arena.full_deployment = saved.full_deployment
		for key: String in ["earned", "claimed"]:
			for index: int in BAND_COUNT:
				arena[key][index] = int(saved[key][index])
