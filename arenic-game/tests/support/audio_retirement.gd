extends RefCounted
## Test teardown only. Godot retires stopped playbacks on the mixer thread,
## then releases their resources during a later main-thread AudioServer update.
## Frame-delta timers cannot prove that the mixer ran after a slow render frame.

static func wait_for_mixer(tree: SceneTree) -> bool:
	var stopped_at: int = Time.get_ticks_usec()
	var first_mix: int = -1
	var deadline: int = stopped_at + 2_000_000
	while Time.get_ticks_usec() < deadline:
		await tree.process_frame
		# This read locks the driver, so the observed mix has finished its work.
		var age: float = AudioServer.get_time_since_last_mix()
		var mixed_at: int = Time.get_ticks_usec() - roundi(age * 1_000_000.0)
		# A millisecond margin exceeds timestamp sampling jitter; it is not a
		# playback timeout or a substitute for observing the next mixer tick.
		if mixed_at <= stopped_at + 1_000:
			continue
		if first_mix < 0:
			first_mix = mixed_at
		elif mixed_at > first_mix + 1_000:
			await tree.process_frame
			await tree.process_frame
			return true
	push_error("Test teardown did not observe audio mixer retirement within two seconds.")
	return false
