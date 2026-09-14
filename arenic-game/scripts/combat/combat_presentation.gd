class_name ArenicCombatPresentation
extends Node3D
## Native art only. This bounded pool observes combat; it never applies damage.
const CASTER_LIMIT: int = 320 # The bounded guild roster.
const POOL_LIMIT: int = 16 # Disposable effects per caster; unknown sources have their own bucket.
const TRANSIENT_TRACKS: int = (CASTER_LIMIT + 1) * POOL_LIMIT
const CAST_EFFECT_SLOTS: int = 5 # The largest active cast: Sacrifice aura plus four strips.
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
	var caster_identity: int = -1
	var beam_span: int = 0
	var arena_id: String = ""
	var track_id: int = -1
	var cast_id: int = 0
	var model_owned: bool = false

class Channel:
	extends RefCounted
	var caster_identity: int
	var target_id: String = ""
	var arena_id: String
	var cell: Vector2i
	var range_tiles: int
	var origin: Vector3
	var target: Vector3
	var visible: bool = false
	var effects: Array[Effect] = [] # Aura first; beam slots retain stable track IDs.
	var segments: Array[Effect] = []

var _stage: ArenicOverworldStage
var _catalog: Dictionary = {}
var _frames: Dictionary[String, SpriteFrames] = {}
var _pool: Array[Effect] = []
var _serial: int = 0
var _cast_effects: Dictionary[int, Effect] = {}
var _cast_snapshot_lookup: Callable = Callable()
var _target_pose_lookup: Callable = Callable()
var _channel_status_lookup: Callable = Callable()
var _channels: Dictionary[int, Channel] = {}
var _beam_frames: Dictionary[int, SpriteFrames] = {}
## Shared arena pause boundary; visual time never decides when gameplay resumes.
var arena_paused_lookup: Callable = Callable()

func configure(stage: ArenicOverworldStage, target_pose_lookup: Callable = Callable(), channel_status_lookup: Callable = Callable(), cast_snapshot_lookup: Callable = Callable()) -> void:
	clear()
	_stage = stage
	_target_pose_lookup = target_pose_lookup
	_channel_status_lookup = channel_status_lookup
	_cast_snapshot_lookup = cast_snapshot_lookup
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
	set_process(false)

