# Local save state

## Decision and implementation plan

Arenic owns its save library in GDScript. Gameplay uses one `SaveGames` facade on local development, native builds, and browser builds. The shared document and model codec own state meaning; platform adapters own durable storage. A future remote adapter or synchronization layer must enter through the same validated document boundary. There is no remote service in this release.

The implementation follows five coordinated phases:

1. Inventory state and define the versioned document, model codec, bounds, and restore rules.
2. Implement native and IndexedDB adapters behind one contract, then integrate scheduled saves and the title-screen slot flow.
3. Prove model round trips, actual target persistence, failure recovery, and deterministic development seeds.
4. Update this architecture, model documentation, `AGENTS.md`, and the repository-local [five-phase-pass skill](../.agents/skills/five-phase-pass/SKILL.md).
5. Audit every state owner and run the relevant native/browser gates against the final implementation.

This document is the contract and validation plan. A task's final test results establish which checks were actually run; the presence of a planned case here is not evidence that it passed.

## Library boundary

| Layer | Responsibility |
| --- | --- |
| `SaveGames` autoload | Boot/hydration, eight-slot management, new/continue flow, active run identity, scheduled checkpoints, explicit flush, and user-visible failures. |
| `ArenicSaveDocument` | Validate document identity, versions, revision, metadata, byte limits, exact payload JSON, and checksum before interpreting model state. |
| `ArenicSaveCodec` | Capture and validate plain model data; reconstruct a complete run and world from catalog identities. |
| `ArenicSaveMigrations` | Pure sequential payload upgrades, followed by complete current-model validation. |
| `ArenicSaveBackend` | Awaitable `read_all`, `write_record`, and `delete_record` operations with the same result semantics on both targets. |
| Native adapter | Application-owned `user://saves` files, atomic replacement, recovery backup, process ownership, and revision checks. |
| Browser adapter | Application-owned IndexedDB `arenic-saves` database and transaction/revision checks. |

Scene scripts request operations from the facade. They never access `FileAccess`, `DirAccess`, JavaScript storage, or IndexedDB to persist a run. Native paths and browser APIs must not appear in domain state or gameplay rules. Development seeding uses the same facade and codec.

The models remain the live simulation authority. A successful checkpoint is the durable continuation point. A failed save leaves the current game and last committed checkpoint intact and reports the failure; it does not claim that the current state has been saved.

## Save document

The current implementation uses envelope format version **1**, authored content version **1**, and payload schema version **11**. Payload versions 1 through 10 remain supported through validated sequential migrations. The envelope identifies one slot and carries:

| Value | Contract |
| --- | --- |
| Run ID | 32 cryptographically random bytes encoded as 64 lowercase hexadecimal characters; generated once when Start creates a run. |
| Slot | Integer `0` through `7`; the UI displays slots 1 through 8. A slot and its run ID are distinct identities. |
| Revision | Monotonically increasing committed revision within one run. Updates compare the revision and run identity, so deleting and recreating a slot cannot let an old session overwrite its replacement. |
| Creation/update times | Unix seconds used for save-list metadata, never to advance combat or award offline progress. |
| Seed | Durable initial domain seed; continuation must not reroll it. |
| Payload JSON | Exact canonical JSON string emitted by the shared codec. The envelope preserves these bytes instead of re-encoding them in each adapter. |
| Checksum | SHA-256 of the payload JSON bytes. This detects accidental alteration; it is not an authentication signature. |

The model payload contains the run setup and world snapshot. Serialize only plain JSON-compatible data with explicit representations for grid vectors, rectangles, integer counters, and catalog identities. Preserve Godot integer precision across JSON/JavaScript boundaries; JavaScript's ordinary number representation cannot exactly hold every Godot 64-bit integer.

Limits are **eight slots**, **64 MiB per slot**, and **1,000,000 total recorded events per snapshot**. Model-specific bounds still apply, including 320 guild members and 40 folded ghosts per arena. Reject a checkpoint that exceeds a bound with an explicit error. Never silently truncate a guild, recording, combat ledger, or draft to make a save fit.

## State ownership and restoration

Every feature must classify its state using the following three categories. “Transient” is a restore decision, not a way to exempt gameplay rules from serialization.

