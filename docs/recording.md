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
   countdown**, which holds that arena at tick 0 and ignores movement/casts.
   R aborts; navigating to another arena also cancels.
2. Capture runs as the clock ticks 0 → 2:00. Movement and casts register as
   **intent**, stamped with the arena's current tick.
3. **Commit** caches the staff against the arena, folds it into the stream,
   returns the hero to its start tile, and restarts the arena through the visual
   rewind and three-second countdown.
4. Every cycle from then on, the ghost replays that staff exactly.

| Moment | Decision |
| --- | --- |
| R, no staff here | none — countdown begins |
| R, staff cached here | Record new · Replay previous · Cancel |
| R, on a ghost | Record new (unfolds it first) · Cancel |
| R, while recording | Commit · Keep recording · Discard |
| R, during the countdown | aborts it and releases its arena pause |
| clock reaches 2:00 | Commit · Discard |
| selected recorder dies mid-take | discard draft immediately; return home; source arena keeps running |
| arrow, on a ghost | Take control · Restart arena · Cancel |
| accepted step into another arena, recording | discard immediately and perform the step |
| navigate to another arena, recording/countdown | discard immediately; release the recording pause |
| walking into an arena with a staff | Replay previous · Continue without |

A take always belongs to the hero that started it, so **Tab is refused while
recording**. Navigating to another arena cancels the active take. Zooming to Overview without
changing the focused arena is still allowed; it does not move the hero.

## Intent, not position

A staff stores what the player pressed, never where the hero ended up, and
replays it from the tile recorded at tick 0. Two rules keep that faithful:

**Capture is atomic with the live effect.** The move is written in the same
branch that applies the step, and the cast in the same branch that combat
accepts. A step that is reverted — walking into a boss — leaves no phantom event,
and a cast that combat refuses records nothing.

**Recorded moves never edge-walk.** Live input may carry a hero into an adjacent
arena; the same event on playback clamps at the arena edge. A ghost that walked
out would be folded into a timeline it no longer stands in. An accepted live
exit discards the active draft before the crossing can be captured. A blocked
exit keeps the draft. No travel confirmation is required.

## Ghosts

`is_ghost()` is **derived** from whether the hero's staff is folded into its
arena's stream, never stored, so the two can never disagree. A ghost's actor is
drawn at 50% opacity, including during ability animations, with no separate ghost
box. Only the focused, selected hero wears the arena-coloured selection brackets;
Tab moves those brackets between heroes. A selected ghost stays translucent.
Taking control restores full opacity. Opacity is derived presentation and is
rebuilt from the fold after loading, without changing the save format.

Whenever an arena restarts — a natural wrap, a commit, a replay, a record-new,
or **Restart arena** — every ghost in it returns to its start tile and to a clean
cast state. Breaking a ghost out with **Take control** is the one path that does
**not** restart: its events leave the stream, the arena keeps playing from
exactly where it was, and a living hero is free at its current tile. A broken-out hero
keeps its cached staff, so R offers to fold it back in.

Natural wraps, Commit, Replay previous, and **Restart arena** show the played
portion backward at a default 10×, increasing its rate as needed to finish
within five seconds before a separate three-second return-to-play countdown.
The rate is frozen when playback begins. The
underlying arena is already reset and held at tick zero; the reverse imagery
does not execute staff events or undo damage. Lifetime damage and deposited
resource banks survive, while the ordinary Guild House cycle reset still clears
affected heroes' carried bags. Starting **Record new** instead uses only the
recording session's existing countdown. See [arena rewind](arena-rewind.md) for
the separate visual history, input boundary, and schema-7 pending restart.

Saving during a rewind or its countdown preserves the reset model and pending
flag. Continue opens a fresh three-second countdown, with no second reset or
attempt to reconstruct historical images. A recording draft/countdown cannot
coexist with that pending flag in its own arena; other arenas can still record.

Stepping past an arena edge mid-take asks before anything is lost: continuing
abandons the step, walking out discards the take and *then* performs it, and
committing folds the partial staff and keeps the hero where it is. At the outer
border of the 3×3 world there is no neighbour, so the step simply clamps and is
recorded as played.

## Dying

Death is **derived, never recorded**. There is no death event in a staff.

Living heroes cannot share a logical grid cell. A moving hero that enters a
stationary hero's cell survives; the stationary hero is defeated. When several
heroes arrive together, the selected mover loses, and the lowest-identity
nonselected mover survives. With no nonselected mover, the lowest identity
survives. Other movers and stationary occupants at that contact are defeated.
Swaps and diagonal paths meeting at the same fractional tick also count as
contact. Following into a vacated cell is safe, as are adjacent cells.