## `caster_identity` is the run identity of whoever cast: with ghosts in the
## arena the caster is often not the hero the player controls, and animating the
## controlled hero instead would show someone else's ability on your own sprite.
func show_cast(caster_identity: int, ability_id: String, arena_id: String, origin: Vector2i, target_cell: Vector2i, facing: String, rules: ArenicClassAbility = null, target_id: String = "", cast_id: int = 0) -> void:
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
	if caster_identity < 0 and is_instance_valid(caster):
		caster_identity = caster.state.identity_id
	if caster_identity < 0 or caster_identity >= CASTER_LIMIT:
		return
	cancel_channel(caster_identity, false)
	_retire_cast(caster_identity, false)
	if is_instance_valid(caster):
		caster.play_ability(id, facing)
	var start: Vector3 = _point(arena, origin)
	var finish: Vector3 = _point(arena, target_cell)
	match id:
		"auto_shot", "acid_flask":
			var stem: String = "projectile" if id == "auto_shot" else "flask"
			var tag: String = "flight_e" if id == "auto_shot" else "flight"
			var arrival: float = rules.resolve_seconds(origin, target_cell)
			if arrival <= 0.0:
				return # An immediate model hit has no in-flight interval.
			var release: float = minf(rules.release_seconds, arrival)
			var effect: Effect = _spawn(caster_identity, arena_id, id, stem, tag, start, arrival - release, release, _reserve_cast(caster_identity, arena_id, cast_id))
			if effect != null:
				effect.travel = true
				effect.target = finish
				if id == "auto_shot":
					effect.sprite.rotation.y = atan2(-(finish.z - start.z), finish.x - start.x)
		"heal":
			# Persistent visuals belong to the actual caster, never the selection.
			var channel := Channel.new()
			channel.caster_identity = caster_identity
			channel.target_id = target_id
			channel.arena_id = arena_id
			channel.cell = origin
			channel.range_tiles = rules.range_tiles
			channel.origin = start
			channel.target = finish
			_channels[caster_identity] = channel
			var aura: Effect = _spawn(caster_identity, arena_id, id, "healing_aura", "restore", start, 1.0, 0.0, _channel_effect(channel, 0))
			aura.follow_hero = true
			_update_channel_beam(channel)
		"cleanse":
			var area: Rect2i = ArenicCombatState.area_rect(origin, rules.area_size)
			var center: Vector2 = Vector2(area.position) + Vector2(area.size - Vector2i.ONE) * 0.5
			var wave_center: Vector3 = ArenicGridMath.arena_origin(arena.grid_slot) + Vector3(center.x * ArenicGridMath.TILE_SIZE, 0.05, -center.y * ArenicGridMath.TILE_SIZE)
			_spawn(caster_identity, arena_id, id, "wave", "purify", wave_center, 2.0, 0.0, _reserve_cast(caster_identity, arena_id, cast_id, false))
			_spawn(caster_identity, arena_id, id, "cleansed", "cleansed", finish, 0.8)
		"dig":
			_spawn(caster_identity, arena_id, id, "excavate", "excavate", finish, 0.8, rules.cast_seconds, _reserve_cast(caster_identity, arena_id, cast_id, false))
		"fortune":
			var aura: Effect = _spawn(caster_identity, arena_id, id, "fortune", "fortune_loop", start, rules.duration_seconds, 0.0, _reserve_cast(caster_identity, arena_id, cast_id))
			if aura != null:
				aura.follow_hero = true
				aura.caster_identity = caster_identity
			_spawn(caster_identity, arena_id, id, "prosperity", "prosperity", start, 0.7)

## The model owns elapsed time. Rebuild only still-active visuals at that time.
func restore_active(snapshot: Dictionary) -> void:
	if snapshot.is_empty():
		return
	var identity: int = int(snapshot.get("caster_identity", -1))
	var owner: ArenicHeroView = _caster_view(identity)
	if identity < 0 and is_instance_valid(owner):
		identity = owner.state.identity_id
	cancel_channel(identity, false)
	_retire_cast(identity, false)
	for effect: Effect in _pool:
		if effect.active and effect.caster_identity == identity:
			_stop(effect)
	var id: String = snapshot.ability_id
	var elapsed: float = maxf(0.0, float(snapshot.elapsed))
	var rules := ArenicClassAbility.new()
	rules.ability_id = id
	rules.cast_seconds = float(snapshot.cast_seconds)
	rules.release_seconds = float(snapshot.release_seconds)
	rules.duration_seconds = float(snapshot.duration_seconds)
	# A fixture may hand over a snapshot with no caster; it falls back to the
	# controlled hero's view rather than dropping the restored effect.
	if id == "heal":
		var caster: ArenicHeroView = _caster_view(int(snapshot.get("caster_identity", -1)))
		if is_instance_valid(caster) and not caster.state.definition.skills.is_empty():
			rules.range_tiles = caster.state.definition.skills[0].range_tiles
	show_cast(identity, id, snapshot.arena_id, snapshot.origin, snapshot.target_cell, snapshot.facing, rules, str(snapshot.get("target_id", "")), int(snapshot.get("cast_id", 0)))
	for effect: Effect in _all_effects():
		if effect.active and effect.caster_identity == identity:
			effect.age = elapsed
	_process(0.0)
	for effect: Effect in _all_effects():
		if effect.active and effect.caster_identity == identity and not effect.number and effect.age >= effect.delay:
			ArenicHeroView.seek_native_animation(effect.sprite, effect.age - effect.delay)
	var restored_caster: ArenicHeroView = _caster_view(int(snapshot.get("caster_identity", -1)))
	if is_instance_valid(restored_caster):
		restored_caster.restore_ability(id, snapshot.facing, elapsed)

