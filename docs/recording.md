# Recording and ghosts

A hero records a **two-minute staff** of intent for the arena it stands in.
Committing folds that staff into the arena's master timeline, and the hero
becomes a **ghost**: playback drives it, input no longer does, and it repeats the
same path every cycle without the player.

Ghosts are the point of the game. They are how one player runs several arenas at
once, and how damage keeps accruing while attention is elsewhere.

## The loop

1. **R** with a hero selected and focused. No modal where there is no real
   choice — a hero with no staff for this arena goes straight to a **3-second
   countdown**, which holds that arena at tick 0 and swallows every input but R.
2. Capture runs as the clock ticks 0 → 2:00. Movement and casts register as
   **intent**, stamped with the arena's current tick.
3. **Commit** caches the staff against the arena, folds it into the stream,
   returns the hero to its start tile, and restarts the arena.
4. Every cycle from then on, the ghost replays that staff exactly.

| Moment | Decision |
| --- | --- |
| R, no staff here | none — countdown begins |
| R, staff cached here | Record new · Replay previous · Cancel |
| R, on a ghost | Record new (unfolds it first) · Cancel |
| R, while recording | Commit · Keep recording · Discard |
| R, during the countdown | aborts it — the only input it accepts |
| clock reaches 2:00 | Commit · Discard |
| arrow, on a ghost | Take control · Restart arena · Cancel |
| step past the arena edge, recording | Continue recording · Cancel & walk out · Commit & stay |
| walking into an arena with a staff | Replay previous · Continue without |

A take always belongs to the hero that started it, so **Tab is refused while
recording**. Camera keys never interrupt one: watching another arena mid-take is
safe, because only the recording arena is ever paused.

## Intent, not position

A staff stores what the player pressed, never where the hero ended up, and
replays it from the tile recorded at tick 0. Two rules keep that faithful:

**Capture is atomic with the live effect.** The move is written in the same
branch that applies the step, and the cast in the same branch that combat
accepts. A step that is reverted — walking into a boss — leaves no phantom event,
and a cast that combat refuses records nothing.

**Recorded moves never edge-walk.** Live input may carry a hero into an adjacent
arena; the same event on playback clamps at the arena edge. A ghost that walked
out would be folded into a timeline it no longer stands in. While recording, the
hero is fenced inside its arena for the same reason — the mid-take travel
decision is not built yet.

## Ghosts

`is_ghost()` is **derived** from whether the hero's staff is folded into its
arena's stream, never stored, so the two can never disagree. A ghost wears a blue
ring beside the controlled hero's arena-coloured one.

Whenever an arena restarts — a natural wrap, a commit, a replay, a record-new,
or **Restart arena** — every ghost in it returns to its start tile and to a clean
cast state. Breaking a ghost out with **Take control** is the one path that does
**not** restart: its events leave the stream, the arena keeps playing from
exactly where it was, and the hero is free at its current tile. A broken-out hero
keeps its cached staff, so R offers to fold it back in.

Stepping past an arena edge mid-take asks before anything is lost: continuing
abandons the step, walking out discards the take and *then* performs it, and
committing folds the partial staff and keeps the hero where it is. At the outer
border of the 3×3 world there is no neighbour, so the step simply clamps and is
recorded as played.

## Dying

Death is **derived, never recorded**. There is no death event in a staff.

A **ghost** struck by a landing dies *in place*: it stops where it fell, neither
moving nor casting for the rest of the cycle, and rises at its start tile when
the arena restarts. Walking it home would resume its recorded intent in an arena
it is not folded into, and replay would be meaningless.

Because the boss pattern is fixed and the ghost's intent is fixed, a ghost that
dies once dies **at the same tick every cycle** until its staff is re-recorded.
That is the feedback loop: the arena tells you exactly which second of your
choreography is wrong.

A **free** hero — one not folded into a stream — returns to Guild House
`(30, 15)` and is restored there, whether or not the player is controlling it.
Level, experience, arena damage and phase progress all survive. If the hero dying
is the one mid-take, the take is discarded: a recording cannot outlive its own
hero being killed out of the arena.

## Ghosts fight

A recorded cast resolves through **exactly the same door** a live cast uses —
`try_cast` — so a ghost's ability can never drift from the player's. Every caster
owns its own in-flight cast and its own cooldown, keyed by run identity, so a
refusal is always that caster's own state and never a collision with the player
or with another ghost.

Two consequences worth knowing:

**Advancing the model no longer cancels other casters.** The model used to cancel
any cast whose owner was not the hero passed to `tick`. With ghosts in the arena
that rule would cancel every ghost's cast on every frame the player was ticked.
A cast now ends only when its own caster's rules end it.

**Every arena restart returns its ghosts to a clean cast state**, not just to
their start tiles. A ghost carrying a cooldown or a projectile in flight across
the seam would play its second cycle differently from its first, and replay has
to be identical every time.

Slots 2-4 remain unassigned and inert on both sides, so they are recorded and do
nothing — exactly as before.

Ability *sound* still follows the hero the player controls; a ghost's cast is
silent. Per-caster spatial ability audio is its own change.

## Limits and read-out

An arena holds at most **40 ghosts**, and the guild at most **320** members. The
cap is checked *before* the countdown, so nobody spends two minutes recording
into an arena that is already full; a hero already folded there may always
re-record, because replacing a staff does not grow the arena. If an arena fills
up while a take is running, the staff is still cached — the work is never thrown
away, it simply waits for room.

The record control doubles as the read-out: the countdown before a take, `REC`
and the cycle clock during one, and `Ghost` when the selected hero is folded in.

The 3×3 map counts **ghosts**, not members. An arena where guild members stand
idle still reads `X`, because the map answers *where is my guild working* — its
tooltip gives both numbers. In the roster strip a folded member wears the same
blue ring it wears in the world, so a selected ghost reads as both at once.

## Timing

Everything is in whole ticks at 60 Hz: `CYCLE_TICKS` 7,200 and `COUNTDOWN_TICKS`
180. See [battle sequences](encounters.md) for the clock contract and the master
timeline's fold / unfold rules, which recording shares rather than duplicates.
