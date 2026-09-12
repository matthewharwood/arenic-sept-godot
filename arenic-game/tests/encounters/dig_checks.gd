extends SceneTree
## Broken ground: what it yields, what it costs a boss, and when it clears.
## Godot --headless --path arenic-game --script res://tests/encounters/dig_checks.gd

const SHELL_PATH: String = "res://scenes/game/game_shell.tscn"
const RETIRE_AUDIO: GDScript = preload("res://tests/support/audio_retirement.gd")
const GUILD: String = "guild_house"
const LABYRINTH: String = "labyrinth"

var checks: int = 0
var failed: bool = false
var shell: Variant
var setup: Node


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("Dig: " + message)


func _run() -> void:
	create_timer(40.0).timeout.connect(func():
		push_error("Dig checks timed out")
		quit(1))
	_check_field()
	setup = root.get_node("RunSetup")
	setup.begin_new_game()
	setup.choose_class(load("res://data/classes/forager.tres"))
	shell = load(SHELL_PATH).instantiate()
	root.add_child(shell)
	await process_frame
	shell.select_hero()
	await physics_frame
	await _check_casts_anywhere()
	await _check_yield_feeds_recruitment()
	await _check_one_dig_per_tile()
	await _check_hazard()
	await _check_clears_on_cycle()
	await _check_flask()
	_check_ground_sorts_under_sprites()
	await _check_acid_burns_heroes()
	await _finish()


## The field itself: values in range, seeded, and spent once.
func _check_field() -> void:
	var field := ArenicDigField.new()
	field.configure(LABYRINTH)
	var low: bool = false
	var high: bool = false
	for index: int in ArenicDigField.CELLS:
		var value: int = field.value_at(ArenicDigField.cell_of(index))
		if value < ArenicDigField.MIN_VALUE or value > ArenicDigField.MAX_VALUE:
			check(false, "Every tile is worth 1 to 3; found %d" % value)
			return
		low = low or value == ArenicDigField.MIN_VALUE
		high = high or value == ArenicDigField.MAX_VALUE
	check(low and high, "The roll spans the whole range rather than settling on one value")
	# Seeded, so a recorded Forager digs the same tile for the same value.
	var twin := ArenicDigField.new()
	twin.configure(LABYRINTH)
	var same: bool = true
	for index: int in 200:
		same = same and field.value_at(ArenicDigField.cell_of(index)) == twin.value_at(ArenicDigField.cell_of(index))
	check(same, "The same arena and cycle roll the same ground every time")
	var other := ArenicDigField.new()
	other.configure(GUILD)
	var differs: bool = false
	for index: int in 200:
		differs = differs or field.value_at(ArenicDigField.cell_of(index)) != other.value_at(ArenicDigField.cell_of(index))
	check(differs, "A different arena rolls different ground")
	field.regenerate(1, 0)
	var moved: bool = false
	for index: int in 200:
		moved = moved or field.value_at(ArenicDigField.cell_of(index)) != twin.value_at(ArenicDigField.cell_of(index))
	check(moved, "A new cycle rolls fresh ground")
	# Bonus lifts the whole field, which is where an upgrade will land.
	field.regenerate(2, 4)
	check(field.value_at(Vector2i(10, 10)) >= ArenicDigField.MIN_VALUE + 4, "A bonus raises what every tile is worth")


## Dig needs no enemy and no adjacency — it breaks the ground underfoot.
func _check_casts_anywhere() -> void:
	var hero: ArenicHeroState = shell.hero
	check(hero.definition.skills[0].ability_id == "dig", "The Forager's starter is Dig")
	check(hero.definition.skills[0].effect_kind == "dig", "Dig places ground rather than striking a target")
	# Stand far from the Guild House target, where a melee ability would refuse.
	hero.cell = Vector2i(4, 4)
	await physics_frame
	check(shell.combat.cast_unavailable_reason(hero).is_empty(), "Dig is available with no enemy in reach")
	check(shell.combat.try_cast(hero).is_empty(), "And casts there")
	await physics_frame
	check(shell.encounter.dig_field(GUILD).is_dug(Vector2i(4, 4)), "The tile underfoot is broken")
	check(shell.encounter.dig_field(LABYRINTH) != null, "A boss arena has diggable ground too")


