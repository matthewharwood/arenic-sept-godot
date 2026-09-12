class_name ArenicHeroState
extends RefCounted
## Authoritative run state. Camera, stage and sprite lifetimes do not own it.
const MAX_EXPERIENCE: int = 9223372036854775807

var definition: ArenicClassDefinition
## Stable run identity; generated names never depend on a sprite or scene instance.
var identity_id: int = 0:
	set(value):
		identity_id = maxi(0, value)
var level: int = 1:
	set(value):
		level = maxi(1, value)
var experience: int = 0:
	set(value):
		experience = maxi(0, value)
## Display threshold only. No XP producer or level-up rules are implied here.
var experience_to_next_level: int = 100:
	set(value):
		experience_to_next_level = maxi(1, value)
var arena_id: String = "guild_house"
var cell: Vector2i = Vector2i(30, 15)
var facing: String = "n"
var selected: bool = true
## This hero's committed staff per arena — its sheet music, keyed by arena id.
## Looked up by key only; the simulation never iterates it.
var recordings: Dictionary[String, ArenicRecording] = {}


## This hero's key in the combat ledger and in an arena's merged stream. Derived
## from the run identity, so it survives stage swaps, arena travel and respawn.
func ally_id() -> String:
	return ArenicCombatState.hero_ally_id(identity_id)


func display_name() -> String:
	if definition != null and not definition.character_name.strip_edges().is_empty():
		return definition.character_name
	return ArenicHeroNames.name_for_id(identity_id)


## Return the actual accepted gain so feedback cannot overstate a saturated total.
## Health and support effects remain authoritative in ArenicCombatState.
func gain_experience(amount: int) -> int:
	if amount <= 0:
		return 0
	var accepted := mini(amount, MAX_EXPERIENCE - experience)
	experience += accepted
	return accepted


## A recorded step. Playback CLAMPS at the arena edge and never edge-walks: a
## ghost that walked out would be folded into a timeline it no longer stands in.
## Only live input may cross into an adjacent arena.
func step_within_arena(direction: Vector2i) -> bool:
	if definition == null or direction == Vector2i.ZERO or absi(direction.x) > 1 or absi(direction.y) > 1:
		return false
	if not ArenicGridMath.tile_valid(cell):
		return false
	var limit := Vector2i(ArenicGridMath.GRID_WIDTH - 1, ArenicGridMath.GRID_HEIGHT - 1)
	var target: Vector2i = (cell + direction).clamp(Vector2i.ZERO, limit)
	var moved: bool = target != cell
	if moved:
		facing = ("n" if direction.y > 0 else "s") if direction.y != 0 else ("e" if direction.x > 0 else "w")
	cell = target
	return moved


## Where a one-tile step lands: the destination arena index and cell. The ONE
## place the edge rule lives, so travel and the mid-recording interrupt that asks
## about it cannot drift apart. An empty result means the step is impossible.
func landing(direction: Vector2i, world: ArenicWorldDefinition) -> Dictionary:
	if definition == null or world == null or direction == Vector2i.ZERO or absi(direction.x) > 1 or absi(direction.y) > 1:
		return {}
	var index := world.index_for_id(arena_id)
	if index < 0 or not ArenicGridMath.tile_valid(cell):
		return {}
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
		return {}
	# Outside the 3x3 border the world does not wrap; the step simply clamps.
	return {"index": destination_index, "cell": target.clamp(Vector2i.ZERO, max_cell)}


## The arena a step would carry this hero into, or an empty string when it stays
## inside the one it is standing in.
func crossing_arena(direction: Vector2i, world: ArenicWorldDefinition) -> String:
	var destination: Dictionary = landing(direction, world)
	if destination.is_empty():
		return ""
	var arrival: String = world.arenas[int(destination["index"])].arena_id
	return arrival if arrival != arena_id else ""


## Device-neutral, one-tile intent. Same edge priority/clamping as Rust travel.rs.
func step(direction: Vector2i, world: ArenicWorldDefinition) -> bool:
	var destination: Dictionary = landing(direction, world)
	if destination.is_empty():
		return false
	var destination_index: int = int(destination["index"])
	var target: Vector2i = destination["cell"]
	var slot := world.arenas[world.index_for_id(arena_id)].grid_slot
	var landed_slot := world.arenas[destination_index].grid_slot
	var destination_changed: bool = landed_slot != slot
	# The original pucks had no facing. Cardinal art uses the vertical direction
	# on a diagonal and retains facing on a blocked move.
	var moved := destination_changed or target != cell
	if moved:
		facing = ("n" if direction.y > 0 else "s") if direction.y != 0 else ("e" if direction.x > 0 else "w")
	cell = target
	arena_id = world.arenas[destination_index].arena_id
	return moved
