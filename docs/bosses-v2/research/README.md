# World of Warcraft encounter research

## Scope and evidence

The design survey spans Classic, The Burning Crusade, Wrath of the Lich King, Cataclysm, Mists of Pandaria, Warlords of Draenor, Legion, Battle for Azeroth, Shadowlands, Dragonflight, The War Within, and Midnight. It starts from all eight legacy Arenic boss documents and all 32 ability documents, then screens a pinned historical corpus of BigWigs encounter modules. Selected mechanics are cross-checked against detailed encounter guides and contemporary player/author observations.

The corpus is **not an official exhaustive census of every battle in WoW**. It includes instanced raids, outdoor bosses, original/Classic distinctions where separately modeled, faction variants, and Season of Discovery. It excludes dungeons, ordinary quests, trash, PvP, private-server encounters, generic affix modules, and code examples. An encounter may have many difficulty versions in one module; a council can have several combatants in one module. Counts are therefore module counts, never asserted unique-boss totals.

Every retained source file was read by the corpus extractor. Its encounter name, option labels or handler names, difficulty/state/target-sensitive signals, provenance, and design screening are recorded. These are **module-level screening dossiers**, not hand-authored deep tactical studies of hundreds of fights. The eight selected precedents receive the deeper comparative treatment below. There is no honest finite proof about every possible future WoW battle, every historical hotfix, or every unbounded party permutation.

