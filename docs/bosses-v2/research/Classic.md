# Classic encounter inventory

This era contains **102 encounter modules** in the pinned corpus. The module author’s encounter observations are source evidence; the candidate-design assessment is an inference for Arenic. This is a breadth screen, not a full tactical guide or a claim that every version of every mechanic was replayed. Preserve variant names: they may distinguish retail, Classic, faction variants, or Season of Discovery.

Source: BigWigs Mods, [BigWigs_Classic](https://github.com/BigWigsMods/BigWigs_Classic/tree/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef), revision `2cc8e655144c096c6c0a070ecb0a1dd9157f81ef`, committed 2026-09-03T16:35:31Z. Full provenance and exclusions: [research contract](README.md).

## AQ20

### Ayamiss the Hunter

**Evidence:** Paralyze, Frenzy / Enrage (different name on classic era), Cloud of Disease, Paralyze (Sacrifice), Frenzy / Enrage (20% Health). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/AQ20/Ayamiss.lua).

**Screen:** phase/state branch, actor/target-sensitive observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Buru the Gorger

**Evidence:** Thorns Removed. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/AQ20/Buru.lua).

**Screen:** phase/state branch. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. The source module is an alert model, not the game’s full authoritative simulation.

### Kurinnaxx

**Evidence:** Mortal Wound, Sand Trap, Frenzy / Enrage (different name on classic era), Frenzy / Enrage (30% Health). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/AQ20/Kurinnaxx.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Moam

**Evidence:** Energize, Energize Removed. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/AQ20/Moam.lua).

**Screen:** timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. The source module is an alert model, not the game’s full authoritative simulation.

### Ossirian the Unscarred

**Evidence:** Enveloping Winds, Curse of Tongues, War Stomp, Strength of Ossirian, Weakened, Fire Weakness. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/AQ20/Ossirian.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### General Rajaxx

**Evidence:** Attack Order, Frenzy / Enrage (different name on classic era), Thundercrash, Enlarge, Lightning Cloud, Frenzy / Enrage (30% Health). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/AQ20/Rajaxx.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

## AQ40

### Silithid Royalty

**Evidence:** Great Heal, Fear, Toxic Volley, Toxic Vapors, Fear (Fear). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/AQ40/BugFamily.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### C'Thun

**Evidence:** Dark Glare, Eye Beam, Digestive Acid. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/AQ40/Cthun.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Fankriss the Unyielding

**Evidence:** Mortal Wound, Summon Worm, Entangle. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/AQ40/Fankriss.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Princess Huhuran

**Evidence:** Wyvern Sting, Enrage / Frenzy (different name on classic era), Berserk (30% Health). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/AQ40/Huhuran.lua).

**Screen:** phase/state branch, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. The source module is an alert model, not the game’s full authoritative simulation.

### Ouro

**Evidence:** Sweep, Sand Blast, Berserk, Sweep (Knockback). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/AQ40/Ouro.lua).

**Screen:** phase/state branch, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. The source module is an alert model, not the game’s full authoritative simulation.

### Battleguard Sartura

**Evidence:** Whirlwind, Frenzy / Enrage (different name on classic era), Frenzy / Enrage (25% Health). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/AQ40/Sartura.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### The Prophet Skeram

**Evidence:** True Fulfillment, Teleport, Arcane Explosion, Summon Images, True Fulfillment (Mind Control). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/AQ40/Skeram.lua).

**Screen:** phase/state branch, actor/target-sensitive observation. **Arenic candidate axes:** movement, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### The Twin Emperors

**Evidence:** Heal Brother, Twin Teleport, Mutate Bug, Explode Bug, Blizzard. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/AQ40/Twins.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** support, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Viscidus

**Evidence:** Poison Bolt Volley, Toxin, On Wipe, Poison Bolt Volley, Toxin Damage, Frost Damage. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/AQ40/Viscidus.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

## BlackfathomDeeps_Classic

### Aku'mai Discovery

**Evidence:** Corrosive Blast, Corrosion, Void Blast, Shadow Seep, Corrosive Blast (Breath), Void Blast (Breath). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/BlackfathomDeeps_Classic/Akumai.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Baron Aquanis Discovery

