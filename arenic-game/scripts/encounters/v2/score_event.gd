@tool
class_name ArenicScoreEvent
extends Resource
## Absolute masks, integer timing, and personal windows. No target selection.
@export var event_id: String = ""
@export var action_id: String = ""
@export var display_name: String = ""
@export var cue_tick: int = 0
@export var at_tick: int = 0
@export var end_tick: int = 1
@export var masks: Array[Rect2i] = []
@export var mask_elements: PackedStringArray = []
@export var tags: PackedStringArray = []
@export var damage: int = 1
@export_enum("impact", "window") var kind: String = "impact"
@export var incoming_direction: String = ""
@export var attunement_bonus: String = ""
@export var boss_origin: Vector2i = Vector2i(30, 12)
@export_enum("n", "e", "s", "w") var boss_facing: String = "n"

func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if event_id.is_empty() or display_name.is_empty() or action_id not in ["sun_seal", "moon_seal", "split_hammer", "confession", "eclipse", "reconciliation"]:
		errors.append("Event needs a stable ID and a supported named action.")
	if cue_tick < 0 or at_tick - cue_tick < (180 if kind == "window" else 120) or end_tick <= at_tick or end_tick > 7200:
		errors.append("Invalid event interval or insufficient warning.")
	if at_tick < 360 or at_tick > 6780 or kind not in ["impact", "window"] or damage < 0 or damage > 4:
		errors.append("Invalid damage, kind, or recovery interval.")
	if masks.size() > 8 or (kind == "impact" and (masks.is_empty() or damage == 0 or end_tick != at_tick + 1)) or (kind == "window" and (not masks.is_empty() or damage != 0)):
		errors.append("Impact/window payload disagrees with its kind.")
	if not mask_elements.is_empty() and mask_elements.size() != masks.size():
		errors.append("Each elemental mask needs its own label.")
	for element: String in mask_elements:
		if element not in ["sun", "moon"]:
			errors.append("Unknown mask element.")
	for mask: Rect2i in masks:
		if not Rect2i(2, 2, 62, 27).encloses(mask) or not mask.has_area():
			errors.append("Mask must preserve the two-cell recovery perimeter.")
	for tag: String in tags:
		if tag not in ["floor", "cone", "projectile", "expose", "sun", "moon"]:
			errors.append("Unknown defense tag.")
	if incoming_direction not in ["", "north", "east", "south", "west"] or attunement_bonus not in ["", "sun", "moon"]:
		errors.append("Unknown direction or bonus element.")
	if kind == "window" and (attunement_bonus.is_empty() or not Rect2i(2, 2, 62, 27).encloses(Rect2i(boss_origin, Vector2i(6, 6)))):
		errors.append("Invalid transfer or bonus.")
	return errors

func wounds(cell: Vector2i, attunement: String) -> bool:
	for index: int in masks.size():
		if masks[index].has_point(cell) and (mask_elements.is_empty() or mask_elements[index] != attunement):
			return true
	return false

func canonical() -> Array:
	var rectangles: Array = []
	for mask: Rect2i in masks:
		rectangles.append([mask.position.x, mask.position.y, mask.size.x, mask.size.y])
	return [event_id, action_id, cue_tick, at_tick, end_tick, rectangles, Array(mask_elements), Array(tags), damage, kind, incoming_direction, attunement_bonus, [boss_origin.x, boss_origin.y], boss_facing]

func _get_validation_conditions() -> Array:
	return ArenicDoctorConditions.from_errors(validation_errors())
