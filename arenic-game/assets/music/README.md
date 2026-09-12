# Music

## Title theme

`title_theme_v1.mp3` is the user-supplied **Arenic Theme Song.mp3**, moved unchanged
from Downloads. Its hash, source name and measurements are recorded in
`title_theme_v1.json`. The Inspector-editable title score selects it through
`res://data/music/title_theme_v1.tres`; see [title music](../../../docs/title-music.md)
for playback ownership and replacement controls.

## Arena music V3

Nine user-supplied48kHz stereo MP3s, retained without re-encoding. Canonical filenames
are `{arena_id}_v3.mp3`; original names, unchanged SHA256 hashes, source durations,
and quiet-tail measurements are recorded in [manifest_v3.json](manifest_v3.json).
Godot imports every stream with native looping enabled from offset0.

| Arena | Source duration | Bytes |
| --- | ---: | ---: |
| labyrinth | 119.880s | 2,869,783 |
| guild_house | 119.040s | 2,933,733 |
| sanctum | 118.872s | 2,955,067 |
| mountain | 119.960s | 2,718,357 |
| bastion | 118.824s | 2,867,936 |
| pawnshop | 119.480s | 2,871,150 |
| crucible | 120.024s | 2,949,295 |
| casino | 119.520s | 2,789,179 |
| gala | 119.520s | 2,889,859 |

Definitions live in `res://data/music/{arena_id}_v3.tres`; each arena's `music` field
selects its versioned definition. `id` remains the stable arena id, `version` is 3,
`loop_seconds` records the actual source duration, and `gain_db` defaults to −12 dB.
Godot 4.7.2 runtime duration readback agrees with these three-decimal values within
0.000004 s. Exact engine values and separate ffprobe measurements are in the manifest.
Validation allows 0.15 s for future decoder frame/padding differences.

Most files include quiet endings; native looping does not make the musical join
seamless. The manifest records terminal intervals below −50 dB, not a listening verdict.
All nine files decoded successfully during the asset audit.

For a replacement, add a new versioned audio file and definition, enable import
looping, record the new duration/hash, and update only the matching arena's `music`
reference. Keep previous versions available until explicitly retired.

Godot supports MP3 directly and recommends preserving an MP3 source when no higher
quality original is available, avoiding a second lossy conversion:
[ResourceImporterMP3](https://docs.godotengine.org/en/stable/classes/class_resourceimportermp3.html).