## Damage provenance is explicit: delayed hits never borrow the most recent cast.
func show_hit(caster_identity: int, ability_id: String, arena_id: String, cell: Vector2, amount: int, facing: String = "n") -> void:
	var arena: ArenicArenaDefinition = _arena(arena_id)
	if arena == null or amount <= 0:
		return
	var point: Vector3 = ArenicGridMath.arena_origin(arena.grid_slot) + Vector3(cell.x * ArenicGridMath.TILE_SIZE, 0.05, -cell.y * ArenicGridMath.TILE_SIZE)
	match ability_id:
		"auto_shot", "bash": _spawn(caster_identity, arena_id, ability_id, "impact", "impact", point, 0.4)
		"backstab": _spawn(caster_identity, arena_id, "backstab", "slash", "slash_" + facing, point, 0.4)
		"acid_flask": _spawn(caster_identity, arena_id, "acid_flask", "shatter", "shatter", point, 0.6)
		"heal": _spawn(caster_identity, arena_id, "heal", "receiving_glow", "receive", point, 0.5)
		"fortune": _spawn(caster_identity, arena_id, "fortune", "prosperity", "prosperity", point, 0.7)
	var effect: Effect = _acquire(caster_identity, arena_id)
	effect.ability = ability_id
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

func sync_active() -> void:
	for identity: int in _channels.keys():
		if not _channel_active(_channels[identity], true):
			cancel_channel(identity)
	for identity: int in _cast_effects.keys():
		var effect: Effect = _cast_effects[identity]
		var caster: ArenicHeroView = _caster_view(identity)
		if not effect.model_owned or not _cast_snapshot_lookup.is_valid():
			continue # Resource-only fixtures use the effect's finite duration.
		var snapshot: Dictionary = _cast_snapshot_lookup.call(caster.state) if is_instance_valid(caster) else {}
		if snapshot.is_empty() or snapshot.ability_id != effect.ability or (effect.cast_id > 0 and int(snapshot.cast_id) != effect.cast_id):
			_retire_cast(identity)
		elif effect.follow_hero:
			effect.arena_id = snapshot.arena_id

## A known identity never borrows another hero's view. Only a fixture that
## explicitly omits its caster uses the controlled hero.
func _caster_view(caster_identity: int) -> ArenicHeroView:
	if not is_instance_valid(_stage):
		return null
	if caster_identity >= 0:
		return _stage.hero_views.get(caster_identity)
	return _stage.hero_view


func cancel_channel(caster_identity: int, cancel_actor: bool = true) -> void:
	var channel: Channel = _channels.get(caster_identity)
	if channel == null:
		return
	for effect: Effect in channel.effects:
		_stop(effect)
		effect.sprite.free()
	var caster: ArenicHeroView = _caster_view(caster_identity)
	if cancel_actor and is_instance_valid(caster):
		caster.cancel_ability()
	_channels.erase(caster_identity)

func clear() -> void:
	for identity: int in _channels.keys():
		cancel_channel(identity)
	for effect: Effect in _pool:
		_stop(effect)
	for identity: int in _cast_effects.keys():
		_retire_cast(identity)
	set_process(false)

func active_effect_count() -> int:
	var result: int = 0
	for effect: Effect in _all_effects():
		if effect.active:
			result += 1
	return result

## Bounded read-only enumeration for transient rewind capture and masking.
func effects_in_arena(arena_id: String) -> Array[Effect]:
	var result: Array[Effect] = []
	for effect: Effect in _all_effects():
		if effect.active and effect.arena_id == arena_id:
			result.append(effect)
	return result

## Canonical restart callers may retire only the performers they actually reset.
## Number labels are observations of the old pass, so they always retire.
func clear_arena(arena_id: String, caster_filter: Callable = Callable()) -> void:
	for identity: int in _channels.keys():
		if _channels[identity].arena_id == arena_id and (not caster_filter.is_valid() or bool(caster_filter.call(identity))):
			cancel_channel(identity, false)
	for identity: int in _cast_effects.keys():
		if _cast_effects[identity].arena_id == arena_id and (not caster_filter.is_valid() or bool(caster_filter.call(identity))):
			_retire_cast(identity, false)
	for effect: Effect in effects_in_arena(arena_id):
		if effect.number or not caster_filter.is_valid() or bool(caster_filter.call(effect.caster_identity)):
			_stop(effect)

