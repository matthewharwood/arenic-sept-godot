class_name ArenicAcidField
extends RefCounted
## One arena's pools of acid.
##
## A pool is ground the caster left behind: it burns whatever stands in it, once
## a second, until it dries up. It belongs to the arena's cycle rather than to
## the caster, so a pool outlives the flask that made it and dies with the cycle
## that saw it thrown — which is what lets a recorded Alchemist lay the same
## ground on the same tick, every loop.

class Pool:
	extends RefCounted
	var area: Rect2i
	var ticks_left: int = 0
	var span: int = 1
	var tick_ticks: int = 60
	var debt: int = 0
	var damage: int = 1

	func strength() -> float:
		return clampf(float(ticks_left) / float(maxi(1, span)), 0.0, 1.0)

var arena_id: String = ""
var _pools: Array[Pool] = []


func configure(owner_arena: String) -> void:
	arena_id = owner_arena
	_pools.clear()


func clear() -> void:
	_pools.clear()


func count() -> int:
	return _pools.size()


## Lays a pool. Re-throwing into the same ground adds a second pool rather than
## refreshing the first: two flasks burn twice as fast, which is the honest
## reading of two flasks.
func spawn(area: Rect2i, rules: ArenicClassAbility) -> void:
	if rules == null or area.size.x <= 0 or area.size.y <= 0:
		return
	var pool := Pool.new()
	pool.area = area
	pool.span = maxi(1, ArenicCycleClock.seconds_to_ticks(rules.duration_seconds))
	pool.ticks_left = pool.span
	pool.tick_ticks = maxi(1, ArenicCycleClock.seconds_to_ticks(rules.tick_seconds))
	pool.damage = maxi(1, rules.damage)
	_pools.append(pool)


## Advances one tick and returns `[area, damage]` for every pool that came due.
## The field says WHEN and WHERE, never who: acid does not care whose boots are
## in it, so the caller applies each burn to everything standing there. Pools
## that dry up this tick are removed.
func advance() -> Array:
	var due: Array = []
	if _pools.is_empty():
		return due
	for index: int in range(_pools.size() - 1, -1, -1):
		var pool: Pool = _pools[index]
		pool.ticks_left -= 1
		pool.debt += 1
		while pool.debt >= pool.tick_ticks:
			pool.debt -= pool.tick_ticks
			due.append([pool.area, pool.damage])
		if pool.ticks_left <= 0:
			_pools.remove_at(index)
	return due


## Cells currently under acid, with how much life each pool has left, for the
## floor overlay. Overlapping pools report their strongest cover.
func overlay() -> Dictionary:
	var strength: Dictionary[int, float] = {}
	for pool: Pool in _pools:
		var life: float = pool.strength()
		for x: int in pool.area.size.x:
			for y: int in pool.area.size.y:
				var cell := pool.area.position + Vector2i(x, y)
				if not ArenicGridMath.tile_valid(cell):
					continue
				var index: int = ArenicDigField.index_of(cell)
				strength[index] = maxf(float(strength.get(index, 0.0)), life)
	var cells := PackedInt32Array()
	var lives := PackedFloat32Array()
	var keys: Array = strength.keys()
	keys.sort()
	for index: int in keys:
		cells.append(index)
		lives.append(float(strength[index]))
	return {"cells": cells, "strengths": lives}
