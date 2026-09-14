# Guild gate

The native master is `guild_gate.aseprite`: a true overhead double gate with gold fittings, ink-violet inset work, worn threshold slabs, and independently editable leaves. The source has six layers and a transparent 57 × 38 canvas. Its anchor is **(28,28)**, the middle of the closed passage, rather than the canvas center. Hinge centers are (6,28) and (50,28); the leaves swing north.

| Tag | Frames (Aseprite, 1-based) | Timing | Runtime playback |
| --- | --- | --- | --- |
| `locked` | 1–2 | 800 ms each | Loop |
| `opening` | 3–12 | 140 ms each; 1.4 seconds total | Once |
| `open` | 13 | 1 second | Loop/static hold |

The locked and opening first frames match exactly, as do the opening final frame and the open state. The collider and prologue state are game-owned; pixels, alpha bounds, and animation completion do not determine passage authority. A centered Godot sprite uses offset `(0,-9)` to honor the native anchor, and must explicitly use nearest filtering.

Palette values are authored in `palette.oklch.json`; the native Lua authoring boundary converts them to Aseprite's RGB representation. The saved master wins over the construction script, so later hand edits survive exports.

From the repository root, replacing `aseprite` with the installed executable path when needed:

```sh
# Construct only if the master is absent; existing sources are preserved.
aseprite --batch --script-param root="$PWD" --script-param asset=gate --script assets/pipeline/build-prologue-art.lua
# Validate both prologue masters and export saved native pixels and timing.
python3 assets/pipeline/export-prologue-art.py --aseprite aseprite
```

Runtime files are `res://assets/environment/guild_gate/guild_gate.png`, `guild_gate.json`, `guild_gate_frames.tres`, and `guild_gate_export.json`. Exports retain untrimmed native frames, lossless texture import, unchanged alpha edges, no mipmaps, and source hashes. Review PNGs/GIFs stay in `previews/`; their looping opening GIF is a review aid, not the runtime one-shot contract.

Verification: Aseprite 1.3.18.5 native readback checked frame bounds, six layers, pivot, complete nonoverlapping tag coverage, exact timing, unclipped alpha margins, and locked/open endpoint equality. The locked, intermediate opening, and open pixels were inspected at 8× through Aseprite exports; the actual source was also opened and its gate motion played in Aseprite. Runtime placement and prologue collision are verified by the owning game integration.
