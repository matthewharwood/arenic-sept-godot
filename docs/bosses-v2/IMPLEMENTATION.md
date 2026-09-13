# Build plan and acceptance contract

## Current baseline and scope

This change is documentation and design data only. It does not alter authoritative, derived, or transient runtime state. It therefore requires scoped document/data checks, not a persistence build or an unrelated game deployment. The working tree already contains unrelated development changes; this package is confined to `docs/bosses-v2/`.

The active Godot model has a 60 Hz integer encounter clock, 7,200-tick cycles, typed score/beat resources, a folded master timeline, per-caster combat, eight live starters, intent recordings, cumulative damage, independent arena clocks and a save codec. `ArenicEncounterBeat.ACTION_IDS` currently contains only `boss_jump`. Its single-action beats are strictly ordered by time. The existing runtime cannot load these proposed multi-action scores unchanged.

The new work must follow the active repository’s [AGENTS.md](../../AGENTS.md), including its repository-local five-phase persistence skill when implementation changes gameplay/save semantics. Do not copy obsolete Bevy bundles, floats, RNG, or UI deception code from the legacy documents.

## Build slices

| Slice | Concrete result | Gate before continuing |
| --- | --- | --- |
| 1. Ruleset/content identity | Immutable content catalog addressed by arena, difficulty, ruleset revision and hash; retain the old Hunter score | Old saves/takes load against old resources with unchanged behavior. |
| 2. Typed v2 event model | Integer event records with simultaneous-action ordering, explicit masks, tags, durations, payloads, and pose track | Resource validation matches the JSON reference and rejects malformed data. |
| 3. Pure score conductor | Hazard/terrain/pose evaluation from cycle tick; fixed phase transfers; no node/timer authority | Empty arena and varied roster yield the same boss stream; seeks match sequential evaluation. |
| 4. Vitality and damage pipeline | Proposed 4-HP profile, wound/heavy/crush, Exposure, shields and bounded bonus packets | Boundary order, one-credit rules, defeat cancellation and live/replay parity. |
| 5. First playable encounter | Warrior’s duel, including small lateral transfers; then Hunter traffic | Visible telegraphs, exact masks, usable rear access, no-hit starter routes. |
| 6. Preparation and terrain | Alchemist chemistry and Forager rib lifecycle, with Dig/Acid ownership | No chemistry recursion or damage-gated geometry; field and terrain save/restore. |
| 7. Optional state/routes | Cardinal attunement, Bard floor credit, Thief portals, Merchant dividends | Neutral/walking/no-resource fallbacks; occupied portal exit and multi-actor tests. |
| 8. Future abilities | Implement the 24 proposed ability contracts in small families | Each new ability passes its eight targeted table cases and all interacting pair fixtures. |
| 9. Composition and presentation | Reserved routes, stage-native warning art, cues, feed attribution, per-arena checks | Native and browser validation, muted-audio readability, 40-ghost choreography and profiling. |

Build the encounter geometry before spending time on finished attack art. A debug overlay must show the exact authority cells and tick. Then replace it with authored effects without changing masks or timing. Keep boss appearance IDs and class/arena mapping stable; new encounter titles are presentation labels, not replacements for saved hero IDs.

## Proposed v2 data schema

`data/scores.json` is the readable design authority for this package; it is **not a Godot resource format**. A future importer should compile it into typed resources with the following concepts. Names below are proposed fields, not claims about existing APIs.

