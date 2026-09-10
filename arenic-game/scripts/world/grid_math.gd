class_name ArenicGridMath
extends RefCounted
## Reference mapping: Bevy (x, y, lift) becomes Godot (x, lift, -y).
## Grid slots grow toward +Z; local tile rows grow toward -Z.

const GRID_WIDTH: int = 66
const GRID_HEIGHT: int = 31
const WORLD_COLUMNS: int = 3
const WORLD_ROWS: int = 3
const ARENA_COUNT: int = WORLD_COLUMNS * WORLD_ROWS
const TILE_SIZE: float = 0.25
const HALF_TILE: float = TILE_SIZE * 0.5
const ARENA_WIDTH: float = GRID_WIDTH * TILE_SIZE
const ARENA_HEIGHT: float = GRID_HEIGHT * TILE_SIZE


static func arena_origin(slot: Vector2i) -> Vector3:
	return Vector3(slot.x * ARENA_WIDTH, 0.0, slot.y * ARENA_HEIGHT)


static func arena_center(slot: Vector2i) -> Vector3:
	return arena_origin(slot) + Vector3(
		(GRID_WIDTH - 1) * TILE_SIZE * 0.5,
		0.0,
		-(GRID_HEIGHT - 1) * TILE_SIZE * 0.5
	)


## Rect2 coordinates are (world X, world Z), with positive size.
## The footprint extends half a tile beyond the outermost tile centers.
static func arena_rect(slot: Vector2i) -> Rect2:
	var origin: Vector3 = arena_origin(slot)
	return Rect2(
		origin.x - HALF_TILE,
		origin.z - (GRID_HEIGHT - 1) * TILE_SIZE - HALF_TILE,
		ARENA_WIDTH,
		ARENA_HEIGHT
	)


static func world_rect() -> Rect2:
	return Rect2(
		arena_rect(Vector2i.ZERO).position,
		Vector2(WORLD_COLUMNS * ARENA_WIDTH, WORLD_ROWS * ARENA_HEIGHT)
	)


## Geometry functions do not clamp; callers validate cells/slots explicitly.
static func tile_to_world(slot: Vector2i, cell: Vector2i) -> Vector3:
	return arena_origin(slot) + Vector3(cell.x * TILE_SIZE, 0.0, -cell.y * TILE_SIZE)


## Returns the containing tile, ignoring vertical lift. Outside cells stay invalid.
## Boundary ties follow Rect2's lower-inclusive, upper-exclusive XZ footprint:
## +X chooses the next column, while +Z chooses the previous local row.
static func world_to_tile(slot: Vector2i, world: Vector3) -> Vector2i:
	var local: Vector3 = world - arena_origin(slot)
	return Vector2i(
		floori(local.x / TILE_SIZE + 0.5),
		ceili(-local.z / TILE_SIZE - 0.5)
	)


static func tile_valid(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < GRID_WIDTH and cell.y >= 0 and cell.y < GRID_HEIGHT


static func slot_valid(slot: Vector2i) -> bool:
	return slot.x >= 0 and slot.x < WORLD_COLUMNS and slot.y >= 0 and slot.y < WORLD_ROWS
