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
	var arrow: Variant = presentation._cast_effects[0]
	var start: Vector3 = ArenicGridMath.tile_to_world(world.arenas[1].grid_slot, Vector2i(30,15)) + Vector3(0,0.05,0)
	var finish: Vector3 = start + Vector3(2,0,0)
	_check(arrow.sprite.global_position.is_equal_approx(start.lerp(finish, (0.5 - 0.26) / (0.75 - 0.26))), "Arrow resumes elapsed flight rather than replaying origin")
	var slower := (load("res://data/classes/hunter_primary.tres") as ArenicClassAbility).duplicate() as ArenicClassAbility
	slower.projectile_speed_tiles_per_second = 8.0
	presentation.clear()
	presentation.show_cast(0, "auto_shot", "guild_house", Vector2i(30,15), Vector2i(38,15), "e", slower)
	_check(is_equal_approx(presentation._cast_effects[0].duration, 1.0) and is_equal_approx(presentation._cast_effects[0].delay, 0.26), "Data-tuned speed controls flight separately from windup")
	shot.elapsed = 0.8
	presentation.restore_active(shot)
	_check(presentation.active_effect_count() == 0, "Landed projectile is not resurrected")
	presentation.clear()
	presentation.show_cast(0, "cleanse", "guild_house", Vector2i(10,10), Vector2i(10,10), "n", load("res://data/classes/bard_primary.tres"))
	var expected: Vector3 = ArenicGridMath.tile_to_world(world.arenas[1].grid_slot, Vector2i(10,10)) + Vector3(0.125,0.05,-0.125)
	_check(presentation._cast_effects[0].sprite.global_position.is_equal_approx(expected), "Even four-tile wave centers over occupied cells")
	presentation.clear()
	presentation.show_cast(0, "cleanse", "guild_house", Vector2i.ZERO, Vector2i.ZERO, "n", load("res://data/classes/bard_primary.tres"))
	expected = ArenicGridMath.arena_origin(world.arenas[1].grid_slot) + Vector3(0.375,0.05,-0.375)
	_check(presentation._cast_effects[0].sprite.global_position.is_equal_approx(expected), "Wave follows model edge clamp")
	presentation.restore_active({"ability_id":"fortune", "arena_id":"guild_house", "origin":hero.cell, "target_cell":hero.cell, "facing":"n", "elapsed":10.0, "remaining":10.0, "is_channeling":false, "cast_seconds":0.0, "release_seconds":0.0, "cast_id":2, "released":true, "duration_seconds":20.0})
	_check(presentation.active_effect_count() == 1 and presentation._cast_effects[0].ability == "fortune", "Fortune handoff restores aura and hit identity, not initial burst")
	stage.hero_view.global_position += Vector3(16.5,0,0)
	presentation._process(0.0)
	_check(presentation._cast_effects[0].sprite.global_position.is_equal_approx(stage.hero_view.global_position + Vector3(0,0.02,0)), "Fortune follows caster between arenas")
	var hit_center := Vector2(32.5, 24.5)
	presentation.show_hit(0, "fortune", "guild_house", hit_center, 3)
	_check(presentation.active_effect_count() == 3, "Actual post-handoff hit creates burst and number")
	var hit_world: Vector3 = ArenicGridMath.arena_origin(world.arenas[1].grid_slot) + Vector3(hit_center.x * ArenicGridMath.TILE_SIZE, 0.05, -hit_center.y * ArenicGridMath.TILE_SIZE)
	_check(presentation._pool[0].sprite.global_position.is_equal_approx(hit_world), "Even-footprint hit feedback preserves the half-tile geometric center")
	for index: int in 40:
		presentation.show_hit(0, "fortune", "guild_house", hero.cell, 3)
	_check(presentation.active_effect_count() <= 17 and presentation._pool.size() == 16, "Repeated hits keep a fixed sixteen-slot pool")
	presentation._cast_snapshot_lookup = func(_caster: ArenicHeroState) -> Dictionary: return {}
	presentation.sync_active()
	presentation._cast_snapshot_lookup = Callable()
	_check(not presentation._cast_effects.has(0), "Authoritative Fortune end removes aura")
	presentation.restore_active({"ability_id":"heal", "arena_id":"guild_house", "origin":Vector2i(30,15), "target_cell":Vector2i(35,15), "facing":"e", "elapsed":30.0, "remaining":INF, "is_channeling":true, "cast_seconds":0.0, "release_seconds":0.0, "cast_id":3, "released":true, "duration_seconds":0.0})
	_check(presentation.active_effect_count() == 3, "Held aura plus two native beam segments survive elapsed time")
	presentation.cancel_channel(0)
	_check(presentation.active_effect_count() == 0, "Channel cancellation clears every beam segment")
	_check_tracking_channel(stage, presentation)
	_check_concurrent_channels(stage, presentation)
	_check_all_ability_pairs(stage, presentation)
	_check_reserved_cast_capacity(stage, presentation)
	presentation.clear()
	presentation.free()
	stage.hero_view.free()
	stage.free()
	print("Combat presentation checks: %d assertions, %d failures; %d native sheets." % [_checks, _failures, sheets])
	quit(0 if _failures == 0 else 1)

