extends SceneTree
## The fold / unfold contract, in isolation. No arena, shell, renderer or clock.
## Godot --headless --path arenic-game --script res://tests/encounters/timeline_checks.gd

const A: String = "hero:1"
const B: String = "hero:2"
const C: String = "hero:3"

var _checks: int = 0
var _failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_order()
	_check_idempotent_fold()
	_check_unfold()
	_check_cursor()
	_check_seek()
	_check_partial_staff()
	_check_determinism()
	_finish()


## Merged order is total: when, then whose, then where in the staff. Godot's
## sort is unstable, so ties have to be broken explicitly or two runs differ.
func _check_order() -> void:
	var timeline := ArenicArenaTimeline.new()
	timeline.fold(A, _staff([5, 10]))
	timeline.fold(B, _staff([5, 7]))
	_check(_ticks(timeline) == [5, 5, 7, 10], "Folding merges both staves into one tick-ordered stream.")
	_check(timeline.events[0].performer == A and timeline.events[1].performer == B, "Within one tick the earlier-folded performer resolves first.")
	timeline.fold(C, _staff([5]))
	_check(_performers_at(timeline, 5) == [A, B, C], "A later performer joins the back of a contested tick.")
	var same_tick := ArenicArenaTimeline.new()
	same_tick.fold(A, _staff([3, 3, 3]))
	_check(_indices(same_tick) == [0, 1, 2], "One performer's simultaneous events keep the order they were recorded in.")


## Re-committing the same performer must not double its events.
func _check_idempotent_fold() -> void:
	var timeline := ArenicArenaTimeline.new()
	var staff := _staff([5, 10])
	timeline.fold(A, staff)
	timeline.fold(B, _staff([7]))
	timeline.fold(A, staff)
	_check(timeline.events.size() == 3, "Refolding a performer replaces its events rather than adding them again.")
	_check(_count_for(timeline, A) == 2, "The refolded performer keeps exactly one copy of its staff.")
	_check(timeline.cursor == 0, "A fold rewinds the cursor, because folding accompanies a restart.")
	timeline.fold(A, _staff([1, 2, 3, 4]))
	_check(_count_for(timeline, A) == 4 and timeline.events.size() == 5, "Recording over a performer replaces the whole staff, not just the overlap.")


## Break-out removes one performer and leaves the others playing.
func _check_unfold() -> void:
	var timeline := ArenicArenaTimeline.new()
	timeline.fold(A, _staff([5, 10]))
	timeline.fold(B, _staff([7]))
	timeline.cursor = 2
	timeline.unfold(A, 8)
	_check(timeline.events.size() == 1 and timeline.events[0].performer == B, "Unfolding removes exactly one performer's events.")
	_check(timeline.cursor == 1, "The cursor resyncs so the remaining performer does not replay what it already did.")
	_check(not timeline.has(A) and timeline.has(B), "The timeline reports who is still folded in.")
	timeline.unfold(C, 0)
	_check(timeline.events.size() == 1, "Unfolding a performer that was never folded changes nothing.")
	# Breaking out and back in must not change who acts first within a tick.
	timeline.fold(A, _staff([7]))
	_check(_performers_at(timeline, 7) == [A, B], "A returning performer reclaims its original place in a contested tick.")


## The cursor walks each tick's events exactly once.
func _check_cursor() -> void:
	var timeline := ArenicArenaTimeline.new()
	timeline.fold(A, _staff([0, 3, 3, 9]))
	_check(timeline.due(0).size() == 1, "Tick zero resolves like any other tick.")
	_check(timeline.due(0).is_empty(), "A tick's events resolve once, not every time it is asked.")
	_check(timeline.due(2).is_empty(), "A tick with no events resolves nothing.")
	_check(timeline.due(3).size() == 2, "Both events stamped for one tick resolve together.")
	_check(timeline.due(20).size() == 1, "A late tick sweeps up everything still pending.")
	_check(timeline.due(20).is_empty(), "A drained stream stays drained.")
	timeline.restart()
	_check(timeline.due(0).size() == 1, "Restarting rewinds the stream to the top of the cycle.")


