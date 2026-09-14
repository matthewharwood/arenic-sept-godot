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
| `growth` | 1.6 | Multiplier during the opening four rolls. |
| `growth_rolls` | 4 | Retains opening costs 40, 64, 102, and 164. |
| `late_cost_step` | 48 | Additional damage cost per later roll. |
| `offers_per_roll` | 3 | Three revealed hero cards; Later is a separate action. |

The table precomputes all 319 earned recruits, alongside the founding hero.
The linear tail avoids the former exponential cutoff. The first balance pass
targets **10–20 hours of active play**: at 40 damage per 120 seconds per Hunter
and an average 80% of the growing guild deployed, the cost table models about
15.8 hours and 2,440,990 cumulative damage for the complete 320-member guild.
This is a reference estimate, not measured player completion time; travel,
recording quality, deaths, support classes and Dig change actual earnings.
The curve is authored separately so later playtests can tune it.

| Guild size | Cumulative earnings | Reference active hours |
| ---: | ---: | ---: |
| 40 | 36,350 | 1.84 |
| 80 | 149,470 | 3.82 |
| 160 | 606,110 | 7.80 |
| 320 | 2,440,990 | 15.78 |

These estimates use the same Hunter/deployment assumptions above and immediate
recruitment as each threshold is crossed; they are useful balance checkpoints.

## Rolling

Newly earned recruitment opens three portrait cards with a short staggered
reveal. All three are face up, use the viewed arena’s theme, and show the existing
hero portrait, class and starter ability. Click a card or press 1–3 to select it.
**Later / Escape** closes the cards without spending the roll; **N** or the
top-right ready button reopens the same choices. Battles continue beneath the
view. New reward attention waits during recording/countdown, introduction,
sequences and other decisions instead of consuming recording input.
A saved closed view stays closed; banked choices remain available with N. A recruit arrives at Guild House `(30, 15)`,
**unrecorded and controllable** — it is a hero that now needs a staff, which is
where the loop begins again.

Offers are drawn from a seed derived from the roll's own index, so a roll shows
the same three classes however long it is left unopened, and a run replays
identically. One roll never offers the same class twice; a later roll may offer a
class again, because a guild wants more than one of most of them.

The guild is capped at 320 members, and any one arena at 40 ghosts.

## Equipment rewards

Natural completed combat-arena loops have a separate [loot draw](loot.md), with
three concealed cards and one awarded equipment item. These do not consume hero
rolls. Collected weapons, armor and accessories appear in the overview Loot tab.
Equipment power and rarity are collection data in this pass; equipping, stat
bonuses, trading and crafting are separate future gameplay work.

## Compatibility

Schema 11 adds the loot ledger. Existing recruitment indices and claimed rolls
remain unchanged, so existing three-class offers stay identical. The lower late
thresholds retain every old earned roll and may grant additional banked rolls to
an established guild. Saved recruitment modals normalize to the new card flow and
release their former arena pause. New card visibility and motion are transient;
only the existing roll index and the loot ledger determine ownership.
