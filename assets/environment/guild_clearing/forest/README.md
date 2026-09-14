# Guild clearing forest and gold mine

Five separately authored overhead trees: a broad oak, split yellow-green birch,
long needle pine, crooked broadleaf and compact five-whorl fir. Their irregular
crowns retain distinct silhouettes at native game scale. Exposed roots, sparse
grass, clustered leaves and soft shadows ground each tree without a tile or
framed base. The mine combines a natural stone outcrop, gold seams, dark cut,
timber bracing, short rails and edge shrubs.

Review the [labeled booklet](previews/index.html),
[native tree contact sheet](previews/trees-field-1x.png) and
[native mine contact sheet](previews/mine-field-1x.png). The checkered grass is a
preview background only; runtime atlases have transparent backgrounds.

| Master | Canvas / pivot | Tags and atlas |
| --- | --- | --- |
| [trees.aseprite](trees.aseprite) | 76 × 76 / (38, 38) | `oak`, `birch`, `pine`, `crooked`, `fir`, each `_n`, `_e`, `_s`, `_w`; 304 × 380 atlas, four columns and five rows |
| [mine.aseprite](mine.aseprite) | 95 × 95 / (47, 47) | `mine_n`, `mine_e`, `mine_s`, `mine_w`; 380 × 95 atlas, four columns |

Directions are ordered north, east, south, west. Mine direction is the entrance
approach; tree directions label the canonical composition and successive
clockwise quarter-turns. Geometry rotates clockwise while canopy/stone lighting is repainted for a fixed screen
upper-left light and the shadow remains toward screen bottom-right. Frames are
static variants, each tagged independently with a one-second editing duration.

Each master retains five editable layers: grounded shadow; roots, grass and
soil; structure silhouette; material planes; and leaf/mineral/edge clusters.
The full-canvas slice records the pivot and the document grid is 19 × 19.
Native material pixels are opaque; only the grounded shadows use partial alpha.
Every exported frame preserves at least three transparent pixels on all sides.

The [local foliage ramps](palette.oklch.json) are authored in OKLCH and extend
the existing [environment material palette](../../palette.oklch.json). RGB
conversion happens only in the native Aseprite authoring script. No ImageGen,
external image synthesis or raster postprocessing is used.

Runtime files are [trees.png](../../../../arenic-game/assets/environment/guild_clearing/forest/trees.png),
[trees.json](../../../../arenic-game/assets/environment/guild_clearing/forest/trees.json),
[mine.png](../../../../arenic-game/assets/environment/guild_clearing/forest/mine.png)
and [mine.json](../../../../arenic-game/assets/environment/guild_clearing/forest/mine.json).
JSON maps each stable tag to its exact untrimmed region and pivot. Use nearest
sampling, lossless texture import, no mipmaps and no automatic 3D compression.
At `pixel_size = 0.25 / 19`, tree canvases cover four game tiles and mine canvases
cover five; these visual bounds do not define collision or gathering state.
The owning stage chooses placement and layering.

To export the saved masters without replacing hand edits, run from the repository
root (replace `aseprite` with the installed executable):

```sh
aseprite --batch --script-param root="$PWD" --script assets/pipeline/build-guild-forest.lua
```

Pass `--script-param rebuild=true` to deliberately reconstruct the masters from
the authored [Lua pixel score](../../../pipeline/build-guild-forest.lua). After
manual editing, the saved master is authoritative. The pipeline reopens both
documents and checks every frame's dimensions, exact tag range, opaque material,
translucent shadow and transparent margin before producing atlases and previews.
[validation.json](validation.json) contains that native pixel readback.
[export-hashes.json](export-hashes.json) records the SHA-256 hashes of both
masters and both runtime atlases; export-only mode reproduced all four exactly.
All 20 tree frames and all four mine frames have distinct pixel exports.

Both sheets were visually inspected at 1× and 3×. Native MCP independently
confirmed canvas sizes, five layers and all 24 static tags. The first conifer
pass was revised to separate the elongated needle pine from the compact fir;
stone chips were added to break up broad mine facets. Stage integration and
in-game placement are separate from this source-art verification.
