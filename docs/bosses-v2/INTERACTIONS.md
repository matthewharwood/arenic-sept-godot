# Ability composition and no-dead-end rules

## What is being quantified

The roster has 32 documented abilities. There are 256 ability–boss cells, 496 unordered distinct ability pairs, 528 unordered pairs including self-pairs, and 1,024 ordered pairs including self-pairs. Across eight bosses that is **8,192 ordered ability-pair cases**. All 255 nonempty subsets of eight classes yield **2,040 class-subset/encounter cases**. These finite sets are enumerated by the validator.

Those counts do not enumerate action timestamps, actor identities, positions, resources, gear, or arbitrary length histories. Merely listing pairs is not a proof of all higher-order behavior. The additional guarantee comes from explicit ownership, bounded effect rules, one nonrecursive modifier pipeline, and a complete reset at the seam. Runtime proof still needs the fixtures in IMPLEMENTATION.

The contract promises **an obtainable useful use** for every ability in every encounter, not that casting any button anywhere succeeds. A neutral row retains its ordinary function. A weak row gives a better time or place to use it. No row has a permanently immune target, required absent role, paid entry fee, or random prerequisite. All class subsets retain at least one resource-free damaging starter. Empty rooms, deliberate friendly fire, and incompatible path reservations are visible strategic failures, not hidden composition gates.

## Pair-rule dispatch

`tools/pair_rules.py` is the complete deterministic classification function. Pass two ability IDs and an arena ID to inspect one case. The classification yields all applicable rules in the following priority order; it is not an estimate of damage and does not simulate gameplay. A pair without a special interaction resolves as two independently owned effects through the same hit pipeline.

| Rule | Applies when | Exact consequence |
| --- | --- | --- |
| P01 Own movement | Either ability is Shadow Step or Poison Shot | Only that caster’s movement changes. Moving cancels its own stationary channel/windup. Other actors and the boss are never moved. |
| P02 Friendly field | Acid Flask is present | Every acid pulse still hits living allies in its cells. Barriers/Ironskin can mitigate; healing cannot revive a killed actor. No encounter reaction is triggered. |
| P03 Supply before spend | Dig, Boulder, Border, Symbiosis, Transmute, Coin Toss, or Pickpocket is present | Resources belong to the caster and cycle; stable acceptance order debits each resource once. No other actor can consume a personal entitlement. |
| P04 Recovery | Cleanse, Barrier, Beam, Resurrect, Symbiosis, Siphon, or Helix is present | Apply one bounded health/guard operation; no overheal bank, no free corpse movement, no resurrecting a contact victim into an occupied cell. |
| P05 Guard | Block, Bulwark, Taunt, Ironskin, Border, or Misdirection is present | Run the damage pipeline below once. An interception cannot be intercepted again. |
| P06 Copy | Mimic is present | Original eligible direct hits can advance one personal meter. Copies and bonus hits cannot trigger copies or spend a second actor’s resources. |
| P07 Bonus | Dice, Vault, or Helix is present | Add at most one +1 bonus packet to an original direct hit after encounter bonus priority. No multiplier products. |
| P08 Periodic | Poison Shot, Acid Flask, Sacrifice, Cleanse, Symbiosis, Helix, Dig, or Fortune is present | Tick ownership is explicit. A timer belongs to its arena; no aura changes another effect’s cadence. |
| P09 Own active cast | Every pair | A single caster cannot overlap incompatible active casts. Separate actors can, subject to positions and resource rules. Passive Mimic remains eligible. |
| P10 Independent | Every pair | Base targeting, geometry, expiry and damage resolve in their own stable order. Boss score fields are read-only throughout. |

## One damage pipeline

1. Compute the immutable event mask and tag from its authored tick. Gather affected actors in stable actor-ID order. A miss exits with no damage/proc.
2. If `crush`, defeat overlapping actors. No interception, barrier, armor, resurrection-in-place during this event, or damage bonus can make it safe.
3. For `projectile`, select one crossing defense by earliest intersection distance along the authored cardinal direction, then defense priority `Border → Misdirection → Block → Bulwark`, then owner ID. The projectile keeps its original visual/score path. If converted, award at most one 1-damage boss credit to that defense owner; no other defense awards another credit. Block/Bulwark produce no reflected credit. A converted projectile cannot re-enter this pipeline as a projectile.
4. A cone may be absorbed by a correctly oriented Bulwark. Floor damage cannot be redirected. A geometry absorption prevents both its immediate wound and its attached Exposure.
5. For remaining wound/heavy damage, choose at most one valid Taunt pledge for each victim, earliest accepted pledge then owner ID. Transfer up to one HP into a new **non-transferable** damage packet. Resolve Warrior personal protection once; do not create another pledge, reflect it, or apply a second Exposure.
6. Apply personal Shadow Step immunity, then Ironskin reduction, then one Barrier shield. Damage floors at zero. Exposure application on an unabsorbed original event is independent of armor reducing its immediate HP damage; Cleanse or later protection can answer its delayed pulse.
7. Apply HP loss and defeat before later actions from that actor. After accepted original hero damage, process the one-hit encounter bonus; then Dice, Vault, Helix, in that priority order. At most one bonus applies, and it never starts another bonus/copy pipeline.
8. Emit one base damage report and, if needed, one explicitly attributed bonus report. Accrued damage is credited once. Observers cannot perform another authoritative hit.

Ground fields use current overlap. Poison/Cleanse stacks use target identity. Misdirection uses a projectile event ID. Dig banks overlap per tile and target. Do not collapse those into one generic status and silently lose their different semantics.

