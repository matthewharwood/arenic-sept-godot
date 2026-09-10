# Cardinal artwork

True overhead **19 × 19** character frames, centered at **(9, 9)**, with north,
east, south, and west tags. The portrait informs the green reptilian crown,
red/gold vestments, gold diadem, torch staff, and red shield. The head is a
crowned top plane, with no front-facing eyes or upright body silhouette.

[cardinal.aseprite](cardinal.aseprite) contains four directional idle poses.
Attacks live in `abilities/<id>/cardinal_<id>.aseprite`, with independent effects
under `fx/`. Seven layers preserve robe, trim, equipment, arms, crown, focus, and
cast accents. The [OKLCH palette](../../palettes/cardinal.oklch.json) is authoritative
for authored colors; the native files preserve the editable artwork.

| Base ability | Frames per direction / total duration | Gameplay release | Separate effects |
| --- | --- | --- | --- |
| [Sacrifice](abilities/heal/cardinal_heal.aseprite), ID `heal` | 9 / 1300 ms preview | Immediate channel | Outgoing crimson life stream, ally receiving glow and healing aura |
| [Barrier](abilities/barrier/cardinal_barrier.aseprite) | 6 / 600 ms | Instant | One ally's blessing flash and gold shell |
| [Beam](abilities/beam/cardinal_beam.aseprite) | 9 / 1360 ms | After 1000 ms channel | Eight-tile ray, local radiant hit |
| [Resurrect](abilities/resurrect/cardinal_resurrect.aseprite) | 12 / 2500 ms | After 2000 ms channel | Per-ally revival wave, enhanced-vision aura |

Full tags are `<ability>_n/e/s/w`; phase tags use `n/e/s/w_<phase>`. Sacrifice's
local frames 4–7 form an **800 ms repeating channel**; game input and interruption
control the exit. Beam and Resurrect channel once for their specified durations.
The source document `heal.md` calls the ability **Sacrifice**; its filename is
retained as the canonical ID. It spends the Cardinal's own health, not free
healing. Conflicting minimum-health values in that reference remain a gameplay
question rather than a choice embedded in art.

Local effects are centered at **(9, 9)** on 19 × 19, or **(19, 19)** for the
38 × 38 revival wave. `life_stream` is 76 × 19 with caster pivot **(1, 9)** and
ally endpoint **(74, 9)**; crimson motes flow **left to right**. Its `transfer`
loop lasts 800 ms; `dissipate` lasts 500 ms. `radiant_beam` is **152 × 19**,
origin **(1, 9)**, far endpoint **(150, 9)**, firing east/right and fading over
1500 ms. Rotate around the origin for other directions. The beam's damage and
ally healing happen immediately on release; the visual fade adds no hit delay.

Barrier applies to one selected ally, not everybody in its 8 × 8 selection area.
Resurrection waves attach to each fallen ally selected within the gameplay
4 × 4 area; the 38-pixel wave is not the selection boundary. Gameplay owns target
selection, cooldowns, barrier strength, health conversion, revival health, and
the 15-second enhanced-vision state. No upgrade or invulnerability effects appear.

[hero.json](hero.json) contains paths, timing, preview intent, and audio briefs.
[source-audit.json](source-audit.json) records saved-file checks. Source-side
`previews/` contain MCP GIFs, native frames, and contact sheets. No final game
textures, runtime metadata, or audio were exported by this art pass.
