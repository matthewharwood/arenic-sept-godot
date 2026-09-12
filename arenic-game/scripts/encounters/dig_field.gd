class_name ArenicDigField
extends RefCounted
## One arena's diggable ground for one cycle.
##
## Every tile is worth 1-3 toward the next hero, rolled fresh when the cycle
## restarts and cleared when it ends. A tile yields once: digging broken ground
## again returns nothing, which is why dug tiles are marked on the floor.
##
## Broken ground is also a trap. A boss standing on a dug tile takes 1 damage
## every eight seconds, counted in whole ticks of actual overlap — so a boss that
## parks on prepared ground bleeds, and one that only passes through does not.
##
## The roll is seeded from the arena and its cycle number, never from chance at
## the moment of asking: a recorded Forager must dig the same tile for the same
## value every time that cycle comes around.

const MIN_VALUE: int = 1
const MAX_VALUE: int = 3
## Eight seconds of standing on broken ground costs a boss one damage.
const HAZARD_TICKS: int = 8 * ArenicCycleClock.TICKS_PER_SECOND
const SEED_SALT: int = 0xD16F1E1D
const CELLS: int = ArenicGridMath.GRID_WIDTH * ArenicGridMath.GRID_HEIGHT

var arena_id: String = ""
var cycle: int = 0
var _values := PackedByteArray()
## Dug cell index to the ticks of enemy overlap it has banked. Presence means
## dug; only broken ground is tracked, so the map stays small.
var _dug: Dictionary[int, int] = {}


func configure(owner_arena: String) -> void:
	arena_id = owner_arena
	cycle = 0
	regenerate(0, 0)


## Rolls fresh ground for one cycle and clears every previous dig. `bonus` lifts
## the whole field, which is where a future upgrade raises what digging is worth.
func regenerate(cycle_index: int, bonus: int = 0) -> void:
	cycle = cycle_index
	_dug.clear()
	_values.resize(CELLS)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED_SALT ^ (hash(arena_id) * 0x9E3779B1) ^ (cycle_index * 0x85EBCA6B)
	var lift: int = maxi(0, bonus)
	for index: int in CELLS:
		_values[index] = mini(255, rng.randi_range(MIN_VALUE, MAX_VALUE) + lift)


static func index_of(cell: Vector2i) -> int:
	return cell.y * ArenicGridMath.GRID_WIDTH + cell.x


static func cell_of(index: int) -> Vector2i:
	@warning_ignore("integer_division")
	return Vector2i(index % ArenicGridMath.GRID_WIDTH, index / ArenicGridMath.GRID_WIDTH)


func value_at(cell: Vector2i) -> int:
	if not ArenicGridMath.tile_valid(cell) or _values.is_empty():
		return 0
	return int(_values[index_of(cell)])


func is_dug(cell: Vector2i) -> bool:
	return ArenicGridMath.tile_valid(cell) and _dug.has(index_of(cell))


func dug_count() -> int:
	return _dug.size()


func dug_cells() -> PackedInt32Array:
	var cells := PackedInt32Array()
	for index: int in _dug.keys():
		cells.append(index)
	cells.sort()
	return cells


## Breaks one tile and returns what it yielded. Ground already broken yields
## nothing — the cast still happened, it simply found nothing left to take.
func dig(cell: Vector2i) -> int:
	if not ArenicGridMath.tile_valid(cell) or _dug.has(index_of(cell)):
		return 0
	_dug[index_of(cell)] = 0
	return value_at(cell)


## Advances one tick of hazard. Returns `[enemy_id, amount]` pairs for the ground
## that came due, so the caller applies damage through the ledger rather than the
## field reaching into it.
func advance_hazards(combat: ArenicCombatState) -> Array:
	var due: Array = []
	if combat == null or _dug.is_empty():
		return due
	for index: int in _dug.keys():
		var enemy: String = combat.enemy_at(arena_id, cell_of(index))
		if enemy.is_empty():
			continue
		# Overlap is BANKED, not reset on leaving: a boss that stands on broken
		# ground for seven seconds a cycle still eventually pays for it.
		var banked: int = int(_dug[index]) + 1
		while banked >= HAZARD_TICKS:
			banked -= HAZARD_TICKS
			due.append([enemy, 1])
		_dug[index] = banked
	return due


## Dug cells a target is currently standing on, for the floor markers.
func overlapped_cells(combat: ArenicCombatState) -> PackedInt32Array:
	var hot := PackedInt32Array()
	if combat == null:
		return hot
	for index: int in dug_cells():
		if combat.is_occupied(arena_id, cell_of(index)):
			hot.append(index)
	return hot
