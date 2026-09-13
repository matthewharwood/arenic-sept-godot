# WrathOfTheLichKing encounter inventory

This era contains **54 encounter modules** in the pinned corpus. The module author’s encounter observations are source evidence; the candidate-design assessment is an inference for Arenic. This is a breadth screen, not a full tactical guide or a claim that every version of every mechanic was replayed. Preserve variant names: they may distinguish retail, Classic, faction variants, or Season of Discovery.

Source: BigWigs Mods, [BigWigs_WrathOfTheLichKing](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/tree/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd), revision `b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd`, committed 2026-08-10T20:10:51Z. Full provenance and exclusions: [research contract](README.md).

## Citadel

### Blood Prince Council

**Evidence:** Bomb, Shadow Prison, Switch, Empowered Shock, Regular Shock, Empowered Flame. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Citadel/BloodCouncil.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Lady Deathwhisper

**Evidence:** Adds, Dark Transformation, Dark Empowerment, Curse of Torpor, Touch of Insignificance, Summon Spirit. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Citadel/Deathwhisper.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** support, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Festergut

**Evidence:** Spores, Inhale CD, Blight, Bloat, Vile Gas. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Citadel/Festergut.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Icecrown Gunship Battle

**Evidence:** Wounding Strike, Battle Fury, Mage Killed, Below Zero Removed, Wounding Strike Applied, Battle Fury Applied. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Citadel/Gunship.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Blood-Queen Lana'thel

**Evidence:** Pact, Shadows, Feed, Air Phase, Ground Phase, Slash. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Citadel/Lanathel.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### The Lich King

**Evidence:** Warmup, Plague Tick, Frenzy, Horror, Furyof Frostmourne, Infest. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Citadel/LichKing.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Lord Marrowgar

**Evidence:** Bone Storm, Bone Spike Graveyard, Coldflame, Bone Spike Graveyard (Impale). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Citadel/Marrowgar.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Professor Putricide

**Evidence:** Volatile Experiment, Tear Gas Start, Tear Gas Over, Plague, Chased By Red Ooze, Red Ooze Death. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Citadel/Putricide.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** support, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Rotface

**Evidence:** Infection, Infection Removed, Slime Spray, Explode, Ooze, Vile Gas. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Citadel/Rotface.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Deathbringer Saurfang

**Evidence:** Rune of Blood, Boiling Blood, Mark of the Fallen Champion, Frenzy, Adds (Blood Beast), Mark of the Fallen Champion (Mark). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Citadel/Saurfang.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Sindragosa

**Evidence:** Mystic Buffet, Unchained Magic, Instability, Chilled to the Bone, Blistering Cold, Frost Beacon. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Citadel/Sindragosa.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Valithria Dreamwalker

**Evidence:** Lay Waste, Lay Waste Removed, Portal, Mana Void. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Citadel/Valithria.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

## Coliseum

### Anub'arak

**Evidence:** Freezing Slash, Pursued by Anub'arak, Penetrating Cold, Leeching Swarm, Shadow Strike, Pursued by Anub'arak (Fixate). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Coliseum/Anubarak.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### The Beasts of Northrend

**Evidence:** Snobold (Add), Snobolled, Impale, Staggering Stomp, Fire Bomb, Jormungars. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Coliseum/Beasts.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Faction Champions

**Evidence:** Hellfire, Hellfire Stopped, Hellfire On You, Wyvern, Blind, Polymorph. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Coliseum/Champions.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Lord Jaraxxus

**Evidence:** Incinerate Flesh, Incinerate Flesh Removed, Legion Flame, Nether Power, Nether Portal, Infernal Eruption. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Coliseum/Jaraxxus.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** routing, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### The Twin Val'kyr

**Evidence:** Touch, Dark Shield, Light Shield, Light Vortex, Dark Vortex. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Coliseum/ValkyrTwins.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

## Naxxramas

### Anub'Rekhan

**Evidence:** Impale, Locust Swarm, Crypt Guard (Big Add), Locust Swarm (Locust). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Naxxramas/Anubrekhan.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Grand Widow Faerlina

**Evidence:** Widow's Embrace, Rain of Fire, Frenzy. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Naxxramas/Faerlina.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Gluth

**Evidence:** Enrage, Mortal Wound, Infected Wound, Decimate. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Naxxramas/Gluth.lua).

**Screen:** actor/target-sensitive observation, difficulty branch. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Gothik the Harvester

**Evidence:** Death Knight Death, Rider Death, Phase2, New Trainee, New Death Knight, New Rider. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Naxxramas/Gothik.lua).

**Screen:** phase/state branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Grobbulus

**Evidence:** Mutating Injection, Poison Cloud, Mutating Injection (Injection). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Naxxramas/Grobbulus.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Heigan the Unclean

**Evidence:** Decrepit Fever, Decrepit Fever (Disease), Decrepit Fever, Decrepit Fever Applied, Decrepit Fever Removed. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Naxxramas/Heigan.lua).

**Screen:** phase/state branch, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. The source module is an alert model, not the game’s full authoritative simulation.

### The Four Horsemen

