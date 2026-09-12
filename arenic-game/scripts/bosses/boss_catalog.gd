@tool
class_name ArenicBossCatalog
extends Resource
## Eight authored boss identities; appearance metadata never supplies combat rules.

const BOSS_COUNT: int = 8

@export var bosses: Array[ArenicBossDefinition] = []


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if bosses.size() != BOSS_COUNT:
		errors.append("Expected exactly 8 bosses; found %d." % bosses.size())
	var ids: Dictionary = {}
	for index in range(bosses.size()):
		var boss: ArenicBossDefinition = bosses[index]
		if boss == null:
			errors.append("Boss %d is null." % index)
			continue
		var id: String = boss.boss_id.strip_edges()
		if id.is_empty() or ids.has(id):
			errors.append("Boss IDs must be nonempty and unique: %s." % id)
		ids[id] = true
		for error in boss.validation_errors():
			errors.append("Boss '%s': %s" % [id, error])
	return errors


func _get_validation_conditions() -> Array:
	return ArenicDoctorConditions.from_errors(validation_errors())


func index_for_id(boss_id: String) -> int:
	for index in range(bosses.size()):
		var boss: ArenicBossDefinition = bosses[index]
		if boss != null and boss.boss_id == boss_id:
			return index
	return -1
