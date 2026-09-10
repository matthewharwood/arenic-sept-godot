# Thief — base form

A slim purple feline viewed straight down, with the portrait's pointed ears,
copper ponytail, curled tail, gold crown/fittings, pale cloth, and paired daggers.
The crown and hair are seen from above; there is no face-on character pose or
perspective tilt. The slim silhouette distinguishes her from the broad Warrior.

Every actor source is **19 × 19**, one tile, with a full-frame `frame` slice and
center pivot **(9, 9)**. Seven editable layers separate tail/stance, cloth,
limbs, ponytail, crown/ears, daggers, and ability accents. Actual quarter-turn
cardinal views preserve handed equipment. The palette is authored in
[OKLCH](../../palettes/thief.oklch.json).

| Source | Main tags | Per-direction timing | Phases and behavior |
| --- | --- | --- | --- |
| [Idle](thief.aseprite) | `idle_n/e/s/w` | 4 frames, 1000 ms | Loop |
| [Backstab](abilities/backstab/thief_backstab.aseprite) | `backstab_n/e/s/w` | 8 frames, 600 ms | Immediate qualifying strike, recovery |
| [Shadow Step](abilities/shadow_step/thief_shadow_step.aseprite) | `shadow_step_n/e/s/w` | 8 frames, 600 ms | Depart/travel total 200 ms; arrive follows |
| [Misdirection](abilities/smoke_screen/thief_smoke_screen.aseprite) | `smoke_screen_n/e/s/w` | 8 frames, 800 ms | Immediate cast, recovery |
| [Pickpocket](abilities/pickpocket/thief_pickpocket.aseprite) | `pickpocket_n/e/s/w` | 10 frames, 1000 ms | Reach, looping hold, take, recover |

Backstab is a **passive** enhancement to a qualifying normal attack. The animation
is a demonstration of that attack, not a new active cast. It applies six seconds
of bleed when the rear/concealment condition succeeds. Shadow Step follows the
explicit 200 ms, four-tile dash mechanics rather than the overview's loose
“instantaneous teleport” wording. World movement is external to the centered
actor; immunity starts immediately and continues for 800 ms after the dash.

The filename `smoke_screen.md` currently contains **Misdirection**: a six-second,
three-tile-radius ability-redirection zone. The source id and folder remain
`smoke_screen` to preserve the document mapping, while the displayed name follows
its title. No concealment or direct zone damage was invented. Earlier Backstab
prose mentions smoke concealment, but that is not implemented by this current
Misdirection asset set. Basic attacks and self-targeted abilities remain exempt.

Pickpocket previews a successful currency attempt at the minimum 500 ms hold.
The `n/e/s/w_hold` tags can loop for longer attempts, up to the documented three
seconds. Gameplay must resolve success, detection, reward tier, buff transfer,
and the target's continuing behavior; the art does not guarantee success.

Separate FX live in each ability's `fx/` folder. Local FX are 19 × 19 with pivot
(9, 9). Shadow trail and theft transfer are 38 × 38 with pivot (19, 19) and four
cardinal tags. Misdirection's `vortex.aseprite` is 114 × 114, pivot (57, 57): the
six-cell diameter corresponding to its three-cell radius. Broken spiral lanes
and an open interior preserve visibility of actors and terrain. Shadow rift
contains both `depart` and `arrive` tags. Gameplay owns all lifetime/path changes.

[hero.json](hero.json) records source documents, frame timings, release hooks,
preview types, FX, audio briefs, and interpretation notes. [audit.json](audit.json)
contains native readback for all 14 sources. Validation checked dimensions,
pivots, authored-palette membership, hard alpha, transparent outer margins,
cardinal actor rotations, tag ranges, and durations. Contact sheets and enlarged
frames were visually reviewed; source-side GIFs are supplied for playback review.

The editable `.aseprite` sources are authoritative. All derived PNG/GIF previews
remain outside the game directory. No runtime export or game implementation was
performed. Preserve later hand edits rather than rerunning construction scripts.
