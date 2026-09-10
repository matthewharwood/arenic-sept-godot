class_name ArenicArenaMusicClock
extends RefCounted
## Playback-independent loop phase. The director advances every arena, even muted.
## Change loop duration through configure(); elapsed_seconds stays in [0, duration).

var elapsed_seconds: float = 0.0
var duration_seconds: float = 0.0
var running: bool = false


func configure(duration_seconds: float, phase_seconds: float = 0.0) -> void:
	elapsed_seconds = 0.0
	self.duration_seconds = duration_seconds if is_finite(duration_seconds) and duration_seconds > 0.0 else 0.0
	running = self.duration_seconds > 0.0
	seek(phase_seconds)


func advance(delta: float) -> void:
	if not running or duration_seconds <= 0.0 or not is_finite(delta) or delta <= 0.0:
		return
	# Ordinary frame deltas need no modulo. Reduce large deltas before adding so
	# even very large finite durations and seeks cannot overflow the phase sum.
	var step: float = fmod(delta, duration_seconds) if delta >= duration_seconds else delta
	var remaining: float = duration_seconds - elapsed_seconds
	elapsed_seconds = step - remaining if step >= remaining else elapsed_seconds + step
	if elapsed_seconds >= duration_seconds:
		elapsed_seconds = 0.0 # Floating-point rounding can land exactly on the end.


func seek(seconds: float) -> void:
	if duration_seconds <= 0.0 or not is_finite(seconds):
		return
	elapsed_seconds = fposmod(seconds, duration_seconds)
	if elapsed_seconds >= duration_seconds:
		elapsed_seconds = 0.0


func get_position() -> float:
	return elapsed_seconds
