class_name ArenicCombatPresentation
extends Node3D
## Native art only. This bounded pool observes combat; it never applies damage.
const POOL_LIMIT: int = 16
const PIXEL_SIZE: float = ArenicGridMath.TILE_SIZE / 19.0
const CATALOG: Resource = preload("res://assets/abilities/starter_catalog.tres")
const DAMAGE_FONT: Font = preload("res://assets/fonts/Rajdhani-Bold.ttf")

class Effect:
	extends RefCounted
	var sprite: AnimatedSprite3D
	var label: Label3D
	var active: bool = false
	var age: float = 0.0
	var delay: float = 0.0
	var duration: float = 1.0
	var origin: Vector3
	var target: Vector3
	var travel: bool = false
	var follow_hero: bool = false
	var channel: bool = false
	var ability: String = ""
	var tag: StringName
	var number: bool = false
	var serial: int = 0

var _stage: ArenicOverworldStage
var _catalog: Dictionary = {}
var _frames: Dictionary[String, SpriteFrames] = {}
var _pool: Array[Effect] = []
var _serial: int = 0
var _last_ability: String = ""
var _last_facing: String = "n"
var _channeling: bool = false
var _fortune_seconds: float = 0.0

func configure(stage: ArenicOverworldStage) -> void:
	clear()
	_stage = stage
	var parsed: Variant = CATALOG.get_meta("abilities")
	if not parsed is Dictionary:
		push_error("Combat presentation needs the exported starter manifest.")
		return
	_catalog = parsed
	for ability: String in _catalog:
		var assets: Dictionary = _catalog[ability].assets
		for stem: String in assets:
			var path: String = assets[stem].sprite_frames
			_frames[ability + "/" + stem] = load(path) as SpriteFrames
	if _pool.is_empty():
		for index: int in POOL_LIMIT:
			var effect := Effect.new()
			effect.sprite = AnimatedSprite3D.new()
			effect.sprite.name = "Effect%d" % index
			effect.sprite.pixel_size = PIXEL_SIZE
			effect.sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			effect.sprite.shaded = false
			effect.sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			effect.sprite.rotation.x = -PI * 0.5
			effect.sprite.render_priority = 2
			effect.sprite.visible = false
			add_child(effect.sprite)
			effect.label = Label3D.new()
			effect.label.name = "Damage%d" % index
			effect.label.font = DAMAGE_FONT
			effect.label.font_size = 16
			effect.label.pixel_size = PIXEL_SIZE
			effect.label.rotation.x = -PI * 0.5
			effect.label.no_depth_test = false
			effect.label.render_priority = 3
			effect.label.visible = false
			add_child(effect.label)
			_pool.append(effect)
	set_process(false)

## `caster_identity` is the run identity of whoever cast: with ghosts in the
## arena the caster is often not the hero the player controls, and animating the
## controlled hero instead would show someone else's ability on your own sprite.
func show_cast(caster_identity: int, ability_id: String, arena_id: String, origin: Vector2i, target_cell: Vector2i, facing: String, rules: ArenicClassAbility = null) -> void:
	var id: String = "heal" if ability_id == "sacrifice" else ability_id
	if not _catalog.has(id) or not is_instance_valid(_stage):
		return
	var arena: ArenicArenaDefinition = _arena(arena_id)
	if arena == null:
		return
	var caster: ArenicHeroView = _caster_view(caster_identity)
	if rules == null and is_instance_valid(caster):
		var skills: Array[ArenicClassAbility] = caster.state.definition.skills
		if not skills.is_empty() and skills[0].ability_id == id:
			rules = skills[0]
	if rules == null:
		return
	_last_ability = id
	_last_facing = facing
	if is_instance_valid(caster):
		caster.play_ability(id, facing)
	var start: Vector3 = _point(arena, origin)
	var finish: Vector3 = _point(arena, target_cell)
	match id:
		"auto_shot", "acid_flask":
			var stem: String = "projectile" if id == "auto_shot" else "flask"
			var tag: String = "flight_e" if id == "auto_shot" else "flight"
			if rules.cast_seconds <= 0.0:
				return # An immediate model hit has no in-flight interval.
			var release: float = minf(rules.release_seconds, rules.cast_seconds)
			var effect: Effect = _spawn(id, stem, tag, start, rules.cast_seconds - release, release)
			if effect != null:
				effect.travel = true
				effect.target = finish
				if id == "auto_shot":
					effect.sprite.rotation.y = atan2(-(finish.z - start.z), finish.x - start.x)
		"heal":
			cancel_channel(false)
			_channeling = true
			var aura: Effect = _spawn(id, "healing_aura", "restore", start, 1.0)
			if aura != null:
				aura.channel = true
				aura.follow_hero = true
			_channel_beam(start, finish)
		"cleanse":
			var area: Rect2i = ArenicCombatState.area_rect(origin, rules.area_size)
			var center: Vector2 = Vector2(area.position) + Vector2(area.size - Vector2i.ONE) * 0.5
			var wave_center: Vector3 = ArenicGridMath.arena_origin(arena.grid_slot) + Vector3(center.x * ArenicGridMath.TILE_SIZE, 0.05, -center.y * ArenicGridMath.TILE_SIZE)
			_spawn(id, "wave", "purify", wave_center, 2.0)
			_spawn(id, "cleansed", "cleansed", finish, 0.8)
		"dig":
			_spawn(id, "excavate", "excavate", finish, 0.8, rules.cast_seconds)
		"fortune":
			_for_each_stop("fortune")
			_fortune_seconds = rules.duration_seconds
			var aura: Effect = _spawn(id, "fortune", "fortune_loop", start, rules.duration_seconds)
			if aura != null:
				aura.follow_hero = true
			_spawn(id, "prosperity", "prosperity", start, 0.7)

