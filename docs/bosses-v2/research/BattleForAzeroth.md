# BattleForAzeroth encounter inventory

This era contains **50 encounter modules** in the pinned corpus. The module author’s encounter observations are source evidence; the candidate-design assessment is an inference for Arenic. This is a breadth screen, not a full tactical guide or a claim that every version of every mechanic was replayed. Preserve variant names: they may distinguish retail, Classic, faction variants, or Season of Discovery.

Source: BigWigs Mods, [BigWigs_BattleForAzeroth](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/tree/ddb54c9f8bb25c8a23167c0688ee428b33091b31), revision `ddb54c9f8bb25c8a23167c0688ee428b33091b31`, committed 2026-06-26T16:30:12Z. Full provenance and exclusions: [research contract](README.md).

## Azeroth

### Azurethos, The Winged Typhoon

**Evidence:** Wing Buffet, Gale Force, Azurethos' Fury. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/Azeroth/Azurethos.lua).

**Screen:** death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Hailstone Construct

**Evidence:** Freezing Tempest, Glacial Breath, Freezing Tempest, Glacial Breath. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/Azeroth/Construct.lua).

**Screen:** timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. The source module is an alert model, not the game’s full authoritative simulation.

### Doom's Howl

**Evidence:** Shattering Pulse, Mortar Shot, Flame Exhausts, Siege Up, Battle Field Repair, Sentry Protection. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/Azeroth/DoomsHowl.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Ji'arak

**Evidence:** Storm Wing, Hurricane Crash, Matriarch's Call. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/Azeroth/Jiarak.lua).

**Screen:** timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. The source module is an alert model, not the game’s full authoritative simulation.

### Dunegorger Kraulok

**Evidence:** Shake Loose, Primal Rage, Earth Spike. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/Azeroth/Kraulok.lua).

**Screen:** death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### The Lion's Roar

**Evidence:** Shattering Pulse, Mortar Shot, Flame Exhausts, Siege Up, Battle Field Repair, Sentry Protection. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/Azeroth/LionsRoar.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### T'zane

**Evidence:** Crushing Slam, Terror Wail, Coalesced Essence, Consuming Spirits. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/Azeroth/Tzane.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Warbringer Yenajz

**Evidence:** Endless Abyss, Void Nova, Reality Tear. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/Azeroth/Yenajz.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

## BattleOfDazaralor

### Stormwall Blockade

**Evidence:** Sister Katherine, Electric Shroud, Voltaic Flash, Crackling Lightning, Brother Joseph, Tidal Shroud. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/BattleOfDazaralor/Blockade.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Champion of the Light Alliance

**Evidence:** Sacred Blade, Wave of Light, Seal of Retribution, Judgement: Righteousness, Seal of Reckoning, Judgement: Reckoning. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/BattleOfDazaralor/ChampionAlliance.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Champion of the Light Horde

**Evidence:** Sacred Blade, Wave of Light, Seal of Retribution, Judgement: Righteousness, Seal of Reckoning, Judgement: Reckoning. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/BattleOfDazaralor/ChampionHorde.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Conclave of the Chosen

**Evidence:** Loa's Pact, Pa'ku's Aspect, Gift of Wind, Hastening Winds, Pa'ku's Wrath, Gonk's Aspect. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/BattleOfDazaralor/Conclave.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Grong Alliance

**Evidence:** Death Knel, Necrotic Combo, Crushed, Rending Bite, Bestial Throw, Deathly Slam. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/BattleOfDazaralor/GrongAlliance.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, movement, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Grong Horde

**Evidence:** Tantrum, Bestial Combo, Crushed, Rending Bite, Bestial Throw, Reverberating Slam. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/BattleOfDazaralor/GrongHorde.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Jadefire Masters Alliance

**Evidence:** Ma'ra Grimfang, Whirling Jade Storm, Multi-Sided Strike, Spirits of Xuen, Stalking, Anathos Firecaller. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/BattleOfDazaralor/JadefireAlliance.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Jadefire Masters Horde

