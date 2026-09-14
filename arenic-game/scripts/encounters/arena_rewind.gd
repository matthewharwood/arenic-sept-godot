class_name ArenicArenaRewind
extends Node3D
## Cosmetic rewind of poses actually sampled during this mounted stage. The
## shell alone pauses/restarts gameplay and consumes the completed arena IDs.
const History = preload("res://scripts/encounters/rewind_history.gd")
const REWIND_SPEED: float = 10.0
const MAX_REWIND_SECONDS: float = 5.0
const COUNTDOWN_SECONDS: float = 3.0
const MAX_POSES: int = 828345 # Preserve the original global history memory budget.
const MAX_CLONES: int = History.MAX_TRACKS * 3
const TRAIL_TICKS: float = 9.0
@export_range(1.0, 30.0, 0.5) var rewind_speed: float = REWIND_SPEED:
	set(value):
		rewind_speed = clampf(value, 1.0, 30.0) if is_finite(value) else REWIND_SPEED

class Playback:
	extends RefCounted
	var arena_id: String
	var cursor: float
	var end_tick: float
	var speed: float = REWIND_SPEED
	var phase: String = "rewind"
	var countdown: float = COUNTDOWN_SECONDS
	var clones: Dictionary[int, Array] = {}
	var tint: Color
	var omitted: int = 0

class Mask:
	extends RefCounted
	var node: GeometryInstance3D
	var layers: int

var _stage: ArenicOverworldStage
var _presentation: ArenicCombatPresentation
var _histories: Dictionary[String, ArenicRewindHistory] = {}
var _playing: Dictionary[String, Playback] = {}
var _masked: Dictionary[int, Mask] = {}
var _serial: int = 0
var _clone_count: int = 0

func configure(stage: ArenicOverworldStage, combat_presentation: ArenicCombatPresentation) -> void:
	_restore_masks()
	for playback: Playback in _playing.values():
		_release_clones(playback)
	_playing.clear()
	_histories.clear()
	_stage = stage
	_presentation = combat_presentation
	_serial = 0
	set_process(false) # The shell advances this boundary deliberately.

func _exit_tree() -> void:
	_restore_masks()

func capture(arena_id: String, tick: int) -> void:
	_capture(arena_id, tick, false)

func _capture(arena_id: String, tick: int, force: bool) -> void:
	if is_active(arena_id) or not is_instance_valid(_stage) or tick < 0 or tick > 7200:
		return
	var index: int = _stage.world.index_for_id(arena_id)
	if index < 0:
		return
	var history: ArenicRewindHistory = _histories.get(arena_id)
	if history == null:
		history = ArenicRewindHistory.new()
		_histories[arena_id] = history
	if history.count > 0:
		var distance: int = tick - history.last().tick
		if distance == 0:
			return
		if distance < 0 or distance > History.SAMPLE_TICKS:
			# Never bridge time that was not captured (including a loaded cycle).
			history.clear()
		elif distance < History.SAMPLE_TICKS and not force:
			return
	var frame := History.Frame.new()
	frame.tick = tick
	frame.serial = _serial
	_serial += 1
	for identity: int in _stage.hero_views:
		var view: ArenicHeroView = _stage.hero_views[identity]
		if not is_instance_valid(view) or view.state.arena_id != arena_id or identity < 0 or identity >= 320:
			continue
		var actor: AnimatedSprite3D = view._death_effect if view._fallen else view.sprite
		_append_sprite(frame, identity, 0, actor)
	var arena: ArenicArenaView = _stage.get_arena(index)
	_append_sprite(frame, 320 + index, 0, arena._boss)
	if is_instance_valid(_presentation):
		for effect: ArenicCombatPresentation.Effect in _presentation.effects_in_arena(arena_id):
			if not effect.number:
				_append_sprite(frame, 329 + (effect.track_id if effect.track_id >= 0 else _presentation._pool.find(effect)), effect.serial, effect.sprite)
	history.append(frame)
	_bound_history()

func _append_sprite(frame: History.Frame, track: int, generation: int, source: AnimatedSprite3D) -> void:
	# Arena frustum visibility is intentionally ignored: its already-updated
	# sprites still provide the same native animation poses off camera.
	if not is_instance_valid(source) or not source.visible or source.sprite_frames == null:
		return
	var texture: Texture2D = source.sprite_frames.get_frame_texture(source.animation, source.frame)
	if texture == null:
		return
	var transform: Transform3D = source.global_transform
	var rotation: Vector3 = transform.basis.get_euler()
	var scale: Vector3 = transform.basis.get_scale()
	var color: Color = source.modulate
	frame.tracks.append(track)
	frame.generations.append(generation)
	frame.textures.append(texture)
	frame.positions.append(transform.origin)
	frame.attributes.append_array(PackedFloat32Array([rotation.x, rotation.y, rotation.z,
		scale.x, scale.y, scale.z, source.pixel_size, source.offset.x, source.offset.y,
		color.r, color.g, color.b, color.a, float(source.render_priority),
		float((1 if source.flip_h else 0) | (2 if source.flip_v else 0))]))