| Category | State | Restore behavior |
| --- | --- | --- |
| Authoritative | Run identity, seed, pending character creation or active-game mode. | Reopen the correct flow for this run. A saved character-creation slot can continue without manufacturing a hero. |
| Authoritative | Prologue checkpoint `run.intro_step`, a whole number from 0 through 6. | Resume the current beat; new games begin at 0 and legacy or established development guilds use 6. |
| Authoritative | Chosen class; stable hero identities; roster order; next identity; level/experience; arena/cell/facing; remembered controlled hero, per-arena selection memory, and explicit close-view hero selection. | Resolve classes through the catalog; restore identities and validate references before publishing. Overview clears active selection while retaining remembered identities. |
| Authoritative | Lifetime damage, prospecting income, recruitment progress and choices governed by the run seed. | Preserve cumulative totals and claimed rewards; do not recalculate them from the rendered scene. |
| Authoritative | Combat enemy/ally ledgers, health/debuffs, in-flight casts with frozen `resolve_seconds`, release/timing state, cooldowns, and cast identity serials. | Restore active abilities without replaying already-applied effects or awarding damage twice. |
| Authoritative | Ordered enemy damage-over-time stacks, with original caster/ability/target and accepted remaining ticks, interval, tick debt, and damage. | Recreate each stack independently with exact integer timing; never replay its original cast or retime it from current ability resources. |
| Authoritative | Guild House wood/gold bank totals and bounded per-hero bags with resource, fill/unload progress, frozen durations and capacity. | Restore exact progress without gathering or depositing during hydration; preserve accepted rules for existing bags. |
| Authoritative | Encounter difficulty, integer arena cycle positions, folded performer membership, dig/acid cycle state and caster ownership, and gameplay counters. | Reconnect validated hero identities; rebuild authored scores and merged execution structures around the saved cycle state. |
| Authoritative | Per-arena `restart_pending` boolean, valid only at tick zero and independent of the ordinary pause flag. | Retain the already-reset model and begin a fresh three-second countdown, without a second reset or reverse playback. Retire an empty arena’s obsolete cosmetic hold during hydration; preserve its ordinary pause and all simulation state. |
| Authoritative | Each hero's committed recordings and any active recording draft/countdown, ownership, start cell, and captured events. | Preserve the take and its exact intent timestamps; continue the same recording state. |
| Authoritative | Pending gameplay decision, options, selected option, owning arena, and decision context. | Reopen the decision with the paused arena and the original action context. |
| Authoritative presentation | Focused arena and focused/overview zoom mode. | Restore the view; selection is active only within its arena. |
| Derived | Per-arena music phase and running state, retained in the compatibility payload as a projection of encounter tick/pause. | Derive phase from the restored cycle and track duration; create fresh voices. Old independent offsets cannot desynchronize the score. |
| Derived | Ghost status, visible selection brackets/roster highlight, generated hero names, merged/sorted timeline indexes, boss presentation, damage-bar layers, boss-condition readouts, HUD text, gathering phases/character bag meters, and resource lookups. | Recompute from the restored authoritative state and current validated catalogs. Do not store competing copies of the same fact. |
| Derived | Interaction-marker state and category display from the authored definition and owning interaction's progress; Keeper uses `intro_step` and the current reading delay. | Recompute after loading; no marker or quest-progress save fields are added. |
| Transient | Pressed/held input, queued device events, pointer focus, hover, scene/node handles, signal connections, tweens, animation frames, audio voices/fades, rendering caches, and the current movement/contact batch. | Recreate runtime objects; begin with neutral input and no duplicate one-shot effects. |
| Transient | Prologue reading delays, opening-door animation time and projected interaction-marker UI. | Reset the current beat’s delay and reproject markers on reload. Completed beats never replay; doors become durably unlocked only when step 6 is committed after the opening animation. |
| Transient | Overview tools overlay visibility and its selected tab. | Recreate closed on Continue. The tool views block gameplay input while open but do not pause clocks, ghosts, combat, or scheduled saves. |
| Transient | Bounded 20 Hz arena visual history, reverse playback/trails, restart phase elapsed time and countdown overlay. | Discard history on load; a saved pending restart supplies a new three-second display while the model remains at tick zero. |
| Transient | Activity event envelopes and subscriptions, delivery sequence/timestamps, the 100-entry feed history, pending damage buckets, expanded history, and its filter/scroll state. | Start a fresh shell-local feed after loading. Publish current unclaimed recruitment and active recording status from restored models; never replay historical damage or award effects from messages. |

The codec records presentation continuation explicitly instead of inferring it from scene objects. The combat tick clock also determines music phase; decoders remain presentation only. The pending decision snapshot restores the UI that owns a paused operation; no invisible modal may hold a saved arena forever.