**Evidence:** Unholy Shadow (Rivendare), Meteor (Korth'azz), Void Zone (Blaumeux), Holy Wrath (Zeliek). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Naxxramas/Horsemen.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Kel'Thuzad Naxxramas

**Evidence:** Frost Blast, Shadow Fissure, Chains of Kel'Thuzad, Detonate Mana. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Naxxramas/Kelthuzad.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Loatheb

**Evidence:** Necrotic Aura, Deathbloom, Inevitable Doom, Summon Spore. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Naxxramas/Loatheb.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** placement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Maexxna

**Evidence:** Poison Shock, Necrotic Poison, Web Spray, Frenzy, Web Wrap (Cocoons). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Naxxramas/Maexxna.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Noth the Plaguebringer

**Evidence:** Cripple, Curse of the Plaguebringer, Wrath of the Plaguebringer, Blink, Curse of the Plaguebringer (Curse), Wrath of the Plaguebringer (Explosion). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Naxxramas/Noth.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** support, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Patchwerk

**Evidence:** Frenzy, Frenzy (5% Health). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Naxxramas/Patchwerk.lua).

**Screen:** No screened branch token; this is not proof of fixed choreography.. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. The source module is an alert model, not the game’s full authoritative simulation.

### Instructor Razuvious

**Evidence:** Disrupting Shout, Jagged Knife, Taunt, Bone Barrier, Mind Exhaustion. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Naxxramas/Razuvious.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Sapphiron

**Evidence:** Life Drain, Frost Breath, Ice Bolt, Frost Breath (Ice Bomb), Ice Bolt (Ice Block). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Naxxramas/Sapphiron.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Thaddius

**Evidence:** Magnetic Pull, Power Surge, Polarity Shift, Negative Charge, Positive Charge, Extras. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Naxxramas/Thaddius.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

## Northrend

### Archavon the Stone Watcher

**Evidence:** Stomp, Cloud, Shards. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Northrend/Archavon.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Emalon the Storm Watcher

**Evidence:** Nova, Overcharge, Overcharge Icon. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Northrend/Emalon.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Koralon the Flame Watcher

**Evidence:** Fists, Cinder, Breath. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Northrend/Koralon.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Malygos

**Evidence:** Spark, Static, Vortex, Phase2, P2End, Phase3. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Northrend/Malygos.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Onyxia

**Evidence:** Flame Breath, Fireball, Breath, Bellowing Roar, Flame Breath (Frontal Cone), Breath (Deep Breath). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Northrend/Onyxia.lua).

**Screen:** phase/state branch, actor/target-sensitive observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Sartharion

**Evidence:** Flame Tsunami, Flame Breath, Shadow Fissure, Shadow Breath, Molten Fury, Hatch Eggs. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Northrend/Sartharion.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, movement, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Toravon the Ice Watcher

**Evidence:** Whiteout, Orbs, Frostbite, Freeze. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Northrend/Toravon.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

## RubySanctum

### Halion

**Evidence:** Fiery Combustion, Combustion, Meteor Strike, Flame Breath, Soul Consumption, Consumption. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/RubySanctum/Halion.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

## Ulduar

### Algalon the Observer

**Evidence:** Cosmic Smash, Black Hole Explosion, Big Bang. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Ulduar/Algalon.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Auriaya

**Evidence:** Terrifying Screech, Sentinel Blast, Guardian Swarm, Sonic Screech. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Ulduar/Auriaya.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Freya

**Evidence:** Nature's Fury, Sunbeam, Iron Roots, Ground Tremor, Unstable Energy. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Ulduar/Freya.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Hodir

**Evidence:** Biting Cold, Storm Cloud, Flash Freeze, Frozen Blows. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Ulduar/Hodir.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Ignis the Furnace Master

**Evidence:** Activate Construct, Brittle, Flame Jets, Scorch, Slag Pot. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Ulduar/Ignis.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### The Iron Council

**Evidence:** Overload, Lightning Whirl, Lightning Tendrils, Fusion Punch, Overwhelming Power, Shield of Runes. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Ulduar/IronCouncil.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement, support, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Kologarn

**Evidence:** Stone Grip, Arm Sweep (Shockwave), Crunch Armor. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Ulduar/Kologarn.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Flame Leviathan

**Evidence:** Blue Pyrite, Flame Vents, Pursued, Systems Shutdown. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Ulduar/Leviathan.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Mimiron

**Evidence:** Plasma Blast, Shock Blast, P3Wx2 Laser Barrage, Magnetic Core, Bomb Bot, Frost Bomb. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Ulduar/Mimiron.lua).

**Screen:** phase/state branch, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. The source module is an alert model, not the game’s full authoritative simulation.

### Razorscale

**Evidence:** Flame Breath, Devouring Flame, Harpooned, Fuse Armor. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Ulduar/Razorscale.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Thorim

**Evidence:** Stormhammer, Charge Orb, Impale, Lightning Shock, Runic Barrier, Rune Detonation. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Ulduar/Thorim.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### General Vezax

**Evidence:** Shadow Crash, Mark of the Faceless, Searing Flames, Surge of Darkness. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Ulduar/Vezax.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### XT-002 Deconstructor

**Evidence:** Gravity Bomb, Searing Light, Tympanic Tantrum, Heartbreak, Exposed Heart. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Ulduar/XT-002.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Yogg-Saron

**Evidence:** Summon Guardian, Sara's Fervor, Malady of the Mind, Brain Link, Squeeze, Induce Madness. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WrathOfTheLichKing/blob/b4ddf4eb00b06f7eb5546a5f30c5a488d02a12dd/Ulduar/YoggSaron.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.
