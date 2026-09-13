# Dragonflight encounter inventory

This era contains **32 encounter modules** in the pinned corpus. The module author’s encounter observations are source evidence; the candidate-design assessment is an inference for Arenic. This is a breadth screen, not a full tactical guide or a claim that every version of every mechanic was replayed. Preserve variant names: they may distinguish retail, Classic, faction variants, or Season of Discovery.

Source: BigWigs Mods, [BigWigs_Dragonflight](https://github.com/BigWigsMods/BigWigs_Dragonflight/tree/4e469575ae8d5d54d1fc52ab5ea97400fe84da38), revision `4e469575ae8d5d54d1fc52ab5ea97400fe84da38`, committed 2026-06-26T16:17:42Z. Full provenance and exclusions: [research contract](README.md).

## Aberrus

### Assault of the Zaqali

**Evidence:** Zaqali Aide, Barrier Backfire, Warlord Kagni, Devastating Leap, Heavy Cudgel, Magma Mystic. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Dragonflight/blob/4e469575ae8d5d54d1fc52ab5ea97400fe84da38/Aberrus/AssaultOfTheZaqali.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Echo of Neltharion

**Evidence:** Volcanic Heart, Rushing Darkness, Calamitous Strike, Twisted Earth, Echoing Fissure, Corruption. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Dragonflight/blob/4e469575ae8d5d54d1fc52ab5ea97400fe84da38/Aberrus/EchoOfNeltharion.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Kazzara, the Hellforged

**Evidence:** Hellsteel Carnage, Dread Rifts, Riftburn, Rays of Anguish, Molten Scar, Hellbeam. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Dragonflight/blob/4e469575ae8d5d54d1fc52ab5ea97400fe84da38/Aberrus/Kazzara.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Magmorax

**Evidence:** Catastrophic Eruption, Molten Spittle, Searing Heat, Blazing Tantrum, Igniting Roar, Overpowering Stomp. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Dragonflight/blob/4e469575ae8d5d54d1fc52ab5ea97400fe84da38/Aberrus/Magmorax.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** placement, movement, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Rashok, the Elder

**Evidence:** Ancient Fury, Searing Slam, Living Lava (damage), Doom Flames, Shadowlava Blast, Charged Smash. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Dragonflight/blob/4e469575ae8d5d54d1fc52ab5ea97400fe84da38/Aberrus/Rashok.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Scalecommander Sarkareth

**Evidence:** Oblivion, Emptiness Between Stars, Mind Fragment, Astral Flare, End Existence, Opressing Howl. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Dragonflight/blob/4e469575ae8d5d54d1fc52ab5ea97400fe84da38/Aberrus/Sarkareth.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### The Amalgamation Chamber

**Evidence:** Essence of Shadow, Corrupting Shadow, Coalescing Void, Umbral Detonation, Lingering Umbra, Shadows Convergence. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Dragonflight/blob/4e469575ae8d5d54d1fc52ab5ea97400fe84da38/Aberrus/TheAmalgamationChamber.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** placement, movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### The Forgotten Experiments

**Evidence:** Infused Strikes, Infused Explosion, Neldris, Rending Charge, Massive Slam, Bellowing Roar. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Dragonflight/blob/4e469575ae8d5d54d1fc52ab5ea97400fe84da38/Aberrus/TheForgottenExperiments.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### The Vigilant Steward, Zskarn

**Evidence:** Dragonfire Traps, Animate Golems, Salvage Parts, Tactical Destruction, Shrapnel Bomb, Unstable Embers. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Dragonflight/blob/4e469575ae8d5d54d1fc52ab5ea97400fe84da38/Aberrus/Zskarn.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, movement, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

## Amirdrassil

### Council of Dreams

**Evidence:** Rebirth, Urctos, Blinding Rage, Ursine Rage, Barreling Charge, Agonizing Claws. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Dragonflight/blob/4e469575ae8d5d54d1fc52ab5ea97400fe84da38/Amirdrassil/CouncilOfDreams.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** placement, movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Fyrakk the Blazing

**Evidence:** Amirdrassil Burns, Blaze, Aflame, Fyr'alath's Bite, Fyr'alath's Mark, Firestorm. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Dragonflight/blob/4e469575ae8d5d54d1fc52ab5ea97400fe84da38/Amirdrassil/Fyrakk.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Gnarlroot

**Evidence:** Flaming Pestilence, Shadow Spines, Controlled Burn, Shadow-Scorched Earth, Dreadfire Barrage, Tortured Scream. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Dragonflight/blob/4e469575ae8d5d54d1fc52ab5ea97400fe84da38/Amirdrassil/Gnarlroot.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Igira the Cruel

**Evidence:** Drenched Blades, Blistering Spear, Blistering Torment, Twisting Blade, Marked for Torment, Gathering Torment. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Dragonflight/blob/4e469575ae8d5d54d1fc52ab5ea97400fe84da38/Amirdrassil/Igira.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Larodar, Keeper of the Flame

**Evidence:** Fiery Force of Nature, Blistering Splinters, Fiery Flourish, Scorching Roots, Charred Brambles, Scorching Bramblethorn. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Dragonflight/blob/4e469575ae8d5d54d1fc52ab5ea97400fe84da38/Amirdrassil/Larodar.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** placement, movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Nymue, Weaver of the Cycle

**Evidence:** Verdant Matrix, Continuum, Impending Loom, Surging Growth, Weaver's Burden, Ephemeral Flora. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Dragonflight/blob/4e469575ae8d5d54d1fc52ab5ea97400fe84da38/Amirdrassil/Nymue.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Smolderon

**Evidence:** Brand of Damnation, Cauterizing Wound, Searing Aftermath, Overheated, Flame Waves, Lava Geysers. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Dragonflight/blob/4e469575ae8d5d54d1fc52ab5ea97400fe84da38/Amirdrassil/Smolderon.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement, movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Tindral Sageswift, Seer of the Flame

**Evidence:** Flame Surge, Searing Wrath, Blazing Mushroom, Fiery Growth, Scorching Ground, Falling Star. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Dragonflight/blob/4e469575ae8d5d54d1fc52ab5ea97400fe84da38/Amirdrassil/Tindral.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** placement, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Volcoross

**Evidence:** Hellboil, Serpent's Fury, Coiling Flames, Flood of the Firelands, Volcanic Disgorge, Scorchtail Crash. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Dragonflight/blob/4e469575ae8d5d54d1fc52ab5ea97400fe84da38/Amirdrassil/Volcoross.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

## DragonIsles

### Aurostor

**Evidence:** Groggy Bash, Pulverizing Outburst, Cranky Tantrum, Slumberous Roar. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Dragonflight/blob/4e469575ae8d5d54d1fc52ab5ea97400fe84da38/DragonIsles/Aurostor.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Basrikron, The Shale Wing

**Evidence:** Sundering Crash, Awaken Crag, Fracturing Tremors, Shale Breath. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Dragonflight/blob/4e469575ae8d5d54d1fc52ab5ea97400fe84da38/DragonIsles/Basrikron.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Bazual, The Dreaded Flame

**Evidence:** Lava Breath, Magma Eruption, Deterring Flame, Flame Infusion, Rain of Destruction. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Dragonflight/blob/4e469575ae8d5d54d1fc52ab5ea97400fe84da38/DragonIsles/Bazual.lua).

