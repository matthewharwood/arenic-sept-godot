extends SceneTree
## Godot --headless --path arenic-game --script res://tests/combat/presentation_checks.gd
## Native resource semantics and elapsed-time handoff; rendered appearance needs a playtest.
var _checks: int = 0
var _failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/abilities/starter_manifest.json"))
	var catalog: Dictionary = ArenicCombatPresentation.CATALOG.get_meta("abilities")
	_check(manifest.size() == 8 and catalog.size() == 8, "Exactly eight authorized starter abilities")
	var sheets: int = 0
	for id: String in manifest:
		var row: Dictionary = manifest[id]
		var assets: Dictionary = row.assets.duplicate()
		assets.actor = row.actor
		for stem: String in assets:
			sheets += 1
			var asset: Dictionary = assets[stem]
			var frames := load(asset.sprite_frames) as SpriteFrames
			_check(frames != null, "Native SpriteFrames loads: " + id + "/" + stem)
			if frames == null:
				continue
			var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/abilities/%s/%s.json" % [id, stem]))
			var native_frames: Array = metadata.frames
			for tag: Dictionary in metadata.meta.frameTags:
				var name: String = tag.name
				_check(frames.has_animation(name), "Native tag: " + name)
				_check(frames.get_frame_count(name) == int(tag.to) - int(tag.from) + 1, "Frame count: " + name)
				_check(frames.get_animation_loop(name) == bool(asset.tags[name].loop), "Loop contract: " + name)
				var duration: float = 0.0
				for index: int in frames.get_frame_count(name):
					var source: Dictionary = native_frames[int(tag.from) + index]
					var frame_duration: float = frames.get_frame_duration(name, index) / frames.get_animation_speed(name)
					_check(is_equal_approx(frame_duration, float(source.duration) / 1000.0), "Native per-frame hold")
					duration += frame_duration
					var atlas := frames.get_frame_texture(name, index) as AtlasTexture
					_check(atlas != null and atlas.region == Rect2(source.frame.x, source.frame.y, source.frame.w, source.frame.h), "Untrimmed source region")
					_check(atlas.atlas.get_width() == int(metadata.meta.size.w) and atlas.atlas.get_height() == int(metadata.meta.size.h), "Imported native atlas dimensions")
				_check(is_equal_approx(duration, float(asset.tags[name].duration_ms) / 1000.0), "Tag timing")
			if stem == "actor":
				_check(asset.canvas == [19.0, 19.0] and asset.pivot == [9.0, 9.0], "Native actor canvas and pivot")
			else:
				_check(catalog[id].assets[stem].sprite_frames == asset.sprite_frames, "Exportable Resource catalog includes FX")
	_check(sheets == 26, "Eight actors and eighteen distinct FX sheets")
	var world := load("res://data/world/arenia.tres") as ArenicWorldDefinition
	var stage := ArenicOverworldStage.new() # Data-only owner; no scene or renderer startup.
	stage.world = world
	for id: String in manifest:
		var hero := ArenicHeroState.new()
		hero.definition = load("res://data/classes/%s.tres" % manifest[id].hero) as ArenicClassDefinition
		var view := ArenicHeroView.new()
		root.add_child(view)
		view.configure(hero)
		view.sync(world.arenas[1], true)
		view.play_ability(id, "e")
		_check(view.sprite.sprite_frames != hero.definition.world_sprite_frames, "Starter actor frames selected: " + id)
		view.restore_ability(id, "e", 0.31)
		if id == "heal":
			_check(view.sprite.animation == "e_channel", "Channel handoff skips completed connect")
			view.cancel_ability()
			_check(view.sprite.animation == "e_release", "Channel cancellation preserves native release")
		view.restore_ability(id, "e", 25.0)
		if id != "heal":
			_check(view.sprite.animation == "idle_n", "Completed handoff returns to authoritative idle: " + id)
		view.cancel_ability(true)
		_check(view.sprite.sprite_frames == hero.definition.world_sprite_frames, "Idle resource restored")
		view.free()
	var hero := ArenicHeroState.new()
	hero.definition = load("res://data/classes/hunter.tres") as ArenicClassDefinition
	var view := ArenicHeroView.new()
	root.add_child(view)
	view.configure(hero)
	view.sync(world.arenas[1], false)
	stage.hero_views[hero.identity_id] = view
	stage.selected_identity = hero.identity_id
	var presentation := ArenicCombatPresentation.new()
	root.add_child(presentation)
	presentation.configure(stage)
	var shot: Dictionary = {"ability_id":"auto_shot", "arena_id":"guild_house", "origin":Vector2i(30,15), "target_cell":Vector2i(38,15), "facing":"e", "elapsed":0.5, "remaining":0.25, "is_channeling":false, "cast_seconds":0.75, "release_seconds":0.26, "cast_id":1, "released":true, "duration_seconds":0.0}
	presentation.restore_active(shot)
	_check(presentation.active_effect_count() == 1, "Exactly one in-flight arrow restored")
	var arrow: Variant = presentation._pool[0]
	var start: Vector3 = ArenicGridMath.tile_to_world(world.arenas[1].grid_slot, Vector2i(30,15)) + Vector3(0,0.05,0)
	var finish: Vector3 = start + Vector3(2,0,0)
	_check(arrow.sprite.global_position.is_equal_approx(start.lerp(finish, (0.5 - 0.26) / (0.75 - 0.26))), "Arrow resumes elapsed flight rather than replaying origin")
	var slower := (load("res://data/classes/hunter_primary.tres") as ArenicClassAbility).duplicate() as ArenicClassAbility
	slower.cast_seconds = 1.5
	presentation.clear()
	presentation.show_cast(0, "auto_shot", "guild_house", Vector2i(30,15), Vector2i(38,15), "e", slower)
	_check(is_equal_approx(presentation._pool[0].duration + presentation._pool[0].delay, 1.5), "Data-tuned cast duration controls projectile landing")
	shot.elapsed = 0.8
	presentation.restore_active(shot)
	_check(presentation.active_effect_count() == 0, "Landed projectile is not resurrected")
	presentation.clear()
	presentation.show_cast(0, "cleanse", "guild_house", Vector2i(10,10), Vector2i(10,10), "n", load("res://data/classes/bard_primary.tres"))
	var expected: Vector3 = ArenicGridMath.tile_to_world(world.arenas[1].grid_slot, Vector2i(10,10)) + Vector3(0.125,0.05,-0.125)
	_check(presentation._pool[0].sprite.global_position.is_equal_approx(expected), "Even four-tile wave centers over occupied cells")
	presentation.clear()
	presentation.show_cast(0, "cleanse", "guild_house", Vector2i.ZERO, Vector2i.ZERO, "n", load("res://data/classes/bard_primary.tres"))
	expected = ArenicGridMath.arena_origin(world.arenas[1].grid_slot) + Vector3(0.375,0.05,-0.375)
	_check(presentation._pool[0].sprite.global_position.is_equal_approx(expected), "Wave follows model edge clamp")
	presentation.restore_active({"ability_id":"fortune", "arena_id":"guild_house", "origin":hero.cell, "target_cell":hero.cell, "facing":"n", "elapsed":10.0, "remaining":10.0, "is_channeling":false, "cast_seconds":0.0, "release_seconds":0.0, "cast_id":2, "released":true, "duration_seconds":20.0})
	_check(presentation.active_effect_count() == 1 and presentation._last_ability == "fortune", "Fortune handoff restores aura and hit identity, not initial burst")
	stage.hero_view.global_position += Vector3(16.5,0,0)
	presentation._process(0.0)
	_check(presentation._pool[0].sprite.global_position.is_equal_approx(stage.hero_view.global_position + Vector3(0,0.02,0)), "Fortune follows caster between arenas")
	var hit_center := Vector2(32.5, 24.5)
	presentation.show_hit("guild_house", hit_center, 3)
	_check(presentation.active_effect_count() == 3, "Actual post-handoff hit creates burst and number")
	var hit_world: Vector3 = ArenicGridMath.arena_origin(world.arenas[1].grid_slot) + Vector3(hit_center.x * ArenicGridMath.TILE_SIZE, 0.05, -hit_center.y * ArenicGridMath.TILE_SIZE)
	_check(presentation._pool[1].sprite.global_position.is_equal_approx(hit_world), "Even-footprint hit feedback preserves the half-tile geometric center")
	for index: int in 40:
		presentation.show_hit("guild_house", hero.cell, 3)
	_check(presentation.active_effect_count() <= 16 and presentation._pool.size() == 16, "Repeated hits keep a fixed sixteen-slot pool")
	presentation.sync_active(false, 0.0)
	_check(not presentation._pool[0].active, "Authoritative Fortune end removes aura")
	presentation.restore_active({"ability_id":"heal", "arena_id":"guild_house", "origin":Vector2i(30,15), "target_cell":Vector2i(35,15), "facing":"e", "elapsed":30.0, "remaining":INF, "is_channeling":true, "cast_seconds":0.0, "release_seconds":0.0, "cast_id":3, "released":true, "duration_seconds":0.0})
	_check(presentation.active_effect_count() == 3, "Held aura plus two native beam segments survive elapsed time")
	presentation.sync_active(false, 0.0)
	_check(presentation.active_effect_count() == 0, "Channel cancellation clears every beam segment")
	presentation.clear()
	presentation.free()
	stage.hero_view.free()
	stage.free()
	print("Combat presentation checks: %d assertions, %d failures; %d native sheets." % [_checks, _failures, sheets])
	quit(0 if _failures == 0 else 1)

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)
