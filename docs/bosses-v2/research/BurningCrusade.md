# BurningCrusade encounter inventory

This era contains **54 encounter modules** in the pinned corpus. The module author’s encounter observations are source evidence; the candidate-design assessment is an inference for Arenic. This is a breadth screen, not a full tactical guide or a claim that every version of every mechanic was replayed. Preserve variant names: they may distinguish retail, Classic, faction variants, or Season of Discovery.

Source: BigWigs Mods, [BigWigs_BurningCrusade](https://github.com/BigWigsMods/BigWigs_BurningCrusade/tree/89a5db9b0e567f493471d151c56b4a72481c3008), revision `89a5db9b0e567f493471d151c56b4a72481c3008`, committed 2026-09-12T17:19:46Z. Full provenance and exclusions: [research contract](README.md).

## BlackTemple

### The Illidari Council

**Evidence:** Vanish, Deadly Poison, Reflective Shield, Circle of Healing, Chromatic Resistance Aura, Blessing of Protection. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/BlackTemple/Council.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Gurtogg Bloodboil

**Evidence:** Bloodboil, Fel Rage, Fel-Acid Breath, Acidic Wound, Bewildering Strike. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/BlackTemple/Gurtogg.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Illidan Stormrage

**Evidence:** Shear, Parasitic Shadowfiend, Flame Crash, Dark Barrage, Eye Blast, Uncaged Wrath. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/BlackTemple/Illidan.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### High Warlord Naj'entus

**Evidence:** Impaling Spine, Tidal Shield, Needle Spine. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/BlackTemple/Najentus.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Shade of Akama

**Evidence:** Rain of Fire, Stealth Removed, Big Wigs_Boss Comm, Repeater Defender, Repeater Sorcerer, Repeater Adds Right. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/BlackTemple/ShadeOfAkama.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Mother Shahraz

**Evidence:** Fatal Attraction, Prismatic Aura: Nature, Prismatic Aura: Arcane, Prismatic Aura: Shadow, Prismatic Aura: Holy, Prismatic Aura: Fire. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/BlackTemple/Shahraz.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Reliquary of Souls

**Evidence:** Soul Drain, Frenzy, Fixate, Rune Shield, Deaden, Spirit Shock. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/BlackTemple/Souls.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Supremus

**Evidence:** Fixate (41951 doesn't exist in Classic), Molten Punch, Molten Flame. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/BlackTemple/Supremus.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Teron Gorefiend

**Evidence:** Shadow of Death, Crushing Shadows, Shadow Of Death, Shadow Of Death Applied, Shadow Of Death Removed, Crushing Shadows. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/BlackTemple/Teron.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

## Hyjal

### Anetheron

**Evidence:** Sleep, Inferno, Swarm. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/Hyjal/Anetheron.lua).

**Screen:** timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. The source module is an alert model, not the game’s full authoritative simulation.

### ArchimondeHyjal

**Evidence:** Grip Of The Legion, Fear, Air Burst, Protection Of Elune. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/Hyjal/Archimonde.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Azgalor

**Evidence:** Doom, Howl of Azgalor, Rain of Fire. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/Hyjal/Azgalor.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Kaz'rogal

**Evidence:** Mark Cast, Mark, Mark Removed. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/Hyjal/Kazrogal.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Rage Winterchill

**Evidence:** Icebolt, Death & Decay, Death And Decay Damage. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/Hyjal/Winterchill.lua).

**Screen:** actor/target-sensitive observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

## Karazhan

### Attumen the Huntsman Raid

**Evidence:** Intangible Presence, Intangible Presence (Curse), Intangible Presence, Summon Attumen, Mount. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/Karazhan/Attumen.lua).

**Screen:** phase/state branch. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. The source module is an alert model, not the game’s full authoritative simulation.

### The Curator Raid

**Evidence:** Evocation, Arcane Infusion, Evocation (Weakened). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/Karazhan/Curator.lua).

**Screen:** phase/state branch, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. The source module is an alert model, not the game’s full authoritative simulation.

### Hyakiss the Lurker

**Evidence:** Hyakiss' Web, Hyakiss Web. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/Karazhan/Hyakiss.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Maiden of Virtue Raid

**Evidence:** Repentance, Holy Fire, Holy Fire. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/Karazhan/Maiden.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Prince Malchezaar

**Evidence:** Enfeeble, Shadow Nova, Enfeeble Applied, Shadow Nova Start, Shadow Nova, Infernal. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/Karazhan/Malchezaar.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Moroes Raid

**Evidence:** Vanish, Garrote, Frenzy / Enrage, Gouge. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/Karazhan/Moroes.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Netherspite

**Evidence:** Void Zone, Netherbreath, Nether Portal - Perseverence, Nether Portal - Perseverence (Tank Soak). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/Karazhan/Netherspite.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Nightbane Raid

**Evidence:** Bellowing Roar, Charred Earth, Rain of Bones, Bellowing Roar (Fear), Rain of Bones (Adds spawning). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/Karazhan/Nightbane.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Romulo & Julianne

**Evidence:** Eternal Affection, Poisoned Thrust, Eternal Affection (Heal), Poisoned Thrust (Poison). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/Karazhan/RomuloJulianne.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Shade of Aran

**Evidence:** Summon Water Elementals, Blizzard, Arcane Explosion, Flame Wreath, Summon Water Elementals (Adds). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/Karazhan/ShadeOfAran.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Terestian Illhoof

