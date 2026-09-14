extends SceneTree
## Native asset/layout contracts; renderer projection is covered by theme checks.

var _checks: int = 0
var _failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var definition := load("res://data/world/guild_clearing.tres") as ArenicGuildClearingDefinition
	_check(definition != null and definition.validation_errors().is_empty(), "The authored clearing passes its typed data contract.")
	if definition == null:
		return _finish()
	_check_definition(definition)
	var first := ArenicGuildClearingView.new()
	var second := ArenicGuildClearingView.new()
	root.add_child(first)
	root.add_child(second)
	_check_trees(first, second, definition)
	_check_paths(first)
	_check_sites()
	_check_tavern_keeper()
	first.set_overview_mix(1.0)
	_check(is_equal_approx(first.trees[0].modulate.a, 0.72) and is_zero_approx(first.paths[0].modulate.a), "Overview reduces tree opacity and removes the small dirt stamps.")
	_check(is_equal_approx(second.trees[0].modulate.a, 1.0) and is_equal_approx(second.paths[0].modulate.a, 0.72), "Independent clearing instances do not share mutable appearance.")
	first.set_overview_mix(0.0)
	_check(is_equal_approx(first.trees[0].modulate.a, 1.0) and is_equal_approx(first.paths[0].modulate.a, 0.72), "Returning to close view restores authored tree and path visibility.")
	first.free()
	second.free()
	_finish()


func _check_definition(definition: ArenicGuildClearingDefinition) -> void:
	_check(definition.trees.size() == 53, "The clearing has 53 authored stable tree placements.")
	var combinations: Dictionary = {}
	var positions: Dictionary = {}
	for tree: ArenicClearingTree in definition.trees:
		combinations[Vector2i(tree.variant, tree.facing)] = true
		positions[tree.cell] = true
	_check(combinations.size() == 20 and positions.size() == 53, "Five tree shapes use all four authored facings without duplicated placement centers.")
	_check(definition.paths.size() == 7, "Seven authored footpaths link the clearing routes, sources and dropoffs.")
	_check(definition.paths[0][0] == Vector2(1, 15) and definition.paths[0][-1] == Vector2(64, 15), "The main path joins both horizontal arena entrances.")
	_check(definition.paths[1][-1] == Vector2(33, 1), "The vertical branch reaches the lower arena entrance.")
	var path_points: Dictionary = {}
	for path: PackedVector2Array in definition.paths:
		for point: Vector2 in path:
			path_points[point] = true
	_check(path_points.has(Vector2(7, 24)) and path_points.has(Vector2(56, 7)), "Both diagonal mine locations are connected to authored paths.")
	var rules := load("res://data/guild/gathering.tres") as ArenicGatheringDefinition
	_check(definition.paths[6][0] == Vector2(rules.wood_dropoff) and definition.paths[6][-1] == Vector2(rules.gold_dropoff), "The porch path connects both relocated tavern-side dropoffs.")
	for field: String in ["variant", "facing", "cell"]:
		var bad := definition.duplicate(true) as ArenicGuildClearingDefinition
		bad.trees[0].set(field, Vector2(NAN, 0) if field == "cell" else (5 if field == "variant" else 4))
		_check(not bad.validation_errors().is_empty(), "Invalid tree %s fails data validation." % field)
	var oversized := definition.duplicate(true) as ArenicGuildClearingDefinition
	while oversized.trees.size() <= 96:
		oversized.trees.append(oversized.trees[0])
	_check(not oversized.validation_errors().is_empty(), "The scenery collection stays bounded at 96 authored trees.")
	var bad_path := definition.duplicate(true) as ArenicGuildClearingDefinition
	bad_path.paths[0] = PackedVector2Array([Vector2.ZERO])
	_check(not bad_path.validation_errors().is_empty(), "A footpath with fewer than two points is rejected.")


