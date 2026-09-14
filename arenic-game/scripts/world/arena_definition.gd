class_name ArenicArenaDefinition
extends Resource
## Authoring data for one arena. Geometry and runtime behavior live elsewhere.

@export var arena_id: String = ""
@export var display_name: String = ""
@export var class_id: String = ""
@export var class_label: String = ""
@export var hotkey: String = ""
@export var grid_slot: Vector2i = Vector2i.ZERO
@export var visual_theme: ArenicArenaTheme
@export var music: ArenicArenaMusicDefinition
@export var boss: ArenicBossDefinition
## Lower-left tile of the boss's six-by-six art canvas; not collision geometry.
@export var boss_origin_cell: Vector2i = Vector2i(30, 22)
@export_enum("n", "e", "s", "w") var boss_facing: String = "n"
## Explicit gameplay occupancy, independent of the six-tile art canvas.
@export var boss_combat_size: Vector2i = Vector2i(6, 6)
## Absolute damage needed to complete each cumulative phase layer.
@export_range(1, 1000000, 1) var phase_damage: int = 20
## Art offset in grid tiles; never changes target occupancy or saved combat identity.
@export var boss_visual_offset: Vector2 = Vector2.ZERO
## Static Guild House scenery shares the target presentation slot.
@export var training_target_frames: SpriteFrames
@export var content_scene: PackedScene