func _check_tracking_channel(stage: ArenicOverworldStage, presentation: ArenicCombatPresentation) -> void:
	var combat := ArenicCombatState.new()
	combat.configure(stage.world)
	var boss_id: String = ArenicCombatState.boss_enemy_id("labyrinth")
	combat.register_enemy("labyrinth", boss_id, Rect2i(30, 12, 6, 6))
	var encounter := ArenicEncounterState.new()
	encounter.configure(stage.world, load("res://data/encounters/catalog.tres"), combat)
	var cardinal := ArenicHeroState.new()
	cardinal.identity_id = 1
	cardinal.definition = load("res://data/classes/cardinal.tres")
	cardinal.arena_id = "labyrinth"
	cardinal.cell = Vector2i(22, 17)
	var caster := ArenicHeroView.new()
	root.add_child(caster)
	caster.configure(cardinal)
	caster.sync(stage.world.arenas[0], false)
	stage.hero_views[1] = caster
	presentation.configure(stage, combat.enemy_presentation_pose, combat.is_channeling)
	_check(combat.try_cast(cardinal).is_empty(), "A real Cardinal starts at the outer edge of the boss footprint's authored range")
	var snapshot: Dictionary = combat.active_cast_snapshot(cardinal)
	presentation.show_cast(1, "heal", "labyrinth", cardinal.cell, snapshot.target_cell, cardinal.facing, cardinal.definition.skills[0], snapshot.target_id)
	_check(presentation._channels[1].visible and presentation._channels[1].caster_identity == 1, "A legal six-cell footprint stays connected even when its center is more than eight tiles away")
	var first_segment: Variant = presentation._channels[1].segments[0]
	_check(presentation._channels[1].segments.size() == 3, "The initial target requires three native beam strips")
	var initial_position: Vector3 = presentation._channels[1].target
	var before_damage: int = combat.total_damage()
	for tick: int in [408, 426, 444, 462, 480]:
		encounter.seek("labyrinth", tick)
		presentation._process(0.125)
		var pose: Dictionary = encounter.boss_placement("labyrinth")
		var expected: Vector3 = ArenicGridMath.arena_origin(stage.world.arenas[0].grid_slot) + Vector3(pose.center.x, pose.lift, -pose.center.y) * ArenicGridMath.TILE_SIZE + Vector3(0, 0.05, 0)
		_check(presentation._channels[1].visible and presentation._channels[1].target.is_equal_approx(expected), "The beam tracks the authored takeoff, arc and new landing at tick%d" % tick)
		_check(presentation._channels[1].segments[0] == first_segment, "Tracking repositions existing native strips without restarting the channel")
		var first: Variant = presentation._channels[1].segments[0]
		var delta: Vector3 = presentation._channels[1].target - presentation._channels[1].origin
		var planar_length: float = Vector2(delta.x, delta.z).length()
		_check((first.sprite.global_position + first.sprite.basis.x * planar_length).is_equal_approx(expected), "Native strip direction reaches the model endpoint including jump height")
	_check(not presentation._channels[1].target.is_equal_approx(initial_position) and combat.total_damage() == before_damage and combat.active_cast_snapshot(cardinal) == snapshot, "Reading moving endpoints changes neither cast state nor damage")
	presentation.sync_active()
	presentation._process(0.0)
	_check(presentation._channels[1].visible and presentation._channels.has(1), "Selecting a non-channeling hero does not cancel another caster's beam")
	var aura: Variant = presentation._channels[1].effects[0]
	_check(aura.sprite.global_position.is_equal_approx(caster.global_position + Vector3(0, 0.02, 0)), "The channel aura follows its actual caster rather than the selected hero")
	_check(presentation._channels[1].segments.size() == 4 and is_equal_approx(presentation._channels[1].segments[3].age, aura.age), "A newly needed fourth strip joins the existing channel animation time")
	encounter.seek("labyrinth", 1320)
	presentation._process(0.0)
	_check(not presentation._channels[1].visible and aura.sprite.visible and combat.is_channeling(cardinal), "An out-of-range target hides the tether while preserving the actual held channel and caster aura")
	var hidden: bool = true
	for segment: Variant in presentation._channels[1].segments:
		hidden = hidden and not segment.sprite.visible
	_check(hidden, "No stale beam segment remains visible when its target leaves range")
	encounter.seek("labyrinth", 444)
	presentation.restore_active(combat.active_cast_snapshot(cardinal))
	_check(presentation._channels[1].visible and presentation._channels[1].target.y > presentation._channels[1].origin.y, "Restoring a held channel derives the current jump endpoint without replaying its old target cell")
	_check(combat.total_damage() == before_damage and combat.active_cast_snapshot(cardinal) == snapshot, "Presenter restoration never replays a hit or advances the held channel")
	_check(presentation.active_effect_count() <= 5 and presentation._beam_frames.size() <= 73, "Moving beams keep four native strips and a bounded clipped-frame cache")
	combat.cancel_active(cardinal)
	presentation._process(0.0)
	_check(not presentation._channels.has(1) and presentation.active_effect_count() == 0, "The caster's active-cast cancellation removes its aura and every beam strip")
	presentation.clear()
	stage.hero_views.erase(1)
	caster.free()


