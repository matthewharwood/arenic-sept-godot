---
name: five-phase-pass
description: Keep Arenic gameplay state, versioned save contracts, native and browser persistence, development seeds, tests, and repository guidance aligned when a feature changes state or its storage. Use for save/load work and gameplay changes that affect saved runs.
---

# Five-phase pass

This is Arenic's cross-surface state workflow. Read [the save architecture](../../../docs/save-state.md) for the shared contract and state ownership. Its source of inspiration is Snapmatch's cross-surface pass; Arenic has no generated application template or Firebase requirement.

## 1. Classify the state change

Before editing, identify which affected values are authoritative, derived, or transient. Authoritative values must round-trip through the shared codec; derived values must have one documented source; transient values must have an intentional restore behavior. A Node, Resource instance, Callable, rendering object, audio voice, or held input is never a durable representation.

Changes to authored class/ability/arena IDs, simulation tick meaning, or resource defaults can change the interpretation of an existing save even without editing the codec. Include that compatibility impact. For a task with no state impact, record that conclusion briefly and use its normal checks; do not run persistence gates for unrelated art or prose.

## 2. Update the shared contract and runtime

Keep `SaveGames` as the game-facing boundary and `ArenicSaveCodec` as the explicit model codec. Gameplay and title UI must not choose a storage backend or write save files/IndexedDB directly. Preserve the same operation and error semantics on native and browser targets.

Update both capture and restoration when adding authoritative fields. Validate the complete candidate before replacing a live run. Resource references serialize as validated catalog identities, not arbitrary paths or executable Godot objects. Preserve integer precision, finite numeric bounds, collection limits, and cross-record identities.

If the meaning or shape changes, make the version decision explicit. Add pure, sequential, validated migrations for supported older data, or an explicit obsolete-version removal policy. Preserve unsupported future saves and failed/corrupt records until the user deliberately discards them. Never turn load failure into an automatic empty save.

## 3. Update both target proofs and seeds

Exercise changed invariants through the shared codec and public facade. Add or update deterministic development fixtures with the same constructor and validation as real new games. No seed-only state shape or hidden production test hook.

Use native process restart for filesystem durability and a real browser/IndexedDB reload for browser durability. Test the relevant failure boundary: interrupted or failed commit, stale revision, malformed or incompatible data, deletion with pending writes, or slot capacity. A pure codec test does not prove an adapter, and a single backend pass does not prove both.

## 4. Update owning guidance

Keep the affected model docs, [save architecture](../../../docs/save-state.md), root `AGENTS.md`, and this skill aligned with the final implementation. Keep field inventories and limits in the architecture instead of duplicating them here. Update CI test classification when adding native checks and keep browser save tests in the appropriate build/deploy gate.

Describe implemented behavior separately from untested behavior and released behavior. Existing user authorization applies; this workflow adds no approval prompt or deployment authority.

## 5. Audit and gate

Review the scoped diff for newly introduced state, asymmetric capture/restore, raw storage calls outside adapters, identity aliases, unsafe numeric coercion, unsupported-version overwrites, and scheduled writes that can resurrect deleted slots. Check that derived state is rebuilt after restoration without replaying gameplay effects.

Run the relevant native checks, disposable production/probe exports, and browser save workflows. Broaden to the existing full native/browser gate when changing shared model initialization, scene lifecycle, or a release artifact. Use the repository's current test commands and isolated project copies; do not import the open editor checkout headlessly.

Finish with the state/version decision and actual test evidence. When release is part of the request, also prove the exact merged revision passes the main gate and the public game serves that revision. Do not infer deployment from local passes.
