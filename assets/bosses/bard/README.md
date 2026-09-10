# The Resonant Mastiff

Layered native source: [bard.aseprite](bard.aseprite). Portrait: [reference](../portraits/bard.png). This boss uses a 114 × 114 transparent RGBA canvas, a (57, 57) pivot, and a six-cell presentation footprint at the 19-pixel tile scale. It contains idle visual states only.

The mastiff is viewed down onto its copper back, skull crown, dorsal muzzle, floppy ears, four paws, and curled tail. A plum collar and gold resonator bells preserve the portrait identity. Breathing, ears, tail, and collar fittings move independently.

| Tags | Frames per direction | Loop duration |
| --- | ---: | ---: |
| `idle_n/e/s/w` | 12 | 2160 ms |

North/east/south/west are exact full-canvas quarter-turns. On an even 114-pixel canvas, pixel rotation is around (56.5, 56.5); the recorded placement pivot remains the requested (57, 57). The pivot is presentation metadata, not an authored collision shape.

The native file is authoritative after manual edits. [authoring.lua](authoring.lua) is the initial native construction recipe and requires `--script-param output=<absolute path to this directory>`. Rebuilding deliberately replaces the saved drawing. [palette.oklch.json](palette.oklch.json) retains the authored colors; conversion to RGBA happens at the Aseprite boundary.

Review files live in [previews/](previews/). The contact sheet places N/E/S/W first, then four north-facing phase samples in each state row, in manifest order. Default-state GIFs use 2× nearest-neighbor display scale. They are review artifacts outside the game directory.

[validation.json](validation.json) records the native audit: 48 frames, 6 editable layers, binary transparency, nonempty frames, exact cardinal rotation and timing, a consistent pivot, and at least eight distinct north-facing frames per state. The union of opaque pixels across all directions stays within (6, 6, 107, 107). Static frames and contact sheets were inspected; the shared gallery owns full-speed playback review and game integration.