func _arena_paused(arena_id: String) -> bool:
	return arena_paused_lookup.is_valid() and bool(arena_paused_lookup.call(arena_id))

func _process(delta: float) -> void:
	sync_active()
	for identity: int in _channels.keys():
		var channel: Channel = _channels[identity]
		if not _channel_active(channel, true):
			cancel_channel(identity)
		elif not _arena_paused(channel.arena_id):
			_update_channel_beam(channel)
	var active: bool = false
	for effect: Effect in _all_effects():
		if not effect.active:
			continue
		if _arena_paused(effect.arena_id):
			effect.sprite.speed_scale = 0.0
			active = true
			continue
		effect.sprite.speed_scale = 1.0
		effect.age += delta
		if effect.age < effect.delay:
			active = true
			continue
		var elapsed: float = effect.age - effect.delay
		var persistent: bool = (effect.channel and _channels.has(effect.caster_identity)) or (effect.model_owned and _cast_snapshot_lookup.is_valid() and _cast_effects.get(effect.caster_identity) == effect)
		if elapsed >= effect.duration and not persistent:
			if _cast_effects.get(effect.caster_identity) == effect:
				_retire_cast(effect.caster_identity)
			else:
				_stop(effect)
			continue
		active = true
		if effect.beam_span > 0 and not _channels[effect.caster_identity].visible:
			effect.sprite.visible = false
			continue
		if effect.number:
			effect.label.global_position = effect.origin.lerp(effect.target, elapsed / effect.duration)
			effect.label.modulate.a = 1.0 - elapsed / effect.duration
			continue
		if not effect.sprite.visible:
			effect.sprite.visible = true
			effect.sprite.play(effect.tag)
		var caster: ArenicHeroView = _caster_view(effect.caster_identity) if effect.follow_hero else null
		if is_instance_valid(caster):
			effect.sprite.global_position = caster.global_position + Vector3(0.0, 0.02, 0.0)
		elif effect.travel:
			effect.sprite.global_position = effect.origin.lerp(effect.target, clampf(elapsed / effect.duration, 0.0, 1.0))
	set_process(active)

func _spawn(caster_identity: int, arena_id: String, id: String, stem: String, tag: String, point: Vector3, duration: float, delay: float = 0.0, reserved: Effect = null) -> Effect:
	var frames: SpriteFrames = _frames.get(id + "/" + stem)
	if frames == null or not frames.has_animation(tag):
		return null
	var effect: Effect = reserved if reserved != null else _acquire(caster_identity, arena_id)
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

func _acquire(caster_identity: int, arena_id: String) -> Effect:
	var owner: int = caster_identity if caster_identity >= 0 and caster_identity < CASTER_LIMIT else -1
	var chosen: Effect
	var count: int = 0
	for effect: Effect in _pool:
		if effect.caster_identity != owner:
			continue
		count += 1
		if not effect.active:
			chosen = effect
			break
		if chosen == null or effect.serial < chosen.serial:
			chosen = effect
	if (chosen == null or chosen.active) and count < POOL_LIMIT:
		chosen = _create_effect((owner + 1) * POOL_LIMIT + count, true)
		_pool.append(chosen)
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
	chosen.caster_identity = owner
	chosen.beam_span = 0
	chosen.ability = ""
	chosen.arena_id = arena_id
	chosen.sprite.speed_scale = 1.0
	chosen.sprite.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
	chosen.sprite.scale = Vector3.ONE
	return chosen

func _stop(effect: Effect) -> void:
	effect.active = false
	effect.sprite.stop()
	effect.sprite.visible = false
	if is_instance_valid(effect.label):
		effect.label.visible = false

