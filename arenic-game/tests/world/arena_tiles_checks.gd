extends SceneTree
## Run after the visible game stops: Godot --path arenic-game --script res://tests/world/arena_tiles_checks.gd
## Instantiates arena presentation only; no shell, camera, save state, or autoload is required.
## A real renderer is required: the headless dummy backend does not retain MultiMesh transforms.

const WORLD_PATH: String = "res://data/world/arenia.tres"
const ARENA_PATH: String = "res://scenes/world/arena.tscn"
const TIMEOUT_SECONDS: float = 5.0
const EXPECTED_BOSSES: Dictionary = {
	"labyrinth": "hunter", "guild_house": "", "sanctum": "cardinal",
	"mountain": "forager", "bastion": "warrior", "pawnshop": "thief",
	"crucible": "alchemist", "casino": "merchant", "gala": "bard",
}

var _host: Node3D
var _watchdog: Timer
var _done: bool = false
var _started_ms: int = 0
var _checks: int = 0
var _tiles_checked: int = 0
var _bosses_checked: int = 0
var _image_checked: bool = false
var _bounds_by_slot: Dictionary = {}


func _initialize() -> void:
	_started_ms = Time.get_ticks_msec()
	_run.call_deferred()


func _run() -> void:
	_watchdog = Timer.new()
	_watchdog.one_shot = true
	_watchdog.wait_time = TIMEOUT_SECONDS
	_watchdog.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_watchdog)
	_watchdog.timeout.connect(_on_timeout)
	_watchdog.start()
	if not _check(DisplayServer.get_name() != "headless", "Run with a real renderer; --headless cannot verify MultiMesh instance geometry."):
		return
	var world := load(WORLD_PATH) as ArenicWorldDefinition
	var packed := load(ARENA_PATH) as PackedScene
	if not _check(world != null and packed != null, "World data and arena scene load."):
		return
	if not _check(world.arenas.size() == 9, "World supplies nine arenas."):
		return
	if not _check(ArenicGridMath.GRID_WIDTH == 66 and ArenicGridMath.GRID_HEIGHT == 31, "Arena lattice is 66 by 31 cells."):
		return
	_host = Node3D.new()
	root.add_child(_host)
	var seen_ids: Dictionary = {}
	for definition in world.arenas:
		if not _check(definition != null, "Arena definition is present."):
			return
		if not _check(EXPECTED_BOSSES.has(definition.arena_id) and not seen_ids.has(definition.arena_id), "Arena identities are the nine unique world entries."):
			return
		seen_ids[definition.arena_id] = true
		if not _check(ArenicGridMath.slot_valid(definition.grid_slot) and not _bounds_by_slot.has(definition.grid_slot), "Arena slots are valid and unique."):
			return
		var arena := packed.instantiate() as ArenicArenaView
		if not _check(arena != null, "Arena scene instantiates ArenicArenaView."):
			return
		arena.definition = definition
		_host.add_child(arena)
		if not _check_tiles(arena) or not _check_boss(arena):
			return
	if not _check(_bosses_checked == 8, "Eight matching bosses are present; Guild House is empty."):
		return
	if not _check_seams():
		return
	_finish(0, "Arena tile checks passed: %d assertions, %d tile placements, %d bosses; tile image checked: %s." % [_checks, _tiles_checked, _bosses_checked, _image_checked])


func _check_tiles(arena: ArenicArenaView) -> bool:
	var tiles := arena.get_node_or_null("Tiles") as MultiMeshInstance3D
	if not _check(tiles != null and tiles.get_script() != null and tiles.get_script().get_global_name() == "ArenicArenaTiles", "%s has native arena tiles." % arena.definition.arena_id):
		return false
	var multimesh: MultiMesh = tiles.multimesh
	if not _check(multimesh != null and multimesh.instance_count == 2046, "Each arena renders all 2,046 cells."):
		return false
	var plane := multimesh.mesh as PlaneMesh
	if not _check(plane != null and plane.size.is_equal_approx(Vector2.ONE * ArenicGridMath.TILE_SIZE), "Each tile has a one-cell plane footprint."):
		return false
	var seen_cells: Dictionary = {}
	var minimum: Vector2 = Vector2(INF, INF)
	var maximum: Vector2 = Vector2(-INF, -INF)
	var problem: String = ""
	var slot: Vector2i = arena.definition.grid_slot
	for index in range(multimesh.instance_count):
		var transform: Transform3D = tiles.global_transform * multimesh.get_instance_transform(index)
		var point: Vector3 = transform.origin
		var cell: Vector2i = ArenicGridMath.world_to_tile(slot, point)
		if not ArenicGridMath.tile_valid(cell) or seen_cells.has(cell):
			problem = "instance %d maps to invalid/duplicate cell %s" % [index, cell]
			break
		if not point.is_equal_approx(ArenicGridMath.tile_to_world(slot, cell)) or not transform.basis.is_equal_approx(Basis.IDENTITY):
			problem = "instance %d is displaced, rotated, or scaled from cell %s" % [index, cell]
			break
		seen_cells[cell] = true
		minimum = minimum.min(Vector2(point.x, point.z))
		maximum = maximum.max(Vector2(point.x, point.z))
		_tiles_checked += 1
	if not _check(problem.is_empty() and seen_cells.size() == 2046, "%s covers the complete cell lattice with exact round trips: %s" % [arena.definition.arena_id, problem]):
		return false
	var half: Vector2 = Vector2.ONE * ArenicGridMath.HALF_TILE
	var measured := Rect2(minimum - half, maximum - minimum + half * 2.0)
	var expected: Rect2 = ArenicGridMath.arena_rect(slot)
	if not _check(measured.position.is_equal_approx(expected.position) and measured.size.is_equal_approx(expected.size), "Rendered outer tile edges match the arena footprint."):
		return false
	_bounds_by_slot[slot] = measured
	if not _image_checked and not _check_tile_image(plane):
		return false
	return true