## The model owns elapsed time. Rebuild only still-active visuals at that time.
func restore_active(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	clear()
	var id: String = snapshot.ability_id
	var elapsed: float = maxf(0.0, float(snapshot.elapsed))
	var rules := ArenicClassAbility.new()
	rules.ability_id = id
	rules.cast_seconds = float(snapshot.cast_seconds)
	rules.release_seconds = float(snapshot.release_seconds)
	rules.duration_seconds = float(snapshot.duration_seconds)
	# A fixture may hand over a snapshot with no caster; it falls back to the
	# controlled hero's view rather than dropping the restored effect.
	show_cast(int(snapshot.get("caster_identity", -1)), id, snapshot.arena_id, snapshot.origin, snapshot.target_cell, snapshot.facing, rules)
	if id == "fortune":
		_fortune_seconds = maxf(0.0, float(snapshot.remaining))
	for effect: Effect in _pool:
		if effect.active:
			effect.age = elapsed
	_process(0.0)
	for effect: Effect in _pool:
		if effect.active and not effect.number and effect.age >= effect.delay:
			ArenicHeroView.seek_native_animation(effect.sprite, effect.age - effect.delay)
	if is_instance_valid(_stage) and is_instance_valid(_stage.hero_view):
		_stage.hero_view.restore_ability(id, snapshot.facing, elapsed)

## Called only by the model's real damage signal, never by a cast timer.
func show_hit(arena_id: String, cell: Vector2, amount: int) -> void:
	var arena: ArenicArenaDefinition = _arena(arena_id)
	if arena == null or amount <= 0 or _last_ability.is_empty():
		return
	var point: Vector3 = ArenicGridMath.arena_origin(arena.grid_slot) + Vector3(cell.x * ArenicGridMath.TILE_SIZE, 0.05, -cell.y * ArenicGridMath.TILE_SIZE)
	match _last_ability:
		"auto_shot", "bash": _spawn(_last_ability, "impact", "impact", point, 0.4)
		"backstab": _spawn("backstab", "slash", "slash_" + _last_facing, point, 0.4)
		"acid_flask": _spawn("acid_flask", "shatter", "shatter", point, 0.6)
		"heal": _spawn("heal", "receiving_glow", "receive", point, 0.5)
		"fortune": _spawn("fortune", "prosperity", "prosperity", point, 0.7)
	var effect: Effect = _acquire()
	if effect == null:
		return
	effect.number = true
	effect.origin = point + Vector3(0.0, 0.03, -0.08)
	effect.target = effect.origin + Vector3(0.0, 0.0, -0.25)
	effect.duration = 0.7
	effect.label.text = str(amount)
	effect.label.modulate = arena.visual_theme.color("base_content")
	effect.label.outline_modulate = arena.visual_theme.color("base_300")
	effect.label.global_position = effect.origin
	effect.label.visible = true
	set_process(true)

func sync_active(channeling: bool, fortune_seconds: float) -> void:
	if _channeling and not channeling:
		cancel_channel()
	_fortune_seconds = maxf(0.0, fortune_seconds)
	if _fortune_seconds == 0.0:
		_for_each_stop("fortune")

## The view of one guild member, falling back to the controlled hero so a
## fixture that names no caster still animates something.
func _caster_view(caster_identity: int) -> ArenicHeroView:
	if not is_instance_valid(_stage):
		return null
	if caster_identity >= 0 and _stage.hero_views.has(caster_identity):
		return _stage.hero_views[caster_identity]
	return _stage.hero_view


func cancel_channel(cancel_actor: bool = true) -> void:
	_channeling = false
	for effect: Effect in _pool:
		if effect.active and effect.channel:
			_stop(effect)
	if cancel_actor and is_instance_valid(_stage) and is_instance_valid(_stage.hero_view):
		_stage.hero_view.cancel_ability()

func clear() -> void:
	for effect: Effect in _pool:
		_stop(effect)
	if is_instance_valid(_stage) and is_instance_valid(_stage.hero_view):
		_stage.hero_view.cancel_ability(true)
	_channeling = false
	_fortune_seconds = 0.0
	_last_ability = ""
	set_process(false)

func active_effect_count() -> int:
	var result: int = 0
	for effect: Effect in _pool:
		if effect.active:
			result += 1
	return result

func _process(delta: float) -> void:
	var active: bool = false
	for effect: Effect in _pool:
		if not effect.active:
			continue
		effect.age += delta
		if effect.age < effect.delay:
			active = true
			continue
		var elapsed: float = effect.age - effect.delay
		var persistent: bool = (effect.channel and _channeling) or (effect.ability == "fortune" and effect.follow_hero and _fortune_seconds > 0.0)
		if elapsed >= effect.duration and not persistent:
			_stop(effect)
			continue
		active = true
		if effect.number:
			effect.label.global_position = effect.origin.lerp(effect.target, elapsed / effect.duration)
			effect.label.modulate.a = 1.0 - elapsed / effect.duration
			continue
		if not effect.sprite.visible:
			effect.sprite.visible = true
			effect.sprite.play(effect.tag)
		if effect.follow_hero and is_instance_valid(_stage.hero_view):
			effect.sprite.global_position = _stage.hero_view.global_position + Vector3(0.0, 0.02, 0.0)
		elif effect.travel:
			effect.sprite.global_position = effect.origin.lerp(effect.target, clampf(elapsed / effect.duration, 0.0, 1.0))
	set_process(active)

func _spawn(id: String, stem: String, tag: String, point: Vector3, duration: float, delay: float = 0.0) -> Effect:
	var frames: SpriteFrames = _frames.get(id + "/" + stem)
	if frames == null or not frames.has_animation(tag):
		return null
	var effect: Effect = _acquire()
	if effect == null:
		return null
	var asset: Dictionary = _catalog[id].assets[stem]
	effect.ability = id
	effect.tag = tag
	effect.origin = point
	effect.target = point
	effect.duration = maxf(0.01, duration)
	effect.delay = maxf(0.0, delay)
	effect.sprite.sprite_frames = frames
	effect.sprite.offset = Vector2(floorf(float(asset.canvas[0]) * 0.5) - float(asset.pivot[0]), float(asset.pivot[1]) - floorf(float(asset.canvas[1]) * 0.5))
	effect.sprite.global_position = point
	effect.sprite.visible = delay == 0.0
	if effect.sprite.visible:
		effect.sprite.play(tag)
	set_process(true)
	return effect

func _acquire() -> Effect:
	var chosen: Effect
	for effect: Effect in _pool:
		if not effect.active:
			chosen = effect
			break
		if not effect.channel and not effect.follow_hero and (chosen == null or effect.serial < chosen.serial):
			chosen = effect
	if chosen == null:
		return null
	_stop(chosen)
	_serial += 1
	chosen.serial = _serial
	chosen.active = true
	chosen.age = 0.0
	chosen.delay = 0.0
	chosen.duration = 1.0
	chosen.number = false
	chosen.travel = false
	chosen.follow_hero = false
	chosen.channel = false
	chosen.ability = ""
	chosen.sprite.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	chosen.sprite.scale = Vector3.ONE
	return chosen

func _stop(effect: Effect) -> void:
	effect.active = false
	effect.sprite.stop()
	effect.sprite.visible = false
	effect.label.visible = false

func _for_each_stop(id: String) -> void:
	for effect: Effect in _pool:
		if effect.active and effect.ability == id:
			_stop(effect)

func _arena(id: String) -> ArenicArenaDefinition:
	if not is_instance_valid(_stage):
		return null
	var index: int = _stage.world.index_for_id(id)
	return _stage.world.arenas[index] if index >= 0 else null

func _point(arena: ArenicArenaDefinition, cell: Vector2i) -> Vector3:
	return ArenicGridMath.tile_to_world(arena.grid_slot, cell) + Vector3(0.0, 0.05, 0.0)

func _channel_beam(start: Vector3, finish: Vector3) -> void:
	var delta: Vector3 = finish - start
	var length: float = delta.length()
	if length < PIXEL_SIZE:
		return
	# Tile the native strip instead of stretching its pixels. The final strip is
	# clipped through AtlasTexture regions; masters and shared frames stay intact.
	var remaining: float = length / PIXEL_SIZE
	var travelled: float = 0.0
	for segment: int in 4:
		if remaining <= 0.0:
			break
		var span: int = mini(74, ceili(remaining))
		var position: Vector3 = start + delta.normalized() * travelled * PIXEL_SIZE
		var effect: Effect = _spawn("heal", "life_stream", "transfer", position, 1.0)
		if effect == null:
			return
		effect.channel = true
		effect.sprite.rotation.y = atan2(-delta.z, delta.x)
		if span < 74:
			var clipped := SpriteFrames.new()
			clipped.remove_animation("default")
			clipped.add_animation("transfer")
			clipped.set_animation_speed("transfer", 1000.0)
			clipped.set_animation_loop("transfer", true)
			var original: SpriteFrames = _frames["heal/life_stream"]
			for frame: int in original.get_frame_count("transfer"):
				var atlas := original.get_frame_texture("transfer", frame).duplicate() as AtlasTexture
				atlas.region.size.x = span + 2
				clipped.add_frame("transfer", atlas, original.get_frame_duration("transfer", frame))
			effect.sprite.sprite_frames = clipped
			effect.sprite.offset.x = floorf(float(span + 2) * 0.5) - 1.0
			effect.sprite.play("transfer")
		travelled += span
		remaining -= span