Live movement and all due recorded moves share one frozen step snapshot. The
conductor resolves contact before active projectiles, live or recorded attacks,
and gathering work. Every victim's health is set to zero and its active cast
canceled before defeat observers run. Even a victim immediately respawned by the
shell cannot perform an ability already collected from its staff that tick.
Selection, contact snapshots and defeat provenance are transient; health,
position, identity and the existing staff remain their normal save authorities.

A **ghost** struck by a landing dies *in place*: it stops where it fell, neither
moving nor casting for the rest of the cycle, and rises at its start tile when
the arena restarts. Walking it home would resume its recorded intent in an arena
it is not folded into, and replay would be meaningless.

An unselected ghost defeated by hero contact follows the same cycle rule. A
selected ghost defeated by contact instead unfolds and returns to a vacant cell
near the Guild House center, retaining its cached recording. Defeated smoke is
nonphysical: another hero can occupy its tile without being struck by it. On a
restart, revived ghosts become physical again; start-cell contacts resolve before
the new cycle is exposed. Rewinding teleports directly to the start and does not
strike heroes along the space between its old and new cells.

On a fresh defeat, the body and focus brackets disappear. The native Aseprite
[ghost death effect](../assets/fx/ghost_death/README.md) plays a 0.78-second burst
of small blood droplets and bone fragments, then a translucent two-second smoke
loop at the fallen tile. Each hero owns at most one reusable effect sprite.
The next arena cycle or explicit restart clears it as the existing model revives
the ghost. Taking control clears the ghost effect as well. Loading a defeated
ghost or replacing its view restores the smoke directly, without replaying the
burst; no animation frame or particle becomes save authority.

Taking control of a defeated ghost unfolds its staff, then uses the normal
free-hero respawn at Guild House with full health; the original arena keeps
running. Choosing **Record new** instead starts a new cycle in the same arena,
restoring the recorder's health and cast state before the countdown. Neither
choice leaves a free hero at zero HP or publishes a second defeat. Both keep the
cached staff until a new take is committed.

With the same boss pattern and other heroes' paths, a ghost that
dies once dies **at the same tick every cycle** until that choreography changes.
That is the feedback loop: the arena tells you exactly which second of your
choreography is wrong.

A **free** hero — one not folded into a stream — returns to a vacant Guild House
cell nearest `(30, 15)` and is restored there, whether or not the player is controlling it.
Level, experience, arena damage and phase progress all survive.

A hero dying **during an active take** discards its draft immediately, restores
it at a vacant Guild House tile, and brings the selected hero's camera home in
close view. No death decision opens. The fatal tick finishes once, then the
source arena continues from its next timestamp. Death at 60 seconds leaves that
fight at 60 seconds, rather than restarting it or pausing its surviving ghosts.

An accepted portal exit, a non-input relocation, or navigation to another arena
also clears the active draft/countdown. Cancellation never folds a partial take,
resets the arena, removes other performers, erases an older cached staff, or
changes banked progress. A blocked world-edge step does not cancel. Another
hero's death does not interrupt the living recorder; ordinary ghost death still
happens in place and its committed staff remains folded.

Schema 10 keeps the existing session, health, clock and modal fields. Older saved
**You Lose** decisions are validated, then normalized during hydration: discard
the draft, remove its pause/decision, and return the fallen hero home without
replaying damage or seeking the source clock. A valid in-arena living recording
still resumes normally. New checkpoints contain the cleared draft and continuing
arena clock. The native process-restart and browser reload checks cover this
continuation alongside the surviving ghost's unchanged staff.


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

**Live input cannot cancel a recorded channel.** Tab between other heroes, Tab
onto or away from the ghost, and cast-key or pointer release leave its existing
Sacrifice channel and beam running. Its own movement, defeat, arena restart, or
explicit model cancellation still ends the channel; the presenter follows that
caster rather than the currently selected hero. Held input remains transient,
and this ownership correction adds no save field or migration.

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
tooltip gives both numbers. In the roster strip a folded member retains a blue
ring to distinguish its recording status from the selected-member highlight.

## Timing

Everything is in whole ticks at 60 Hz: `CYCLE_TICKS` 7,200 and `COUNTDOWN_TICKS`
180. See [battle sequences](encounters.md) for the clock contract and the master
timeline's fold / unfold rules, which recording shares rather than duplicates.
