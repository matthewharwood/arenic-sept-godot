# Guild clearing tavern

`tavern.aseprite` is the editable native source: 247 × 171 RGBA pixels, nine
independent material/detail layers, one `tavern` frame, and center pivot
`(123, 85)`. It depicts one true overhead building at 19 pixels per tile.

The warm pitched shingle roof has a west pantry extension, stone chimney,
timber straps, a thin south wall and porch, a tankard/TAVERN sign, and attached
barrels and gutter vines. Lighting comes from the upper left. Colors are
authored in the shared environment OKLCH palette plus the local russet and
stone swatches; the Lua script converts them only at Aseprite's RGBA boundary.

The runtime PNG is untrimmed and nearest sampled at
`arenic-game/assets/environment/guild_clearing/tavern/tavern.png`. The matching
JSON records its dimensions and native anchor. Visible pixels occupy inclusive
`(11, 19)..(234, 150)`; the last 20 bottom rows remain transparent. The south
wall lies around native y132, and the porch anchor `(136, 150)` is 65 pixels
below the center. Engine placement, the stable training-target identity and
its animation wrapper remain separate from this art source.

From the repository root, with Aseprite on PATH:

```sh
aseprite --batch --script-param root="$PWD" --script assets/environment/guild_clearing/tavern/build.lua
aseprite --batch --script-param root="$PWD" --script assets/environment/guild_clearing/tavern/preview.lua
```

Normal execution exports the saved master without rewriting it. Use the
additional `--script-param rebuild=true` only when deliberately replacing the
master with the original pixel score. Keep subsequent manual refinements in
the master. `preview.lua` uses Aseprite to compose the exported tavern, seated
Keeper and authored grass; its preview is not a runtime placement test.

Reviewed the native and 4× frame, plus the grass composition. Aseprite MCP
readback verifies the canvas, nine visible layers and one tag; export scans
verify transparency margins and preserve exact native dimensions. Runtime
integration and rendered in-game review are performed by the game owner.
