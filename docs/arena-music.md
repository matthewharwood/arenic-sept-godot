# Arena music

`GameShell` owns `ArenicArenaMusicDirector` alongside the persistent HUD. The director owns independent arena clocks and a fixed playback pool; replacing the stage preserves clock phases and pause flags for matching arena IDs. Entering a new `GameShell` starts all nine clocks together at zero.

## Music data and replacements

Each `ArenicArenaDefinition.music` points to `res://data/music/{arena_id}_v3.tres`, an `ArenicArenaMusicDefinition` containing the stable arena `id`, `version`, `stream`, `loop_seconds`, and `gain_db`. The current gain is −12 dB. The stream references `res://assets/music/{arena_id}_v3.mp3` with native looping enabled at offset zero.

The nine supplied 48 kHz stereo MP3s are retained unchanged for native and Web builds. Actual durations range from **118.824 to 120.024 seconds**; clocks use each file's metadata duration, not an assumed 120 seconds. Original names, hashes, decoder measurements, and quiet-tail measurements are in the [music manifest](../arenic-game/assets/music/manifest_v3.json). See the [asset README](../arenic-game/assets/music/README.md) for the per-arena table and import contract. Quiet endings are retained; repeating the files does not establish a seamless musical join.

For V4, add a versioned audio file and definition, enable import looping, and record its actual duration and hash. Change the matching arena's `music` resource reference; no director logic needs changing. Keep prior versions until explicitly retired. The definition validates the ID, stream, version, duration, looping, and gain; duration agreement allows 0.15 seconds for decoder padding differences.

## Clock and playback contract

`ArenicArenaMusicClock` holds a wrapped position in `[0, duration_seconds)`. `configure(duration, phase = 0)` initializes it; `advance(delta)` accepts positive finite game time; `seek(seconds)` wraps signed finite positions; `running` controls advancement; `get_position()` reads the authoritative phase. Invalid advances/seeks leave the phase unchanged, and an invalid duration disables the clock.

All running clocks advance with game delta even while their arenas are inaudible. Decoders never supply timing authority. Returning to an arena starts its stream at its current clock phase. A stage replacement reuses clocks by arena ID; a changed duration wraps the preserved phase into the new duration.

Future choreography should use the director's independent controls:

```gdscript
shell.music.seek_arena(&"casino", 30.0)
shell.music.set_clock_running(&"casino", false)
shell.music.set_clock_running(&"casino", true)
```

A paused clock retains its phase and voice assignment but has **no active decoder**. Seeking a paused arena remains silent; resuming starts at the saved phase. Active seeks restart the existing player at the authoritative phase, including a seek in the same frame as a queued 3D play. `snapshot()` exposes phases, voice weights and sources, pending focus, and start/correction counts for diagnostics.

## Bounded mix and spatial sound

The director creates two music players and one hum player, each with polyphony one: at most **two music voices**, or **three voices including hum during a handoff**. A 100 ms debounce coalesces focus requests so the latest destination wins. Normal transitions take 650 ms with equal-power gains. If both music slots are occupied, the quieter slot retires over 90 ms before reuse. Interrupted fade weights are normalized to avoid an added gain boost.

Once per game second, active playheads are compared with their clocks using circular loop distance. Drift above 120 ms restarts the existing voice at the clock phase; application focus return requests the next check. This is recovery for suspension or long frames, not continuous per-frame seeking.

Music sources sit at actual arena centers. The listener follows camera focus and orientation, offset eight world units along the camera's backward axis instead of using its render height. Distance attenuation and Doppler are disabled; panning strength is 0.7.

Overview fades in a procedural hum at −26 dB. Its eight-second, 11,025 Hz, 16-bit mono PCM loop is synthesized once and cached: **176,400 bytes** of sample data. Its source makes a separate 48-second orbit around the listener. There is no per-frame audio synthesis.

## Native and Web

Native rendering remains Forward+. Godot 4 Web exports use Compatibility/WebGL 2. All three players explicitly select `Stream` playback so the engine mixer handles spatial sound and the generated hum; Web's default sample mixer has feature limitations, while streaming can increase latency. Browser autoplay may require a first click, tap, or keypress. [Godot Web export documentation](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html#audio-playback).

The same assets and music logic serve both targets. Browser background suspension may stop game processing, so clocks follow delivered game delta rather than promising wall-clock progress while suspended. Resume drift correction restores decoder alignment. `DisplayPolicy` skips desktop window overrides on Web, leaving browser canvas sizing intact.

## Verification

Godot 4.7.2 isolated-project checks passed on 2026-09-10:

- `tests/audio/clock_checks.gd`: **54 assertions** covering boundaries, large deltas, independent phase/pause, and invalid inputs.
- `tests/audio/music_checks.gd`: **289 assertions** covering nine V3 loops, silent clock advancement, real decoder seeks, bounded voices, burst coalescing, hum handoff, independent pause/resume, spatial sources, drift recovery, and stage clock preservation.

The integration check mutes its test process while checking decoder behavior; it does not establish listening quality. From the repository root, run these checks when a separate Godot process is safe:

```sh
godot --headless --path arenic-game --script res://tests/audio/clock_checks.gd
godot --headless --path arenic-game --script res://tests/audio/music_checks.gd
```

Additional checks passed; full measurements are in [arena-music-validation.json](arena-music-validation.json).

- Native CoreAudio mixed nonzero hum and music PCM. All nine MP3s continued across their encoded loop boundaries. Capturing the same passage with the listener on opposite sides verified the left/right balance reverses. A 50-request burst opened zero discarded tracks, settled on the latest arena and remained well below clipping.
- On an Apple M4 Max using Metal Forward+ at a requested 3436 × 1932 window, 2,929 director updates measured **0.075 ms p95 / 0.103 ms p99 / 0.513 ms maximum**. These are director CPU times, not full-frame timings, and exclude first-use synthesis/import. They do not guarantee 60 fps on other hardware.
- Chrome/WebGL 2, single-threaded export: pointer title → class → world, zoom, hotkeys, rapid retargeting and return to overview worked. After the first gesture, WebAudio ran at 44.1 kHz stereo. All nine tracks and the hum produced nonzero mixed PCM; all nine near-end seeks wrapped and kept playing. No browser errors or synchronization corrections occurred. The longer navigation run returned to Guild House around 106 seconds rather than restarting it.
- Scene flow (98 assertions), hero flow (112), display (78) and all 54 project scripts also passed their checks. Short audio tests await mixer retirement before quitting; the director stops its voices on exit.

`tests/audio/render_checks.gd` performs the real-driver PCM/panning/loop test. It writes its JSON and WAV evidence under `user://audio-validation/`, or the directory supplied in `ARENIC_AUDIO_TEST_OUTPUT`. Run it with a real audio driver; the two headless suites above cover logic without an audible test. Subjective headphone/speaker listening quality and sample-perfect musical joins were not assessed.

## Local Web export

The runnable **Web** preset uses a standard adaptive shell without threads. From the repository root, with matching Godot export templates installed:

```sh
mkdir -p .tmp/web
godot --headless --path arenic-game --export-debug Web "$PWD/.tmp/web/index.html"
```

Serve `.tmp/web/` over localhost or HTTPS; opening `index.html` as a file is insufficient. Keep the Toolkit editor plugin enabled during export so its export hook removes the development MCP autoload before the addon is excluded. The finished pack contains game/audio resources, without development tests or Toolkit runtime code.
