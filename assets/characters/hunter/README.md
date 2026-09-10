# Hunter artwork

The Hunter has four cardinal idle poses and four base attack animations.
Character frames are **19 × 19**, occupying one **19-pixel grid cell** at the
default **1280 × 720** resolution, with center pivot **(9, 9)**. The view is true
overhead orthographic: no visible face, front torso, or standing boots. North,
east, south, and west are exact 90-degree rotations around that center.
Equipment, body, and effects remain editable layers.
All coordinates below are zero-based source pixels in the full-frame `frame`
slice. Preserve the fixed canvases and apply nearest-neighbor display scaling.

- [hunter.aseprite](hunter.aseprite): four 200 ms idle frames, tagged `idle_n`,
  `idle_e`, `idle_s`, and `idle_w`, one frame per direction.
- `abilities/<ability>/hunter_<ability>.aseprite`: character attack source.
- `abilities/<ability>/fx/`: independent projectiles, impacts, status, or trap sources.
- `previews/`: review material, including the [attack gallery](previews/attacks.html).
- Each FX folder contains timing/anchor notes and a source summary. Layered
  `.aseprite` files are authoritative; PNGs, GIFs, and the gallery are derived.

## Character attacks

Each full tag plays once. Animation duration includes recovery; it does not
define the ability's cooldown or projectile travel time.

| Source | Full tags | Frames per direction / duration | Total frames | Release or placement |
| --- | --- | --- | --- | --- |
| [Auto Shot](abilities/auto_shot/hunter_auto_shot.aseprite) | `auto_shot_n/e/s/w` | 8 / 700 ms | 32 | Release at 260 ms |
| [Poison Shot](abilities/poison_shot/hunter_poison_shot.aseprite) | `poison_shot_n/e/s/w` | 12 / 1160 ms | 48 | Release after 500 ms preparation |
| [Sniper](abilities/sniper/hunter_sniper.aseprite) | `sniper_n/e/s/w` | 10 / 960 ms | 40 | Release after 500 ms aim |
| [Trap](abilities/trap/hunter_trap.aseprite) | `trap_n/e/s/w` | 6 / 500 ms | 24 | Gameplay placement at 0 ms; gesture is cosmetic |

Tag notation above abbreviates four separate tags: for example, `auto_shot_n`,
`auto_shot_e`, `auto_shot_s`, and `auto_shot_w`.

Auto Shot is the basic bow attack on the rulebook's **2.5-second cadence**, with
no Mark Target sequence. The supplied `auto_shot.md` describes Mark Target;
the user's explicit choice resolves that conflict in favor of the rulebook.
Poison Shot includes 200 ms of recoil after release; gameplay owns the one-tile
displacement.
Sniper retains the bow and fires one precision arrow. These files contain the
base abilities in all four cardinal directions, without upgrades.

## Independent effects

| Source | Canvas | Tags / duration | Pivot |
| --- | --- | --- | --- |
| [Auto arrow](abilities/auto_shot/fx/projectile.aseprite) | 19 × 9 | Flight: 4 frames, 320 ms loop | Tip (17, 4) |
| [Auto impact](abilities/auto_shot/fx/impact.aseprite) | 19 × 19 | Impact: 5 frames, 300 ms once | Contact (9, 9) |
| [Poison arrow](abilities/poison_shot/fx/projectile.aseprite) | 19 × 9 | `flight_e`: 320 ms loop | Tip (17, 4) |
| [Poison impact](abilities/poison_shot/fx/impact.aseprite) | 19 × 19 | `impact`: 1000 ms once | Contact (9, 9) |
| [Poison status](abilities/poison_shot/fx/affliction.aseprite) | 19 × 19 | `afflicted_loop`: 1000 ms loop | Target center (9, 9) |
| [Sniper arrow](abilities/sniper/fx/projectile.aseprite) | 19 × 9 | `flight_e`: 200 ms loop | Tip (17, 4) |
| [Sniper impact](abilities/sniper/fx/impact.aseprite) | 19 × 19 | `impact`: 500 ms once | Contact (9, 9) |
| [Sniper reticle](abilities/sniper/fx/reticle.aseprite) | 19 × 19 | `lock_on`: 500 ms once; `locked_hold`: 320 ms loop | Target center (9, 9) |
| [Trap](abilities/trap/fx/trap.aseprite) | 19 × 19 | `place`: 500 ms; `armed`: 1000 ms loop; `trigger`: 100 ms | Cell center (9, 9) |
| [Trap explosion](abilities/trap/fx/explosion.aseprite) | 38 × 38 | `explode`: 1000 ms once | Effect anchor (19, 19) |

Arrows are authored pointing right/east with fixed tips; gameplay supplies
position, direction, speed, and hit detection. Their loops animate the trails.
Attach impacts to contact points and status effects to their documented anchors.
The Sniper reticle runs during aim and disappears on release or cancellation;
its optional hold does not extend the base aiming time.

Gameplay owns Poison Shot's 20-second status and 12-second cooldown, Sniper's
four-second cooldown and boss targeting, and the trap's 60-second lifetime and
2 × 2 damage area. Trap placement and damage on triggering are immediate:
placement art adds no arming delay, and the 100 ms trigger overlay runs alongside
the explosion. Ally visibility of the armed indicator is a game rule. Art canvas
size never defines a collision box, damage radius, or gameplay footprint.

## Source and export boundary

These sources stay under `assets/`, outside `arenic-game/`. Review previews are
allowed; **no final game textures or metadata have been exported**. Future
runtime output belongs under `arenic-game/assets/characters/hunter/`, preserving
the ability/FX organization. The pipeline preset covers all 15 current sources.
Reapply it after relocating the checkout. Export at native 1× size with tags
and slices, no trimming, then apply the documented pivots in Godot. The review
gallery is an art preview, not runtime integration. See the
[art pipeline and resolution guide](../../README.md).

The gallery includes a **1280 × 720 arena concept screen** with **66 × 31 cells**
of **19 × 19 pixels**: a **1254 × 589** board. Its closeups default to **1×**, the
actual 720p sprite size, with enlarged integer scales available for inspection.
Full-speed playback, scrubbing, direction selection, and character-only views
support animation review. Its travel and target placement are staged; this is
not actual game integration, and a future 2.5D camera is unimplemented.
Saved frame timing, tags, and pivots are listed in
[source-manifest.json](previews/source-manifest.json).
