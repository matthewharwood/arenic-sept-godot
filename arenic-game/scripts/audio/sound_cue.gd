class_name ArenicSoundCue
extends Resource
## Explicit playback policy for one sound. The shared source stream stays immutable.

@export var stream: AudioStream
@export_range(-80.0, 6.0, 0.1) var volume_db: float = -8.0
@export_range(1, 8, 1) var max_instances: int = 2
@export_range(0.0, 1.0, 0.005) var min_interval_seconds: float = 0.045
@export_range(0, 100, 1) var priority: int = 50
@export var loop: bool = false
@export_range(0.0, 1.0, 0.005) var fade_out_seconds: float = 0.035


func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if stream == null:
		errors.append("A sound cue needs an audio stream.")
	else:
		var duration: float = stream.get_length()
		if not is_finite(duration) or duration <= 0.0:
			errors.append("A sound cue needs a finite, positive stream duration.")
	if not is_finite(volume_db) or volume_db < -80.0 or volume_db > 6.0:
		errors.append("Sound gain must be finite and between -80 and 6 dB.")
	if max_instances < 1 or max_instances > 8:
		errors.append("Sound instances must be between one and eight.")
	if not is_finite(min_interval_seconds) or min_interval_seconds < 0.0 or min_interval_seconds > 1.0:
		errors.append("Sound minimum interval must be finite and between zero and one second.")
	if priority < 0 or priority > 100:
		errors.append("Sound priority must be between zero and one hundred.")
	if not is_finite(fade_out_seconds) or fade_out_seconds < 0.0 or fade_out_seconds > 1.0:
		errors.append("Sound fade must be finite and between zero and one second.")
	elif loop and fade_out_seconds <= 0.0:
		errors.append("A looping cue needs a positive stop fade.")
	return errors