**Evidence:** Depth Charge, Bubble Beam, Torrential Downpour, Depth Charge (Bomb), Bubble Beam (Beam). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/BlackfathomDeeps_Classic/BaronAquanis.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Gelihast Discovery

**Evidence:** Shadow Strike, Curse of Blackfathom, Fear, March of the Murlocs, Curse of Blackfathom (Curse), Fear (Fear). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/BlackfathomDeeps_Classic/Gelihast.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Ghamoo-ra Discovery

**Evidence:** Crunch Armor, Exposed, Triple Chomp, Aqua Shell, Exposed (Weakened). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/BlackfathomDeeps_Classic/Ghamoo-ra.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Lady Sarevess Discovery

**Evidence:** Forked Lightning, Freezing Arrow, Frozen Solid (Fake proxy spell), Aku'mai's Rage. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/BlackfathomDeeps_Classic/LadySarevess.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Lorgus Jett Discovery

**Evidence:** Spawn Murloc, Heal, Corrupted Windfury Totem, Corrupted Lightning Shield Totem, Corrupted Molten Fury Totem. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/BlackfathomDeeps_Classic/LorgusJett.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Twilight Lord Kelris Discovery

**Evidence:** Sleep, Dream Eater, Shadowy Chains, Manifesting Dreams, Dream Eater (You die). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/BlackfathomDeeps_Classic/TwilightLordKelris.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

## BlackwingLair

### Broodlord Lashlayer

**Evidence:** Mortal Strike, Blast Wave, Knock Away. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/BlackwingLair/Broodlord.lua).

**Screen:** phase/state branch, actor/target-sensitive observation. **Arenic candidate axes:** movement, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Chromaggus

**Evidence:** Enrage / Frenzy (different name on classic era), Frenzy / Enrage (different name on classic era), Chromatic Mutation, Brood Affliction: Bronze, Frenzy / Enrage (20% Health), Chromatic Mutation (Mind Control). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/BlackwingLair/Chromaggus.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Ebonroc

**Evidence:** Wing Buffet, Shadow Flame, Shadow of Ebonroc. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/BlackwingLair/Ebonroc.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Firemaw

**Evidence:** Wing Buffet, Shadow Flame, Flame Buffet. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/BlackwingLair/Firemaw.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Flamegor

**Evidence:** Wing Buffet, Shadow Flame, Enrage / Frenzy (different name on classic era). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/BlackwingLair/Flamegor.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Nefarian Classic

**Evidence:** Shadow Command, Shadow Flame, Bellowing Roar, Veil of Shadow, Shadow Command (Mind Control), Bellowing Roar (Fear). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/BlackwingLair/Nefarian.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Razorgore the Untamed

**Evidence:** Dominate Mind, Conflagration, Dominate Mind (Mind Control). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/BlackwingLair/Razorgore.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Vaelastrasz the Corrupt

**Evidence:** Burning Adrenaline, Burning Adrenaline (Bomb), Burning Adrenaline (Tank Bomb). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/BlackwingLair/Vaelastrasz.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

## CrystalVale_Classic

### Thunderaan Season of Discovery

**Evidence:** Chain Lightning, Tendrils of Air, Cyclonic Winds, Lightning Cloud, Heal. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/CrystalVale_Classic/Thunderaan.lua).

**Screen:** actor/target-sensitive observation. **Arenic candidate axes:** movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

## Gnomeregan_Classic

### Crowd Pummeler 9-60 Discovery

**Evidence:** Gnomeregan Smash, The Claw!, Off Balanced, Gnomeregan Smash (Knockback), The Claw! (Charge). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/Gnomeregan_Classic/CrowdPummeler9-60.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Electrocutioner 6000 Discovery

**Evidence:** Magnetic Pulse, Discombobulation Protocol, Static Arc, Discombobulation Protocol (Knockback). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/Gnomeregan_Classic/Electrocutioner6000.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Grubbis Discovery

**Evidence:** Irradiated Cloud, Radiation Sickness, Enrage, Petrify, Trogg Rage, Grubbis Mad!. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/Gnomeregan_Classic/Grubbis.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Mechanical Menagerie Discovery

