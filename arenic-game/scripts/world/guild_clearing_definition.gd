@tool
class_name ArenicGuildClearingDefinition
extends Resource
## Stable, Inspector-editable scenery; bags and movement remain model authority.
const PATH_SPACING: float = 1.6
const MAX_PATH_STAMPS: int = 256
@export var trees: Array[ArenicClearingTree] = []
@export var paths: Array[PackedVector2Array] = []
@export var wood_variants: PackedInt32Array = PackedInt32Array([0, 3])
@export var wood_facings: PackedInt32Array = PackedInt32Array([1, 2])
@export var mine_facings: PackedInt32Array = PackedInt32Array([1, 3])

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if trees.is_empty() or trees.size() > 96:
		errors.append("Clearing needs 1–96 authored trees.")
	for tree: ArenicClearingTree in trees:
		if tree == null or not tree.cell.is_finite() or tree.cell.x < 2.0 or tree.cell.x > 63.0 or tree.cell.y < 2.0 or tree.cell.y > 28.0 or tree.variant < 0 or tree.variant > 4 or tree.facing < 0 or tree.facing > 3:
			errors.append("Trees need valid in-arena positions, one of five variants and a cardinal orientation.")
	if paths.size() > 12:
		errors.append("Clearing supports at most twelve footpaths.")
	var path_stamps: int = 0
	for path: PackedVector2Array in paths:
		if path.size() < 2 or path.size() > 16:
			errors.append("Footpaths require 2–16 points.")
		for point: Vector2 in path:
			if not point.is_finite() or point.x < 0.0 or point.x > 65.0 or point.y < 0.0 or point.y > 30.0:
				errors.append("Footpath points must remain inside the clearing.")
		for segment: int in range(1, path.size()):
			var distance: float = path[segment - 1].distance_to(path[segment])
			if is_finite(distance):
				path_stamps += maxi(1, ceili(distance / PATH_SPACING))
	if path_stamps > MAX_PATH_STAMPS:
		errors.append("Footpaths exceed the 256-stamp scenery budget.")
	for values: PackedInt32Array in [wood_variants, wood_facings, mine_facings]:
		if values.size() != 2:
			errors.append("Each resource source needs a visual selection.")
	for value: int in wood_variants:
		if value < 0 or value > 4:
			errors.append("Unknown wood tree variant.")
	for values: PackedInt32Array in [wood_facings, mine_facings]:
		for value: int in values:
			if value < 0 or value > 3:
				errors.append("Unknown resource orientation.")
	return errors

func _get_validation_conditions() -> Array:
	return ArenicDoctorConditions.from_errors(validation_errors())
