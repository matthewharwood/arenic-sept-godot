# Main-game HUD

The HUD belongs to the existing Godot `GameShell`, outside its replaceable
`OverworldStage`. It retains each arena's glass palette, the damage/phase strip,
all nine themed environments, existing combat, and the 1280 × 720 logical layout.
The top/bottom insets remain 35/96 pixels, preserving the 589-pixel world band and
native 19-pixel tiles. No alternate game or sample roster is launched.

The bottom strip provides forty roster positions, hero vitals, four fixed ability
slots, a reserved record control, and a 3×3 arena map. The run still contains the
one chosen starter hero. Empty positions use X; a fallen entry uses a skull and
selection uses blue. The roster view supports stored overflow, exposing omitted
entries in a scrollable reserve panel while keeping the selected identity visible.
No extra characters are created to fill the display. The map reflects actual hero
location and arena selection, with a black active cell and read-only Normal raid
information. There is no fabricated prize or recording activity.

| Control | Behavior |
| --- | --- |
| Tab / Shift+Tab or roster | Find and select the current hero |
| [ / ] or map buttons | Select the previous / next arena |
| 1 / Space / first ability button | Use the existing starter ability; hold/release channels |
| 2 / 3 / 4 | Fixed unassigned positions; no abilities are invented |
| R | Reserved recording information |
| H | Show / hide controls |
| P / Enter / wheel | Existing overview and zoom controls |
| Arrows | Existing hero movement or arena navigation |

Authored starter names such as Dean and King remain intact. Future unnamed heroes
can use the deterministic 100-first-name × 100-surname identity table; the first
10,000 IDs have distinct name pairs. Hero identity, level, and XP belong to the
run state and survive stage replacement. XP begins at zero; this UI change does
not invent XP awards or level-up rules. HP and debuffs read the existing combat
ally ledger, avoiding a second source of health.

Semantic OKLCH tokens keep HP/selection blue, XP/gains green, and damage/debuffs
red while inheriting each arena's text and surface colors. HP/XP bars ease toward
changes, with at most eight short floating numbers. Changing selection clears old
feedback. Debuffs appear before buffs, sorted by earliest expiry within each
kind. The current untimed combat debuffs show their names without a fabricated
duration; Fortune's aura uses its actual remaining combat time. Future timed
effects use the same view contract. Long effect lists retain full tooltips and a
visible overflow count.

Global chat and recording simulation remain outside this iteration. Existing
starter attacks, channels, cooldowns, sound, damage phases, and navigation remain
authoritative in the original physics-driven model.
