# Auto Shot effects

Base bow attack; no marking crosshair or damage-amplification effect.

| Source | Canvas / pivot | Animation |
| --- | --- | --- |
| [projectile.aseprite](projectile.aseprite) | 19 × 9 / tip (17, 4) | `flight_e`: four 80 ms frames, loop |
| [impact.aseprite](impact.aseprite) | 19 × 19 / contact (9, 9) | `impact`: 40, 50, 60, 70, 80 ms, once |

Both are viewed directly overhead, use the Hunter palette, and keep separate
editable layers. The arrow
points east; gameplay moves it from its tip and chooses the hit. The impact
ends transparent. Emit the arrow on the fourth frame of the chosen direction's
attack tag, at 260 ms. The full actor
gesture is 700 ms; gameplay's 2.5-second Auto Shot cadence remains separate.

Review sheets and exact metadata are in the Hunter's
[preview manifest](../../../previews/source-manifest.json). Native sources
are authoritative; no final runtime files have been exported.