func _arena(id: String) -> ArenicArenaDefinition:
	if not is_instance_valid(_stage):
		return null
	var index: int = _stage.world.index_for_id(id)
	return _stage.world.arenas[index] if index >= 0 else null

func _point(arena: ArenicArenaDefinition, cell: Vector2i) -> Vector3:
	return ArenicGridMath.tile_to_world(arena.grid_slot, cell) + Vector3(0.0, 0.05, 0.0)

func _channel_active(channel: Channel, fallback: bool) -> bool:
	if not _channel_status_lookup.is_valid():
		return fallback
	var caster: ArenicHeroView = _caster_view(channel.caster_identity)
	return is_instance_valid(caster) and _channel_status_lookup.call(caster.state)


func _update_channel_beam(channel: Channel) -> void:
	channel.visible = false
	if not channel.target_id.is_empty() and _target_pose_lookup.is_valid():
		var pose: Dictionary = _target_pose_lookup.call(channel.arena_id, channel.target_id)
		if pose.is_empty():
			return
		var arena: ArenicArenaDefinition = _arena(channel.arena_id)
		if arena == null:
			return
		var center: Vector2 = pose.center
		channel.target = ArenicGridMath.arena_origin(arena.grid_slot) + Vector3(center.x, float(pose.lift), -center.y) * ArenicGridMath.TILE_SIZE + Vector3(0, 0.05, 0)
		# Use the same nearest occupied-cell Chebyshev reach as combat. During
		# flight the footprint size travels with the derived visual center;
		# this tests the tether's reach, not airborne ground-hit eligibility.
		var half_size := Vector2(Rect2i(pose.footprint).size - Vector2i.ONE) * 0.5
		var nearest: Vector2 = Vector2(channel.cell).clamp(center - half_size, center + half_size)
		var separation: Vector2 = (nearest - Vector2(channel.cell)).abs()
		if maxf(separation.x, separation.y) > channel.range_tiles:
			return
	var delta: Vector3 = channel.target - channel.origin
	var planar := Vector3(delta.x, 0, delta.z)
	var length: float = planar.length()
	if length < PIXEL_SIZE:
		return
	channel.visible = true
	var direction: Vector3 = planar / length
	# Keep the native pixels' projected width while following the target's
	# height toward the top-down camera; a tilted unit basis would shorten it.
	var along: Vector3 = direction + Vector3.UP * (delta.y / length)
	var across: Vector3 = Vector3.UP.cross(direction)
	var beam_basis := Basis(along, across, along.cross(across).normalized())
	# Tile the native strip instead of stretching its pixels. The final strip is
	# clipped through AtlasTexture regions; masters and shared frames stay intact.
	var remaining: float = length / PIXEL_SIZE
	var travelled: float = 0.0
	var used: int = 0
	for segment: int in 4:
		if remaining <= 0.0:
			break
		var span: int = mini(74, ceili(remaining))
		var position: Vector3 = channel.origin + along * travelled * PIXEL_SIZE
		var effect: Effect = channel.segments[segment] if segment < channel.segments.size() else _spawn(channel.caster_identity, channel.arena_id, "heal", "life_stream", "transfer", position, 1.0, 0.0, _channel_effect(channel, segment + 1))
		if effect == null:
			return
		if segment >= channel.segments.size():
			effect.age = channel.effects[0].age
			channel.segments.append(effect)
		effect.channel = true
		effect.sprite.global_position = position
		effect.sprite.basis = beam_basis
		if effect.beam_span != span:
			effect.beam_span = span
			effect.sprite.sprite_frames = _beam_strip_frames(span)
			effect.sprite.offset.x = floorf(float(span + 2) * 0.5) - 1.0
			ArenicHeroView.seek_native_animation(effect.sprite, effect.age)
		effect.sprite.visible = true
		travelled += span
		remaining -= span
		used += 1
	while channel.segments.size() > used:
		_stop(channel.segments.pop_back())


func _beam_strip_frames(span: int) -> SpriteFrames:
	if span == 74:
		return _frames["heal/life_stream"]
	if _beam_frames.has(span):
		return _beam_frames[span]
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
	_beam_frames[span] = clipped
	return clipped


