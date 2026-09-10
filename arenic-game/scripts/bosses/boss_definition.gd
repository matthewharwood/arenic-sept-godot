class_name ArenicBossDefinition
extends Resource
## Boss presentation data only. Canvas size is not a collision footprint.

const FRAME_SIZE: Vector2i = Vector2i(114, 114)
const FRAME_PIVOT: Vector2i = Vector2i(57, 57)

@export var boss_id: String = ""
@export var display_name: String = ""
@export var portrait: Texture2D
## Repository-relative authoring reference; never loaded through ResourceLoader.
@export var source_sprite_path: String = ""
@export var sprite_frame_size_px: Vector2i = FRAME_SIZE
@export var sprite_pivot_px: Vector2i = FRAME_PIVOT
@export var sprite_frames: SpriteFrames
@export_file("*.json") var sprite_metadata_path: String = ""
@export var default_state_id: String = ""
@export var visual_states: Array[ArenicBossVisualState] = []


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if boss_id.is_empty() or boss_id != boss_id.strip_edges():
		errors.append("Boss ID must be nonempty and have no surrounding whitespace.")
	if display_name.strip_edges().is_empty():
		errors.append("Display name is missing.")
	if portrait == null:
		errors.append("Portrait is missing.")
	if source_sprite_path != "assets/bosses/%s/%s.aseprite" % [boss_id, boss_id]:
		errors.append("Source must reference the repository's matching boss Aseprite file.")
	if sprite_frame_size_px != FRAME_SIZE or sprite_pivot_px != FRAME_PIVOT:
		errors.append("Boss art requires a 114x114 canvas and pivot (57,57).")
	if sprite_metadata_path != "res://assets/bosses/%s/%s.json" % [boss_id, boss_id]:
		errors.append("Sprite metadata must reference the matching runtime boss JSON.")
	_validate_states(errors)
	if sprite_frames == null:
		errors.append("SpriteFrames resource is missing.")
	else:
		_validate_export(errors)
	return errors


func _validate_states(errors: PackedStringArray) -> void:
	var ids: Dictionary = {}
	var prefixes: Dictionary = {}
	for state in visual_states:
		if state == null:
			errors.append("Visual states contain an empty resource.")
			continue
		if state.state_id.is_empty() or state.state_id != state.state_id.strip_edges() or ids.has(state.state_id):
			errors.append("Visual state IDs must be nonempty and unique: %s." % state.state_id)
		ids[state.state_id] = true
		if state.tag_prefix.is_empty() or state.tag_prefix != state.tag_prefix.strip_edges() or prefixes.has(state.tag_prefix):
			errors.append("Visual state prefixes must be nonempty and unique: %s." % state.tag_prefix)
		prefixes[state.tag_prefix] = true
		if sprite_frames != null:
			for tag in state.animation_tags():
				if not sprite_frames.has_animation(tag):
					errors.append("Visual state is missing animation '%s'." % tag)
	if not ids.has(default_state_id) or default_state_id.is_empty():
		errors.append("Default visual state is missing from visual_states.")
	if sprite_frames != null:
		for direction in ArenicBossVisualState.DIRECTIONS:
			if not sprite_frames.has_animation("idle_%s" % direction):
				errors.append("The default idle alias is missing for '%s'." % direction)


