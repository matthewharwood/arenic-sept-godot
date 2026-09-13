# TheWarWithin encounter inventory

This era contains **30 encounter modules** in the pinned corpus. The module author’s encounter observations are source evidence; the candidate-design assessment is an inference for Arenic. This is a breadth screen, not a full tactical guide or a claim that every version of every mechanic was replayed. Preserve variant names: they may distinguish retail, Classic, faction variants, or Season of Discovery.

Source: BigWigs Mods, [BigWigs_TheWarWithin](https://github.com/BigWigsMods/BigWigs_TheWarWithin/tree/da9346c72880dcd19731f86312d9d02bd6b348c3), revision `da9346c72880dcd19731f86312d9d02bd6b348c3`, committed 2026-06-26T16:06:31Z. Full provenance and exclusions: [research contract](README.md).

## KhazAlgar

### Aggregation of Horrors

**Evidence:** Crystalline Barrage, Dark Awakening, Voidquake, Crystal Strike, Crystalline Barrage (Void Rocks), Dark Awakening (Explosion). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_TheWarWithin/blob/da9346c72880dcd19731f86312d9d02bd6b348c3/KhazAlgar/AggregationOfHorrors.lua).

**Screen:** timer/cadence observation. **Arenic candidate axes:** placement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. The source module is an alert model, not the game’s full authoritative simulation.

### The Gobfather

**Evidence:** Flaming Flames, Bombfield, Death From Above, Giga-Rocket Slam, Flaming Flames (Frontal Cone), Death From Above (Dodge). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_TheWarWithin/blob/da9346c72880dcd19731f86312d9d02bd6b348c3/KhazAlgar/Gobfather.lua).

**Screen:** timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. The source module is an alert model, not the game’s full authoritative simulation.

### Kordac, the Dormant Protector

**Evidence:** Arcane Bombardment, Titanic Impact, Supression Burst, Overcharged Earth, Overcharged Lasers, Arcane Bombardment (Dodge). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_TheWarWithin/blob/da9346c72880dcd19731f86312d9d02bd6b348c3/KhazAlgar/Kordac.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Orta, the Broken Mountain

**Evidence:** Colossal Slam, Tectonic Roar, Rupturing Runes, Mountain's Grasp, Colossal Slam (Frontal Cone), Tectonic Roar (Knockback). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_TheWarWithin/blob/da9346c72880dcd19731f86312d9d02bd6b348c3/KhazAlgar/Orta.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Reshanor, The Untethered

**Evidence:** Twilight Breath, Veilshatter Roar, Twilight Breath (Frontal Cone), Veilshatter Roar (Roar). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_TheWarWithin/blob/da9346c72880dcd19731f86312d9d02bd6b348c3/KhazAlgar/Reshanor.lua).

**Screen:** timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. The source module is an alert model, not the game’s full authoritative simulation.

### Shurrai, Atrocity of the Undersea

**Evidence:** Abyssal Strike, Regurgitate Souls, Briny Vomit, Dark Tide, Abyssal Strike (Heal Absorb), Regurgitate Souls (Adds). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_TheWarWithin/blob/da9346c72880dcd19731f86312d9d02bd6b348c3/KhazAlgar/Shurrai.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

## LiberationOfUndermine

### The One-Armed Bandit

**Evidence:** Pay-Line, High Roller!, Foul Exhaust, The Big Hit, Spin To Win!, Fraud Detected!. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_TheWarWithin/blob/da9346c72880dcd19731f86312d9d02bd6b348c3/LiberationOfUndermine/Bandit.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Cauldron of Carnage

**Evidence:** Colossal Clash, Zapbolt, Fiery Wave, Raised Guard, King of Carnage, Tiny Tussle. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_TheWarWithin/blob/da9346c72880dcd19731f86312d9d02bd6b348c3/LiberationOfUndermine/Cauldron.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Chrome King Gallywix

**Evidence:** Mechengineer's Canisters, Canister Detonation, Big Bad Buncha Bombs, Blast Burns, Bad Belated Boom, 1500-Pound "Dud". [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_TheWarWithin/blob/da9346c72880dcd19731f86312d9d02bd6b348c3/LiberationOfUndermine/Gallywix.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Sprocketmonger Lockenstock

**Evidence:** Gigadeath, Polarization Generator, Posi-Polarization, Nega-Polarization, Polarized Catastro-Blast, Void Barrage. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_TheWarWithin/blob/da9346c72880dcd19731f86312d9d02bd6b348c3/LiberationOfUndermine/Lockenstock.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** placement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Mug'Zee, Heads of Security

**Evidence:** Moxie, Double-Minded Fury, Mug, Earthshaker Gaol, Enraged, Pay Respects. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_TheWarWithin/blob/da9346c72880dcd19731f86312d9d02bd6b348c3/LiberationOfUndermine/MugZee.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, movement, support, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Rik Reverb

**Evidence:** Amplification!, Lingering Voltage, Resonant Echoes, Entranced, Noise Pollution, XXX Check if this warning is needed. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_TheWarWithin/blob/da9346c72880dcd19731f86312d9d02bd6b348c3/LiberationOfUndermine/Rik.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Stix Bunkjunker

**Evidence:** Electromagnetic Sorting, Rolling Rubbish, Garbage Dump, Rolled!, Garbage Pile, Muffled Doomsplosion. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_TheWarWithin/blob/da9346c72880dcd19731f86312d9d02bd6b348c3/LiberationOfUndermine/Stix.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, movement, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Vexie and the Geargrinders