| Field | Type / unit | Meaning and validation |
| --- | --- | --- |
| `schema_version` | positive integer, proposed 1 | Structural shape of serialized score data, separate from simulation ruleset. |
| `ruleset_revision` | immutable identifier | Complete semantics including movement, damage, abilities, ordering and reset. |
| `content_hash` | SHA-256 | Canonical serialized content; no timestamps or paths in the hashed value. |
| `arena_id`, `difficulty` | stable catalog IDs | Existing arena identity; Normal is the only score authored here. |
| `cycle_ticks` | 7,200 | Reject another value under this draft’s ruleset. |
| `pose_track` | ordered `(tick, origin, facing)` | Initial pose at zero, legal full footprint, final pose equals opening; no player input. |
| `event_id` | unique stable string | Resolve simultaneous events by total order; never deduplicate on tick alone. |
| `action_id` | validated finite enum | Preserve the six encounter-specific meanings while compiling to shared primitives. |
| `cue_tick`, `at_tick`, `end_tick` | whole ticks | Cue precedes impact; end is exclusive; no event crosses the seam. |
| `masks` | ordered array of integer rectangles | Absolute geometry, bounds-checked; union cells once per event so overlapping rectangles do not hit twice. |
| `damage`, `tags`, `kind` | integers/enums | Wound/heavy/crush or optional window; tag controls protection. |
| `incoming_direction` | N/E/S/W | Explicit projectile defense orientation; no render-derived angle. |
| `pulse_offsets` | integer tick offsets | Repeating damage produces one stable child event per listed pulse. |
| `boss_origin`, `boss_facing` | optional pose payload | Must exactly agree with the pose-track entry at the event tick. |
| `mask_elements` | one element per mask | Cardinal Sun/Moon immunity follows the painted mask element after mirroring. |
| `portal_endpoints` | exactly two cells | Fixed Thief portal pair; vacancy check and personal cooldown are actor state. |
| `active_pad`, `dividend_pad` | integer rectangle | Optional actor eligibility geometry, not a compulsory hazard mask. |
| `window_condition` | finite enum, actor-local | Direct hit, prepared periodic tick, clean phrase, successful portal, matched seal, floor steps or pad occupancy. |

The draft JSON contains narrative metadata alongside event data. An importer should select the simulation fields explicitly; do not load arbitrary keys into runtime objects. Source strings, URLs, comments, editorial feature scores and ability-fit notes are not simulation authority. Preserve the exact compiled fixture as a reviewable golden file. Do not import Python, filesystem access or research tools into the game.

Suggested shared primitives: fixed area impact; finite pulse area; fixed projectile impact; static terrain interval; fixed paired portal interval; actor attunement marker; personal optional window; and grounded pose transfer. Encounter-specific action IDs select their typed parameters. Do not create a separate script/controller per boss when the pure event vocabulary suffices.

## Exact window conditions

| Encounter | Personal condition | Qualifying hit | Reset |
| --- | --- | --- | --- |
| Hunter | Window active | Original direct hit | Once per actor/window. |
| Warrior | Avoid every damaging mask event in the phrase before Open Guard, including any extra overlap | Original direct hit | Clear hit-mask failure flag at phrase start; consuming protection does not count as avoidance. |
| Thief | At least one successful fixed portal transfer in this phrase | Original direct hit | Portal success flag at phrase start; personal portal cooldown independently saved. |
| Alchemist | Effect was accepted before Distillation opened | Poison/Cleanse DOT, Acid, Dig, Sacrifice or Fortune periodic hit | Once per actor/window; base tick still applies. |
| Cardinal | Actor matches the event’s displayed Sun/Moon bonus at hit | Original direct hit | Attunement persists within cycle, claim resets per window. |
| Bard | Occupy each of the three `active_pad` rectangles at its exact floor-check tick | Original direct hit | Three-bit success record at phrase start; fourth visual step has no hidden rule. |
| Forager | Owned ground field existed before Fresh Seam opened | Acid or Dig grounded periodic hit | Once per actor/window; attached DOT is not a ground field. |
| Merchant | Caster occupies `dividend_pad` at hit tick | Original direct hit | Once per actor/window; +1 cycle scrip accompanies the +1 damage. |

The initial opportunity is at the last listed event of each phrase; no damage threshold can open it earlier. A base hit always retains its normal value when the optional condition fails. The last window begins at tick 6,780 and expires at 7,200. A pending projectile arriving at 7,200 belongs to the discarded outgoing cast state and does not hit on the new cycle.

All original direct hits include Auto Shot, Bash, Backstab, Poison’s initial hit, Sniper, Trap explosion, Beam, Dance finale, Boulder and Coin Toss. Cleanse’s immediate enemy hit is direct. Sacrifice/Fortune/Acid/Dig/attached stacks are periodic. Converted hostile projectiles, Mimic echoes and bonus packets are not original direct hits. A Trap’s optional position-based bonus uses its owner’s current caster position, never the trap’s cell, unless that encounter explicitly says field overlap.