**Screen:** timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. The source module is an alert model, not the game’s full authoritative simulation.

### Liskanoth, The Futurebane

**Evidence:** Deep Freeze, Binding Ice, Ascend, Deep Freeze, Binding Ice. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Dragonflight/blob/4e469575ae8d5d54d1fc52ab5ea97400fe84da38/DragonIsles/Liskanoth.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** cadence. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Strunraan, The Sky's Misery

**Evidence:** Empowered Storm, Strunraan's Tempest, Overcharge, Shock Water, Thunder Vortex, Arc Expulsion. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Dragonflight/blob/4e469575ae8d5d54d1fc52ab5ea97400fe84da38/DragonIsles/Strunraan.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** movement, economy. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### The Zaqali Elders

**Evidence:** Umbral Smash, Burning Shadows, Enveloping Darkness, Burning Strike, Searing Touch, Lava Geyser. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Dragonflight/blob/4e469575ae8d5d54d1fc52ab5ea97400fe84da38/DragonIsles/ZaqaliElders.lua).

**Screen:** actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

## VaultOfTheIncarnates

### Broodkeeper Diurna

**Evidence:** Broodkeeper's Bond, Greatstaff of the Broodkeeper, Greatstaff's Wrath, Clutchwatcher's Rage, Rapid Incubation, Wildfire. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Dragonflight/blob/4e469575ae8d5d54d1fc52ab5ea97400fe84da38/VaultOfTheIncarnates/BroodkeeperDiurna.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Dathea, Ascended

