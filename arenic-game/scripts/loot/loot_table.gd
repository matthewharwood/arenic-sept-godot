@tool
class_name ArenicLootTable
extends Resource
## A reward revision owns its item identities and probability rows forever.
## Publish a new revision when changing a released draw; old pending rewards keep v1.
@export var revision: String = "loot-v1"
@export var items: Array[Dictionary] = []
## Rows: weights, minimum damage, minimum hero-ticks, minimum full-deployment ticks.
@export var bands: Array[Dictionary] = []

const RARITIES: Array[String] = ["Common", "Magic", "Rare", "Epic", "Legendary", "Mythic"]
const SLOTS: Array[String] = ["Weapon", "Armor", "Accessory"]

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if revision != "loot-v1" or items.size() != 100 or bands.size() != 6:
		errors.append("Loot v1 requires exactly 100 items and six quality bands.")
	var identities: Dictionary = {}
	var rarity_counts: Array[int] = [0, 0, 0, 0, 0, 0]
	for item: Dictionary in items:
		if item.size() != 6 or not item.get("id") is String or not item.get("name") is String or item.get("slot") not in SLOTS or item.get("rarity") not in RARITIES or not item.get("power") is int or not item.get("description") is String:
			errors.append("Loot items need a stable identity, name, slot, rarity, power and description.")
			continue
		if item.id.is_empty() or identities.has(item.id) or item.name.is_empty() or item.power < 1:
			errors.append("Loot item identity or power is invalid.")
		identities[item.id] = true
		rarity_counts[RARITIES.find(item.rarity)] += 1
	for count: int in rarity_counts:
		if count < 3:
			errors.append("Every rarity needs at least three distinct items.")
	for band: Dictionary in bands:
		if band.size() != 4 or not band.get("weights") is Array or band.weights.size() != 6:
			errors.append("Loot bands require six integer weights and three progression gates.")
			continue
		var total: int = 0
		for weight: Variant in band.weights:
			if not weight is int or weight < 0:
				errors.append("Loot rarity weights must be nonnegative integers.")
			else:
				total += weight
		if total != 10000:
			errors.append("Loot rarity weights must total 10000.")
		for key: String in ["damage", "hero_ticks", "full_ticks"]:
			if not band.get(key) is int or band[key] < 0:
				errors.append("Loot progression gates must be nonnegative integers.")
	return errors

func item_for(identity: String) -> Dictionary:
	for item: Dictionary in items:
		if item.id == identity:
			return item.duplicate(true)
	return {}

func _get_validation_conditions() -> Array:
	return ArenicDoctorConditions.from_errors(validation_errors())