func _create_effect(track: int, with_label: bool) -> Effect:
	var effect := Effect.new()
	effect.sprite = AnimatedSprite3D.new()
	effect.sprite.name = "Effect%d" % track
	effect.sprite.pixel_size = PIXEL_SIZE
	effect.sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	effect.sprite.shaded = false
	effect.sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	effect.sprite.rotation.x = -PI * 0.5
	effect.sprite.render_priority = 2
	effect.sprite.visible = false
	add_child(effect.sprite)
	if with_label:
		effect.label = Label3D.new()
		effect.label.name = "Damage%d" % track
		effect.label.font = DAMAGE_FONT
		effect.label.font_size = 16
		effect.label.pixel_size = PIXEL_SIZE
		effect.label.rotation.x = -PI * 0.5
		effect.label.no_depth_test = false
		effect.label.render_priority = 3
		effect.label.visible = false
		add_child(effect.label)
	effect.track_id = track
	return effect


func _channel_effect(channel: Channel, slot: int) -> Effect:
	assert(slot >= 0 and slot < CAST_EFFECT_SLOTS)
	if slot == channel.effects.size():
		channel.effects.append(_create_effect(TRANSIENT_TRACKS + channel.caster_identity * CAST_EFFECT_SLOTS + slot, false))
	var effect: Effect = channel.effects[slot]
	_serial += 1
	effect.serial = _serial
	effect.age = 0.0
	effect.beam_span = 0
	effect.active = true
	effect.channel = true
	effect.caster_identity = channel.caster_identity
	effect.arena_id = channel.arena_id
	return effect


func _all_effects() -> Array[Effect]:
	var effects: Array[Effect] = _pool.duplicate()
	effects.append_array(_cast_effects.values())
	for channel: Channel in _channels.values():
		effects.append_array(channel.effects)
	return effects


func channel_snapshots() -> Array[Dictionary]:
	var snapshots: Array[Dictionary] = []
	var identities: Array = _channels.keys()
	identities.sort()
	for identity: int in identities:
		var channel: Channel = _channels[identity]
		var frames: Array[int] = []
		for effect: Effect in channel.segments:
			frames.append(effect.sprite.frame)
		snapshots.append({"caster": identity, "arena": channel.arena_id, "target_id": channel.target_id,
			"visible": channel.visible, "origin": channel.origin, "target": channel.target,
			"segments": channel.segments.size(), "frames": frames, "age": channel.effects[0].age})
	return snapshots


## One authoritative in-flight cast per hero; these slots cannot be stolen by hits.
func _reserve_cast(identity: int, arena_id: String, cast_id: int, model_owned: bool = true) -> Effect:
	var effect: Effect = _create_effect(TRANSIENT_TRACKS + identity * CAST_EFFECT_SLOTS, false)
	_serial += 1
	effect.serial = _serial
	effect.caster_identity = identity
	effect.cast_id = cast_id
	effect.model_owned = model_owned
	effect.arena_id = arena_id
	effect.active = true
	_cast_effects[identity] = effect
	return effect


func _retire_cast(identity: int, cancel_actor: bool = true) -> void:
	var effect: Effect = _cast_effects.get(identity)
	if effect == null:
		return
	_stop(effect)
	effect.sprite.free()
	if cancel_actor and effect.follow_hero:
		var caster: ArenicHeroView = _caster_view(identity)
		if is_instance_valid(caster):
			caster.cancel_ability()
	_cast_effects.erase(identity)


## Read-only diagnostic view. Nodes and presentation clocks are never save data.
func cast_effect_snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var identities: Array = _cast_effects.keys()
	identities.sort()
	for identity: int in identities:
		var effect: Effect = _cast_effects[identity]
		result.append({"caster":identity, "ability":effect.ability, "arena":effect.arena_id,
			"age":effect.age, "frame":effect.sprite.frame, "visible":effect.sprite.visible,
			"cast_id":effect.cast_id, "position":effect.sprite.global_position})
	return result
