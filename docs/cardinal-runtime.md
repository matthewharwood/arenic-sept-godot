# Cardinal practice and tuning

The Twofold Witness is playable in **Sanctum / Normal**, with 25 authored events
in a 7,200-tick cycle. It implements the [Cardinal design](bosses-v2/05-cardinal.md)
using the existing eight starter abilities. The other 24 planned abilities and
their optional Transmute cache economy are still separate future work. There is
no cache reward with no implemented consumer.

New games use `cardinal-1`: four maximum HP, the legacy Hunter patrol, and this
Cardinal score. Existing saved games migrate to `legacy-1`, preserving the
one-HP prototype and static Sanctum. Start a new game or use the isolated practice
launcher to try Cardinal; Continue does not reinterpret an existing recording.

From the repository root:

```sh
python3 scripts/preview-cardinal.py
python3 scripts/preview-cardinal.py --hero bard --tick 2850
```

The launcher copies the current project into a temporary directory, opens Sanctum
with the chosen hero, and uses the normal game controls, combat, recording and
presentation. It cannot overwrite a player's save. F6 starts practice at the next
warning; F7 resets the encounter and returns the hero to the neutral south aisle;
F8 pauses/resumes simulation. Seeking is practice setup, not a rewind of actor
history. Each seek clears personal effects and starts a fresh attempt. Closing
the window removes the temporary project. Re-run after editing a draft.

The opening six seconds contain no damage. Use the two central aisles for an
unattuned route; enter the labeled Sun or Moon font for optional seal immunity.
Reconciliation gives an attuned actor +1 on the first original direct hit only.
The final window is seven seconds, as the event table specifies. The last
Confession's delayed Exposure can still wound at 1:53.5; the final transfer is at
1:53 and there are no new impact events afterward. Music never controls timing.

## Data and extension points

| Owner | Edit here |
| --- | --- |
| 25 events, 5 grounded pose keys, fonts, Exposure delay/damage, bonus | [`cardinal_normal_1.tres`](../arenic-game/data/encounters/v2/cardinal_normal_1.tres) |
| Typed event validation and per-mask immunity | [`score_event.gd`](../arenic-game/scripts/encounters/v2/score_event.gd) |
| Ordering, geometry validation, content hash, event lookup | [`mask_score.gd`](../arenic-game/scripts/encounters/v2/mask_score.gd) |
| Personal attunement, delayed wounds, claims | [`actor_effects.gd`](../arenic-game/scripts/encounters/v2/actor_effects.gd) |
| Shared timeline integration | [`encounter_state.gd`](../arenic-game/scripts/encounters/encounter_state.gd) |
| Exact floor masks and non-color patterns | [`score_view.gd`](../arenic-game/scripts/encounters/v2/score_view.gd), [`mask_warning.gdshader`](../arenic-game/shaders/encounters/mask_warning.gdshader) |
| Compatibility and frozen ability fingerprint | [`content_identity.gd`](../arenic-game/scripts/encounters/v2/content_identity.gd) |

Use integer ticks (60 per second). Warnings are at least 120 ticks; every
Reconciliation transfer warns for 180. Rectangle ends are exclusive. Keep the
Sun/Moon label with its rectangle after mirroring. At most 64 events, 16 poses,
eight masks per event, four windows and four outstanding Exposures are accepted.
All pose keys stay grounded. The destination footprint crushes at transfer;
there is no swept collision and no airborne immunity.

For an easier draft, first adjust a specific pressure: extend a warning by moving
`cue_tick` earlier; move the final overlapping Sun Seal away from Confession;
or widen a working gap by adjusting that event's rectangle. Avoid changing all
three at once. Keep the six recognizable moves and test the quiet start/seam.
Damage, masks, fonts, pose/facing and timing are simulation changes, whereas ink,
font sizes, warning patterns and labels are presentation changes.

The shipped revision is immutable once recordings exist. Duplicate the resource
for a new revision and retain the old resource/catalog resolution. Add a new
ruleset/content identity and an explicit new-game selection when promoting it.
During local draft work the practice launcher always reads the working copy.
A changed score or starter build under an existing fingerprint causes SaveGames
to reject hydration and retain the original slot; it never rewrites a take.
There is deliberately no live difficulty slider that changes an active recording.

## State and ordering

Schema 10 adds `run.combat.encounter` with `ruleset`, `fingerprint`, and the
bounded arena/actor ledger. A run-wide fingerprint pins all cached recordings and
the active draft to the same score and starter build. Their existing identities,
start cells and ordered intent events remain authoritative. The hash includes
movement grid/tick rate, vitality, score semantics and all starter mechanical
properties; it excludes visual/audio properties. It is pinned once per run,
retained on capture, and checked before restore. Legacy content uses its existing
released interpretation.

Attunement lasts until font change or source-arena reset. Death removes Exposure
but preserves window claims and attunement, so respawning cannot farm a second
bonus. Exposure follows actor identity while advancing on the source arena clock;
Cleanse can remove it even after the actor walks to another arena. At its damage
tick it is still cleansable; cleanup occurs on the next tick. Source-arena reset
clears all its actor effects, including actors who left it. Reset also revives
current participants and clears their casts/cooldowns while retaining banked
progress. Death and arena departure discard an active draft immediately while the source
arena and other ghosts keep playing. Existing cached recordings are retained.

For this revision, movement and hero contact run first, then font contact and
accepted hero support/direct effects, then boss events ordered by event ID, then
Exposure, enemy DOTs, and ground fields. The score supplies the current footprint
and facing before any hit test on a transfer tick. The legacy Hunter keeps its
existing landing semantics and ordering. A cue lookup or restored pose never
replays damage. Presentation reads the current clock, with no saved warning nodes.

The current warnings are deliberate geometric floor effects with labels and
patterns, using the existing boss appearance and arena music. Dedicated attack
sprite animation and new move-specific audio have not been authored. Replacing
these presentation assets does not require changing damage masks or the score.

## Verification

`tests/encounters/cardinal_checks.gd` covers all source/resource event and pose
values, cue/impact/end boundaries, mirrored labels, personal wounds, simultaneous
events, crush, exact-tick Cleanse, one-time direct bonuses, the published real
walking recording, 100-cycle empty/40-actor event equality, independent pause,
and malformed/changed-content save rejection. The forty-actor case uses distinct
recovery slots; it is not evidence of forty optimized combat routes.

The native process-restart fixture and real IndexedDB reload test preserve
attunement, an earned claim, four-HP vitality and an Exposure at its deadline.
The native renderer captures five cue/window moments through the actual game:

```sh
python3 scripts/preview-cardinal.py --capture .tmp/cardinal-review
python3 scripts/ci/test-godot.py --godot /Applications/Godot.app/Contents/MacOS/Godot --suite all
```

Native screenshots use the platform's actual framebuffer at a 1280 × 720 logical
layout. Treat mechanical test success as a starting point for human difficulty
tuning, not a claim that the fight is balanced. Local verification is separate
from publishing a release.