**Evidence:** Broken Pact, Sacrifice, Broken Pact (Weakened). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/Karazhan/Terestian.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### The Big Bad Wolf

**Evidence:** Red Riding Hood, Red Riding Hood Applied, Red Riding Hood Removed. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/Karazhan/TheBigBadWolf.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### The Crone

**Evidence:** Chain Lightning, Chain Lightning. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/Karazhan/WizardofOz.lua).

**Screen:** timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. The source module is an alert model, not the game’s full authoritative simulation.

## Outland

### Doomwalker

**Evidence:** Enrage / Frenzy, Frenzy / Enrage (20% Health), Overrun, Earthquake, Frenzy Enrage. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/Outland/Doomwalker.lua).

**Screen:** phase/state branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Gruul the Dragonkiller

**Evidence:** Ground Slam, Stoned, Shatter, Growth, Cave In, Reverberation. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/Outland/Gruul.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Doom Lord Kazzak

**Evidence:** Mark of Kazzak, Twisted Reflection, Frenzy, Mark of Kazzak (Mark), Frenzy (Enrage). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/Outland/Kazzak.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Magtheridon

**Evidence:** Blast Nova, Shadow Cage, Debris, Mind Exhaustion, Shadow Cage (Banish). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/Outland/Magtheridon.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### High King Maulgar

**Evidence:** Blindeye the Seer (Priest), Prayer of Healing, Greater Power Word: Shield, Krosh Firehand (Mage), Spell Shield, Olm the Summoner (Warlock). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/Outland/Maulgar.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement, support, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

## Serpentshrine

### Hydross the Unstable

**Evidence:** Tomb, Sludge, Mark, Stance. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/Serpentshrine/Hydross.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Fathom-Lord Karathress

**Evidence:** Heal, Totem. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/Serpentshrine/Karathress.lua).

**Screen:** death/stage event. **Arenic candidate axes:** support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Leotheras the Blind

**Evidence:** Engage Leotheras, Whisper, Whirlwind, Whirlwind Bar, Madness, Phase. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/Serpentshrine/Leotheras.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### The Lurker Below

**Evidence:** Whirl, Geyser, Cancel All Messages, Scan For Lurker, Lurker Down, Lurker Up. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/Serpentshrine/Lurker.lua).

**Screen:** timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. The source module is an alert model, not the game’s full authoritative simulation.

### Morogrim Tidewalker

**Evidence:** Grave, Tidal, Murlocs, Globules. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/Serpentshrine/Morogrim.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Lady Vashj

**Evidence:** Phase2, Phase3, Charge, Charge Removed, Barrier Remove, Elemental Death. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/Serpentshrine/Vashj.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement, support, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

## Sunwell

### Brutallus

**Evidence:** Burn, Meteor Slash, Stomp. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/Sunwell/Brutallus.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Felmyst

**Evidence:** Gas Nova, Demonic Vapor, Encapsulate, Corrosion. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/Sunwell/Felmyst.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Kalecgos

**Evidence:** Crazed Rage, [[ Kalecgos ]], Arcane Buffet, Frost Breath, Wild Magic (Increased healing) (You), Wild Magic (Increased cast time) (Healers). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/Sunwell/Kalecgos.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement, support, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Kil'jaeden

**Evidence:** Sinister Reflection, Shield of the Blue, Fire Bloom, Shadow Spike, Flame Dart, Darkness of a Thousand Souls. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/Sunwell/KilJaeden.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** support, routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### M'uru

**Evidence:** Darkness, Dark Fiend, Black Hole. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/Sunwell/Muru.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### The Eredar Twins

**Evidence:** Pyrogenics, Confounding Blow, Shadow Blades, Conflagration, Shadow Nova. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/Sunwell/Twins.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

## TheEye

### Al'ar

**Evidence:** Flame Patch, Armor, Scan For Alar. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/TheEye/Alar.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Kael'thas Sunstrider

**Evidence:** Conflag, Toy, Toy Removed, Fear Cast, Fear, Phoenix. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/TheEye/Kaelthas.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Void Reaver

**Evidence:** Arcane Orb, Knock Away, Pounding, Arcane Orb (Orb), Knock Away (Tank Knockback). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/TheEye/Reaver.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### High Astromancer Solarian

**Evidence:** Wrath, Wrath Remove, Phase2, Split. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/TheEye/Solarian.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** routing. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

## ZulAman_Classic

### Akil'zon

**Evidence:** Static Disruption, Electrical Storm, Electrical Storm, Electrical Storm Removed. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/ZulAman_Classic/Akilzon.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Halazzi

**Evidence:** Flame Shock, Frenzy, Lightning Totem. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/ZulAman_Classic/Halazzi.lua).

**Screen:** actor/target-sensitive observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Jan'alai

**Evidence:** Summon Amani'shi Hatcher, Flame Breath (this is the aura debuff spellid), Fire Bomb, Enrage. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/ZulAman_Classic/Janalai.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Hex Lord Malacrass

**Evidence:** Fire Nova Totem, Consecration, Spirit Bolts, Siphon Soul, Lifebloom, Healing Wave. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/ZulAman_Classic/Malacrass.lua).

**Screen:** actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Nalorakk

**Evidence:** Deafening Roar, Deafening Roar. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/ZulAman_Classic/Nalorakk.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Zul'jin

**Evidence:** Grievous Throw, Creeping Paralysis, Claw Rage. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_BurningCrusade/blob/89a5db9b0e567f493471d151c56b4a72481c3008/ZulAman_Classic/Zuljin.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.
