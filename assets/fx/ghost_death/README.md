# Hero ghost death

The editable [Aseprite master](ghost_death.aseprite) contains a short red-droplet
and ivory-bone burst that resolves into a translucent lavender spirit. The
asymmetric shroud, hooked side wisps, hollow center, and curled hem are authored
pixel clusters. Upper and lower currents deform the loop in opposite directions.

This is transient presentation. The encounter owns death, its world anchor, and
the next arena-cycle reset; these pixels never define damage or collision.

| Contract | Value |
| --- | --- |
| Native canvas / slice | 57 × 57, transparent RGBA, untrimmed |
| Fixed pivot | (28, 28), aligned with the defeated hero's ground anchor |
| `burst` | Frames 1–12, 65 ms each, 780 ms total, nonlooping |
| `spirit` | Frames 13–28, 125 ms each, 2 seconds total, looping |
| Runtime atlas | 399 × 228; seven columns, four rows |
| Editable layers | Smoke wisps, Blood droplets, Bone fragments, Spirit shroud, Rim and impact light |
| Sampling | Native pixels, nearest filtering, no mipmaps or alpha-border repair |

Play `burst` once, then `spirit` until the authoritative arena loop resets. The
last burst frame exactly matches the first spirit frame; blood and bones are
absent from every spirit frame. Use sprite opacity 1: the artwork already carries
graded transparency, and inheriting the living ghost's 50% actor modulation
would dim it twice. Decorative canvas extent is not the hero's footprint.

The export is
[`ghost_death_frames.tres`](../../../arenic-game/assets/fx/ghost_death/ghost_death_frames.tres),
with the matching transparent PNG and frame/slice/layer JSON beside it. Palette
authoring remains in [OKLCH](palette.oklch.json), converted to RGBA only inside
Aseprite. The last swatch is the review GIF matte, not a runtime pixel.

Run from the repository root:

```sh
aseprite --batch --script-param root="$PWD" --script assets/pipeline/build-ghost-death.lua
```

Replace `aseprite` with the installed executable when necessary. The script
creates a missing master and exports the saved master on subsequent runs. It
preserves hand edits by default. `--script-param rebuild=true` explicitly replaces
the master from the original pixel score; use it only when that replacement is
intended. It does not open or change the live GUI document.

Open the [preview](previews/index.html) to replay death, pause/scrub, and inspect
both native 1× and enlarged 6× views against dark and light arena-like surfaces.
The canvas player uses the actual RGBA atlas. Separate [burst](previews/burst.gif)
and [spirit](previews/spirit.gif) GIFs are native Aseprite exports composited onto
slate, because GIF cannot retain graded alpha. GIF holds alternate the nearest
centiseconds to preserve the complete tag duration; PNG metadata and Godot use
the exact original millisecond timing.

Source checks on 2026-09-12: Aseprite MCP confirmed all 28 frames, five layers,
and both tag ranges. PNG readback confirmed RGBA, untrimmed regions, clear canvas
edges in every frame, 16 distinct loop frames, graded alpha, and the identical
burst-to-spirit boundary. The rendered preview traversed both tags and wrapped
only the spirit tag with no browser errors. Native 1× and enlarged dark/light
views were inspected. Runtime lifecycle integration and Godot play verification
belong to the consuming gameplay change.
