class_name ArenicHeroPlacement
extends RefCounted
## Deterministic, bounded placement for arrivals and legacy overlap migration.
const WORLD: ArenicWorldDefinition = preload("res://data/world/arenia.tres")
const KEEPER: ArenicNpcDefinition = preload("res://data/npcs/keeper.tres")
const NONE := Vector2i(-1, -1)


static func nearest_free(preferred: Vector2i, occupied: Dictionary, blocked: Array[Rect2i] = []) -> Vector2i:
	if not ArenicGridMath.tile_valid(preferred):
		return NONE
	for radius: int in maxi(ArenicGridMath.GRID_WIDTH, ArenicGridMath.GRID_HEIGHT):
		for y: int in range(preferred.y - radius, preferred.y + radius + 1):
			for x: int in range(preferred.x - radius, preferred.x + radius + 1):
				if maxi(absi(x - preferred.x), absi(y - preferred.y)) != radius:
					continue
				var cell := Vector2i(x, y)
				if not ArenicGridMath.tile_valid(cell) or occupied.has(cell):
					continue
				var obstructed: bool = false
				for area: Rect2i in blocked:
					if area.has_point(cell):
						obstructed = true
						break
				if not obstructed:
					return cell
	return NONE


static func for_hero(arena_id: String, preferred: Vector2i, roster: Array, combat: ArenicCombatState = null, exclude: int = -1) -> Vector2i:
	var occupied: Dictionary = {}
	for hero: ArenicHeroState in roster:
		if hero.identity_id == exclude or hero.arena_id != arena_id:
			continue
		if combat != null and combat.ally_defeated_at(arena_id, hero.ally_id()):
			continue # A fallen ghost is smoke, without a physical body.
		occupied[hero.cell] = true
	return nearest_free(preferred, occupied, obstacles(arena_id, combat))


static func obstacles(arena_id: String, combat: ArenicCombatState = null) -> Array[Rect2i]:
	var result: Array[Rect2i] = []
	if arena_id == "guild_house":
		result.append(Rect2i(KEEPER.cell, Vector2i.ONE))
	if combat != null and combat._arenas.has(arena_id):
		for enemy_id: String in combat._enemy_ids(arena_id):
			var footprint: Rect2i = combat.enemy_footprint(arena_id, enemy_id)
			if footprint.has_area():
				result.append(footprint)
	else:
		var index: int = WORLD.index_for_id(arena_id)
		if index >= 0:
			var arena: ArenicArenaDefinition = WORLD.arenas[index]
			if arena.boss != null or arena.training_target_frames != null:
				result.append(Rect2i(arena.boss_origin_cell, arena.boss_combat_size))
	return result