## Yield is income toward the next hero, not damage on the boss.
func _check_yield_feeds_recruitment() -> void:
	var before_prospected: int = setup.prospected
	var before_damage: int = shell.combat.total_damage()
	var field: ArenicDigField = shell.encounter.dig_field(GUILD)
	var target := Vector2i(6, 6)
	var worth: int = field.value_at(target)
	shell.hero.cell = target
	await physics_frame
	shell.combat.tick(2.0, shell.hero) # clear the cooldown
	check(shell.combat.try_cast(shell.hero).is_empty(), "A second dig casts once the cooldown is up")
	await physics_frame
	check(setup.prospected == before_prospected + worth, "The tile pays exactly what it was worth")
	check(shell.combat.total_damage() == before_damage, "Digging deals the boss no damage by itself")
	check(shell._total_earnings() == shell.combat.total_damage() + setup.prospected, "Rolls are earned against damage AND ground broken")


## A tile yields once.
func _check_one_dig_per_tile() -> void:
	var field: ArenicDigField = shell.encounter.dig_field(GUILD)
	var spent := Vector2i(6, 6)
	check(field.is_dug(spent), "The tile is already broken")
	var before: int = setup.prospected
	var dug_before: int = field.dug_count()
	shell.combat.tick(2.0, shell.hero)
	check(shell.combat.try_cast(shell.hero).is_empty(), "Digging spent ground is still a legal cast")
	await physics_frame
	check(setup.prospected == before, "But it yields nothing the second time")
	check(field.dug_count() == dug_before, "And breaks no new ground")


## Broken ground under a boss bleeds it, one damage every eight seconds.
func _check_hazard() -> void:
	var field: ArenicDigField = shell.encounter.dig_field(LABYRINTH)
	var boss: Rect2i = shell.combat.enemy_footprint(LABYRINTH, ArenicCombatState.boss_enemy_id(LABYRINTH))
	var under: Vector2i = boss.position + Vector2i(2, 2)
	check(field.dig(under) > 0, "A tile under the boss is broken")
	var away: Vector2i = Vector2i(2, 28)
	check(field.dig(away) > 0, "And one far from it")
	var before: int = shell.combat.damage_for_arena(LABYRINTH)
	# One tick short of eight seconds: nothing is due yet.
	for tick: int in ArenicDigField.HAZARD_TICKS - 1:
		field.advance_hazards(shell.combat)
	check(shell.combat.damage_for_arena(LABYRINTH) == before, "Broken ground costs nothing before eight seconds of standing on it")
	for hazard: Array in field.advance_hazards(shell.combat):
		shell.combat.apply_hazard_damage(LABYRINTH, str(hazard[0]), int(hazard[1]))
	check(shell.combat.damage_for_arena(LABYRINTH) == before + 1, "The eighth second costs the boss exactly one")
	check(field.overlapped_cells(shell.combat) == PackedInt32Array([ArenicDigField.index_of(under)]), "Only the tile actually under the boss reads as occupied")
	# The far tile never banks anything, however long the cycle runs.
	var far_before: int = shell.combat.damage_for_arena(LABYRINTH)
	for tick: int in ArenicDigField.HAZARD_TICKS:
		for hazard: Array in field.advance_hazards(shell.combat):
			shell.combat.apply_hazard_damage(LABYRINTH, str(hazard[0]), int(hazard[1]))
	check(shell.combat.damage_for_arena(LABYRINTH) == far_before + 1, "Ground the boss is not standing on costs it nothing")
	await physics_frame


## Broken ground is a cycle's worth of work; the cycle ends and it is gone.
func _check_clears_on_cycle() -> void:
	var field: ArenicDigField = shell.encounter.dig_field(LABYRINTH)
	check(field.dug_count() > 0, "The Labyrinth has broken ground")
	var cycle: int = field.cycle
	shell.encounter.restart(LABYRINTH)
	await physics_frame
	check(field.dug_count() == 0, "Restarting the cycle clears every dig")
	check(field.cycle == cycle + 1, "And counts a new cycle, so the ground rolls fresh")
	check(shell.encounter.dig_field(GUILD).dug_count() > 0, "Another arena's ground is untouched by it")


