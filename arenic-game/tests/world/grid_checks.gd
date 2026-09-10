extends SceneTree
## Run with Godot --headless --path arenic-game --script res://tests/world/grid_checks.gd.

const Grid = preload("res://scripts/world/grid_math.gd")
const EPSILON: float = 0.0001

var _checks: int = 0
var _failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	_check_constants_and_extents()
	_check_all_arenas()
	_check_invalid_inputs()
	if _failures.is_empty():
		print("Grid checks passed: %d assertions." % _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("Grid checks failed: %d of %d assertions." % [_failures.size(), _checks])
		quit(1)


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _check_constants_and_extents() -> void:
	_expect(Grid.GRID_WIDTH == 66 and Grid.GRID_HEIGHT == 31, "Arena is 66 by 31 tiles.")
	_expect(Grid.ARENA_COUNT == 9, "World contains 9 arenas.")
	_expect(is_equal_approx(Grid.TILE_SIZE, 0.25), "Tile size is 0.25.")
	_expect(
		Grid.arena_rect(Vector2i.ZERO).is_equal_approx(Rect2(-0.125, -7.625, 16.5, 7.75)),
		"Arena 0 includes half-tile outer extents."
	)
	_expect(
		Grid.world_rect().is_equal_approx(Rect2(-0.125, -7.625, 49.5, 23.25)),
		"World includes all 3 by 3 arena footprints."
	)
	_expect(
		Grid.arena_center(Vector2i(1, 1)).is_equal_approx(Vector3(24.625, 0.0, 4.0)),
		"World center matches the reference XZ conversion."
	)


func _check_all_arenas() -> void:
	var cells: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(65, 0), Vector2i(0, 30), Vector2i(65, 30),
		Vector2i(32, 15), Vector2i(33, 15)
	]
	for row in range(3):
		for column in range(3):
			var slot := Vector2i(column, row)
			var rect: Rect2 = Grid.arena_rect(slot)
			var center: Vector3 = Grid.arena_center(slot)
			_expect(Grid.slot_valid(slot), "Valid slot %s." % slot)
			_expect(Grid.world_rect().encloses(rect), "World encloses slot %s." % slot)
			_expect(
				Vector2(center.x, center.z).is_equal_approx(rect.get_center()),
				"Center matches footprint for slot %s." % slot
			)
			_expect(
				Grid.world_to_tile(slot, center) == Vector2i(33, 15),
				"Center tie selects cell (33, 15) for slot %s." % slot
			)
			for cell in cells:
				var world: Vector3 = Grid.tile_to_world(slot, cell)
				_expect(Grid.tile_valid(cell), "Valid cell %s." % cell)
				_expect(rect.has_point(Vector2(world.x, world.z)), "Footprint contains %s/%s." % [slot, cell])
				_expect(Grid.world_to_tile(slot, world) == cell, "Tile round trip %s/%s." % [slot, cell])
				_expect(
					Grid.world_to_tile(slot, world + Vector3(0.0, 8.0, 0.0)) == cell,
					"Vertical lift does not change the cell at %s/%s." % [slot, cell]
				)
			_check_footprint_edges(slot, rect)
			if column < 2:
				var right: Rect2 = Grid.arena_rect(slot + Vector2i.RIGHT)
				_expect(is_equal_approx(rect.end.x, right.position.x), "East-west seam aligns at %s." % slot)
			if row < 2:
				var next_row: Rect2 = Grid.arena_rect(slot + Vector2i.DOWN)
				_expect(is_equal_approx(rect.end.y, next_row.position.y), "North-south seam aligns at %s." % slot)


func _check_footprint_edges(slot: Vector2i, rect: Rect2) -> void:
	var center: Vector2 = rect.get_center()
	var inside: Array[Vector2] = [
		Vector2(rect.position.x, center.y),
		Vector2(rect.end.x - EPSILON, center.y),
		Vector2(center.x, rect.position.y),
		Vector2(center.x, rect.end.y - EPSILON)
	]
	var outside: Array[Vector2] = [
		Vector2(rect.position.x - EPSILON, center.y),
		Vector2(rect.end.x, center.y),
		Vector2(center.x, rect.position.y - EPSILON),
		Vector2(center.x, rect.end.y)
	]
	for point in inside:
		_expect(
			Grid.tile_valid(Grid.world_to_tile(slot, Vector3(point.x, 0.0, point.y))),
			"Half-open footprint includes inside edge %s/%s." % [slot, point]
		)
	for point in outside:
		_expect(
			not Grid.tile_valid(Grid.world_to_tile(slot, Vector3(point.x, 0.0, point.y))),
			"Outside edge does not clamp into slot %s/%s." % [slot, point]
		)


func _check_invalid_inputs() -> void:
	var invalid_cells: Array[Vector2i] = [
		Vector2i(-1, 0), Vector2i(66, 0), Vector2i(0, -1), Vector2i(0, 31)
	]
	var invalid_slots: Array[Vector2i] = [
		Vector2i(-1, 0), Vector2i(3, 0), Vector2i(0, -1), Vector2i(0, 3)
	]
	for cell in invalid_cells:
		_expect(not Grid.tile_valid(cell), "Reject invalid cell %s." % cell)
		_expect(
			Grid.world_to_tile(Vector2i.ZERO, Grid.tile_to_world(Vector2i.ZERO, cell)) == cell,
			"Inverse preserves invalid cell %s instead of clamping." % cell
		)
	for slot in invalid_slots:
		_expect(not Grid.slot_valid(slot), "Reject invalid slot %s." % slot)
