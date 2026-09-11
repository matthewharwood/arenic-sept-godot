class_name ArenicClassAbility
extends Resource

@export var title: String
@export var audio_profile: ArenicAbilitySoundProfile
@export_multiline var description: String
## Starter rules; animation lengths never decide gameplay timing or hit size.
@export var ability_id: String = ""
@export_enum("target", "ground", "channel", "cleanse", "aura") var effect_kind: String = "target"
@export_range(1, 100, 1) var damage: int = 1
@export_range(0.0, 120.0, 0.05) var cooldown_seconds: float = 1.0
@export_range(0, 66, 1) var range_tiles: int = 1
@export_range(0.0, 10.0, 0.05) var cast_seconds: float = 0.0
## Target/ground release delay, clamped to cast_seconds. Other effects release immediately.
@export_range(0.0, 10.0, 0.01) var release_seconds: float = 0.0
## Zero means an indefinite held channel; finite auras require a duration.
@export_range(0.0, 120.0, 0.1) var duration_seconds: float = 0.0
@export_range(0.05, 10.0, 0.05) var tick_seconds: float = 1.0
@export var requires_adjacent: bool = false
@export var requires_backstab: bool = false
@export var area_size: Vector2i = Vector2i(4, 4)
@export_range(0, 66, 1) var radius_tiles: int = 2
## Data hook only: nearby allies add this fraction; no currency is awarded.
@export_range(0.0, 1.0, 0.01) var loot_bonus_per_ally: float = 0.05
