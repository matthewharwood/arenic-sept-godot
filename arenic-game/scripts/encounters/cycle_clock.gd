class_name ArenicCycleClock
extends RefCounted
## An arena's cycle position, counted in whole simulation ticks.
##
## Deterministic replay needs exact equality between the tick an event was
## stamped at and the tick it plays at. Float seconds cannot provide that: the
## error accumulated across a 7,200-tick loop drifts a recorded ghost off the
## boss pattern it was recorded against, and the drift compounds every cycle.
## So the encounter counts ticks and never seconds. The music director projects
## this integer position into continuous playback phase; audio never advances
## the authoritative game clock.

## Pinned in project settings. One physics step is exactly one simulation tick.
const TICKS_PER_SECOND: int = 60
const CYCLE_SECONDS: int = 120
const CYCLE_TICKS: int = CYCLE_SECONDS * TICKS_PER_SECOND

var tick: int = 0
## Transient presentation invalidation: distinguish explicit seeks from slow frames.
## Hydration rebuilds this counter; it is never part of recorded or saved rules.
var seek_revision: int = 0
var cycle_ticks: int = CYCLE_TICKS
## Only the arena that owns a modal or a countdown pauses. There is no global pause.
var paused: bool = false
## A completed authoritative reset awaits its cosmetic rewind/countdown.
## Independent of modal/recording pause ownership; saved without visual history.
var restart_pending: bool = false


func configure(length: int, start: int = 0) -> void:
	cycle_ticks = maxi(1, length)
	seek(start)


## Advances exactly one tick. Returns true when the cycle wrapped, which is the
## moment playback rewinds and every performer snaps back to its start tile.
func step() -> bool:
	if paused or restart_pending:
		return false
	tick += 1
	if tick < cycle_ticks:
		return false
	tick = 0
	return true


func seek(value: int) -> void:
	tick = posmod(value, cycle_ticks)
	seek_revision += 1


## Whole ticks from `from` forward to `to`, wrapping the cycle. Zero means the
## two positions are the same tick, not a full lap.
func ticks_between(from: int, to: int) -> int:
	return posmod(to - from, cycle_ticks)


static func seconds_to_ticks(seconds: float) -> int:
	return roundi(seconds * float(TICKS_PER_SECOND)) if is_finite(seconds) else 0


func seconds() -> float:
	return float(tick) / float(TICKS_PER_SECOND)


## `m:ss` of the current cycle position — the format every clock read-out shares.
func format() -> String:
	@warning_ignore("integer_division")
	var total: int = tick / TICKS_PER_SECOND
	@warning_ignore("integer_division")
	return "%d:%02d" % [total / 60, total % 60]