Overview has no actively selected hero: all `hero.selected` flags are false,
while `selected_identity` and per-arena memories retain valid guild identities.
Plain zoom does not select a hero; Tab or a roster/actor click explicitly does.
Existing schema-4 overview saves may contain a true selected flag and remain
valid. Hydration normalizes those flags after restoring the view. A close-view
save restores selected flags only for members in the viewed arena after the shell’s
initial overview construction. The next checkpoint writes the normalized flags.
The original overview normalization added no fields; schema 9 extends it to
remote heroes in a close view.

The overview tools are separate from the durable `ArenicModal` decision flow.
Autosave while they are open captures the continuing game with no overlay state.
Opening a recording decision closes tools before presenting the saved decision
and its arena pause. Recruitment and loot use separate transient card views;
these block input without pausing any arena.

[Arena rewind](arena-rewind.md) adds `world.arenas[arena_id].restart_pending` in
schema 7. Its true value requires tick zero and cannot share that arena with a
recording draft or recording countdown. An ordinary modal can coexist; finishing
the restart clears only its own flag and retains any modal pause. Hydration
recreates a fresh 180-physics-step countdown against the accepted, already-reset
model. It never resets twice, executes historical events, or restores visual
samples as game state. The five-second maximum rewind duration and the rate
chosen for each captured span are transient presentation policy; schema 7 and
the saved intent timestamps are unchanged. Lifetime damage and wood/gold banks remain accumulated;
the ordinary Guild House cycle reset still clears affected carried bags before
the pending checkpoint is captured.

The recording-death choice advances the payload to schema 8. Existing health,
recording-session and modal records remain the sole authorities; there is no
second death boolean or saved presentation timer. The `commit_death` and
`return_home` actions must appear together in order, belong to the remembered
selected recorder, reference its paused arena, and have a zero-health unfurled
owner. The fatal simulation tick completes before the choice freezes the next
tick, keeping reconstructed timeline cursors and periodic effects consistent.
The full-screen red appearance is derived from those actions. Version 7 → 8
retains every existing value and only changes the version; it never manufactures
a death screen for old saves. Newer snapshots remain incompatible with old code,
which cannot safely interpret these two actions.

Restoration is transactional at the model boundary: decode and validate all fields, catalog references, ownership relationships, numeric bounds, and event order into a candidate, then replace the live run. Invalid input must not partially mutate `RunSetup`, the combat ledger, or the current scene. Rebuild derived presentation only after the complete model is accepted.

Authored data also affects compatibility. Changing class/ability IDs, arena identities, simulation tick rate, event meaning, or resource defaults can change how a save plays. Review those changes as persistence changes even when the serialized field list stays the same.

The Backstab cooldown correction from 1.5 to 0.5 seconds remains compatible with version 1. A cooldown already in progress retains its saved remaining seconds; subsequent casts use 0.5 seconds. The ability identity, timer representation, and 0.2-second windup are unchanged, so no migration or save reset is needed.

Auto Shot now freezes its accepted arrival as `release_seconds + Euclidean distance(origin, target_cell) / projectile_speed_tiles_per_second`. The current authored speed is 16 tiles per second, with a 0.26-second release delay. `Cast.resolve_seconds` is authoritative and survives JSON, process restart, and stage recreation; rendering receives that same value through the existing `cast_seconds` snapshot key. A later catalog change does not retime an active saved shot. Version 3 shots retain their previous fixed 0.75-second total, while new casts use the current speed. Cooldown and stable cast/target identities remain unchanged.

Boss airborne status is derived from the saved encounter clock and authored score, never serialized as a second state flag. Hit eligibility is evaluated from that model at arrival; the lookup is transient and reattached during shell initialization before simulation resumes. Loading must not replay already-applied hits, launch a second projectile, or infer eligibility from a rendered height.

Sacrifice presentation follows the cast's existing saved `target_id` and the
boss's derived center/lift; it does not change hit eligibility or serialize a
second target transform. Fallen-ghost presentation is derived from existing
fold membership and the combat ally health ledger. A fresh defeat signal plays
the burst once; hydration or view replacement starts the lingering smoke loop
directly. Arena revival removes it. These are transient presentation changes,
so those presentation changes require no additional save fields or migration.

Leaving a defeated ghost now uses existing recovery operations: Take control
respawns it through the free-hero Guild House path; Record new revives it before
the normal recording restart in its current arena. Both write the same existing
health, membership and location fields. Old dead checkpoints remain valid; the
next chosen action uses the corrected recovery behavior, with no save rewrite
or migration on load.

