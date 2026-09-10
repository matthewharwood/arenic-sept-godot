extends SceneTree
## Godot --headless --path arenic-game --script res://tests/audio/clock_checks.gd
## Pure loop-clock checks: no audio device, playback node, scene or renderer.

const Clock = preload("res://scripts/audio/arena_music_clock.gd")

var _checks: int = 0
var _failures := PackedStringArray()


func _initialize() -> void:
	_check_loop_boundaries()
	_check_independent_clocks()
	_check_large_deltas()
	_check_invalid_inputs()
	if _failures.is_empty():
		print("Arena music clock checks passed: %d assertions." % _checks)
		quit(0)
	else:
		for failure: String in _failures:
			push_error(failure)
		print("Arena music clock checks failed: %d of %d assertions." % [_failures.size(), _checks])
		quit(1)


func _check_loop_boundaries() -> void:
	var clock := Clock.new()
	_expect(clock.duration_seconds == 0.0 and clock.get_position() == 0.0 and not clock.running, "An unconfigured clock is stopped at zero.")
	clock.advance(30.0)
	clock.seek(30.0)
	_expect(clock.get_position() == 0.0, "An unconfigured clock cannot advance or seek.")
	clock.configure(120.0)
	_expect(clock.running and clock.duration_seconds == 120.0 and clock.elapsed_seconds == 0.0, "A two-minute track starts running at phase zero.")
	clock.advance(119.75)
	_expect(clock.get_position() == 119.75, "Time before the loop boundary is preserved.")
	clock.advance(0.25)
	_expect(clock.get_position() == 0.0, "The exact 120-second boundary wraps to zero.")
	clock.advance(0.5)
	clock.advance(120.0)
	_expect(clock.get_position() == 0.5, "A complete loop preserves the current fractional phase.")
	clock.seek(119.5)
	clock.advance(2.0)
	_expect(clock.get_position() == 1.5, "Advancing across the loop end preserves overshoot.")
	clock.seek(-1.0)
	_expect(clock.get_position() == 119.0, "A negative seek wraps to the previous loop's phase.")
	clock.seek(241.25)
	_expect(clock.get_position() == 1.25, "Seeking beyond multiple loops preserves the independent offset.")
	clock.seek(-240.0)
	_expect(clock.get_position() == 0.0, "An exact negative loop boundary is zero.")


func _check_independent_clocks() -> void:
	var clocks: Array[RefCounted] = []
	for index: int in range(9):
		var clock := Clock.new()
		clock.configure(120.0)
		clocks.append(clock)
		_expect(clock.get_position() == 0.0, "Each arena starts at the same zero phase: %d." % index)
	for clock in clocks:
		clock.advance(7.5)
		_expect(clock.get_position() == 7.5, "Every arena advances independently of which one is audible.")
	var first: RefCounted = clocks[0]
	var second: RefCounted = clocks[1]
	second.seek(35.0)
	first.advance(13.0)
	second.advance(13.0)
	_expect(first.get_position() == 20.5 and second.get_position() == 48.0, "Seeking one arena leaves another arena's phase unchanged.")
	second.running = false
	first.advance(8.0)
	second.advance(8.0)
	_expect(first.get_position() == 28.5 and second.get_position() == 48.0, "Explicit pause affects only its own clock.")
	second.seek(-4.0)
	_expect(second.get_position() == 116.0 and not second.running, "Seeking a paused clock preserves its paused state.")
	second.advance(2.0)
	_expect(second.get_position() == 116.0, "A paused seek stays fixed until resumed.")
	second.running = true
	second.advance(5.0)
	_expect(second.get_position() == 1.0, "Resume continues from the saved independent phase.")
	first.configure(90.0, -5.0)
	_expect(first.get_position() == 85.0 and first.running and second.duration_seconds == 120.0 and second.get_position() == 1.0, "Reconfiguring one loop duration cannot alter another clock.")


func _check_large_deltas() -> void:
	var clock := Clock.new()
	clock.configure(120.0, 17.0)
	clock.advance(1000000007.0)
	_expect(clock.get_position() == 64.0, "A large finite delta skips many loops while preserving the offset.")
	clock.advance(120000000000.25)
	_expect(clock.get_position() == 64.25, "A billion full loops plus a fractional delta preserve subsecond phase.")
	clock.advance(1.0e308)
	_expect(is_finite(clock.get_position()) and clock.get_position() >= 0.0 and clock.get_position() < 120.0, "Extremely large finite time jumps remain finite and within the loop.")
	clock.configure(1.0e308, 9.0e307)
	clock.advance(9.0e307)
	_expect(is_finite(clock.get_position()) and absf(clock.get_position() / 1.0e308 - 0.8) < 0.000000000001, "Large finite phase and delta do not overflow when their unwrapped sum would.")
	clock.seek(-1.0)
	_expect(is_finite(clock.get_position()) and clock.get_position() >= 0.0 and clock.get_position() < clock.duration_seconds, "Modulo rounding never exposes the exclusive loop endpoint.")


func _check_invalid_inputs() -> void:
	var clock := Clock.new()
	clock.configure(120.0, 37.0)
	for delta: float in [0.0, -1.0, INF, -INF, NAN]:
		clock.advance(delta)
		_expect(clock.get_position() == 37.0 and clock.running, "Nonpositive or nonfinite deltas leave a valid running clock unchanged.")
	for phase: float in [INF, -INF, NAN]:
		clock.seek(phase)
		_expect(clock.get_position() == 37.0, "Nonfinite seeks leave the saved phase unchanged.")
	for duration: float in [0.0, -1.0, INF, -INF, NAN]:
		clock.configure(duration, 42.0)
		clock.advance(5.0)
		clock.seek(9.0)
		_expect(clock.duration_seconds == 0.0 and clock.get_position() == 0.0 and not clock.running, "Invalid duration disables and clears the clock safely.")
	clock.configure(120.0, NAN)
	_expect(clock.get_position() == 0.0 and clock.running, "A valid duration with invalid initial phase starts at zero.")
	clock.running = false
	clock.configure(120.0, 15.0)
	_expect(clock.get_position() == 15.0 and clock.running, "Valid reconfiguration restarts a previously paused or disabled clock.")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