func _check_concurrent_channels(stage: ArenicOverworldStage, presentation: ArenicCombatPresentation) -> void:
	var combat := ArenicCombatState.new()
	combat.configure(stage.world)
	for arena: ArenicArenaDefinition in stage.world.arenas:
		combat.register_enemy(arena.arena_id, ArenicCombatState.boss_enemy_id(arena.arena_id), Rect2i(30, 20, 6, 6))
	presentation.configure(stage, combat.enemy_presentation_pose, combat.is_channeling)
	var original: ArenicHeroView = stage.hero_views[0]
	var members: Array[ArenicHeroState] = []
	var first_segment: ArenicCombatPresentation.Effect
	# Exercise the entire saved roster bound; forty channels per arena. Contact
	# is outside this presenter fixture: these casts test capacity, not movement.
	for identity: int in ArenicSaveCodec.MAX_HEROES:
		var member := ArenicHeroState.new()
		member.identity_id = identity
		member.definition = load("res://data/classes/cardinal.tres")
		member.arena_id = stage.world.arenas[identity / 40].arena_id
		member.cell = Vector2i(22, 17)
		var view := ArenicHeroView.new()
		root.add_child(view)
		view.configure(member)
		view.sync(stage.world.arenas[identity / 40], false)
		stage.hero_views[identity] = view
		members.append(member)
		_check(combat.try_cast(member).is_empty(), "Each Cardinal owns a legal independent cast")
		var cast: Dictionary = combat.active_cast_snapshot(member)
		presentation.show_cast(identity, "heal", member.arena_id, member.cell, cast.target_cell, member.facing, member.definition.skills[0], cast.target_id)
		if identity == 0:
			first_segment = presentation._channels[0].segments[0]
			presentation._process(0.125)
		elif identity == 1:
			_check(presentation._channels.size() == 2 and presentation._channels[0].segments[0] == first_segment and is_equal_approx(first_segment.age, 0.125), "The second Sacrifice preserves the first caster's beam nodes and animation age")
	_check(presentation._channels.size() == 320, "Every supported caster has reserved channel capacity outside the sixteen-slot hit pool")
	var tracks: Dictionary = {}
	var complete: bool = true
	for channel: ArenicCombatPresentation.Channel in presentation._channels.values():
		complete = complete and channel.visible and channel.segments.size() == 4
		for effect: ArenicCombatPresentation.Effect in channel.effects:
			complete = complete and effect.active and effect.sprite.visible and not tracks.has(effect.track_id)
			tracks[effect.track_id] = true
	_check(complete and tracks.size() == 1600, "All 320 auras and four-strip beams stay visible with distinct rewind tracks")
	# Capture the highest legal caster through real rewind indexing, masks and
	# clones; a valid presenter slot must not fall outside the history table.
	for definition: ArenicArenaDefinition in stage.world.arenas:
		var arena := ArenicArenaView.new() # Data-only registry; no scenery startup.
		arena.definition = definition
		stage._arenas.append(arena)
	var rewind := ArenicArenaRewind.new()
	root.add_child(rewind)
	rewind.configure(stage, presentation)
	var final_arena: String = members.back().arena_id
	rewind.capture(final_arena, 0)
	rewind.capture(final_arena, 3)
	rewind.begin(final_arena, 3)
	var final_effect: ArenicCombatPresentation.Effect = presentation._channels[319].segments.back()
	var final_track: int = 329 + final_effect.track_id
	_check(rewind._playing[final_arena].clones.has(final_track) and rewind._playing[final_arena].clones[final_track][0].visible, "The highest supported Cardinal beam is captured and drawn through rewind")
	_check(final_effect.sprite.layers == 0 and first_segment.sprite.layers != 0, "Rewind masks only the channel effects in its own arena")
	rewind.configure(null, null)
	_check(final_effect.sprite.layers != 0 and final_effect.sprite.visible, "Retiring rewind restores the still-active channel's own render layers")
	rewind.free()
	for arena: ArenicArenaView in stage._arenas:
		arena.free()
	stage._arenas.clear()
	for hit: int in 100:
		presentation.show_hit(0, "heal", members[0].arena_id, Vector2(32, 22), 1)
	presentation._process(0.125)
	_check(presentation._channels[0].segments[0] == first_segment and first_segment.sprite.visible and presentation.active_effect_count() == 1616, "Hit-pool pressure cannot evict any persistent channel")
	var paused_arena: String = members[0].arena_id
	presentation.arena_paused_lookup = func(arena_id: String) -> bool: return arena_id == paused_arena
	var paused_age: float = first_segment.age
	var other: ArenicCombatPresentation.Effect = presentation._channels[40].segments[0]
	var other_age: float = other.age
	presentation._process(0.25)
	_check(first_segment.age == paused_age and is_equal_approx(other.age, other_age + 0.25), "Pausing one arena freezes only its own beams")
	presentation.arena_paused_lookup = Callable()
	combat.cancel_channel(members[1])
	presentation._process(0.0)
	_check(not presentation._channels.has(1) and presentation._channels.size() == 319 and first_segment.sprite.visible, "One caster stopping removes only that caster's channel")
	presentation.clear_arena(paused_arena, func(identity: int) -> bool: return identity == 0)
	_check(not presentation._channels.has(0) and presentation._channels.has(2) and presentation._channels.has(40), "Filtered arena cleanup preserves every other caster and arena")
	presentation.clear()
	for member: ArenicHeroState in members:
		presentation.restore_active(combat.active_cast_snapshot(member))
	_check(presentation._channels.size() == 319 and combat.total_damage() == 0, "Restoration reconstructs every still-active caster without replaying damage")
	presentation.clear()
	for member: ArenicHeroState in members:
		stage.hero_views[member.identity_id].free()
		stage.hero_views.erase(member.identity_id)
	stage.hero_views[0] = original


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(message)