Cleanse's stacking damage over time is durable in schema 5. Each entry in
`run.combat.enemy_dots` stores exactly `caster_id`, `ability_id`, `arena`,
`enemy_id`, `remaining_ticks`, `interval_ticks`, `tick_debt`, and `damage`.
The array preserves acceptance order and supports at most **6,400 stacks**.
The caster must be an existing hero who owns the authored `cleanse` ability;
the target must exist in the named arena's enemy ledger. Unlike legacy ground
hazards, these stacks never accept an unknown owner.

Timers are whole 60 Hz arena ticks: remaining lifetime **1–7,200**, interval
**3–600**, and accumulated tick debt **0 through interval minus one**. Damage is
an integer **1–100**. New starter stacks accept 300 remaining ticks, a 60-tick
interval, zero debt, and one damage; later Inspector edits apply to new casts
only. Each unpaused encounter tick advances the matching arena's stacks. A due
tick also applies at the expiry endpoint, then that stack is removed. Stacks
do not refresh one another, and their saved target identity follows the enemy
without consulting rendered or airborne ground geometry. Pausing the owning
arena holds its stacks; restarting that arena clears only its stacks. Save/load
preserves completed direct damage and resumes future ticks without repeating
Cleanse's immediate hit, healing, or debuff removal. Expired or oversized saved
collections fail validation rather than being silently trimmed.

The [activity event API](activity-events.md) and Global Chat view add observations
and transient presentation only. Damage, available recruitment, recording, and
defeat still come from their existing authoritative owners. Current recruitment
attention is derived again after hydration, while the old event history is
discarded. The activity API itself remains transient. Attribution of future lingering hazard damage is durable in schema 3: each acid pool stores its original `caster_id`, and each dug tile stores `[cell_index, overlap_tick_debt, caster_id]`. IDs are stable `hero:<identity>` strings resolved through the saved roster and matching `acid_flask`/`dig` ability. The first successful dig owns a tile until its cycle resets; each overlapping acid pool keeps its own caster. Owners may move to another arena without transferring ownership. An empty string means unknown, including hazards from older saves; never infer their owner from the controlled hero. Existing in-flight casts already save owner and ability IDs. Loading recreates future damage observations from these models without replaying old feed entries.

## Title screen and eight slots

The title screen waits for storage hydration before presenting save-dependent actions. Continue appears only when at least one valid, supported save can be resumed. It opens a slot picker rather than assuming the newest save is the desired game.

Start creates a fresh run in an available slot and persists its pending character-creation state before entering class selection. A new run receives its own ID and seed. Eight occupied slots require the user to manage a slot; Start never overwrites the oldest game automatically.

The picker exposes all eight slots, the supported save summaries, empty capacity, and invalid or unsupported records that need management. Loading selects a particular slot through the facade. Deleting a record requires a concrete confirmation in the game's interface and targets that slot/run identity. A rejected or future-version record is not resumable, but it remains owned data until deliberately discarded.

## New-game prologue

`RunSetup.intro_step` identifies the next or current beat: **0** is the Jung quote, **1** is the Guild House beckoning, **2–5** are the four recording lessons, and **6** is complete with arena routes unlocked. Start resets the checkpoint to 0; choosing a class preserves it. A locked game contains exactly one founder in the Guild House with no recording or replay; an initialized world stays focused on the Guild House. Pending class selection accepts the new-game step 0 or migrated step 6. The founder is centered at Guild House `(33, 15)` when the new-game quote starts; the established-guild spawn constant and migrated hero positions remain unchanged.

Each completed beat requests a checkpoint through `SaveGames`. Reloading a saved beat resumes that beat with fresh transient reading time, rather than repeating the already completed quote or earlier dialogue. The final door opening is transient animation; only its completion advances the durable checkpoint to 6. Version 1 saves and established development fixtures start at 6 so existing guilds never receive new travel restrictions.

## Scheduled commits and lifecycle

During an active run, checkpoints are scheduled at a **five-second** interval. Coalesce dirty changes and allow one commit in flight; edits made during that commit remain pending for the next checkpoint. Continuous simulation must not postpone saving forever through a trailing-only debounce.

Capture a coherent model snapshot at a simulation boundary. Validate and serialize it once, then pass the immutable document to the selected adapter. A revision is committed only after the adapter confirms durable success. Failures preserve the dirty state and surface a save error without destroying the last good record.

Explicit scene/lifecycle flushes handle intentional transitions and supported pause/exit notifications. The scheduled loop provides the regular durability guarantee: browsers can terminate without allowing an asynchronous shutdown write to finish, so closing a tab cannot promise to save changes after the last completed checkpoint.