**Evidence:** Coalescing Storm, Diverted Essence, Aerial Slash, Blowback, Storm Bolt, Static Cling. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Dragonflight/blob/4e469575ae8d5d54d1fc52ab5ea97400fe84da38/VaultOfTheIncarnates/DatheaAscended.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### Eranog

**Evidence:** Flamerift, Primal Flow, Molten Cleave, Incinerating Roar, Molten Spikes, Burning Wound. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Dragonflight/blob/4e469575ae8d5d54d1fc52ab5ea97400fe84da38/VaultOfTheIncarnates/Eranog.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Kurog Grimtotem

**Evidence:** Elemental Surge, Sundering Strike, Fire Altar, Magma Burst, Molten Rupture, Searing Carnage. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Dragonflight/blob/4e469575ae8d5d54d1fc52ab5ea97400fe84da38/VaultOfTheIncarnates/KurogGrimtotem.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Raszageth the Storm-Eater

**Evidence:** Hurricane Wing, Static Charge, Volatile Current, Electrified Jaws, Lightning Breath, Lightning Strikes. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Dragonflight/blob/4e469575ae8d5d54d1fc52ab5ea97400fe84da38/VaultOfTheIncarnates/RaszagethTheStormEater.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** placement, movement, support. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Sennarth, The Cold Breath

**Evidence:** Chilling Blast, Frost Expulsion, Sticky Webbing, Wrapped in Webs, Call Spiderlings, Enveloping Webs. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Dragonflight/blob/4e469575ae8d5d54d1fc52ab5ea97400fe84da38/VaultOfTheIncarnates/SennarthTheColdBreath.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, difficulty branch, death/stage event, timer/cadence observation. **Arenic candidate axes:** movement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. Do not gate the next phrase on a kill. The source module is an alert model, not the game’s full authoritative simulation.

### Terros

**Evidence:** Rock Blast, Awakened Earth, Resonating Annihilation, Resonant Aftermath, Shattering Impact, Concussive Slam. [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Dragonflight/blob/4e469575ae8d5d54d1fc52ab5ea97400fe84da38/VaultOfTheIncarnates/Terros.lua).

**Screen:** phase/state branch, actor/target-sensitive observation, timer/cadence observation. **Arenic candidate axes:** placement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. A health/state transition cannot be inherited as a recording-safe trigger. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.

### The Primal Council

**Evidence:** Kadros Icewrath, Primal Blizzard, Glacial Convocation, Dathea Stormlash, Conductive Mark, (vs ICON, leave skull/cross for boss marking). [Pinned encounter source](https://github.com/BigWigsMods/BigWigs_Dragonflight/blob/4e469575ae8d5d54d1fc52ab5ea97400fe84da38/VaultOfTheIncarnates/ThePrimalCouncil.lua).

**Screen:** actor/target-sensitive observation, difficulty branch, timer/cadence observation. **Arenic candidate axes:** placement. Preserve a useful warning/response pattern only after replacing target- or phase-dependent triggers with authored ticks. Freeze placement or scope the consequence to the affected actor; never move the global score. The source module is an alert model, not the game’s full authoritative simulation.
