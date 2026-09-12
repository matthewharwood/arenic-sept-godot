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

The first release uses envelope format version **1**, authored content version **1**, and payload schema version **1**. The envelope identifies one slot and carries:

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
| Authoritative | Chosen class; stable hero identities; roster order; next identity; level/experience; arena/cell/facing; controlled hero and per-arena selection memory. | Resolve classes through the catalog; restore identities and validate references before publishing. |
| Authoritative | Lifetime damage, prospecting income, recruitment progress and choices governed by the run seed. | Preserve cumulative totals and claimed rewards; do not recalculate them from the rendered scene. |
| Authoritative | Combat enemy/ally ledgers, health/debuffs, in-flight casts, release/timing state, cooldowns, and cast identity serials. | Restore active abilities without replaying already-applied effects or awarding damage twice. |
| Authoritative | Encounter difficulty, integer arena cycle positions, folded performer membership, dig/acid cycle state, and gameplay counters. | Reconnect validated hero identities; rebuild authored scores and merged execution structures around the saved cycle state. |
| Authoritative | Each hero's committed recordings and any active recording draft/countdown, ownership, start cell, and captured events. | Preserve the take and its exact intent timestamps; continue the same recording state. |
| Authoritative | Pending gameplay decision, options, selected option, owning arena, and decision context. | Reopen the decision with the paused arena and the original action context. |
| Authoritative presentation | Focused arena, focused/overview zoom mode, and per-arena music clock position/running state. | Restore the view and seek newly created voices; music time never advances combat. |
| Derived | Ghost status, selected flags, generated hero names, merged/sorted timeline indexes, boss presentation, damage phase labels, HUD text, and resource lookups. | Recompute from the restored authoritative state and current validated catalogs. Do not store competing copies of the same fact. |
| Transient | Pressed/held input, queued device events, pointer focus, hover, scene/node handles, signal connections, tweens, animation frames, audio voices/fades, and rendering caches. | Recreate runtime objects; begin with neutral input and no duplicate one-shot effects. |

The codec records presentation continuation explicitly instead of inferring it from scene objects. The combat tick clock remains authoritative for gameplay while continuous music time is retained independently. The pending decision snapshot restores the UI that owns a paused operation; no invisible modal may hold a saved arena forever.

Restoration is transactional at the model boundary: decode and validate all fields, catalog references, ownership relationships, numeric bounds, and event order into a candidate, then replace the live run. Invalid input must not partially mutate `RunSetup`, the combat ledger, or the current scene. Rebuild derived presentation only after the complete model is accepted.

Authored data also affects compatibility. Changing class/ability IDs, arena identities, simulation tick rate, event meaning, or resource defaults can change how a save plays. Review those changes as persistence changes even when the serialized field list stays the same.

## Title screen and eight slots

The title screen waits for storage hydration before presenting save-dependent actions. Continue appears only when at least one valid, supported save can be resumed. It opens a slot picker rather than assuming the newest save is the desired game.

Start creates a fresh run in an available slot and persists its pending character-creation state before entering class selection. A new run receives its own ID and seed. Eight occupied slots require the user to manage a slot; Start never overwrites the oldest game automatically.

The picker exposes all eight slots, the supported save summaries, empty capacity, and invalid or unsupported records that need management. Loading selects a particular slot through the facade. Deleting a record requires a concrete confirmation in the game's interface and targets that slot/run identity. A rejected or future-version record is not resumable, but it remains owned data until deliberately discarded.

## Scheduled commits and lifecycle

During an active run, checkpoints are scheduled at a **five-second** interval. Coalesce dirty changes and allow one commit in flight; edits made during that commit remain pending for the next checkpoint. Continuous simulation must not postpone saving forever through a trailing-only debounce.

Capture a coherent model snapshot at a simulation boundary. Validate and serialize it once, then pass the immutable document to the selected adapter. A revision is committed only after the adapter confirms durable success. Failures preserve the dirty state and surface a save error without destroying the last good record.

Explicit scene/lifecycle flushes handle intentional transitions and supported pause/exit notifications. The scheduled loop provides the regular durability guarantee: browsers can terminate without allowing an asynchronous shutdown write to finish, so closing a tab cannot promise to save changes after the last completed checkpoint.

Save and Title pauses simulation and input before its final asynchronous commit, then restores the previous pause state. Failure keeps the current game active and shows the storage error. Slot removal retains the reviewed revision and run identity; refreshing a slot cancels an outdated confirmation.

On native, replacement must leave a recoverable committed record if a write fails or the process stops. Storage operations acquire a loopback `TCPServer` lock whose port is derived from the absolute save directory, then check the revision before replacement. The operating system releases this resource after a crash, avoiding stale PID lock files. An unavailable lock reports an error and leaves the record intact. On browser, compare the expected revision and commit the replacement in the same IndexedDB transaction. Adapter success has the same meaning to the facade on both targets.

Deleting a slot or wiping obsolete versions first coordinates with scheduled and in-flight writes. Invalidate pending operations for the affected run so a late completion or old timer cannot recreate a deleted slot. A revision conflict is an error to resolve, not permission to overwrite another session's data.

## Versions, corruption, and intentional removal

Keep storage layout versions, envelope versions, and model payload versions conceptually separate. A new IndexedDB store or file layout does not by itself migrate the meaning of gameplay fields.

Supported migrations are pure sequential transformations: validate the old version, transform one version step, validate the next version, and finally validate the complete current candidate. Test these transformations independently of either backend, then prove the actual old-record hydration path on both targets. This initial release has no earlier save format to migrate.

The slot decoder returns `ready`, `invalid`, or `incompatible`, with an error message identifying the failure. Invalid envelope/identity, checksum corruption, and invalid model data are `invalid`; unsupported format/content versions or unavailable payload migrations are `incompatible`. Future-version records must survive running an older game; never downgrade them, use their slot as empty space, or silently replace them with defaults.

Removing obsolete versions is explicit and scoped to the application's saves. Use the slot picker's Remove confirmation for each obsolete record; supported and future-version records remain unless individually selected for removal. Reset all local runs by removing all eight slots through this same interface. The facade coordinates removal with active writes and never deletes unrelated IndexedDB databases or other `user://` application data.

## Development seeds

Development fixtures use the same runtime constructors, catalog validation, codec, and save facade as normal new games. `ArenicSaveSeed.apply(run, seed)` reads [founders_v1.json](../arenic-game/data/dev/founders_v1.json), creates a seeded three-hero guild through the normal class/recruitment APIs, and grants 120 prospecting income. The founder starts at Guild House `(30, 15)` and recruits occupy adjacent cells. The seed fixes class choices; each newly created save still receives a fresh cryptographic run ID.

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
| Shared codec | Complete authoritative state round trip, including a pending new game, in-flight cast, active draft, committed ghost, damaged/support actors, and dig/acid state; integer precision and catalog-reference failures. |
| Document/version handling | Stable payload checksum, malformed/oversize input, collection bounds, unknown/future versions, and each future migration transform. |
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
