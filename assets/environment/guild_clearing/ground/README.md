# Guild clearing ground

Native Aseprite woodland ground, authored at **19 source pixels per logical tile**. The grass has quiet moss, sage and olive clusters; the transparent earth overlays use broken contours, short tufts, small stones and occasional pale flowers. There are no planks, room edges, rugs, random noise or gameplay obstacles in these assets.

The layered `.aseprite` files are the editable masters. [palette.oklch.json](palette.oklch.json) owns the muted material swatches; RGB conversion happens inside Aseprite at export. These ramps extend the shared environment palette with lower-contrast ground colors.

| Master / atlas | Native frame | Atlas size | Left-to-right order |
| --- | --- | --- | --- |
| `grass_tiles` | 19 × 19 | 76 × 19 | `moss`, `sage`, `olive`, `dapple` |
| `dirt_patches` | 76 × 76 | 228 × 76 | `worn_clearing`, `curved_footpath`, `stony_clearing` |

Atlases and JSON live in `arenic-game/assets/environment/guild_clearing/ground/`. Frames are untrimmed, single-row regions with no padding. JSON records exact regions and pixel-center pivots: `(9,9)` for grass and `(37.5,37.5)` for patches. Tags represent static variants, not an animation. Use nearest filtering at native pixel scale.

All four grass frames are fully opaque and share the same outer edge swatch, so different variants can meet without seams. Repeat individual 19 × 19 regions across the field. Dirt patches are transparent overlays four tiles wide; their alpha edges soften into that field. They are decorative and do not define collision, gathering radius or placement.

Re-export saved masters without altering their pixels:

```sh
aseprite --batch --script-param root=/absolute/path/to/arenic-sept-godot \
  --script assets/environment/guild_clearing/ground/author-ground.lua
```

`author=true` explicitly reconstructs the initial hand-shaped clusters and overwrites the masters; omit it after native edits. The script uses Aseprite's own images, layers, cels, palette, compositing and PNG export. It contains no random texture generator or external raster library.

Verified with Aseprite **1.3.18.5-arm64**: grass master has four frames and three editable layers; dirt master has three frames and four layers. Native pixel readback in [validation.json](validation.json) verifies 361 opaque pixels per grass tile, compatible outer edges, and transparent unclipped borders on all patches. Patch transparent counts are 3,527, 4,179 and 3,805 out of 5,776 pixels. Source hashes in [provenance.json](provenance.json) verify that export-only leaves the masters unchanged.

Reviewed the [native field](previews/field-composite-1x.png), [enlarged field](previews/field-composite-3x.png), and [19-pixel hero contrast](previews/hero-legibility-3x.png). The preview composes the unchanged runtime Forager sprite onto grass and soil; it is not part of either runtime atlas. Placement in the actual outdoor arena is owned by the renderer integration.
