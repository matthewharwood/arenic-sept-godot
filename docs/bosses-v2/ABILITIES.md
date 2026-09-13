# The 32-ability encounter contract

The source roster is eight classes with four abilities each. The linked legacy repository is pinned at `58c3aa5675e3b29e7b962fbfc7fb6d1d75da6b97`; its local checkout matched the remote main revision during this review. All 32 source documents and eight current asset manifests were inspected. The eight live starter rules override conflicting old design descriptions. This file makes deliberate, explicit v2 decisions for the other 24 abilities; it does not assert that those abilities are implemented.

## Shared defaults

Cooldown begins at accepted cast. Reject without spending resources if the cast cannot legally begin. A cancelled accepted channel consumes its elapsed cooldown; it receives no deferred damage or refund. An actor has one active cast/channel at a time; a passive does not occupy it. A following aura counts as active for Fortune under the current starter rule, so Coin Toss, Dice, and Vault must be scheduled outside Fortune’s active interval unless a later separately versioned loadout rule changes this. That opportunity cost is part of the Merchant design, not a hidden rotation assumption.

Cells use the geometry in CONTRACT. A targetless area cast remains legal on empty space. All effects expire by the cycle boundary. Every class retains its starter and may use it without permanent resource cost; “all class compositions viable” is not a promise that an intentionally empty offensive loadout deals damage.

Any current runtime cast time stored in float seconds must be quantized once at acceptance using `ceil(seconds × 60)` in this v2 ruleset. Thus Auto Shot’s 0.26-second draw becomes 16 ticks and Bash’s 0.35 seconds becomes 21. The migration must preserve old takes under their old semantics. Never change quantization under the same fingerprint.

Health/damage values are normalized prototype values. They are explicit initial tuning, subject to a new content revision after balance testing. A strong or weak rating in an encounter describes a window or spatial fit, not a simulated DPS tier.

## Hunter

### Auto Shot — `auto_shot`

**Live starter identity; v2 numerical contract.** Cooldown: 150 ticks. Nearest eligible enemy within 8 Chebyshev tiles; stable enemy ID breaks distance ties. Draw 16 ticks, then the smallest integer n with (16n)² ≥ 3600 × (dx²+dy²) ticks of flight. Freeze aim cell and flight time at acceptance; 1 damage only if the authoritative footprint still covers that cell.