Save & Title in the H controls menu pauses simulation and input before its final asynchronous commit, then restores the previous pause state. Failure keeps the current game active and shows the storage error. Slot removal retains the reviewed revision and run identity; refreshing a slot cancels an outdated confirmation.

On native, replacement must leave a recoverable committed record if a write fails or the process stops. Storage operations acquire a loopback `TCPServer` lock whose port is derived from the absolute save directory, then check the revision before replacement. The operating system releases this resource after a crash, avoiding stale PID lock files. An unavailable lock reports an error and leaves the record intact. On browser, compare the expected revision and commit the replacement in the same IndexedDB transaction. Adapter success has the same meaning to the facade on both targets.

Deleting a slot or wiping obsolete versions first coordinates with scheduled and in-flight writes. Invalidate pending operations for the affected run so a late completion or old timer cannot recreate a deleted slot. A revision conflict is an error to resolve, not permission to overwrite another session's data.

## Versions, corruption, and intentional removal

Keep storage layout versions, envelope versions, and model payload versions conceptually separate. A new IndexedDB store or file layout does not by itself migrate the meaning of gameplay fields.

Supported migrations are pure sequential transformations with bounded shape checks on the fields each step changes and complete current-model validation before hydration. Test these transformations independently of either backend, then prove the actual old-record hydration path on both targets. Version 1 → 2 adds `run.intro_step = 6`, including older pending class-selection slots. Version 2 → 3 adds an empty unknown caster to each existing acid pool and dug tile. No existing damage, timer, position, class, or prologue progress is changed. All other fields, including unexpected ones, are retained for validation rather than discarded; a malformed legacy record fails closed. Version 3 → 4 adds each active cast’s frozen `resolve_seconds`: the immutable released-v3 timing table keyed by ability ID, while still validating owner and ability against the current catalog. The table records fixed cast time for thrown attacks and duration for other effects; later Inspector/catalog timing edits cannot rewrite this history. An already-active older Auto Shot therefore still arrives at 0.75 seconds from acceptance, preserving its saved elapsed/release state. Version 4 → 5 adds an empty `enemy_dots` array to existing combat state, including when old direct Cleanse damage exists; no prior cast is replayed and no retrospective stack is invented. A v4 record that already contains this future field is rejected. Pending class-selection combat remains empty. Version 5 → 6 adds gathering and safely separates legacy overlapping living positions as detailed below. Version 6 → 7 adds `restart_pending = false` to each existing world arena, preserving historical ticks and pauses without inventing a countdown; an old payload that already contains the new field is rejected. Pending class-selection worlds remain empty. Version 7 → 8 adds the loss-decision semantics without new fields. Version 8 → 9 retains every field for validation, then hydration derives music from the saved cycle and clears remote selection without changing hero identities, arena memories, ticks or recordings. The complete chain is validated against schema 9 so every supported old version remains supported after newer fields are introduced. Migration never mutates or replaces its stored input. The next successful checkpoint writes version 9 with the same run identity and normal revision semantics.

The slot decoder returns `ready`, `invalid`, or `incompatible`, with an error message identifying the failure. Invalid envelope/identity, checksum corruption, and invalid model data are `invalid`; unsupported format/content versions or unavailable payload migrations are `incompatible`. Future-version records must survive running an older game; never downgrade them, use their slot as empty space, or silently replace them with defaults.

Removing obsolete versions is explicit and scoped to the application's saves. Use the slot picker's Remove confirmation for each obsolete record; supported and future-version records remain unless individually selected for removal. Reset all local runs by removing all eight slots through this same interface. The facade coordinates removal with active writes and never deletes unrelated IndexedDB databases or other `user://` application data.

## Gathering and hero separation

Schema 6 adds `run.gathering = {wood_total, gold_total, bags}`. Both totals are nonnegative signed 64-bit decimal strings. The array has at most 320 entries, each keyed by a unique existing `hero_id` and containing exactly `kind` (`wood` or `gold`), `fill_ticks`, `fill_duration_ticks`, `unload_ticks`, `unload_duration_ticks`, and `capacity_units`. Durations are whole ticks: fill 1–7,200, unload 1–600, capacity 1–1,000. Fill is positive and bounded by its frozen duration; unload is below its duration and may be positive only for a full bag. A defeated hero cannot retain a bag. Pending class-selection saves have empty bags and zero banks.

The model advances only with the unpaused Guild House clock after all movement and contact deaths. Depositing is a single authoritative transfer; restore recreates character bag meters without another transfer or historical deposit message. World gathering sites have no resource-name, dropoff or bank text, but both banks remain in the ledger and actual future deposits still publish activity. Cycle restart clears bags of current Guild House participants; death clears the victim's bag. Other-arena bags and accumulated banks survive. [Gathering rules](gathering.md) describe the data and derived phases.