func _validate_export(errors: PackedStringArray) -> void:
	var file := FileAccess.open(sprite_metadata_path, FileAccess.READ)
	if file == null:
		errors.append("Cannot read sprite metadata: %s." % sprite_metadata_path)
		return
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		errors.append("Sprite metadata is invalid JSON: %s." % parser.get_error_message())
		return
	if not parser.data is Dictionary:
		errors.append("Sprite metadata must be a JSON object.")
		return
	var data: Dictionary = parser.data
	if not data.get("frames") is Array or not data.get("meta") is Dictionary:
		errors.append("Sprite metadata needs a frames array and meta object.")
		return
	var frames: Array = data["frames"]
	var metadata: Dictionary = data["meta"]
	if frames.is_empty() or not metadata.get("frameTags") is Array:
		errors.append("Sprite metadata needs nonempty frames and frameTags.")
		return
	_validate_source_frames(frames, errors)
	_validate_slice(metadata, errors)
	var seen_tags: Dictionary = {}
	for value in metadata["frameTags"]:
		if not value is Dictionary:
			errors.append("A source animation tag is not an object.")
			continue
		var tag: Dictionary = value
		var tag_name: String = str(tag.get("name", ""))
		if tag_name.is_empty() or seen_tags.has(tag_name):
			errors.append("Source animation names must be nonempty and unique: %s." % tag_name)
			continue
		seen_tags[tag_name] = true
		if not _is_integer(tag.get("from")) or not _is_integer(tag.get("to")):
			errors.append("Source animation '%s' has invalid frame indices." % tag_name)
			continue
		var first: int = int(tag["from"])
		var last: int = int(tag["to"])
		if first < 0 or last < first or last >= frames.size():
			errors.append("Source animation '%s' has an out-of-range frame span." % tag_name)
			continue
		if tag.get("direction", "forward") != "forward":
			errors.append("Source animation '%s' must be a forward appearance loop." % tag_name)
		_validate_animation(tag_name, first, last, frames, errors)
	for animation in sprite_frames.get_animation_names():
		if not seen_tags.has(animation):
			errors.append("Runtime animation '%s' is absent from source metadata." % animation)
	if seen_tags.is_empty():
		errors.append("Source metadata has no animation tags.")
	_validate_idle_aliases(errors)


func _validate_source_frames(frames: Array, errors: PackedStringArray) -> void:
	for index in range(frames.size()):
		if not frames[index] is Dictionary:
			errors.append("Source frame %d is not an object." % index)
			continue
		var frame: Dictionary = frames[index]
		var region := _json_rect(frame.get("frame"))
		if region.size != Vector2(FRAME_SIZE) or region.position.x < 0 or region.position.y < 0:
			errors.append("Source frame %d must be an untrimmed 114x114 region." % index)
		if frame.get("rotated", false) or frame.get("trimmed", false):
			errors.append("Source frame %d must not be rotated or trimmed." % index)
		if _json_rect(frame.get("spriteSourceSize")) != Rect2(Vector2.ZERO, Vector2(FRAME_SIZE)):
			errors.append("Source frame %d has an unexpected sprite offset." % index)
		var source_size: Variant = frame.get("sourceSize")
		if not source_size is Dictionary or source_size.get("w") != 114 or source_size.get("h") != 114:
			errors.append("Source frame %d has an unexpected canvas size." % index)
		if not _is_positive_number(frame.get("duration")):
			errors.append("Source frame %d needs a positive duration in milliseconds." % index)


func _validate_slice(metadata: Dictionary, errors: PackedStringArray) -> void:
	if not metadata.get("slices") is Array:
		errors.append("Source metadata needs the exported 'frame' slice to verify its pivot.")
		return
	var found: bool = false
	for value in metadata["slices"]:
		if not value is Dictionary or value.get("name") != "frame":
			continue
		found = true
		if not value.get("keys") is Array or value["keys"].is_empty():
			errors.append("The frame slice has no keys.")
			continue
		for key in value["keys"]:
			if not key is Dictionary:
				errors.append("A frame slice key is invalid.")
				continue
			var pivot: Variant = key.get("pivot")
			if not pivot is Dictionary or pivot.get("x") != 57 or pivot.get("y") != 57:
				errors.append("The source frame slice pivot must remain (57,57).")
			if _json_rect(key.get("bounds")) != Rect2(Vector2.ZERO, Vector2(FRAME_SIZE)):
				errors.append("The source frame slice must cover the full 114x114 canvas.")
	if not found:
		errors.append("Source metadata has no 'frame' slice.")


