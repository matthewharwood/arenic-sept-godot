class_name ArenicGatheringSiteView
extends Node3D
## Guild House presentation only. Mount at the local origin of its ArenaView.
## Definitions own placement/range; the run owns bags and both bank totals.
const PIXEL_SIZE: float = ArenicGridMath.TILE_SIZE / 19.0
const ATLAS: Texture2D = preload("res://assets/environment/gathering/gathering_sites.png")
const MINES: Texture2D = preload("res://assets/environment/guild_clearing/forest/mine.png")
const CLEARING: ArenicGuildClearingDefinition = preload("res://data/world/guild_clearing.tres")
const WOOD: Vector3 = Vector3(0.76, 0.12, 149.0)
const GOLD: Vector3 = Vector3(0.86, 0.13, 85.0)
static var _resource_colors: Dictionary[String, Color] = {}

var _definition: ArenicGatheringDefinition


func configure(definition: ArenicGatheringDefinition) -> void:
	if definition == null:
		return
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_definition = definition
	for index: int in definition.wood_sources.size():
		_build_site("WoodSource%d" % index, definition.wood_sources[index], ArenicGuildClearingView.tree_texture(CLEARING.wood_variants[index], CLEARING.wood_facings[index]), "wood")
	for index: int in definition.gold_sources.size():
		_build_site("GoldSource%d" % index, definition.gold_sources[index], _region(MINES, CLEARING.mine_facings[index], 95), "gold")
	_build_site("WoodDropoff", definition.wood_dropoff, _region(ATLAS, 2, 57), "wood")
	_build_site("GoldDropoff", definition.gold_dropoff, _region(ATLAS, 3, 57), "gold")


static func resource_color(kind: String) -> Color:
	if not _resource_colors.has(kind):
		var converter := ArenicArenaTheme.new()
		converter.palette = {"resource": WOOD if kind == "wood" else GOLD}
		_resource_colors[kind] = converter.color("resource")
	return _resource_colors[kind]


func _build_site(node_name: String, cell: Vector2i, texture: Texture2D, kind: String) -> void:
	var site := Node3D.new()
	site.name = node_name
	site.position = ArenicArenaTiles.tile_point(Vector2(cell))
	add_child(site)
	var color: Color = resource_color(kind)
	var reach := _sprite("Reach", _reach_texture(_definition.radius_tiles), 0.003)
	reach.modulate = Color(color, 0.22)
	reach.render_priority = -3
	site.add_child(reach)
	var prop := _sprite("Prop", texture, 0.008)
	if int(texture.get_width()) % 2 == 0:
		prop.offset = Vector2(0.5, 0.5)
	site.add_child(prop)


static func _region(atlas: Texture2D, frame: int, size: int) -> AtlasTexture:
	var region := AtlasTexture.new()
	region.atlas = atlas
	region.region = Rect2(frame * size, 0, size, size)
	region.filter_clip = true
	return region


func _sprite(node_name: String, texture: Texture2D, elevation: float) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.name = node_name
	sprite.texture = texture
	sprite.pixel_size = PIXEL_SIZE
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.rotation.x = -PI * 0.5
	sprite.position.y = elevation
	return sprite


func _reach_texture(radius_tiles: float) -> ImageTexture:
	var radius: float = radius_tiles * 19.0
	var center: int = ceili(radius) + 1
	var image := Image.create(center * 2 + 1, center * 2 + 1, false, Image.FORMAT_RGBA8)
	image.fill(Color(1, 1, 1, 0)) # White masks acquire authored resource color above.
	for y: int in image.get_height():
		for x: int in image.get_width():
			var delta := Vector2(x - center, y - center)
			var distance: float = delta.length()
			if distance <= radius:
				var edge: bool = distance >= radius - 1.0
				var segment: int = floori((delta.angle() + PI) * radius / 6.0)
				image.set_pixel(x, y, Color(1, 1, 1, 0.9 if edge and segment % 3 != 2 else 0.08))
	return ImageTexture.create_from_image(image)
