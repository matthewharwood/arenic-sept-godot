class_name ArenicHeroView
extends Node3D
## A one-cell view of HeroState; never infer gameplay coordinates from Transform.
const PIXEL_SIZE: float = ArenicGridMath.TILE_SIZE / 19.0
var state: ArenicHeroState
var sprite: AnimatedSprite3D
var _selection: Sprite3D

func configure(hero: ArenicHeroState) -> void:
	state = hero
	sprite = AnimatedSprite3D.new()
	sprite.name = "Sprite"
	sprite.sprite_frames = hero.definition.world_sprite_frames
	sprite.pixel_size = PIXEL_SIZE
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.rotation.x = -PI * 0.5
	# A centered odd 19px canvas puts pixel (9,9) over the tile's center pixel.
	sprite.centered = true
	add_child(sprite)
	_selection = Sprite3D.new()
	_selection.name = "Selection"
	_selection.texture = _selection_texture()
	_selection.pixel_size = PIXEL_SIZE
	_selection.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_selection.shaded = false
	_selection.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_selection.rotation.x = -PI * 0.5
	_selection.position.y = -0.005
	add_child(_selection)

func sync(arena: ArenicArenaDefinition, show_selection: bool) -> void:
	global_position = ArenicGridMath.tile_to_world(arena.grid_slot, state.cell) + Vector3(0.0, 0.025, 0.0)
	var animation_name := "idle_" + state.facing
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_name):
		if sprite.animation != animation_name or not sprite.is_playing():
			sprite.play(animation_name)
	_selection.visible = show_selection and state.selected
	if arena.visual_theme != null:
		_selection.modulate = arena.visual_theme.color("primary")

func _selection_texture() -> ImageTexture:
	var pixels := Image.create(23, 23, false, Image.FORMAT_RGBA8)
	pixels.fill(Color(0, 0, 0, 0))
	var mask := Color(1, 1, 1, 1)
	# Corner brackets stay outside the native 19px sprite canvas.
	for offset in range(6):
		for edge in [0, 22]:
			pixels.set_pixel(offset, edge, mask)
			pixels.set_pixel(22 - offset, edge, mask)
			pixels.set_pixel(edge, offset, mask)
			pixels.set_pixel(edge, 22 - offset, mask)
	return ImageTexture.create_from_image(pixels)
