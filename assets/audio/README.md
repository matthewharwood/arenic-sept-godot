# Ability audio

All 32 abilities have stable sound events in `events.json`. The first-pass queue contains 92 ElevenLabs requests. Audio generation is currently blocked: the configured ElevenLabs MCP credential is an API-key ID rather than a valid API key. **No sound files have been generated.** `generation-status.json` records that result; absent sounds are visibly pending in the galleries.

## Naming and phases

| Hook | Meaning | Playback |
| --- | --- | --- |
| `charge` | Real windup or held preparation, where the ability has one | Start on input; stop on cancellation or release |
| `cast` | Activation, release, or passive proc | One shot; play once per activation |
| `impact` | Contact, application, deflection, or resolution | One shot at the actual event; not an unconditional cast timer |
| `sustain` | Active channel, traveling roll, held guard, persistent field or status | Loop while that state exists; stop on exit/cancel/despawn |
| `end` | Optional custom expiry/cancel sound | Reserved hook; no clip unless specified |

Event IDs are `<hero>.<ability_id>.<phase>`, such as `hunter.poison_shot.impact`. Slots 1–4 are a mapping in the hero manifest, never a filename: rearranging a hotbar must not rename assets. An impact on a support ability means a heal/shield/buff application, not damage. A passive trigger must not become an extra active cast.

Canonical files are `abilities/<hero>/<ability_id>/<phase>_01.mp3`. One placeholder variant is planned per applicable phase. Each generated file has a sibling `<phase>_01.generation.json` storing provider, exact prompt, duration, loop flag, output format, original returned file path, and generation date. Keep credentials out of all project files and logs.

## Generating and replacing

1. Run `python3 assets/pipeline/prepare-ability-audio.py` from the repository root. It rebuilds the finite request queue from the eight hero manifests and retains readiness only when both audio and provenance exist.
2. For each pending request, call ElevenLabs MCP `text_to_sound_effects` with its `text`, `duration_seconds`, `loop`, `output_directory`, and `output_format`. Use small bounded batches; stop on authentication or quota errors. Check the returned path before retrying an uncertain response.
3. Copy the actual returned clip to its canonical path and write provenance. Do not substitute silent or synthesized files and label them ElevenLabs output.
4. Decode-check durations, listen to representative casts/impacts/channels, and check loop seams. Then rebuild the event manifest and character galleries.
5. To replace a clip later, keep the canonical event ID/file path and update its provenance. Run the same rebuild. Source manifests own sound intent; audio events resolve files; game code will emit the events after integration.

The planned common sound palette is compact, dry, tactile fantasy audio with restrained highs and short tails; no speech or background music. Bard effects use brief instrumental gestures. Planned format is `mp3_44100_128`. Playback gain is separate from generation; the gallery starts muted at 45% volume and prevents the four closeups from sounding simultaneously. Manual loop auditions stop after three seconds. Pause, seeking, changing ability/facing, and leaving the page stop active sounds. Slower visual playback also slows audio for inspection; runtime pitch and loudness are not specified by that review behavior.

Gallery cue times are staged demonstrations. A trap impact occurs on a staged collision, a shield impact on a staged deflection, and Coin Toss illustrates the maximum five-second hold. Runtime must use actual gameplay events and must cancel charge/sustain audio when interrupted. Mimic overlays need the original copied ability’s effect and sound at integration. No final audio exports have been placed inside `arenic-game/`.

## Preview timing windows

Every phase has `preview_window.start_ms` and exclusive `end_ms` in `events.json`. These are illustrative timings for one review cycle; they are not runtime timers. Charge ends at release, a rolling Boulder sustains only during travel, Dance sustains during its eight beats, and the real release-frame duration is reserved after a held guard or healing channel. `condition` can gate a cue by the visible `growth` or `helix-state` control; a seed must not sound as though it heals. Runtime emits the same stable event IDs from actual state transitions, with its own stop/cancel events.