func _check_trees(first: ArenicGuildClearingView, second: ArenicGuildClearingView, definition: ArenicGuildClearingDefinition) -> void:
	_check(first.trees.size() == 53 and second.trees.size() == 53, "Each runtime clearing mounts exactly the authored tree count.")
	var sampled: Dictionary = {}
	for index: int in first.trees.size():
		var tree: Sprite3D = first.trees[index]
		var placement: ArenicClearingTree = definition.trees[index]
		var expected_cell: Vector2 = (placement.cell * 19.0).round() / 19.0
		var expected: Vector3 = ArenicArenaTiles.tile_point(expected_cell) + Vector3(0, 0.007, 0)
		_check(tree.name == "Tree%02d" % index and tree.position.is_equal_approx(expected) and tree.position == second.trees[index].position, "Tree%02d preserves authored placement, snapped to native pixels, across independent builds." % index)
		_check(_native_sprite(tree) and tree.offset == Vector2(0.5, 0.5), "Tree%02d keeps nearest native scale and the even-frame pixel-center offset." % index)
		var atlas := tree.texture as AtlasTexture
		var region := Rect2(placement.facing * 76, placement.variant * 76, 76, 76)
		_check(atlas != null and atlas.region == region and atlas.filter_clip and atlas.atlas.get_size() == Vector2(304, 380), "Tree%02d selects one bounded 76px frame from its actual variant/facing." % index)
		if atlas != null and not sampled.has(region):
			var image: Image = atlas.atlas.get_image()
			_check(image != null and not image.has_mipmaps() and image.get_region(Rect2i(region)).get_used_rect().has_area(), "Every tree variant/facing contains native opaque artwork without mipmap sampling.")
			sampled[region] = true
	_check(sampled.size() == 20, "All 20 exported tree frames are exercised by actual placements.")
	_check(first.find_children("*", "CollisionObject3D", true, false).is_empty(), "Scenery creates no alternate gameplay collision bodies.")


func _check_paths(clearing: ArenicGuildClearingView) -> void:
	_check(not clearing.paths.is_empty() and clearing.paths.size() <= 256, "The authored footpaths produce a bounded number of ground stamps.")
	var sampled: Dictionary = {}
	for patch: Sprite3D in clearing.paths:
		var atlas := patch.texture as AtlasTexture
		_check(_native_sprite(patch) and atlas != null and atlas.region.size == Vector2(76, 76) and atlas.region.position.y == 0 and atlas.region.position.x in [0.0, 76.0, 152.0] and atlas.atlas.get_size() == Vector2(228, 76) and atlas.filter_clip, "Every path stamp samples one complete transparent native patch within the atlas.")
		var pixel_point: Vector2 = Vector2(patch.position.x, -patch.position.z) / patch.pixel_size + Vector2(32.5, 15.0) * 19.0
		_check(pixel_point.distance_to(pixel_point.round()) < 0.001 and is_equal_approx(patch.position.y, 0.001), "Path centers snap to the native raster beneath scenery and heroes.")
		if atlas != null and not sampled.has(atlas.region):
			var image: Image = atlas.atlas.get_image().get_region(Rect2i(atlas.region))
			_check(image.get_used_rect().has_area() and image.get_used_rect().size.x < 76 and image.get_used_rect().size.y < 76, "Ground stamps retain transparent unclipped borders for blending.")
			sampled[atlas.region] = true
	_check(sampled.size() == 3, "Authored paths exercise all three dirt patch variants.")


