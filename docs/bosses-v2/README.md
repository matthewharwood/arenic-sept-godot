# Eight scores for Arenic

Eight Normal encounters turn the existing two-minute recording loop into eight different spatial instruments. Each contains six authored moves, four thirty-second phrases, exact tick timings, a complete arena definition, a WoW precedent, and a role for every documented hero ability. These are build specifications for **encounter ruleset `v2.0`**, not a claim that the encounters or the 24 future abilities already run in Godot.

| Arena / boss | Primary historical precedent | The recurring decision | Score |
| --- | --- | --- | --- |
| Labyrinth / The Switchkeeper (Hunter) | Operator Thogar, Blackrock Foundry, Warlords of Draenor | Cross a traffic lane or keep firing from a siding? | [Hunter](01-hunter.md) |
| Bastion / The Iron Cantor (Warrior) | Will of the Emperor, Mogu’shan Vaults, Mists of Pandaria | Spend uptime on a flank or finish a clean dodge phrase? | [Warrior](02-warrior.md) |
| Pawnshop / The Glass Usurer (Thief) | Artificer Xy’mox, Castle Nathria, Shadowlands | Take the portal shortcut or the reliable outer route? | [Thief](03-thief.md) |
| Crucible / The Ninth Formula (Alchemist) | Professor Putricide, Icecrown Citadel, Wrath of the Lich King | Work beside a reagent now or reserve its reaction window? | [Alchemist](04-alchemist.md) |
| Sanctum / The Twofold Witness (Cardinal) | Maiden of Vigilance, Tomb of Sargeras, Legion | Match the current seal or use the neutral aisle? | [Cardinal](05-cardinal.md) |
| Gala / The Last Conductor (Bard) | Council of Blood, Castle Nathria, Shadowlands | Finish the floor phrase or preserve a cast window? | [Bard](06-bard.md) |
| Mountain / The Crystal Mason (Forager) | Fractillus, Manaforge Omega, The War Within | Build beside a wall before it becomes a shard fan? | [Forager](07-forager.md) |
| Casino / The House Without Chance (Merchant) | Opulence, Battle of Dazar’alor, Battle for Azeroth | Commit to a dividend window or bank a safer smaller return? | [Merchant](08-merchant.md) |

Read [the shared contract](CONTRACT.md) before an individual score. [The ability contract](ABILITIES.md) resolves all 32 ability identities and their deterministic variants. [Interaction algebra](INTERACTIONS.md) defines every pair and the rules for larger compositions. [Evaluation](EVALUATION.md) supplies the distance measure and the limits of the validation. [Implementation](IMPLEMENTATION.md) gives the build order, persistence work, and acceptance fixtures.

The research has two depths: [comparative analysis](research/README.md), including detailed selected precedents and alternatives, and twelve linked era inventories generated from pinned BigWigs encounter modules. The inventories cover every encounter module in that corpus after the documented exclusions; they are **not exhaustive tactical guides to every WoW difficulty, dungeon, quest, or historical patch**. Individual inventory rows distinguish source evidence from design inference. The source corpus spans Classic through Midnight and includes world bosses and Season of Discovery variants. See the explicit coverage gaps before treating its count as a count of all WoW bosses.

## Design commitments

A boss performs the same score even with no heroes, one hero, forty ghosts, or a completely different damage total. Boss positioning, facing, hazard masks, spawns, resets, and exposure windows never read threat, health, player location, roster size, gear, success counters, loot, or random numbers. Actions may change their recipient’s damage, healing, protection, or cycle-local income. They cannot rewrite the score.

Every class can enter alone and make progress. No mechanic demands a tank, a healer, a cleanse, an interrupt, a teleport, an item, a paid currency, or a minimum number of bodies. There is always a walking solution from the published staging routes. A bad take can still die; “no dead end” means no unavoidable composition lock or permanent loss of progress, not immunity to mistakes or to deliberately colliding with another recording.

All eight keep the same readable grammar: **announce → commit → resolve → recover**. Each score uses A–A′–B–A″: establish a motif, vary one spatial property, introduce a contrasting task, then return to the motif with one known overlap. These are original scores with specific historical precedents, not copies of WoW encounter timings.

## Deliverables and authority

- Eight encounter documents and [machine-readable design scores](data/scores.json).
- A 32 × 8 interaction table, embedded into the eight encounters and stored in [coverage data](data/ability-coverage.json).
- A reproducible validator, distance report, and finite coverage counts in [validation](data/validation.json).
- Source provenance, per-era encounter inventories, and an explicit shortlist comparison.

Only this new documentation directory is part of this change. Existing runtime resources, current scores, artwork, recordings, and unrelated work remain under their current authority. At build time, the versioning plan is mandatory: silently replacing the old Labyrinth score would invalidate existing takes.
