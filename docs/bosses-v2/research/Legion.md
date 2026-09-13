# Legion encounter inventory

This era contains **59 encounter modules** in the pinned corpus. The module author’s encounter observations are source evidence; the candidate-design assessment is an inference for Arenic. This is a breadth screen, not a full tactical guide or a claim that every version of every mechanic was replayed. Preserve variant names: they may distinguish retail, Classic, faction variants, or Season of Discovery.

Source: BigWigs Mods, [BigWigs_Legion](https://github.com/BigWigsMods/BigWigs_Legion/tree/bbc48372f2b4483f1573175de20fd7b805785bc9), revision `bbc48372f2b4483f1573175de20fd7b805785bc9`, committed 2026-06-26T16:14:51Z. Full provenance and exclusions: [research contract](README.md).

## Antorus

### Aggramar

**Evidence:** Wrought in Flame, Taeshalach's Reach, Scorching Blaze, Wake of Flame, Taeshalach Technique, Foe Breaker. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/Antorus/Aggramar.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Argus the Unmaker

**Evidence:** Cone of Death, Soulblight Orb, Soul Blight, Death Fog, Tortured Rage, Sweeping Scythe. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/Antorus/Argus.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, movement, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### The Coven of Shivarra

**Evidence:** Shivan Pact, Fiery Strike, Whirling Saber, Fulminating Pulse, Shadow Blades, Storm of Darkness. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/Antorus/CovenofShivarra.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Eonar the Life-Binder

**Evidence:** Life Force, Spear of Doom, Rain of Fel, Final Doom, Purge, Arcane Buildup. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/Antorus/Eonar.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Felhounds of Sargeras

**Evidence:** Burning Maw, Molten Touch, Desolate Gaze, Enflame Corruption, Enflamed, Corrupting Maw. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/Antorus/Felhounds.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Portal Keeper Hasabel

**Evidence:** Reality Tear, Collapsing World, Felstorm Barrage, Transport Portal, Howling Shadows, Catastrophic Implosion. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/Antorus/Hasabel.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement, support, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Antoran High Command

**Evidence:** Fusillade, Entropic Mine, Summon Reinforcements, Bladestorm, Pyroblast, Assume Command. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/Antorus/HighCommand.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Imonar the Soulhunter

**Evidence:** Shock Lance, Sleep Canister, Pulse Grenade, Sever, Charged Blasts, Shrapnel Blast. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/Antorus/Imonar.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Kin'garoth

**Evidence:** Forging Strike, Reverberating Strike, Diabolic Bomb, Ruiner, Shattering Strike, Apocalypse Protocol. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/Antorus/Kingaroth.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Varimathras

**Evidence:** Torment of Flames, Frost, Fel, Shadows, Misery, Shadow Strike, Dark Fissure, Marked Prey, Necrotic Embrace. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/Antorus/Varimathras.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** placement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

## ArgusInvasionPoints

### Mistress Alluradel

**Evidence:** Beguiling Charm, Fel Lash, Heart Breaker, Sadist. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/ArgusInvasionPoints/Alluradel.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Matron Folnuna

**Evidence:** Infected Claws, Slumbering Gasp, Fel Blast, Grotesque Spawn. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/ArgusInvasionPoints/Folnuna.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Inquisitor Meto

**Evidence:** Reap, Sow, Seed of Chaos, Death Field. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/ArgusInvasionPoints/Meto.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Occularus

**Evidence:** Gushing Wound, Lash, Searing Gaze, Phantasm, Eye Sore. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/ArgusInvasionPoints/Occularus.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Sothanar

**Evidence:** Silence, Soul Cleave, Cavitation, Seed of Destruction. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/ArgusInvasionPoints/Sotanathor.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Pit Lord Vilemus

**Evidence:** Drain, Stomp, Fel Breath. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/ArgusInvasionPoints/Vilemus.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

## BrokenIsles

### Apocron

**Evidence:** Quake, Felfire Missiles, Sear. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/BrokenIsles/Apocron.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Brutallus

**Evidence:** Meteor Slash, Rupture, Crashing Embers. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/BrokenIsles/Brutallus.lua).

**Screen:** death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Calamir