func _bound_history() -> void:
	var poses: int = 0
	for history: ArenicRewindHistory in _histories.values():
		poses += history.poses
	while poses > MAX_POSES:
		var oldest: ArenicRewindHistory
		for arena_id: String in _histories:
			var history: ArenicRewindHistory = _histories[arena_id]
			if is_active(arena_id) or history.count == 0:
				continue
			if oldest == null or history.first().serial < oldest.first().serial:
				oldest = history
		if oldest == null:
			break
		poses -= oldest.first().tracks.size()
		oldest.pop_first()

func begin(arena_id: String, end_tick: int, rewind: bool = true) -> void:
	if is_active(arena_id) or not is_instance_valid(_stage) or _stage.world.index_for_id(arena_id) < 0:
		return
	_capture(arena_id, clampi(end_tick, 0, 7200), true)
	var playback := Playback.new()
	playback.arena_id = arena_id
	playback.cursor = float(end_tick)
	playback.end_tick = float(end_tick)
	playback.tint = _stage.world.arenas[_stage.world.index_for_id(arena_id)].visual_theme.color("accent")
	var history: ArenicRewindHistory = _histories.get(arena_id)
	if not rewind or history == null or history.count < 2:
		playback.phase = "countdown"
		playback.cursor = 0.0
	else:
		playback.cursor = float(history.last().tick)
		playback.end_tick = playback.cursor
		# Fit the entire captured span into the deadline without lengthening short
		# rewinds. Freeze this rate so Inspector edits cannot extend an active one.
		var span_ticks: float = playback.end_tick - float(history.first().tick)
		playback.speed = maxf(rewind_speed, span_ticks / (60.0 * MAX_REWIND_SECONDS))
	_playing[arena_id] = playback
	_refresh_masks()
	if playback.phase == "rewind":
		_draw_playback(playback)

func advance(delta: float) -> Array[String]:
	var finished: Array[String] = []
	if not is_finite(delta) or delta <= 0.0:
		return finished
	for arena_id: String in _playing.keys():
		var playback: Playback = _playing[arena_id]
		var remaining: float = delta
		if playback.phase == "rewind":
			var history: ArenicRewindHistory = _histories[arena_id]
			var until_start: float = maxf(0.0, playback.cursor - float(history.first().tick)) / (60.0 * playback.speed)
			if remaining + 0.000000001 < until_start:
				playback.cursor -= remaining * 60.0 * playback.speed
				_draw_playback(playback)
				continue
			remaining = maxf(0.0, remaining - until_start)
			playback.cursor = 0.0
			playback.phase = "countdown"
			_release_clones(playback)
		playback.countdown = maxf(0.0, playback.countdown - remaining)
		if playback.countdown <= 0.000001:
			finished.append(arena_id)
			_playing.erase(arena_id)
			clear_history(arena_id)
	_refresh_masks()
	return finished

func is_active(arena_id: String) -> bool:
	return _playing.has(arena_id)

func phase(arena_id: String) -> String:
	return _playing[arena_id].phase if is_active(arena_id) else ""

func display_tick(arena_id: String) -> float:
	return _playing[arena_id].cursor if is_active(arena_id) else 0.0

func countdown_seconds(arena_id: String) -> int:
	return ceili(_playing[arena_id].countdown - 0.000001) if phase(arena_id) == "countdown" else 0

func clear_history(arena_id: String) -> void:
	if not is_active(arena_id):
		_histories.erase(arena_id)

func snapshot(arena_id: String) -> Dictionary:
	var history: ArenicRewindHistory = _histories.get(arena_id)
	var playback: Playback = _playing.get(arena_id)
	var visible_clones: int = 0
	if playback != null:
		for sprites: Array in playback.clones.values():
			for sprite: Sprite3D in sprites:
				visible_clones += 1 if sprite.visible else 0
	return {"phase": phase(arena_id), "display_tick": display_tick(arena_id), "countdown": countdown_seconds(arena_id),
		"countdown_seconds": countdown_seconds(arena_id), "samples": history.count if history != null else 0,
		"first_tick": history.first().tick if history != null and history.count > 0 else -1,
		"last_tick": history.last().tick if history != null and history.count > 0 else -1,
		"visible_clones": visible_clones, "omitted_tracks": playback.omitted if playback != null else 0}

func _draw_playback(playback: Playback) -> void:
	for sprites: Array in playback.clones.values():
		for sprite: Sprite3D in sprites:
			sprite.hide()
	playback.omitted = 0
	for trail: int in 3:
		_draw_at(playback, minf(playback.end_tick, playback.cursor + TRAIL_TICKS * trail), trail)
	for track: int in playback.clones.keys():
		var sprites: Array = playback.clones[track]
		if not sprites[0].visible and not sprites[1].visible and not sprites[2].visible:
			for sprite: Sprite3D in sprites:
				sprite.free()
				_clone_count -= 1
			playback.clones.erase(track)

