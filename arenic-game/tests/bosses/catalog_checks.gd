extends SceneTree
## Run after boss exports/imports finish and the visible game stops:
## Godot --headless --path arenic-game --script res://tests/bosses/catalog_checks.gd
## Negative fixtures are in memory; no resources or source assets are saved.

const CATALOG_PATH: String = "res://data/bosses/catalog.tres"
const EXPECTED_STATES: Dictionary = {
	"hunter": ["cycle", "quiet", "sorrow", "startled", "wrath", "elation"],
	"warrior": ["idle"],
	"thief": ["cycle", "obsidian", "crimson", "indigo"],
	"alchemist": ["cycle", "bomb", "skull", "potion"],
	"cardinal": ["idle"],
	"bard": ["idle"],
	"forager": ["idle"],
	"merchant": ["idle"],
}

var _checks: int = 0
var _frame_samples: int = 0
var _failures := PackedStringArray()


func _initialize() -> void:
	var catalog := load(CATALOG_PATH) as ArenicBossCatalog
	if not _expect(catalog != null, "Boss catalog loads with its declared resource type."):
		_finish()
		return
	var errors := catalog.validation_errors()
	for error in errors:
		_failures.append(error)
	if not _expect(errors.is_empty(), "All boss assets agree with their exported source metadata."):
		_finish()
		return
	_expect(catalog.bosses.size() == EXPECTED_STATES.size(), "There are exactly eight bosses.")
	for index in range(catalog.bosses.size()):
		_check_boss(catalog, index)
	_expect(catalog.index_for_id("missing") == -1, "Unknown boss lookup returns -1.")
	_check_invalid_catalogs(catalog)
	_check_invalid_definitions(catalog.bosses[0])
	_check_invalid_frames(catalog.bosses[0])
	_finish()


func _check_boss(catalog: ArenicBossCatalog, index: int) -> void:
	var boss: ArenicBossDefinition = catalog.bosses[index]
	if not _expect(EXPECTED_STATES.has(boss.boss_id), "Boss identity is one of the eight supplied types."):
		return
	_expect(catalog.index_for_id(boss.boss_id) == index, "Lookup preserves catalog order for %s." % boss.boss_id)
	_expect(boss.resource_path == "res://data/bosses/%s.tres" % boss.boss_id, "Boss definition has a stable data path.")
	_expect(boss.portrait.resource_path == "res://assets/portraits/bosses/%s.png" % boss.boss_id, "Portrait belongs to the matching boss.")
	_expect(boss.sprite_frames.resource_path == "res://assets/bosses/%s/%s_frames.tres" % [boss.boss_id, boss.boss_id], "SpriteFrames belongs to the matching boss.")
	var state_ids: Array[String] = []
	for state in boss.visual_states:
		state_ids.append(state.state_id)
		_expect(state.tag_prefix == state.state_id, "State prefix preserves the authored state ID.")
		for tag in state.animation_tags():
			_expect(boss.sprite_frames.has_animation(tag), "State supplies all four cardinal animations.")
	_expect(state_ids == EXPECTED_STATES[boss.boss_id], "Appearance states match the supplied %s contract." % boss.boss_id)
	_expect(boss.default_state_id == EXPECTED_STATES[boss.boss_id][0], "Default appearance matches the supplied contract.")
	_expect(boss.sprite_frame_size_px == Vector2i(114, 114), "Boss canvas is 114x114.")
	_expect(boss.sprite_pivot_px == Vector2i(57, 57), "Boss pivot is (57,57).")
	# Authoring files intentionally live outside res:// and are checked only by this repository test.
	var repository: String = ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	_expect(FileAccess.file_exists(repository.path_join(boss.source_sprite_path)), "Native source exists outside the game directory.")
	for tag in boss.sprite_frames.get_animation_names():
		_frame_samples += boss.sprite_frames.get_frame_count(tag)


func _check_invalid_catalogs(valid: ArenicBossCatalog) -> void:
	var empty := ArenicBossCatalog.new()
	_expect(_has_error(empty.validation_errors(), "exactly 8"), "An empty catalog is rejected.")
	var duplicate := ArenicBossCatalog.new()
	duplicate.bosses.assign(valid.bosses)
	duplicate.bosses[1] = duplicate.bosses[0]
	_expect(_has_error(duplicate.validation_errors(), "unique"), "Duplicate boss IDs are rejected.")
	var missing := ArenicBossCatalog.new()
	missing.bosses.assign(valid.bosses)
	missing.bosses[0] = null
	_expect(_has_error(missing.validation_errors(), "null"), "A null boss resource is rejected.")


