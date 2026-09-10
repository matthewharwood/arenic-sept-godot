# The Crucible Gel

Layered native source: [alchemist.aseprite](alchemist.aseprite). Portrait: [reference](../portraits/alchemist.png). This boss uses a 114 × 114 transparent RGBA canvas, a (57, 57) pivot, and a six-cell presentation footprint at the 19-pixel tile scale. It contains idle visual states only.

Emerald and violet gel continuously reshapes between a rounded bomb, a dorsal skull form, and narrow flask shoulders. The pale bone crown is embedded in the upper gel, with a brass neck, liquid fuse, and trapped bubbles. Surface gloss and bubbles are clipped to the changing gel boundary.

| Tags | Frames per direction | Loop duration |
| --- | ---: | ---: |
| `cycle_n/e/s/w` | 30 | 8040 ms |
| `bomb_n/e/s/w` | 8 | 1760 ms |
| `skull_n/e/s/w` | 8 | 1760 ms |
| `potion_n/e/s/w` | 8 | 1760 ms |

`idle_n/e/s/w` alias the corresponding full-cycle frame ranges. State tags hold one form; the cycle performs the transitions.

North/east/south/west are exact full-canvas quarter-turns. On an even 114-pixel canvas, pixel rotation is around (56.5, 56.5); the recorded placement pivot remains the requested (57, 57). The pivot is presentation metadata, not an authored collision shape.

The native file is authoritative after manual edits. [authoring.lua](authoring.lua) is the initial native construction recipe and requires `--script-param output=<absolute path to this directory>`. Rebuilding deliberately replaces the saved drawing. [palette.oklch.json](palette.oklch.json) retains the authored colors; conversion to RGBA happens at the Aseprite boundary.

Review files live in [previews/](previews/). The contact sheet places N/E/S/W first, then four north-facing phase samples in each state row, in manifest order. Default-state GIFs use 2× nearest-neighbor display scale. They are review artifacts outside the game directory.

[validation.json](validation.json) records the native audit: 216 frames, 6 editable layers, binary transparency, nonempty frames, exact cardinal rotation and timing, a consistent pivot, and at least eight distinct north-facing frames per state. The union of opaque pixels across all directions stays within (7, 7, 106, 106). Static frames and contact sheets were inspected; the shared gallery owns full-speed playback review and game integration.