## The flask is a skill shot: it flies where you face and leaves a pool behind.
func _check_flask() -> void:
	setup.begin_new_game()
	setup.choose_class(load("res://data/classes/alchemist.tres"))
	var fresh = load(SHELL_PATH).instantiate()
	root.add_child(fresh)
	await process_frame
	var hero: ArenicHeroState = fresh.hero
	var rules: ArenicClassAbility = hero.definition.skills[0]
	check(rules.effect_kind == "flask" and rules.range_tiles == 3, "Acid Flask is a three-tile skill shot")
	check(rules.area_size == Vector2i(3, 3) and rules.duration_seconds == 8.0, "It leaves a 3x3 pool for eight seconds")

	# It aims where the hero faces, with no target anywhere near.
	hero.cell = Vector2i(20, 20)
	hero.facing = "n"
	await physics_frame
	check(ArenicCombatState.throw_target(hero, 3) == Vector2i(20, 23), "Facing north throws three tiles north")
	hero.facing = "w"
	check(ArenicCombatState.throw_target(hero, 3) == Vector2i(17, 20), "Facing west throws three tiles west")
	hero.cell = Vector2i(1, 20)
	check(ArenicCombatState.throw_target(hero, 3) == Vector2i(0, 20), "A throw into the wall lands against it rather than leaving the arena")

	# Land one on the Guild House target and let it burn.
	var boss: Rect2i = fresh.combat.enemy_footprint(GUILD, ArenicCombatState.boss_enemy_id(GUILD))
	hero.cell = boss.position + Vector2i(2, -3)
	hero.facing = "n"
	await physics_frame
	var acid: ArenicAcidField = fresh.encounter.acid_field(GUILD)
	check(acid.count() == 0, "No pools before the throw")
	check(fresh.combat.cast_unavailable_reason(hero).is_empty(), "The flask needs no target to throw")
	check(fresh.combat.try_cast(hero).is_empty(), "And casts")
	check(acid.count() == 0, "The pool does not exist until the flask lands")
	var before: int = fresh.combat.damage_for_arena(GUILD)
	fresh.combat.tick(rules.cast_seconds, hero)
	check(acid.count() == 1, "It lands after its flight and leaves a pool")
	check(fresh.combat.damage_for_arena(GUILD) == before, "The impact itself deals no damage")
	var pools: Dictionary = acid.overlay()
	check(pools["cells"].size() == 9, "The pool covers nine tiles")

	# One damage a second, for eight seconds, then gone.
	for tick: int in ArenicCycleClock.TICKS_PER_SECOND - 1:
		acid.advance()
	check(fresh.combat.damage_for_arena(GUILD) == before, "Nothing burns before the first second is up")
	for burn: Array in acid.advance():
		_burn(fresh.combat, GUILD, burn)
	check(fresh.combat.damage_for_arena(GUILD) == before + 1, "The first second burns for one")
	var burns: int = 1
	for tick: int in ArenicCycleClock.TICKS_PER_SECOND * 9:
		for burn: Array in acid.advance():
			_burn(fresh.combat, GUILD, burn)
			burns += 1
	check(burns == 8, "Eight seconds of acid burn exactly eight times, then it dries up")
	check(acid.count() == 0, "And the pool is gone")

	# A pool away from anything burns nothing.
	hero.cell = Vector2i(6, 6)
	hero.facing = "s"
	fresh.combat.tick(10.0, hero)
	fresh.combat.try_cast(hero)
	fresh.combat.tick(rules.cast_seconds, hero)
	check(acid.count() == 1, "A second flask lays its own pool")
	var quiet: int = fresh.combat.damage_for_arena(GUILD)
	for tick: int in ArenicCycleClock.TICKS_PER_SECOND * 3:
		for burn: Array in acid.advance():
			_burn(fresh.combat, GUILD, burn)
	check(fresh.combat.damage_for_arena(GUILD) == quiet, "Acid with nothing standing in it burns nothing")
	# And the cycle takes it with it.
	fresh.encounter.restart(GUILD)
	check(acid.count() == 0, "Restarting the cycle clears every pool")
	fresh.free()
	await process_frame


## Ground effects are underfoot, not over the top: a boss wading through acid
## must be drawn over the pool. Both the height and the transparent sort order
## have to agree, or the sprite disappears into the floor.
func _check_ground_sorts_under_sprites() -> void:
	var view: ArenicArenaView = shell.stage.get_arena(shell.stage.world.index_for_id(LABYRINTH))
	var boss := view.get_node("Boss") as AnimatedSprite3D
	var broken := view.get_node("BrokenGround") as ArenicGroundOverlay
	var pools := view.get_node("AcidPools") as ArenicGroundOverlay
	check(broken.position.y < boss.position.y and pools.position.y < boss.position.y, "Both ground layers sit below the boss sprite")
	check(broken.position.y < pools.position.y, "Acid reads over broken ground")
	var boss_sort: int = boss.render_priority
	check(broken.sort_order() < boss_sort and pools.sort_order() < boss_sort, "And both sort behind it, so transparency cannot swallow the sprite")
	check(broken.sort_order() < pools.sort_order(), "While still sorting among themselves")


