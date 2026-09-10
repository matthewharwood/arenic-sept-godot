# Bard artwork

The portrait guides the purple and gold shoulders, dark braided crown, warm wooden lute, and turquoise musical accents. The instrument is seen from above; no face or standing torso is visible.

All actor sources are transparent **19×19** layered Aseprite files, one grid cell at **1280×720 / 1×**, with center pivot **(9, 9)**. Four cardinal directions are exact 90-degree rotations. There are no faces, front torsos, or standing boots. The [idle source](bard.aseprite) has four 200 ms frames tagged `idle_n`, `idle_e`, `idle_s`, and `idle_w`.

The native `.aseprite` masters are authoritative. Each actor has seven named layers; each effect has three. Colors are authored in the [OKLCH palette](../../palettes/bard.oklch.json) and converted at the Aseprite pixel boundary.

## Base abilities

Each full ability tag is named `<id>_n`, `<id>_e`, `<id>_s`, or `<id>_w`. Durations below are per direction and are separate from cooldowns and gameplay lifetimes.

| Ability | Source ID | Frames per direction | Duration | Release |
| --- | --- | ---: | ---: | ---: |
| [Mimic](abilities/mimic/bard_mimic.aseprite) | `mimic` | 9 | 900 ms | 500 ms |
| [Dance](abilities/dance/bard_dance.aseprite) | `dance` | 18 | 4200 ms | 4000 ms |
| [Cleanse](abilities/cleanse/bard_cleanse.aseprite) | `cleanse` | 6 | 600 ms | 0 ms |
| [Helix](abilities/helix/bard_helix.aseprite) | `helix` | 8 | 800 ms | 0 ms |

Mimic is a passive successful-proc preview, not a manually aimed attack. Its music and resonance are overlays: the game must replay the qualifying adjacent ally's actual offensive effect after 500 ms at 80% power. The preview does not guarantee the base 10% proc.

Dance illustrates a successful eight-beat sequence at 120 BPM, with its finale at 4000 ms. Gameplay supplies the player's timing and score. Cleanse acts immediately in a 4×4 area; its 2000 ms wave is presentation only and adds no heal or immunity upgrade.

Helix has separate regeneration and haste loops. Select one mode at a time; the base ability never applies both modes together. The 38×38 accent does not define its three-tile gameplay radius or extend its uptime.

## Independent effects

Coordinates are zero-based pixels in the full-canvas `frame` slice. Canvases and pivots are fixed across every frame.

| Source | Tag | Canvas | Pivot | Duration / playback |
| --- | --- | --- | --- | --- |
| [Mimic / echo](abilities/mimic/fx/echo.aseprite) | `echo` | 19×19 | (9, 9) | 800 ms / once |
| [Mimic / resonance](abilities/mimic/fx/resonance.aseprite) | `resonance` | 19×19 | (9, 9) | 600 ms / once |
| [Dance / rhythm](abilities/dance/fx/rhythm.aseprite) | `beat_loop` | 38×38 | (19, 19) | 500 ms / loop |
| [Dance / finale](abilities/dance/fx/finale.aseprite) | `finale` | 38×38 | (19, 19) | 1000 ms / once |
| [Cleanse / wave](abilities/cleanse/fx/wave.aseprite) | `purify` | 76×76 | (38, 38) | 2000 ms / once |
| [Cleanse / cleansed](abilities/cleanse/fx/cleansed.aseprite) | `cleansed` | 19×19 | (9, 9) | 800 ms / once |
| [Helix / regeneration](abilities/helix/fx/regeneration.aseprite) | `regen_loop` | 38×38 | (19, 19) | 1000 ms / loop |
| [Helix / haste](abilities/helix/fx/haste.aseprite) | `haste_loop` | 38×38 | (19, 19) | 800 ms / loop |
| [Helix / transition](abilities/helix/fx/transition.aseprite) | `toggle` | 38×38 | (19, 19) | 600 ms / once |

The [manifest](hero.json) records source documents, timing, effect roles, staged preview behavior, and sound-cue descriptions. Cast and impact audio hooks describe production targets; their existence does not establish that audio has been generated.

## Review and handoff

Open the [shared attack gallery](../../previews/bard/attacks.html) for native-scale staging. Source-side [actor contacts](previews/actors-contact-4x.png) show all north frames; [effect contacts](previews/effects-contact-2x.png) show four phases of each effect tag in manifest order. The `previews/` folder also contains native-timed actor and state-specific effect GIFs. Those are derived review files.

[Validation readback](previews/validation.json) checks native dimensions, frame and tag timing, pivots, exact cardinal pixel rotations, binary transparency, and a one-pixel transparent margin around every actor frame. Contact frames and MCP previews were visually inspected; they do not replace full-speed playback review or an actual Godot playtest.

All editable sources and previews remain outside `arenic-game/`. Future runtime output mirrors this folder under `arenic-game/assets/characters/bard/`, at native 1× dimensions with tags and slices. No final texture or metadata export is performed by this artwork task. Game movement, collision, targeting, ability outcomes, resource costs, and effect lifetime remain gameplay-owned. The gallery is a concept preview, not game integration.
