class_name ArenicGatheringState
extends RefCounted
## Authoritative bags and banked resources. The caller owns the Guild House clock.

const ARENA_ID: String = "guild_house"
const TICKS_PER_SECOND: int = 60
const MAX_HEROES: int = 320
const MAX_TOTAL: int = 9223372036854775807
const MAX_FILL_TICKS: int = 7200
const MAX_UNLOAD_TICKS: int = 600
const MAX_CAPACITY: int = 1000

class Bag:
	extends RefCounted
	var kind: String = ""
	var fill_ticks: int = 0
	var fill_duration_ticks: int = 300
	var unload_ticks: int = 0
	var unload_duration_ticks: int = 60
	var capacity_units: int = 10

var definition: ArenicGatheringDefinition
var wood_total: int = 0
var gold_total: int = 0
var _bags: Dictionary[int, Bag] = {}


## Invalid authoring leaves the last valid configuration and all progress intact.
## Rules freeze per bag; a valid reconfigure updates sites and future bags only.
func configure(authored: ArenicGatheringDefinition) -> bool:
	if authored == null or not authored.validation_errors().is_empty():
		return false
	definition = authored.duplicate(true) as ArenicGatheringDefinition
	return true


## Exactly one unpaused Guild House tick, after movement and contact deaths.
## Duplicate identities and oversized batches fail closed before any work. Stable
## identity order also makes simultaneous deposits deterministic at bank capacity.
func advance(heroes: Array[ArenicHeroState], combat: ArenicCombatState) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if definition == null or combat == null or heroes.size() > MAX_HEROES:
		return events
	var ordered: Dictionary[int, ArenicHeroState] = {}
	for hero: ArenicHeroState in heroes:
		if not _valid_hero(hero) or ordered.has(hero.identity_id):
			return events
		ordered[hero.identity_id] = hero
	var identities: Array = ordered.keys()
	identities.sort()
	for identity: int in identities:
		var hero: ArenicHeroState = ordered[identity]
		if combat.ally_defeated_at(hero.arena_id, hero.ally_id()):
			clear_hero(identity)
			continue
		var bag: Bag = _bags.get(identity)
		if hero.arena_id != ARENA_ID:
			if bag != null:
				bag.unload_ticks = 0
			continue
		if bag == null:
			var resource: String = definition.source_kind_at(hero.cell)
			if resource.is_empty():
				continue
			bag = Bag.new()
			bag.kind = resource
			bag.fill_duration_ticks = roundi(definition.fill_seconds * TICKS_PER_SECOND)
			bag.unload_duration_ticks = roundi(definition.unload_seconds * TICKS_PER_SECOND)
			bag.capacity_units = definition.capacity_units
			_bags[identity] = bag
		if bag.fill_ticks < bag.fill_duration_ticks:
			if not definition.source_kind_at(hero.cell, bag.kind).is_empty():
				bag.fill_ticks += 1
			continue
		if not definition.at_dropoff(hero.cell, bag.kind):
			bag.unload_ticks = 0
			continue
		bag.unload_ticks += 1
		if bag.unload_ticks < bag.unload_duration_ticks:
			continue
		var total: int = wood_total if bag.kind == "wood" else gold_total
		var accepted: int = mini(bag.capacity_units, MAX_TOTAL - total)
		if bag.kind == "wood":
			wood_total += accepted
		else:
			gold_total += accepted
		_bags.erase(identity)
		if accepted > 0:
			events.append({"kind": "deposited", "hero_id": identity, "resource": bag.kind, "amount": accepted})
	return events


func clear_hero(identity: int) -> void:
	_bags.erase(identity)


## Only participating Guild House bags restart; the bank and remote bags remain.
func restart(heroes: Array[ArenicHeroState]) -> void:
	if heroes.size() > MAX_HEROES:
		return
	for hero: ArenicHeroState in heroes:
		if _valid_hero(hero) and hero.arena_id == ARENA_ID:
			clear_hero(hero.identity_id)


## Read-only presentation: progress is local to the derived phase. Partial bag
## amounts are display-only until a full bag completes its matching dropoff.
func snapshot_for(hero: ArenicHeroState) -> Dictionary:
	if not _valid_hero(hero) or definition == null:
		return {}
	var bag: Bag = _bags.get(hero.identity_id)
	if bag == null:
		return {"kind": "", "fill_ticks": 0, "fill_duration_ticks": roundi(definition.fill_seconds * TICKS_PER_SECOND),
			"unload_ticks": 0, "unload_duration_ticks": roundi(definition.unload_seconds * TICKS_PER_SECOND),
			"capacity_units": definition.capacity_units, "phase": "idle", "progress": 0.0, "amount": 0,
			"source_id": "", "dropoff_id": ""}
	var full: bool = bag.fill_ticks == bag.fill_duration_ticks
	var phase: String = "full" if full else "carrying"
	if hero.arena_id == ARENA_ID:
		if full and definition.at_dropoff(hero.cell, bag.kind):
			phase = "unloading"
		elif not full and not definition.source_kind_at(hero.cell, bag.kind).is_empty():
			phase = "gathering"
	@warning_ignore("integer_division")
	var amount: int = bag.fill_ticks * bag.capacity_units / bag.fill_duration_ticks
	return {"kind": bag.kind, "fill_ticks": bag.fill_ticks, "fill_duration_ticks": bag.fill_duration_ticks,
		"unload_ticks": bag.unload_ticks, "unload_duration_ticks": bag.unload_duration_ticks,
		"capacity_units": bag.capacity_units, "phase": phase,
		"progress": float(bag.unload_ticks) / bag.unload_duration_ticks if phase == "unloading" else float(bag.fill_ticks) / bag.fill_duration_ticks,
		"amount": amount,
		"source_id": definition.source_at(hero.cell, bag.kind).get("id", "") if phase == "gathering" else "",
		"dropoff_id": bag.kind + "_dropoff" if phase == "unloading" else ""}


static func _valid_hero(hero: ArenicHeroState) -> bool:
	return hero != null and hero.identity_id >= 0 and hero.identity_id < MAX_HEROES and ArenicGridMath.tile_valid(hero.cell)
