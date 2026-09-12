@tool
class_name ArenicAbilitySoundProfile
extends Resource
## Phase routing is explicit. Asset names never decide when a sound plays.

@export var charge: ArenicSoundCue
@export var cast: ArenicSoundCue
@export var impact: ArenicSoundCue
@export var sustain: ArenicSoundCue
@export var end: ArenicSoundCue
@export var cancel: ArenicSoundCue


func cue_for_phase(phase: String) -> ArenicSoundCue:
	match phase:
		"charge": return charge
		"cast": return cast
		"impact": return impact
		"sustain": return sustain
		"end": return end
		"cancel": return cancel
		_: return null


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	for phase: String in ["charge", "cast", "impact", "sustain", "end", "cancel"]:
		var cue: ArenicSoundCue = cue_for_phase(phase)
		if cue == null:
			if phase in ["cast", "impact"]:
				errors.append("A starter sound profile needs its %s cue." % phase)
			continue
		for error: String in cue.validation_errors():
			errors.append("%s: %s" % [phase, error])
		var expects_loop: bool = phase in ["charge", "sustain"]
		if cue.loop != expects_loop:
			errors.append("%s must be %s." % [phase, "a loop" if expects_loop else "a one-shot cue"])
	return errors


func _get_validation_conditions() -> Array:
	return ArenicDoctorConditions.from_errors(validation_errors())
