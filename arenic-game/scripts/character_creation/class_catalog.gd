class_name ArenicClassCatalog
extends Resource

@export var classes: Array[ArenicClassDefinition] = []


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var ids: Dictionary = {}
	if classes.is_empty() or classes.size() > 8:
		errors.append("The class grid supports one to eight definitions.")
	for definition in classes:
		if definition == null:
			errors.append("The catalog contains an empty definition.")
			continue
		if definition.class_id.is_empty() or ids.has(definition.class_id):
			errors.append("Class IDs must be nonempty and unique: %s" % definition.class_id)
		ids[definition.class_id] = true
		if definition.display_name.is_empty() or definition.character_name.is_empty():
			errors.append("A class or character name is missing: %s" % definition.class_id)
		if definition.icon == null or definition.portrait == null:
			errors.append("A class image is missing: %s" % definition.class_id)
		if definition.skills.is_empty():
			errors.append("Class information is missing: %s" % definition.class_id)
		for skill in definition.skills:
			if skill == null or skill.title.is_empty() or skill.description.is_empty():
				errors.append("An ability needs a title and description: %s" % definition.class_id)
	return errors
