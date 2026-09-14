# Guild House gathering

The Guild House is an outdoor field with a central tavern and the Keeper seated outside. It has two replenishing wood sites, two replenishing gold mines, a wood dropoff and a gold dropoff. These sites do not deplete. Banked wood and gold have no spending, crafting, combat benefit or recruitment effect yet.

`arenic-game/data/guild/gathering.tres` is the Inspector-editable `ArenicGatheringDefinition`. It authors source centers, dropoff centers, the circular interaction radius, fill time, bag capacity and unload time. The defaults are:

| Site or rule | Default |
| --- | --- |
| Wood sources | `(12, 9)`, `(12, 23)` |
| Gold mines | `(7, 24)`, `(56, 7)` |
| Wood / gold dropoffs | `(23, 21)` / `(42, 21)`, beside the tavern |
| Inclusive interaction radius | 2 tiles |
| Fill one bag | 5 seconds |
| Full bag capacity | 10 units |
| Unload one full bag | 1 second |

All positions use the existing 66 × 31 arena grid. Sites must have distinct, valid centers; there must be exactly two sources of each resource. Radius is bounded to 0.25–8 tiles, fill time to 0.05–120 seconds, unload time to 0.05–10 seconds, and capacity to 1–1,000 units. The resource exposes the same validation errors to configuration and Godot Doctor.

## Work and bags

`ArenicGatheringState` is a pure model. Its caller advances it once per unpaused Guild House simulation tick, after movement and contact deaths. It uses the hero's authoritative cell and combat defeat state, so selected heroes and recorded ghosts obey the same rules. It owns no timer, node, collision shape, animation or audio player.

A living Guild House hero automatically starts a bag within a source's radius. Moving while still inside the radius continues work. Leaving preserves partial fill progress, including when carrying it to another arena. One bag holds one resource: a partial wood bag can resume at either wood site, but cannot change into gold. Empty bags choose the nearest eligible source; exact distance ties use wood, then authored source order.

After exactly 300 default 60 Hz ticks, the bag is full and gathering stops. Only a full bag can unload, and only inside its matching dropoff radius. After 60 default ticks, unloading clears the bag and banks its contents. Moving inside the radius is allowed; leaving interrupts and resets unload progress while retaining the full bag. A partially filled bag cannot deposit early.

Each bag freezes its fill duration, unload duration and capacity when its first work tick is accepted. Reconfiguring the model preserves existing bags and totals, updates site geometry, and changes the rules for future bags. This keeps an in-progress saved bag consistent after authored settings change. The progress bar, displayed amount, current phase and current source/dropoff IDs are derived readouts. Partial displayed units are not banked resources.

Death discards that hero's carried bag. Revival can start fresh work. Guild House cycle restart clears bags for heroes currently in that arena, keeping banked totals and bags carried in other arenas. This makes work inside the existing two-minute recording cycle repeat from an empty bag. The model does not create extra replay events: recorded movement determines gathering through the same proximity rules as live movement.

## State and interfaces

`RunSetup.gathering` owns the model. The shared [save codec](save-state.md) owns versioning, complete validation, capture and restoration; scene code must not store bags separately. A new or migrated pre-gathering run starts with empty bags and zero banked totals.

The model holds at most 320 bags, keyed by stable hero identity `0..319`. Each `Bag` stores `kind`, `fill_ticks`, `fill_duration_ticks`, `unload_ticks`, `unload_duration_ticks` and `capacity_units`. Accepted bags have positive fill progress; positive unload progress requires a full bag. Bank totals are nonnegative signed 64-bit integers. Deposits saturate at that ceiling and report only the units actually accepted; a completed unload clears its bag even when the bank cannot accept its full contents.

| API | Contract |
| --- | --- |
| `configure(definition) -> bool` | Validate and copy authored settings; a rejected update leaves the last valid configuration and work intact. |
| `advance(heroes, combat) -> Array[Dictionary]` | Advance exactly one Guild House tick. Stable identity order; duplicate IDs, invalid IDs or oversized batches reject before mutation. Returns only completed, positive deposits. |
| `clear_hero(identity)` | Discard one carried bag, without changing its bank. |
| `restart(heroes)` | Clear bags only for the supplied heroes currently in the Guild House. |
| `snapshot_for(hero)` | Read `kind`, fill/unload ticks and durations, `capacity_units`, `amount`, derived `phase`, phase-local `progress`, `source_id` and `dropoff_id`. Invalid heroes return an empty dictionary. |

Deposit events have exactly `{kind: "deposited", hero_id, resource, amount}`. Consumers may display or publish these observations; they must not award the resources again. There is no history replay when a save restores. Snapshot mutation cannot alter a bag.

`gathering/gathering_checks.gd` covers authored boundaries, exact fill/unload endpoints, matching resources, movement, partial retention, frozen rules, defeated and unselected heroes, cycle clearing, defensive readouts, duplicate/oversized inputs and deterministic saturating deposits. Integration and save gates separately verify the caller's clock, scene feedback, collision ordering and persistence.

## Clearing presentation and existing runs

The northwest and southeast mines are nestled in the tree perimeter. `data/world/guild_clearing.tres` independently authors scenery through typed tree placements (five variants, four orientations) and seven winding paths. `ArenicGuildClearingView` renders the native Aseprite atlases at 19 pixels per grid tile, with a maximum of 96 trees and 256 path stamps. Actual source and dropoff centers still come only from `gathering.tres`; decorative trees do not create extra gathering sites or collisions. The wood dropoff at `(23, 21)` sits left of the tavern, and the gold dropoff at `(42, 21)` sits right of it. The seventh path curves between them through the porch: `(23, 21) → (24, 18) → (28, 17.5) → (33, 18) → (37, 17.5) → (41, 18) → (42, 21)`.

Gathering sites display their native artwork without world text: no WOOD, GOLD MINE, dropoff captions or Bank readouts. Character bag progress and amount UI remain, and actual completed deposits still publish their activity-feed observation. Removing site labels does not remove either bank from the saved ledger.

The tavern replaces the old construct's visual in the existing target slot; its explicit art offset does not change the Guild House combat identity, six-tile target footprint or damage ledger. The Keeper remains at `(33, 18)`, and hero starts, onboarding and gates retain their existing positions and rules. Rugs, books, braziers and the indoor floor treatment no longer appear in this arena.

This restyle keeps save schema 6. Restoration uses current source/dropoff geometry while preserving hero cells, recorded intent, bank totals and each bag's frozen work rules/progress. It does not gather, deposit, kill or relocate a hero during hydration. The dropoff move leaves all source positions, radius, fill/unload timing, capacity and the two-minute clock unchanged. Previous dropoff positions no longer unload bags; normal simulation resets unload progress outside the current matching radius. Existing recordings retain their exact intent and may need rerecording to reach the new dropoffs, just as routes to earlier mine positions may need updating. Stored events are never silently rewritten. Trees, paths, ground, tavern and seated-NPC animation are rebuilt presentation. Editable masters and export contracts are in [the clearing art folder](../assets/environment/guild_clearing/README.md).