The outdoor Guild House restyle retained schema 6; the later arena-restart feature advances the current schema to 7. Current authored mine centers are `(7, 24)` and `(56, 7)`; wood and gold dropoffs now sit beside the tavern at `(23, 21)` and `(42, 21)`. This dropoff move leaves sources, radius, timing, capacity and the two-minute clock unchanged. Hydration uses current geometry while preserving existing bank totals, frozen bag rules/progress, hero positions, combat identity, introduction state and recorded intent. It never rewrites a route or awards work during load. Previous dropoff positions no longer unload; normal simulation resets unloading outside the current matching radius. Existing recordings may need rerecording to reach the new dropoffs. The unchanged Keeper cell and target footprint avoid a hero-relocation rule. Scenery and seated animation are derived from current assets and are not serialized.

Version 5 → 6 supplies empty gathering state without retroactive awards. Because older versions allowed living heroes to overlap, the migration visits stable identities in order and moves later overlapping heroes to the nearest free tile in that arena, avoiding authored blockers. Before relocation, an existing ally cell must be a valid grid position matching the original hero cell; migration cannot repair malformed or contradictory ledgers. It updates the matching ally cell but preserves cached recording starts/events, health, identity and every other field. Dead ghost smoke does not occupy a tile. The migration never executes contact deaths. Current-schema validation rejects overlapping living positions rather than silently moving them. New recruits and respawns use the same deterministic empty-cell search; normal movement, simultaneous crossings and replay restarts use the contact rule instead.

## Development seeds

Development fixtures use the same runtime constructors, catalog validation, codec, and save facade as normal new games. `ArenicSaveSeed.apply(run, seed)` reads [founders_v1.json](../arenic-game/data/dev/founders_v1.json), creates a seeded three-hero guild through the normal class/recruitment APIs, and grants 120 prospecting income. The founder starts at Guild House `(30, 15)` and recruits occupy adjacent cells. The fixture represents an established guild and sets `intro_step = 6`. It begins with empty gathering bags, zero wood/gold banks, and without pools, dug tiles, or enemy damage-over-time stacks; effects created later enter the current schema through the same ordinary cast and landing APIs as player attacks. The seed fixes class choices; each newly created save still receives a fresh cryptographic run ID.

From the repository root, launch the native editor/debug executable with a seed between `1` and `2147483647`:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path arenic-game -- --dev-seed=42
```

This selects the isolated `user://dev-saves` directory. Native release exports ignore the argument. A developer on another host can use its installed Godot debug executable with the same arguments.

For the local web build, append `?dev_seed=42` to the game's URL, for example `http://127.0.0.1:4174/arenic-sept-godot/play/?dev_seed=42`. The parameter is accepted only on `localhost`, `127.0.0.1`, or `[::1]` and selects the isolated IndexedDB database `arenic-saves-dev`. Public release hosts ignore it.

Seeding creates a fixture only when that development namespace is empty. Reloading never overwrites an existing seeded run, even with a different seed; use Continue to resume it. To generate a different fixture, deliberately remove its development saves first, then relaunch with the new seed. Production saves remain in their separate namespace. The fixture reaches durable storage through the same codec and adapter as a player-created run; it does not depend on private browser probe controls.

## Validation plan

| Boundary | Required evidence |
| --- | --- |
| Shared codec | Complete authoritative state round trip, including a pending new game, in-flight cast, active draft, committed ghost, damaged/support actors, dig/acid state, partial/full/unloading gathering bags and bank totals, and staggered enemy DOT stacks with exact caster identity and independent expiry on future ticks; integer precision and catalog-reference failures. |
| Document/version handling | Stable payload checksum, malformed/oversize input, collection bounds, unknown/future versions, and the supported version 1 → 2 → 3 → 4 → 5 → 6 → 7 → 8 migrations, including legacy overlapping heroes, missing/unknown/wrong-class effect casters and malformed legacy state. |
| Arena restart continuation | Tick-zero pending freeze, independent modal pause, exclusion of a recording in the same arena, retained damage/resource banks, fresh three-second continuation without duplicate reset, and native-process/IndexedDB restoration. |
| Native adapter | Actual save → new process → load, atomic replacement/recovery, stale revision, write failure, and slot deletion/reset with scheduled work. |
| Browser adapter | Real IndexedDB save → page reload → Continue → same state, browser write failure/conflict, occupied-slot limit, corrupt/future record management, and scoped deletion. |
| Title lifecycle | Fresh profile hides Continue, Start commits one unique run, class selection persists, slot picker resumes the chosen run, and full capacity never silently overwrites a save. |
| Autosave | Periodic progress during continuous simulation, one commit in flight, changes during a commit retained, failure remains visible/dirty, and deleted runs never reappear. |
| Development | Reproducible seeded state through the public persistence boundary on both targets. |
| Production artifact | Existing native/browser gate still passes; editor MCP and private QA hooks remain absent from the clean web artifact. |