All hostile projectile and cone events carry an authored **incoming direction**. For area impacts such as Glass Rain/Ore Spit this direction is north, meaning a north-facing shield catches the descending warning. This is a deliberate logical convention for the top-down model, not a physics inference from artwork. Rectangular rays use west unless their event states east; Guard Spear uses north. The exact directions are stored in the design score data. A cone’s direction is likewise authored and mirrors with its mask.

## Higher-order interactions that need explicit protection

| Combination | Resolution and useful role | Failure to prevent |
| --- | --- | --- |
| Acid + any melee + healing | Reserve a rear cell outside acid; healing supports a risky edge, never legitimizes standing in a lethal pulse chain. | Generic “healing fixes acid” advice hiding friendly-fire deaths. |
| Acid + Dig + Trap | Each keeps a separate owner, trigger and damage cadence. Trap is a single burst; Dig banks overlap; Acid pulses. | One detonation recursively triggering the boss chemistry or duplicate field hits. |
| Poison + Cleanse + boss transfer | Enemy stacks follow the same enemy identity; ally Cleanse removes only ally Exposure. | Cleansing the boss’s useful poison or dropping DOTs when the sprite changes position. |
| Block + Border + Misdirection | Exactly one defense wins interception. Others remain available for another event. | Infinite reflect loops or multiple income awards from one bolt. |
| Taunt + Taunt + Barrier | Select one pledge, transfer once, then use the recipient’s shield once. | Cyclic damage transfer or shields consuming twice. |
| Ironskin + Barrier + Shadow Step | Immunity first, reduction second, shield last; unused shields remain until expiry. | Consuming a scarce shield for already-zero damage. |
| Resurrect + hazard + hero contact | Validate corpse cell, revive to 2 HP, resume future intents only, then normal events can kill it again. | Spawning inside a living hero, rewinding the staff, or retroactive income. |
| Multiple Resurrects | First stable eligible revival wins; later casts use their explicit living fallback. | Double revival, duplicate movement, or rejected cast with spent resources but no effect. |
| Multiple Helix regeneration auras | Per actor, accept at most one healing pulse per 240-tick arena-aligned bucket; choose lowest caster ID among simultaneous pulses. | Forty auras turning a one-wound design into unbounded throughput. |
| Multiple Symbiosis nodes | Per actor, one node heal per 120-tick arena-aligned bucket. Lowest owner ID wins simultaneous claims; no node-to-node growth. | A healing network recursively multiplying itself. |
| Dice + Vault + Helix + encounter bonus | Highest-priority +1 packet applies; other unspent charges remain valid. | Exponential damage or taking a permanent bank as a multiplier. |
| Mimic + Mimic + Dance + Vault | Dance’s finale is one direct-hit event; its extra damage does not count as extra hits. Echoes never feed either Bard. | A copied performance, copied input sequence, or infinite echo recursion. |
| Fortune + Merchant other abilities | Same caster waits for its active 20-second aura to end; different Merchants may coordinate under their own state. | Assuming a solo Merchant can charge a coin and maintain Fortune concurrently. |
| Siphon + Siphon + healing | A donor’s HP is checked immediately before each transfer; never take the last HP. Boss mode remains available solo. | Simultaneous drains killing a donor or fabricating HP. |
| Dig + Border + Boulder + Symbiosis | Spend from one wallet in acceptance order. Empty-wallet refusal is visible; base Symbiosis and Dig remain free. | Hidden random rocks, negative wallets, or using the same rock twice. |
| Pickpocket + Transmute + Coin Toss | Personal deterministic budgets; receipts never change the boss’s posted dividend or the next phase. | A later recording replay failing because someone else took the loot. |
| Shadow Step + mirror portal | At most one explicit displacement intent and one valid portal transfer per tick; portal cooldown starts on success. Contact evaluates final destination. | Repeated teleports, exit search, or immunity to actor contact. |
| Any support + selected-hero changes | Support cannot change boss score. Existing selection-sensitive contact remains a recorded-world input constraint. | Claiming unchanged ghost survival when the selected actor or contact pattern changed. |
| Any ability + cycle wrap + save | Clear cycle effects once and reset budgets/counters before tick zero; never replay terminal pulses from the old cycle. | Extra damage on load, duplicate rewards, or cold-start/warm-loop drift. |

## Bounded proof of repeatability

Let R be the complete cycle-reset operation and I the same ordered input staffs. If R restores the same simulation-relevant state (including build, HP, cooldowns, wallets, attunement, temporary meters, start cells and IDs), and every tick step is pure and totally ordered, induction over 7,200 ticks gives identical cycle outcomes. Reapplying R then gives the same next cycle. The cumulative damage/reward ledger is an output accumulator, never an input to combat; it may differ without changing choreography.

This proof has explicit premises. It excludes changed staffs, changed roster/selection contact, changed content revisions, external player interference, and live build edits. Pair rules alone do not establish the premises. Save/restore and runtime tests must verify them. “Forever” means indefinitely repeated validated cycles under a fixed compatible ruleset, not a claim that an integer counter has infinite range; lifetime ledger overflow must be detected without wrapping or silently rewriting a save.

## A useful fallback in every failure case

No magic school immunity, mandatory interrupt, mandatory taunt, required healer, body-count soak, resource-consuming door, unbreakable player wall, or DPS-gated phase is present. A low-resource Forager digs or plants a free seed. A low-scrip Merchant uses Fortune and receives a deterministic budget next phrase. A solo support character uses its starter and its stated self/boss fallback. An unsuccessful dance or attunement loses a bonus rather than halting progress. A dead ghost revives at the seam, and its cached recording remains available to edit.

Not every bad path can be rescued. A ghost revived into a later section of an incompatible staff can die again; a player can deliberately acid or occupy another route. Such interference must be visible in the composer and activity feed. Never “fix” it by silently moving a boss event or altering another actor’s recording.
