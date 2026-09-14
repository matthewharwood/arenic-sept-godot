@tool
class_name ArenicGatheringDefinition
extends Resource
## Guild House work sites and rules. No scene geometry or animation owns work.

@export_group("Guild House sites")
@export var wood_sources: Array[Vector2i] = [Vector2i(12, 9), Vector2i(12, 23)]
@export var gold_sources: Array[Vector2i] = [Vector2i(7, 24), Vector2i(56, 7)]
@export var wood_dropoff: Vector2i = Vector2i(23, 21)
@export var gold_dropoff: Vector2i = Vector2i(42, 21)
@export_range(0.25, 8.0, 0.25) var radius_tiles: float = 2.0
@export_group("Bag rules")
@export_range(0.05, 120.0, 0.05) var fill_seconds: float = 5.0
@export_range(1, 1000, 1) var capacity_units: int = 10
@export_range(0.05, 10.0, 0.05) var unload_seconds: float = 1.0


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if wood_sources.size() != 2 or gold_sources.size() != 2:
		errors.append("Gathering requires exactly two wood sources and two gold mines.")
		return errors
	var occupied: Dictionary[Vector2i, bool] = {}
	var sites: Array[Vector2i] = [wood_dropoff, gold_dropoff]
	sites.append_array(wood_sources)
	sites.append_array(gold_sources)
	for cell: Vector2i in sites:
		if not ArenicGridMath.tile_valid(cell):
			errors.append("Every gathering site must be inside the 66 by 31 Guild House grid.")
		if occupied.has(cell):
			errors.append("Gathering sites and dropoffs must have distinct center cells.")
		occupied[cell] = true
	if not is_finite(radius_tiles) or radius_tiles < 0.25 or radius_tiles > 8.0:
		errors.append("Gathering radius must be finite and between 0.25 and 8 tiles.")
	if not is_finite(fill_seconds) or fill_seconds < 0.05 or fill_seconds > 120.0:
		errors.append("Bag fill time must be finite and between 0.05 and 120 seconds.")
	if not is_finite(unload_seconds) or unload_seconds < 0.05 or unload_seconds > 10.0:
		errors.append("Bag unload time must be finite and between 0.05 and 10 seconds.")
	if capacity_units < 1 or capacity_units > 1000:
		errors.append("Bag capacity must be between 1 and 1000 units.")
	return errors


## Empty bags choose the nearest site; exact ties use wood, then authored order.
## An existing bag can only work at a source of its already accepted resource.
func source_kind_at(cell: Vector2i, kind: String = "") -> String:
	return source_at(cell, kind).get("kind", "")


func source_at(cell: Vector2i, kind: String = "") -> Dictionary:
	var found: Dictionary = {}
	var nearest: float = INF
	for resource: String in ["wood", "gold"]:
		if not kind.is_empty() and resource != kind:
			continue
		var sources: Array[Vector2i] = wood_sources if resource == "wood" else gold_sources
		for index: int in range(sources.size()):
			var source: Vector2i = sources[index]
			var distance: int = cell.distance_squared_to(source)
			if distance <= radius_tiles * radius_tiles and distance < nearest:
				nearest = distance
				found = {"id": "%s:%d" % [resource, index], "kind": resource, "cell": source}
	return found


func at_dropoff(cell: Vector2i, kind: String) -> bool:
	if kind not in ["wood", "gold"]:
		return false
	var center: Vector2i = wood_dropoff if kind == "wood" else gold_dropoff
	return cell.distance_squared_to(center) <= radius_tiles * radius_tiles


func _get_validation_conditions() -> Array:
	return ArenicDoctorConditions.from_errors(validation_errors())
