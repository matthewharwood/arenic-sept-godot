@tool
class_name ArenicArenaMusicDefinition
extends Resource
## One replaceable arena score. Versioned resources preserve prior audio choices.
## Duration metadata describes the source loop; AudioStream owns native repetition.

const LENGTH_TOLERANCE_SECONDS: float = 0.15 # MP3 frame/padding metadata tolerance.

@export var id: StringName = &""
@export var version: int = 3
@export var stream: AudioStream
@export var loop_seconds: float = 120.0
@export var gain_db: float = -12.0


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if String(id).strip_edges().is_empty():
		errors.append("Music needs a stable arena id.")
	if version < 1:
		errors.append("Music version must be positive.")
	if not is_finite(loop_seconds) or loop_seconds <= 0.0:
		errors.append("Music loop duration must be finite and positive.")
	if not is_finite(gain_db):
		errors.append("Music gain must be finite.")
	if stream == null:
		errors.append("Music needs an audio stream.")
		return errors
	var length_seconds: float = stream.get_length()
	if not is_finite(length_seconds) or length_seconds <= 0.0:
		errors.append("Music stream must have a finite positive duration.")
	elif is_finite(loop_seconds) and absf(length_seconds - loop_seconds) > LENGTH_TOLERANCE_SECONDS:
		errors.append("Music loop metadata differs from the stream duration by more than %.2fs." % LENGTH_TOLERANCE_SECONDS)
	if stream is AudioStreamMP3:
		var mp3 := stream as AudioStreamMP3
		if not mp3.loop or not is_zero_approx(mp3.loop_offset):
			errors.append("MP3 music must loop from the beginning.")
	return errors


func _get_validation_conditions() -> Array:
	return ArenicDoctorConditions.from_errors(validation_errors())
