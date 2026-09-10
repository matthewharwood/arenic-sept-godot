class_name ArenicHeroState
extends RefCounted
## Authoritative run state. Camera, stage and sprite lifetimes do not own it.
var definition: ArenicClassDefinition
var arena_id: String = "guild_house"
var cell: Vector2i = Vector2i(30, 15)
var facing: String = "n"
var selected: bool = true

## Device-neutral, one-tile intent. Same edge priority/clamping as Rust travel.rs.
func step(direction: Vector2i, world: ArenicWorldDefinition) -> bool:
	if definition == null or world == null or direction == Vector2i.ZERO or absi(direction.x) > 1 or absi(direction.y) > 1:
		return false
	var index := world.index_for_id(arena_id)
	if index < 0 or not ArenicGridMath.tile_valid(cell):
		return false
	var slot := world.arenas[index].grid_slot
	var target := cell + direction
	var destination := slot
	var max_cell := Vector2i(ArenicGridMath.GRID_WIDTH - 1, ArenicGridMath.GRID_HEIGHT - 1)
	if target.x > max_cell.x and slot.x < ArenicGridMath.WORLD_COLUMNS - 1:
		destination.x += 1
		target.x = 0
	elif target.x < 0 and slot.x > 0:
		destination.x -= 1
		target.x = max_cell.x
	elif target.y > max_cell.y and slot.y > 0:
		destination.y -= 1
		target.y = 0
	elif target.y < 0 and slot.y < ArenicGridMath.WORLD_ROWS - 1:
		destination.y += 1
		target.y = max_cell.y
	var destination_index := world.index_for_slot(destination)
	if destination_index < 0:
		return false
	target = target.clamp(Vector2i.ZERO, max_cell)
	# The original pucks had no facing. Cardinal art uses the vertical direction
	# on a diagonal and retains facing on a blocked move.
	var moved := destination != slot or target != cell
	if moved:
		facing = ("n" if direction.y > 0 else "s") if direction.y != 0 else ("e" if direction.x > 0 else "w")
	cell = target
	arena_id = world.arenas[destination_index].arena_id
	return moved
