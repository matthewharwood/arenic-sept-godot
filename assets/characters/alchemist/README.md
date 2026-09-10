# Alchemist artwork

True overhead **19 × 19** character frames, centered at **(9, 9)**, with north,
east, south, and west tags. The portrait informs the maroon pointed hood, gold
trim, bone hands, open parchment book, and purple/green glass flasks. The crown
and equipment are seen from above; there is no face or upright body view.

[alchemist.aseprite](alchemist.aseprite) contains four directional idle poses.
Each attack is in `abilities/<id>/alchemist_<id>.aseprite`; independently editable
projectiles, fields, and channels are under its `fx/` folder. Seven character
layers keep robes, trim, kit, arms, crown, held focus, and cast accents separate.
The [OKLCH palette](../../palettes/alchemist.oklch.json) is the color source.

| Base ability | Frames per direction / total duration | Gameplay release | Separate effects |
| --- | --- | --- | --- |
| [Acid Flask](abilities/acid_flask/alchemist_acid_flask.aseprite) | 8 / 800 ms | 260 ms throw; 800 ms flight afterward | Glass flask, shatter, bubbling acid pool |
| [Ironskin Draft](abilities/ironskin_draft/alchemist_ironskin_draft.aseprite) | 6 / 600 ms | Instant; drinking is cosmetic | Metallic hardening, protective shimmer |
| [Siphon](abilities/siphon/alchemist_siphon.aseprite) | 11 / 1600 ms preview | 500 ms setup | Ally-to-Alchemist life link, ally drain contact, self gain aura |
| [Transmute](abilities/transmute/alchemist_transmute.aseprite) | 10 / 2000 ms | 1500 ms channel | Golden item connection, neutral conversion flash |

Full tags are `<ability>_n/e/s/w`; phase tags are `n/e/s/w_<phase>`. Siphon's
local frames 6–9 form an **800 ms repeating channel**, followed by an illustrative
release. Gameplay decides when to stop it. Transmute's channel is 1500 ms once.

All square effects use a center pivot: **(9, 9)** for 19 × 19 and **(19, 19)**
for 38 × 38. The east-facing `life_link` is 76 × 19 with caster pivot **(1, 9)**
and ally endpoint **(74, 9)**; motes flow **right to left**, toward the Alchemist.
The 38 × 19 `gold_link` uses origin **(1, 9)** and item endpoint **(36, 9)**,
flowing left to right. Links attach to actual entities; the drawn span does not
limit gameplay range. Link files include a separate 500 ms `dissipate` tag where
applicable. `gain_aura` belongs on the Alchemist, not the drained ally.

Game rules own the Acid Flask's 1.5-tile pool radius/15-second lifetime, the
Ironskin Draft's 8-second self protection, Siphon's consent/range/8-second cap,
and Transmute's uncertain outcome. The compact 38-pixel acid field is a visual
motif; its canvas is not the damage radius. No upgrade behaviors are drawn.

[hero.json](hero.json) defines source paths, timing, preview intent, and audio
briefs. [source-audit.json](source-audit.json) records saved-file verification.
`previews/` beside each source contains MCP GIFs, native frame PNGs, and contact
sheets. These are review files; layered `.aseprite` masters remain authoritative.
No game textures, runtime metadata, or audio were exported by this art pass.
