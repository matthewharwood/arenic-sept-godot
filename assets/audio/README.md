# Ability audio

All 32 studied abilities have stable preview sound events in `events.json`; the preview queue now contains 94 requests, including the two authored starter charge phases. Runtime authorization now covers **22 starter/shared clips**: cast and impact for eight starters, charge for Auto Shot and Acid Flask, sustain for Sacrifice and Fortune, and shared move/blocked sounds. The other 24 abilities remain source-side previews.

All 22 runtime clips have been generated through ElevenLabs. [starter-generation-plan.json](starter-generation-plan.json) owns the requests; [starter-runtime-manifest.json](starter-runtime-manifest.json) owns the delivered sources, hashes and processing measurements. [generation-status.json](generation-status.json) records the successful batch and retains the earlier authentication failure in its history. The broader preview manifest has 20 ready ability cues and 74 pending; the two shared cues are separate. Missing preview sounds remain pending rather than being substituted with silence.

## Naming and phases

| Hook | Meaning | Playback |
| --- | --- | --- |
| `charge` | Real windup or held preparation, where the ability has one | Start on input; stop on cancellation or release |
| `cast` | Activation, release, or passive proc | One shot; play once per activation |
| `impact` | Contact, application, deflection, or resolution | One shot at the actual event; not an unconditional cast timer |
| `sustain` | Active channel, traveling roll, held guard, persistent field or status | Loop while that state exists; stop on exit/cancel/despawn |
| `end` | Optional custom normal-expiry sound | Reserved one-shot hook; no starter clip authored |
| `cancel` | Optional custom interruption sound | Reserved one-shot hook; no starter clip authored |

Event IDs are `<hero>.<ability_id>.<phase>`, such as `hunter.poison_shot.impact`. Slots 1–4 are a mapping in the hero manifest, never a filename: rearranging a hotbar must not rename assets. An impact on a support ability means a heal/shield/buff application, not damage. A passive trigger must not become an extra active cast.

Canonical ability sources are `abilities/<hero>/<ability_id>/<phase>_01.mp3`; shared movement sources are `shared/{move,blocked}_01.mp3`. One generated variant is retained per authorized phase. Each generated file has a sibling `<phase>_01.generation.json` storing provider, exact prompt, duration, loop flag, output format, original returned file path, and generation date. Keep credentials out of all project files and logs.

## Generating and replacing

1. For the authorized runtime set, use `starter-generation-plan.json`. The broader `python3 assets/pipeline/prepare-ability-audio.py` queue covers all 32 preview abilities and does not expand runtime authorization; it retains readiness only when both audio and provenance exist.
2. For each pending request, call ElevenLabs MCP `text_to_sound_effects` with its `text`, `duration_seconds`, `loop`, `output_directory`, and `output_format`. Use small bounded batches; stop on authentication or quota errors. Check the returned path before retrying an uncertain response.
3. Copy the actual returned clip to its canonical path and write provenance. Do not substitute silent or synthesized files and label them ElevenLabs output.
4. Run `python3 assets/pipeline/export-starter-audio.py` for the authorized runtime set. It writes measured mono PCM16 WAV at 44.1 kHz and the runtime manifest, preserving the original MP3s. Decode-check durations, listen to representative casts/impacts/channels, and check loop seams. Rebuild preview event manifests and galleries separately when updating those studies.
5. To replace a clip later, keep the canonical event ID/file path and update its provenance. Run the same export. Source manifests own sound intent; typed Godot profiles explicitly select runtime phase cues. Actual model events own playback timing, not preview timestamps or filenames.

The common sound palette is compact, dry, tactile fantasy audio with restrained highs and short tails; no speech or background music. Bard effects use brief instrumental gestures. The generated source format is `mp3_44100_128`; the tool exposes no model identifier. Playback gain is separate from generation; the gallery starts muted at 45% volume and prevents the four closeups from sounding simultaneously. Manual loop auditions stop after three seconds. Pause, seeking, changing ability/facing, and leaving the page stop active sounds. Slower visual playback also slows audio for inspection; runtime pitch and loudness are not specified by that review behavior.

Gallery cue times are staged demonstrations. A trap impact occurs on a staged collision, a shield impact on a staged deflection, and Coin Toss illustrates the maximum five-second hold. Runtime must use actual gameplay events and must cancel charge/sustain audio when interrupted. Mimic overlays need the original copied ability’s effect and sound at integration. The 22 authorized runtime cues are exported under `arenic-game/assets/audio/sfx/` and referenced by typed profiles in `arenic-game/data/audio/`. Cast/impact are one-shots, charge/sustain are loops, and all starter end/cancel fields are explicitly null. The per-cue gains, budgets and stop fades are documented in [the runtime audio contract](../../docs/ability-audio.md).

Source/runtime checks passed 160 assertions: original MP3 hashes preserved, mono PCM16 at 44.1 kHz, nonzero signal, peaks at or below −12 dBFS, exact 0.5-second movement/blocked/charge cues, and explicit uncompressed Godot imports. Both sustains use a 60 ms circular crossfade and native loop markers, with measured boundary jumps below 0.00055. Acid Flask charge has a documented 169.6 ms quiet-preroll adjustment so the short real windup can be heard; its source MP3 remains untouched. All 21 native checks and 28 Chromium cases passed on September 10, 2026, including 182 native SFX assertions for resource, playback and lifecycle contracts. The browser run used fresh production and private probe exports. Both focused SFX cases passed with decoded sound output, music retained and silence after channel release; a visible native movement/collision/Hunter playtest had no runtime warnings or errors. Subjective listening remains a separate, unverified check.

## Preview timing windows

Every phase has `preview_window.start_ms` and exclusive `end_ms` in `events.json`. These are illustrative timings for one review cycle; they are not runtime timers. Charge ends at release, a rolling Boulder sustains only during travel, Dance sustains during its eight beats, and the real release-frame duration is reserved after a held guard or healing channel. `condition` can gate a cue by the visible `growth` or `helix-state` control; a seed must not sound as though it heals. Runtime emits the same stable event IDs from actual state transitions, with its own stop/cancel events.
