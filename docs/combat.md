# Starter combat

Class selection founds a **guild** with one chosen hero, selected and facing north at Guild House tile `(30, 15)`. It does not create a party or extra heroes. Each of the nine arenas has an immortal target: eight class bosses and Guild House's animated training construct. They occupy explicit 6 × 6 gameplay footprints at `(30, 22)` by default, facing north; the Labyrinth rests at `(30, 12)` because its [battle sequence](encounters.md) opens on the arena centre, and a scored boss moves its footprint as its cycle runs. Artwork size and transparent pixels do not determine occupancy.

This is a normalized combat prototype. Every authored damaging hit deals **1 damage**. Targets accumulate damage without losing health, dying, or disappearing. Enemies deal no damage through abilities; the one way a hero is defeated is standing inside a boss landing's blast radius, which returns it to Guild House with its progress intact ([battle sequences](encounters.md)). Sacrifice has no health cost in this prototype. Loot, currency, enemy attacks, additional abilities, and ability sound playback are not implemented by this change.

Heroes are a roster from the start, even while it holds exactly one: the guild
grows over a run and nothing downstream may assume a single hero. Each member
owns its own ledger entry, keyed `hero:<identity>` by its run identity, so health
and debuffs are per-member and travel with that member between arenas.
`ArenicCombatState.sync_allies()` is the one place a member's entry relocates.
Members do not block one another: several may share a tile.

### Who an arena hands you

Each arena remembers the member you last controlled in it, so walking a patrol of
arenas picks up where you left off rather than resetting to the top of the
roster. Paginating — brackets, an arena hotkey, the map, or overview arrows —
hands control to that member. An arena with no memory hands over the **first**
member standing there; an arena with **no members at all changes nothing**, so
you keep the hero you had.

**Tab** cycles the members standing in the focused arena, and every stop updates
what that arena remembers. Tab still finds the controlled hero when it is
somewhere else entirely.

A member that walks out of an arena takes that arena's memory with it, so the
arena will offer whoever is still there rather than someone who has gone. Another
member leaving does not erase a memory that still points at someone present.
Selection and that memory change together in `RunSetup.select()`, so the two
cannot drift apart.

Only deliberate navigation adopts a default. Following a hero that already moved
— edge-walking, respawning, Tab-to-find — leaves control where it is.

Being handed a **ghost** is allowed and asks nothing; moving it or recording over
it still opens its modal first.

## Controls and timing

Press **Tab** to focus and select the hero, then press **Space** or click the HUD ability button to cast. The hero must be selected in its focused arena. A new press queues at most one cast for the next physics tick; key repeat and holding an ordinary ability do not auto-cast. A rejected cast reports a reason and spends no cooldown. Accepted casts start their cooldown at windup, and another cast is rejected while the current cast, channel, or aura is active.

Hold Space or the button for Cardinal's Sacrifice. Releasing the cast controls ends a live-controlled channel. Movement input, navigation/zoom changes, deselection, application focus loss, sequence acquisition, and stage replacement cancel the live-controlled channel and clear queued input. The model also cancels if the hero moves or changes arena. A quick press and release before the first one-second tick deals no damage. A ghost's recorded channel belongs to playback: selecting it, selecting another hero, or releasing a key or button cannot cancel it. Presentation follows that caster's actual model state and clears when the model ends the channel.

Sacrifice's native beam follows the accepted enemy identity, including its current
encounter-derived center and jump height. It updates its direction, tiled length,
and endpoint through takeoff and landing without changing the saved target cell
or restarting the channel. The tether hides when that moving footprint leaves
the authored range and reconnects when it returns; its caster aura remains while
the model still holds the channel. A boss in the air still receives no ground
damage. Selecting another hero does not reassign the beam or its aura.

Every ability's presentation is owned by its actual caster. Each of the 320
supported hero identities has a separate budget of sixteen temporary hit/burst
and number effects; unknown legacy sources use an additional independent bucket.
These slots allocate lazily. A busy caster can replace its own oldest temporary
feedback, but another caster cannot steal it.

Active Auto Shot and Acid Flask projectiles, Fortune auras, Cleanse waves and
Dig excavation reserve their own slots outside those temporary budgets. Sacrifice
reserves its aura and up to four native beam strips. The largest active cast uses
five slots; one authoritative cast per hero means the reserved layouts never
collide. Model-owned casts remain visible until their own model finishes, even
if a presentation frame's elapsed time passes their nominal duration. Immediate
Cleanse/Dig animations expire locally and do not become durable state.

