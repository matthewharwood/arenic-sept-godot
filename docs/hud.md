# Main-game HUD

The HUD belongs to the existing Godot `GameShell`, outside its replaceable
`OverworldStage`. It retains each arena's glass palette, the arena damage strip,
all nine themed environments, existing combat, and the 1280 × 720 logical layout.
The top/bottom insets remain 35/96 pixels, preserving the 589-pixel world band and
native 19-pixel tiles. No alternate game or sample roster is launched.

The top strip contains the current arena's full-width damage-taken progress
bar, its authored name, active boss conditions, and right-aligned recruitment
progress, hero-ready [N] and loot-ready controls. Conditions use the remaining
space and retain full details in tooltips.
The name and effect list follow arena selection; the progress bar reads that
arena's cumulative damage and retains its existing layered progression.

`ArenicEncounterState.boss_effects(arena_id)` derives conditions from the actual
boss footprint, cycle clock, and hazard fields. Airborne shows the time until
landing in green; Acid and Broken ground contact appear in red, with real expiry
or affected-tile counts. Cleanse appears in the same debuff color as
`Cleanse ×2 [5s]`: the multiplier counts independent active stacks on that boss,
and the timer rounds up the time until the next stack expires. Its tooltip
explains that each stack expires independently; one stack omits the multiplier,
and the last expiry removes the readout. Unlike ground contact, the applied
Cleanse status remains visible while the boss is airborne. Green means beneficial
to the boss. Unimplemented
conditions such as Bleed or Haste are never invented to fill the row. Empty state
shows no chips. Long lists show an overflow count with full tooltip details.
These are transient observations, not a second effect model or save authority.

New guilds first see the quote and Keeper conversation described in [the introduction](introduction.md). Space talks to the nearby Keeper outside an active recording; the introduction owns navigation and attacks until its gates finish opening.

The bottom strip provides forty roster positions, hero vitals, four fixed ability
slots, the record control, Global Chat, and a 3×3 arena map. A new run begins with
one chosen starter hero. Empty positions use X; a fallen entry uses a skull and
selection uses blue. The roster view supports stored overflow, exposing omitted
entries in a scrollable reserve panel while keeping the selected identity visible.
Overworld clears hero selection and its roster highlight; the remembered hero's
vitals remain visible as navigation context. Zooming alone does not select that
hero again; Tab or a roster click selects it explicitly.
No extra characters are created to fill the display. The map counts running
ghosts in each arena, with a black active cell and read-only Normal raid
information. Its tooltip also reports how many guild members are present.

Hero vitals share one baseline for the name on the left and class on the right.
XP and HP reserve their full measured text heights, followed by 3-pixel bars with
1-pixel gaps; debuffs and buffs keep separate rows below. Long names, classes,
and stat lines use ellipses while retaining their complete values in tooltips,
so the compact panel stays within the existing HUD height.

The five action buttons are 70 × 70 logical pixels
with 12-pixel corner radii and share the same normal, hover, and pressed shapes.
In overworld they open Rotate selected (1), Roster (2), Loot (3), Auction (4), and
Craft (R) in one tabbed menu. Titles and hotkeys come from `ArenicOverworldActions`;
the Loot tab projects collected equipment and offers a button for banked loot
draws. The other tabs remain empty. Rotate selected wraps
within its button. Combat and recording feedback stay hidden in this mode, and
opening the menu closes the HUD's Controls, reserve-roster, and chat popovers.

Zooming into an arena restores the four ability buttons and Record/Ghost control,
including their latest combat and recording readouts.
Each title is centered above an internal feedback row, with its hotkey (1–4 or R)
separately aligned at the bottom-right in the selected arena's `accent` color. Slot 1 shows the authored
starter title; slots 2–4 show an em dash and remain disabled. These button styles
are separate from the square HUD controls. Their labels do not intercept pointer
input, so existing press/release and held-channel behavior stays intact. The
recording countdown and live clock occupy that feedback row below Record/REC;
active recording stays red, and R always uses the arena accent. Ability feedback
prioritizes a held channel, finite active time, cooldown, then a short availability
or notice state such as No target, Get behind, or Staff saved. Short feedback is
supplied explicitly alongside its full description, without parsing hint text.
Titles and feedback are measured to fit their separate rows.
Long instructions and notice details stay in the tooltip; there is no hint label
below the action row. The 96-pixel HUD strip and world viewport stay unchanged.

Global Chat is a system activity feed from all nine arenas. Its 270 × 88 logical
pixel view sits between Record and the raid map, with four recent lines inside
a 12-pixel outline. Press C or click its header to open a scrollable 100-entry
history. The expanded view offers All activity, Notices, Warnings +, and Important
filters. Unclaimed hero availability remains pinned in red while routine damage
rows appear in gray as `Dean · Auto Shot · 3 damage · Labyrinth`. Hero and attack
come first, and different attackers retain separate totals. Long rows remain
available in full through the tooltip and expanded history. Importance and
severity are separate fields. The full
[event contract](activity-events.md) defines delivery, colors, and retention.

H opens the controls menu above the lower-right HUD. It contains Overview/Zoom,
Save & Title, and Close H. The menu measures its text before placing the footer,
and its own canvas layer keeps Save & Title accessible during the introduction.
The existing P/Enter/wheel shortcuts remain available;
choosing Overview closes the menu. Save & Title uses the existing save facade,
including its simulation pause during the final commit and visible error handling.

Recruitment sits at the top-right. Progress toward the next unearned threshold
stays visible as `Next hero 16/102`, with banked rolls separately shown by a green
`2 [N]` button. An adjacent Loot button shows pending arena rewards. Claiming a
roll changes its badge without spending damage; ready badges disappear at zero.
Large progress counts compact to K/M/B with exact values in their tooltips.
Rewards reserve their measured widths before the arena title and boss conditions
are laid out, so no condition text can overlap them.

The full-screen arena-themed reward view contains three square cards. Hero
portraits reveal with a 0.11-second stagger and 0.26-second entrance, then accept
one selection. Loot cards share concealed arena backs; selecting one locks all
three inputs and flips the awarded item over 0.34 seconds. Later/Escape banks
an unclaimed choice; Continue closes a claimed result. Keyboard 1–3 maps to the
visible card order. The view captures input while all arena clocks continue.
New reward attention waits during recording, countdown and other decisions.

| Control | Behavior |
| --- | --- |
| Tab / Shift+Tab or roster | Find and select the current hero |
| [ / ] or map buttons | Select the previous / next arena |
| 1 / 2 / 3 / 4 / R in overworld | Open Rotate selected / Roster / Loot / Auction / Craft |
| 1 / Space / first ability button when zoomed | Use the existing starter ability; hold/release channels |
| 2 / 3 / 4 when zoomed | Fixed unassigned positions; no abilities are invented |
| R when zoomed | Start the recording countdown; abort it, or review an active take |
| C / Global Chat header | Expand or collapse system activity history; Escape closes history before changing the world view |
| H | Show / hide controls and Save & Title |
| N / top-right hero-ready badge | Reopen three revealed hero choices without spending the banked roll |
| Top-right Loot badge | Open three concealed cards and reveal one equipment reward |
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

Starter attacks, channels, cooldowns, sound, damage phases, recording, and
navigation remain authoritative in the original physics-driven model. The feed
observes those actions and creates no gameplay effects.
