# Deterministic encounter contract

## Authority and precedence

For the proposed v2 encounters: this contract governs shared mechanics; the named encounter governs its geometry and score; ABILITIES governs cast semantics; INTERACTIONS governs composition. Current [combat](../combat.md), [recording](../recording.md), and [encounters](../encounters.md) remain the runtime truth until implementation. Their eight starter identities are retained. Older Bevy drafts and art manifests supply intent and names, never executable behavior where they conflict with active rules.

A research precedent describes why a mechanic is chosen. It does not override any Arenic rule. In particular, WoW health transitions, target selection, unavoidable raid damage, enrages, and random mechanics do not transfer into these scores.

## Clock, geometry, and score

Use 60 simulation ticks per second and 7,200 ticks per cycle. Intervals are half-open `[start,end)`; an instant impact lasts one tick. All times in the prose convert exactly by `tick = seconds × 60`. At a stated start tick an effect exists; at its end tick it does not. The cycle boundary is cleanup, not an event at tick 7,200 inside the outgoing score. All cue starts are nonnegative. Audio and animation observe ticks and cannot advance them.

The arena is 66 × 31 cells: x = 0…65 west to east, y = 0…30 south to north. A hero occupies one cell. A boss occupies a 6 × 6 rectangle whose lower-left origin is specified in the score. A rectangle `[x,y,w,h]` includes cells x…x+w−1 and y…y+h−1. Rectangles clip only when a definition explicitly says so; malformed authored geometry is rejected. Boss rest anchors, their adjacent rear cells, and all hazards are defined in logical cells, independent of sprite alpha.

Boss movement in v2 is a fixed, grounded **phase transfer**: telegraph both footprints for 180 ticks, remove occupancy at the old anchor and place it at the new anchor at the listed tick. No swept body collision, homing, crowd displacement, or airborne interval is implied. A hero on an arriving footprint takes a crush defeat; the destination is painted for the entire warning. The path of the sprite between anchors is cosmetic. Projectiles still query the authoritative footprint on their hit tick. This new action deliberately differs from the old Hunter’s airborne jumps; retain those old semantics under the old score revision.

Facing changes are also authored. All geometry is absolute in the data. Never derive the next attack direction from the nearest player. For back attacks, north-facing means a hero south of the footprint, south-facing means north, east-facing means west, and west-facing means east, within the starter’s adjacency rule.

## Combat profile and failure

The proposed v2 vitality profile is **4 maximum HP**, with hero direct hits still worth 1 damage. Standard wound events deal 1 HP once per event to each overlapping hero. Heavy events deal 2 HP. Crush events set HP to zero and bypass protection. A repeating hazard explicitly lists its pulse period; merely remaining inside a visual does not imply per-frame damage. Multiple different event IDs can hit in the same tick. No faction-free damage is silently turned off: player Acid Flask still burns friends.

This profile is a planned semantic change from the current 1-HP prototype. It must ship with its own ruleset revision, not as a stealth default edit. A fully dodged encounter needs no healing. Wounds make healing, barriers, defensive timing, cleansing, and resource support valuable for aggressive routes. There is no compulsory global damage pulse and no healer-only gate. Bosses remain immortal; “success” is sustainable repeated contribution to the existing cumulative damage ledger.

All debuffs in the v2 boss set are **Exposure**: at most one stack per actor and source event, 1 additional HP damage exactly 240 ticks after application. The removable status expires at +241 ticks, after its damage deadline; a Cleanse on the damage tick can still remove it first. Cleanse removes them. Exposure does not slow movement, silence, change cooldowns, hide information, or spread to other actors. Reapplication uses separate explicit event IDs, with a maximum of four outstanding stacks per actor. At the bound, replace the latest-expiring stack only if the incoming stack expires earlier; otherwise retain the old four and report the bound in diagnostics. Score validation must make reaching this limit impossible without player-created effects.

Defeat follows current ghost/free-hero rules. A defeated ghost emits no further moves or casts for the cycle. Saved damage and resource banks never roll back. Revival at a normal restart clears cooldowns, channels, hazards, Exposure, pair-interaction counters, cycle currency, and temporary protection. The last six seconds of every score are quiet after the final return at tick 6,780; projectiles and fields already alive expire normally until the seam, then clean up.

## Shared damage language

`wound` = 1 damage. `heavy` = 2 damage. `crush` = defeat. `expose` = 1 wound now plus the specified delayed Exposure. `window` = optional, time-bounded opportunity, no compulsory damage. `projectile` and `cone` are defense tags, not new damage amounts. `floor` and `crush` cannot be reflected. Boss damage and hero support resources use integers. A 1-damage hit is never reduced to zero by percentage rounding: v2 does not use percentage boss resistance.

