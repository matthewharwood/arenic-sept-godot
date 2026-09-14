class_name ArenicArenaTimeline
extends RefCounted
## One arena's master score: every performer's staff merged into a single
## tick-ordered stream, plus the playback cursor that walks it.
##
## Playback never sees performers, layers or recordings — only this one array.
## That is what makes forty ghosts cost one sorted array and one cursor instead
## of forty playback loops, and it is why a boss staff and a recorded hero staff
## need no separate machinery.
##
## The staves are retained so the stream can be rebuilt: folding is defined as
## remove-then-add, which makes re-committing the same performer idempotent by
## construction rather than by the caller remembering to clean up first.

var events: Array[ArenicTimelineEvent] = []
var cursor: int = 0

var _staves: Dictionary[String, ArenicRecording] = {}
var _orders: Dictionary[String, int] = {}
var _next_order: int = 0


## Replaces `performer`'s staff and rewinds the cursor. Folding always
## accompanies a restart; the caller zeroes the clock and snaps performers to
## their start tiles. A performer keeps its original fold order across refolds,
## so re-committing never reshuffles who acts first within a tick.
func fold(performer: String, recording: ArenicRecording) -> void:
	if performer.is_empty() or recording == null:
		return
	if not _orders.has(performer):
		_orders[performer] = _next_order
		_next_order += 1
	_staves[performer] = recording
	_rebuild()
	cursor = 0


## Removes every event belonging to `performer` and resyncs the cursor so
## playback continues from `at_tick` without replaying what already happened.
## The arena does NOT restart: this is break-out, not rewind.
func unfold(performer: String, at_tick: int) -> void:
	if not _staves.has(performer):
		return
	# Contact defeat can unfold a performer after due() has already handed the
	# entire current tick to the conductor. Rebuilding must not make that tick
	# pending again for the survivors; an ordinary between-tick unfold still
	# starts at at_tick, whose events have not been consumed yet.
	var resume_tick: int = at_tick
	if cursor > 0:
		resume_tick = maxi(resume_tick, events[cursor - 1].tick + 1)
	_staves.erase(performer)
	# The fold order is kept. A performer that returns later reclaims its old
	# place in the tick, so breaking out and back in cannot change resolution.
	_rebuild()
	seek_to(resume_tick)


func has(performer: String) -> bool:
	return _staves.has(performer)


func staff(performer: String) -> ArenicRecording:
	return _staves.get(performer)


func performers() -> PackedStringArray:
	var ids: Array = _staves.keys()
	ids.sort()
	return PackedStringArray(ids)


func clear() -> void:
	_staves.clear()
	_orders.clear()
	_next_order = 0
	events.clear()
	cursor = 0


## Rewinds playback to the top of the cycle.
func restart() -> void:
	cursor = 0


## Places the cursor so every event stamped before `at_tick` counts as played
## and the events AT that tick are still pending — the state a cycle has when
## its clock reads `at_tick`.
func seek_to(at_tick: int) -> void:
	cursor = _partition(at_tick)


## The events already resolved at `at_tick`, and the cursor that goes with them.
## Scrubbing replays this window's moves from each performer's start tile;
## transient effects are skipped. Abilities and landings are not re-fired.
func seek_window(at_tick: int) -> Array[ArenicTimelineEvent]:
	var upto: int = _partition(at_tick + 1)
	return events.slice(0, upto)


## Advances the cursor past every event due at `at_tick`, returning them in
## resolution order. Playback applies them; the timeline never applies anything.
func due(at_tick: int) -> Array[ArenicTimelineEvent]:
	var ready: Array[ArenicTimelineEvent] = []
	while cursor < events.size() and events[cursor].tick <= at_tick:
		ready.append(events[cursor])
		cursor += 1
	return ready


func _rebuild() -> void:
	events.clear()
	for performer: String in _staves:
		var recording: ArenicRecording = _staves[performer]
		var order: int = _orders[performer]
		for index: int in recording.events.size():
			events.append(recording.events[index].stamped(performer, order, index))
	events.sort_custom(ArenicTimelineEvent.precedes)


## First index whose event is at or after `at_tick`.
func _partition(at_tick: int) -> int:
	var low: int = 0
	var high: int = events.size()
	while low < high:
		@warning_ignore("integer_division")
		var middle: int = (low + high) / 2
		if events[middle].tick < at_tick:
			low = middle + 1
		else:
			high = middle
	return low
