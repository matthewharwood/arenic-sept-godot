# The guild

A run founds a guild with one chosen hero and grows it by fighting. Damage dealt
anywhere is the run's one currency; crossing a threshold earns a **roll**, and a
roll deploys a new hero to the Guild House.

The loop closes on itself. You beat on a boss by hand until you can afford a
second hero, then you [record](recording.md) the first as a ghost so it keeps
earning while you play the second. Ghosts are income, which is what makes
recording worth doing rather than merely possible.

## Earning

Two incomes feed the same total: **damage dealt** anywhere, and **ground broken**
by the Forager's [Dig](combat.md#digging). `ArenicCombatState.total_damage()`
plus `RunSetup.prospected` is the run's whole earnings, cumulative and monotonic. **Damage is never spent** — a roll is a milestone
crossed, not a balance drawn down — so a player deep in an arena never loses a
reward for not stopping to collect it. Banked rolls wait indefinitely.

Thresholds are authored in `data/guild/recruitment.tres`:

| Field | Default | Meaning |
| --- | ---: | --- |
| `first_roll_damage` | 40 | About one two-minute cycle of a single committed Hunter ghost. |
| `growth` | 1.6 | Each roll costs this much more than the one before. |
| `offers_per_roll` | 3 | Choices presented, leaving a fourth slot to decline. |

Geometric growth is clamped rather than allowed to overflow, and the threshold
table is precomputed once because the read-out asks for progress every frame.

## Rolling

**N** claims a banked roll. It presents three classes plus **Later**; declining
never spends the roll. A recruit arrives at Guild House `(30, 15)`,
**unrecorded and controllable** — it is a hero that now needs a staff, which is
where the loop begins again.

Offers are drawn from a seed derived from the roll's own index, so a roll shows
the same three classes however long it is left unopened, and a run replays
identically. One roll never offers the same class twice; a later roll may offer a
class again, because a guild wants more than one of most of them.

The guild is capped at 320 members, and any one arena at 40 ghosts.

## Not built yet

The design also calls for **upgrades** in the same roll — picked and given to a
hero rather than recruiting. The roll modal and the choice format already carry
per-option payloads, so an upgrade offer joins the same list without changing
either; what an upgrade *is* (a stat, a level, an ability) is still an open
design question.
