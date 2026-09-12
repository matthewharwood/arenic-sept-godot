@tool
class_name ArenicMovementSoundProfile
extends Resource
## Separate confirmed movement and blocked-step cues; no input-repeat playback.

@export var move: ArenicSoundCue
@export var blocked: ArenicSoundCue


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	for phase: String in ["move", "blocked"]:
		var cue: ArenicSoundCue = move if phase == "move" else blocked
		if cue == null:
			errors.append("Movement audio needs its %s cue." % phase)
			continue
		for error: String in cue.validation_errors():
			errors.append("%s: %s" % [phase, error])
		if cue.loop:
			errors.append("%s must be a one-shot cue." % phase)
	return errors


func _get_validation_conditions() -> Array:
	return ArenicDoctorConditions.from_errors(validation_errors())
