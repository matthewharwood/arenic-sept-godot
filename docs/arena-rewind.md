# Arena rewind and restart

A restart shows the played portion of an arena cycle in reverse at a default
**10× speed**, increasing the rate as needed to finish within **five seconds**.
It then holds its canonical starting state for **3–2–1** before play resumes. The
reverse image is a presentation of recent history. It never undoes damage,
deposits, deaths, or recorded intent by running game rules backward.

## Request broken into four checklist tasks

- [x] **Give each arena a safe restart boundary.** Reset through the existing
  encounter operation, retain lifetime damage and resource banks, and freeze
  the new cycle at tick zero until its restart presentation finishes. Preserve
  the ordinary cycle cleanup, including affected heroes' carried gathering bags.
- [x] **Show the portion that actually played in reverse.** Keep bounded,
  transient visual samples, play them backward within five seconds, and add restrained trails.
  Never synthesize earlier game state or make the renderer a simulation owner.
- [x] **Present a clear return to play.** Show the reverse clock and chevrons,
  followed by a centered three-second countdown inside the world-view rectangle.
  Hold input and the owning arena during the transition while other arenas keep
  their independent loops.
- [x] **Make restart continuation durable and prove the flow.** Save the pending
  decision in schema 7, restore it with a fresh three-second countdown, migrate
  prior saves without inventing a pending restart, and verify native and browser
  continuation plus actual rendered presentation.

The initial rewind implementation passed 51 native checks and all 64 browser
tests, including Commit, automatic cycle wrap, and real IndexedDB continuation
during a pending restart. Its production export was reviewed in the local game
preview. The five-second cap separately passed all 51 native checks, including
75 rewind assertions, and the two browser restart/IndexedDB cases against a
fresh private export. A new native capture of the unchanged 40-hero seed shows
the complete 120-second cycle reversing in exactly 300 frames at 60 Hz, then
180 countdown frames, with damage and prospecting totals preserved. Local
verification does not establish game deployment.

## Trigger and ownership

Natural cycle wrap, Commit, Replay previous, and **Restart arena** use the same
rewind flow. Empty arenas skip the cosmetic hold: their clocks and normal
cycle cleanup still run. An unscored arena such as the Guild House also wraps
without a rewind when it has no folded workers. A free hero returning after
automatic recording-death recovery can therefore move through the home clock boundary without inheriting
an idle countdown. Recorded Guild House workers retain their normal rewind.
A populated boss arena's rewind remains local when the player returns home;
only viewing that arena displays its countdown. A committed staff that is cached because an arena is already full
still follows the commit restart. Starting or replacing a recording uses
`restart(arena_id, false)` and retains the recording session's existing
three-second countdown; it does not add another rewind or countdown. Taking
control of a living ghost still unfolds it in place without restarting.

`ArenicEncounterState.arena_restarting` announces the old end tick before the
reset. The shell seals the available visual history and begins the presentation.
The existing reset returns the timeline and ghosts to their starts, revives the
appropriate ledger entries, clears cycle effects, and resolves start-cell
contacts. `arena_restarted` then marks the new cycle pending at tick zero. The
shell clears ghost-owned presentation effects at that boundary.

The restart flag is separate from the ordinary modal/recording pause flag.
`is_paused(arena_id)` accounts for either one, so ghost events, combat time,
attached DOTs, hazards, and gathering stay stopped in the pending arena. Other
arenas continue. A saved ordinary decision may coexist with a pending restart;
releasing the restart flag must not release that decision's pause. A recording
draft or recording countdown cannot own the same arena as a pending restart.

## Visual history and return to play

[`ArenicRewindHistory`](../arenic-game/scripts/encounters/rewind_history.gd) holds
samples at **20 Hz**, once per three authoritative 60 Hz ticks. Each arena has
at most **2,401 samples**, enough for both endpoints of a two-minute cycle, with
at most **7,065 tracks per sample**: 320 guild members, nine bosses, sixteen
temporary effects per caster plus an unknown-source bucket (5,136 slots), and
five reserved active-cast effects per hero (1,600 slots). Across all nine arena
histories, the existing global cap of **828,345 sampled poses** evicts the oldest
inactive samples first. Denser samples can retain a shorter visual span.
Transient tracks derive from source identity and local slot; reserved tracks
use caster identity and cast slot. A fresh generation on reuse prevents one
cast from interpolating into another. A typed frame holds packed
track IDs, effect generations, positions and 15 appearance values, alongside
shared texture references. It contains no replayable input or authoritative
model snapshot. A capture gap clears the older segment, so missing time is never
bridged as if it had been observed.

[`ArenicArenaRewind`](../arenic-game/scripts/encounters/arena_rewind.gd) owns the
transient visual phase and the shell owns its connection to the encounter. At
the start of each playback it freezes the rate to
`max(rewind_speed, captured_span_ticks / (60 × 5))`, using the interval between
the first and last available samples. The configured default is 10×, with an
Inspector range of 1–30×. Changing that setting affects the next playback;
an active rewind keeps its accepted rate and deadline.