**Evidence:** High Voltage!, Explosive Egg, Cluck!, Widget Volley, Widget Fortress, Sprocketfire Breath. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/Gnomeregan_Classic/MechanicalMenagerie.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Mekgineer Thermaplugg Discovery

**Evidence:** Summon Bomb, High Voltage!, STX-96/FR, Sprocketfire Punch, Sprocketfire, Furnace Surge. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/Gnomeregan_Classic/MekgineerThermaplugg.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Viscous Fallout Discovery

**Evidence:** Summon Irradiated Goo, Radiation Burn, Sludge, Summon Irradiated Goo (Adds). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/Gnomeregan_Classic/ViscousFallout.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

## MoltenCore

### Baron Geddon

**Evidence:** Living Bomb, Inferno, Armageddon, Ignite Mana, Living Bomb (Bomb), Armageddon (Explosion). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/MoltenCore/BaronGeddon.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Garr

**Evidence:** Antimagic Pulse, Antimagic Pulse, Buff Removed, Buff Dispelled. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/MoltenCore/Garr.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Gehennas

**Evidence:** Gehennas' Curse, Rain of Fire, Gehennas' Curse (Curse). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/MoltenCore/Gehennas.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Golemagg the Incinerator

**Evidence:** Magma Splash, Pyroblast, Magma Splash Applied, Pyroblast Applied, Pyroblast Applied So D, Pyroblast Removed So D. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/MoltenCore/Golemagg.lua).

**Screen:** actor/target-sensitive observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Lucifron

**Evidence:** Impending Doom, Lucifron's Curse, Dominate Mind, Lucifron's Curse (Curse), Dominate Mind (Mind Control). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/MoltenCore/Lucifron.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Magmadar

**Evidence:** Panic, Enrage / Frenzy (different name on classic era), Conflagration, Panic (Fear), Conflagration (Fire under YOU). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/MoltenCore/Magmadar.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Majordomo Executus

**Evidence:** Magic Reflection, Damage Shield, Teleport, Magic Reflection (Spell Reflection). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/MoltenCore/Majordomo.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** support, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Ragnaros Classic

**Evidence:** Wrath of Ragnaros, Wrath of Ragnaros (Knockback), Ragnaros Submerge Visual, Wrath Of Ragnaros, Summon Ragnaros Start, Big Wigs_Boss Comm. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/MoltenCore/Ragnaros.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Shazzrah

**Evidence:** Magic Grounding / Deaden Magic (different name on classic era), Gate of Shazzrah, Counterspell, Shazzrah's Curse, Gate of Shazzrah (Teleport), Counterspell (Frontal Cone). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/MoltenCore/Shazzrah.lua).

**Screen:** timer/cadence observation. **Arenic candidate axes:** placement, support, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. The source module is an alert model, not the game’s full authoritative simulation.

### Sulfuron Harbinger

**Evidence:** Inspire, Dark Mending, Demoralizing Shout. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/MoltenCore/Sulfuron.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### The Molten Core

**Evidence:** Heart of Ash, Heart of Cinder, Harmonic Tremor, Doomsday, Meteor, Heart of Ash (Link 1). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/MoltenCore/TheMoltenCore.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

## Naxxramas_Classic

### Anub'Rekhan

**Evidence:** Impale, Locust Swarm, Locust Swarm, Locust Swarm Applied, Locust Swarm Removed. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/Naxxramas_Classic/Anubrekhan.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Grand Widow Faerlina

**Evidence:** Widow's Embrace, Enrage, Rain of Fire, Silence, Poison Bolt Volley. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/Naxxramas_Classic/Faerlina.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Gluth

**Evidence:** Frenzy, Terrifying Roar, Mortal Wound, Infected Wound, Decimate, Terrifying Roar (Fear). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/Naxxramas_Classic/Gluth.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Gothik the Harvester

**Evidence:** Harvest Soul, Unrelenting Death Knight Dies, Unrelenting Rider Dies, New Trainee, New Death Knight, New Rider. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/Naxxramas_Classic/Gothik.lua).

**Screen:** phase/state branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Grobbulus

