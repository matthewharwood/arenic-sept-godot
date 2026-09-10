# Poison Shot — base effects

True straight-down orthographic artwork for the **19-pixel tile grid**. Each
source fits within one tile. The editable `.aseprite` files are authoritative;
all colors reuse the [Hunter OKLCH palette](../../../../../palettes/hunter.oklch.json).

| Source | Canvas | Tags and timing | Pivot |
| --- | --- | --- | --- |
| [projectile.aseprite](projectile.aseprite) | 19 × 9 | `flight_e`, frames 1–4, 320 ms loop | Arrow tip (17, 4) |
| [impact.aseprite](impact.aseprite) | 19 × 19 | `impact`, frames 1–10, 1000 ms once | Tile/contact center (9, 9) |
| [affliction.aseprite](affliction.aseprite) | 19 × 19 | `afflicted_loop`, frames 1–6, 1000 ms loop | Target tile center (9, 9) |

Coordinates are zero-based source pixels. Every source has a full-canvas
`frame` slice with its pivot. Keep canvases untrimmed. The arrow faces east/right
and stays fixed at its tip while the trail changes; gameplay supplies motion,
direction, and hit detection. The impact splatters outward in the ground plane
and ends on a transparent frame. Affliction is a quiet broken peripheral halo,
with a clear central 9 × 9 region for the top-down target. There are no upright
vapor columns or area-damage/poison-spreading upgrades.

Spawn the projectile after the Hunter's 500 ms preparation. The separate actor
and gameplay movement own the 200 ms recoil. On contact, show the one-second
impact and attach the affliction at the target tile center. Gameplay owns the
base 20-second poison status, damage ticks, refresh, and early removal; the
one-second affliction loop is presentation, not the status duration.

Named layers keep wake, shaft, payload, glints, splatter, droplets, and peripheral
motes independently editable. `previews/` contains refreshed review-only MCP
GIFs, enlarged key frames/contact sheets, and transparent native frames under
`previews/frames/<source>/`. The `2x` filenames indicate review enlargement,
not a new grid or viewport. [summary.json](summary.json) records timing, pivots,
and saved-file checks. No final runtime export was made.
