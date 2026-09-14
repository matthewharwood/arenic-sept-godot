class_name ArenicOverworldActions
extends RefCounted
## Shared presentation catalog. IDs select empty tabs; they perform no gameplay.

const COUNT: int = 5
const IDS: Array[StringName] = [&"rotate_selected", &"roster", &"loot", &"auction", &"craft"]
const TITLES: PackedStringArray = ["Rotate selected", "Roster", "Loot", "Auction", "Craft"]
const HOTKEYS: PackedStringArray = ["1", "2", "3", "4", "R"]
const KEYS: PackedInt32Array = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_R]

static func entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index: int in COUNT:
		result.append({"id": IDS[index], "title": TITLES[index], "hotkey": HOTKEYS[index], "key": KEYS[index]})
	return result

static func action_for_slot(index: int) -> StringName:
	return IDS[index] if index >= 0 and index < COUNT else &""

static func index_for(action: StringName) -> int:
	return IDS.find(action)

static func title(action: StringName) -> String:
	var index: int = index_for(action)
	return TITLES[index] if index >= 0 else ""

static func hotkey(action: StringName) -> String:
	var index: int = index_for(action)
	return HOTKEYS[index] if index >= 0 else ""

static func action_for_key(key: int) -> StringName:
	return action_for_slot(KEYS.find(key))
