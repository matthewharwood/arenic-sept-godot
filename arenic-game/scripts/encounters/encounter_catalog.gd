@tool
class_name ArenicEncounterCatalog
extends Resource
## Every authored staff, addressed by arena and difficulty.
##
## An arena without a score for the active difficulty simply has no battle
## sequence yet; that is a normal authoring state, not an error. Difficulty tiers
## own separate scores so Heroic and Mythic can rewrite an encounter outright
## rather than scale one timeline.

@export var scores: Array[ArenicEncounterScore] = []


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen: Dictionary = {}
	for index: int in scores.size():
		var score: ArenicEncounterScore = scores[index]
		if score == null:
			errors.append("Score %d is null." % index)
			continue
		var key: String = "%s/%s" % [score.arena_id, score.difficulty]
		if seen.has(key):
			errors.append("Two scores author the same arena and difficulty: %s." % key)
		seen[key] = true
		for error: String in score.validation_errors():
			errors.append("Score '%s': %s" % [key, error])
	return errors


func score_for(arena_id: String, difficulty: String, ruleset: String = ArenicActorEffects.LEGACY) -> ArenicEncounterScore:
	for score: ArenicEncounterScore in scores:
		if score is ArenicMaskScore and ruleset == ArenicActorEffects.LEGACY:
			continue
		if score != null and score.arena_id == arena_id and score.difficulty == difficulty:
			return score
	return null


func _get_validation_conditions() -> Array:
	return ArenicDoctorConditions.from_errors(validation_errors())