## Required actor state and persistence

| State | Authority | Save/restore decision |
| --- | --- | --- |
| Score/ruleset/build fingerprint | Content catalog and recording metadata | Persist exact IDs/hash; reject mismatched replay without discarding the take. |
| Cycle tick / ordinary pause / restart-pending | Existing arena clock | Preserve current independent arena behavior and rewind/countdown rules. |
| Boss pose, masks, warnings, ribs and portal existence | Pure score lookup | Derive at restored tick; never save node positions or duplicate hazard clocks. |
| Hero position, HP, active cast, cooldowns and effects | Existing model, extended with typed records | Capture exact integers/IDs and restore before accepting input. |
| Attunement, portal cooldown, floor bits, duel-failure flags | Actor-local encounter ledger | Save only values not reconstructible from the fixed score; reset at specified boundary. |
| Window claims, Dice/Mimic counters, aura-heal bucket claims | Actor-local ability ledger | Save and reset exactly; do not infer from visual effects. |
| Dig ownership/overlap, acid owner, DOTs, shields | Their single model owner | Extend existing fields carefully; no duplicate entity-derived authority. |
| Cycle rocks/scrip/reagents, personal first-dig bitmap | Per-actor cycle resource ledger | Reset at seam; serialize for mid-cycle restore. Economic loot remains a separate owner. |
| Cumulative damage, recruitment income, deposited banks | Existing persistent guild/arena ledgers | Monotonic output only; never control boss phases or active build stats. |
| UI, sounds, camera interpolation, cue animation | Transient presentation | Rebuild from current state; no replay of already-earned damage/audio on load. |

For v2 combat rocks, a cell pays once **per Forager per cycle**, recorded in a personal 66×31 bitmap. The existing economic dig payout and shared damaged-ground ownership still occur only on the first global excavation. Digging a cell already broken by another hero may therefore grant a first personal combat rock without granting a second economic payout or duplicating its ground-damage field. This prevents an earlier ghost from exhausting a later ghost’s combat supply while preserving the shared substrate. The difference from the live starter is explicit and requires the v2 ruleset.

Exposure’s delayed damage is a scheduled operation at application+240 ticks. Its removable status persists through that tick and expires at +241, so phase-four Cleanse can remove it before phase-six damage. Do not delete it at tick+240 in generic expiry and accidentally cancel every delayed wound. The terminal pulse records for Acid, Cleanse DOT and Fortune similarly have explicit ownership; expiration of a visual/occupancy interval does not double or erase that pulse.

## Compatibility and activation

A recording’s fingerprint includes arena, tier, score content hash, simulation ruleset, tick rate, grid dimensions, start cell, stable actor ID, selected build/ability definitions and resource initialization. Existing records without a fingerprint migrate to the **legacy score/build revision**, not the new content. Preserve a legacy catalog entry for the old Labyrinth patrol and static bosses. Do not reinterpret an old `boss_jump` as a v2 transfer.

On encountering unavailable content, keep the last valid save and its recordings intact and display an incompatible-content state. Loading is not permission to overwrite. A player can explicitly create a new v2 recording while retaining the old take in its original revision. An update must not silently migrate intent timings, coordinates, automatic targeting rules, or damage-caused survival. Cosmetic changes that leave simulation data identical do not require a new gameplay fingerprint; changing mask, facing, ordering, ability effect or resource initialization does.

Load into an isolated candidate model, validate all references and bounds, then atomically replace the live model only when successful. Restore exactly one model authority, derive presentation afterward, and keep pending restart/countdown behavior separate. Browser and native adapters use the same validation and migration logic through SaveGames.

## Bounds and capacity sketch

These are initial implementation budgets to measure, not current benchmark results. Keep the existing maximum 40 ghosts per arena and 320 guild members globally; free heroes can also be physical, so do not pretend the worst case is only 41 actors. The complete world roster supplies the upper bound.