## Seeking leaves the target tick's events pending: that is the state a cycle
## has when its clock reads that tick, before the tick is played.
func _check_seek() -> void:
	var timeline := ArenicArenaTimeline.new()
	timeline.fold(A, _staff([0, 3, 7]))
	timeline.fold(B, _staff([3]))
	timeline.seek_to(3)
	_check(timeline.cursor == 1, "Seeking counts only the events strictly before the target tick as played.")
	_check(timeline.due(3).size() == 2, "The target tick's events are still due after a seek.")
	timeline.seek_to(0)
	_check(timeline.cursor == 0, "Seeking to zero leaves the whole cycle pending.")
	timeline.seek_to(9999)
	_check(timeline.cursor == timeline.events.size(), "Seeking past the end counts the whole cycle as played.")
	_check(timeline.seek_window(3).size() == 3, "The replay window through a tick includes that tick's events.")
	_check(timeline.seek_window(2).size() == 1, "The window stops short of a tick that has not arrived.")


## A partial commit is simply a shorter staff.
func _check_partial_staff() -> void:
	var timeline := ArenicArenaTimeline.new()
	timeline.fold(A, _staff([0, 3]))
	var resolved: int = 0
	for at_tick: int in 400:
		resolved += timeline.due(at_tick).size()
	_check(resolved == 2, "A partial staff plays through and then idles for the rest of the cycle.")


## The same folds in the same order must produce byte-identical streams.
func _check_determinism() -> void:
	var first := ArenicArenaTimeline.new()
	var second := ArenicArenaTimeline.new()
	for timeline: ArenicArenaTimeline in [first, second]:
		timeline.fold(B, _staff([4, 4, 9]))
		timeline.fold(A, _staff([4, 6]))
		timeline.fold(C, _staff([4]))
	var left: Array = []
	var right: Array = []
	for index: int in first.events.size():
		left.append([first.events[index].tick, first.events[index].performer, first.events[index].index])
		right.append([second.events[index].tick, second.events[index].performer, second.events[index].index])
	_check(left == right, "Identical fold sequences produce identical streams.")
	_check(_performers_at(first, 4) == [B, B, A, C], "Fold order, not performer name, decides a contested tick.")


static func _staff(ticks: Array) -> ArenicRecording:
	var events: Array[ArenicTimelineEvent] = []
	for at_tick: int in ticks:
		events.append(ArenicTimelineEvent.move(at_tick, Vector2i.RIGHT))
	return ArenicRecording.create(Vector2i(30, 15), events)


static func _ticks(timeline: ArenicArenaTimeline) -> Array:
	var result: Array = []
	for event: ArenicTimelineEvent in timeline.events:
		result.append(event.tick)
	return result


static func _indices(timeline: ArenicArenaTimeline) -> Array:
	var result: Array = []
	for event: ArenicTimelineEvent in timeline.events:
		result.append(event.index)
	return result


static func _performers_at(timeline: ArenicArenaTimeline, at_tick: int) -> Array:
	var result: Array = []
	for event: ArenicTimelineEvent in timeline.events:
		if event.tick == at_tick:
			result.append(event.performer)
	return result


static func _count_for(timeline: ArenicArenaTimeline, performer: String) -> int:
	var total: int = 0
	for event: ArenicTimelineEvent in timeline.events:
		if event.performer == performer:
			total += 1
	return total


func _check(passed: bool, message: String) -> bool:
	_checks += 1
	if not passed:
		_failed = true
		print("Timeline assertion failed: ", message)
	return passed


func _finish() -> void:
	if _failed:
		quit(1)
		return
	print("Timeline checks passed: %d assertions; fold order, idempotence, break-out, cursor and determinism." % _checks)
	quit(0)
