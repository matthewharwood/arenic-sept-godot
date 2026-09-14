# Equipment rewards

Every natural two-minute cycle in one of the eight boss arenas banks one equipment draw when heroes participated and the arena dealt positive combat damage since its cycle baseline. The Guild House never awards equipment. Manual restart, committing a recording, re-recording, empty cycles, zero-damage cycles, and loading a save never award a draw. The source clock owns the boundary; cards and animations do not advance or pause combat.

A draw presents three concealed cards and selecting one awards exactly one item. Unopened rewards remain banked when dismissed. Equipment currently lives in a collection: power and flavor describe the item, but equipping it and changing combat statistics are not implemented. Duplicate equipment stacks by item identity. The first catalog contains exactly 100 original items across weapons, armor, and accessories: 24 Common, 24 Magic, 20 Rare, 16 Epic, 12 Legendary, and 4 Mythic.

## First-pass balance

The authored [loot-v1 table](../arenic-game/data/loot/catalog_v1.tres) contains the catalog, rarity weights, and progression gates. All percentages below apply independently to each concealed card; the three item identities are distinct. Card selection grants one of those outcomes, never all three.

| Band | Common | Magic | Rare | Epic | Legendary | Mythic | Completed damage | Completed hero ticks | Full-deployment hero ticks |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 0 | 82% | 17% | 1% | 0 | 0 | 0 | 0 | 0 | 0 |
| 1 | 62% | 31% | 7% | 0 | 0 | 0 | 400 | 57,600 | 0 |
| 2 | 35% | 45% | 18% | 2% | 0 | 0 | 8,000 | 1,152,000 | 0 |
| 3 | 18% | 38% | 35% | 8.5% | 0.5% | 0 | 100,000 | 11,520,000 | 0 |
| 4 | 8% | 27% | 43% | 19% | 3% | 0 | 500,000 | 23,040,000 | 0 |
| 5 | 3% | 17% | 44% | 28% | 7.5% | 0.5% | 2,000,000 | 46,080,000 | 23,040,000 |

One hero contributing for one 60 Hz simulation step supplies one hero tick. Paused, empty, or manually abandoned cycles never credit lifetime progression. Work is accumulated during the cycle and only credited at a positive-damage natural finish. The final band additionally requires all eight boss arenas to have their 40 recorded heroes deployed and their clocks running at the reward boundary. Its full-deployment requirement is ten complete 320-hero waves, or twenty minutes of actual concurrent combat, after the guild reaches that capacity. Wall-clock time, offline time, and merely opening a reward contribute nothing.

These gates complement the first-pass 10–20 hour guild-development target; they are a tuning hypothesis, not a claim that a playthrough has measured that duration. Rewards choose their band when earned. Waiting for a stronger guild never upgrades or rerolls a previously earned draw.

## Authority and persistence

`RunSetup.get_loot()` owns one `ArenicLootState`. Schema 11 stores `run.loot` with revision, completed damage/hero-work/full-deployment-work/cycle totals, eight arena records, and the item-count inventory. Every arena record stores the damage baseline, current ground-cycle serial, current-cycle hero/full-deployment work, the last observed full-deployment flag, and six earned/claimed bucket pairs. All counters use exact decimal strings. The ledger has 48 bucket pairs and at most 100 inventory entries regardless of play duration; it explicitly rejects totals above one trillion rewards instead of silently truncating them.

A reward token combines the frozen revision, arena identity, band, and that bucket's next unclaimed ordinal. SHA-256 of the run seed, token, card index and draw purpose supplies deterministic rarity and item selection on native and Web. There is no platform RNG dependency, stored array of millions of unopened chests, or second saved copy of derived card contents. Deferring, navigating, reloading, or earning other rewards cannot change a token's outcomes. Claims validate the token against the current bucket cursor, atomically increment that cursor and one item count, and reject stale or duplicate clicks.

Schema 10 → 11 creates an empty reward ledger and copies each existing arena's cumulative combat damage and ground-cycle serial into its baseline. It does not grant old loops or old partial-cycle damage retrospectively, replay any damage, or alter the schema-10 encounter fingerprint. Current saves preserve partial-cycle progress exactly. Inventory identities, bounds, earned/claimed sums, baseline/combat references, cycle/world references, and progression gates are validated before replacing the run. Card reveal progress, hover, tweens, and receipt presentation are transient and restore closed; awarded items remain authoritative inventory.

Released `loot-v1` identities and weights are immutable because pending draws reference them. Iterate the first-pass table before release; subsequent balance changes need a new reward revision, retaining the old table for previously earned buckets and an explicit migration. Do not change an existing token's interpretation underneath a saved guild.

## Runtime integration

- On actual `arena_advanced`, call `observe_cycle_progress(arena_id, total_damage, participating_heroes, full_deployment)`, after combat has resolved.
- On a natural cycle boundary, call `complete_cycle(arena_id, total_damage, ground_cycle + 1)` before the canonical reset. Duplicate completion serials cannot award twice.
- On every canonical restart, call `reset_cycle(arena_id, total_damage, ground_cycle)`. Manual restart does not call `complete_cycle`.
- `peek(seed, preferred_arena)` derives the next pending draw; `claim(token, index, seed)` returns exactly the awarded item or an empty dictionary. `pending_count()`, `claimed_count()`, and `inventory_rows()` supply UI projections.

The native domain checks cover catalog bounds, staged rarity, full-guild gates, partial-cycle continuity, deterministic draw identity, stale claims, and hostile payloads. Native process workers use the actual SaveGames service and disk adapter to persist a pending draw, claimed inventory, and partial work across a fresh engine process. Browser flow checks exercise real card controls and IndexedDB reload. Actual test results belong in the task's verification report.

## Isolated reward practice

Run `python3 scripts/preview-rewards.py` from the repository root. It opens the real game in Sanctum with the first three hero cards already visible. **F6** reopens hero cards and banks the next normal recruit if needed; **F7** supplies one practice arena completion and opens the real concealed loot cards; **F8** cycles the arena theme for the current card type. Normal click, cancel, and N controls remain available. The disposable project uses its own application identity and no active SaveGames slot, so the player's guild and saves remain untouched. Close the window and rerun the command to reset practice or load current UI edits.
