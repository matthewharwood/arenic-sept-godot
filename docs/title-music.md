# Title music

The title scene owns one non-spatial `TitleMusic` player. Its `Definition` points
to `res://data/music/title_theme_v1.tres`, an `ArenicTitleMusicDefinition` resource.
The supplied **Arenic Theme Song.mp3** is stored unchanged at
`res://assets/music/title_theme_v1.mp3`: 298.92 seconds, 48 kHz stereo, 6,979,886 bytes.
Its original name, SHA-256 and provenance are in the adjacent JSON manifest.

## Change it in the Inspector

Open `scenes/title/title_scene.tscn`, select **TitleMusic**, and expand
**Definition**, or open `data/music/title_theme_v1.tres` directly.

- **Stream** chooses the MP3. Add future tracks under `assets/music/`.
- **Gain Db** controls loudness, from −60 to 0 dB; the default is −12 dB.
- **Loop** repeats the complete track from the beginning; enabled by default.
- **Fade In Seconds** ranges from 0 to 5 seconds; the default is 0.75 seconds.
- **Enabled** disables music without removing the scene node.
- **Version** records the revision; create a new versioned resource/asset for a
  replacement, then assign that resource to the player's **Definition**.

The resource owns settings; `ArenicTitleMusic` owns playback. A future settings
screen can pass a replacement resource to `configure(definition)`, which stops
the old voice, cancels its fade and applies the new data. `configure(null)` stops
and clears music. No song path is hardcoded in the player. It duplicates only
the stream resource before setting looping, preserving shared import settings.
The authored definition participates in Godot Doctor's data preflight.

Native playback begins when the title opens. Web playback waits for a real
pointer, touch or key press, without consuming menu input or bypassing browser
autoplay policy. Clicking blank title paper lets the song play before Start.
The player uses streamed audio rather than decoding a five-minute Web sample.

Leaving the title stops and releases its voice immediately. Class selection is
silent, and the world retains its separate arena music. Returning to the title
starts the song from the beginning. No global music player or saved setting is
introduced. The full supplied song is retained; looping does not promise a
seamless musical join.

`tests/audio/title_music_checks.gd` verifies data, replacement, gain, loop/end,
disable, re-entry and teardown in the native lane. The clean-production browser
test verifies real gesture playback and silence after Start; it also runs in the
published-site verification job. These checks measure behavior, not subjective
mix quality.
