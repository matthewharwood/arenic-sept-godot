# WarlordsOfDraenor encounter inventory

This era contains **34 encounter modules** in the pinned corpus. The module author’s encounter observations are source evidence; the candidate-design assessment is an inference for Arenic. This is a breadth screen, not a full tactical guide or a claim that every version of every mechanic was replayed. Preserve variant names: they may distinguish retail, Classic, faction variants, or Season of Discovery.

Source: BigWigs Mods, [BigWigs_WarlordsOfDraenor](https://github.com/BigWigsMods/BigWigs_WarlordsOfDraenor/tree/ad94f51d9c2c44cd4afdc957e4f18f226a462845), revision `ad94f51d9c2c44cd4afdc957e4f18f226a462845`, committed 2026-06-26T16:04:01Z. Full provenance and exclusions: [research contract](README.md).

## BlackrockFoundry

### Blackhand

**Evidence:** Demolition, Molten Slag, Fixate, Blackiron Plating, Explosive Round, Massive Shattering Smash. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WarlordsOfDraenor/blob/ad94f51d9c2c44cd4afdc957e4f18f226a462845/BlackrockFoundry/Blackhand.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Beastlord Darmac

**Evidence:** Rend and Tear, Savage Howl, Seared Flesh, Inferno Breath, Inferno Pyre, Conflagration. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WarlordsOfDraenor/blob/ad94f51d9c2c44cd4afdc957e4f18f226a462845/BlackrockFoundry/Darmac.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Gruul

**Evidence:** Inferno Slice, Overhead Smash, Overwhelming Blows, Petrifying Slam, Destructive Rampage, Cave In. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WarlordsOfDraenor/blob/ad94f51d9c2c44cd4afdc957e4f18f226a462845/BlackrockFoundry/Gruul.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Hans'gar and Franzok

**Evidence:** Smart Stampers, Disrupting Roar, Skullcracker, Crippling Suplex, Shattered Vertebrae, Scorching Burns. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WarlordsOfDraenor/blob/ad94f51d9c2c44cd4afdc957e4f18f226a462845/BlackrockFoundry/HansgarAndFranzok.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Flamebender Ka'graz

**Evidence:** Devastating Slam, Drop the Hammer, Lava Slash, Summon Enchanted Armaments, Molten Torrent, Summon Cinder Wolves. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WarlordsOfDraenor/blob/ad94f51d9c2c44cd4afdc957e4f18f226a462845/BlackrockFoundry/Kagraz.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Kromog

**Evidence:** Rune of Trembling Earth, Call of the Mountain, Warped Armor, Stone Breath, Slam, Rippling Smash. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WarlordsOfDraenor/blob/ad94f51d9c2c44cd4afdc957e4f18f226a462845/BlackrockFoundry/Kromog.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Oregorger

**Evidence:** Acid Torrent, Acid Maw, Retched Blackrock, Explosive Shard, Blackrock Barrage, Rolling Fury. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WarlordsOfDraenor/blob/ad94f51d9c2c44cd4afdc957e4f18f226a462845/BlackrockFoundry/Oregorger.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### The Blast Furnace

**Evidence:** Bellows Operator, Security Guard, Firecaller, Cauterize Wounds, Volatile Fire, Furnace Engineer. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WarlordsOfDraenor/blob/ad94f51d9c2c44cd4afdc957e4f18f226a462845/BlackrockFoundry/TheBlastFurnace.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### The Iron Maidens

**Evidence:** Corrupted Blood, Earthen Barrier, Deadly Throw, Rapid Fire, Penetrating Shot, Deploy Turret. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WarlordsOfDraenor/blob/ad94f51d9c2c44cd4afdc957e4f18f226a462845/BlackrockFoundry/TheIronMaidens.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** support, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Operator Thogar

**Evidence:** Iron Bellow, Cauterizing Bolt, Delayed Siege Bomb (Bombs), Enkindle, Prototype Pulse Grenade (Grenade), Reinforcements. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WarlordsOfDraenor/blob/ad94f51d9c2c44cd4afdc957e4f18f226a462845/BlackrockFoundry/Thogar.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

## Draenor

### Drov the Ruiner

**Evidence:** Colossal Slam, Call of Earth, Acid Breath. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WarlordsOfDraenor/blob/ad94f51d9c2c44cd4afdc957e4f18f226a462845/Draenor/Drov.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Supreme Lord Kazzak

**Evidence:** Fel Breath, Supreme Doom, Mark of Kazzak, Twisted Reflection. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WarlordsOfDraenor/blob/ad94f51d9c2c44cd4afdc957e4f18f226a462845/Draenor/Kazzak.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Rukhmar

**Evidence:** Pierce Armor, Solar Breath, Loose Quills, Fixate. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WarlordsOfDraenor/blob/ad94f51d9c2c44cd4afdc957e4f18f226a462845/Draenor/Rukhmar.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Tarlna the Ageless

**Evidence:** Colossal Blow, Genesis, Grow Untamed Mandragora, Savage Vines, Noxious Spit. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WarlordsOfDraenor/blob/ad94f51d9c2c44cd4afdc957e4f18f226a462845/Draenor/Tarlna.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

## HellfireCitadel

### Archimonde

**Evidence:** P1, Doomfire, Shadowfel Burst, Desecrate, Light of the Naaru, P2. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WarlordsOfDraenor/blob/ad94f51d9c2c44cd4afdc957e4f18f226a462845/HellfireCitadel/Archimonde.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Hellfire High Council

**Evidence:** Mark of the Necromancer, Reap, Nightmare Visage, Wailing Horror, Fel Rage, Bloodboil. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WarlordsOfDraenor/blob/ad94f51d9c2c44cd4afdc957e4f18f226a462845/HellfireCitadel/Council.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Fel Lord Zakuun

**Evidence:** Rumbling Fissures, Soul Cleave, Disembodied, Cavitation, Befouled, Seed of Destruction. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WarlordsOfDraenor/blob/ad94f51d9c2c44cd4afdc957e4f18f226a462845/HellfireCitadel/FelLordZakuun.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Gorefiend

**Evidence:** Touch of Doom, Doom Well, Shared Fate, Feast of Souls, Digest, Shadow of Death. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WarlordsOfDraenor/blob/ad94f51d9c2c44cd4afdc957e4f18f226a462845/HellfireCitadel/Gorefiend.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Hellfire Assault

**Evidence:** Howling Axe, Shockwave, Inspiring Presence, Slam, Cower!, Repair. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WarlordsOfDraenor/blob/ad94f51d9c2c44cd4afdc957e4f18f226a462845/HellfireCitadel/HellfireAssault.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Iron Reaver

**Evidence:** Pounding, Barrage, Unstable Orb, Blitz, Full Charge, Firebomb. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WarlordsOfDraenor/blob/ad94f51d9c2c44cd4afdc957e4f18f226a462845/HellfireCitadel/IronReaver.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Kilrogg Deadeye

**Evidence:** Heart Seeker, Blood Splatter, Vision of Death, Death Throes, Shred Armor, Cleansing Aura. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WarlordsOfDraenor/blob/ad94f51d9c2c44cd4afdc957e4f18f226a462845/HellfireCitadel/KilroggDeadeye.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Kormrok

**Evidence:** Fiery Residue, Foul Residue, Shadow Residue, Foul Crush, Explosive Burst, Swat. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WarlordsOfDraenor/blob/ad94f51d9c2c44cd4afdc957e4f18f226a462845/HellfireCitadel/Kormrok.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Mannoroth

**Evidence:** Shadowforce, Glaive Combo, Massive Blast, Fel Hellstorm, Mannoroth's Gaze, Felseeker. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WarlordsOfDraenor/blob/ad94f51d9c2c44cd4afdc957e4f18f226a462845/HellfireCitadel/Mannoroth.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** support, routing, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Shadow-Lord Iskar

**Evidence:** Fel Chakram, Phantasmal Winds, Phantasmal Wounds, Shadow Riposte, Focused Blast, Fel Bomb. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WarlordsOfDraenor/blob/ad94f51d9c2c44cd4afdc957e4f18f226a462845/HellfireCitadel/ShadowLordIskar.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Socrethar the Eternal

**Evidence:** Reverberating Blow, Shattered Defenses, Volatile Fel Orb, Felblaze Charge, Felblaze Residue, Fel Prison. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WarlordsOfDraenor/blob/ad94f51d9c2c44cd4afdc957e4f18f226a462845/HellfireCitadel/Socrethar.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Tyrant Velhari

**Evidence:** Annihilating Strike, Infernal Tempest, Ancient Enforcer, Enforcer's Onslaught, Tainted Shadows, Font of Corruption. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WarlordsOfDraenor/blob/ad94f51d9c2c44cd4afdc957e4f18f226a462845/HellfireCitadel/TyrantVelhari.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Xhul'horac

**Evidence:** Fel Strike, Fel Surge, Felblaze Flurry, Chains of Fel, Void Strike, Void Surge. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WarlordsOfDraenor/blob/ad94f51d9c2c44cd4afdc957e4f18f226a462845/HellfireCitadel/Xhulhorac.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

## Highmaul

### Brackenspore

**Evidence:** Call of the Tides, Exploding Fungus, Small Adds, Bad Shroom (Reduced casting speed), Big Add, Decay. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WarlordsOfDraenor/blob/ad94f51d9c2c44cd4afdc957e4f18f226a462845/Highmaul/Brackenspore.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Kargath Bladefist

**Evidence:** Ravenous Bloodmaw, On the Hunt, Arena Sweeper, Fire Pillar, Impale, Blade Dance. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WarlordsOfDraenor/blob/ad94f51d9c2c44cd4afdc957e4f18f226a462845/Highmaul/KargathBladefist.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Ko'ragh

**Evidence:** Dominating Power, Expel Magic: Fel, Vulnerability, Caustic Energy, Overwhelming Energy, Suppression Field. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WarlordsOfDraenor/blob/ad94f51d9c2c44cd4afdc957e4f18f226a462845/Highmaul/Koragh.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement, support, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Imperator Mar'gok

**Evidence:** Dark Star, Infinite Darkness, Entropy, Enveloping Night, Glimpse of Madness, Eyes of the Abyss. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WarlordsOfDraenor/blob/ad94f51d9c2c44cd4afdc957e4f18f226a462845/Highmaul/Margok.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement, routing, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Tectus

**Evidence:** Gift of Earth, Petrification, Earthen Flechettes, Raving Assault, Accretion, Crystalline Barrage. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WarlordsOfDraenor/blob/ad94f51d9c2c44cd4afdc957e4f18f226a462845/Highmaul/Tectus.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### The Butcher

**Evidence:** Night-Twisted Cadaver, Pale Vitriol, The Tenderizer, Cleave, Gushing Wounds, Bounding Cleave. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WarlordsOfDraenor/blob/ad94f51d9c2c44cd4afdc957e4f18f226a462845/Highmaul/TheButcher.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Twin Ogron

**Evidence:** Arcane Twisted, Arcane Volatility, Shield Bash, Shield Charge, Interrupting Shout, Pulverize. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_WarlordsOfDraenor/blob/ad94f51d9c2c44cd4afdc957e4f18f226a462845/Highmaul/TwinOgron.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.
