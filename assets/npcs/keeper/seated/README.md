# Seated Keeper

`keeper_seated.aseprite` is a layered, true overhead seated pose. Its 38 × 38
RGBA canvas has pivot `(19, 19)` and seven editable layers: shadow, timber
chair, mantle/lap, collar, sleeves/hands, gold thread/clasp, and silver crown.
The south-facing crown and topknot are copied exactly from frame 9 of the
existing Keeper source. The ivory, violet and worn gold costume retains its
original OKLCH swatches; the chair uses the shared environment timber ramp.
No visible face or front-facing portrait is added.

| Tag | Source frames | Frame durations | Playback |
| --- | --- | --- | --- |
| `idle_s` | 1–4 | 800, 300, 800, 300 ms | Repeating 2.20-second loop |
| `beckon_s` | 5–8 | 180, 220, 300, 240 ms | One 0.94-second gesture |

The chair and crown stay fixed. Idle repeats small lap-fold breathing changes;
beckoning gently raises and extends the right hand, then returns it. The
runtime atlas is 304 × 38 with eight untrimmed 38 × 38 regions. The exported
`keeper_seated.tres` exposes both tags using their actual source durations.
Only idle loops. Beckoning emits `animation_finished` after one gesture so the
introduction can return the Keeper to idle.
It is ready for the introduction's `idle_s` / `beckon_s` calls, with NPC
resource selection left to the game integration owner. All frames retain
transparent margins; inclusive alpha bounds are `(7, 7)..(33, 34)`.

From the repository root, with Aseprite on PATH:

```sh
aseprite --batch --script-param root="$PWD" --script assets/npcs/keeper/seated/build.lua
aseprite --batch --tag idle_s assets/npcs/keeper/seated/keeper_seated.aseprite --save-as assets/npcs/keeper/seated/previews/idle_s.gif
aseprite --batch --tag beckon_s assets/npcs/keeper/seated/keeper_seated.aseprite --save-as assets/npcs/keeper/seated/previews/beckon_s.gif
```

The build exports the saved master. Only an explicit
`--script-param rebuild=true` recreates it from the original pixel score.
The PNG retains full alpha; review GIFs have GIF's binary transparency and
are not runtime assets. `previews/motion-review.html` repeats both studies at
native and 4× nearest scales, on the grass palette. The tavern composition
image is generated separately by its native `preview.lua`.

Reviewed native/4× pixels, the complete beckoning poses and both rendered
loops. Aseprite MCP readback confirms eight frames, exact durations, seven
visible layers and both tags. This task changes artwork only; it does not
modify dialogue progression, saved state, NPC coordinates or game data.
