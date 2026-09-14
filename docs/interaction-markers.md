# Interaction markers

NPCs and environmental objects share a compact overhead interaction marker.
Its symbol describes actual interaction progress supplied by the owning system;
its category gives that interaction a consistent visual identity. The component
does not create quests, objectives, rewards or completion rules.

## State and category

[`ArenicInteractionMarker.State`](../arenic-game/scripts/interaction/interaction_marker.gd)
describes progress independently of the authored category:

| State | Symbol | Color | Meaning |
| --- | --- | --- | --- |
| `HIDDEN` | None | None | No marker should be shown |
| `LOCKED` | `!` | Gray | Known interaction is unavailable |
| `AVAILABLE` | `!` | Category color | Interaction can be accepted |
| `ACCEPTED` | `?` | Gray | Accepted, but not ready to finish |
| `READY` | `?` | Category color | Owner's completion requirements are met |

Colors are fixed semantic OKLCH tokens, independent of arena accents.
`STANDARD` and `CAMPAIGN` use gold, `REPEATABLE` blue, `SPECIAL` orange,
`URGENT` red and `TRAVEL` green. Gray overrides category color for locked or
accepted states. A `CAMPAIGN` marker can opt into a brown crest with
`campaign_frame`; category alone does not enable the crest. Keeper uses plain
gold symbols by default.

These categories are extension points, not evidence that those interactions
exist. Special, urgent and travel colors are Arenic design choices, not
universal World of Warcraft rules.

## Authoring and ownership

Create an
[`ArenicInteractionMarkerDefinition`](../arenic-game/scripts/interaction/interaction_marker_definition.gd)
resource with the following fields:

| Field | Contract |
| --- | --- |
| `marker_id` | Stable identifier for the interaction, 1–64 characters |
| `target_id` | Stable identifier for the actual NPC or environmental target, 1–64 characters |
| `display_name` | Nonblank label, at most 96 characters, used with the status tooltip |
| `target_kind` | Typed `NPC` or `ENVIRONMENT` target category |
| `kind` | `STANDARD`, `CAMPAIGN`, `REPEATABLE`, `SPECIAL`, `URGENT` or `TRAVEL` |
| `head_offset` | Finite 8–96 logical pixels from the marker's bottom edge to its anchor; scales with its canvas parent |
| `campaign_frame` | Optional brown crest, used only for `CAMPAIGN` |

Identifiers must pass Godot's identifier validation. Validate the definition
and verify that its target matches the owning interaction before mounting it.
For NPCs, the typed
[`ArenicNpcDefinition.interaction_marker`](../arenic-game/scripts/intro/npc_definition.gd)
references this resource. The current example is
[`keeper_introduction.tres`](../arenic-game/data/interactions/keeper_introduction.tres):
`marker_id = "first_thread"`, `target_id = "keeper"`, NPC target, campaign
category and no crest.

The owner mounts one `ArenicInteractionMarker` in its canvas, assigns
`definition`, and supplies the current value through `set_state(state)`. It
connects the inherited Button `pressed` signal to its normal interaction
handler. That handler must recheck actual range, session restrictions and
progress before changing anything; a click is a request, not proof of eligibility.

Call `project_to(anchor, camera, world_rect, present, actionable)` with the
real `Node3D` target, active camera and HUD world rectangle in viewport canvas
coordinates. The component projects into its parent's canvas, applies the
authored offset, and hides targets behind the camera or outside that rectangle.
It does not pin distant interactions to a screen edge. The view has a compact
36×44 button area, a text status tooltip and no keyboard-focus capture.
Disabled markers ignore pointer input; the owner retains keyboard routing and
the same validation for pointer and keyboard requests. State changes and camera
projection are separate calls so a hidden or off-screen target stays hidden.

Environmental interactions use the same component and camera anchor contract
with `target_kind = ENVIRONMENT`. Attach one only when an actual environmental
interaction owns progress and can handle the request. Gathering nodes receive
no fabricated quest markers from this system.

Keep one presentation per target. If a future owner has multiple real quests
on the same target, it must choose which one is presented, with priority
`READY > AVAILABLE > ACCEPTED > LOCKED` and an explicit tie policy. The marker
does not discover quests, combine objectives or infer priority from names.

## Keeper introduction

[`ArenicGuildIntroduction.marker_state()`](../arenic-game/scripts/intro/guild_introduction.gd)
derives the marker from saved `RunSetup.intro_step`, the current reading timer
and door-opening presentation:

| Introduction condition | Marker |
| --- | --- |
| Step 0: opening quote | Hidden |
| Step 1: invitation | Gold `!`, available |
| Steps 2–4, and step 5 before its minimum reading time | Gray `?`, accepted |
| Step 5 after its minimum reading time | Gold `?`, ready to finish |
| Doors opening, or step 6 complete | Hidden |

The invitation marker is clickable only when `can_talk()` accepts the current
hero and session. Once dialogue starts, question marks are status indicators;
the existing Continue/Open the doors button and Space/Enter advance after the
reading interval. No quest reward is introduced. On completion the marker
disappears, while clicking the NPC sprite or using nearby Space can still open
the existing recording reminder when its normal conditions allow it.

The shared view is derived/transient presentation. There are no additional
save fields or schema changes: loading reconstructs the marker from the saved
introduction step and resets the current reading delay, as described in the
[save-state inventory](save-state.md#state-ownership-and-restoration). Definition resources,
buttons, projected positions, hover and animation frames are not saved progress.

## Reference design

Blizzard's new-player guide uses a yellow exclamation point for an available
quest and a yellow question mark for a completed quest awaiting turn-in.
[Official Elwynn Forest guide](https://worldofwarcraft.blizzard.com/en-us/news/20147001)
describes both states. The
[Classic manual, “Acquiring Quests from NPCs”](https://us.media.blizzard.com/manuals/wow/wow-classic-manual-enUS.pdf)
describes the accepted-but-incomplete state as a gray question mark. Arenic's
available/accepted/ready sequence follows that Classic distinction.

Modern WoW also distinguishes campaign, repeatable and other categories; its
War Within quest-log update uses a three-dot icon for in-progress quests.
[Blizzard's modern UI and quest update](https://news.blizzard.com/en-us/article/24117139/user-interface-and-quest-updates-in-the-war-withintm)
is a separate reference. Arenic deliberately retains its documented gray `?`
accepted state instead of claiming that Classic and modern icon legends are
identical. The optional crest and broader Arenic categories remain presentation
choices governed by the explicit resource contract above.
