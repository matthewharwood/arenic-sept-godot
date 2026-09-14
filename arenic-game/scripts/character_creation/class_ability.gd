@tool
class_name ArenicClassAbility
extends Resource

@export var title: String
@export var audio_profile: ArenicAbilitySoundProfile
@export_multiline var description: String
## Starter rules; animation lengths never decide gameplay timing or hit size.
@export var ability_id: String = ""
@export_enum("target", "ground", "channel", "cleanse", "aura", "dig") var effect_kind: String = "target"
@export_range(1, 100, 1) var damage: int = 1
@export_range(0.0, 120.0, 0.05) var cooldown_seconds: float = 1.0
@export_range(0, 66, 1) var range_tiles: int = 1
@export_range(0.0, 10.0, 0.05) var cast_seconds: float = 0.0
## Zero keeps fixed cast_seconds timing; positive speed uses windup + Euclidean flight distance.
@export_range(0.0, 120.0, 0.1) var projectile_speed_tiles_per_second: float = 0.0
## Target/ground release delay. Fixed-time effects clamp this to cast_seconds.
@export_range(0.0, 10.0, 0.01) var release_seconds: float = 0.0
## Zero means an indefinite held channel; finite auras require a duration.
@export_range(0.0, 120.0, 0.1) var duration_seconds: float = 0.0
@export_range(0.05, 10.0, 0.05) var tick_seconds: float = 1.0
## Zero disables enemy DOT. Each accepted Cleanse freezes its own bounded stack.
@export_range(0.0, 120.0, 0.05) var enemy_dot_duration_seconds: float = 0.0
@export_range(0.05, 10.0, 0.05) var enemy_dot_tick_seconds: float = 1.0
@export_range(1, 100, 1) var enemy_dot_damage: int = 1
@export var requires_adjacent: bool = false
@export var requires_backstab: bool = false
@export var area_size: Vector2i = Vector2i(4, 4)
@export_range(0, 66, 1) var radius_tiles: int = 2
## Data hook only: nearby allies add this fraction; no currency is awarded.
@export_range(0.0, 1.0, 0.01) var loot_bonus_per_ally: float = 0.05


func resolve_seconds(origin: Vector2i, target: Vector2i) -> float:
	if projectile_speed_tiles_per_second > 0.0:
		return release_seconds + Vector2(origin).distance_to(Vector2(target)) / projectile_speed_tiles_per_second
	return cast_seconds


## Shared by authored-data preflight and combat acceptance. Seconds are authored
## values; each accepted DOT freezes rounded integer ticks in its own state.
func enemy_dot_error() -> String:
	if not is_finite(enemy_dot_duration_seconds) or enemy_dot_duration_seconds < 0.0 or enemy_dot_duration_seconds > 120.0:
		return "enemy_dot_duration_seconds must be finite and between 0 and 120."
	if enemy_dot_duration_seconds > 0.0:
		if effect_kind != "cleanse":
			return "Enabled enemy DOTs require the cleanse effect kind."
		if roundi(enemy_dot_duration_seconds * 60.0) < 1:
			return "enemy_dot_duration_seconds must round to at least one 60 Hz tick when enabled."
	if not is_finite(enemy_dot_tick_seconds) or enemy_dot_tick_seconds < 0.05 or enemy_dot_tick_seconds > 10.0:
		return "enemy_dot_tick_seconds must be finite and between 0.05 and 10."
	if enemy_dot_damage < 1 or enemy_dot_damage > 100:
		return "enemy_dot_damage must be between 1 and 100."
	return ""


func validation_errors() -> PackedStringArray:
	var error: String = enemy_dot_error()
	return PackedStringArray() if error.is_empty() else PackedStringArray([error])


func _get_validation_conditions() -> Array:
	return ArenicDoctorConditions.from_errors(validation_errors())