Fortune no longer has a global presentation timer or ability-wide cleanup.
Its aura follows its caster, survives selecting another class, and restores
alongside other Merchants. Hit presentation receives the actual damage event's
caster, ability, arena and facing; a delayed projectile or ground pulse never
borrows the last ability that happened to be cast. Unknown provenance remains
unknown. Arena resets filter by arena and caster, and stage/save restoration
reconstructs every active cast without replaying damage.

All visuals remain derived/transient. This ownership fix adds no saved fields
and changes no authoritative damage, cooldown, cast timing or recorded intent.
The complete audit and extension checklist are in
[ability ownership](ability-ownership.md).

Each caster owns its own in-flight cast and cooldown, keyed by run identity, so
forty recorded heroes and the player can all act in one arena without contending.
Every cast query — cooldown, remaining, channel state, presentation snapshot — is
scoped to a caster; there is no single "the" cast to ask about.

`GameShell._physics_process()` advances combat explicitly through `tick(delta, hero)`. Overview continues cooldowns and Fortune; a camera sequence pauses combat advancement after cancelling a held channel. The combat model has no node timer, rendering callback, or audio-playback dependency. Music maintains its separate clock contract in [arena-music.md](arena-music.md).

## Eight starter abilities

Defaults are authored in `arenic-game/data/classes/<class>_primary.tres`, using `ArenicClassAbility`. Damage is currently 1 for every starter. Times below are seconds from accepted cast; cooldowns include windup.