**Evidence:** Mutating Injection, Poison Cloud, Mutating Injection (Injection). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/Naxxramas_Classic/Grobbulus.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Heigan the Unclean

**Evidence:** Decrepit Fever, Decrepit Fever (Disease), Decrepit Fever, Decrepit Fever Applied, Decrepit Fever Removed. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/Naxxramas_Classic/Heigan.lua).

**Screen:** phase/state branch, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. The source module is an alert model, not the game’s full authoritative simulation.

### The Four Horsemen

**Evidence:** Meteor (Thane Korth'azz), Void Zone (Lady Blaumeux), Holy Wrath (Sir Zeliek), Shield Wall. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/Naxxramas_Classic/Horsemen.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Kel'Thuzad

**Evidence:** Mortal Wound, Frost Blast, Shadow Fissure, Chains of Kel'Thuzad, Detonate Mana, Chains of Kel'Thuzad (Mind Control). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/Naxxramas_Classic/Kelthuzad.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Loatheb

**Evidence:** Poison Aura, Inevitable Doom, Remove Curse, Summon Spore, Corrupted Mind, Fungal Bloom. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/Naxxramas_Classic/Loatheb.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Maexxna

**Evidence:** Web Wrap, Web Spray, Necrotic Poison, Enrage, Enrage (30% Health). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/Naxxramas_Classic/Maexxna.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Noth the Plaguebringer

**Evidence:** Cripple, Curse of the Plaguebringer, Wrath of the Plaguebringer, Blink, Curse of the Plaguebringer (Curse), Wrath of the Plaguebringer (Explosion). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/Naxxramas_Classic/Noth.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** support, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Patchwerk

**Evidence:** Enrage, Enrage (5% Health). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/Naxxramas_Classic/Patchwerk.lua).

**Screen:** No screened branch token; this is not proof of fixed choreography.. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. The source module is an alert model, not the game’s full authoritative simulation.

### Instructor Razuvious

**Evidence:** Disrupting Shout, Taunt, Shield Wall, Mind Exhaustion. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/Naxxramas_Classic/Razuvious.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Sapphiron

**Evidence:** Life Drain, Ice Bolt, Frost Breath, Chill, Life Drain (Curse), Chill (Blizzard). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/Naxxramas_Classic/Sapphiron.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Thaddius

**Evidence:** Magnetic Pull, Power Surge, Polarity Shift, Negative Charge, Positive Charge, Extras. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/Naxxramas_Classic/Thaddius.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

## NightmareGrove_Classic

### Emeriss Season of Discovery

**Evidence:** Volatile Infection, Corruption of the Earth, Spore Cloud, Shared, Noxious Breath, Seeping Fog. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/NightmareGrove_Classic/Emeriss.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Lethon Season of Discovery

**Evidence:** Shadow Bolt Whirl, Draw Spirit, Shared, Noxious Breath, Seeping Fog, Noxious Breath (Breath). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/NightmareGrove_Classic/Lethon.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Taerar Season of Discovery

**Evidence:** Bellowing Roar, Summon Shade of Taerar, Shared, Noxious Breath, Seeping Fog, Bellowing Roar (Fear). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/NightmareGrove_Classic/Taerar.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Ysondre Season of Discovery

**Evidence:** Summon Demented Druid Spirit, Divergent Lightning, Shared, Noxious Breath, Seeping Fog, Summon Demented Druid Spirit (Adds). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/NightmareGrove_Classic/Ysondre.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

## Onyxia_Classic

### Onyxia

**Evidence:** Flame Breath, Fireball, Breath, Bellowing Roar, Flame Lash, Flame Breath (Frontal Cone). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/Onyxia_Classic/Onyxia.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

## ScarletEnclave_Classic

### Alexei the Beastlord

**Evidence:** Wild Aperture, Stomp, Enervate, Enkindle, Immolation Trap, Wild Aperture (Frontal Cone). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/ScarletEnclave_Classic/Alexei.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Balnazzar Scarlet Enclave

**Evidence:** Balnazzar, Carrion Swarm, Circle of Domination, Summon Infernal, Screeching Terror, Screeching Fear. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/ScarletEnclave_Classic/Balnazzar.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### High Commander Beatrix

