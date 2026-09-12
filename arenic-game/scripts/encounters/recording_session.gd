class_name ArenicRecordingSession
extends RefCounted
## The one in-flight recording. Exactly one exists at a time, and the draft staff
## is empty unless one is.
##
## Capture is INTENT, stamped with the recording arena's tick. It is written
## where the live effect happens — the same branch that steps the hero or
## accepts the cast — so a committed staff can never contain an event the live
## take did not perform, or miss one it did.

enum State { IDLE, COUNTDOWN, RECORDING }

## Three seconds to get ready. The recording arena is held at tick zero for it.
const COUNTDOWN_TICKS: int = 3 * ArenicCycleClock.TICKS_PER_SECOND

var state: State = State.IDLE
var countdown_left: int = 0
var identity: int = -1
var performer: String = ""
var arena_id: String = ""
var start_cell: Vector2i = Vector2i.ZERO
var events: Array[ArenicTimelineEvent] = []


func is_idle() -> bool:
	return state == State.IDLE


func is_counting_down() -> bool:
	return state == State.COUNTDOWN


func is_recording() -> bool:
	return state == State.RECORDING


## True while this session belongs to `hero` — capture never writes to a draft
## owned by someone else, which is why Tab is refused mid-recording.
func owns(hero: ArenicHeroState) -> bool:
	return hero != null and identity == hero.identity_id and not is_idle()


## Starts the countdown. The caller holds the arena at tick zero.
func arm(hero: ArenicHeroState) -> void:
	state = State.COUNTDOWN
	countdown_left = COUNTDOWN_TICKS
	identity = hero.identity_id
	performer = hero.ally_id()
	arena_id = hero.arena_id
	start_cell = hero.cell
	events.clear()


## Counts one tick off the countdown. Returns true on the tick capture begins.
func advance_countdown() -> bool:
	if state != State.COUNTDOWN:
		return false
	countdown_left -= 1
	if countdown_left > 0:
		return false
	countdown_left = 0
	state = State.RECORDING
	return true


## Whole seconds still showing on the countdown, for the HUD.
func countdown_seconds() -> int:
	return ceili(float(countdown_left) / float(ArenicCycleClock.TICKS_PER_SECOND))


func capture(event: ArenicTimelineEvent) -> void:
	if state == State.RECORDING and event != null:
		events.append(event)


## Builds the staff and ends the session. A partial take is simply a shorter
## event list: the ghost plays it, then idles for the rest of every cycle.
func take() -> ArenicRecording:
	var recording := ArenicRecording.create(start_cell, events)
	clear()
	return recording


func clear() -> void:
	state = State.IDLE
	countdown_left = 0
	identity = -1
	performer = ""
	arena_id = ""
	events.clear()
