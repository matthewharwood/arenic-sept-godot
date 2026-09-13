@tool
class_name ArenicTitleMusicDefinition
extends Resource
## Inspector-authored title score. Playback owns a copy of the imported stream,
## so changing looping here never mutates an asset shared by another scene.

@export var enabled: bool = true
@export var version: int = 1
@export var stream: AudioStreamMP3
@export_range(-60.0, 0.0, 0.5, "suffix:dB") var gain_db: float = -12.0
@export var loop: bool = true
@export_range(0.0, 5.0, 0.05, "suffix:s") var fade_in_seconds: float = 0.75


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if version < 1:
		errors.append("Title music version must be positive.")
	if not is_finite(gain_db) or gain_db < -60.0 or gain_db > 0.0:
		errors.append("Title music gain must be between -60 and 0 dB.")
	if not is_finite(fade_in_seconds) or fade_in_seconds < 0.0 or fade_in_seconds > 5.0:
		errors.append("Title music fade must be between zero and five seconds.")
	if stream == null:
		if enabled:
			errors.append("Enabled title music needs an MP3 stream.")
	elif not is_finite(stream.get_length()) or stream.get_length() <= 0.0:
		errors.append("Title music needs a finite positive stream duration.")
	return errors


func make_stream() -> AudioStreamMP3:
	if stream == null:
		return null
	var playback_stream := stream.duplicate() as AudioStreamMP3
	playback_stream.loop = loop
	playback_stream.loop_offset = 0.0
	return playback_stream


func _get_validation_conditions() -> Array:
	return ArenicDoctorConditions.from_errors(validation_errors())
