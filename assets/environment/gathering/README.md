# Guild House gathering sites

Four static overhead objects share the existing
[environment OKLCH palette](../palette.oklch.json): an evergreen and cut logs,
a timber-braced gold seam, a receiving timber rack, and an open gold strongbox.
The [native master](gathering_sites.aseprite) is 57 × 57 RGBA pixels with pivot
(28, 28), four material layers and one independent frame/tag per object.

| Frame | Tag | Use |
| --- | --- | --- |
| 1 | `wood_source` | Preserved source study; current sites use clearing trees |
| 2 | `gold_source` | Preserved source study; current mines use clearing outcrops |
| 3 | `wood_dropoff` | Wood receiving area |
| 4 | `gold_dropoff` | Gold receiving area |

The transparent [native preview](previews/gathering_sites.png) and
[4× review](previews/gathering_sites-4x.png) are exported directly by Aseprite.
See the [preview page](previews/index.html) for individual objects. The 228 × 57
runtime atlas and region metadata live in
`arenic-game/assets/environment/gathering/`. Keep nearest filtering, lossless
compression, no mipmaps, and unchanged alpha-border pixels. One source pixel is
one close-view pixel with `pixel_size = 0.25 / 19`.

`ArenicGatheringSiteView` mounts at the local origin of the Guild House
`ArenicArenaView`. `configure(definition)` builds all six site views. The
definition owns cell positions and Euclidean radius, drawn as a quiet dashed
ring. Current wood and mine views use the
[clearing forest atlas](../guild_clearing/forest/README.md); receiving rack and
strongbox remain frames 3 and 4 of this atlas. The rack is at `(23,21)` left of
the tavern and the strongbox at `(42,21)` right. No world resource-name,
dropoff or Bank labels are mounted, and this static scenery view no longer
reads bank state. The gathering model retains exact saved balances, and real
deposits still publish their activity observation.

`ArenicHeroView.set_gathering_status(snapshot)` adds a small resource-colored sack
meter and amount near the actor. Full bags say `Wood full` or `Gold full`;
unloading drains the meter while the label names the resource. The caller passes
an empty snapshot on death, and fallen ghost views also hide their meter directly.
These controls observe state and never start, advance, or deposit work.

Re-export the saved master without changing hand edits:

```sh
aseprite --batch --script-param root=/absolute/path/to/arenic-sept-godot \
  --script assets/pipeline/build-gathering-sites.lua
```

Pass `--script-param rebuild=true` only to deliberately regenerate the master
from the authored pixel score. Native Aseprite metadata confirms four separate
static tags and four editable layers. An earlier disposable Godot fixture
verified the original six placements, native pixel scale, the then-present bank
labels, full/carry/unloading states, and hiding the bag view when its snapshot
clears. That historical fixture predates removal of world labels and relocation
of the dropoffs. Current integration checks are reported separately; the source
master and atlas pixels are unchanged by those presentation and placement edits.
