# Starter ability and movement audio

Runtime sound scope is the eight approved starter abilities and two shared movement cues: **22 clips**. The other 24 studied abilities remain source-side previews. Arena music keeps its separate clocks and playback contract in [arena-music.md](arena-music.md).

## Event ownership

Combat state determines charge, release, actual application, sustained activity, completion and cancellation. Sound observes those events; it never applies damage, advances cooldowns, or treats an animation frame as proof of a hit. A rejected cast must not sound like an accepted attack. Impact cues belong to actual model applications, including support applications, rather than an unconditional timer after every cast.

The authoritative signal is `ability_phase(ability_id, phase, arena_id, cell: Vector2, cast_id)`. Phases are `charge`, `cast`, `sustain`, `impact`, `end` and `cancel`. Accepted cast IDs increase within the run; rejected input emits nothing and consumes no ID. Auto Shot and Acid Flask charge at accepted windup and release at their authored **0.26 seconds**, clamped to impact time. Other starters cast immediately; channels and auras then start sustain. Natural completion emits `end`, while a held release, movement or invalid owner emits `cancel`.

Actual damaging hits emit impact at the occupied footprint's geometric center: the default 6 × 6 footprint at `(30, 22)` uses `(32.5, 24.5)`. Cleanse emits an impact for each ally whose support state changes, at that ally's cell. A miss emits no impact. An empty, fully healthy Cleanse emits cast/end only. `active_cast_snapshot()` includes `cast_id`, `released` and `release_seconds` so restored presentation can resume a loop without replaying a one-shot.

Movement audio follows the resolved step: `move` is for a successful tile change and `blocked` is for rejected movement. Key repeats, navigation keys and camera movement are not footsteps. A held channel stops with release, movement, focus loss or its other gameplay cancellation boundaries. Finite Fortune retains its own lifetime after key-up. Cancelling or replacing presentation must stop its owned loop voices without replaying a cast or hit.

## Explicit resources

Schemas live under `arenic-game/scripts/audio/`:

- `ArenicSoundCue` (`sound_cue.gd`) owns the stream, gain, per-cue instance limit, minimum interval, priority, loop flag and stop-fade duration.
- `ArenicAbilitySoundProfile` (`ability_sound_profile.gd`) exposes `charge`, `cast`, `impact`, `sustain`, `end` and `cancel`. `cue_for_phase(phase)` uses an explicit match and returns `null` for an unknown or absent phase.
- `ArenicMovementSoundProfile` (`movement_sound_profile.gd`) exposes `move` and `blocked`.

Profiles are authored in `arenic-game/data/audio/abilities/<ability_id>.tres` and `arenic-game/data/audio/movement.tres`. They reference `res://assets/audio/sfx/<ability_id>/<phase>.wav` and `res://assets/audio/sfx/shared/{move,blocked}.wav`. Resource fields control routing; neither filenames nor source preview timestamps decide playback.

| Starter / source ID | Cast | Impact | Charge loop | Sustain loop |
| --- | --- | --- | --- | --- |
| Auto Shot / `auto_shot` | Yes | Yes | Yes | — |
| Bash / `bash` | Yes | Yes | — | — |
| Backstab / `backstab` | Yes | Yes | — | — |
| Acid Flask / `acid_flask` | Yes | Yes | Yes | — |
| Sacrifice / `heal` | Yes | Yes | — | Yes |
| Cleanse / `cleanse` | Yes | Yes | — | — |
| Dig / `dig` | Yes | Yes | — | — |
| Fortune / `fortune` | Yes | Yes | — | Yes |

`end` and `cancel` are explicitly null in the starter profiles. They reserve optional one-shot endings; they do not require an invented clip. The normal loop-stop fade still applies. A 0.5-second charge recording can loop until the actual release boundary, even when release occurs earlier than the recording's duration.

## Authored playback limits

| Cue | Gain | Maximum instances | Minimum interval | Priority | Loops |
| --- | ---: | ---: | ---: | ---: | --- |
| Movement | +1 dB | 1 | 0.065 s | 20 | No |
| Blocked step | 0 dB | 1 | 0.100 s | 15 | No |
| Cast | +2 dB | 2 | 0.045 s | 60 | No |
| Impact | +3 dB | 3 | 0.045 s | 80 | No |
| Auto Shot charge | −3 dB | 1 | 0.045 s | 45 | Yes |
| Acid Flask charge | +6 dB | 1 | 0.045 s | 45 | Yes |
| Sacrifice sustain | +1 dB | 1 | 0.045 s | 40 | Yes |
| Fortune sustain | 0 dB | 1 | 0.045 s | 40 | Yes |