**Evidence:** Explosive Shell, Rose's Thorn, Confession, Unwavering Blade, Stock Break, Explosive Shell (Fire under YOU). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/ScarletEnclave_Classic/Beatrix.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Grand Crusader Caldoran

**Evidence:** Blinding Flare, Wake of Ashes, Devoted Offering, Divine Conflagration, Execution Sentence, Cessation. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/ScarletEnclave_Classic/Caldoran.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Lillian Voss

**Evidence:** Scarlet Grasp, Debilitate, Noxious Poison, Unstable Concoction, Intoxicating Venom, Ignite. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/ScarletEnclave_Classic/LillianVoss.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Mason the Echo

**Evidence:** Drowning Shallows, Tidal Force, Ignite Flesh, Mortal Wound, Drowning Shallows (Curse), Tidal Force (Shield). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/ScarletEnclave_Classic/Mason.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Reborn Council

**Evidence:** Peeled Secrets, Molten Basin, Blades of Light, Divine Avatar, Blades of Light (Whirlwind). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/ScarletEnclave_Classic/RebornCouncil.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Solistrasza

**Evidence:** Tarnished Breath, Hallowed Dive, Cremation, Crimson Flare, Tarnished Breath (Breath), Crimson Flare (Beam). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/ScarletEnclave_Classic/Solistrasza.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

## StormCliffs_Classic

### Azuregos Season of Discovery

**Evidence:** Reflection, Arcane Vacuum, Frost Breath, Manastorm, Arcane Vacuum (Teleport), Frost Breath (Interruptible). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/StormCliffs_Classic/Azuregos.lua).

**Screen:** timer/cadence observation. **Arenic candidate axes:** movement, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. The source module is an alert model, not the game’s full authoritative simulation.

## SunkenTemple_Classic

### Atal'ai Defenders Discovery

**Evidence:** Zul'Lor, Corrupted Slam, Frailty, Mijan, Thorns, Renew. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/SunkenTemple_Classic/AtalaiDefenders.lua).

**Screen:** phase/state branch. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. The source module is an alert model, not the game’s full authoritative simulation.

### Atal'alarion Discovery

**Evidence:** Demolishing Smash, Pillars of Might, Demolishing Smash (Knockback). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/SunkenTemple_Classic/Atalalarion.lua).

**Screen:** timer/cadence observation. **Arenic candidate axes:** placement, movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. The source module is an alert model, not the game’s full authoritative simulation.

### Avatar of Hakkar Discovery

**Evidence:** Frightsome Howl, Bubbling Blood, Insanity, Curse of Tongues, Corrupted Blood, Drain Blood. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/SunkenTemple_Classic/AvatarOfHakkar.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Dreamscythe and Weaver Discovery

**Evidence:** Acid Breath, Wing Buffet, Caustic Overflow, Wing Buffet (Knockback). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/SunkenTemple_Classic/DreamscytheAndWeaver.lua).

**Screen:** phase/state branch, actor/target-sensitive observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Festering Rotslime Discovery

**Evidence:** Gunk, Nauseous Gas, Gunk (Disease). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/SunkenTemple_Classic/FesteringRotslime.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Jammal'an and Ogom Discovery

**Evidence:** Holy Nova, Holy Fire, Agonizing Weakness, Mortal Lash, Shadow Sermon: Pain, Mass Penance. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/SunkenTemple_Classic/JammalanAndOgom.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** support, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Morphaz and Hazzas Discovery

**Evidence:** Backfire, Dreamer's Lament, Lucid Dreaming, Corrupted Breath, Animate Flame, Backfire (Knockback). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/SunkenTemple_Classic/MorphazAndHazzas.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Shade of Eranikus Discovery

**Evidence:** Corrosive Breath, Bellowing Roar, Deep Slumber (Clouds), Deep Slumber (Player), Lethargic Poison, Waking Nightmare. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/SunkenTemple_Classic/ShadeOfEranikus.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

## TheTaintedScar_Classic

### Lord Kazzak Season of Discovery

**Evidence:** Mark of Kazzak, Twisted Reflection, Mark of Kazzak (Curse). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/TheTaintedScar_Classic/Kazzak.lua).

