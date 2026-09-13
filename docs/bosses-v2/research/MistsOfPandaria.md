# MistsOfPandaria encounter inventory

This era contains **48 encounter modules** in the pinned corpus. The module author’s encounter observations are source evidence; the candidate-design assessment is an inference for Arenic. This is a breadth screen, not a full tactical guide or a claim that every version of every mechanic was replayed. Preserve variant names: they may distinguish retail, Classic, faction variants, or Season of Discovery.

Source: BigWigs Mods, [BigWigs_MistsOfPandaria](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/tree/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4), revision `11ab705fd775a6ac7bd9f971d218717c4eb5b1d4`, committed 2026-07-02T23:11:08Z. Full provenance and exclusions: [research contract](README.md).

## EndlessSpring

### Lei Shi

**Evidence:** Engage Check, Scary Fog, Scary Fog Removed, Spray, Hide, Get Away Applied. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/EndlessSpring/LeiShi.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Protectors of the Endless

**Evidence:** Sha Corruption First, Sha Corruption Second, Expel Corruption, Defiled Ground, Defiled Ground Damage, Lightning Prison Applied. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/EndlessSpring/Protector.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Sha of Fear

**Evidence:** Huddle In Terror Applied, Huddle In Terror Removed, Waterspout, Implacable Strike, Emerge, Submerge. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/EndlessSpring/ShaOfFear.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Tsulong

**Evidence:** Sunbeam Spawn, Engage Check, Terrorize, Dread Shadows, Sunbeam, Sun Breath. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/EndlessSpring/Tsulong.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

## HeartOfFear

### Garalon

**Evidence:** Pheromone Trail, Crush, Fury, Pheromones Applied, Pheromones Removed, Pungency. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/HeartOfFear/Garalon.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Wind Lord Mel'jarak

**Evidence:** Whirling Blade Damage, Residue Removed, Amber Prison, Amber Prison Removed, Rain Of Blades, Quickening. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/HeartOfFear/Meljarak.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, movement, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Grand Empress Shek'zeer

**Evidence:** Heart Of Fear Removed, Heart Of Fear Applied, Dispatch, Poison, Dread Screech, Consuming Terror. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/HeartOfFear/Shekzeer.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, support, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Blade Lord Ta'yak

**Evidence:** Wind Step Applied, Wind Step Removed, Blade Tempest, Wind Step, Tayak Casts, Instructor Unseen Strike. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/HeartOfFear/Tayak.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Amber-Shaper Un'sok

**Evidence:** Parasitic Growth, Parasitic Growth Removed, Burning Amber, Amber Scalpel, Reshape Life, Reshape Life Removed. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/HeartOfFear/Unsok.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Imperial Vizier Zor'lok

**Evidence:** Convert, Attenuation, Pre Force And Verse, Force And Verse, Exhale, Exhale Over. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/HeartOfFear/Zorlok.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

## Mogushan

### Elegon

**Evidence:** Floor Removed, Overcharged Applied, Overcharged Removed, Draw Power, Phase2, Celestial Breath. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/Mogushan/Elegon.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement, routing, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Feng the Accursed

**Evidence:** Lightning Fists, Epicenter, Wildfire Spark, Wildfire, Draw Flame, Arcane Resonance. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/Mogushan/Feng.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** movement, support, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Gara'jal the Spiritbinder

**Evidence:** Frenzy, Big Wigs_Boss Comm, Voodoo Dolls Applied, Voodoo Dolls Removed, Crossed Over, Crossed Over Removed. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/Mogushan/Garajal.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### The Spirit Kings

**Evidence:** Qiang, Zian, Subetai, Meng. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/Mogushan/TheSpiritKings.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### The Stone Guard

**Evidence:** Power Down, Cobalt Petrification, Cobalt Mine, Amethyst Petrification, Amethyst Pool, Jade Petrification. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/Mogushan/TheStoneGuard.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** placement, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Will of the Emperor

**Evidence:** Rage, Focused Assault, Focused Energy, Strength, Courage, Bosses. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/Mogushan/WillOfTheEmperor.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

## Pandaria

### Nalak

**Evidence:** Arc Nova, Lightning Tether, Stormcloud Applied, Stormcloud Removed, Stormcloud Damage. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/Pandaria/Nalak.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Oondasta

**Evidence:** Crush, Piercing Roar, Frill Blast. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/Pandaria/Oondasta.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Ordos

**Evidence:** Magma Crush, Pool Of Fire, Pool Of Fire Damage, Ancient Flame, Ancient Flame Damage, Burning Soul Removed. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/Pandaria/Ordos.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Salyis's Warband

**Evidence:** Cannon Barrage, Stomp. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/Pandaria/Salyis.lua).

**Screen:** death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Sha of Anger

**Evidence:** Growing Anger, Aggressive Behavior, Unleashed Wrath, Bitter Thoughts, Aggressive Behavior (Mind Control). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/Pandaria/ShaOfAnger.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

## SiegeOfOrgrimmar

### Galakras

**Evidence:** Ranking Officials, Foot Soldiers, Galakras. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/SiegeOfOrgrimmar/Galakras.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** support, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Garrosh Hellscream

**Evidence:** Farseer, Intermissions, Warmup, Warmup Backup, Manifest Rage, Phase3End. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/SiegeOfOrgrimmar/GarroshHellscream.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement, support, routing, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### General Nazgrim