**Evidence:** Mestrah, the Illuminated, Whirling Jade Storm, Multi-Sided Strike, Spirits of Xuen, Stalking, Manceroy Flamefist. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/BattleOfDazaralor/JadefireHorde.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Lady Jaina Proudmoore

**Evidence:** Chilling Touch, Frozen Solid, Kul Tiran Corsair, Marked Target, Set Charge, Searing Pitch. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/BattleOfDazaralor/Jaina.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### High Tinker Mekkatorque

**Evidence:** Buster Cannon, Blast Off, Gigavolt Charge, Wormhole Generator, Deploy Spark Bot, World Enlarger. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/BattleOfDazaralor/Mekkatorque.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Opulence

**Evidence:** Consuming Flame, The Zandalari Crown Jewels, Topaz of Brilliant Sunlight, Crush, Chaotic Displacement, The Hand of In'zashi. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/BattleOfDazaralor/Opulence.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, movement, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### King Rastakhan

**Evidence:** Scorching Detonation, Plague of Toads, Greater Serpent Totem, Seal of Purification, Meteor Leap, Crushing Leap. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/BattleOfDazaralor/Rastakhan.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement, support, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

## CrucibleOfStorms

### The Restless Cabal

**Evidence:** Relics of Power, Umbral Shell, Abyssal Collapse, Storm of Annihilation, Power Overwhelming, Pact of the Restless. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/CrucibleOfStorms/Cabal.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, movement, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Uu'nat, Harbinger of the Void

**Evidence:** Relics of Power, Umbral Shell, Custody of the Deep, Abyssal Collapse, Storm of Annihilation, Touch of the End. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/CrucibleOfStorms/Uunat.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement, support, routing, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

## EternalPalace

### Abyssal Commander Sivara

**Evidence:** Chimeric Marks, Crushing Reverberation, Frostvenom Tipped, Overwhelming Barrage, Overflow, Frostshock Bolts. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/EternalPalace/AbyssalCommander.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Blackwater Behemoth

**Evidence:** Darkest Depths, Bioluminescent Cloud, Bioluminescence, Gaze from Below, Radiant Biomass, Feeding Frenzy. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/EternalPalace/BlackwaterBehemoth.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Lady Ashvane

**Evidence:** Rippling Wave, Briny Bubble, Upsurge, Barnacle Bash, Cutting Coral, Arcing Azerite. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/EternalPalace/LadyAshvane.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Orgozoa

**Evidence:** Desensitizing Sting, Dribbling Ichor, Incubation Fluid, Arcing Current, Amniotic Splatter, Massive Incubator. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/EternalPalace/Orgozoa.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** movement, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Queen Azshara

**Evidence:** Pressure Surge, Drained Soul, Painful Memories, Longing, Torment, Cursed Heart. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/EternalPalace/QueenAzshara.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, movement, support, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Radiance of Azshara

**Evidence:** Tide Fist, Arcanado Burst, Squall Trap, Arcane Bomb, Unshackled Power, Ancient Tempest. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/EternalPalace/RadianceofAszhara.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, movement, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### The Queen's Court

**Evidence:** Desperate Measures, Separation of Power, Form Rank, Repeat Performance, Stand Alone, Deferred Sentence. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/EternalPalace/TheQueensCourt.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, movement, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Za'qul, Herald of Ny'alotha

**Evidence:** Dark Beyond, Hysteria, Mind Tether, Portal of Madness, Crushing Grasp, Dread. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/EternalPalace/Zaqul.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

## Nyalotha

### Carapace of N'Zoth

**Evidence:** Madness Bomb, Adaptive Membrane, Mandible Slam, Black Scar, Growth-Covered Tentacle, Gaze of Madness. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/Nyalotha/CarapaceofNZoth.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Drest'agath