**Evidence:** Burning Bomb, Wrathful Flames, Howling Gale, Icy Comet, Arcane Desolation, Arcanopulse. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/BrokenIsles/Calamir.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Drugon the Frostblood

**Evidence:** Ice Hurl, Snow Crash, Avalanche, Snow Plow. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/BrokenIsles/Drugon.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Flotsam

**Evidence:** Jetsam, Breaksam, Getsam, Yaksam. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/BrokenIsles/Flotsam.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Humongris

**Evidence:** Fire Boom, Earthshake Stomp, Ice Fist, Make the Snow, You Go Bang!, Blizzard. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/BrokenIsles/Humongris.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Levantus

**Evidence:** Massive Spout, Electrify, Rending Whirl, Gust of Wind. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/BrokenIsles/Levantus.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Malificus

**Evidence:** Pestilence, Incite Panic, Shadow Barrage, Virulent Infection. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/BrokenIsles/Malificus.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Na'zak the Fiend

**Evidence:** Corroding Spray, Foundational Collapse, Absorb Leystones, Web Wrap. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/BrokenIsles/Nazak.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Nithogg

**Evidence:** Crackling Jolt, Tail Lash, Electrical Storm, Storm Breath, Static Charge. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/BrokenIsles/Nithogg.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Shar'thos

**Evidence:** Cry of the Tormented, Burning Earth, Dread Flame, Nightmare Breath, Tail Lash. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/BrokenIsles/Sharthos.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Si'vash

**Evidence:** Tidal Wave, Submerge, Summon Honor Guard. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/BrokenIsles/Sivash.lua).

**Screen:** death/stage event, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### The Soultakers

**Evidence:** Expel Soul, Soul Rend, Marauding Mists, Seadog's Scuttle, Tentacle Bash, Shatter Crewmen. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/BrokenIsles/TheSoultakers.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Withered J'im

**Evidence:** More... MORE MORE MORE!, Nightshifted Bolts, Resonance. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/BrokenIsles/WitheredJim.lua).

**Screen:** death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

## Nighthold

### Spellblade Aluriel

**Evidence:** Annihilate, Pre Mark of Frost, Mark of Frost, Frostbitten, Replicate: Mark of Frost, Detonate: Mark of Frost. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/Nighthold/Aluriel.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, movement, routing, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Chronomatic Anomaly

**Evidence:** Speed: Slow / Normal / Fast, Chronometric Particles, Time Release, Time Bomb, Temporal Orb, Vortex (standing in stuff). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/Nighthold/ChronomaticAnomaly.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Grand Magistrix Elisande

**Evidence:** Terminate (Berserk), Recursion, Blast, Slow Time, Expedite, Fast Time. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/Nighthold/Elisande.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Star Augur Etraeus

**Evidence:** Nether Traversal, Coronal Ejection, Gravitational Pull, Chilled, Icy Ejection, Frigid Nova. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/Nighthold/Etraeus.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Gul'dan

**Evidence:** Time Dilation, Scattering Field, Resonant Barrier, Liquid Hellfire, Fel Efflux, Hand of Gul'dan. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/Nighthold/Guldan.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, movement, support, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Krosus

**Evidence:** Searing Brand, Fel Beam, Orb of Destruction, Slam, Burning Pitch, Isolated Rage. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/Nighthold/Krosus.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Skorpyron

**Evidence:** Arcanoslash, Shockwave, Chitinous Exoskeleton, Exoskeletal Vulnerability, Call of the Scorpid, Focused Blast. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/Nighthold/Skorpyron.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### High Botanist Tel'arn

**Evidence:** Call of Night, Recursive Strikes, Controlled Chaos, Solar Collapse, Summon Plasma Spheres, Toxic Spores. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/Nighthold/Telarn.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Tichondrius

**Evidence:** Carrion Plague, Seeker Swarm, Brand of Argus, Feast of Blood, Echoes of the Void, Illusionary Night. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/Nighthold/Tichondrius.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Trilliax

**Evidence:** Arcane Seepage, Arcane Slash, Cleaner, Toxic Slice, Sterilize, Cleansing Rage. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/Nighthold/Trilliax.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

## Nightmare

### Cenarius

