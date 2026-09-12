# Battle sequences

Every arena owns a **two-minute battle cycle**, counted in whole simulation
ticks. A cycle is authored as a *score*: a staff of ordered beats, each one an
action that resolves at an exact tick inside the cycle. The score is data.
Nothing about a sequence is written in a system, a tween, or a node.

## Ticks, never seconds

`project.godot` pins `physics_ticks_per_second` to **60**, and one physics step
is exactly one simulation tick. `CYCLE_TICKS` is 7,200. Every authored position,
every resolved beat, and every future recorded event is a whole tick.

This is a contract, not a detail. Recorded hero timelines replay against these
same beats, and replay is only deterministic if the tick an event was stamped at
equals the tick it plays at. Float seconds cannot promise that: the error
accumulated across a 7,200-tick loop drifts a ghost off the pattern it was
recorded against, and compounds every cycle. Changing the tick rate changes what
every authored score and every stored recording means.

The music director keeps its own float clock, because audio playback genuinely
is continuous. The two are nominally the same two minutes; they are no longer
the same clock, and the tick clock is the authority.

Only the Labyrinth has an authored score today. The other eight arenas keep their
resting boss and no battle sequence, which is a normal authoring state rather
than a missing feature.

## The sheet-music model

| Term | Type | Meaning |
| --- | --- | --- |
| Stream | `ArenicArenaTimeline` | Every performer's staff merged into one tick-ordered array. |
| Staff | `ArenicRecording` | One performer's start tile plus its ordered events. |
| Event | `ArenicTimelineEvent` | One intent at one tick. |
| Cycle | `cycle_ticks` | The looping two-minute bar every arena repeats: 7,200 ticks. |
| Score | `ArenicEncounterScore` | One arena's staff at one difficulty. |
| Beat | `ArenicEncounterBeat` | One action at one cycle position. |
| Conductor | `ArenicEncounterState` | Performs scores against the combat ledger. |
| Clock | `ArenicCycleClock` | One arena's integer cycle position, and its pause flag. |
| Catalogue | `ArenicEncounterCatalog` | Every score, addressed by arena and difficulty. |

`at_tick` is when a beat **resolves**, not when its motion starts. A jump
therefore occupies `[at_tick - travel_ticks, at_tick]` in the air and lands
exactly on the beat, so a score reads like struck notes rather than like
windups. Beats are strictly ordered, every position lies inside `[0, cycle)`, and
a beat may not leave before the previous one resolves; the score rejects all
three mistakes rather than silently dropping a beat.

The beat at or before position zero is where the boss stands when the cycle
restarts. An arena's authored `boss_origin_cell` must match it, so nothing jumps
on the first frame of a run.

Difficulties (`normal`, `heroic`, `mythic`) own **separate scores**, not scaled
copies of one timeline: Heroic may rewrite an encounter outright. Only `normal`
is authored today, and the active tier is fixed to it.

## The Labyrinth, Normal

Seventeen beats. The Hunter opens at the arena centre for eight seconds, then
runs four laps of four stations at seven seconds each, wrapping exactly on two
minutes.

```
 tick 0     480  900 1320 1740 2160 ...                          6780   7200
 |----------|----|----|----|----|--- ... ---------------------------|------|
 centre     1    2    3    4    1                                   4     (loop)
 (30,12)  (30,20)(30,4)(54,12)(6,12)
```

Each landing takes 72 ticks (1.2 s) in the air, peaks 6 tiles up, and strikes a
**7-tile radius**. Stations are the lower-left cell of the boss's 6 × 6 gameplay
footprint; station 1 is north, 2 south, 3 east, 4 west.

## One stream, one cursor

Playback never sees scores, layers or performers. At configure the authored boss
score converts to a **staff** and folds into the arena's **master timeline**; the
timeline is then a single tick-ordered array with a cursor. Each tick resolves
the events stamped for it, the clock advances, and on the wrap the cursor returns
to the top so tick zero replays like any other tick.

That is the whole of playback, and it is why a recorded hero needs no new
machinery: a ghost is a performer whose staff was captured instead of authored.
Forty of them cost one sorted array and one cursor, not forty playback loops.

`fold` is defined as **remove-then-add**, so re-committing a performer is
idempotent by construction rather than by the caller remembering to clean up.
`unfold` removes one performer and resyncs the cursor to the current tick, so the
arena keeps playing without replaying what already happened — that is break-out,
and it is the one path that does not restart the arena. A performer keeps its
original fold order across a refold or a break-out and back, so who acts first
within a contested tick never silently changes.

Godot's sort is **not stable**, so order cannot be left implicit. Merged events
compare on tick, then the performer's fold order, then position within its staff
— a total order, so two runs resolve simultaneous events identically.

## What a landing does

The footprint moves first, then the blast resolves, so the landing and the ground
the boss now occupies are one event to anything reading the ledger. Accumulated
damage travels with the target: a jump never resets a phase.

A blast strikes **support actors only**; targets stay immortal, and a landing
adds nothing to the arena damage ledger. A struck hero is defeated and respawns
at Guild House `(30, 15)` with full health. Level, experience, arena damage and
phase progress all survive; only position and health are restored. Any active
cast is cancelled.

Hero abilities keep the Chebyshev metric because they are authored against tile
reach. A blast is an authored circle, so it uses **true radial distance** from
the landing footprint's centre. That is the one deliberate difference between the
two, and it is why a blast is drawn as a circle.

## Timing and determinism

`GameShell._physics_process()` advances the conductor exactly one tick per step,
immediately **after** `ArenicCombatState.tick`, so ally positions are synced
before any landing resolves. The conductor never reads a delta, so a slow frame
drops a tick rather than skewing one. A camera sequence pauses both.
There is no node timer, tween, or audio dependency; the music director keeps its
own clocks for playback, and nothing in a sequence reads them.

Every arena's cycle advances, including unfocused ones, so a battle sequence is
never something that only happens where the camera looks.

Rendered boss motion is **derived** from cycle position and never stored, so a
seek, a stage swap, or a dropped frame cannot desynchronise what is drawn from
what was struck. Ghost position will not work this way: intent replayed from a
start tile is path-dependent and has to be replayed rather than derived. Both
read the same clock.

Because the clock counts whole ticks and a slow frame drops a step rather than
batching one, a span longer than the cycle only arises from a deliberate call. It
advances tick by tick and resolves every lap it actually covered: a lap that
elapsed is a lap that happened.

## Presentation, and what is deliberately provisional

The rig is a top-down **orthographic** camera, so raising a sprite on `+Y` moves
it nowhere on screen. Height reads as **scale** instead: the boss grows as it
rises toward the viewer and returns to size as it lands. The small world lift is
kept only so an airborne boss sorts above ground decoration.

`ArenicBossBlastRing` marks lethal ground for 150 ticks (2.5 s) before a landing — longer
than the 1.2 s arc, because an unannounced instant kill is not readable — then
flashes on the beat. It is intentionally primitive geometry and decides nothing;
authored blast artwork replaces it wholesale. A ground shadow under an airborne
boss would improve the read and does not exist yet.

Recording, richer beat actions, tile choreography, per-difficulty loadouts, and
authored landing art are future work. The beat vocabulary is meant to grow by
adding actions to `ArenicEncounterBeat.ACTION_IDS` and a matching arm in
`ArenicEncounterState._resolve`, never by forking the score format.
