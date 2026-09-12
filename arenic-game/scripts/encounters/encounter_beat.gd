@tool
class_name ArenicEncounterBeat
extends Resource
## One note on an arena's staff: an authored action at an exact cycle tick.
##
## `at_tick` is the moment the action RESOLVES, not when its motion starts. A
## jump therefore occupies `[at_tick - travel_ticks, at_tick]` in the air and
## lands exactly on the beat, so a score reads like struck notes rather than
## like windups. Positions are whole ticks inside the cycle, never seconds:
## a recorded ghost has to line up with this pattern tick for tick, every cycle.

const ACTION_IDS: PackedStringArray = ["boss_jump"]

@export_range(0, 36000, 1, "or_greater") var at_tick: int = 0
@export_enum("boss_jump") var action_id: String = "boss_jump"
## Lower-left cell of the boss's gameplay footprint when this beat resolves.
@export var boss_origin_cell: Vector2i = Vector2i(30, 12)
@export_enum("n", "e", "s", "w") var facing: String = "n"
## Airborne ticks before the landing. Zero teleports on the beat.
@export_range(0, 3600, 1) var travel_ticks: int = 72
## Peak arc height in tiles, toward the top-down camera. Presentation only.
@export_range(0.0, 64.0, 0.01) var lift_tiles: float = 6.0
## Radial tiles struck on landing. Zero lands without a blast.
@export_range(0.0, 64.0, 0.01) var blast_radius_tiles: float = 7.0


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if at_tick < 0:
		errors.append("Beat position must be a nonnegative cycle tick.")
	if action_id not in ACTION_IDS:
		errors.append("Unknown beat action: %s." % action_id)
	if facing not in ["n", "e", "s", "w"]:
		errors.append("Beat facing must be one of n, e, s, w.")
	if travel_ticks < 0:
		errors.append("Travel time must be a nonnegative tick count.")
	if not is_finite(lift_tiles) or lift_tiles < 0.0:
		errors.append("Arc lift must be finite and nonnegative.")
	if not is_finite(blast_radius_tiles) or blast_radius_tiles < 0.0:
		errors.append("Blast radius must be finite and nonnegative.")
	return errors


## The footprint this beat lands on, given the arena's authored boss size.
func footprint(boss_size: Vector2i) -> Rect2i:
	return Rect2i(boss_origin_cell, boss_size)


## Center of that footprint in tile coordinates. Even sizes land on a half tile,
## which is exactly where the six-by-six art canvas is already centered.
func center_cell(boss_size: Vector2i) -> Vector2:
	return Vector2(boss_origin_cell) + Vector2(boss_size - Vector2i.ONE) * 0.5


func _get_validation_conditions() -> Array:
	return ArenicDoctorConditions.from_errors(validation_errors())