Use `scripts/ci/test-godot.py` for isolated native checks and the repository's disposable web export/Playwright workflow described in [GitHub Pages](github-pages.md). Register new native checks in the runner's explicit suites. A browser codec test with a mocked storage object does not establish IndexedDB durability, and a running native process reading its own cache does not establish restart persistence.

## Verification — September 12, 2026

The complete local Godot 4.7.2 gate passed on macOS: **39 results**, comprising import, Godot Doctor, 32 headless checks, and five rendered checks. Persistence coverage includes 53 codec assertions, 56 native adapter assertions, 49 facade assertions, and a separate two-process save/restore check. The restored run preserves its identity and full payload before the first simulation tick, then resumes its pending decision and simulation. A visible native title launch also completed without logged errors.

The complete Chromium gate passed **43 of 43 tests**, with no failures, flaky results, or skipped tests, against the assembled site and separate clean/probe exports. This includes seven actual IndexedDB adapter cases and six save-flow cases covering reload/Continue, a live recording, eight-slot capacity and deletion, corrupt/future versions, development seed isolation, and transaction failures. Existing gameplay, viewport, gallery, music, and sound checks also passed. The final eight-slot picker and a seeded local browser run were visually inspected.

These are local verification results. Publication requires the separate PR, main-branch, and public-site checks documented in the release workflow.

## Snapmatch reference

