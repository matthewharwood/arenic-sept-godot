class_name ArenicRecording
extends RefCounted
## One performer's staff for one arena: the tile it stood on at tick zero, plus
## its tick-ordered events.
##
## The start tile anchors every replay — a staff stores intent, never position,
## so the same events replayed from a different tile describe a different path.
## A partial staff is simply a shorter event list: it plays through, then idles
## for the rest of every cycle.

var start_cell: Vector2i = Vector2i.ZERO
var events: Array[ArenicTimelineEvent] = []


static func create(start: Vector2i, staff: Array[ArenicTimelineEvent]) -> ArenicRecording:
	var recording := ArenicRecording.new()
	recording.start_cell = start
	recording.events = staff.duplicate()
	recording.events.sort_custom(func(l: ArenicTimelineEvent, r: ArenicTimelineEvent) -> bool: return l.tick < r.tick)
	return recording


func is_empty() -> bool:
	return events.is_empty()


func last_tick() -> int:
	return events[events.size() - 1].tick if not events.is_empty() else 0
