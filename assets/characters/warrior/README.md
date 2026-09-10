# Warrior — base form

A brown bear viewed straight down, using the portrait's plum armor, gold edging,
large shield, red cloth, and broad silhouette. The short sword is a secondary
readability cue; the shield leads the class's attacks and defenses. There is no
front-facing torso, perspective tilt, or upright character illustration.

Every actor source is **19 × 19**, one tile, with a full-frame `frame` slice and
center pivot **(9, 9)**. Six editable layers separate cloth/stance, armor,
limbs, bear crown, equipment, and ability accents. Cardinal views are actual
quarter turns around the center, preserving equipment handedness. The palette
is authored in [OKLCH](../../palettes/warrior.oklch.json).

| Source | Main tags | Per-direction timing | Phases and behavior |
| --- | --- | --- | --- |
| [Idle](warrior.aseprite) | `idle_n/e/s/w` | 4 frames, 1000 ms | Loop |
| [Bash](abilities/bash/warrior_bash.aseprite) | `bash_n/e/s/w` | 6 frames, 500 ms | Immediate strike; recovery is cosmetic |
| [Block](abilities/block/warrior_block.aseprite) | `block_n/e/s/w` | 8 frames, 1000 ms | `n/e/s/w_raise`, looping `_hold`, `_lower` |
| [Taunt](abilities/taunt/warrior_taunt.aseprite) | `taunt_n/e/s/w` | 10 frames, 1400 ms | 800 ms channel, challenge, recovery |
| [Bulwark](abilities/bulwark/warrior_bulwark.aseprite) | `bulwark_n/e/s/w` | 8 frames, 1000 ms | Immediate deploy, looping hold, lower |

The main Block and Bulwark tags demonstrate a complete action. During gameplay,
play their hold phase until cancellation or the real ability duration ends.
Block starts north and rotates clockwise on subsequent taps; its 90-degree arc
is a separate four-direction `guard.aseprite`, with `deflect.aseprite` for actual
projectile contacts. It does not fire a projectile.

Separate FX live beside each ability in `fx/`. Local impacts and status marks
are 19 × 19, pivot (9, 9). Taunt's `challenge.aseprite` is 38 × 38, pivot (19, 19),
representing its 2 × 2 target area. Bulwark's `barrier.aseprite` uses 57 × 57,
pivot (28, 28), to rotate a three-by-two-tile frontal footprint without clipping.
Place that field's center ahead of the Warrior in gameplay. Its `barrier_n/e/s/w`
tags loop; `n/e/s/w_dissipate` last 500 ms. The overhead lattice and bright frontal
crest show its orientation. Status/field loops do not determine gameplay lifetime.

Bash weakens the **next** enemy attack by 30%, consumed on use or after 8 seconds;
this follows the explicit gameplay prose over older continuous-reduction example
code. Taunt changes targeting for six seconds, preserving movement and attack
schedules. Bulwark lasts four seconds and absorbs frontal projectiles/cones.
No upgrade effects were added.

[hero.json](hero.json) records source references, durations, release hooks, FX,
preview semantics, audio briefs, and interpretation notes. [audit.json](audit.json)
contains native readback for all 13 sources. Validation checked canvas sizes,
pivots, authored-palette membership, hard alpha, transparent outer margins,
cardinal actor rotations, tag ranges, and timing. Contact sheets and enlarged
frames were visually reviewed; source-side GIFs are supplied for playback review.

The `.aseprite` files are authoritative. PNG/GIF previews are derived and remain
outside the game directory. This work exports no runtime sheets or metadata and
implements no game behavior. Do not regenerate a source over later hand edits.
