# Activity events and Global Chat

Global Chat shows system activity from the current game session: raid damage,
available recruits, recruited heroes, recording transitions, and actual defeats.
There is no message composer, network chat service, or invented boss activity.
The [HUD](hud.md) displays the events; existing models still decide every effect.

## One event API

[`ArenicEventBus`](../arenic-game/scripts/events/event_bus.gd) exposes
`subscribe(callback)`, `unsubscribe(callback)`, and `dispatch(event)`. Every
callback receives the same concrete
[`ArenicGameEvent`](../arenic-game/scripts/events/game_event.gd) type. Its envelope
contains `event_type: StringName`, a plain `payload: Dictionary`, `severity`, and
`importance`. The bus adds its own sequence and monotonic observation time.
These values identify delivery within one shell lifetime, not a saved run clock.

```gdscript
var bus := ArenicEventBus.new()
var observer: Callable = func(event: ArenicGameEvent) -> void:
	print(event.event_type, event.payload)
var subscribed: bool = bus.subscribe(observer)
var delivered: bool = bus.dispatch(ArenicGameEvent.create(
	&"raid.damage", {"arena_id": "guild_house", "amount": 1,
		"hero_id": 0, "hero_name": "Dean", "ability_id": "auto_shot", "ability_name": "Auto Shot"},
	ArenicGameEvent.Severity.DEBUG, ArenicGameEvent.Importance.LOW))
var removed: bool = bus.unsubscribe(observer)
```

The example demonstrates the API shape. Real publishers dispatch after the
owning model applies the observed action; subscribers do not use observations
as commands. Each API returns success and exposes a rejection through
`last_error`. The shell owns the bus and feed and releases their subscription
when it exits.

Delivery is synchronous with at most 32 subscribers. Each listener receives its
own copied envelope and payload, so one observer cannot change another's
message. Subscription changes affect the next dispatch; freed receivers are
skipped. Recursive dispatch is rejected. The envelope permits at most 32 flat
payload keys, 96-character event/key identifiers, and 256-character strings;
other values must be integers, finite floats, or booleans. There is no generic
object graph or unbounded event queue.

## Feed vocabulary and presentation

[`ArenicActivityFeed`](../arenic-game/scripts/ui/activity_feed.gd) subscribes to
the bus and validates the payload for each supported event. Unknown types or
malformed domain payloads do not produce a feed entry. Other subscribers can
interpret additional types without extending the bus or adding event subclasses.

| Event type | Payload | Current meaning |
| --- | --- | --- |
| `raid.damage` | `arena_id`, positive integer `amount`, `hero_id`, `hero_name`, `ability_id`, `ability_name` | Damage already applied anywhere, attributed to the actual caster and authored attack, including remote ghost activity. |
| `recruit.ready` | Integer `available` | Current unclaimed hero count; changing this notice never grants a roll. |
| `guild.hero_recruited` | `hero_id`, `hero_name` | A real guild member has arrived. |
| `recording.status` | `hero_id`, `hero_name`, `arena_id`, `status` | Countdown, recording, paused, resumed, committed, discarded, or cancelled. |
| `hero.defeated` | `hero_id`, `hero_name`, `arena_id`, boolean `recorded`, optional `cause` | A real defeat. `recorded` describes return next cycle; free or selected-contact victims return to the Guild House. Cause is `attack` or `contact`. |
| `notice` | `text` | An explicit observation, including real save failures and successful recovery. |

Severity describes the occurrence; importance describes the player's need to
notice it. The enum values are `DEBUG`, `INFO`, `WARNING`, `ERROR` and independently
`LOW`, `NORMAL`, `HIGH`. A recruit becoming available is `INFO` with `HIGH`
importance. It appears red because it is actionable, without being labeled an
error. Damage uses `DEBUG`/`LOW` and appears gray.

The [view](../arenic-game/scripts/ui/activity_feed_view.gd) chooses colors through
semantic HUD tokens: ordinary information uses arena content ink, debug uses
gray, warnings use yellow with `!`, errors use red with an `Error` prefix, and
high-importance information uses red with `!`. Warning/error styling takes
precedence over importance. Producers contain no colors or UI formatting.
Expanded-history filters select all entries, informational-or-higher notices,
warnings-or-higher, or high importance independently.

The shell's save-status adapter publishes actual `SaveGames` failures as `ERROR`/`HIGH` notices,
with whitespace normalized and text limited to 256 characters. Identical errors
are deduplicated. An `INFO` recovery notice appears only after a subsequent save
succeeds; beginning a retry does not claim recovery.

Damage reads `Dean · Auto Shot · 3 damage · Labyrinth`: the actor and attack
come first so they remain visible in the compact view. `ability_name` comes from
the authored ability title, including `Sacrifice` for the stable `heal` ID.
The ledger emits attribution when a hit actually applies, using its own cast
owner. The shell never borrows the currently selected hero or the most recent
cast. Missed, rejected and cancelled attacks produce no damage row.

Acid pools and successfully dug tiles retain their original caster identity for
later damage, even when another hero is selected or the game reloads. Re-digging
a tile does not steal its owner. Old saves lack that provenance: their existing
hazards show `Unknown hero · Acid Flask` or `Unknown hero · Dig` until the cycle
clears them. Source-less environmental damage reads `Environment`; it never
invents a hero. See the [save contract](save-state.md) for schema-3 migration.

The model keeps the latest 100 history entries and at most 100 pending damage
buckets, keyed by arena, hero identity and attack ID. Damage is summed over
one-second presentation windows in stable key order. Different heroes or attacks
never merge. At capacity, pending rows flush early before admitting another
source; the queue cannot grow without bound. Entries retain the source fields
and exact combined amount for other views. This coalescing never modifies the
combat ledger. The compact view has four lines; an unclaimed-recruit reminder
occupies one until claimed, with the other lines following recent activity.
Long compact text retains a full tooltip and can be read in expanded history.

## Lifetime and validation

Event delivery and activity history are transient. A replacement stage keeps
the current shell's feed. Loading a run creates a fresh history, then reports
current recruitment availability and active recording status after hydration.
Old damage is never reconstructed as new activity. Saved hazard ownership is
durable provenance, while messages and feed history remain transient;
[save ownership](save-state.md#state-ownership-and-restoration) records these
separate restore behaviors.

Relevant checks cover bus isolation and rejection, bounded aggregation,
recruitment attention, real recording and defeat observations, C/header history
controls, actual combat-to-feed delivery, and the preserved native world area.
Native and browser runs establish validation separately; this contract is not a
claim that a particular build has passed or been deployed.

## Design references

The single subscription point follows the purpose of Martin Fowler's
[Event Aggregator](https://martinfowler.com/eaaDev/EventAggregator.html).
Separating common envelope metadata from event payload takes inspiration from
[CloudEvents 1.0.2](https://github.com/cloudevents/spec/blob/v1.0.2/cloudevents/spec.md).
Explicit severity and observed time draw on the
[OpenTelemetry log data model](https://opentelemetry.io/docs/specs/otel/logs/data-model/),
while severity-based history filters follow the familiar
[DevTools console filtering](https://developer.chrome.com/docs/devtools/console/log/)
pattern. These are design principles only: Arenic adds no dependency or protocol
adapter and claims no compliance with those specifications.

Contact defeats use the optional `cause: "contact"` field on `hero.defeated`; ordinary attacks use `"attack"`. The feed also accepts the original payload without that field. Unknown causes are rejected. Completed gathering deposits publish an informational `notice` naming the actual hero, resource and accepted amount; restoring a bank does not replay notices.
