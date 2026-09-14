# Ability ownership audit

This covers all **eight currently playable starter abilities**. The remaining
24 ability designs are preview-only and have no runtime casts to validate yet.
They must meet this same contract before becoming playable.

| Ability | Authoritative owner | Presentation and cancellation |
| --- | --- | --- |
| Auto Shot | Per-hero cast ID and frozen flight | Reserved projectile; actual shooter/ability on impact; independent restore. |
| Bash | Per-hero windup and hit resolution | Hero-owned actor animation; caster-specific impact/number budget. |
| Backstab | Per-hero cast, accepted facing and position checks | Hero-owned actor animation; impact uses its own cast facing, even after another class casts. |
| Acid Flask | Per-hero flight; independent arena pool records with caster provenance | Reserved flask; correctly attributed impacts; arena pools survive their caster's completed cast. Overlapping ground intentionally shows strongest coverage without deleting either pool. |
| Sacrifice | Per-hero held cast and accepted target identity | Reserved aura plus up to four strips; ending another channel cannot remove them. |
| Cleanse | Immediate per-caster cleanse plus independent enemy DOT records | Reserved finite wave; separate feedback budget; DOT ticks use their recorded caster and ability. |
| Dig | Arena/cell ground state, first-digger provenance | Reserved finite excavation; other cells and arenas retain their dug state. Digging one already-broken tile does not create a second ground owner. |
| Fortune | Per-hero finite aura cast and elapsed time | Reserved following aura; its own model completion controls removal. Multiple Merchants and a selected non-Merchant coexist and reload correctly. |

## Boundaries corrected

Fortune used a global presentation timer and ability-wide stop. Projectiles and
short cast effects shared the disposable sixteen-effect pool. Damage effects
used the last observed cast's ability/caster/facing, which could mislabel delayed
hits after another class acted. Those shared ownership shortcuts are removed.

Each caster has sixteen lazily allocated temporary slots, separate from five
reserved active-cast slots. Unknown legacy damage has its own temporary bucket.
One caster can replace its own oldest temporary feedback under heavy fan-out;
it cannot evict another caster or its own reserved ongoing ability. No unbounded
node allocation or queue is introduced. Rewind track indices include every legal
slot; the existing global sampled-pose memory budget is preserved.

The model already stores casts/cooldowns per hero, with stable advancement order.
Acid pools, Cleanse DOTs and dug ground already preserve their intended arena,
target and caster identities. Those authoritative rules and save fields are
unchanged. Reload rebuilds presentation from the existing cast snapshots;
finished one-shot animations are not replayed and restoration awards no damage.

## Audio boundary

Ability audio currently follows the controlled hero by design. Its event filter
rejects other casters before processing phase changes, and loop cancellation
uses the accepted cast ID. Ghost casts remain silent. The twelve-voice mix and
same-cue coalescing are deliberate audio limits, not visual effect ownership.
This audit does not introduce multi-hero audio or change existing sound timing.

## Regression and future abilities

The presentation check exercises every ordered pair of the eight abilities,
including same-class pairs, a delayed first hit after the second cast, pressure
on the second caster's temporary budget, and filtered cleanup. A catalog coverage
assertion requires this matrix to expand when another ability is implemented.

Capacity cases exercise all 320 supported identities with Sacrifice and with a
mixture of Auto Shot, Acid Flask and Fortune. They check independent arena pause,
selection, cancellation, restoration without damage, and the highest rewind
track. Separate native writer/reader processes restore six simultaneous mixed
casts. Browser coverage records a third Cardinal beside two channels and a Bard
beside two Merchants, two Hunters and two Alchemists, then reloads their saves.

For a new runtime ability:

1. Keep cast/target/cooldown authority keyed by hero and accepted cast identity.
2. Carry actual caster/ability/arena provenance into hit and phase events.
3. Choose an explicit reserved or per-caster transient visual lifetime; never
   clear effects merely because another hero uses the same ability.
4. Define arena pause/reset behavior and restore derived state from the shared
   codec without replaying gameplay or persisting nodes/audio/input.
5. Extend same-class and mixed-class ownership tests, capacity bounds and real
   native/browser restart proof where the ability persists through a save.
