class_name ArenicHeroView
extends Node3D
## A one-cell view of HeroState; never infer gameplay coordinates from Transform.
const PIXEL_SIZE: float = ArenicGridMath.TILE_SIZE / 19.0
var state: ArenicHeroState
var sprite: AnimatedSprite3D
var _selection: Sprite3D
var _idle_frames: SpriteFrames
var _starter_frames: SpriteFrames
var _starter_id: String = ""
var _ability_id: String = ""
var _ability_direction: String = "n"
var _channeling: bool = false

func configure(hero: ArenicHeroState) -> void:
	state = hero
	sprite = AnimatedSprite3D.new()
	sprite.name = "Sprite"
	_idle_frames = hero.definition.world_sprite_frames
	_starter_id = hero.definition.skills[0].ability_id if not hero.definition.skills.is_empty() and hero.definition.skills[0] != null else ""
	if _starter_id == "sacrifice":
		_starter_id = "heal"
	if not _starter_id.is_empty():
		_starter_frames = load("res://assets/abilities/%s/actor_frames.tres" % _starter_id) as SpriteFrames
	sprite.sprite_frames = _idle_frames
	sprite.animation_finished.connect(_on_animation_finished)
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
	if _ability_id.is_empty() and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_name):
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

func play_ability(ability_id: String, direction: String) -> void:
	var canonical: String = "heal" if ability_id == "sacrifice" else ability_id
	if canonical != _starter_id or _starter_frames == null:
		return
	_ability_direction = direction if direction in ["n", "e", "s", "w"] else "n"
	_ability_id = canonical
	_channeling = canonical == "heal"
	sprite.stop()
	sprite.sprite_frames = _starter_frames
	var tag: String = _ability_direction + "_connect" if _channeling else canonical + "_" + _ability_direction
	sprite.play(tag)

## Restore elapsed presentation after stage replacement; never replay a windup.
func restore_ability(ability_id: String, direction: String, elapsed: float) -> void:
	play_ability(ability_id, direction)
	if _ability_id.is_empty():
		return
	if _channeling and elapsed >= 0.3:
		sprite.play(_ability_direction + "_channel")
		seek_native_animation(sprite, elapsed - 0.3)
	elif not seek_native_animation(sprite, elapsed):
		_restore_idle()

## Frame weights are native milliseconds at 1000 FPS, including uneven holds.
static func seek_native_animation(target: AnimatedSprite3D, elapsed: float) -> bool:
	var frames: SpriteFrames = target.sprite_frames
	var tag: StringName = target.animation
	var speed: float = frames.get_animation_speed(tag)
	var total: float = 0.0
	for index: int in frames.get_frame_count(tag):
		total += frames.get_frame_duration(tag, index) / speed
	if total <= 0.0:
		return false
	if not frames.get_animation_loop(tag) and elapsed >= total:
		return false
	var cursor: float = fposmod(maxf(0.0, elapsed), total)
	for index: int in frames.get_frame_count(tag):
		var duration: float = frames.get_frame_duration(tag, index) / speed
		if cursor < duration:
			target.set_frame_and_progress(index, cursor / duration)
			return true
		cursor -= duration
	return true

func cancel_ability(immediate: bool = false) -> void:
	if _ability_id.is_empty():
		return
	var was_channel: bool = _channeling
	_channeling = false
	if was_channel and not immediate:
		sprite.play(_ability_direction + "_release")
	else:
		_restore_idle()

func _on_animation_finished() -> void:
	if _ability_id.is_empty():
		return
	if _channeling:
		sprite.play(_ability_direction + "_channel")
	else:
		_restore_idle()

func _restore_idle() -> void:
	_ability_id = ""
	_channeling = false
	sprite.sprite_frames = _idle_frames
	if _idle_frames != null and state != null:
		sprite.play("idle_" + state.facing)