**Screen:** actor/target-sensitive observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

## World_Classic

### Azuregos

**Evidence:** Reflection, Arcane Vacuum, Frost Breath, Manastorm, Arcane Vacuum (Teleport), Frost Breath (Interruptible). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/World_Classic/Azuregos.lua).

**Screen:** death/stage event, timer/cadence observation. **Arenic candidate axes:** movement, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Emeriss

**Evidence:** Volatile Infection, Corruption of the Earth, Spore Cloud, Shared, Noxious Breath, Seeping Fog. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/World_Classic/Emeriss.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Lord Kazzak

**Evidence:** Mark of Kazzak, Twisted Reflection, Mark of Kazzak (Curse). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/World_Classic/Kazzak.lua).

**Screen:** actor/target-sensitive observation, death/stage event. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Lethon

**Evidence:** Shadow Bolt Whirl, Draw Spirit, Shared, Noxious Breath, Seeping Fog, Noxious Breath (Breath). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/World_Classic/Lethon.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Taerar

**Evidence:** Bellowing Roar, Summon Shade of Taerar, Shared, Noxious Breath, Seeping Fog, Bellowing Roar (Fear). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/World_Classic/Taerar.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Ysondre

**Evidence:** Summon Demented Druid Spirit, Shared, Noxious Breath, Seeping Fog, Summon Demented Druid Spirit (Adds), Noxious Breath (Breath). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/World_Classic/Ysondre.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

## ZulGurub_Classic

### High Priestess Arlokk

**Evidence:** Gouge, Mark of Arlokk, Shadow Word: Pain. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/ZulGurub_Classic/Arlokk.lua).

**Screen:** actor/target-sensitive observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Edge of Madness

**Evidence:** Avatar (Gri'lek), Summon Nightmare Illusions (Hazza'rah), Vanish (Renataki), Lightning Cloud (Wushoolay). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/ZulGurub_Classic/EdgeOfMadness.lua).

**Screen:** No screened branch token; this is not proof of fixed choreography.. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. The source module is an alert model, not the game’s full authoritative simulation.

### Gahz'ranka

**Evidence:** Frost Breath, Massive Geyser, Frost Breath, Massive Geyser. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/ZulGurub_Classic/Gahzranka.lua).

**Screen:** No screened branch token; this is not proof of fixed choreography.. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. The source module is an alert model, not the game’s full authoritative simulation.

### Hakkar

**Evidence:** Blood Siphon, Cause Insanity, Cause Insanity (Mind Control). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/ZulGurub_Classic/Hakkar.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### High Priestess Jeklik

**Evidence:** Pierce Armor, Great Heal, Mind Flay, Curse of Blood, Throw Liquid Fire, Shadow Word: Pain. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/ZulGurub_Classic/Jeklik.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Jin'do the Hexxer

**Evidence:** Delusions of Jin'do, Hex, Summon Brain Wash Totem, Powerful Healing Ward, Banish, Summon Brain Wash Totem (Totem). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/ZulGurub_Classic/Jindo.lua).

**Screen:** actor/target-sensitive observation. **Arenic candidate axes:** support, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Bloodlord Mandokir

**Evidence:** Mortal Strike, Threatening Gaze, Enrage. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/ZulGurub_Classic/Mandokir.lua).

**Screen:** actor/target-sensitive observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### High Priestess Mar'li

**Evidence:** Hatch Eggs, Drain Life, Poison Bolt Volley. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/ZulGurub_Classic/Marli.lua).

**Screen:** actor/target-sensitive observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### High Priest Thekal

**Evidence:** Thekal, Mortal Cleave, Silence, Lor'Khan, Great Heal, Bloodlust. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/ZulGurub_Classic/Thekal.lua).

**Screen:** actor/target-sensitive observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### High Priest Venoxis

**Evidence:** Renew, Holy Fire, Poison Cloud, Parasitic Serpent, Enrage. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Classic/blob/2cc8e655144c096c6c0a070ecb0a1dd9157f81ef/ZulGurub_Classic/Venoxis.lua).

**Screen:** phase/state branch, actor/target-sensitive observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.