For full historical scholarship beyond this build brief, the remaining coverage gaps are optional Karazhan animal variants not individually represented by these modules, encounters omitted by upstream, anniversary/event versions such as the 2024 Blackrock Depths raid, and exact live-release status of every newer Midnight/Lair module. Seasonal remixes and retuning require version-by-version client journals or archived logs. The corpus keeps newer module observations without treating file presence as proof of release. Midnight Season 2 is corroborated by Blizzard’s [Venomous Abyss announcement](https://worldofwarcraft.blizzard.com/en-us/news/24294062); its search-index date is inconsistent, so no exact release date is derived from that metadata.

## Breadth ledger

| Era | Encounter modules | Evidence |
| --- | ---: | --- |
| Classic | 102 | [Era dossiers](Classic.md) |
| BurningCrusade | 54 | [Era dossiers](BurningCrusade.md) |
| WrathOfTheLichKing | 54 | [Era dossiers](WrathOfTheLichKing.md) |
| Cataclysm | 31 | [Era dossiers](Cataclysm.md) |
| MistsOfPandaria | 48 | [Era dossiers](MistsOfPandaria.md) |
| WarlordsOfDraenor | 34 | [Era dossiers](WarlordsOfDraenor.md) |
| Legion | 59 | [Era dossiers](Legion.md) |
| BattleForAzeroth | 50 | [Era dossiers](BattleForAzeroth.md) |
| Shadowlands | 35 | [Era dossiers](Shadowlands.md) |
| Dragonflight | 32 | [Era dossiers](Dragonflight.md) |
| TheWarWithin | 30 | [Era dossiers](TheWarWithin.md) |
| Midnight | 22 | [Era dossiers](Midnight.md) |

**Total: 551 retained modules; 5 excluded examples/affix modules.** [Structured corpus](../data/research-corpus.json) contains revision pins and per-file checksums.

## What changed from the Arenic starting point

The original eight drafts provide valuable identities: traps, attrition, deception, chemistry, inversion, rhythm, terrain, and gambling. Their two-minute structure is retained. Their proposed RNG, hidden/fake warnings, shuffled keys, reversed causality, player-target prediction, speed changes, health-based transitions, and unwinnable final checks are rejected. Their “OC scores” have no reproducible derivation; the new distance method exposes its features, weights, full pair matrix, and limitations.

The new identities preserve the visual families while choosing a different action vocabulary: crossing, answering, routing, sequencing, attuning, phrasing, building, and investing. Bosses never need to die for a phase to advance. The Hunter’s existing corner patrol remains available under its old score version, rather than being overwritten beneath old recordings.

## Comparative selection across the full history

This table records the high-value alternatives considered across every expansion era. Citations point to the era dossiers, which link the individual pinned source modules. These are design judgments about adaptation cost, not a ranking of WoW encounter quality.

| Era | Candidates and useful relationship | Reason for final disposition |
| --- | --- | --- |
| [Classic](Classic.md) | Heigan’s safe-zone travel; C’Thun’s eye/beam patterns; Four Horsemen’s positional rotation; Thaddius’s polarity; Sapphiron’s cover | Strong foundational vocabulary. Heigan overlaps the chosen floor/traffic designs; Thaddius’s player-contact polarity is less compatible than optional self-attunement. No resist roster or unavoidable raid wipe is imported. |
| [Burning Crusade](BurningCrusade.md) | Karazhan Opera’s readable vignettes; Netherspite’s beam occupation; Shade of Aran’s movement constraints; Kael’thas’s staged escalation; M’uru’s density | Beam occupation and staged props are useful secondary references. Mandatory simultaneous jobs and changes caused by add deaths carry unnecessary recording/composition risk. |
| [Wrath](WrathOfTheLichKing.md) | Putricide’s lab sequence; Mimiron’s contrasting machines; Ulduar’s optional hard modes; Twin Val’kyr essences; Sindragosa’s ice cover; Lich King’s terrain phases | Putricide is the chemistry primary. Twin Val’kyr informs voluntary attunement. Mimiron would add substantial multi-body art and mode implementation; health-triggered arena changes are not adopted. |
| [Cataclysm](Cataclysm.md) | Atramedes’s sound meter; Rhyolith’s steering; Ragnaros’s repeated slam/seed language; Alysrazor’s traversal; Spine’s staged payload | Explicit warnings are useful. Actual audio dependence, player steering of boss routes, flight-mode requirements, and role-gated payloads conflict with the stable-score goal. |
| [Mists](MistsOfPandaria.md) | Will of the Emperor’s dodge/reward; Elegon’s platform boundary; Durumu’s maze; Lei Shen’s quadrants; Siegecrafter’s production line; Spoils’ paired rooms | Emperor provides the close-range primary. Durumu risks duplicating traffic and floor choreography; kill-selected assembly lines and split-room throughput require more state than the first eight need. |
| [Warlords](WarlordsOfDraenor.md) | Thogar’s traffic; Hans’gar/Franzok’s factory rhythm; Kromog’s shelter/destruction; Tectus’s splitting; Iskar’s handoff; Gorefiend’s separate jobs | Thogar supplies the most direct authored-timetable precedent. Fractillus later gives the clearer wall lifecycle. Splitting and handoff requirements are optional future material. |
| [Legion](Legion.md) | Maiden’s polarity; Elisande’s returning waves; Chronomatic Anomaly’s pace changes; Eonar’s defense; Kil’jaeden’s intermissions; Aggramar’s combo | Maiden supplies self-attunement. Elisande is a useful visual-repetition reference but actual time-rate changes are rejected. Aggramar overlaps Emperor’s duel; Eonar adds mandatory jobs. |
| [Battle for Azeroth](BattleForAzeroth.md) | Opulence’s preparation/payoff; MOTHER’s crossing; Jaina’s visibility/terrain; Azshara’s wards; Xanesh’s routing | Opulence best transforms the Merchant away from random combat. MOTHER duplicates crossing; false information and mandatory orb relays would punish unrelated recordings. |
| [Shadowlands](Shadowlands.md) | Xy’mox’s portal/relic grammar; Council’s dance; Painsmith’s lanes; Sludgefist’s pillar cadence; Fatescribe’s rings; Halondrus’s movement pressure | Xy’mox and Council are selected for different jobs: optional shortcuts and optional floor performance. They share an expansion but have separate arenas, geometry, reward conditions, and casts. |
| [Dragonflight](Dragonflight.md) | Dathea’s platforms; Kurog’s sector identity; Echo of Neltharion’s walls; Nymue’s weave; Smolderon’s rings; Tindral’s traversal | All screened. Nymue is a close alternative to Gala/Mountain but would blur their distinction. Mount/flight requirements and persistent room destruction increase adaptation cost. |
| [The War Within](TheWarWithin.md) | Fractillus’s crystal lifecycle; Ky’veza’s phantom lines; Silken Court’s countermechanics; One-Armed Bandit’s posted combinations; Rik Reverb’s sound objects; Dimensius’s scale | Fractillus is the terrain primary. One-Armed Bandit is a strong Merchant alternate, but Opulence better anchors preparation and a stable payoff without chance-based theming becoming a rules assumption. |
| [Midnight](Midnight.md) | Voidspire’s different spatial tests; Dreamrift’s realm vocabulary; Quel’Danas’s polarity; Venomous Abyss’s poison/wall/phase patterns; Sporefall and Lair modules | Included in the contemporary corpus. No selected primary depends on a newly changing ruleset or uncertain module release status; these supply expansion-wide comparisons and future candidates. |

## Deep dives into the eight selected precedents

### Operator Thogar → The Switchkeeper

**Historical scope:** Blackrock Foundry, Warlords of Draenor; Normal/Heroic, 2015; Mythic considered separately.

Thogar uses four tracks and a repeatable train arrival sequence, with troop arrivals and blocked space creating prioritization. The documented original train sequence is fixed per pull rather than a looping two-minute pattern. Arenic borrows anticipation of cross-traffic and station occupancy; it authors a new loop and removes kill-dependent departures and the all-track enrage. [Detailed guide](https://www.icy-veins.com/wow/operator-thogar-strategy-guide-normal-heroic-mythic). The [pinned author-maintained module](https://github.com/BigWigsMods/BigWigs_WarlordsOfDraenor/blob/ad94f51d9c2c44cd4afdc957e4f18f226a462845/BlackrockFoundry/Thogar.lua) independently records the named encounter’s warning/state vocabulary.

**Adaptation:** Trains are spectral web shuttles with a finite hazard rectangle, never target-seeking traps. Optional projectile cover and preparatory floor damage matter between departures. A cross-platform swap in B reverses the direction of study without changing the map.

**What would break a take:** Train occupancy is a timed hazard, not physics or a line-of-sight wall. Do not accidentally make the scenic rails impassable. A shortened travel animation must not shorten the 180-tick transfer warning.

**Build consequence:** the [Arenic score](../01-hunter.md) is a new 120-second composition with no imported WoW numerical tuning. Its six-move vocabulary and all 32 ability interactions are specified independently from the source.

### Will of the Emperor → The Iron Cantor

**Historical scope:** Mogu’shan Vaults, Mists of Pandaria; Normal five-strike combo; Heroic’s longer combo is not imported.

Will of the Emperor rewards avoiding Devastating Combo with Opportunistic Strike while adds create separate pressures. Normal and Heroic have different combo lengths; references to ten attacks belong to Heroic. Arenic takes the dodge-and-answer relationship, not the original encounter’s adds, taunt behavior, or numerical damage. [Detailed guide](https://www.icy-veins.com/mists-of-pandaria-classic/will-of-the-emperor-encounter-guide-strategy-abilities-loot). The [pinned author-maintained module](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/Mogushan/WillOfTheEmperor.lua) independently records the named encounter’s warning/state vocabulary.

**Adaptation:** One immortal duelist replaces two bosses. Every cleave direction is printed in advance. Completing a phrase provides an optional personal riposte; failure loses only the reward or health, never prevents the next phrase.

**What would break a take:** Rotated masks must be baked into data. Never use current player orientation to rotate the duel. No weapon animation creates extra contact frames.

**Build consequence:** the [Arenic score](../02-warrior.md) is a new 120-second composition with no imported WoW numerical tuning. Its six-move vocabulary and all 32 ability interactions are specified independently from the source.

### Artificer Xy'mox → The Glass Usurer

**Historical scope:** Castle Nathria, Shadowlands; Normal/Heroic relic phases; Mythic overlap used only as a comparison.

Castle Nathria Xy’mox combines Dimensional Tear portals with relic hazards including seeds, spirits, and a central annihilation weapon. Its original portals are dropped by selected players. Arenic instead fixes portal positions and relic order, and omits random assignment and chasing fixates. [Detailed guide](https://www.icy-veins.com/wow/artificer-xy-mox-strategy-guide-for-castle-nathria). The [pinned author-maintained module](https://github.com/BigWigsMods/BigWigs_Shadowlands/blob/f9b43b9e82e2a8c72a72b97a73b50a6813e4a8f6/CastleNathria/Xymox.lua) independently records the named encounter’s warning/state vocabulary.

**Adaptation:** Three displayed relics correspond to three reproducible routing problems. The boss remains a single clearly identified target. A recorded portal route remains legible even without audio, and walking around the outside always works.

**What would break a take:** Portal transfers must be integrated into the existing movement/contact phase. Do not replay a portal crossing twice after restore, resolve it against a render position, or search for a different exit if occupied.

**Build consequence:** the [Arenic score](../03-thief.md) is a new 120-second composition with no imported WoW numerical tuning. Its six-move vocabulary and all 32 ability interactions are specified independently from the source.

### Professor Putricide → The Ninth Formula

**Historical scope:** Icecrown Citadel, Wrath of the Lich King; Normal baseline; Heroic Unbound Plague explicitly excluded.

Putricide mixes persistent slime, alternating experimental adds, gas bombs and bouncing goo; the abomination provides a way to manage floor pressure. Health thresholds change the original phases, and Heroic adds Unbound Plague. Arenic preserves laboratory sequencing and preparation, while replacing player-chasing experiments with fixed reagent tracks. [Detailed guide](https://www.icy-veins.com/wotlk-classic/professor-putricide-encounter-guide-strategy-abilities-loot). The [pinned author-maintained module](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Citadel/Putricide.lua) independently records the named encounter’s warning/state vocabulary.

**Adaptation:** The chemistry is a scored circuit, not a simulation of arbitrary multiplying pools. Player Acid never changes a boss pool’s radius, identity, fuse, or next reaction. A helpful reagent action earns a local bonus without causing a cascade.

**What would break a take:** All reaction dependencies are authored event IDs, with depth at most one. Never let a player pool, a cleansed debuff, or an intercepted vial trigger or cancel another boss event.

**Build consequence:** the [Arenic score](../04-alchemist.md) is a new 120-second composition with no imported WoW numerical tuning. Its six-move vocabulary and all 32 ability interactions are specified independently from the source.

### Maiden of Vigilance → The Twofold Witness

**Historical scope:** Tomb of Sargeras, Legion; Normal/Heroic infusion and instability; no raid-wide mandatory soak.

Maiden of Vigilance assigns Light/Fel infusions; opposite-element interactions trigger Unstable Soul, with a pit-and-ward response and a later shielded phase. Arenic uses explicit polarity and personal recovery, but removes random assignment, inter-player chain explosions, knockback, and required shield breaking. Twin Val’kyr supplies a secondary comparison for voluntarily selected essences, not a second primary precedent. [Detailed guide](https://www.icy-veins.com/wow/maiden-of-vigilance-strategy-tactics-normal-heroic). The [pinned author-maintained module](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/TombOfSargeras/MaidenofVigilance.lua) independently records the named encounter’s warning/state vocabulary.

**Adaptation:** No beneficial ability ever becomes hostile. Sun and Moon are actor-owned tags, not healing inversion. An untagged solo actor can complete the entire score through the neutral aisle. A failed match deals one immediate personal wound; Confession separately applies delayed Exposure. Neither creates a raid-wide explosion.

**What would break a take:** Do not implement polarity as a debuff that Cleanse removes, and do not trigger explosions on hero adjacency. Attunement affects only damage evaluation and the optional bonus, never movement or recorded casts.

**Build consequence:** the [Arenic score](../05-cardinal.md) is a new 120-second composition with no imported WoW numerical tuning. Its six-move vocabulary and all 32 ability interactions are specified independently from the source.

### The Council of Blood → The Last Conductor

**Historical scope:** Castle Nathria, Shadowlands; Normal/Heroic dance; no health-triggered transition or kill order.

Council of Blood alternates ordinary combat with Danse Macabre at health thresholds; successful movement earns a benefit. Different kill orders also change the remaining mechanics. Arenic borrows a readable dance and returning combat, while fixing every intermission in time and removing kill-order dependence and attack-speed changes. [Detailed guide](https://www.icy-veins.com/wow/the-council-of-blood-strategy-guide-for-castle-nathria). The [pinned author-maintained module](https://github.com/BigWigsMods/BigWigs_Shadowlands/blob/f9b43b9e82e2a8c72a72b97a73b50a6813e4a8f6/CastleNathria/TheCouncilofBlood.lua) independently records the named encounter’s warning/state vocabulary.

**Adaptation:** The floor gives a movement score separate from the Bard hero’s Dance ability. Any class can perform the floor phrase. Visual footfall markers carry the full information when sound is muted.

**What would break a take:** Dance ability grading and encounter floor grading are separate actor counters. Do not pause or speed up a timeline to align music. Never shuffle keys, icons, or cast order.

**Build consequence:** the [Arenic score](../06-bard.md) is a new 120-second composition with no imported WoW numerical tuning. Its six-move vocabulary and all 32 ability interactions are specified independently from the source.

### Fractillus → The Crystal Mason

**Historical scope:** Manaforge Omega, The War Within; Heroic wall construction/shattering relationship; original tuning not copied.

Fractillus creates crystal walls in lanes and uses later mechanics to shatter them; wall accumulation and fragments create pressure. Source guides describe player-directed placement and knockback-driven destruction. Arenic keeps construction followed by demolition but fixes wall locations and expiry, and replaces knockback tasks with optional preparation rewards. [Detailed guide](https://www.method.gg/guides/manaforge-omega/fractillus-heroic). The [pinned author-maintained module](https://github.com/BigWigsMods/BigWigs_TheWarWithin/blob/da9346c72880dcd19731f86312d9d02bd6b348c3/ManaforgeOmega/Fractillus.lua) independently records the named encounter’s warning/state vocabulary.

**Adaptation:** The arena changes connectivity on schedule. Player attacks cannot open or close a route early. Each raised rib has two open ends; permanent corridors and a perimeter circuit prevent topology locks.

**What would break a take:** Wall removal at the same tick as shatter must happen before movement and impact geometry. Do not use player Boulder or Dig to remove the wall collision early; those interactions grant damage only.

**Build consequence:** the [Arenic score](../07-forager.md) is a new 120-second composition with no imported WoW numerical tuning. Its six-move vocabulary and all 32 ability interactions are specified independently from the source.

### Opulence → The House Without Chance

**Historical scope:** Battle of Dazar’alor, Battle for Azeroth; Normal/Heroic split approach and jewel preparation.

Opulence begins with separate trapped approaches and preparatory crown jewels before the treasury fight, whose gold effects reward spatial organization. Arenic takes investment before payoff and different approaches. It omits compulsory group splitting, mandatory jewel roles, raid-size tuning, and random payouts. [Detailed guide](https://www.wowhead.com/guide/opulence-treasure-guardian-battle-of-dazaralor-raid-strategy-guide). The [pinned author-maintained module](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/BattleOfDazaralor/Opulence.lua) independently records the named encounter’s warning/state vocabulary.

**Adaptation:** Cycle-local scrip and personal entitlements guarantee a solvent next loop. The house advertises a posted dividend schedule; a cautious outer route trades a small opportunity for stable progress. Cosmetic dice and roulette never decide combat.

**What would break a take:** No bonus depends on bank wealth, lucky rolls, prior-cycle streaks, or how many other heroes took the pad. Do not turn resource shortage into a recording refusal on a later cycle; wallets reset at the seam.

**Build consequence:** the [Arenic score](../08-merchant.md) is a new 120-second composition with no imported WoW numerical tuning. Its six-move vocabulary and all 32 ability interactions are specified independently from the source.

## Source interpretation and conflicts

BigWigs is an author-maintained observation/alert model, not Blizzard’s authoritative server code. Its event handlers show what the addon reacts to, not a complete description of what the encounter does. Handler absence cannot prove that a boss lacks a mechanic; a timer bar cannot prove exact server cadence. The screening flags therefore guide adaptation risk, while the selected mechanics are checked against encounter guides.

Some guides disagree about Council kill order (Frieda-first versus Niklaus-first). That is a strategy choice and does not change the selected dance precedent; Arenic imports no kill order. Emperor guides may lead with Heroic’s ten-hit combo while describing Normal’s five later; the design explicitly identifies the difficulty. Putricide’s Unbound Plague belongs to Heroic, not Normal. The Xy’mox primary is Castle Nathria, not the later Sepulcher encounter. Thogar’s original fixed train schedule does not loop within its full fight; Arenic’s authored two-minute wrap is an adaptation. Fractillus’s player-placed walls and knockback removal are replaced with fixed construction and demolition events.

Guide publication metadata is retained where visible: Vlad’s Thogar guide was updated April 13, 2015; Abide’s Emperor guide July 29, 2025; Council/Xy’mox reference guides originate in the Castle Nathria period. Other pages are cited by exact title/URL and treated as accessed September 13, 2026 without inventing an unavailable original publication date. Revision-specific module dates and hashes are in the structured corpus.

## Source register

1. Matthew Harwood, [legacy Arenic boss set](https://github.com/matthewharwood/arenic_bevy/tree/58c3aa5675e3b29e7b962fbfc7fb6d1d75da6b97/_docs/bosses) and [32 abilities](https://github.com/matthewharwood/arenic_bevy/tree/58c3aa5675e3b29e7b962fbfc7fb6d1d75da6b97/_docs/abilities), matched local and remote revision. Starting identities and rejected mechanics.
2. Active Arenic repository: [combat](../../combat.md), [recording](../../recording.md), [encounter model](../../encounters.md), and current resource/script contracts. These supply the local implementation baseline.
3. BigWigs Mods, twelve era repositories and exact revisions listed below. Primary author-maintained encounter observations; all inventory rows link exact source files.
   - [BigWigs_Classic](https://github.com/BigWigsMods/BigWigs_Classic/tree/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef) — 2026-09-03T16:35:31Z, `2cc8e655144c096c6c0a070ecb0a1dd9157f81ef`.
   - [BigWigs_BurningCrusade](https://github.com/BigWigsMods/BigWigs_BurningCrusade/tree/89a5db9b0e567f493471d151c56b4a72481c3008) — 2026-09-12T17:19:46Z, `89a5db9b0e567f493471d151c56b4a72481c3008`.
   - [BigWigs_WrathOfTheLichKing](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/tree/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd) — 2026-08-10T20:10:51Z, `b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd`.
   - [BigWigs_Cataclysm](https://github.com/BigWigsMods/BigWigs_Cataclysm/tree/371db88970151039862e72f6ad9b245dc8a63f37) — 2026-06-26T16:36:37Z, `371db88970151039862e72f6ad9b245dc8a63f37`.
   - [BigWigs_MistsOfPandaria](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/tree/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4) — 2026-07-02T23:11:08Z, `11ab705fd775a6ac7bd9f971d218717c4eb5b1d4`.
   - [BigWigs_WarlordsOfDraenor](https://github.com/BigWigsMods/BigWigs_WarlordsOfDraenor/tree/ad94f51d9c2c44cd4afdc957e4f18f226a462845) — 2026-06-26T16:04:01Z, `ad94f51d9c2c44cd4afdc957e4f18f226a462845`.
   - [BigWigs_Legion](https://github.com/BigWigsMods/BigWigs_Legion/tree/bbc48372f2b4483f1573175de20fd7b805785bc9) — 2026-06-26T16:14:51Z, `bbc48372f2b4483f1573175de20fd7b805785bc9`.
   - [BigWigs_BattleForAzeroth](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/tree/ddb54c9f8bb25c8a23167c0688ee428b33091b31) — 2026-06-26T16:30:12Z, `ddb54c9f8bb25c8a23167c0688ee428b33091b31`.
   - [BigWigs_Shadowlands](https://github.com/BigWigsMods/BigWigs_Shadowlands/tree/f9b43b9e82e2a8c72a72b97a73b50a6813e4a8f6) — 2026-06-26T16:08:35Z, `f9b43b9e82e2a8c72a72b97a73b50a6813e4a8f6`.
   - [BigWigs_Dragonflight](https://github.com/BigWigsMods/BigWigs_Dragonflight/tree/4e469575ae8d5d54d1fc52ab5ea97400fe84da38) — 2026-06-26T16:17:42Z, `4e469575ae8d5d54d1fc52ab5ea97400fe84da38`.
   - [BigWigs_TheWarWithin](https://github.com/BigWigsMods/BigWigs_TheWarWithin/tree/da9346c72880dcd19731f86312d9d02bd6b348c3) — 2026-06-26T16:06:31Z, `da9346c72880dcd19731f86312d9d02bd6b348c3`.
   - [BigWigs](https://github.com/BigWigsMods/BigWigs/tree/8177bf9d06f2f1b6c51b54bf8da330a39e4c3651) — 2026-09-09T15:54:43Z, `8177bf9d06f2f1b6c51b54bf8da330a39e4c3651`.

4. Icy Veins, [Operator Thogar encounter guide](https://www.icy-veins.com/wow/operator-thogar-strategy-guide-normal-heroic-mythic). Used for the named historical mechanic and difficulty distinctions; accessed September 13, 2026.
5. Icy Veins, [Will of the Emperor encounter guide](https://www.icy-veins.com/mists-of-pandaria-classic/will-of-the-emperor-encounter-guide-strategy-abilities-loot). Used for the named historical mechanic and difficulty distinctions; accessed September 13, 2026.
6. Icy Veins, [Artificer Xy'mox encounter guide](https://www.icy-veins.com/wow/artificer-xy-mox-strategy-guide-for-castle-nathria). Used for the named historical mechanic and difficulty distinctions; accessed September 13, 2026.
7. Icy Veins, [Professor Putricide encounter guide](https://www.icy-veins.com/wotlk-classic/professor-putricide-encounter-guide-strategy-abilities-loot). Used for the named historical mechanic and difficulty distinctions; accessed September 13, 2026.
8. Icy Veins, [Maiden of Vigilance encounter guide](https://www.icy-veins.com/wow/maiden-of-vigilance-strategy-tactics-normal-heroic). Used for the named historical mechanic and difficulty distinctions; accessed September 13, 2026.
9. Icy Veins, [The Council of Blood encounter guide](https://www.icy-veins.com/wow/the-council-of-blood-strategy-guide-for-castle-nathria). Used for the named historical mechanic and difficulty distinctions; accessed September 13, 2026.
10. Method, [Fractillus encounter guide](https://www.method.gg/guides/manaforge-omega/fractillus-heroic). Used for the named historical mechanic and difficulty distinctions; accessed September 13, 2026.
11. Wowhead, [Opulence encounter guide](https://www.wowhead.com/guide/opulence-treasure-guardian-battle-of-dazaralor-raid-strategy-guide). Used for the named historical mechanic and difficulty distinctions; accessed September 13, 2026.
12. Blizzard Entertainment, [Curse of Ula’tek: The Venomous Abyss](https://worldofwarcraft.blizzard.com/en-us/news/24294062). Contemporary raid scope only; no unverified timestamp or tuning imported.