func _check_all_ability_pairs(stage: ArenicOverworldStage, presentation: ArenicCombatPresentation) -> void:
	var names: Array[String] = ["hunter", "warrior", "thief", "alchemist", "cardinal", "bard", "forager", "merchant"]
	var covered: Dictionary = {}
	for first_name: String in names:
		for second_name: String in names:
			presentation.configure(stage)
			var members: Array[ArenicHeroState] = []
			for index: int in 2:
				var member := ArenicHeroState.new()
				member.identity_id = 10 + index
				member.definition = load("res://data/classes/%s.tres" % (first_name if index == 0 else second_name))
				member.arena_id = "guild_house"
				member.cell = Vector2i(30, 15 + index)
				var view := ArenicHeroView.new()
				root.add_child(view)
				view.configure(member)
				view.sync(stage.world.arenas[1], false)
				stage.hero_views[member.identity_id] = view
				members.append(member)
			var first: ArenicHeroState = members[0]
			var second: ArenicHeroState = members[1]
			var rules: ArenicClassAbility = first.definition.skills[0]
			covered[rules.ability_id] = true
			presentation.show_cast(first.identity_id, rules.ability_id, first.arena_id, first.cell, Vector2i(35, 15), "e", rules)
			presentation.show_hit(first.identity_id, rules.ability_id, first.arena_id, Vector2(35, 15), 1, "e")
			presentation._process(0.1)
			var original: Array[ArenicCombatPresentation.Effect] = presentation.effects_in_arena(first.arena_id)
			var second_rules: ArenicClassAbility = second.definition.skills[0]
			presentation.show_cast(second.identity_id, second_rules.ability_id, second.arena_id, second.cell, Vector2i(35, 15), "w", second_rules)
			for hit: int in 40:
				presentation.show_hit(second.identity_id, second_rules.ability_id, second.arena_id, Vector2(35, 15), 1, "w")
			var intact: bool = true
			for effect: ArenicCombatPresentation.Effect in original:
				intact = intact and is_instance_valid(effect.sprite) and effect.active and is_equal_approx(effect.age, 0.1) and effect.caster_identity == first.identity_id and effect.ability == rules.ability_id
			_check(intact, "%s then %s preserves the first caster's effects under pool pressure" % [first_name, second_name])
			presentation.show_hit(first.identity_id, rules.ability_id, first.arena_id, Vector2(35, 15), 1, "e")
			var provenance: bool = true
			for effect: ArenicCombatPresentation.Effect in presentation.effects_in_arena(first.arena_id):
				if effect.caster_identity == first.identity_id:
					provenance = provenance and effect.ability == rules.ability_id
			_check(provenance, "Delayed %s hits retain their source after %s casts" % [first_name, second_name])
			presentation.clear_arena(first.arena_id, func(identity: int) -> bool: return identity == first.identity_id)
			var second_alive: bool = false
			for effect: ArenicCombatPresentation.Effect in presentation.effects_in_arena(second.arena_id):
				second_alive = second_alive or effect.caster_identity == second.identity_id
			# Bash/Backstab still have their owned native impact after cleanup;
			# Cleanse/Dig have their cast wave/excavation even with numbers retired.
			_check(second_alive, "Cleaning %s preserves %s's independent animation" % [first_name, second_name])
			presentation.clear()
			for member: ArenicHeroState in members:
				stage.hero_views[member.identity_id].free()
				stage.hero_views.erase(member.identity_id)
	_check(covered.size() == presentation._catalog.size(), "The pair matrix must cover every implemented ability; additions require ownership coverage")


