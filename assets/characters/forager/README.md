# Forager artwork

The portrait guides the red and emerald clothing, long dark green hair, gold circlet, harvesting sickle, and living sprig. Dig swaps the harvesting gesture for a short spade stroke. The head and equipment are viewed directly from above.

All actor sources are transparent **19×19** layered Aseprite files, one grid cell at **1280×720 / 1×**, with center pivot **(9, 9)**. Four cardinal directions are exact 90-degree rotations. There are no faces, front torsos, or standing boots. The [idle source](forager.aseprite) has four 200 ms frames tagged `idle_n`, `idle_e`, `idle_s`, and `idle_w`.

The native `.aseprite` masters are authoritative. Each actor has seven named layers; each effect has three. Colors are authored in the [OKLCH palette](../../palettes/forager.oklch.json) and converted at the Aseprite pixel boundary.

## Base abilities

Each full ability tag is named `<id>_n`, `<id>_e`, `<id>_s`, or `<id>_w`. Durations below are per direction and are separate from cooldowns and gameplay lifetimes.

| Ability | Source ID | Frames per direction | Duration | Release |
| --- | --- | ---: | ---: | ---: |
| [Dig](abilities/dig/forager_dig.aseprite) | `dig` | 8 | 800 ms | 800 ms |
| [Boulder](abilities/bolder/forager_bolder.aseprite) | `bolder` | 8 | 800 ms | 0 ms |
| [Border](abilities/border/forager_border.aseprite) | `border` | 12 | 1700 ms | 1500 ms |
| [Symbiosis](abilities/mushroom/forager_mushroom.aseprite) | `mushroom` | 8 | 800 ms | 300 ms |

Canonical IDs follow the documents: `bolder` displays **Boulder**, and `mushroom` displays **Symbiosis**.

Dig is one 800 ms excavation per tag. Gameplay can repeat it for a second selected tile, within the two-tile cap, gaining one rock and marking each successful tile as dug. Boulder costs two rocks, is 2×2 cells, rolls until a solid obstruction, and has separate rolling and crumbling sources.

Border requires one rock and previously dug ground. Its 1500 ms growth precedes the active one-cell deflection loop; gameplay owns the 60-second lifetime and reflected projectiles.

Symbiosis has separate `seed`, `sprout`, `young`, `mature`, and `ancient` tags. The seed does not heal. Changing stages represents resource investment, never automatic growth from animation time alone. The feeding trail and healing loop are independent sources. Do not play all growth tags as a continuous seed-to-ancient animation. The brief disagrees about the exact gold-to-radius/duration formula; this art represents feeding without deciding that gameplay rule. No linked-node or World Tree upgrade is included.

## Independent effects

Coordinates are zero-based pixels in the full-canvas `frame` slice. Canvases and pivots are fixed across every frame.

| Source | Tag | Canvas | Pivot | Duration / playback |
| --- | --- | --- | --- | --- |
| [Dig / excavate](abilities/dig/fx/excavate.aseprite) | `excavate` | 19×19 | (9, 9) | 800 ms / once |
| [Dig / dug_ground](abilities/dig/fx/dug_ground.aseprite) | `dug` | 19×19 | (9, 9) | 1000 ms / loop |
| [Boulder / boulder](abilities/bolder/fx/boulder.aseprite) | `roll_e` | 38×38 | (19, 19) | 800 ms / loop |
| [Boulder / crumble](abilities/bolder/fx/crumble.aseprite) | `crumble` | 38×38 | (19, 19) | 2000 ms / once |
| [Border / barrier](abilities/border/fx/barrier.aseprite) | `grow` | 19×19 | (9, 9) | 1500 ms / once |
| [Border / barrier](abilities/border/fx/barrier.aseprite) | `barrier_loop` | 19×19 | (9, 9) | 1000 ms / loop |
| [Border / deflect](abilities/border/fx/deflect.aseprite) | `deflect` | 19×19 | (9, 9) | 400 ms / once |
| [Symbiosis / node](abilities/mushroom/fx/node.aseprite) | `seed` | 19×19 | (9, 9) | 1000 ms / loop |
| [Symbiosis / node](abilities/mushroom/fx/node.aseprite) | `sprout` | 19×19 | (9, 9) | 1000 ms / loop |
| [Symbiosis / node](abilities/mushroom/fx/node.aseprite) | `young` | 19×19 | (9, 9) | 1000 ms / loop |
| [Symbiosis / node](abilities/mushroom/fx/node.aseprite) | `mature` | 19×19 | (9, 9) | 1000 ms / loop |
| [Symbiosis / node](abilities/mushroom/fx/node.aseprite) | `ancient` | 19×19 | (9, 9) | 1000 ms / loop |
| [Symbiosis / feed](abilities/mushroom/fx/feed.aseprite) | `feed` | 38×19 | (19, 9) | 800 ms / loop |
| [Symbiosis / heal](abilities/mushroom/fx/heal.aseprite) | `heal_loop` | 38×38 | (19, 19) | 1000 ms / loop |

The [manifest](hero.json) records source documents, timing, effect roles, staged preview behavior, and sound-cue descriptions. Cast and impact audio hooks describe production targets; their existence does not establish that audio has been generated.

## Review and handoff

Open the [shared attack gallery](../../previews/forager/attacks.html) for native-scale staging. Source-side [actor contacts](previews/actors-contact-4x.png) show all north frames; [effect contacts](previews/effects-contact-2x.png) show four phases of each effect tag in manifest order. The `previews/` folder also contains native-timed actor and state-specific effect GIFs. Those are derived review files.

[Validation readback](previews/validation.json) checks native dimensions, frame and tag timing, pivots, exact cardinal pixel rotations, binary transparency, and a one-pixel transparent margin around every actor frame. Contact frames and MCP previews were visually inspected; they do not replace full-speed playback review or an actual Godot playtest.

All editable sources and previews remain outside `arenic-game/`. Future runtime output mirrors this folder under `arenic-game/assets/characters/forager/`, at native 1× dimensions with tags and slices. No final texture or metadata export is performed by this artwork task. Game movement, collision, targeting, ability outcomes, resource costs, and effect lifetime remain gameplay-owned. The gallery is a concept preview, not game integration.