**Evidence:** Creeping Nightmares, Nightmare Brambles, Forces of Nightmare, Dread Thorns, P2, Entangling Nightmares. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/Nightmare/Cenarius.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Dragons of Nightmare

**Evidence:** Corrupted Breath, Marks, Call Defiled Spirit, Defiled Vines, Nightmare Blast, Volatile Infection. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/Nightmare/Dragons.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Elerethe Renferal

**Evidence:** Web of Pain, Feeding Time, Vile Ambush, Necrotic Venom, Gathering Clouds, Dark Storm. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/Nightmare/EleretheRenferal.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Il'gynoth

**Evidence:** Final Torpor, Nightmare Corruption, Dominator Tentacle, Ground Slam, Nightmarish Fury, Nightmare Ichor. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/Nightmare/Ilgynoth.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Nythendra

**Evidence:** Infested Breath, Rot, Volatile Rot, Heart of the Swarm, Infested Ground, Infested. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/Nightmare/Nythendra.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** placement, movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Ursoc

**Evidence:** Overwhelm, Rend Flesh, Focused Gaze, Momentum, Roaring Cacophony, Miasma. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/Nightmare/Ursoc.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Xavius

**Evidence:** Decent Into Madness, Madness, Dream Simulacrum, The Infinite Dark, Tormenting Swipe, Corrupting Nova. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/Nightmare/Xavius.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

## TombOfSargeras

### Demonic Inquisition

**Evidence:** Belac's Prisoner, Torment, Unbridled Torment (Berserk), Scythe Sweep, Calcified Quills, Bone Saw. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/TombOfSargeras/DemonicInquisition.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Fallen Avatar

**Evidence:** Touch of Sargeras, Rupture Realities, Unbound Chaos, Shadowy Blades, Lingering Darkness, Desolate. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/TombOfSargeras/FallenAvatar.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, movement, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Goroth

**Evidence:** Burning Armor, Infernal Spike, Crashing Comet, Shattering Star, Infernal Burning, Fel Eruption. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/TombOfSargeras/Goroth.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Harjatan the Bludger

**Evidence:** Jagged Abrasion, Unchecked Rage, Commanding Roar, Draw In, Frigid Blows, Frosty Discharge. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/TombOfSargeras/Harjatan.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Kil'jaeden

**Evidence:** Felclaws, Rupturing Singularity, Armageddon, Shadow Reflection: Erupting, Bursting Dreadflame, Focused Dreadflame. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/TombOfSargeras/Kiljaeden.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Maiden of Vigilance

**Evidence:** Unstable Soul, Aegwynn's Ward, Infusion, Hammer of Creation, Light Remanence, Hammer of Obliteration. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/TombOfSargeras/MaidenofVigilance.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** placement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Mistress Sassz'ine

**Evidence:** Hydra Shot, Burden of Pain, From the Abyss, Concealing Murk, Slicing Tornado, Thundering Shock. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/TombOfSargeras/Sasszine.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** placement, movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Sisters of the Moon

**Evidence:** Twilight Glaive, Moon Glaive, Discorporate, Glaive Storm, Incorporeal Shot, Twilight Volley. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/TombOfSargeras/SistersoftheMoon.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### The Desolate Host

**Evidence:** Dissonance, Quietus, Spear of Anguish, Collapsing Fissure, Tormented Cries, Rupturing Slam. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/TombOfSargeras/TheDesolateHost.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

## TrialOfValor

### Guarm-TrialOfValor

**Evidence:** Frost Lick, Shadow Lick, Flame Lick, Guardian's Breath, Flashing Fangs, Headlong Charge. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/TrialOfValor/Guarm.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Helya-TrialOfValor

**Evidence:** Orb of Corruption, Bilewater Breath, Bilewater Liquefaction, Bilewater Redox, Tentacle Strike, Taint of the Sea. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/TrialOfValor/Helya.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Odyn-TrialOfValor

**Evidence:** Valarjar's Bond, Revivify, Horn of Valor, Expel Light, Shield of Light, Draw Power. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Legion/blob/bbc48372f2b4483f1573175de20fd7b805785bc9/TrialOfValor/Odyn.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement, support, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.
