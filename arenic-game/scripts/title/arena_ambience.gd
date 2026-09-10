extends Node3D

@onready var _hero: MeshInstance3D = $Hero
@onready var _boss: MeshInstance3D = $Boss
@onready var _shards: Node3D = $OrbitingShards

var _hero_origin: Transform3D
var _boss_origin: Transform3D
var _shards_origin: Transform3D
var _hover_phase: float = 0.0
var _boss_angle: float = 0.0
var _shard_angle: float = 0.0
var _motion_enabled: bool = true
var _initialized: bool = false


func _ready() -> void:
	_hero_origin = _hero.transform
	_boss_origin = _boss.transform
	_shards_origin = _shards.transform
	_initialized = true
	set_process(_motion_enabled)


func set_motion_enabled(enabled: bool) -> void:
	_motion_enabled = enabled
	if not _initialized:
		return
	set_process(enabled)
	if not enabled:
		_hover_phase = 0.0
		_boss_angle = 0.0
		_shard_angle = 0.0
		_hero.transform = _hero_origin
		_boss.transform = _boss_origin
		_shards.transform = _shards_origin


func _process(delta: float) -> void:
	_hover_phase = fposmod(_hover_phase + delta * 0.55, TAU)
	_boss_angle = fposmod(_boss_angle + delta * 0.12, TAU)
	_shard_angle = fposmod(_shard_angle + delta * 0.08, TAU)

	_hero.position.y = _hero_origin.origin.y + sin(_hover_phase) * 0.08
	_boss.position.y = _boss_origin.origin.y - sin(_hover_phase) * 0.10
	_boss.basis = _boss_origin.basis.rotated(Vector3.UP, _boss_angle)
	_shards.basis = _shards_origin.basis.rotated(Vector3.UP, _shard_angle)
