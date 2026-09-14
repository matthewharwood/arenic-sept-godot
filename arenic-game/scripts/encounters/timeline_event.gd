class_name ArenicTimelineEvent
extends RefCounted
## One intent on a staff: an action at an exact cycle tick.
##
## The vocabulary is deliberately one list, not a hierarchy. A richer action
## extends this type and gains an arm in `ArenicEncounterState`; it never forks
## the event format, because every performer — boss, minion, recorded hero —
## shares one merged stream and one comparison order.
##
## `performer`, `order` and `index` are stamped when the event is folded into an
## arena; a stored staff leaves them unset.

const MOVE: StringName = &"move"
const ABILITY: StringName = &"ability"
const BOSS_JUMP: StringName = &"boss_jump"
const BOSS_MASK: StringName = &"boss_mask"
const ACTIONS: Array[StringName] = [MOVE, ABILITY, BOSS_JUMP, BOSS_MASK]

var tick: int = 0
var action_id: StringName = MOVE
## A one-tile step intent. Playback clamps it; only live input may edge-walk.
var delta: Vector2i = Vector2i.ZERO
## Ability slot 1-4, mirroring the hotbar.
var slot: int = 0
## Authored payload for a boss action. Stored staves reference the resource.
var score_event: ArenicScoreEvent
var beat: ArenicEncounterBeat

var performer: String = ""
## Fold order of the performer, then position within its staff. Together with
## the tick these are a total order, so two runs resolve simultaneous events
## identically. Godot's sort is not stable, so this cannot be left implicit.
var order: int = 0
var index: int = 0


static func move(at_tick: int, step: Vector2i) -> ArenicTimelineEvent:
	var event := ArenicTimelineEvent.new()
	event.tick = at_tick
	event.action_id = MOVE
	event.delta = step
	return event


static func ability(at_tick: int, ability_slot: int) -> ArenicTimelineEvent:
	var event := ArenicTimelineEvent.new()
	event.tick = at_tick
	event.action_id = ABILITY
	event.slot = ability_slot
	return event


static func boss_jump(from_beat: ArenicEncounterBeat) -> ArenicTimelineEvent:
	var event := ArenicTimelineEvent.new()
	event.tick = from_beat.at_tick
	event.action_id = BOSS_JUMP
	event.beat = from_beat
	return event


## A copy stamped for one performer's place in one arena's merged stream.
func stamped(owner_id: String, fold_order: int, staff_index: int) -> ArenicTimelineEvent:
	var event := ArenicTimelineEvent.new()
	event.tick = tick
	event.action_id = action_id
	event.delta = delta
	event.slot = slot
	event.beat = beat
	event.score_event = score_event
	event.performer = owner_id
	event.order = fold_order
	event.index = staff_index
	return event


## Total order for the merged stream: when, then whose, then where in the staff.
static func precedes(left: ArenicTimelineEvent, right: ArenicTimelineEvent) -> bool:
	if left.tick != right.tick:
		return left.tick < right.tick
	if left.order != right.order:
		return left.order < right.order
	return left.index < right.index
