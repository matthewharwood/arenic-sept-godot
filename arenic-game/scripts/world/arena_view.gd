class_name ArenicArenaView
extends Node3D
## Tiles and boss remain mounted through overview, close-up and sequence camera moves.
@export var definition: ArenicArenaDefinition

const TILE_PIXELS: float = 19.0
const BOSS_TILES: Vector2i = Vector2i(6, 6)
var damage_phase: int = 0

func _ready() -> void:
	if definition == null:
		push_error("Arena view needs an arena definition.")
		return
	position = ArenicGridMath.arena_center(definition.grid_slot)
	var environment := ArenicArenaEnvironment.new()
	environment.name = "EnvironmentLayers"
	add_child(environment)
	environment.configure(definition, $Tiles)
	_build_boss()
	if definition.content_scene != null:
		$ContentSlot.add_child(definition.content_scene.instantiate())

func _build_boss() -> void:
	var boss_data := definition.boss
	var frames: SpriteFrames = boss_data.sprite_frames if boss_data != null else definition.training_target_frames
	if frames == null:
		return
	if not ArenicGridMath.tile_valid(definition.boss_origin_cell) or not ArenicGridMath.tile_valid(definition.boss_origin_cell + BOSS_TILES - Vector2i.ONE):
		push_error("Boss canvas must fit inside arena: " + definition.arena_id)
		return
	var animation_name := "idle_" + definition.boss_facing
	if not frames.has_animation(animation_name):
		push_error("Boss is missing its idle animation: " + definition.arena_id)
		return
	var sprite := AnimatedSprite3D.new()
	sprite.name = "Boss"
	sprite.sprite_frames = frames
	sprite.pixel_size = ArenicGridMath.TILE_SIZE / TILE_PIXELS
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.fixed_size = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Sprite3D's centered 114px frame has the authored (57,57) pivot.
	sprite.centered = true
	sprite.rotation.x = -PI * 0.5
	var lower_left := ArenicGridMath.tile_to_world(definition.grid_slot, definition.boss_origin_cell)
	var canvas_center := lower_left + Vector3(2.5, 0.0, -2.5) * ArenicGridMath.TILE_SIZE
	sprite.position = canvas_center - position + Vector3(0.0, 0.01, 0.0)
	add_child(sprite)
	sprite.play(animation_name)

## Damage phases never remove the target. Authored forms advance until the last
## available appearance; later phase layers remain represented by the ledger/HUD.
func set_damage_phase(completed: int) -> void:
	damage_phase = maxi(0, completed)
	var sprite := get_node_or_null("Boss") as AnimatedSprite3D
	if sprite == null:
		return
	var animation_name: String = "idle_" + definition.boss_facing
	if damage_phase > 0 and definition.boss != null and not definition.boss.visual_states.is_empty():
		var states: Array[ArenicBossVisualState] = definition.boss.visual_states
		animation_name = states[mini(damage_phase, states.size() - 1)].tag_prefix + "_" + definition.boss_facing
	if sprite.sprite_frames.has_animation(animation_name) and sprite.animation != animation_name:
		sprite.play(animation_name)
