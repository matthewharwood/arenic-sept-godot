# Merchant artwork

The portrait guides the dark plum and gold coat, swept black hair, teal scarf, coin purse, cards, and turquoise dice. Coin Toss exposes a growing gold coin during the charge and releases it into its independent projectile source.

All actor sources are transparent **19×19** layered Aseprite files, one grid cell at **1280×720 / 1×**, with center pivot **(9, 9)**. Four cardinal directions are exact 90-degree rotations. There are no faces, front torsos, or standing boots. The [idle source](merchant.aseprite) has four 200 ms frames tagged `idle_n`, `idle_e`, `idle_s`, and `idle_w`.

The native `.aseprite` masters are authoritative. Each actor has seven named layers; each effect has three. Colors are authored in the [OKLCH palette](../../palettes/merchant.oklch.json) and converted at the Aseprite pixel boundary.

## Base abilities

Each full ability tag is named `<id>_n`, `<id>_e`, `<id>_s`, or `<id>_w`. Durations below are per direction and are separate from cooldowns and gameplay lifetimes.

| Ability | Source ID | Frames per direction | Duration | Release |
| --- | --- | ---: | ---: | ---: |
| [Coin Toss](abilities/coin_toss/merchant_coin_toss.aseprite) | `coin_toss` | 14 | 5400 ms | 5000 ms |
| [Dice](abilities/dice/merchant_dice.aseprite) | `dice` | 6 | 500 ms | 0 ms |
| [Fortune](abilities/fortune/merchant_fortune.aseprite) | `fortune` | 6 | 600 ms | 0 ms |
| [Vault](abilities/vault/merchant_vault.aseprite) | `vault` | 6 | 600 ms | 0 ms |

Coin Toss shows the maximum 5000 ms hold followed by release and 400 ms recovery. Runtime may release earlier; it must sample or hold the charge poses according to actual input. The projectile and payout are independent. A preview payout stages a success and does not guarantee the base 80% money-return chance.

Dice is an instant self-buff: the roll becomes an orbiting stack indicator, not an attacking projectile. Gameplay owns the one-percent stack gain, fifty-stack cap, and consumption on a critical hit. Fortune is an economic aura with a two-tile range and 20-second lifetime; its local ring is not a damage or healing effect.

Vault is a 76×76 source matching four-by-four 19-pixel cells. It opens visually for 700 ms but its critical-damage buff activates immediately. The loop and critical accent remain independent of the gameplay-owned ten-second duration. No upgraded defensive, permanent, or resource-generating fortress is included.

## Independent effects

Coordinates are zero-based pixels in the full-canvas `frame` slice. Canvases and pivots are fixed across every frame.

| Source | Tag | Canvas | Pivot | Duration / playback |
| --- | --- | --- | --- | --- |
| [Coin Toss / coin](abilities/coin_toss/fx/coin.aseprite) | `flight_e` | 19×19 | (9, 9) | 400 ms / loop |
| [Coin Toss / payout](abilities/coin_toss/fx/payout.aseprite) | `payout` | 19×19 | (9, 9) | 800 ms / once |
| [Dice / dice](abilities/dice/fx/dice.aseprite) | `roll` | 19×19 | (9, 9) | 500 ms / once |
| [Dice / dice](abilities/dice/fx/dice.aseprite) | `orbit_loop` | 19×19 | (9, 9) | 1000 ms / loop |
| [Dice / lucky](abilities/dice/fx/lucky.aseprite) | `lucky` | 19×19 | (9, 9) | 500 ms / once |
| [Fortune / fortune](abilities/fortune/fx/fortune.aseprite) | `fortune_loop` | 38×38 | (19, 19) | 1000 ms / loop |
| [Fortune / prosperity](abilities/fortune/fx/prosperity.aseprite) | `prosperity` | 19×19 | (9, 9) | 700 ms / once |
| [Vault / vault](abilities/vault/fx/vault.aseprite) | `open` | 76×76 | (38, 38) | 700 ms / once |
| [Vault / vault](abilities/vault/fx/vault.aseprite) | `vault_loop` | 76×76 | (38, 38) | 1000 ms / loop |
| [Vault / critical](abilities/vault/fx/critical.aseprite) | `critical` | 19×19 | (9, 9) | 600 ms / once |

The [manifest](hero.json) records source documents, timing, effect roles, staged preview behavior, and sound-cue descriptions. Cast and impact audio hooks describe production targets; their existence does not establish that audio has been generated.

## Review and handoff

Open the [shared attack gallery](../../previews/merchant/attacks.html) for native-scale staging. Source-side [actor contacts](previews/actors-contact-4x.png) show all north frames; [effect contacts](previews/effects-contact-2x.png) show four phases of each effect tag in manifest order. The `previews/` folder also contains native-timed actor and state-specific effect GIFs. Those are derived review files.

[Validation readback](previews/validation.json) checks native dimensions, frame and tag timing, pivots, exact cardinal pixel rotations, binary transparency, and a one-pixel transparent margin around every actor frame. Contact frames and MCP previews were visually inspected; they do not replace full-speed playback review or an actual Godot playtest.

All editable sources and previews remain outside `arenic-game/`. Future runtime output mirrors this folder under `arenic-game/assets/characters/merchant/`, at native 1× dimensions with tags and slices. No final texture or metadata export is performed by this artwork task. Game movement, collision, targeting, ability outcomes, resource costs, and effect lifetime remain gameplay-owned. The gallery is a concept preview, not game integration.
