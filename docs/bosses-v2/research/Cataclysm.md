# Cataclysm encounter inventory

This era contains **31 encounter modules** in the pinned corpus. The module author’s encounter observations are source evidence; the candidate-design assessment is an inference for Arenic. This is a breadth screen, not a full tactical guide or a claim that every version of every mechanic was replayed. Preserve variant names: they may distinguish retail, Classic, faction variants, or Season of Discovery.

Source: BigWigs Mods, [BigWigs_Cataclysm](https://github.com/BigWigsMods/BigWigs_Cataclysm/tree/371db88970151039862e72f6ad9b245dc8a63f37), revision `371db88970151039862e72f6ad9b245dc8a63f37`, committed 2026-06-26T16:36:37Z. Full provenance and exclusions: [research contract](README.md).

## Baradin

### Alizabal

**Evidence:** Hate, Skewer, Blade Dance, Blade Dance Over. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Cataclysm/blob/371db88970151039862e72f6ad9b245dc8a63f37/Baradin/Alizabal.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Argaloth

**Evidence:** Meteor Slash, Consuming Darkness, Fel Firestorm, Fel Flames. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Cataclysm/blob/371db88970151039862e72f6ad9b245dc8a63f37/Baradin/Argaloth.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Occu'thar

**Evidence:** Searing Shadows, Eyes, Focused Fire. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Cataclysm/blob/371db88970151039862e72f6ad9b245dc8a63f37/Baradin/Occuthar.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

## Bastion

### Cho'gall

**Evidence:** Blaze, Corrupting Crash, Sickness Check, Fury Of Chogall, Orders, Summon Corrupting Adherent. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Cataclysm/blob/371db88970151039862e72f6ad9b245dc8a63f37/Bastion/Chogall.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Valiona and Theralion

**Evidence:** Blackout, Twilight Meteorite, Deep Breath, Devouring Flames, Engulfing Magic, Dazzling Destruction. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Cataclysm/blob/371db88970151039862e72f6ad9b245dc8a63f37/Bastion/DoubleDragon.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Halfus Wyrmbreaker

**Evidence:** Malevolent Strikes, Paralysis, Scorching Breath, Furious Roar, Fireball Barrage, Shadow Nova. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Cataclysm/blob/371db88970151039862e72f6ad9b245dc8a63f37/Bastion/Halfus.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Sinestra

**Evidence:** Breath, Twilight Slicer, Extinction, Omelet Time, Indomitable. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Cataclysm/blob/371db88970151039862e72f6ad9b245dc8a63f37/Bastion/Sinestra.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Ascendant Council

**Evidence:** Ignacious, Aegis of Flame, Burning Blood, Inferno Rush, Feludius, Glaciate. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Cataclysm/blob/371db88970151039862e72f6ad9b245dc8a63f37/Bastion/TwilightAscendants.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** placement, support, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

## Blackwing

### Atramedes

**Evidence:** Grounded Abilities, Searing Flame, Modulation, Sonar Pulse, Pestered!, Sonic Breath. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Cataclysm/blob/371db88970151039862e72f6ad9b245dc8a63f37/Blackwing/Atramedes.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, movement, support, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Chimaeron

**Evidence:** Massacre, Double Attack, Break, Systems Failure, Caustic Slime. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Cataclysm/blob/371db88970151039862e72f6ad9b245dc8a63f37/Blackwing/Chimaeron.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Magmaw

**Evidence:** Massive Crash, Point of Vulnerability, Pillar of Flame, Parasitic Infection, Lava Spew, Ignition. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Cataclysm/blob/371db88970151039862e72f6ad9b245dc8a63f37/Blackwing/Magmaw.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** placement, movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Maloriak

**Evidence:** Arcane Storm, Remedy, Release Aberrations, Growth Catalyst, Acid Nova, Absolute Zero. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Cataclysm/blob/371db88970151039862e72f6ad9b245dc8a63f37/Blackwing/Maloriak.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Nefarian

**Evidence:** Onyxia, Lightning Discharge, Electrical Overload, Electrocute, Children of Deathwing, Shadowflame Breath. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Cataclysm/blob/371db88970151039862e72f6ad9b245dc8a63f37/Blackwing/Nefarian.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Omnotron Defense System

**Evidence:** Magmatron, Acquiring Target, Incineration Security Measure, Electron, Lightning Conductor, Toxitron. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Cataclysm/blob/371db88970151039862e72f6ad9b245dc8a63f37/Blackwing/Omnotron.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** movement, support, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

## DragonSoul

### Warmaster Blackhorn

**Evidence:** Sapper, Pre Stage2, Stage2, Twilight Flames, Twilight Onslaught, Shockwave. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Cataclysm/blob/371db88970151039862e72f6ad9b245dc8a63f37/DragonSoul/Blackhorn.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Madness of Deathwing

**Evidence:** Impale, Tentacle Killed, Last Phase, Assault Aspects, Elementium Bolt, Cataclysm. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Cataclysm/blob/371db88970151039862e72f6ad9b245dc8a63f37/DragonSoul/DeathwingMadness.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Spine of Deathwing

**Evidence:** About To Roll, Rolls, Level, Absorbed Blood, Fiery Grip Cast, Searing Plasma Cast. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Cataclysm/blob/371db88970151039862e72f6ad9b245dc8a63f37/DragonSoul/DeathwingSpine.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Hagara the Stormbinder

**Evidence:** Assault, Frost Flake Applied, Frost Flake Removed, Water Shield, Frozen Tempest, Feedback. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Cataclysm/blob/371db88970151039862e72f6ad9b245dc8a63f37/DragonSoul/Hagara.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Morchok

**Evidence:** Kohcrom, Summon Kohcrom, Blood Over, Stomp, Furious, Black Blood. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Cataclysm/blob/371db88970151039862e72f6ad9b245dc8a63f37/DragonSoul/Morchok.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** placement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Ultraxion

**Evidence:** Warmup, Gift, Dreams, Magic, Loop, Hourof Twilight. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Cataclysm/blob/371db88970151039862e72f6ad9b245dc8a63f37/DragonSoul/Ultraxion.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Yor'sahj the Unsleeping

**Evidence:** Bolt, Blobs, Acidic Applied, Acidic Removed, Deep Corruption, Acid Pulse. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Cataclysm/blob/371db88970151039862e72f6ad9b245dc8a63f37/DragonSoul/Yorsahj.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Warlord Zon'ozz

**Evidence:** Darkness, Void Diffusion, Psychic Drain, Voidofthe Unmaking, Shadows Cast, Shadows Applied. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Cataclysm/blob/371db88970151039862e72f6ad9b245dc8a63f37/DragonSoul/Zonozz.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

## Firelands

### Alysrazor

**Evidence:** Flight Check, Start Flying, Stop Flying, Initiates, Buff Check, Wound. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Cataclysm/blob/371db88970151039862e72f6ad9b245dc8a63f37/Firelands/Alysrazor.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Baleroc

**Evidence:** Blades, Countdown, Countdown Removed, Shards, Torment. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Cataclysm/blob/371db88970151039862e72f6ad9b245dc8a63f37/Firelands/Baleroc.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Beth'tilac

**Evidence:** Drone Looper, Broodling Watcher, Fixate, Frenzy, Kiss, Devastate. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Cataclysm/blob/371db88970151039862e72f6ad9b245dc8a63f37/Firelands/Bethtilac.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Ragnaros

**Evidence:** Phase4, Dreadflame, Empower Sulfuras, Cloudburst, Entrapping Roots, Breadthof Frost. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Cataclysm/blob/371db88970151039862e72f6ad9b245dc8a63f37/Firelands/Ragnaros.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, support, routing, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Lord Rhyolith

**Evidence:** Heated Volcano, Magma Flow, Obsidian, Obsidian Stack, Spark, Fragments. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Cataclysm/blob/371db88970151039862e72f6ad9b245dc8a63f37/Firelands/Rhyolith.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Shannox

**Evidence:** Hurl Spear, Face Rage, Traps, Immolation Trap Applied, Hurl Spear, Face Rage. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Cataclysm/blob/371db88970151039862e72f6ad9b245dc8a63f37/Firelands/Shannox.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** placement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Majordomo Staghelm

**Evidence:** Searing Seeds (Bomb), Adrenaline, Leaping Flames, Reckless Leap, Cat Form, Scorpion Form. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Cataclysm/blob/371db88970151039862e72f6ad9b245dc8a63f37/Firelands/Staghelm.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

## Throne

### Al'Akir

**Evidence:** Wind Burst, Feedback, Acid Rain, Lightning Rod, Static Shock, Electrocute. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Cataclysm/blob/371db88970151039862e72f6ad9b245dc8a63f37/Throne/Alakir.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Conclave of Wind

**Evidence:** Rohash, Wind Blast, Storm Shield, Nezir, Wind Chill, Permafrost. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Cataclysm/blob/371db88970151039862e72f6ad9b245dc8a63f37/Throne/Conclave.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, movement, support, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.