Every authored cue has a **0.035-second stop fade**. These resource values are independent of source-file peak normalization. Cue validation requires a finite positive stream duration, finite gain between −80 and +6 dB, one to eight instances, an interval/fade between zero and one second, and priority 0–100. Loop cues need a positive fade. Starter profiles require cast and impact; charge/sustain must loop, while cast/impact/end/cancel and both movement cues are one-shots. Optional null phases are valid.

`ArenicGameplayAudio` (`arenic-game/scripts/audio/gameplay_audio.gd`) allocates **12 reusable spatial players**: two reserved for loops and ten for one-shots. Each player has polyphony one and streamed playback. Admission respects the per-cue limits and priority, considering both a playing cue and its pending replacement. Higher-priority pending sounds cannot be displaced by a lower-priority request. Each voice keeps at most one latest replacement; there is no growing event backlog.

Voices fade in over 8 ms. A newly replaced voice retires over 18 ms; an already-running retirement keeps its existing fade. A pending one-shot is discarded after 100 ms rather than playing late. A pending loop instead revalidates its cast ID/phase against current model state and resumes at the current loop offset after a stall. Cancelled or expired activity cannot restore a stale loop. Normal charge/sustain stops use their authored 35 ms fade.

The director duplicates source streams before applying loop flags and complete-frame loop boundaries. SFX uses its own `ArenicSFX` bus, routed to Master with a −3 dB limiter, and shares music's existing camera listener. It is audible only in the focused arena while the application is in the foreground. Overview, another arena, backgrounding and stage replacement retire obsolete sound. Returning can restore an active charge/sustain at its current phase; it never replays past casts, impacts or movement. Music's director, stream settings and independent clocks remain separate.

The WAVs already have restrained source peaks, so cue gain is not another blanket attenuation. The values above were calibrated against measured source levels; decoded output and subjective mix review remain separate checks.

## Source and runtime handoff

ElevenLabs `text_to_sound_effects` produces the original `mp3_44100_128` source clips. The tool does not expose a model identifier; no model upgrade is implied. Each canonical source has a sibling `.generation.json` with its exact request and returned-file provenance. [starter-generation-plan.json](../assets/audio/starter-generation-plan.json) defines the bounded request set; [starter-runtime-manifest.json](../assets/audio/starter-runtime-manifest.json) records delivered source/runtime hashes and processing measurements.

The exporter, `assets/pipeline/export-starter-audio.py`, prepares uncompressed mono PCM16 WAV at 44.1 kHz, preserving that representation through explicit Godot import settings. Source peaks stay at or below −12 dBFS. Movement, blocked and both charge files are exactly 0.5 seconds. Each two-second sustain source becomes a 1.94-second loop using a 60 ms circular crossfade and native WAV loop markers. Charge-only onset alignment removes quiet preparation before release where required, then retains the half-second duration; the original MP3 is unchanged. The manifest records actual frames, duration, gain, onset adjustment and loop metadata per clip. Original source recordings remain under `assets/audio/`; runtime WAVs live under `arenic-game/assets/audio/sfx/`. Regeneration replaces explicit cue resources or their referenced files and updates provenance; it does not rename gameplay phases or derive timing from the waveform.

All 22 real ElevenLabs clips were delivered. Source/PCM validation passed 160 assertions covering decoded format, nonzero samples, measured peaks, exact shared-cue durations, preserved source hashes and loop/import metadata. The two sustain boundaries have measured sample jumps below 0.00055; this numeric seam check does not establish subjective listening approval.

On September 10, 2026, the complete native suite passed **16 headless and 5 rendered checks**. This includes **182 SFX assertions** covering resources, model-driven playback, private stream metadata, voice limits, queue priority/deadlines, cancellation and restoration, plus **281 combat-model assertions**. A visible native GameShell playtest also exercised movement, collision and Hunter casting without runtime warnings or errors; it started 11 voices with a peak of three concurrent voices and observed charge, cast, impact and end events.

Both focused Chromium SFX cases passed in 22.4 seconds, with nonzero decoded SFX bus samples while music remained active. The measured peak was 0.2271 and the maximum active voice count was three; channel release returned to silence. The other 26 browser cases passed in 3.6 minutes, completing **28/28 Chromium cases** against fresh production and private probe exports. These checks establish playback and lifecycle behavior, while subjective listening remains unverified. See [the source audio guide](../assets/audio/README.md), [browser validation](../tests/web/README.md) and [combat rules](combat.md).