**Evidence:** Throes of Agony, Void Grip, Volatile Seed, Entropic Crash, Mutterings of Insanity, Void Glare. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/Nyalotha/Drestagath.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### The Hivemind

**Evidence:** Ka'zir's Hivemind Control, Tek'ris's Hivemind Control, Acid Pool, Dark Reconstitution, Ka'zir, Volatile Eruption. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/Nyalotha/Hivemind.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** placement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Il'gynoth, Corruption Reborn

**Evidence:** Eye of N'Zoth, Touch of the Corruptor, Corruptor's Gaze, Nightmare Corruption, Fixate, Cursed Blood. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/Nyalotha/Ilgynoth.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Maut

**Evidence:** Shadow Claws, Dark Offering, Devour Magic, Devoured Abyss, Stygian Annihilation, Dark Manifestation. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/Nyalotha/Maut.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### N'Zoth, the Corruptor

**Evidence:** Gift of N'zoth, Mindwrack, Creeping Anquish, Anguish, Synaptic Shock, Shattered Ego. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/Nyalotha/NZoth.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Ra-den the Despoiled

**Evidence:** Nullifying Strike, Void/Vita Essences (Mythic: +Nightmare), Vita Empowered, Unstable Vita, Call Crackling Stalker, Void Empowered. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/Nyalotha/Raden.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Shad'har the Insatiable

**Evidence:** Debilitating Spit, Fixate, Hungry, Tasty Morsel, Crush and Dissolve, Crush. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/Nyalotha/Shadhar.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### The Prophet Skitra

**Evidence:** Shadow Shock, Shred Psyche, Psychic Outburst, Images of Absolution, Illusionary Projection. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/Nyalotha/Skitra.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Vexiona

**Evidence:** Encroaching Shadows, Shadowy Residue, Twilight Breath, Despair, Annihilation, Dark Gateway. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/Nyalotha/Vexiona.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Wrathion

**Evidence:** Searing Breath, Incineration, Gale Blast, Burning Cataclysm, Burning Madness, Creeping Madness. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/Nyalotha/Wrathion.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Dark Inquisitor Xanesh

**Evidence:** Void Ritual, Voidwoken, Dark Ascension, Abyssal Strike, Soul Flay, Torment. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/Nyalotha/Xanesh.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

## Uldir

### Fetid Devourer

**Evidence:** Thrashing Terror, Rotting Regurgitation, Shockwave Stomp, Malodorous Miasma, Putrid Paroxysm, XXX Used for CL.adds right now. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/Uldir/Devourer.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### G'huun

**Evidence:** Power Matrix, Reorigination Blast, Explosive Corruption, Blighted Ground, Thousand Maws, Torment. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/Uldir/Ghuun.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, movement, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### MOTHER

**Evidence:** Clinging Corruption, Depleted Energy, Cleansing Purge, Sanitizing Strike, Purifying Flame, Wind Tunnel. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/Uldir/Mother.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Mythrax the Unraveler

**Evidence:** Annihilation, Essence Shear, Obliteration Blast, Oblivion Sphere, Imminent Ruin, Essence Shatter. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/Uldir/Mythrax.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Taloc

**Evidence:** Plasma Discharge, Blood Storm, Cudgel of Gore, Retrieve Cudgel, Sanguine Static, Fixate. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/Uldir/Taloc.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, movement, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Vectis

**Evidence:** Omega Vector, Lingering Infection, Evolving Affliction, Contagion, Gestate, Immunosuppression. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/Uldir/Vectis.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Zek'voz, Herald of N'zoth

**Evidence:** Surging Darkness, Void Lash, Shatter, Eye Beam, Qiraji Warrior, Roiling Deceit. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/Uldir/Zekvoz.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Zul

**Evidence:** Fixate, Minion of Zul, Dark Revelation, Pool of Darkness, Thrumming Pulse, Congeal Blood. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BattleForAzeroth/blob/ddb54c9f8bb25c8a23167c0688ee428b33091b31/Uldir/Zul.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.