All optional bonus windows add **one extra damage on the actor’s first qualifying hit per window**. They never multiply each other. An actor can earn at most one bonus per event/window ID; the priority is local encounter bonus, then Dice, then Vault, then Helix. Unused lower-priority bonuses remain until their own expiry. DOTs and fields qualify only where the encounter explicitly permits them; a qualifying scheduled tick uses its owner’s identity. Bonus hits do not trigger other bonus systems or copies.

## Non-interference boundary

The boss score is `B(arena, score_revision, cycle_tick)`. The actor simulation is `S(t+1) = F(S(t), authored_events(t), recorded_intents(t))`. Changing a hero’s strategy can change damage, survival, resource receipts, and actor contact. It cannot change B. Determinism means the same **complete initial state and ordered inputs** reproduce the same complete result. It does not mean a ghost survives if someone places acid on its path or collides with it.

No boss trigger reads a success total, damage threshold, live input, selected hero, or other arena clock. A miss never postpones a beat. An empty target set still consumes the authored event at its tick. Objects remain until authored expiry even if attacked. Gates never wait for damage. There is no combat RNG, including seeded RNG; deterministic pseudo-random combat would still violate this stronger requirement.

Persistent loot or recruitment can be randomized outside combat. Their outputs cannot change the active recording’s effective stats, resource budget, action timings, hazard geometry, or damage profile. Freeze the complete build when recording; equipment edits start a new explicit recording/build revision. Dig’s existing random 1–3 income is economic only; its v2 combat-rock return is a separate fixed one-per-new-cell rule. Fortune cannot import a loot roll into damage.

## Resolution order and boundary decisions

Implementation must version and test the order rather than casually replacing the current timeline order. At each tick: (1) expire effects whose end tick has arrived and obtain the authoritative boss pose; (2) apply movement intents and fixed portal transfers; (3) resolve existing hero contact using stable identity and the existing selected-hero rule; (4) resolve accepted hero support/direct cast effects in stable staff order; (5) resolve boss event impacts; (6) resolve attached DOTs and field pulses in stable owner/event order; (7) commit damage/income observations and advance the arena clock.

A Barrier completing on a hit tick protects against the boss hit. A Cleanse completing on an Exposure-expiry tick removes it before the delayed damage. A damage projectile hitting a relocating boss uses the new footprint even if the visual still shows the old one. A death cancels all later actor work in that tick. Support cannot undo a crush. Existing active casts finish through the same model as live and recorded casts. Inputs rejected for cooldown, lack of resource, or invalid target have a visible reason and consume neither cooldown nor currency.

Total event order is `(tick, phase, stable_performer_order, event_index, stable_target_id)`. No unordered collection, entity allocation order, display order, or wall clock may break a tie. Boss events that share a tick require separate stable event IDs in the v2 event list; the current strictly-increasing single-action beat schema needs a versioned extension.

## Arena affordances and navigation

The two-cell perimeter is the recovery circuit, outside all boss hazard masks and fixed boss footprints. It is not an attack platform: most starters cannot reach the boss from it. Published approach routes lead to safe working areas. Terrain never creates a sealed room. All arenas have at least two spatially separated exits from a working area. The common cycle begins and ends with six seconds without boss damage; neither six-second window is a timer pause.

Player deployables are nonblocking for bodies. Borders and Bulwarks affect tagged attacks only. Dig never removes walkability. No ability can build a wall that traps another hero. Portals are optional and fixed; an ordinary walking bypass is always open. A portal exit occupied by a living hero causes the entry transfer to be rejected, with the entrant staying on its entry cell; it does not seek a random free exit. The entry cell is still an ordinary hero-contact location. At most one transfer per actor per tick and a 120-tick personal portal cooldown prevent ping-pong.

Do not put forty actors on one safety marker. Forty published start slots occupy `(3+3i,2)` for i=0…19 and `(3+3i,28)` for i=0…19. These are unique and outside hazards. Useful formations require reserved, noncrossing routes and remain a choreography problem. A zero-conflict solo witness proves only solo viability; forty-actor throughput requires separate runtime simulation.

## Visual and sound contract

Hazard fill means the exact affected cells, with an outer warning outline that never changes the mask. Use a shape plus a label/pattern for polarity and reagent identity; color alone is insufficient. Real unsafe tiles never have false warnings, and safe tiles never impersonate lethal ones. Show action name, impact countdown, and the next two score events. Announce crush or terrain changes for at least 180 ticks; ordinary attacks for at least 120 ticks. Previewing the complete score is allowed.

Bard music may phrase at 120 BPM (30 ticks per beat), but action timings remain ticks. Audio muting, view swaps, slow rendering, and seeking cannot change either the floor phrase or Dance grading. Preserve the square arena/HUD style and native art sizing from the active repository. New effects need source art and runtime integration later; this document does not imply that they exist.
