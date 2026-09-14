class_name ArenicHeroView
extends Node3D
## A one-cell view of HeroState; never infer gameplay coordinates from Transform.
const PIXEL_SIZE: float = ArenicGridMath.TILE_SIZE / 19.0
const GHOST_OPACITY: float = 0.5
const GHOST_DEATH_FRAMES: String = "res://assets/fx/ghost_death/ghost_death_frames.tres"
var state: ArenicHeroState
var sprite: AnimatedSprite3D
var _selection: Sprite3D
var _idle_frames: SpriteFrames
var _starter_frames: SpriteFrames
var _starter_id: String = ""
var _ability_id: String = ""
var _ability_direction: String = "n"
var _themed: ArenicArenaTheme
var _channeling: bool = false
var _ghost: bool = false
var _fallen: bool = false
var _death_effect: AnimatedSprite3D
var _bag_bar: Sprite3D
var _bag_label: Label3D
var _bag_key: String = ""

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

## Marks this hero as folded into its arena's stream. Playback drives it, so the
## translucent actor distinguishes it without competing with the focus brackets.
func set_ghost(value: bool) -> void:
	_ghost = value
	if not value and _fallen:
		set_defeated(false)
	if sprite != null:
		var opacity: float = GHOST_OPACITY if value else 1.0
		if sprite.modulate.a != opacity:
			sprite.modulate.a = opacity

## The ledger owns defeat. Only a fresh defeat event plays the one-shot burst;
## mounting a saved or replaced view restores the lingering spirit directly.
func set_defeated(value: bool, play_burst: bool = false) -> void:
	var fallen: bool = value and _ghost
	if fallen == _fallen:
		return
	_fallen = fallen
	if fallen:
		cancel_ability(true)
		set_gathering_status({})
		sprite.hide()
		_selection.hide()
		if _death_effect == null:
			_death_effect = AnimatedSprite3D.new()
			_death_effect.name = "GhostDeath"
			_death_effect.sprite_frames = load(GHOST_DEATH_FRAMES) as SpriteFrames
			_death_effect.pixel_size = PIXEL_SIZE
			_death_effect.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			_death_effect.shaded = false
			_death_effect.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_death_effect.rotation.x = -PI * 0.5
			_death_effect.position.y = 0.015
			_death_effect.animation_finished.connect(_on_ghost_death_finished)
			add_child(_death_effect)
		_death_effect.show()
		_death_effect.play("burst" if play_burst else "spirit")
	else:
		if _death_effect != null:
			_death_effect.stop()
			_death_effect.hide()
		_restore_idle()
		sprite.show()

func _on_ghost_death_finished() -> void:
	if _fallen and _death_effect.animation == &"burst":
		_death_effect.play("spirit")


## The caller supplies a read-only gathering snapshot (or {} on death). Visual
## quantization bounds texture updates to 25 fill steps rather than every tick.
func set_gathering_status(snapshot: Dictionary) -> void:
	var kind: String = str(snapshot.get("kind", ""))
	var phase: String = str(snapshot.get("phase", "idle"))
	if _fallen or kind not in ["wood", "gold"] or phase == "idle":
		if _bag_bar != null:
			_bag_bar.hide()
			_bag_label.hide()
		_bag_key = ""
		return
	var progress: float = clampf(float(snapshot.get("progress", 0.0)), 0.0, 1.0)
	var full: bool = phase == "full"
	var unloading: bool = phase == "unloading"
	var units: int = maxi(0, int(snapshot.get("amount", 0)))
	var capacity: int = maxi(1, int(snapshot.get("capacity_units", 1)))
	var fill: int = roundi((1.0 - progress if unloading else progress) * 25.0)
	var label: String = "%s full" % kind.capitalize() if full else ("Unloading %s" % kind if unloading else "%s %d/%d" % [kind.capitalize(), units, capacity])
	var key: String = "%s:%d:%s" % [kind, fill, label]
	if key == _bag_key:
		return
	_bag_key = key
	if _bag_bar == null:
		_bag_bar = Sprite3D.new()
		_bag_bar.name = "GatheringBag"
		_bag_bar.pixel_size = PIXEL_SIZE
		_bag_bar.rotation.x = -PI * 0.5
		_bag_bar.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_bag_bar.shaded = false
		_bag_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_bag_bar.render_priority = 4
		_bag_bar.position = Vector3(0.0, 0.05, -PIXEL_SIZE * 17.0)
		add_child(_bag_bar)
		_bag_label = Label3D.new()
		_bag_label.name = "GatheringStatus"
		_bag_label.font = preload("res://assets/fonts/Barlow-Regular.ttf")
		_bag_label.font_size = 10
		_bag_label.pixel_size = PIXEL_SIZE
		_bag_label.rotation.x = -PI * 0.5
		_bag_label.position = Vector3(0.0, 0.055, -PIXEL_SIZE * 28.0)
		_bag_label.outline_size = 3
		_bag_label.render_priority = 4
		add_child(_bag_label)
	var color: Color = ArenicGatheringSiteView.resource_color(kind)
	_bag_label.text = label
	_bag_label.modulate = color
	_bag_label.outline_modulate = ArenicHudTokens.color("map_active", null, 0.9)
	_bag_bar.texture = _bag_texture(fill, color, full)
	_bag_bar.show()
	_bag_label.show()


func _bag_texture(fill: int, color: Color, full: bool) -> ImageTexture:
	var pixels := Image.create(37, 9, false, Image.FORMAT_RGBA8)
	pixels.fill(Color(0, 0, 0, 0))
	var dark: Color = ArenicHudTokens.color("map_active", null, 0.85)
	# Small tied sack beside a bounded bar, with an explicit full marker.
	pixels.fill_rect(Rect2i(1, 3, 6, 5), dark)
	pixels.fill_rect(Rect2i(2, 2, 4, 6), color.darkened(0.45))
	pixels.fill_rect(Rect2i(2, 3, 4, 1), color)
	pixels.fill_rect(Rect2i(3, 1, 2, 1), color)
	pixels.fill_rect(Rect2i(9, 2, 27, 5), dark)
	pixels.fill_rect(Rect2i(10, 3, fill, 3), color)
	if full:
		pixels.set_pixel(35, 0, color)
		pixels.set_pixel(35, 1, color)
	return ImageTexture.create_from_image(pixels)


func sync(arena: ArenicArenaDefinition, show_selection: bool) -> void:
	global_position = ArenicGridMath.tile_to_world(arena.grid_slot, state.cell) + Vector3(0.0, 0.025, 0.0)
	var animation_name := "idle_" + state.facing
	if not _fallen and _ability_id.is_empty() and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation_name):
		if sprite.animation != animation_name or not sprite.is_playing():
			sprite.play(animation_name)
	_selection.visible = not _fallen and show_selection and state.selected
	# Views follow the ledger every tick, so the OKLCH conversion behind
	# `color()` cannot run per hero per frame; it only changes when the hero
	# stands in a different arena.
	if arena.visual_theme != null and arena.visual_theme != _themed:
		_themed = arena.visual_theme
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
	if _fallen:
		return
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
