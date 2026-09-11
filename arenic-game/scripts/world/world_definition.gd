class_name ArenicWorldDefinition
extends Resource
## Ordered arena data. Valid definitions contain each of the nine grid slots once.

const GUILD_HOUSE_INDEX: int = 1

@export var arenas: Array[ArenicArenaDefinition] = []


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	if arenas.size() != ArenicGridMath.ARENA_COUNT:
		errors.append("Expected exactly 9 arenas; found %d." % arenas.size())
	var seen_ids: Dictionary = {}
	var seen_hotkeys: Dictionary = {}
	var seen_slots: Dictionary = {}
	for index in range(arenas.size()):
		var arena: ArenicArenaDefinition = arenas[index]
		if arena == null:
			errors.append("Arena %d is null." % index)
			continue
		var id: String = arena.arena_id.strip_edges()
		if id.is_empty():
			errors.append("Arena %d needs an arena_id." % index)
		elif seen_ids.has(id):
			errors.append("Arena %d duplicates arena_id '%s'." % [index, id])
		seen_ids[id] = true
		var key: String = arena.hotkey.strip_edges().to_upper()
		if key.is_empty():
			errors.append("Arena %d needs a hotkey." % index)
		elif seen_hotkeys.has(key):
			errors.append("Arena %d duplicates hotkey '%s'." % [index, key])
		seen_hotkeys[key] = true
		if not ArenicGridMath.slot_valid(arena.grid_slot):
			errors.append("Arena %d has invalid grid_slot %s." % [index, arena.grid_slot])
		if seen_slots.has(arena.grid_slot):
			errors.append("Arena %d duplicates grid_slot %s." % [index, arena.grid_slot])
		seen_slots[arena.grid_slot] = true
		if arena.phase_damage < 1:
			errors.append("Arena %d needs a positive damage threshold." % index)
		if arena.boss != null or arena.training_target_frames != null:
			if arena.boss_combat_size.x < 1 or arena.boss_combat_size.y < 1 or not ArenicGridMath.tile_valid(arena.boss_origin_cell) or not ArenicGridMath.tile_valid(arena.boss_origin_cell + arena.boss_combat_size - Vector2i.ONE):
				errors.append("Arena %d has an invalid boss combat footprint." % index)
			if arena.boss_facing not in ["n", "e", "s", "w"]:
				errors.append("Arena %d has an invalid boss facing." % index)
	return errors


func index_for_class(class_id: String) -> int:
	for index in range(arenas.size()):
		var arena: ArenicArenaDefinition = arenas[index]
		if arena != null and arena.class_id == class_id:
			return index
	return GUILD_HOUSE_INDEX


func index_for_slot(slot: Vector2i) -> int:
	for index in range(arenas.size()):
		var arena: ArenicArenaDefinition = arenas[index]
		if arena != null and arena.grid_slot == slot:
			return index
	return -1


func index_for_id(id: String) -> int:
	for index in range(arenas.size()):
		var arena: ArenicArenaDefinition = arenas[index]
		if arena != null and arena.arena_id == id:
			return index
	return -1