**Evidence:** Protective Plating, Unrelenting CAR-nage, Call Bikers, Spew Oil, Oil Slick, Incendiary Fire. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_TheWarWithin/blob/da9346c72880dcd19731f86312d9d02bd6b348c3/LiberationOfUndermine/Vexie.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

## ManaforgeOmega

### Forgeweaver Araz

**Evidence:** Invoke Collector, Arcane Collector, Astral Harvest, Arcane Manifestation, Astral Surge, Arcane Obliteration. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_TheWarWithin/blob/da9346c72880dcd19731f86312d9d02bd6b348c3/ManaforgeOmega/Araz.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** movement, routing, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Dimensius, the All-Devouring

**Evidence:** Oblivion, Massive Smash, Living Mass, livingMassLeftMarker,, livingMassRightMarker,, Excess Mass. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_TheWarWithin/blob/da9346c72880dcd19731f86312d9d02bd6b348c3/ManaforgeOmega/Dimensius.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Fractillus

**Evidence:** Nexus Shrapnel, Null Consumption, Enraged Shattering, Crystalline Shockwave, Shattering Backhand, Shattershell. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_TheWarWithin/blob/da9346c72880dcd19731f86312d9d02bd6b348c3/ManaforgeOmega/Fractillus.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### The Soul Hunters

**Evidence:** Adarus Duskblaze, Devourer's Ire, Unending Hunger, Voidstep, Hungering Slash, Encroaching Oblivion. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_TheWarWithin/blob/da9346c72880dcd19731f86312d9d02bd6b348c3/ManaforgeOmega/Hunters.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Loom'ithar

**Evidence:** Lair Weaving, Woven Ward, Infusion Tether, Living Silk, Silken Snare, Overinfusion Burst. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_TheWarWithin/blob/da9346c72880dcd19731f86312d9d02bd6b348c3/ManaforgeOmega/Loomithar.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Soulbinder Naazindhri

**Evidence:** Soul Calling, Shadowguard Assassin, Voidblade Ambush, using 1227048 as 1227049 has no good tooltip info, Unbound Mage, Void Volley, Essence Implosion. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_TheWarWithin/blob/da9346c72880dcd19731f86312d9d02bd6b348c3/ManaforgeOmega/Naazindhri.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Nexus-King Salhadaar

**Evidence:** Nexus-King Salhadaar, Oath-Bound, King's Thrall, Subjugation Rule, Conquer, Vanquish. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_TheWarWithin/blob/da9346c72880dcd19731f86312d9d02bd6b348c3/ManaforgeOmega/Salhadaar.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Plexus Sentinel

**Evidence:** Atomize, Arcane Radiation, Arcane Lightning, Eradicating Salvo, Manifest Matrices, Displacement Matrix. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_TheWarWithin/blob/da9346c72880dcd19731f86312d9d02bd6b348c3/ManaforgeOmega/Sentinel.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** movement, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

## NerubarPalace

### Queen Ansurek

**Evidence:** Reactive Toxin, Concentrated Toxin, Frothy Toxin (Fail), Toxic Waves (Damage), Acid (Damage), Venom Nova. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_TheWarWithin/blob/da9346c72880dcd19731f86312d9d02bd6b348c3/NerubarPalace/Ansurek.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Nexus-Princess Ky'veza

**Evidence:** Assassination, Queensbane, Dark Viscera, Twilight Massacre, Nether Rift, Nexus Daggers. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_TheWarWithin/blob/da9346c72880dcd19731f86312d9d02bd6b348c3/NerubarPalace/Kyveza.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Broodtwister Ovi'nax

**Evidence:** Experimental Dosage, Experimental Dosage (was rupture/healing absorb), Ingest Black Blood, Unstable Infusion, Sanguine Overflow (Damage), Caustic Reaction. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_TheWarWithin/blob/da9346c72880dcd19731f86312d9d02bd6b348c3/NerubarPalace/Ovinax.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Rasha'nan

**Evidence:** Rolling Acid, Corrosion, Acidic Stupor, Acid Pool (Damage), Infested Spawn, Infested Bite. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_TheWarWithin/blob/da9346c72880dcd19731f86312d9d02bd6b348c3/NerubarPalace/Rashanan.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** placement, movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Sikran, Captain of the Sureki

**Evidence:** Cosmic Wound, Decimate, Cosmic Shards, Shattering Sweep, Captain's Flourish, Expose. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_TheWarWithin/blob/da9346c72880dcd19731f86312d9d02bd6b348c3/NerubarPalace/Sikran.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** movement, support, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### The Bloodbound Horror

**Evidence:** Invoke Terrors, Gruesome Disgorge, Gruesome Disgorge (Debuff), Unseeming Blight, Spewing Hemorrhage, Internal Hemorrhage. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_TheWarWithin/blob/da9346c72880dcd19731f86312d9d02bd6b348c3/NerubarPalace/TheBloodboundHorror.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### The Silken Court

**Evidence:** Anub'arash, Reckless Charge, Reckless Impact, Entangled, Burrowed Eruption, Call of the Swarm. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_TheWarWithin/blob/da9346c72880dcd19731f86312d9d02bd6b348c3/NerubarPalace/TheSilkenCourt.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** movement, support, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Ulgrax the Devourer

**Evidence:** Gleeful Brutality, Carnivorous Contest (Soak), Carnivorous Contest (Pull), Contemptful Rage, Stalkers Webbing, Stalker Netting. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_TheWarWithin/blob/da9346c72880dcd19731f86312d9d02bd6b348c3/NerubarPalace/Ulgrax.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, movement, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.