A complete 120-second captured cycle uses 24× at the default setting and takes
five seconds to reverse. A configured 30× reverses it in four seconds. A
30-second captured segment still takes three seconds at 10×, even if it was
captured near the end of a cycle. A slow 1× setting increases to 1.2× for a
six-second segment so it also finishes within five seconds. All available
samples remain in the history; the cap changes playback rate without shortening
the trajectory or jumping to its start. Missing history after a load or view
replacement never permits manufactured gameplay or historical damage reports.

Playback interpolates sampled position, rotation and scale while retaining
actual sampled texture frames and facing. Two restrained accent trails use
samples 9 and 18 historical ticks later, at 28% and 12% opacity. Across concurrent
rewinds there are at most **21,195 clone sprites**, three per possible track.
During rewind those clones replace the real geometry through temporary render
layer masks. Selection brackets, bag meters, damage numbers and unsampled
procedural ground/blast overlays are hidden. Countdown and teardown restore the
real render layers; configuring a replacement stage clears the old history.

The separate countdown holds the reset arena at tick zero for 180 physics steps.
At 60 Hz, a full cycle at the default setting therefore uses 300 reverse steps
followed by 180 countdown steps. A frame crossing the reverse boundary spends
its remaining time on countdown instead of discarding it. Only
after that interval does the shell release `restart_pending`; the first live
step then starts from the canonical cycle boundary. Navigation to another arena
does not transfer restart ownership to the new focus.

[`ArenicArenaRestartOverlay`](../arenic-game/scripts/ui/arena_restart_overlay.gd)
is a `Control` under the HUD. The shell copies `hud.get_world_rect()` into its
position and size and calls
`present(phase, countdown, display_tick, arena_theme)`. The phases are `rewind`,
`countdown`, or empty to hide; the displayed clock consumes 60 Hz ticks. The
overlay measures its Barlow and Rajdhani text within the actual rectangle.
Rewinding uses a compact top-center badge with native double-left chevrons,
a 12-pixel top inset and 28-pixel clock, leaving the founder's central reverse
path visible. The large countdown stays centered. Both use an understated square
plate and the arena accent over an OKLCH-authored neutral surface. It owns no input, process
timer, audio, or model mutation. Its mouse and keyboard focus are ignored.

## Saved boundary and compatibility

Schema **7** adds exactly one boolean to each world arena:
`world.arenas[arena_id].restart_pending`. It is valid only at tick zero. Capture
and restore preserve the independent `paused` value and the existing modal
context. The validator rejects a simultaneous recording draft/countdown in that
arena. [Save-state architecture](save-state.md) remains the shared contract for
bounded, transactional validation and native/IndexedDB storage.

Restoration retires an old pending hold when its arena has no resident heroes,
preserving tick zero, the independent modal pause, and all cycle/bank state.
For populated arenas, restoration accepts the already-reset model, then starts a fresh three-second
countdown with no reverse playback and no second reset. Visual samples, trails,
phase elapsed time, accepted playback rate, text, and audio effects are not saved.
The five-second presentation cap does not change schema 7 or require a migration.
Loading does not
repeat a reset, deposit, damage event, ghost death burst, or historical feed row.

Version 6 → 7 supplies `restart_pending = false` for each old arena. A historical
tick zero is not evidence that a restart was underway. The migration preserves
old clocks, recordings, bags, banks and combat totals, and rejects an old payload
that already supplies the new field rather than silently choosing its meaning.

Lifetime arena/enemy damage, guild progress, and wood/gold banks survive both
ordinary and animated restarts. Cycle-local casts, hazards and attached DOTs use
their existing reset rules. Guild House bags clear for affected participants
through the ordinary cycle-reset hook; the rewind image cannot refund deposited
resources or recreate a cleared bag.

## Validation boundaries

The focused renderer check retains all 2,401 samples and compares each displayed
reverse pose through a full cycle at configured 1×, 10×, 20× and 30×. It checks
the five-second maximum, the unchanged short-segment rate, partial capture spans,
rate edits during playback, exact reverse/countdown frame boundaries, and a
frame whose remaining time crosses either or both phase boundaries. Existing
history, native-frame, mask, trail, arena isolation and global-cap checks remain.

The focused overlay check covers displayed time, all countdown numbers, responsive
containment, row separation, resize while visible, and input transparency. Model
and shell checks cover pending tick-zero freeze, independent arenas, restart
triggers, recording ownership, and preservation of the existing reset effects.
Codec and separate-process tests prove exact pending continuation and migration;
the browser gate must use real IndexedDB and input. Rendered review must inspect
the reverse image, trails and countdown in the actual game. Report those results
separately from whether a revision was merged or deployed.

The arena-isolation follow-up passed all 54 native checks across the full run
and two updated-expectation reruns, plus all 68 browser cases against isolated
production/probe builds. Its new Cardinal regression fails against the preceding
implementation and passes after the fix. Coverage includes an empty home wrapping
during the former death decision and Give Up flow (now replaced by automatic
draft cancellation), immediate movement, a populated Hunter
restart while Cardinal moves through the home clock boundary, arena-local overlay
visibility, and native/IndexedDB restoration of populated and empty pending holds.
These results verify local builds, not a deployment.