func _validate_animation(tag: String, first: int, last: int, frames: Array, errors: PackedStringArray) -> void:
	if not sprite_frames.has_animation(tag):
		errors.append("Runtime SpriteFrames is missing source animation '%s'." % tag)
		return
	if sprite_frames.get_frame_count(tag) != last - first + 1:
		errors.append("Animation '%s' has a different frame count from its source." % tag)
		return
	var speed: float = sprite_frames.get_animation_speed(tag)
	if not is_finite(speed) or speed <= 0.0:
		errors.append("Animation '%s' needs a positive playback speed." % tag)
		return
	if not sprite_frames.get_animation_loop(tag):
		errors.append("Appearance animation '%s' must loop." % tag)
	for index in range(last - first + 1):
		if not frames[first + index] is Dictionary:
			continue
		var expected: Dictionary = frames[first + index]
		var duration: float = sprite_frames.get_frame_duration(tag, index)
		if not is_finite(duration) or duration <= 0.0:
			errors.append("Animation '%s' frame %d needs a positive duration." % [tag, index])
		elif _is_positive_number(expected.get("duration")) and not is_equal_approx(duration / speed, float(expected["duration"]) / 1000.0):
			errors.append("Animation '%s' frame %d duration differs from Aseprite." % [tag, index])
		var texture := sprite_frames.get_frame_texture(tag, index) as AtlasTexture
		if texture == null or texture.atlas == null:
			errors.append("Animation '%s' frame %d needs an atlas texture." % [tag, index])
			continue
		if texture.atlas.resource_path != "res://assets/bosses/%s/%s.png" % [boss_id, boss_id]:
			errors.append("Animation '%s' frame %d uses the wrong atlas." % [tag, index])
		if texture.region != _json_rect(expected.get("frame")):
			errors.append("Animation '%s' frame %d region differs from Aseprite." % [tag, index])
		if texture.margin != Rect2() or texture.get_size() != Vector2(FRAME_SIZE):
			errors.append("Animation '%s' frame %d has a trimmed or shifted canvas." % [tag, index])
		if not Rect2(Vector2.ZERO, texture.atlas.get_size()).encloses(texture.region):
			errors.append("Animation '%s' frame %d extends outside its atlas." % [tag, index])


func _validate_idle_aliases(errors: PackedStringArray) -> void:
	var default_prefix: String = ""
	for state in visual_states:
		if state != null and state.state_id == default_state_id:
			default_prefix = state.tag_prefix
			break
	if default_prefix.is_empty() or default_prefix == "idle":
		return
	for direction in ArenicBossVisualState.DIRECTIONS:
		var alias: String = "idle_%s" % direction
		var original: String = "%s_%s" % [default_prefix, direction]
		if not sprite_frames.has_animation(alias) or not sprite_frames.has_animation(original):
			continue
		if sprite_frames.get_frame_count(alias) != sprite_frames.get_frame_count(original):
			errors.append("Idle alias '%s' differs from its default appearance loop." % alias)
			continue
		for index in range(sprite_frames.get_frame_count(alias)):
			var alias_texture := sprite_frames.get_frame_texture(alias, index) as AtlasTexture
			var original_texture := sprite_frames.get_frame_texture(original, index) as AtlasTexture
			if alias_texture == null or original_texture == null:
				continue
			if alias_texture.region != original_texture.region or not is_equal_approx(sprite_frames.get_frame_duration(alias, index), sprite_frames.get_frame_duration(original, index)):
				errors.append("Idle alias '%s' frame %d differs from its default appearance." % [alias, index])
		if not is_equal_approx(sprite_frames.get_animation_speed(alias), sprite_frames.get_animation_speed(original)):
			errors.append("Idle alias '%s' has a different playback speed." % alias)


static func _is_positive_number(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value)) and float(value) > 0.0


static func _is_integer(value: Variant) -> bool:
	return (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT) and is_finite(float(value)) and float(value) == floor(float(value))


static func _json_rect(value: Variant) -> Rect2:
	if not value is Dictionary:
		return Rect2(-1, -1, -1, -1)
	for key in ["x", "y", "w", "h"]:
		if not _is_integer(value.get(key)):
			return Rect2(-1, -1, -1, -1)
	return Rect2(float(value["x"]), float(value["y"]), float(value["w"]), float(value["h"]))
