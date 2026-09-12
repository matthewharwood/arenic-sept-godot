@tool
class_name ArenicBossVisualState
extends Resource
## An authored appearance loop, not a gameplay state or transformation rule.

const DIRECTIONS: PackedStringArray = ["n", "e", "s", "w"]

@export var state_id: String = ""
@export var tag_prefix: String = ""


func animation_tags() -> PackedStringArray:
	var tags := PackedStringArray()
	for direction in DIRECTIONS:
		tags.append("%s_%s" % [tag_prefix, direction])
	return tags