- Authored content is exactly 200 events and 40 pose keys across eight scores. A runtime loader may permit up to 64 events and 16 pose keys per v2 score; reject larger content at validation rather than truncating it.
- Each event has at most 8 rectangles; each footprint is bounded by 2,046 cells. Bake a 2,046-bit cell mask per distinct geometry when useful (256 bytes rounded up). Never spawn one Godot node per authoritative hazard cell.
- At most 320 active casts and following auras globally. Projectiles must have a maximum lifetime derived from arena width, speed, and channel/charge duration; no unbounded cross-world flight.
- Per caster: at most 4 traps, 2 Borders, 1 Bulwark, 1 Misdirection, 1 Symbiosis, 1 Vault; acid count is bounded by its 4-second cooldown/8-second lifetime (3 records including a terminal boundary record). Reject invalid content that breaks these derived limits.
- Cleanse has at most 2 concurrent stacks per caster/target under its 4-second cooldown and 5-second duration. With 320 participating actors and one boss, the conservative cap is 640 stacks. Poison has one per caster/target. Expired records leave no residual owner nodes.
- Dig’s shared cells are bounded by 2,046 per arena; personal first-dig bitmaps total at most 320 × 2,046 bits, about 80 KiB. Per-cell overlap counters need only a fixed tick remainder and owner/target identity under the current one-boss design.
- Optional window claims are at most 4 per actor per encounter cycle, plus bounded per-aura claims. A four-entry bitset or typed array is sufficient; never retain prior-cycle claim IDs forever.
- Pair-interaction processing is one pass over an event’s actual candidates, without recursive emission. Naive global hero-contact candidates can approach 51,040 pairs at 320 actors; reuse the project’s contact model and measure dense cases instead of adding another independent collision pass.

A reasonable initial target is under 2 ms p95 for the encounter-specific evaluation across eight arenas on the selected test host, measured separately from rendering and existing combat/contact. This is a proposed profiling budget. Correctness and bounded work come first; record actual native/browser results before calling it met.

## Boundary fixture matrix

| Fixture | Required coverage |
| --- | --- |
| Event windows | At every event: cue−1, cue, resolve−1, resolve, end−1, end; no cue damage, no repeated instant hit. |
| Pose transfers | Old footprint before tick, new at tick, overlap cell retained, former cell free, arriving crush, rear orientation. |
| Multi-event same tick | Final reprise overlap, independent IDs/tags, stable shield order, two real hits if both masks overlap. |
| Periodic edges | First pulse, final pulse, exact end, pause/resume, owner defeat, cycle wrap, reload between pulse and deletion. |
| Optional bonuses | No participation, partial success, success, reused hit, multiple buffs, changing caster position at impact. |
| Resource supply | Zero permanent wealth, empty cycle wallet, simultaneous spend, personal reagent expiry, first personal dig on globally broken cell. |
| Support combinations | Every exceptional pair/higher-order row in INTERACTIONS, including copying, reflection, shields, healing and revival. |
| Recording fidelity | Capture intent atomically, live/replay same acceptance, rejected costs unchanged, no held input as save state. |
| Cross-arena behavior | All eight unfocused clocks, one paused arena, another recording, camera/overview changes, selected-hero contact. |
| Long-run/save parity | 100 repeated cycles; save at each mechanic boundary; old schema migration; missing/future content; invalid candidate leaves old save untouched. |
| Human/readability | Actual keyboard and pointer, muted audio, native scale, 40 distinct starts, warning labels under dense FX. |

Do not generate thousands of shallow tests that only mirror JSON values. Use a small pure model to check independent properties, then authoritative Godot fixtures for behavior and a visible native/browser smoke test for timing/readability. The current documentation validator is useful evidence for geometry and coverage, but cannot establish engine integration, timing quantization, party balance or frame-time budgets.

## Authoring checklist for future revisions

Update the score, its encounter document, ability matrix if relevant, fingerprints, migration decision and the evidence report together. Re-run the static checker; repeat only the runtime gates affected by the change plus the shared replay/save invariants. Preserve historical guide citations so a future designer can see which properties were inherited and which were deliberately changed. Publish a new tier as a separate score; never scale a saved Normal take into a different geometry without an explicit new recording.