func _check_reserved_cast_capacity(stage: ArenicOverworldStage, presentation: ArenicCombatPresentation) -> void:
	var combat := ArenicCombatState.new()
	combat.configure(stage.world)
	for arena: ArenicArenaDefinition in stage.world.arenas:
		combat.register_enemy(arena.arena_id, ArenicCombatState.boss_enemy_id(arena.arena_id), Rect2i(30, 20, 6, 6))
	presentation.configure(stage, combat.enemy_presentation_pose, combat.is_channeling, combat.active_cast_snapshot)
	var original: ArenicHeroView = stage.hero_views[0]
	var members: Array[ArenicHeroState] = []
	for identity: int in ArenicSaveCodec.MAX_HEROES:
		var member := ArenicHeroState.new()
		member.identity_id = identity
		member.definition = load("res://data/classes/%s.tres" % ["hunter", "alchemist", "merchant"][identity % 3])
		member.arena_id = stage.world.arenas[identity / 40].arena_id
		member.cell = Vector2i(22, 17)
		var view := ArenicHeroView.new()
		root.add_child(view)
		view.configure(member)
		view.sync(stage.world.arenas[identity / 40], false)
		stage.hero_views[identity] = view
		members.append(member)
		_check(combat.try_cast(member).is_empty(), "The model admits each independent projectile or Fortune")
		var cast: Dictionary = combat.active_cast_snapshot(member)
		presentation.show_cast(identity, cast.ability_id, cast.arena_id, cast.origin, cast.target_cell, cast.facing, member.definition.skills[0], cast.target_id, cast.cast_id)
	combat.tick(0.1)
	presentation._process(0.1)
	var first: ArenicCombatPresentation.Effect = presentation._cast_effects[0]
	var merchant: ArenicCombatPresentation.Effect = presentation._cast_effects[2]
	for hit: int in 50:
		presentation.show_hit(0, "auto_shot", members[0].arena_id, Vector2(30,20), 1)
	_check(presentation._cast_effects.size() == 320 and first.active and merchant.active, "All 320 projectiles/auras remain reserved under hit pressure")
	var paused: String = members[0].arena_id
	presentation.arena_paused_lookup = func(arena: String) -> bool: return arena == paused
	var remote: ArenicCombatPresentation.Effect = presentation._cast_effects[41]
	var remote_age: float = remote.age
	presentation._process(0.1)
	_check(is_equal_approx(merchant.age, 0.1) and is_equal_approx(remote.age, remote_age + 0.1), "Fortune and projectile visual time follow their owning arena")
	presentation.arena_paused_lookup = Callable()
	# Change which actor is selected without changing any caster's model state.
	stage.selected_identity = 0
	presentation.sync_active()
	_check(presentation._cast_effects.has(2) and presentation._cast_effects.has(5), "Selecting a non-Merchant cannot retire either Fortune aura")
	combat.cancel_active(members[2])
	presentation.sync_active()
	_check(not presentation._cast_effects.has(2) and presentation._cast_effects.has(5), "Only the cancelled Merchant loses its Fortune")
	presentation.clear()
	for member: ArenicHeroState in members:
		presentation.restore_active(combat.active_cast_snapshot(member))
	_check(presentation._cast_effects.size() == 319 and combat.total_damage() == 0, "Reload reconstructs every independent in-flight cast without replaying damage")
	presentation.show_hit(-1, "", paused, Vector2(30,20), 1)
	var unknown: bool = false
	for effect: ArenicCombatPresentation.Effect in presentation._pool:
		if effect.active and effect.caster_identity == -1:
			unknown = unknown or (effect.number and effect.ability.is_empty())
	_check(unknown, "Unowned legacy damage never borrows the selected hero's ability")
	presentation.clear()
	for member: ArenicHeroState in members:
		stage.hero_views[member.identity_id].free()
		stage.hero_views.erase(member.identity_id)
	stage.hero_views[0] = original