This design borrows schema-first boundaries, validated hydration, pure migration transforms, post-commit publication, and teardown ordering from [Snapmatch's state implementation](https://github.com/matthewharwood/snapmatch/tree/ea33cd75c83a94e6bf2888b7ac5f9b9405fc6f9a/apps/web/app/state). Its [five-phase pass](https://github.com/matthewharwood/snapmatch/blob/ea33cd75c83a94e6bf2888b7ac5f9b9405fc6f9a/.agents/skills/five-phase-pass/SKILL.md) supplies the cross-surface enforcement pattern. Snapmatch's multiplayer Firestore authority and generated-app template are specific to that repository; Arenic's current authority remains local and its paired surfaces are native and browser builds.

## Loop and selection compatibility (schema 9)

Music phase is now derived from each saved arena’s tick divided by cycle length, multiplied by its current track duration. Capture writes this canonical projection into the retained `world.music` fields; restore derives it again from the encounter, so legacy independent offsets cannot override the loop. No migration changes a gameplay tick or recording. Decoder voices, playback rates and correction bookkeeping remain transient.

Selection flags outside the viewed arena normalize to false, while `selected_identity` remains a valid remembered identity and per-arena memories survive. A viewed empty arena has no active target; a first recruit arriving there selects locally. Native process-restart and real IndexedDB tests cover this normalization, first arrival, countdown silence, recording reset, resumed music, and remembered local selections.


## Cardinal encounter compatibility (schema 10)

`run.combat.encounter` stores a ruleset ID, accepted content/build fingerprint,
and a bounded map from source arena to actor identity. Each personal record has
`attunement` (`""`, `sun`, `moon`), up to four `exposures` (`event_id`, integer
`due_tick`, integer `damage`), and up to four claimed window IDs. Source event
identities, deadlines, damage, unique claims and collection bounds are validated
against trusted authored content before hydration. Restore reconstructs integers
explicitly after JSON decoding. Pose, cues, patterns and countdown labels derive
from the saved arena clock; they never replay hits on load.

Schema 9 → 10 assigns `legacy-1` with empty actor effects, retaining all existing
health, clocks, recordings and static Sanctum. New games use `cardinal-1` with
four maximum HP and Cardinal’s Normal score. The run-wide fingerprint pins every
cached staff and draft to the same score and starter mechanical definitions.
Capture retains the originally accepted fingerprint. Missing/changed content
rejects the candidate without altering the existing run or durable slot. A new
revision requires new explicit activation, not mutation of an old take. Native
and browser adapters continue through the same SaveGames/codec boundary.

Full mechanic, reset and presentation ownership is in
[Cardinal runtime](cardinal-runtime.md). The native two-process fixture and real
IndexedDB test include personal attunement, consumed bonuses and the exact
Exposure damage boundary. Existing development seeds receive the new ruleset
through ordinary new-game class selection; seeded saves already on disk retain
their original revision.

### Empty-arena restart compatibility

Rewind eligibility changes presentation holds, not recorded event ordering,
authored scores, tick length or the payload shape. Schema 10 remains current.
An empty arena's saved `restart_pending` is accepted and cleared when rebuilding
its transient restart controller, without repeating its reset. Populated arena
holds still restore independently. The unscored Guild House wraps its resource
and music cycle without a hold unless workers are folded in; existing recordings
and ordinary carried-bag cleanup remain unchanged. Native process and IndexedDB
reload checks cover a remote hold alongside free movement at home.

### Concurrent channel presentation

Schema 10 already saves active casts per hero, including accepted target,
geometry and elapsed time. Sacrifice beams and caster auras are derived from
those records; their nodes, clipped frames and pool slots remain transient.
Hydration reconstructs every still-active caster, preserving other owners while
restoring each snapshot. No new field, migration, input replay or damage event is
introduced. Held input still restores neutral, and existing live/recorded
channel-cancellation rules remain authoritative. Native process and IndexedDB
checks cover simultaneous channels and independent cancellation after reload.


## Recording cancellation compatibility

Death, an accepted arena exit, or navigation to another arena discards the active
recording/countdown. Authoritative session ownership/events clear; the hero's
existing cached recordings, other folded performers, and arena clock remain.
Death restores the free hero at the Guild House. Cancellation releases its own
pause and closes its recording decision, without starting a rewind or seeking.
HUD feedback and held input are transient; no new save fields are needed.

Schema 10 remains current because the existing representation already expresses
this continuation. The codec still validates older saved death decisions, then
the real shell normalizes a fallen or abandoned draft before hydration returns.
The next capture saves the cleared session and running source clock. Living,
in-arena drafts and committed intent retain their existing interpretation and
content fingerprint. This is an intentional update to recording control flow
for both legacy and Cardinal runs, not a reinterpretation of a committed staff.

## Reward cards and equipment (schema 11)

`run.loot` is the versioned authority for completed battle damage, participating
hero ticks, fully deployed hero ticks, completed reward counts, eight per-arena
cycle baselines/serials/work counters, six earned/claimed quality buckets per
arena, and item counts keyed by the fixed 100-item catalog. [Loot](loot.md) owns
its exact gates, numeric bounds and weights. All cumulative counts use decimal
strings across JSON and IndexedDB. Each pending draw is determined by its frozen
arena, quality band, claimed ordinal, loot revision and run seed. A card click
advances one claim and one inventory count together before showing the result.

Version 10 → 11 supplies an empty loot ledger with each damage baseline and
cycle serial copied from the accepted current arena snapshot. It grants no
retroactive loot and cannot replay a completion during hydration. Partial cycles
after that checkpoint earn only subsequent damage/work. The complete candidate
is validated before replacing any live state; future loot revisions and unknown
item IDs fail closed. The arena fingerprint and committed hero intent are
unchanged.

Hero card choices retain the existing deterministic roll index. The new authored
recruitment curve preserves costs 40/64/102/164 then adds 48 per subsequent roll,
with 319 earned recruits plus the founder. This intentionally lowers later
thresholds: prior banked/claimed rolls survive and established runs may gain
additional banked recruitment. Saved old recruitment decisions release their
pause and reopen through the new card view without claiming anything.

Card visibility, stagger/flip time, pending pointer input and displayed result
are transient and restore closed. Deferred heroes remain available through N;
unclaimed loot remains in the top-right Loot action. Claimed equipment remains
in the overview Loot collection even if the game closes during its reveal.
The collection has no equip slots or combat-stat effects in this first pass.


### Ownership across all implemented abilities

Presentation restores active casts per saved hero identity and accepted cast ID.
Projectiles and Fortune auras use reserved slots, as Sacrifice does; temporary
feedback has separate per-caster capacity. The codec's existing `casts` records
remain the sole authority. Model completion retires only the matching caster's
visual; no selected-hero timer can clear another aura. Immediate Cleanse/Dig
animation is transient, while saved DOTs, acid pools and dug ground reconstruct
through their existing arena owners. This fix requires no payload or semantic
migration and does not reinterpret recordings. Native restart coverage saves
and restores two simultaneous casts of Fortune, Auto Shot and Acid Flask; the
browser records a Bard beside multiple ghost classes and restores both Merchants.
See [the ability ownership audit](ability-ownership.md).
