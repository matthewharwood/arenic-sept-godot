class_name ArenicGuildClearingView
extends Node3D
## Aseprite scenery at native pixel scale. Stable authored clusters, no runtime RNG.
const DEFINITION: ArenicGuildClearingDefinition = preload("res://data/world/guild_clearing.tres")
const TREE_ATLAS: Texture2D = preload("res://assets/environment/guild_clearing/forest/trees.png")
const PATH_ATLAS: Texture2D = preload("res://assets/environment/guild_clearing/ground/dirt_patches.png")
const PIXEL_SIZE: float = ArenicGridMath.TILE_SIZE / 19.0
var trees: Array[Sprite3D] = []
var paths: Array[Sprite3D] = []

func _ready() -> void:
	assert(DEFINITION.validation_errors().is_empty())
	for index: int in DEFINITION.trees.size():
		var placement: ArenicClearingTree = DEFINITION.trees[index]
		var tree := sprite("Tree%02d" % index, tree_texture(placement.variant, placement.facing), placement.cell, 0.007, -1)
		add_child(tree)
		trees.append(tree)
	var patch_index: int = 0
	for path: PackedVector2Array in DEFINITION.paths:
		for segment: int in range(1, path.size()):
			var start: Vector2 = path[segment - 1]
			var finish: Vector2 = path[segment]
			var steps: int = maxi(1, ceili(start.distance_to(finish) / ArenicGuildClearingDefinition.PATH_SPACING))
			for step: int in steps:
				var point: Vector2 = start.lerp(finish, float(step) / steps)
				# Native pixel alignment keeps winding paths crisp at every viewport.
				point = (point * 19.0).round() / 19.0
				var texture := AtlasTexture.new()
				texture.atlas = PATH_ATLAS
				texture.region = Rect2((patch_index % 3) * 76, 0, 76, 76)
				texture.filter_clip = true
				var patch := sprite("Path%03d" % patch_index, texture, point, 0.001, -8)
				patch.rotate_y(float(patch_index % 4) * PI * 0.5)
				patch.modulate.a = 0.72
				add_child(patch)
				paths.append(patch)
				patch_index += 1

func set_overview_mix(amount: float) -> void:
	for tree: Sprite3D in trees:
		tree.modulate.a = lerpf(1.0, 0.72, amount)
	for path: Sprite3D in paths:
		path.modulate.a = lerpf(0.72, 0.0, amount)

static func tree_texture(variant: int, facing: int) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = TREE_ATLAS
	texture.region = Rect2(facing * 76, variant * 76, 76, 76)
	texture.filter_clip = true
	return texture

static func sprite(node_name: String, texture: Texture2D, cell: Vector2, elevation: float, priority: int) -> Sprite3D:
	var result := Sprite3D.new()
	result.name = node_name
	result.texture = texture
	result.pixel_size = PIXEL_SIZE
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	result.shaded = false
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	result.rotation.x = -PI * 0.5
	result.position = ArenicArenaTiles.tile_point((cell * 19.0).round() / 19.0) + Vector3(0, elevation, 0)
	result.render_priority = priority
	if int(texture.get_width()) % 2 == 0:
		result.offset = Vector2(0.5, 0.5)
	return result
