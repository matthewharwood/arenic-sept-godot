# Encounter distance and verification

## A shared feel with measurable separation

Every encounter shares the 120-second cycle, A–A′–B–A″ structure, warning/impact/recovery language, immortal damage target, personal optional rewards, readable geometry, and a free walking solution. These are the family resemblance. The choice of where to stand, when to commit, and what preparation earns value should differ.

The distance calculation combines three independent descriptions. It intentionally excludes boss name, art, color, expansion, lore, and absolute timestamp differences. Simply recoloring a floor or delaying the same attack is not enough to make two fights distinct.

**Behavior distance B:** weighted normalized Manhattan distance across eight authored 0–4 axes. An axis is 0 when absent, 1 when secondary, 2 when regularly relevant, 3 when a major pressure, and 4 when the defining repeated decision. Weights are `[2,2,2,2,2,1,2,2]`; the sustain weight is lower because recovery is a shared system. Divide the weighted difference by `4 × sum(weights)`.

**Spatial distance G:** Jaccard distance between the unions of all harmful/solid cells across each complete score: `1 − intersection/union`. This measures different working geography without giving credit merely for a different timestamp. It loses order and intensity; behavior and playtests must cover those.

**Ability-fit distance A:** average absolute difference of the 32 ratings (`− = −1`, `= = 0`, `+ = 1`), normalized by 2. Ratings are authored qualitative judgments tied to the per-ability explanations; they are not experimentally measured effectiveness.

`D = 0.55B + 0.25G + 0.20A`, bounded 0…1. This is a transparent design screening score, not a psychological measurement. The feature values, weights and ratings can be challenged independently. Lower D means more similarity. A provisional future review threshold is D < 0.25; it is a design heuristic chosen for this portfolio, not a scientifically validated cut-off.

## Behavioral signatures

| Boss | Transit | Facing | Portals | Terrain/setup | Polarity | Sustain | Phrase precision | Economy |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Hunter | 4 | 1 | 1 | 0 | 1 | 1 | 3 | 0 |
| Warrior | 1 | 4 | 0 | 0 | 0 | 1 | 2 | 0 |
| Thief | 3 | 1 | 4 | 0 | 0 | 0 | 2 | 0 |
| Alchemist | 1 | 0 | 0 | 4 | 1 | 3 | 2 | 1 |
| Cardinal | 1 | 1 | 0 | 0 | 4 | 3 | 1 | 0 |
| Bard | 3 | 2 | 0 | 0 | 1 | 1 | 4 | 0 |
| Forager | 2 | 0 | 1 | 4 | 0 | 2 | 1 | 1 |
| Merchant | 1 | 0 | 1 | 1 | 1 | 0 | 3 | 4 |

Transit means moving between work areas under hazards. Facing means meaningful front/rear/side choice. Portals includes optional route transformations. Terrain/setup includes timed obstruction and pre-positioned fields, not merely any floor attack. Polarity is state matching. Sustain is optional wound recovery supporting aggressive work. Phrase precision measures ordered participation bonuses or timed commitment. Economy is personal deterministic resource investment.

These scores are not inferred from the boss’s title. For example, Warrior’s facing 4 follows its cleave/rear vocabulary and small stance shifts; Hunter’s transit 4 follows separated train lanes and sidings; Merchant’s economy 4 follows the coin/posted-dividend decision. Alchemist and Forager both score 4 for setup, so their separation must also be present in hazard topology and ability fit.

## Full distance matrix

| Boss | Hunter | Warrior | Thief | Alchemist | Cardinal | Bard | Forager | Merchant |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Hunter | 0.000 | 0.404 | 0.300 | 0.432 | 0.342 | 0.354 | 0.467 | 0.399 |
| Warrior | 0.404 | 0.000 | 0.398 | 0.355 | 0.344 | 0.388 | 0.431 | 0.408 |
| Thief | 0.300 | 0.398 | 0.000 | 0.452 | 0.430 | 0.425 | 0.449 | 0.446 |
| Alchemist | 0.432 | 0.355 | 0.452 | 0.000 | 0.334 | 0.511 | 0.285 | 0.351 |
| Cardinal | 0.342 | 0.344 | 0.430 | 0.334 | 0.000 | 0.443 | 0.461 | 0.410 |
| Bard | 0.354 | 0.388 | 0.425 | 0.511 | 0.443 | 0.000 | 0.507 | 0.468 |
| Forager | 0.467 | 0.431 | 0.449 | 0.285 | 0.461 | 0.507 | 0.000 | 0.437 |
| Merchant | 0.399 | 0.408 | 0.446 | 0.351 | 0.410 | 0.468 | 0.437 | 0.000 |

The closest pairs require the most attention in the first playtest:

- **Alchemist / Forager — 0.2851:** behavior 0.1500, geography 0.6978, ability fit 0.1406.
- **Hunter / Thief — 0.3003:** behavior 0.2167, geography 0.5119, ability fit 0.2656.
- **Alchemist / Cardinal — 0.3344:** behavior 0.3333, geography 0.4669, ability fit 0.1719.

