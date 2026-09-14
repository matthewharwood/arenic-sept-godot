# The first thread — Guild House introduction

A newly chosen hero enters the Guild House in close view at cell `(33,15)`.
The Jung quote supplied in the plot appears first, once per new guild. After
Begin (Space or click), The Keeper beckons from `(33,18)` with a compact gold
`!` overhead marker. Arrows can move the hero around the clearing; Space or
the marker starts the conversation when the hero is within four cells.

Four short lines introduce R, the three-beat countdown, recording movement and
attacks, and the existing **Commit** choice. Space, Enter, or the Continue button
advances a line after its reading interval. The authored sequence has two seconds
for the opening quote, four 2.75-second reading intervals, and a 1.4-second gate
animation: roughly fifteen seconds with normal clicking, with additional time
available to read. It does not force a player to finish speaking on a deadline.

While the introduction is unfinished, camera navigation, arena hotkeys, map
buttons, recordings, attacks, and edge crossings remain locked. During the
beckoning step the selected hero can walk inside the Guild House. The last line
starts all three exit gates together; passage and normal controls unlock only
after their opening animation finishes. Those three connections lead into the
surrounding eight arenas. The unlocked game stays focused on the chosen hero.
The Keeper remains a noncombat NPC; nearby Space or a click on his sprite can
recall his recording advice when no recording or decision is active. During a recording Space keeps its
normal attack behavior. Ability slot 1 remains the dedicated attack control.

The [shared interaction marker](interaction-markers.md) changes to a gray `?`
after the conversation is accepted. The final line's minimum reading interval
changes it to a gold `?`, indicating readiness to finish through the existing
dialogue controls. Quote, door opening and completed states hide the marker.
These symbols derive from `intro_step` and the transient reading timer; they
add no quest state, rewards or saved fields. Colors have fixed semantic meaning
across arenas, and Keeper uses a plain marker without the optional campaign crest.

Conversations use a transparent half-body Keeper illustration rising above the
left of a parchment dialogue panel, with a dark nameplate and angular gold
threadwork. A light scrim dims the arena behind the conversation; the bottom HUD
remains clear. Name, role and dialogue portrait are authored on the NPC resource.
The name retains its authored casing, so the nameplate reads “The Keeper”.
The nameplate measures the name and role at their actual font sizes, wrapping
within the available text column. The parchment grows with the shaped dialogue
and keeps progress and Continue in a separate padded footer. Content, font and
viewport changes trigger a coalesced remeasurement; short lines can shrink the
panel again. The portrait stays outside the text column and extends behind the bottom HUD. A dedicated clipping container follows the HUD’s world boundary, hiding the transparent hem at one hard edge without clipping the dialogue controls. Narrower logical
layouts can stack the footer controls without overlapping the dialogue. Begin,
Continue, Back and Open the doors include a wide black spacebar keycap with
a white symbol and recessed lower edge. Its native button icon contributes to measured sizing,
responds to disabled/pressed states, and keeps the entire prompt clickable.
This composition is transient presentation and does not change the introduction
steps, reading times or saved run schema.

## Authored data and artwork

- [Introduction resource](../arenic-game/data/intro/guild_introduction.tres): quote,
  attribution, four dialogue resources, reading times and gate timing.
- [NPC definition](../arenic-game/data/npcs/keeper.tres): stable identity, name,
  role, reference portrait, transparent dialogue portrait, world frames, cell,
  interaction radius and typed marker definition. Future NPC definitions
  belong beside this resource.
- [Keeper marker](../arenic-game/data/interactions/keeper_introduction.tres):
  stable interaction/target IDs, category and overhead offset.
- [Keeper source](../assets/npcs/keeper/): built-in Image Gen portrait, exact
  generation prompt and provenance, native layered Aseprite master, OKLCH palette,
  sprite metadata and NPC manifest.
- [Seated Keeper](../assets/npcs/keeper/seated/README.md): current world pose,
  editable 38×38 master, four idle frames and four one-shot beckoning frames.
- [NPC booklet](../assets/previews/npcs/index.html): portrait reference,
  four-facing idle/beckon playback, dialogue and separately disclosed design
  spoilers. [NPC source contract](../assets/npcs/README.md) describes expansion.
- [Gate master](../assets/environment/guild_gate/guild_gate.aseprite): editable
  57×38 overhead sprite with `(28,28)` passage pivot; locked, opening and open tags.

The Keeper’s current world sprite is a strict overhead seated pose on a 38×38
canvas with pivot `(19,19)`. It plays `idle_s` on a loop and `beckon_s` once,
then returns to idle through `animation_finished`. The original standing 19×19
master with pivot `(9,9)` and its cardinal studies remain source references.
Runtime sprites use nearest filtering and the same `0.25 / 19` pixel size as
heroes; both existing portraits are unchanged illustrated artwork, never resized
world sprites. Saved native Aseprite masters own their pixels and timing, and
exports preserve untrimmed regions. His eventual spider form is a narrative
design note; no final-boss combat or transformation is implemented here.

## State, input and restoration

`RunSetup.intro_step` is authoritative and bounded to 0–6: quote, beckon, four
lines, complete. The [save contract](save-state.md) stores it in payload schema 2.
Schema 1 saves migrate to complete, preserving established guilds and pending
legacy character creation. New games start at the quote. A new founder is
centered before combat initialization; hydration never repositions a saved hero.
A save during a line resumes that line, with a fresh reading interval. Completed
quotes, dialogue, and gate opening do not replay. Reading timers, UI, NPC/gate
nodes and animation progress are transient; an interrupted gate opening resumes
at the last line with its doors still locked.

The shell owns the lock and all transitions; the view requests only the next
step. Each accepted step requests a save through `SaveGames.flush()`. Keyboard,
pointer/HUD navigation, and the physics movement boundary obey the same lock.
Gate artwork is a view of this rule, not collision authority. NPCs never enter
the combat ledger, and their dialogue creates no recording or damage. Completion
publishes a normal notice through the shared activity bus.

The new native introduction checks exercise the actual shell, selection, read
intervals, Space consumption, direct HUD guards, every Guild House seam, gate
opening, release and subsequent scene lifetime. Codec/process-restart tests
cover migration and continuation; browser tests complete the real dialogue,
reload a current beat and continue legacy guilds. These are test contracts, not
a deployment claim; release verification is recorded separately.