## Acid has no allegiance. A hero standing in a pool burns like anything else,
## and at one health that is fatal — which is the point: you have to record a
## path around your own ground.
func _check_acid_burns_heroes() -> void:
	setup.begin_new_game()
	setup.choose_class(load("res://data/classes/alchemist.tres"))
	var fresh = load(SHELL_PATH).instantiate()
	root.add_child(fresh)
	await process_frame
	fresh.select_hero()
	await physics_frame
	var hero: ArenicHeroState = fresh.hero
	var rules: ArenicClassAbility = hero.definition.skills[0]
	var acid: ArenicAcidField = fresh.encounter.acid_field(GUILD)

	# A pool the hero is not standing in leaves it alone.
	hero.cell = Vector2i(10, 10)
	await physics_frame
	await physics_frame
	acid.spawn(ArenicCombatState.area_rect(Vector2i(40, 20), Vector2i(3, 3)), rules)
	for tick: int in ArenicCycleClock.TICKS_PER_SECOND + 1:
		for burn: Array in acid.advance():
			_burn(fresh.combat, GUILD, burn)
	check(hero.arena_id == GUILD and hero.cell == Vector2i(10, 10), "Acid the hero is standing clear of leaves it alone")
	check(not fresh.combat.ally_defeated_at(GUILD, hero.ally_id()), "And costs it nothing")

	# Standing in one is fatal at a single health.
	acid.clear()
	acid.spawn(ArenicCombatState.area_rect(hero.cell, Vector2i(3, 3)), rules)
	var status: Dictionary = fresh.combat.ally_status(GUILD, hero.ally_id())
	check(int(status["health"]) == 1, "A hero has one health today, so one burn is fatal")
	for tick: int in ArenicCycleClock.TICKS_PER_SECOND:
		for burn: Array in acid.advance():
			_burn(fresh.combat, GUILD, burn)
	await physics_frame
	check(hero.arena_id == "guild_house" and hero.cell == Vector2i(30, 15), "A hero burned to death walks home like any other death")
	check(not fresh.combat.ally_defeated_at(GUILD, hero.ally_id()), "And is restored when it gets there")

	# A GHOST burned in its own pool dies where it stood, as every ghost does.
	var staff := ArenicRecording.create(Vector2i(12, 12), [ArenicTimelineEvent.move(30, Vector2i.RIGHT)] as Array[ArenicTimelineEvent])
	hero.recordings[GUILD] = staff
	fresh.encounter.fold_ghost(hero, staff)
	await physics_frame
	check(fresh.encounter.is_ghost(hero), "The hero is folded in")
	var stood: Vector2i = hero.cell
	acid.clear()
	acid.spawn(ArenicCombatState.area_rect(stood, Vector2i(3, 3)), rules)
	for tick: int in ArenicCycleClock.TICKS_PER_SECOND:
		for burn: Array in acid.advance():
			_burn(fresh.combat, GUILD, burn)
	await physics_frame
	check(hero.arena_id == GUILD and hero.cell == stood, "A ghost burned by acid dies where it stood rather than walking home")
	check(fresh.combat.ally_defeated_at(GUILD, hero.ally_id()), "And stays down for the rest of the cycle")
	fresh.encounter.restart(GUILD)
	await physics_frame
	check(not fresh.combat.ally_defeated_at(GUILD, hero.ally_id()), "The next cycle revives it, to burn again unless the take changes")
	fresh.free()
	await process_frame


## Applies one due burn exactly as the conductor does.
static func _burn(combat: ArenicCombatState, arena_id: String, burn: Array) -> void:
	var area: Rect2i = burn[0]
	for enemy_id: String in combat.enemies_in(arena_id, area):
		combat.apply_hazard_damage(arena_id, enemy_id, int(burn[1]))
	combat.damage_allies_in(arena_id, area, int(burn[1]))


func _finish() -> void:
	shell.free()
	await process_frame
	check(await RETIRE_AUDIO.wait_for_mixer(self), "Stopped audio resources retire before test exit")
	print("Dig checks: %d assertions, %s." % [checks, "FAILED" if failed else "passed"])
	quit(1 if failed else 0)
