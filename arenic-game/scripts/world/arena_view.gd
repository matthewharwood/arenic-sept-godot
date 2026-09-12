class_name ArenicArenaView
extends Node3D
## Tiles and boss remain mounted through overview, close-up and sequence camera moves.
@export var definition: ArenicArenaDefinition

const TILE_PIXELS: float = 19.0
const BOSS_TILES: Vector2i = Vector2i(6, 6)
## The rig is a top-down ORTHOGRAPHIC camera, so raising a sprite on +Y moves it
## nowhere on screen. Height has to read as size instead: this is how much bigger
## one tile of authored lift draws the boss as it rises toward the viewer.
const LIFT_SCALE_PER_TILE: float = 0.075
const MAX_LIFT_SCALE: float = 2.0
var damage_phase: int = 0
var _boss: AnimatedSprite3D
var _blast: ArenicBossBlastRing
var _ground: ArenicGroundOverlay
var _acid: ArenicGroundOverlay
var _spent: Color = Color(0.55, 0.42, 0.25)
var _trapped: Color = Color(1.0, 0.42, 0.35)
var _corrosive: Color = Color(0.55, 0.85, 0.25)

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
	_blast = ArenicBossBlastRing.new()
	_blast.name = "BlastRing"
	add_child(_blast)
	_blast.configure(definition.visual_theme)
	_ground = ArenicGroundOverlay.new()
	_ground.name = "BrokenGround"
	add_child(_ground)
	_ground.set_elevation(1)
	_acid = ArenicGroundOverlay.new()
	_acid.name = "AcidPools"
	add_child(_acid)
	_acid.set_elevation(2)
	_theme_ground(definition.visual_theme)
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
	# Stated, not inherited: a boss standing in acid or on broken ground is drawn
	# over it. Ground effects sort below zero precisely so this holds.
	sprite.render_priority = 0
	sprite.rotation.x = -PI * 0.5
	var lower_left := ArenicGridMath.tile_to_world(definition.grid_slot, definition.boss_origin_cell)
	var canvas_center := lower_left + Vector3(2.5, 0.0, -2.5) * ArenicGridMath.TILE_SIZE
	sprite.position = canvas_center - position + Vector3(0.0, 0.01, 0.0)
	add_child(sprite)
	sprite.play(animation_name)
	_boss = sprite

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


## Renders the boss where its arena's score currently places it. Motion is
## presentation: the ledger already moved the footprint when the beat resolved,
## so a skipped frame changes what is drawn and never what was struck.
## `lift` is tiles toward the top-down camera, which is +Y in world space.
func set_boss_placement(placement: Dictionary) -> void:
	if _boss == null or placement.is_empty():
		return
	var center: Vector2 = placement["center"]
	var lift: float = float(placement["lift"])
	# The world lift still keeps an airborne boss sorted above ground decoration;
	# the scale is what actually shows it leaving the floor.
	_boss.position = ArenicArenaTiles.tile_point(center) + Vector3(0.0, lift * ArenicGridMath.TILE_SIZE + 0.01, 0.0)
	_boss.scale = Vector3.ONE * minf(MAX_LIFT_SCALE, 1.0 + lift * LIFT_SCALE_PER_TILE)
	if _blast != null:
		_blast.show_warning(placement["target"], float(placement["radius"]), int(placement["until"]), int(placement["travel"]))


## Broken ground belongs to its biome; the trap tint borrows the HUD's negative
## token, because an occupied trap is damage in progress. Acid stays green
## whatever the arena: it is the substance, not the place.
func _theme_ground(visual_theme: ArenicArenaTheme) -> void:
	if visual_theme == null:
		return
	_spent = visual_theme.color("base_content").lerp(visual_theme.color("accent"), 0.45)
	_trapped = ArenicHudTokens.color("negative", visual_theme)
	_corrosive = ArenicHudTokens.color("positive", visual_theme).lerp(Color(0.7, 1.0, 0.2), 0.55)


## Which tiles are spent, and which of them a target is standing on right now.
func set_dig_ground(dug: PackedInt32Array, overlapped: PackedInt32Array) -> void:
	if _ground == null:
		return
	var colors := PackedColorArray()
	for index: int in dug:
		var occupied: bool = overlapped.has(index)
		colors.append(Color(_trapped, 0.85) if occupied else Color(_spent, 0.42))
	_ground.set_cells(dug, colors)


## Pools of acid, fading as they dry up.
func set_acid_pools(cells: PackedInt32Array, strengths: PackedFloat32Array) -> void:
	if _acid == null:
		return
	var colors := PackedColorArray()
	for slot: int in cells.size():
		var life: float = strengths[slot] if slot < strengths.size() else 1.0
		colors.append(Color(_corrosive, lerpf(0.22, 0.66, life)))
	_acid.set_cells(cells, colors)


## A tile just broke. The marker is already drawn by the next sync; this is the
## moment of it, for feedback that a dig actually found something.
func show_dig(cell: Vector2i, value: int) -> void:
	if _blast != null and value > 0:
		_blast.strike(Vector2(cell), 0.9)


## Flashes an authored landing. Only the arena that owns the beat is told.
func show_blast(center: Vector2, radius_tiles: float) -> void:
	if _blast != null:
		_blast.strike(center, radius_tiles)
