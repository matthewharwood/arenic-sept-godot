class_name ArenicClassDefinition
extends Resource

@export var class_id: String
@export var display_name: String
@export var character_name: String
@export var icon: Texture2D
@export var portrait: Texture2D
## Native overhead actor, separate from the character-selection portrait.
@export var world_sprite_frames: SpriteFrames
@export var skills: Array[ArenicClassAbility] = []
## Art direction only: these values never affect gameplay.
@export_range(0.5, 1.1) var portrait_height: float = 1.0
@export var portrait_offset := Vector2.ZERO