func _check_tile_image(plane: PlaneMesh) -> bool:
	var material := plane.material as BaseMaterial3D
	if material == null or material.albedo_texture == null:
		return true # Runtime pixel inspection covers an unreadable/material-specific texture.
	var image: Image = material.albedo_texture.get_image()
	if image == null or image.is_empty():
		return true
	if not _check(image.get_size() == Vector2i(19, 19), "Shared tile texture is 19 by 19 native pixels."):
		return false
	var background: Color = image.get_pixel(0, 0)
	var changed_pixels: int = 0
	var changed_position: Vector2i = Vector2i(-1, -1)
	for y in range(19):
		for x in range(19):
			if not image.get_pixel(x, y).is_equal_approx(background):
				changed_pixels += 1
				changed_position = Vector2i(x, y)
	_image_checked = true
	return _check(changed_pixels == 1 and changed_position == Vector2i(9, 9), "Tile texture has exactly one distinct center pixel.")


func _check_boss(arena: ArenicArenaView) -> bool:
	var definition: ArenicArenaDefinition = arena.definition
	var expected_id: String = str(EXPECTED_BOSSES[definition.arena_id])
	var sprite := arena.get_node_or_null("Boss") as AnimatedSprite3D
	if expected_id.is_empty():
		return _check(definition.boss == null and sprite == null, "Guild House has no boss definition or sprite.")
	if not _check(definition.boss != null and sprite != null, "%s has its assigned boss sprite." % definition.arena_id):
		return false
	var boss: ArenicBossDefinition = definition.boss
	if not _check(boss.boss_id == expected_id and boss.boss_id == definition.class_id, "Arena class and boss identity agree."):
		return false
	if not _check(boss.sprite_frames != null and sprite.sprite_frames == boss.sprite_frames and boss.sprite_frames.resource_path == "res://assets/bosses/%s/%s_frames.tres" % [expected_id, expected_id], "Boss uses its existing matching SpriteFrames resource."):
		return false
	if not _check(definition.boss_facing == "n" and sprite.animation == &"idle_n" and sprite.sprite_frames.has_animation(&"idle_n") and sprite.is_playing(), "Boss plays the authored north-facing idle loop."):
		return false
	if not _check(is_equal_approx(sprite.pixel_size, ArenicGridMath.TILE_SIZE / 19.0) and is_equal_approx(114.0 * sprite.pixel_size, 6.0 * ArenicGridMath.TILE_SIZE), "Boss canvas occupies exactly six cells at 19 pixels per cell."):
		return false
	if not _check(not sprite.shaded and sprite.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST and not sprite.fixed_size, "Boss preserves unshaded nearest-filtered world scaling."):
		return false
	if not _check(sprite.centered and sprite.offset.is_zero_approx() and sprite.rotation.is_equal_approx(Vector3(-PI * 0.5, 0.0, 0.0)), "Boss uses its centered pivot on the overhead plane."):
		return false
	var origin: Vector2i = definition.boss_origin_cell
	if not _check(ArenicGridMath.tile_valid(origin) and ArenicGridMath.tile_valid(origin + Vector2i(5, 5)), "The complete six-cell boss footprint stays inside the arena."):
		return false
	var center: Vector3 = ArenicGridMath.tile_to_world(definition.grid_slot, origin) + Vector3(2.5 * ArenicGridMath.TILE_SIZE, 0.01, -2.5 * ArenicGridMath.TILE_SIZE)
	if not _check(sprite.global_position.is_equal_approx(center), "Boss pivot centers the six-by-six-cell footprint above the tiles."):
		return false
	_bosses_checked += 1
	return true


func _check_seams() -> bool:
	for y in range(3):
		for x in range(3):
			var bounds: Rect2 = _bounds_by_slot[Vector2i(x, y)]
			if x < 2:
				var right: Rect2 = _bounds_by_slot[Vector2i(x + 1, y)]
				if not _check(is_equal_approx(bounds.end.x, right.position.x), "Horizontal arena edges meet without a gap or overlap."):
					return false
			if y < 2:
				var below: Rect2 = _bounds_by_slot[Vector2i(x, y + 1)]
				if not _check(is_equal_approx(bounds.end.y, below.position.y), "Vertical arena edges meet without a gap or overlap."):
					return false
	return true


func _check(condition: bool, message: String) -> bool:
	if _done:
		return false
	if Time.get_ticks_msec() - _started_ms >= int(TIMEOUT_SECONDS * 1000.0):
		_on_timeout()
		return false
	_checks += 1
	if not condition:
		_finish(1, "Arena tile assertion failed: " + message)
		return false
	return true


func _on_timeout() -> void:
	_finish(1, "Arena tile checks exceeded the five-second watchdog.")


func _finish(code: int, message: String) -> void:
	if _done:
		return
	_done = true
	_watchdog.stop()
	if is_instance_valid(_host):
		_host.free()
	_watchdog.queue_free()
	print(message)
	quit(code)