func _check_invalid_definitions(valid: ArenicBossDefinition) -> void:
	var altered := valid.duplicate() as ArenicBossDefinition
	altered.sprite_frame_size_px = Vector2i(113, 114)
	_expect(_has_error(altered.validation_errors(), "114x114"), "A mismatched canvas is rejected.")
	altered = valid.duplicate() as ArenicBossDefinition
	altered.sprite_pivot_px = Vector2i(56, 57)
	_expect(_has_error(altered.validation_errors(), "pivot"), "A drifting pivot is rejected.")
	altered = valid.duplicate() as ArenicBossDefinition
	altered.default_state_id = "missing"
	_expect(_has_error(altered.validation_errors(), "Default visual state"), "A missing default state is rejected.")
	altered = valid.duplicate() as ArenicBossDefinition
	var duplicate_states: Array[ArenicBossVisualState] = [valid.visual_states[0], valid.visual_states[0]]
	altered.visual_states = duplicate_states
	_expect(_has_error(altered.validation_errors(), "unique"), "Duplicate visual states are rejected.")
	altered = valid.duplicate() as ArenicBossDefinition
	altered.portrait = null
	_expect(_has_error(altered.validation_errors(), "Portrait"), "Missing portrait data is rejected.")
	altered = valid.duplicate() as ArenicBossDefinition
	altered.source_sprite_path = "res://../assets/bosses/hunter/hunter.aseprite"
	_expect(_has_error(altered.validation_errors(), "Source"), "A source path crossing the res boundary is rejected.")


func _check_invalid_frames(valid: ArenicBossDefinition) -> void:
	var altered := valid.duplicate() as ArenicBossDefinition
	altered.sprite_frames = _copy_frames(valid.sprite_frames)
	altered.sprite_frames.remove_animation("idle_w")
	_expect(_has_error(altered.validation_errors(), "missing"), "A missing directional alias is rejected.")
	altered = valid.duplicate() as ArenicBossDefinition
	altered.sprite_frames = _copy_frames(valid.sprite_frames)
	var tag: String = "idle_n"
	var texture: Texture2D = altered.sprite_frames.get_frame_texture(tag, 0)
	var duration: float = altered.sprite_frames.get_frame_duration(tag, 0)
	altered.sprite_frames.set_frame(tag, 0, texture, duration + 50.0)
	_expect(_has_error(altered.validation_errors(), "duration differs"), "Runtime duration drift is rejected.")
	altered = valid.duplicate() as ArenicBossDefinition
	altered.sprite_frames = _copy_frames(valid.sprite_frames)
	var shifted := altered.sprite_frames.get_frame_texture(tag, 0).duplicate() as AtlasTexture
	shifted.region.position.x += 1.0
	altered.sprite_frames.set_frame(tag, 0, shifted, duration)
	_expect(_has_error(altered.validation_errors(), "region differs"), "Runtime atlas region drift is rejected.")
	altered = valid.duplicate() as ArenicBossDefinition
	altered.sprite_frames = _copy_frames(valid.sprite_frames)
	altered.sprite_frames.set_animation_loop(tag, false)
	_expect(_has_error(altered.validation_errors(), "must loop"), "A non-looping appearance is rejected.")
	_expect(valid.validation_errors().is_empty(), "Invalid in-memory fixtures leave the authoritative boss unchanged.")


func _copy_frames(original: SpriteFrames) -> SpriteFrames:
	var copied := SpriteFrames.new()
	copied.remove_animation("default")
	for tag in original.get_animation_names():
		copied.add_animation(tag)
		copied.set_animation_speed(tag, original.get_animation_speed(tag))
		copied.set_animation_loop(tag, original.get_animation_loop(tag))
		for index in range(original.get_frame_count(tag)):
			copied.add_frame(tag, original.get_frame_texture(tag, index), original.get_frame_duration(tag, index))
	return copied


func _has_error(errors: PackedStringArray, fragment: String) -> bool:
	for error in errors:
		if fragment in error:
			return true
	return false


func _expect(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(message)
	return condition


func _finish() -> void:
	if _failures.is_empty():
		print("Boss catalog checks passed: %d assertions; %d animation frame references checked against Aseprite JSON." % [_checks, _frame_samples])
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("Boss catalog checks failed: %d failures in %d assertions." % [_failures.size(), _checks])
		quit(1)