For a redesign, first change the decision structure: where preparation goes, which route is short or safe, which action commits the actor, or what earns the optional reward. Recompute afterward. Do not adjust feature values just to pass a threshold. A spreadsheet-like heatmap is not a substitute for recognizable play.

## Counterfactual design tests

Remove the unique mechanic from each fight while leaving common damage attacks in place. Hunter without traffic should lose its crossing decision. Warrior without the dodge/rear answer should lose its duel. Thief without portals should keep a valid longer route but lose shortcut planning. Alchemist without fixed chemistry should lose reagent sequencing. Cardinal without attunement should retain a neutral baseline but lose seal optimization. Bard without floor credit should lose optional choreography. Forager without timed walls should lose cover-demolition planning. Merchant without posted dividends should lose investment timing.

If removing a signature makes no practical difference, increase its optional reward or route advantage under a new draft; do not make it a mandatory class gate. If a signature eliminates ordinary movement/casting for most of a loop, shorten its occupancy or enlarge its working area. Four shared thirty-second labels alone do not satisfy compositional distinction: the event list includes an explicit B rearrangement/terrain contrast and one A″ overlap.

## What was checked on this documentation

The included validator passed structural checks for eight scores, six unique moves each (48 total), 25 events each (200 total), all 256 ability–boss records, 8,192 ordered pair classifications, and 2,040 class-subset coverage cases. These classification counts mean every pair/subset resolves to a documented rule set and starter coverage; they are **not 10,232 gameplay simulations**.

The navigation checker traversed 3,840 fifteen-tick intervals across the eight cycles. It found and independently checked one conservative, zero-hazard solo path per arena that holds an adjacent rear for 75 ticks in every phrase and returns to the start. It treats all damage masks as unsafe even when protection, attunement, or between-pulse gaps could help. It uses no portals, buffs, heals, dynamic cover or other actors. Because hazards/pose boundaries are aligned to those intervals, checking their union conservatively covers each whole interval. No claim is made about diagonal movement, optimal DPS, human execution, all start cells, or friendly-fire effects from an actual rotation.

The checker also validates whole ticks, warning lengths, arena bounds, phase seam poses, no boss hazard in the published start slots/perimeter, complete action references, and explicit finite score data. It does not import any new score into Godot or test engine rendering. [Validation JSON](data/validation.json) includes hashes tying results to the exact inputs; [walking witnesses](data/walking-witnesses.json) expose the routes for implementation tests.

Run from the active repository root:

```sh
python3 docs/bosses-v2/tools/validate.py
python3 docs/bosses-v2/tools/pair_rules.py acid_flask barrier crucible
```

## Runtime acceptance before enabling v2

| Property | Required experiment | Pass condition |
| --- | --- | --- |
| Empty-roster independence | Run each score with 0, 1, 8 and 40 ghosts; vary damage and loadouts | Identical boss pose/event/hazard stream hashes, except actor-local consequences. |
| Repeated-cycle stability | Run a fixed complete staff set for 100 cycles plus a direct seek/reconstruct | Cycle-local result digest repeats; earned cumulative deltas match each lap. |
| Cold/warm parity | Compare first playback after commit with later loops and save-restored loops | Identical accepted casts, target hits/misses, budgets, debuffs, survival and event order. |
| Starter viability | One hero of each class on each boss; zero permanent currency; only starter enabled | Obtain repeatable nonzero damage or credited Dig contribution and survive using a legal route. |
| Full-kit usefulness | Exercise each of the 256 table cells with a targeted fixture | Each has its documented usable window and the stated disadvantage/fallback behaves correctly. |
| Support independence | Remove all healers, interrupts, taunts, movement skills, then each class in turn | At least one no-hit ordinary walking route and damage plan remains. |
| Multi-actor choreography | Reserve separate starts/routes for 2, 8, 20 and 40 ghosts, including acid and portals | No unintended contacts; explicit incompatible routes fail predictably and are reported. |
| Balance differentiation | Same starter and comparable four-ability builds across all eight | Different useful routes/actions; no one passive safe tile gives maximum output everywhere. |
| Visual accessibility | Muted audio, reduced visual effects, native and enlarged view | Every fatal footprint and timing remains legible; no color-only or audio-only decision. |
| Bounds | Max fields, max targets, max stack claims, simultaneous expiry/impact | No silent truncation, recursion, duplicate credit, missed reset, or frame-dependent result. |

A design target is at least 25% of a cycle with reachable useful starter uptime on a no-hit route, including a rear opportunity each phrase. This is a proposed tuning gate, **not a result already established by the short rear witnesses**. A second target is at least one materially helpful and one situationally weak option per full kit across the portfolio. Equal DPS is not the goal; predictable tradeoffs and no compulsory class are.

For playtesting, hide boss names/art and ask players to identify the eight decision patterns after two recorded loops. Record confusion pairs, route edits, missed warnings, resource refusals and ability uses. A repeated confusion pair outranks a favorable mathematical distance. Keep the first balance session’s results next to this document and revise the draft content hash when behavior changes.
