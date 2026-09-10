# Arena decorations

Twenty-seven native pixel decorations, three per arena. Each saved master is a
layered **76 × 76** Aseprite document with three separately named static frames,
a **(38, 38)** pivot, and four editable layers: ground shadow, structure,
ornament, and highlights. Objects use overhead roof, canopy, vessel and tool
surfaces; they add atmosphere at the arena border and define no gameplay rules.

Review the [labeled gallery](previews/index.html), [native contact sheet](previews/contact-sheet-1x.png),
or [3× sheet](previews/contact-sheet-3x.png). Native and enlarged pixels were
visually reviewed; the art includes opaque material pixels, a limited 90/255
alpha ground shadow, and at least three fully transparent edge pixels.

| Atlas row | Arena | Left / middle / right frame |
| --- | --- | --- |
| 0 | [Labyrinth](labyrinth/labyrinth_decorations.aseprite) | Sakura canopy / torii roof / stone lantern roof |
| 1 | [Guild House](guild_house/guild_house_decorations.aseprite) | Coffee rug / books / hearth |
| 2 | [Sanctum](sanctum/sanctum_decorations.aseprite) | Reliquary / candles / gothic tracery |
| 3 | [Mountain](mountain/mountain_decorations.aseprite) | Fern / pine crown / mushrooms |
| 4 | [Bastion](bastion/bastion_decorations.aseprite) | Forge / anvil / shield rack |
| 5 | [Pawnshop](pawnshop/pawnshop_decorations.aseprite) | Crates / lamp / coins |
| 6 | [Crucible](crucible/crucible_decorations.aseprite) | Crystal facets / alembic / rune circle |
| 7 | [Casino](casino/casino_decorations.aseprite) | Rose planter / card table / chips |
| 8 | [Gala](gala/gala_decorations.aseprite) | Music crystal / turntable / stage lights |

## Runtime contract

The authorized runtime export is
[`arena_decorations.png`](../../arenic-game/assets/environment/arena_decorations.png)
with [`arena_decorations.json`](../../arenic-game/assets/environment/arena_decorations.json).
The **228 × 684** atlas has three columns and nine rows with no trimming,
rotation, scaling or inter-frame padding. Region `(column * 76, row * 76, 76, 76)`
is the whole frame. The JSON lists stable `arena/prop` IDs, exact regions, named
tags and pivots. Its three source frames are independent objects, not an animation.

Use nearest sampling, lossless compression, no mipmaps and no automatic 3D
compression. At `pixel_size = 0.25 / 19`, a decoration canvas covers four tiles
(one world unit) and is 76 logical pixels in the close view. The source canvas
does not alter the existing 19-pixel hero or 114-pixel boss contracts. Parent
scene code owns placement, facing, opacity, depth and runtime visual validation.

## Native pipeline

[build-arena-decorations.lua](../pipeline/build-arena-decorations.lua) performs
native Aseprite pixel authoring, saved-master readback and native image exports.
[palette.oklch.json](palette.oklch.json) holds authored material ramps and exact
reference theme accents in OKLCH; conversion to RGB occurs only inside Aseprite.
There is no image-generation service or external raster postprocessing.

To export saved masters without overwriting manual art changes, run from the
repository root (replace `aseprite` with the installed executable):

```sh
aseprite --batch --script-param export_only=true --script assets/pipeline/build-arena-decorations.lua
```

Omitting `export_only=true` deliberately recreates the nine masters from the
authored Lua source before exporting. Use that mode only when regeneration is
intended; after hand edits, the saved `.aseprite` is authoritative. For a different
working directory, pass `--script-param root=/absolute/path/to/arenic-sept-godot`.

[native-readback.json](native-readback.json) records the reopened masters' layers,
tags, pivots, durations and pixel counts. [validation.json](validation.json) records
RGBA/region/border checks, file hashes and the export-only stability check.

The reference `arena.rs` establishes nine arena identities, palettes and
atmospheric voices; its rendered props are primitive placeholders.
`_docs/arena_model.go` additionally names flora/fauna concepts, such as the
Lanternthorn Hedge and Cinder Beetle. These new recognizable objects are a
creative 2D interpretation of the themes, not reproductions of those named
concepts. The floor signatures and sparse sky-swarm preserve the source
arena grammar. The palette references are the checked local clone's
`crates/arenic_game/src/theme/palettes.rs` and `theme-css/arenic.css`.