Mobile, short firing windows; never homes or retargets. [Legacy source](https://github.com/matthewharwood/arenic_bevy/blob/58c3aa5675e3b29e7b962fbfc7fb6d1d75da6b97/_docs/abilities/hunter/auto_shot.md).

### Poison Shot — `poison_shot`

**Planned v2 ability.** Cooldown: 720 ticks. 24-tick draw; fixed aim within 8 tiles, same flight rule as Auto Shot. On hit, 1 direct damage plus 1 damage at +240,+480,+720,+960,+1200 ticks. One active poison per caster/target, refresh duration without an immediate tick. At release recoil one cell opposite facing; reject recoil into a wall/occupied destination and keep the cast, never relocate another actor.

Recoil is an explicit own-staff movement effect; attached poison survives boss transfers. [Legacy source](https://github.com/matthewharwood/arenic_bevy/blob/58c3aa5675e3b29e7b962fbfc7fb6d1d75da6b97/_docs/abilities/hunter/poison_shot.md).

### Sniper — `sniper`

**Planned v2 ability.** Cooldown: 240 ticks. 30-tick stationary aim; target boss only anywhere in this arena; impact at aim completion, fixed cell, 2 damage. Movement during aim cancels without refunding elapsed cooldown. Terrain marked opaque blocks the ray.

Long range changes access, not the clock; no cross-arena shot. [Legacy source](https://github.com/matthewharwood/arenic_bevy/blob/58c3aa5675e3b29e7b962fbfc7fb6d1d75da6b97/_docs/abilities/hunter/sniper.md).

### Trap — `trap`

**Planned v2 ability.** Cooldown: 180 ticks. Instant placement under caster, arms after 60 ticks; max 4 traps/caster, 1 per cell/caster; reject a fifth without cost. Lasts 1,200 ticks. First grounded boss overlap triggers a 2×2 footprint [x,y,2,2], clipped at arena edge, 2 damage once per enemy and no friendly damage. Trap never roots or interrupts.

Pre-position at future boss anchors; recorded geometry is independent of boss damage. [Legacy source](https://github.com/matthewharwood/arenic_bevy/blob/58c3aa5675e3b29e7b962fbfc7fb6d1d75da6b97/_docs/abilities/hunter/trap.md).

## Warrior

### Bash — `bash`

**Live starter identity; v2 numerical contract.** Cooldown: 60 ticks. Adjacent enemy including diagonal; hit after 21 ticks for 1 damage. The live starter has no weakening rider. v2 keeps that damage contract and adds no hidden interrupt.

Fast flank punish; scripted cleaves always finish. [Legacy source](https://github.com/matthewharwood/arenic_bevy/blob/58c3aa5675e3b29e7b962fbfc7fb6d1d75da6b97/_docs/abilities/warrior/bash.md).

### Block — `block`

**Planned v2 ability.** Cooldown: 60 ticks. Toggle shield, initially north; repeated taps rotate N→E→S→W. Active until own cancel. Suppresses incoming projectile wound/heavy damage from the cardinal facing. Does not reduce movement speed in v2. Cannot block floor, cone, Exposure, or crush.

Directional defense; exact boundary directions are cardinal attack tags, not float angles. [Legacy source](https://github.com/matthewharwood/arenic_bevy/blob/58c3aa5675e3b29e7b962fbfc7fb6d1d75da6b97/_docs/abilities/warrior/block.md).

### Taunt — `taunt`

**Planned v2 ability.** Cooldown: 600 ticks. 48-tick cast; six-second guard pledge to the nearest living ally within 3 tiles, tie stable actor ID. At a tagged projectile/cone hit on that ally, transfer at most 1 HP of that event to this Warrior if still within 3. Per Warrior maximum 1 transfer per 60 ticks. Solo fallback: self gains a one-hit 1-HP guard.

Redefines old aggro redirection as damage interception: no changed boss aim, facing, or hazard footprint. [Legacy source](https://github.com/matthewharwood/arenic_bevy/blob/58c3aa5675e3b29e7b962fbfc7fb6d1d75da6b97/_docs/abilities/warrior/taunt.md).

### Bulwark — `bulwark`

**Planned v2 ability.** Cooldown: 720 ticks. Instant, 240-tick frontal 3×2 field adjacent to the caster, rotates with cast facing only. Absorbs projectile and cone events crossing its leading edge for allies behind it within the rectangle; no body collision. One active field per caster; later cast replaces it after normal cooldown.

A team shelter; cannot stop trains, walls, floor reactions, or collapse. [Legacy source](https://github.com/matthewharwood/arenic_bevy/blob/58c3aa5675e3b29e7b962fbfc7fb6d1d75da6b97/_docs/abilities/warrior/bulwark.md).

## Thief

### Backstab — `backstab`

**Live starter identity; v2 numerical contract.** Cooldown: 30 ticks. One adjacent enemy strictly behind its authored facing. Hit after 12 ticks for 1 damage. Keep the live active attack rather than the old passive multiplier/bleed concept.

Rear access must exist in every encounter; arriving at a future rear is a meaningful skill. [Legacy source](https://github.com/matthewharwood/arenic_bevy/blob/58c3aa5675e3b29e7b962fbfc7fb6d1d75da6b97/_docs/abilities/thief/backstab.md).

### Shadow Step — `shadow_step`

**Planned v2 ability.** Cooldown: 480 ticks. Commit a four-cell cardinal displacement over 12 ticks; pass through boss/hazard cells, then 48 ticks of immunity to wound/heavy/Exposure damage. Pick the farthest legal cell along that four-cell segment from the cast snapshot; if none exists reject. Hero contact still resolves at the destination. No crush immunity.

Own intent owns displacement; no automatic target acquisition. [Legacy source](https://github.com/matthewharwood/arenic_bevy/blob/58c3aa5675e3b29e7b962fbfc7fb6d1d75da6b97/_docs/abilities/thief/shadow_step.md).

### Misdirection — `smoke_screen`

**Planned v2 ability.** Cooldown: 900 ticks. Place radius-3 Chebyshev field at an aim cell within 6 tiles for 360 ticks. A hostile projectile traversing it keeps its scheduled trajectory and impact, but deals zero hero damage and awards 1 boss damage to its owner once. Max 1 conversion per field per 60 ticks, lowest event ID wins.

Preserves the smoke_screen source ID; offense conversion cannot reflect recursively or change pathing. [Legacy source](https://github.com/matthewharwood/arenic_bevy/blob/58c3aa5675e3b29e7b962fbfc7fb6d1d75da6b97/_docs/abilities/thief/smoke_screen.md).

### Pickpocket — `pickpocket`

**Planned v2 ability.** Cooldown: 600 ticks. Adjacent to the boss, hold 30…180 ticks. At valid release, grant 1 cycle scrip per full 60 ticks, minimum 1; boss keeps all schedule-critical properties. At 180 ticks also grant 1 deterministic study token, redeemable outside combat for fixed progress. Max one token per actor per phrase.

A safe economic line exists even with no stealable buff; no permanent player currency cost. [Legacy source](https://github.com/matthewharwood/arenic_bevy/blob/58c3aa5675e3b29e7b962fbfc7fb6d1d75da6b97/_docs/abilities/thief/pickpocket.md).

## Alchemist

### Acid Flask — `acid_flask`

**Live starter identity; v2 numerical contract.** Cooldown: 240 ticks. Aim exactly three tiles in facing at cast; wall clamp. At +48 ticks place a 3×3 pool for 480 ticks; pulse 1 damage at +60…+480 from landing, eight pulses, allies and enemies alike. Separate casts stack.

Tick at final lifetime boundary resolves once before field deletion by an explicit terminal-pulse record; document this exception to half-open field occupancy. [Legacy source](https://github.com/matthewharwood/arenic_bevy/blob/58c3aa5675e3b29e7b962fbfc7fb6d1d75da6b97/_docs/abilities/alchemist/acid_flask.md).

### Ironskin Draft — `ironskin_draft`

**Planned v2 ability.** Cooldown: 720 ticks. Instant self protection for 240 ticks: subtract 1 HP from each wound/heavy damage event, minimum zero. Exposure damage included; crush excluded. Cannot stack with itself.

A four-second committed work period; durations never depend on health or difficulty. [Legacy source](https://github.com/matthewharwood/arenic_bevy/blob/58c3aa5675e3b29e7b962fbfc7fb6d1d75da6b97/_docs/abilities/alchemist/ironskin_draft.md).

### Siphon — `siphon`

**Planned v2 ability.** Cooldown: 240 ticks. Channel up to 180 ticks. Each 60 ticks, transfer 1 HP from the designated adjacent consenting ally above 1 HP to caster missing health. Select donor ID at acceptance; donor availability affects only that pulse. If solo, target the boss within 3 tiles: deal 1 and heal self 1 per pulse. Move cancels.

Explicit opt-in is recorded in the donor build; never drain an unwilling or last-HP actor. Full-health caster can still use boss mode. [Legacy source](https://github.com/matthewharwood/arenic_bevy/blob/58c3aa5675e3b29e7b962fbfc7fb6d1d75da6b97/_docs/abilities/alchemist/siphon.md).

### Transmute — `transmute`

**Planned v2 ability.** Cooldown: 600 ticks. 120-tick stationary conversion of one cycle reagent in a cache within 3 tiles into 2 cycle scrip or a 1-HP self guard lasting 300 ticks; mode recorded on cast. Every phrase spawns a personal reagent entitlement at the arena cache; entitlement is never consumed by other actors. If inventory is empty, reject before cast.

Guaranteed value; never performs a combat loot roll or consumes permanent items. First cache exists at tick zero. [Legacy source](https://github.com/matthewharwood/arenic_bevy/blob/58c3aa5675e3b29e7b962fbfc7fb6d1d75da6b97/_docs/abilities/alchemist/transmute.md).

## Cardinal

### Sacrifice — `heal`

**Live starter identity; v2 numerical contract.** Cooldown: 60 ticks. Hold on one accepted enemy identity within 8 tiles; 1 damage each 60 ticks while in range and grounded; no personal HP cost. Movement/cancel ends it. Unlike the old description, the live starter is an offensive channel.

Preserve stable source ID heal and live Sacrifice semantics; other Cardinal abilities supply healing. [Legacy source](https://github.com/matthewharwood/arenic_bevy/blob/58c3aa5675e3b29e7b962fbfc7fb6d1d75da6b97/_docs/abilities/cardinal/heal.md).

### Barrier — `barrier`

**Planned v2 ability.** Cooldown: 480 ticks. Instant shield on living ally within a caster-centered 8×8 area [x−3,y−3,8,8]. Choose unshielded missing-health ally, then least recently served, distance, ID. Self is eligible. Absorb 1 HP from the next wound/heavy event; 360-tick expiry. Multiple shields on one actor use only the earliest-expiring one for an event.

Round-robin fairness state is cycle-local and saved; damage protection is optional, never a route prerequisite. [Legacy source](https://github.com/matthewharwood/arenic_bevy/blob/58c3aa5675e3b29e7b962fbfc7fb6d1d75da6b97/_docs/abilities/cardinal/barrier.md).

### Beam — `beam`

**Planned v2 ability.** Cooldown: 360 ticks. 60-tick stationary windup, then a one-cell-wide cardinal ray to arena boundary. Each intersected enemy takes 2 damage once; living allies on the ray heal 1. Stops at opaque boss terrain; ignores other heroes. Does not pierce between arenas.

Aimed line can join offense and recovery; moving early cancels. [Legacy source](https://github.com/matthewharwood/arenic_bevy/blob/58c3aa5675e3b29e7b962fbfc7fb6d1d75da6b97/_docs/abilities/cardinal/beam.md).

### Resurrect — `resurrect`

**Planned v2 ability.** Cooldown: 3600 ticks. 120-tick stationary channel; revive one dead ghost in a centered 4×4 area [x−1,y−1,4,4], stable actor ID. Restore 2 HP at its defeated cell only if vacant. Resume only staff events at/after current tick; do not replay missed events. If no legal corpse, give caster a 1-HP barrier for 600 ticks and display the next three boss events.

A living fallback prevents a dead button. Revival changes actor outcomes, not the boss; it cannot repair an already-impossible recorded route. [Legacy source](https://github.com/matthewharwood/arenic_bevy/blob/58c3aa5675e3b29e7b962fbfc7fb6d1d75da6b97/_docs/abilities/cardinal/resurrect.md).

## Bard

### Cleanse — `cleanse`

**Live starter identity; v2 numerical contract.** Cooldown: 240 ticks. Instant centered 4×4 [x−1,y−1,4,4]: heal living allies 1, remove Exposure, hit intersecting enemies for 1 and attach an independent 300-tick stack, pulsing 1 at +60,+120,+180,+240,+300. Max pending stacks is bounded by cooldown and actor count.

Attached stacks follow target identity through transfers. Live ability is more than old cleanse-only design. [Legacy source](https://github.com/matthewharwood/arenic_bevy/blob/58c3aa5675e3b29e7b962fbfc7fb6d1d75da6b97/_docs/abilities/bard/cleanse.md).

### Dance — `dance`

**Planned v2 ability.** Cooldown: 600 ticks. Record eight taps at +30,+60,+90,+120,+150,+180,+210,+240 ticks after acceptance. Each within ±6 ticks scores one point; first tap assigned to earliest unfilled window, one per window. Finish at +247, nearest enemy within 8 tiles takes 1 damage for each two successes, minimum 1 if any succeed. Own movement allowed; actor contact still applies.

Fixed rhythm in ticks, not audio BPM or random prompts; partial success contributes. [Legacy source](https://github.com/matthewharwood/arenic_bevy/blob/58c3aa5675e3b29e7b962fbfc7fb6d1d75da6b97/_docs/abilities/bard/dance.md).

### Mimic — `mimic`

**Planned v2 ability.** Cooldown: passive ticks. Count eligible adjacent-ally direct offensive hits; every tenth schedules a 1-damage echo to that target identity after 30 ticks if in 8-tile range. Solo fallback counts own direct hits. Echoes never copy movement, fields, healing, resource spend, procs, or Mimic. If both self and adjacent allies hit, count ally events only for that tick.

Replaces 10% chance with a visible deterministic ten-note meter; bonus events never advance it. [Legacy source](https://github.com/matthewharwood/arenic_bevy/blob/58c3aa5675e3b29e7b962fbfc7fb6d1d75da6b97/_docs/abilities/bard/mimic.md).

### Helix — `helix`

**Planned v2 ability.** Cooldown: 60 ticks. Toggle a radius-3 Chebyshev aura. Regeneration heals each living ally 1 every 240 ticks; Haste grants self and allies one +1 direct-hit charge every 240 ticks, maximum one unspent charge each. Starts first pulse at +240. Toggling resets the pulse timer.

Haste means extra damage, not faster movement or cooldowns; adding a Bard cannot invalidate another recording’s action timestamps. [Legacy source](https://github.com/matthewharwood/arenic_bevy/blob/58c3aa5675e3b29e7b962fbfc7fb6d1d75da6b97/_docs/abilities/bard/helix.md).

## Forager

### Dig — `dig`

**Live starter identity; v2 numerical contract.** Cooldown: 90 ticks. Instant underfoot, marks one new cell per cast. Keep fixed 1 damage per 480 ticks of actual boss overlap per cell and existing independent economic income. v2 also grants exactly 1 cycle rock on the caster’s first personal dig of that cell this cycle, capped at 8; globally spent ground grants no duplicate economic payout or damage field. Ground stays walkable.

No combat resource RNG; existing banked overlap clears at seam. Cannot dig under an occupied boss. [Legacy source](https://github.com/matthewharwood/arenic_bevy/blob/58c3aa5675e3b29e7b962fbfc7fb6d1d75da6b97/_docs/abilities/forager/dig.md).

### Boulder — `bolder`

**Planned v2 ability.** Cooldown: 360 ticks. Spend 2 cycle rocks; launch a 2×2 stone, one cell every 15 ticks in facing, to boundary or fixed opaque terrain. Each enemy takes 2 damage once per boulder. No hero collision or knockback. The stable historical ID is bolder.

Starts with 2 cycle rocks, so a first cast is always obtainable without luck. [Legacy source](https://github.com/matthewharwood/arenic_bevy/blob/58c3aa5675e3b29e7b962fbfc7fb6d1d75da6b97/_docs/abilities/forager/bolder.md).

### Border — `border`

**Planned v2 ability.** Cooldown: 900 ticks. Spend 1 rock on a dug cell within 2 tiles; 90-tick cast, one-cell projectile shield for 3,600 ticks, max 2 per caster. Reflect projectile damage into one 1-damage boss credit per event without reversing the original hazard’s geometry; projectile deals zero damage to heroes behind its crossing.

Dug substrate is required but deterministic; does not obstruct hero movement or a boss transfer. [Legacy source](https://github.com/matthewharwood/arenic_bevy/blob/58c3aa5675e3b29e7b962fbfc7fb6d1d75da6b97/_docs/abilities/forager/border.md).

### Symbiosis — `mushroom`

**Planned v2 ability.** Cooldown: 900 ticks. Plant within 2 tiles, 120-tick maturation, lives 1,200 ticks. Base radius 2, heal 1 each 240 ticks after maturation. Spend up to 2 rocks through recorded feed intents: each raises radius by 1; no pulse-speed changes. One active node per caster; replaced only by a new accepted cast.

Preserves mushroom ID and healing-node concept. Zero-cost base seed makes an empty-rock build useful. [Legacy source](https://github.com/matthewharwood/arenic_bevy/blob/58c3aa5675e3b29e7b962fbfc7fb6d1d75da6b97/_docs/abilities/forager/mushroom.md).

## Merchant

### Fortune — `fortune`

**Live starter identity; v2 numerical contract.** Cooldown: 1200 ticks. Following radius-2 Chebyshev aura, 1 damage to each enemy at +60…+1200 ticks, exactly 20 pulses, same terminal-pulse exception as Acid. Movement allowed. No critical chance or random damage.

Current live damage aura takes precedence over the old luck-only design. [Legacy source](https://github.com/matthewharwood/arenic_bevy/blob/58c3aa5675e3b29e7b962fbfc7fb6d1d75da6b97/_docs/abilities/merchant/fortune.md).

### Coin Toss — `coin_toss`

**Planned v2 ability.** Cooldown: 600 ticks. Spend 1 of 4 starting cycle scrip; charge 0…300 ticks, then fixed cardinal skill shot at 16 cells/s. Damage = 1 + floor(charge/100), max 4. A hit refunds the one spent scrip; miss loses it this cycle only. Every phrase restores the personal wallet to at least 1, maximum 8.

No permanent gold spend, roll, or compounding bank dependence. Fortune always supplies a resource-free fallback. [Legacy source](https://github.com/matthewharwood/arenic_bevy/blob/58c3aa5675e3b29e7b962fbfc7fb6d1d75da6b97/_docs/abilities/merchant/coin_toss.md).

### Dice — `dice`

**Planned v2 ability.** Cooldown: 180 ticks. Instant, add one certainty pip, cap 3. At 3 pips the next direct hit gains +1 damage and consumes 3. No proc chance. Pips reset at the seam. A blocked bonus priority leaves them intact.

Accumulate in downtime and spend in a chosen window; title and animation can still feature dice. [Legacy source](https://github.com/matthewharwood/arenic_bevy/blob/58c3aa5675e3b29e7b962fbfc7fb6d1d75da6b97/_docs/abilities/merchant/dice.md).

### Vault — `vault`

**Planned v2 ability.** Cooldown: 1200 ticks. Instant 4×4 field within 3 tiles for 600 ticks. Each actor standing inside gets +1 on its first qualifying direct hit during that field, once; max one Vault bonus per actor per 600 ticks across all Merchants. No multiplication or boss-benefiting effect.

Scheduled dividend territory replaces old exponential critical stacking; field origin never follows its caster. [Legacy source](https://github.com/matthewharwood/arenic_bevy/blob/58c3aa5675e3b29e7b962fbfc7fb6d1d75da6b97/_docs/abilities/merchant/vault.md).

## Rules that resolve source conflicts

Sacrifice remains the current damaging enemy channel; this proposal does not quietly reinstate its old HP-to-ally-healing design. Cleanse retains immediate damage plus attached stacks. Backstab remains a positional active attack. Dig is one underfoot cell, not a two-tile selection. Fortune is the current damage aura. Misdirection, Symbiosis, and Boulder keep the source IDs `smoke_screen`, `mushroom`, and `bolder` so assets and recorded references remain traceable.

Random Mimic, Dice critical chance, variable Pickpocket success, random Transmute values, and paid Coin Toss outcomes become fixed counters or cycle-local budgets. Transmute may support the optional out-of-combat economy, but no such reward changes the running encounter. Helix and Block may not alter another actor’s movement cadence. Taunt and Misdirection cannot retarget the score. Resurrect cannot rewind a staff. These changes are required to reconcile the old abilities with the requested recording stability.

Each encounter has a personal cache at `(8,15)`, available from tick 0, with one reagent entitlement per thirty-second phrase. Unused entitlements expire at the next phrase. Interacting means casting Transmute within 3 tiles; no new interact button is required. The cache is nonblocking scenery and lies outside boss hazards. Pickpocket and reward tokens never consume a finite shared pile that could starve another recording. Source-based economic mechanics therefore remain useful in all eight arenas without introducing composition gates.

Projectile dx/dy are integer aim-cell offsets at cast acceptance. The squared-distance inequality gives an exact integer flight duration without a platform-dependent square root; cast windup is added separately. Cardinal rays use the authored cardinal cells. Sniper’s arbitrary sightline uses integer supercover traversal, with x-edge crossings processed before y-edge crossings on exact ties; an opaque touched cell blocks the ray.
