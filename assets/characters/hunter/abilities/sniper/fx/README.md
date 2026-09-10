# Sniper — base effects

True straight-down orthographic artwork for the **19-pixel tile grid**. Each
source fits one tile: a single precision arrow, cream/gold trail, closing target
reticle, and radial contact burst. All colors reuse the
[Hunter OKLCH palette](../../../../../palettes/hunter.oklch.json). There are no
critical-hit, chain-shot, or multiple-target upgrade effects.

| Source | Canvas | Tags and timing | Pivot |
| --- | --- | --- | --- |
| [projectile.aseprite](projectile.aseprite) | 19 × 9 | `flight_e`, frames 1–4, 200 ms loop | Arrow tip (17, 4) |
| [impact.aseprite](impact.aseprite) | 19 × 19 | `impact`, frames 1–6, 500 ms once | Tile/contact center (9, 9) |
| [reticle.aseprite](reticle.aseprite) | 19 × 19 | `lock_on`, frames 1–6, 500 ms once; `locked_hold`, frames 7–8, 320 ms loop | Target tile center (9, 9) |

Coordinates are zero-based source pixels. Every file has a full-canvas `frame`
slice and explicit pivot. Preserve fixed canvas dimensions without trimming.
The arrow points east/right. Gameplay positions and rotates it at its tip and
controls travel time; the 200 ms loop animates the trail. The impact expands
radially in the ground plane and ends on a clear frame after 500 ms.

Center the reticle on the top-down target during the Hunter's 500 ms aim.
Play `lock_on` once; use `locked_hold` only if an acquired target needs to stay
visible. That optional hold does not extend the base aiming time. Remove the
reticle on release or cancellation. Game rules own target eligibility, damage,
and the base four-second cooldown. The reticle center stays transparent.

Layers separate trail, arrow, glint, radial shards, flash, sparks, brackets, and
focus ticks. `previews/` contains refreshed review-only MCP GIFs, enlarged key
frames/contact sheets, and transparent native frames under
`previews/frames/<source>/`. The `2x` filenames indicate review enlargement,
not a new grid or viewport. [summary.json](summary.json) records exact timing,
pivots, and saved-file checks. The `.aseprite` files remain authoritative.
No final game export was made.