**Evidence:** Hunters Mark, Execute, Arcane Shock, Magistrike, Healing Tide Totem, Chain Heal. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/SiegeOfOrgrimmar/GeneralNazgrim.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Immerseus

**Evidence:** Swelling Corruption, Sha Corruption, Corrosive Blast, Corrosive Blast Stack, Splits, Reform. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/SiegeOfOrgrimmar/Immerseus.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Iron Juggernaut

**Evidence:** Assault mode, Siege mode, Mine Arming, Reset Marking, Explosive Tar, Cutter Laser Removed. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/SiegeOfOrgrimmar/IronJuggernaut.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Kor'kron Dark Shaman

**Evidence:** Earthbreaker Haromm, Wavebinder Kardris, Iron Tomb, Iron Prison, Toxic Mist Removed, Toxic Mist Applied. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/SiegeOfOrgrimmar/KorKron.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Malkorok

**Evidence:** Rage Phase, Non rage phase, Displaced Energy Removed, Displaced Energy Applied, Displaced Energy, Blood Rage. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/SiegeOfOrgrimmar/Malkorok.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement, routing, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Norushen

**Evidence:** Amalgam of Corruption, Big add, Look Within. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/SiegeOfOrgrimmar/Norushen.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Paragons of the Klaxxi

**Evidence:** Rapid Fire, Aim, Aim Removed, Prey, Mutate, Faulty Mutation Removed. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/SiegeOfOrgrimmar/ParagonsOfTheKlaxxi.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** support, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Sha of Pride

**Evidence:** Weakened Resolve Over, Weakened Resolve Begin, Banishment, Unleashed Start, Unleashed, Imprison Applied. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/SiegeOfOrgrimmar/ShaOfPride.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Siegecrafter Blackfuse

**Evidence:** Siegecrafter Blackfuse, Automated Shredders, The Assembly Line. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/SiegeOfOrgrimmar/SiegecrafterBlackfuse.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Spoils of Pandaria

**Evidence:** Mogu crate, Mantid crate, Crate of Panderan Relics. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/SiegeOfOrgrimmar/SpoilsOfPandaria.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement, support, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### The Fallen Protectors

**Evidence:** Rook Stonetoe, He Softfoot, Sun Tenderheart. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/SiegeOfOrgrimmar/TheFallenProtectors.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Thok the Bloodthirsty

**Evidence:** Prisoner Tracker, Yet Charge, Blood Frenzy, Enrage, Skeleton Key Removed, Skeleton Key. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/SiegeOfOrgrimmar/Thok.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement, support, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

## ThroneOfThunder

### Council of Elders

**Evidence:** High Priestess Mar'li, Sul the Sandcrawler, Kazra'jin, Frost King Malakk. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/ThroneOfThunder/Council.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Dark Animus

**Evidence:** Large Anima Golem, Massive Anima Golem, Dark Animus. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/ThroneOfThunder/DarkAnimus.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Durumu the Forgotten

**Evidence:** Dark Parasite Removed, Dark Parasite Applied, On Boss Disable, Ice Wall, Eye Sore Damage, Life Drain Cast. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/ThroneOfThunder/Durumu.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Horridon

**Evidence:** Farraki, Gurubashi, Drakkari, Amani, War-God Jalak. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/ThroneOfThunder/Horridon.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, movement, support, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Iron Qon

**Evidence:** Dam'ren, Quet'zal, Ro'shak. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/ThroneOfThunder/IronQon.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Ji-Kun

**Evidence:** Caw, Primal Nutriment, Flight, Feed Young, Talon Rake, Infected Talons. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/ThroneOfThunder/JiKun.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Jin'rokh the Breaker

**Evidence:** Ionization Removed, Personal Ionization, Ionization, Lightning Storm Duration, Lightning Storm, Thundering Throw Safe. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/ThroneOfThunder/Jinrokh.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Lei Shen

**Evidence:** Mark Check, Stop Mark Check, Chain Lightning, Summon Small Diffused Lightning, Add Deaths, Helm Of Command. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/ThroneOfThunder/LeiShen.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Megaera

**Evidence:** Arcane Head, Fire Head, Frost Head, Poison Head. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/ThroneOfThunder/Megaera.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, movement, support, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Primordius

**Evidence:** Viscous Horror, Player Mutations, Fully Mutated Removed, Fully Mutated Applied, Erupting Pustules Removed, Erupting Pustules Applied. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/ThroneOfThunder/Primordius.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Ra-den

**Evidence:** XXX 139040 fix desc last phase balls, Anima, Unstable Anima Repeated Damage, Anima Sensitivity Applied, Anima Sensitivity Removed, Unstable Anima Applied. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/ThroneOfThunder/Raden.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** routing, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Tortos

**Evidence:** Breath Update, Crystal Shell, Crystal Shell Removed, Snapping Bite, Summon Bats, Quake Stomp. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/ThroneOfThunder/Tortos.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Twin Consorts

**Evidence:** Lu'lin, Suen, Celestial Aid. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_MistsOfPandaria/blob/11ab705fd775a6ac7bd9f971d218717c4eb5b1d4/ThroneOfThunder/TwinConsorts.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.