func _check_sites() -> void:
	var rules := load("res://data/guild/gathering.tres") as ArenicGatheringDefinition
	_check(rules.gold_sources == [Vector2i(7, 24), Vector2i(56, 7)], "Mines occupy the upper-left and lower-right clearing corners.")
	_check(rules.wood_sources == [Vector2i(12, 9), Vector2i(12, 23)] and rules.wood_dropoff == Vector2i(23, 21) and rules.gold_dropoff == Vector2i(42, 21), "Wood sites stay in place while dropoffs flank the tavern, wood left and gold right.")
	var view := ArenicGatheringSiteView.new()
	root.add_child(view)
	view.configure(rules)
	_check(view.find_children("*", "Label3D", true, false).is_empty(), "Gathering sites have no world labels or bank readouts.")
	for entry: Array in [["WoodDropoff", rules.wood_dropoff], ["GoldDropoff", rules.gold_dropoff]]:
		var dropoff := view.get_node(entry[0]) as Node3D
		_check(dropoff.position.is_equal_approx(ArenicArenaTiles.tile_point(Vector2(entry[1]))) and _native_sprite(dropoff.get_node("Prop")), "Dropoff artwork and interaction geometry share the authored location.")
	for index: int in 2:
		var site := view.get_node("GoldSource%d" % index) as Node3D
		var prop := site.get_node("Prop") as Sprite3D
		var atlas := prop.texture as AtlasTexture
		_check(site.position.is_equal_approx(ArenicArenaTiles.tile_point(Vector2(rules.gold_sources[index]))) and _native_sprite(prop), "A mine view follows the authored gathering location at native scale.")
		_check(atlas.region == Rect2(ArenicGuildClearingView.DEFINITION.mine_facings[index] * 95, 0, 95, 95) and atlas.atlas.get_size() == Vector2(380, 95), "Each mine uses its authored cardinal frame from the 95px atlas.")
	view.free()


func _check_tavern_keeper() -> void:
	var arena := load("res://data/world/guild_house.tres") as ArenicArenaDefinition
	var keeper := load("res://data/npcs/keeper.tres") as ArenicNpcDefinition
	var frames: SpriteFrames = arena.training_target_frames
	var texture: Texture2D = frames.get_frame_texture("idle_s", 0)
	_check(texture.get_size() == Vector2(247, 171), "The central tavern retains its untrimmed 247×171 native canvas.")
	for facing: String in ["n", "e", "s", "w"]:
		_check(frames.has_animation("idle_" + facing) and frames.get_frame_count("idle_" + facing) == 1 and frames.get_frame_texture("idle_" + facing, 0) == texture, "The static tavern supports target-facing presentation without changing its art.")
	var combat_center: Vector2 = Vector2(arena.boss_origin_cell) + Vector2(arena.boss_combat_size - Vector2i.ONE) * 0.5
	var visual_center: Vector2 = combat_center + arena.boss_visual_offset
	_check(arena.boss_origin_cell == Vector2i(30, 22) and arena.boss_combat_size == Vector2i(6, 6) and visual_center == Vector2(32.5, 22), "Tavern art is centered independently of the unchanged six-cell target footprint.")
	_check(keeper.arena_id == "guild_house" and keeper.cell == Vector2i(33, 18) and absf(keeper.cell.x - visual_center.x) <= 0.5 and keeper.cell.y < visual_center.y, "The seated Keeper waits outside, centered in front of the tavern.")
	var used: Rect2i = texture.get_image().get_used_rect()
	var bottom_row: float = visual_center.y - (float(used.end.y - 1) - 85.0) / 19.0
	_check(float(keeper.cell.y) < bottom_row, "The Keeper's standing cell is beyond the tavern's lower opaque porch edge.")
	for animation: String in ["idle_s", "beckon_s"]:
		_check(keeper.sprite_frames.has_animation(animation) and keeper.sprite_frames.get_frame_texture(animation, 0).get_size() == Vector2(38, 38), "The seated Keeper preserves the prologue's native idle/beckon animation contract.")
	_check(keeper.sprite_frames.get_animation_loop("idle_s") and not keeper.sprite_frames.get_animation_loop("beckon_s"), "The Keeper idles continuously but finishes beckoning so the introduction can return to idle.")


func _native_sprite(sprite: Sprite3D) -> bool:
	return sprite != null and sprite.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST and is_equal_approx(sprite.pixel_size * 19.0, ArenicGridMath.TILE_SIZE) and not sprite.shaded and sprite.basis.z.is_equal_approx(Vector3.UP)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failed = true
		push_error("Guild clearing: " + message)


func _finish() -> void:
	print("Guild clearing checks: %d assertions %s." % [_checks, "FAILED" if _failed else "passed"])
	quit(1 if _failed else 0)
