# Thief boss source

The portrait at `../portraits/thief.png` is the visual reference. `thief.aseprite` is the authoritative editable master: 114 × 114 RGBA pixels, full-canvas `frame` slice, center pivot (57, 57), true overhead orthographic view. One source pixel remains one display pixel at 720p; this is a six-cell presentation envelope, independent of collision and stats.

Three outfits: `obsidian`, `crimson`, `indigo`, each with eight 200 ms poses per cardinal direction (1600 ms). Each hold is followed by six 300 ms transition poses. `cycle_n/e/s/w` and `idle_n/e/s/w` alias the same 42-frame, 10200 ms sequence. The costume colors interpolate in OKLCH and cloth/feather lengths change gradually.

The layers separate body, equipment and secondary cloth or mechanical motion. Colors are authored in `palette.oklch.json` and converted to Aseprite RGBA only at the file-format boundary. `author-native.lua` records this initial native authoring pass; do not automatically rerun it over hand edits.

`boss.json` is the handoff manifest. `audit.json` is native readback of frame timings, named tags, pivot, visible bounds, palette membership, binary alpha, clear outer margin and exact cardinal rotations. Every standalone state has at least eight distinct poses. The four cardinal GIFs and enlarged contact/direction sheets in `previews/` are derived review files. No attacks, collision, stats, audio or runtime game exports are authored here.