func _draw_at(playback: Playback, tick: float, trail: int) -> void:
	var history: ArenicRewindHistory = _histories[playback.arena_id]
	var index: int = history.floor_index(tick)
	var before: History.Frame = history.at(index)
	var after: History.Frame = history.at(mini(index + 1, history.count - 1))
	var fraction: float = (tick - before.tick) / float(after.tick - before.tick) if after.tick > before.tick else 0.0
	var later_poses := PackedInt32Array()
	later_poses.resize(History.MAX_TRACKS)
	later_poses.fill(-1)
	for pose: int in after.tracks.size():
		later_poses[after.tracks[pose]] = pose
	for pose: int in before.tracks.size():
		var track: int = before.tracks[pose]
		var sprites: Array = playback.clones.get(track, [])
		if sprites.is_empty():
			if _clone_count + 3 > MAX_CLONES:
				playback.omitted += 1
				continue
			for number: int in 3:
				var sprite := Sprite3D.new()
				sprite.name = "Rewind%dTrail%d" % [track, number]
				sprite.shaded = false
				sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				sprite.hide()
				add_child(sprite)
				sprites.append(sprite)
				_clone_count += 1
			playback.clones[track] = sprites
		var clone: Sprite3D = sprites[trail]
		var later: int = later_poses[track]
		if later >= 0 and before.generations[pose] != after.generations[later]:
			later = -1 # A recycled FX slot must never fly between unrelated casts.
		var offset: int = pose * History.STRIDE
		var position: Vector3 = before.positions[pose]
		var rotation := Vector3(before.attributes[offset], before.attributes[offset + 1], before.attributes[offset + 2])
		var scale := Vector3(before.attributes[offset + 3], before.attributes[offset + 4], before.attributes[offset + 5])
		if later >= 0:
			position = position.lerp(after.positions[later], fraction)
			var next: int = later * History.STRIDE
			rotation = Vector3(lerp_angle(rotation.x, after.attributes[next], fraction), lerp_angle(rotation.y, after.attributes[next + 1], fraction), lerp_angle(rotation.z, after.attributes[next + 2], fraction))
			scale = scale.lerp(Vector3(after.attributes[next + 3], after.attributes[next + 4], after.attributes[next + 5]), fraction)
		clone.texture = before.textures[pose]
		clone.global_transform = Transform3D(Basis.from_euler(rotation).scaled(scale), position)
		clone.pixel_size = before.attributes[offset + 6]
		clone.offset = Vector2(before.attributes[offset + 7], before.attributes[offset + 8])
		clone.modulate = Color(before.attributes[offset + 9], before.attributes[offset + 10], before.attributes[offset + 11], before.attributes[offset + 12])
		clone.render_priority = int(before.attributes[offset + 13]) - trail
		var flips: int = int(before.attributes[offset + 14])
		clone.flip_h = (flips & 1) != 0
		clone.flip_v = (flips & 2) != 0
		if trail > 0:
			var opacity: float = clone.modulate.a
			clone.modulate = clone.modulate.lerp(playback.tint, 0.35)
			clone.modulate.a = opacity * (0.28 if trail == 1 else 0.12)
		clone.show()

func _release_clones(playback: Playback) -> void:
	for sprites: Array in playback.clones.values():
		for sprite: Sprite3D in sprites:
			sprite.free()
			_clone_count -= 1
	playback.clones.clear()

func _refresh_masks() -> void:
	var wanted: Dictionary[int, GeometryInstance3D] = {}
	if is_instance_valid(_stage):
		for arena_id: String in _playing:
			if phase(arena_id) != "rewind":
				continue
			for view: ArenicHeroView in _stage.hero_views.values():
				if is_instance_valid(view) and view.state.arena_id == arena_id:
					_collect_geometry(view, wanted)
			var arena: ArenicArenaView = _stage.get_arena(_stage.world.index_for_id(arena_id))
			for node: Node3D in [arena._boss, arena._blast, arena._ground, arena._acid]:
				_collect_geometry(node, wanted)
			if is_instance_valid(_presentation):
				for effect: ArenicCombatPresentation.Effect in _presentation.effects_in_arena(arena_id):
					_collect_geometry(effect.sprite, wanted)
					_collect_geometry(effect.label, wanted)
	for identity: int in _masked.keys():
		if not wanted.has(identity):
			var mask: Mask = _masked[identity]
			if is_instance_valid(mask.node):
				mask.node.layers = mask.layers
			_masked.erase(identity)
	for identity: int in wanted:
		if not _masked.has(identity):
			var mask := Mask.new()
			mask.node = wanted[identity]
			mask.layers = mask.node.layers
			_masked[identity] = mask
		wanted[identity].layers = 0

func _collect_geometry(node: Node, result: Dictionary[int, GeometryInstance3D]) -> void:
	if not is_instance_valid(node):
		return
	if node is GeometryInstance3D:
		result[node.get_instance_id()] = node
	for child: Node in node.get_children():
		_collect_geometry(child, result)

func _restore_masks() -> void:
	for mask: Mask in _masked.values():
		if is_instance_valid(mask.node):
			mask.node.layers = mask.layers
	_masked.clear()
