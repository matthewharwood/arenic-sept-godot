class_name ArenicNpcDefinition
extends Resource
## Stable identity and appearance; dialogue progress belongs to the saved run.
@export var npc_id: String = ""
@export var display_name: String = ""
@export var role: String = ""
@export var interaction_marker: ArenicInteractionMarkerDefinition
@export var portrait: Texture2D
## Transparent half-body cutout for conversations; portrait remains the full reference.
@export var dialogue_portrait: Texture2D
@export var sprite_frames: SpriteFrames
@export var arena_id: String = "guild_house"
@export var cell: Vector2i = Vector2i(33, 18)
@export_range(1.0, 8.0, 0.5) var interaction_radius: float = 4.0