| Hero | Ability / source ID | Target and effect | Hit timing | Cooldown |
| --- | --- | --- | --- | ---: |
| Hunter | Auto Shot / `auto_shot` | Nearest enemy within 8 tiles. | 0.26 s draw, then 16 tiles/s to the fixed aim cell; airborne or departed targets miss. | 2.5 s |
| Warrior | Bash / `bash` | One adjacent enemy, including diagonals. | One hit after 0.35 s. | 1 s |
| Thief | Backstab / `backstab` | One adjacent enemy, strictly behind its facing. | One hit after 0.2 s. | 0.5 s |
| Alchemist | Acid Flask / `acid_flask` | Aimed three tiles along the caster's facing. No target. | Lands after 0.8 s; see [ground effects](#ground-effects). | 4 s |
| Cardinal | Sacrifice / `heal` | Hold a channel on one enemy within 8 tiles. No health cost or health gate. | First hit at 1 s, then once per second while held and in range. | 1 s |
| Bard | Cleanse / `cleanse` | Exact 4 × 4 area: heal allies by 1, clear their debuffs, hit each intersecting enemy once, and attach an independent 5-second damage stack. | Immediate hit, then 1 damage each second through 5 s per stack. | 4 s |
| Forager | Dig / `dig` | The tile underfoot. No target, no range, no adjacency. | Instant; see [digging](#digging). | 1.5 s |
| Merchant | Fortune / `fortune` | Aura follows the caster and hits all enemies within radius 2, including diagonals. | Exactly 20 one-second ticks, from 1 s through 20 s. | 20 s |

## Ground effects

Two starters do not damage anything themselves — they put something on the floor
and let it work. Both belong to the **arena's cycle** rather than to the combat
ledger, and both clear when that cycle ends, so a replayed take always starts on
level ground.

Ground effects lie **under** whatever stands on them: a boss wading through acid
is drawn over the pool, never swallowed by it. That needs two things to agree —
each layer sits below the boss sprite's own lift in world height, and sorts below
the default priority a `Sprite3D` renders at. Acid still reads over broken
ground, because the layers sort among themselves first.

The ledger announces a landing through `ability_landed`, and the arena's cycle
state does the rest. Instant abilities land at cast; thrown ones land when they
resolve. Live casts and ghost playback reach it through the same door, so a ghost
lays exactly the ground its take did.

### Acid Flask

A **skill shot**: it flies three tiles along the caster's facing, whatever is
there, and needs no target. Aim is taken when it is *cast*, so turning during the
0.8-second flight does not steer it, and a throw into the arena wall lands
against the wall rather than vanishing.

Where it lands it leaves a **3 × 3 pool for 8 seconds**, burning everything
inside it for **1 a second** — eight burns, then it dries up. Acid with nothing
standing in it burns nothing. A second flask onto the same ground lays a *second*
pool rather than refreshing the first, so two flasks burn twice as fast.

**Acid has no allegiance.** A hero standing in a pool burns like anything else,
and at one health that is fatal, so an Alchemist has to record a path around
their own ground. A burned hero dies exactly as it would to a boss landing: a
free one walks home to the Guild House, a **ghost dies where it stood** and rises
with the next cycle — and since both its intent and the pool are fixed, it will
burn at the same tick every cycle until the take changes.

The pool reports when and where a burn came due, with the original thrower's
stable identity for activity attribution. The ledger still applies it to enemies
and allies alike; provenance does not change friendly fire. Pool ownership
survives save/reload, and legacy pools explicitly retain an unknown owner.

### Digging

Dig breaks the ground the Forager is standing on. It needs no enemy, so it casts
anywhere — in a boss arena or the Guild House alike — and it deals no damage by
itself.

When a cycle starts, every tile in the arena is worth **1-3**. Breaking one pays
that toward the next hero: damage and broken ground are two incomes feeding the
same [guild rolls](guild.md). A tile pays **once** — digging spent ground is
still a legal cast, it simply finds nothing left to take, which is why spent
tiles are marked on the floor.

Broken ground is also a trap. A boss standing on a dug tile takes **1 damage
every 8 seconds**, counted in whole ticks of *actual overlap*. Overlap is banked
rather than reset when the boss leaves, so a boss that parks on prepared ground
for part of each cycle still eventually pays for it; one that only passes through
does not. Each dug tile bleeds independently, so ground prepared under a landing
site is far stronger than a scattered trail.

Each tile retains the first successful digger's identity for its later damage
messages. Digging already broken ground does not replace that owner. Ownership
and overlap debt are saved together and clear together when the cycle restarts.

Every dig clears when the arena's cycle ends and the ground rolls fresh. The roll
is seeded from the arena and its cycle number, never from chance at the moment of
asking — a recorded Forager must dig the same tile for the same value every time
that cycle comes around.

Range is the **Chebyshev distance to the nearest occupied footprint cell**: `max(abs(dx), abs(dy))`. Target selection considers only the caster's arena, then sorts equal-distance candidates by stable enemy ID. Targeted casts face the selected cell, using vertical facing when both axes tie. Self-area abilities retain the hero's facing. Adjacent means distance exactly 1; standing inside a target is not adjacency. Movement into grounded target footprints is blocked by the shell. Scored bosses derive their current ground footprint from the encounter clock; airborne bosses have no ground collision or damage footprint, including during a jump that began after a shot was fired. Ground contact resumes at the exact authored landing tick.

Backstab checks the target's facing, not the caster's. North is local `+Y`, so its rear is below the footprint's minimum Y. South reverses that edge; east and west use the corresponding opposite X edge. Front and side positions fail. Delayed melee checks adjacency again at impact, and Backstab also rechecks the target's facing. Moving out of reach or turning during windup can make the attack miss. The cooldown remains spent.

Acid Flask fixes its ground cell when cast and creates the pool described above.
Auto Shot retains its selected target and aim cell within the original cast arena. Its authored `projectile_speed_tiles_per_second` is 16: flight time uses Euclidean distance, so close, distant and diagonal arrows move at the same speed. The accepted total duration is frozen per cast and saved; the 0.26-second draw and 2.5-second cooldown are independent of distance. At arrival the target must be grounded and still occupy the original aim cell. A miss grants no damage, activity damage row or impact sound. A released
projectile can finish after the hero moves; it never selects a new target in a
remote arena.

Cleanse's even-sized area is biased toward `+X/+Y`: at `(10, 10)` it covers cells `(9, 9)` through `(12, 12)`, inclusive. Its lower corner is clamped so the complete 4 × 4 remains inside the 66 × 31 arena at an edge. Large enemy footprints are hit once even if several of their cells intersect it. Ally health is capped at each ally's `max_health`; clearing debuffs adds no immunity or other buff.

Each grounded enemy hit by Cleanse also receives an independent damage-over-time stack. The authored defaults are `enemy_dot_duration_seconds = 5`, `enemy_dot_tick_seconds = 1`, and `enemy_dot_damage = 1`; zero duration disables the additional stack. Acceptance freezes these rules as integer 60 Hz ticks, together with the original caster, ability, arena and enemy identities. Inspector edits affect later casts. Stacks remain attached when the enemy moves or jumps and after the caster travels elsewhere; they do not reacquire targets or require a fresh ground hit.

The owning arena advances its stacks exactly once per running simulation tick. Pausing that arena pauses its remaining time and tick debt. A due hit occurs before expiry, so the five-second default delivers precisely five periodic hits in addition to the immediate hit. Recasts and different Bards add stacks without refreshing older ones. Restarting or wrapping the arena clears its stacks while retaining earned damage. The shared [save codec](save-state.md) stores the ordered stack state and restores it without replaying any hit, sound or cast effect.

The combat model accepts at most 6,400 enemy stacks globally. A cast that would exceed that bound rejects before its cooldown, healing, initial hit or any new stack; it never partially applies the area. Authored duration is bounded to 120 seconds, interval to 0.05–10 seconds, and per-tick damage to 1–100. The boss readout groups actual stacks by ability and shows the next expiry; it is a defensive projection of the model, not another timer. Periodic hits update the normal damage ledger and source-attributed activity signals without emitting a new cast or impact sound phase.

Fortune reevaluates the caster's current cell and arena at every tick. Recasting cannot stack or restart it. There is no time-zero hit, and a large timestep cannot extend the 20-second lifetime. Nearby allies other than the caster contribute `loot_bonus_per_ally = 0.05` to a temporary data hook at each tick. `fortune_loot_bonus()` exposes that fraction while the aura is active; expiration clears it. No gold, inventory item, or payout is created.

## Damage and phase persistence

`ArenicCombatState` owns independent cumulative totals for each arena and each enemy ID within that arena. `ArenicArenaDefinition.phase_damage` is the absolute damage needed per phase, default **20**. It is not a percentage of target health. For a total of 43 and threshold 20, two phases are complete and the current phase contains 3 damage; the HUD displays phase 3. Cumulative damage is never discarded at a boundary.

The full-width HUD bar follows the selected arena, including overview `[` / `]` navigation. Its nine themed procedural patterns share the same square, full-width 9-pixel mask. At exactly 20 damage the current fill becomes zero for phase 2, while a muted completed layer remains visible across the full width; at 21, the new layer fills 5% over it. Completed phases advance a boss's authored appearance when one exists, stopping at its final available appearance; further phase layers continue in the ledger and HUD. Bosses and the Guild construct remain present and damageable. This is not an enemy health bar.

`RunSetup` retains the chosen hero and combat model across stage replacement. `configure(world)` and re-registering the same enemy ID preserve totals. `begin_new_game()` or choosing a new class creates fresh run state. Stage replacement cancels a held channel, but preserves an airborne cast or Fortune and its remaining time.

The shell and save hydration restore the new presenter from `active_cast_snapshot()` for every hero after configuring it. Restoration replaces only the snapshot owner’s visuals, so simultaneous casts coexist. The snapshot contains `ability_id`, `effect_kind`, `arena_id`, `origin`, `target_cell`, `target_id`, `facing`, `elapsed`, `remaining`, `is_channeling`, `cast_seconds`, and `duration_seconds`; idle combat returns an empty dictionary. Values are independent of the model's mutable state. Fortune reports the caster's current location; projectiles preserve their original cast geometry. Sacrifice resolves its original `target_id` through the read-only `enemy_presentation_pose()` lookup. Reading or restoring a snapshot does not restart the timer or apply damage. An indefinite held channel reports `INF` remaining.

## Extension and authoring APIs

The model lives in `arenic-game/scripts/combat/combat_state.gd` and extends `RefCounted`. It owns no scene or spawned actor. Relevant APIs are:

| API | Contract |
| --- | --- |
| `configure(world)` | Add known arenas/update authored thresholds while preserving existing totals and active state. |
| `register_enemy(arena_id, enemy_id, footprint, facing = "n")` | Register an explicit `Rect2i` inside one arena; returns false for invalid input. Same-ID registration updates geometry/facing and retains damage. |
| `try_cast(hero)` | Empty string on acceptance; human-readable rejection otherwise. |
| `cast_unavailable_reason(hero)` | Same availability check without consuming cooldown or changing state. |
| `tick(delta, hero)` / `cancel_channel()` | Advance authoritative simulation / cancel only a held channel. Invalid negative or nonfinite deltas do nothing. |
| `damage_for_arena(id)` / `damage_for_enemy(arena, enemy)` | Read cumulative damage. |
| `phase_size(id)` / `completed_phases(id)` / `damage_in_phase(id)` | Read absolute threshold, complete layers, and current remainder. |
| `enemy_footprint(arena, enemy)` / `is_occupied(arena, cell)` | Read explicit targeting/movement geometry. |
| `cooldown_remaining()` / `active_remaining()` / `is_channeling()` | Read the sole chosen hero's timers. |
| `active_cast_snapshot()` | Restore presentation after stage replacement without replaying gameplay. |
| `advance_enemy_dots(arena_id)` | Advance that arena's attached stacks by exactly one 60 Hz tick; commit due damage and expiry before notifying observers. |
| `clear_enemy_dots(arena_id)` | Remove only that arena's stacks without discarding earned damage. |
| `enemy_dot_effects(arena_id, enemy_id)` | Read grouped stack counts, authored ability names and next-expiry timers for the target. |

Future minions and sub-bosses use distinct enemy IDs and the same registration path. The shell currently uses `boss:<arena_id>` for all nine targets, including the Guild training construct. Registering a target does not spawn art or create a health/death system.

Support state is separate from the hero sprite. `register_ally(arena_id, actor_id, cell, health = 1, max_health = 1, debuffs = PackedStringArray())` stores capped health and debuffs; re-registration intentionally replaces those values. `move_ally()` changes location without resetting support values, and `ally_status()` returns a defensive copy. The sole caster is synchronized under reserved ID `"hero"`, starts at 1/1 support health, and carries that state across arena travel. Registering allies creates no extra heroes or rendered units. Zero support health does not disable prototype attacks.

The model emits `ability_cast(caster_id, ability_id, arena_id, origin, target_cell, facing)`
at accepted windup, `damage_applied(arena_id, enemy_id, amount)` for actual hits,
and `progress_changed(arena_id)` when the ledger changes. Each accepted hit also
emits `damage_reported(caster_id, ability_id, arena_id, enemy_id, amount)` for
the [activity feed](activity-events.md). Effects and messages observe these
signals; they never award damage. Held-channel catch-up processes at most 64
ticks per call and retains remaining time debt, keeping an unusually large
timestep bounded without dropping hits.

Sound consumes `ability_phase(ability_id, phase, arena_id, cell, cast_id)`, which distinguishes charge, release, actual impact, sustain, completion and cancellation. Auto Shot and Acid Flask release after 0.26 seconds, clamped to their hit time. Fast release/hit/completion sequences retain their one-shot sounds. Profiles and bounded playback are documented in [ability audio](ability-audio.md).

`ArenicClassAbility` exposes damage, cooldown, cast time, range, duration, tick interval, enemy DOT duration/interval/damage, adjacency/backstab requirements, area size, radius, and the Fortune loot coefficient. `boss_combat_size` and `phase_damage` are independently authored per arena. Preserve all-one damage while this normalization is the intended balance. Native source-frame duration is not a gameplay clock; presentation must consume the authored cast timing while damage remains authoritative in the model.

## Native assets and validation

Only these eight starter actor animations and their associated FX are approved for runtime integration. Saved `.aseprite` masters remain under `assets/characters/`; the dedicated exporter writes `arenic-game/assets/abilities/` and `starter_catalog.tres`. Actor canvases remain 19 × 19 with `(9, 9)` pivots, source tags and frame durations preserved, lossless textures and nearest filtering. FX retain their authored canvases and pivots. The focused arena still uses exactly 19 logical pixels per tile; no sprite resizing is used to change gameplay reach. See [the art pipeline](../assets/README.md).

The other 24 studied abilities and their sound effects remain source-side previews. The eight starters now have 22 authorized ElevenLabs cues including shared movement/collision sounds; their separate sound director preserves existing spatial arena music.

Validated on macOS with Godot 4.7.2: all **16 headless and 5 renderer checks passed**. Combat coverage includes 281 pure-model assertions, 212 scene/input assertions across all eight class choices, 2,092 presentation/resource assertions, 43 damage-HUD assertions, and 182 SFX assertions. The suite checks nearest-target ties, all Backstab facings, channel cancellation, support healing/debuffs, exact Fortune ticks, independent totals, phase overflow, stage handoff, bounded effects, native frame data, HUD geometry and sound lifecycle. A visible native Auto Shot playtest also confirmed target damage and bar fill.

The three Chromium combat tests passed against the isolated Web export using real menu choices, keyboard and pointer input: Hunter hit/cooldown/overview selection, Cardinal channel release/movement cancellation, and Merchant movement plus exactly 20 timed Fortune hits. Framebuffer samples and screenshots verify the completed-phase foundation remains visible. These are behavior and rendering checks, not a cross-browser or 60-fps performance claim. The September 10 audio revision passed **28 Chromium cases**, run as two focused SFX cases followed by 26 combat/site/navigation/density/music regression cases. See the [browser suite](../tests/web/README.md).

Concurrent Sacrifice regression coverage exercises the full 320-member bound,
independent arena pauses and cancellation, hit-pool pressure, restoration without
new damage, and the highest caster's real rewind capture/masks/clones. The
browser case records a third Cardinal beside two recorded channels, checks all
three beam animations, releases only the recorder, and reloads both remaining
channels from IndexedDB. Native durability uses separate writer/reader processes.
