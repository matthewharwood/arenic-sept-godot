extends SceneTree
## Real viewport input -> chosen hero -> ledger -> persistent HUD and boss phase.
const SHELL_PATH: String = "res://scenes/game/game_shell.tscn"
const RETIRE_AUDIO: GDScript = preload("res://tests/support/audio_retirement.gd")
const CLASSES: PackedStringArray = ["hunter", "warrior", "thief", "alchemist", "cardinal", "bard", "forager", "merchant"]
var checks: int = 0
var failed: bool = false
var shell: Variant # Resolve GameShell only after SceneTree autoload initialization.
var setup: Node

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("Combat flow: " + message)

func _run() -> void:
	create_timer(40.0).timeout.connect(func():
		push_error("Combat flow timed out")
		quit(1))
	# Load after autoload registration, matching the shipping scene handoff.
	var packed_shell := load(SHELL_PATH) as PackedScene
	setup = root.get_node("RunSetup")
	for class_id: String in CLASSES:
		setup.begin_new_game()
		setup.choose_class(load("res://data/classes/" + class_id + ".tres"))
		shell = packed_shell.instantiate()
		root.add_child(shell)
		await process_frame
		check(shell.hero == setup.get_hero() and shell.hero.definition.class_id == class_id, class_id + " is the founding guild member")
		check(shell.hero.arena_id == "guild_house" and shell.hero.cell == Vector2i(30, 15), "New run starts in Guild House")
		check(shell.combat == setup.combat, "RunSetup owns the combat ledger")
		for arena: ArenicArenaDefinition in shell.stage.world.arenas:
			check(shell.combat.enemy_footprint(arena.arena_id, "boss:" + arena.arena_id).size == Vector2i(6, 6), "Each arena registers its explicit target footprint")
		press(KEY_SPACE)
		await physics_frame
		await physics_frame
		check(shell.combat.damage_for_arena("guild_house") == 0, "Overview cannot cast")
		press(KEY_TAB)
		check(shell.zoomed and shell.hero.selected, "Tab selects and focuses the one hero")
		# A fixture places the hero behind the training target; real arrow input
		# checks occupancy, and real Space input drives every starter's damage.
		shell.hero.cell = Vector2i(30, 21)
		shell.stage.sync_heroes(shell.hero.identity_id, true)
		press(KEY_UP)
		await physics_frame
		await physics_frame
		check(shell.hero.cell == Vector2i(30, 21), "Boss footprint blocks walking inside it")
		key(KEY_SPACE, true)
		await physics_frame
		await physics_frame
		if class_id != "cardinal":
			key(KEY_SPACE, false)
		var waited: float = 0.0
		while shell.combat.damage_for_arena("guild_house") == 0 and waited < 1.5:
			await create_timer(0.05).timeout
			waited += 0.05
		key(KEY_SPACE, false)
		var bar := shell.hud.get_node("TopStrip/DamageBar") as ArenicArenaDamageBar
		if class_id == "alchemist":
			# The flask leaves a pool; the pool is what burns, a second later.
			check(shell.combat.damage_for_arena("guild_house") == 0, "The flask impact deals the target no damage")
			var pools: ArenicAcidField = shell.encounter.acid_field("guild_house")
			check(pools.count() == 1, "It leaves a pool of acid behind instead")
			shell.combat.apply_hazard_damage("guild_house", "boss:guild_house", 1)
		elif class_id == "forager":
			# Dig pays the guild in broken ground rather than the boss in damage.
			check(shell.combat.damage_for_arena("guild_house") == 0, "Dig deals the target no damage through real cast input")
			check(setup.prospected > 0, "It yields toward the next hero instead")
			check(shell.encounter.dig_field("guild_house").is_dug(shell.hero.cell), "And leaves the tile underfoot broken")
			shell.combat.apply_hazard_damage("guild_house", "boss:guild_house", 1)
		else:
			check(shell.combat.damage_for_arena("guild_house") == 1, class_id + " deals normalized damage through real cast input")
		check(shell.combat.damage_for_enemy("guild_house", "boss:guild_house") == 1, "Target and arena totals agree")
		check(bar.total_damage == 1 and bar.current_damage == 1, "Selected HUD displays the damage event")
		check(not shell.combat.is_channeling(shell.hero), "Release stops a held channel")
		press(KEY_ESCAPE)
		press(KEY_BRACKETLEFT)
		check(shell.selected_index == 0 and not shell.zoomed and bar.total_damage == 0, "Overview bracket selection shows the other arena's independent total")
		press(KEY_BRACKETRIGHT)
		check(shell.selected_index == 1 and bar.total_damage == 1, "Returning restores that arena's cumulative bar")
		var ledger: ArenicCombatState = shell.combat
		var old_view: int = shell.stage.hero_view.get_instance_id()
		shell.replace_stage(shell.stage_scene)
		check(shell.combat == ledger and shell.combat.damage_for_arena("guild_house") == 1, "Stage replacement preserves combat")
		check(shell.stage.hero_view.get_instance_id() != old_view and bar.total_damage == 1, "Presentation is replaceable while HUD progress persists")
		if class_id == "merchant":
			check(shell.combat_presentation.active_effect_count() > 0, "A running Fortune aura is restored after a stage swap")
		if class_id == "hunter":
			_check_phases()
		shell.free()
		await process_frame
	setup.begin_new_game()
	check(setup.get_combat().damage_for_arena("guild_house") == 0, "New game resets damage")
	check(await RETIRE_AUDIO.wait_for_mixer(self), "Stopped audio resources retire before test exit")
	print("Combat flow checks: %d assertions, %s." % [checks, "FAILED" if failed else "passed"])
	quit(1 if failed else 0)

func _check_phases() -> void:
	# Advance the same real model explicitly without waiting for nineteen cooldowns.
	var combat: ArenicCombatState = shell.combat
	for index: int in 20:
		combat.tick(3.0, shell.hero)
		check(combat.try_cast(shell.hero).is_empty(), "Phase build accepts an in-range cast")
		combat.tick(1.0, shell.hero)
	var bar := shell.hud.get_node("TopStrip/DamageBar") as ArenicArenaDamageBar
	check(combat.damage_for_arena("guild_house") == 21, "Damage continues beyond a full bar")
	check(bar.completed_phases == 1 and bar.current_damage == 1, "The next phase layers over the completed bar")
	check(shell.stage.get_arena(1).damage_phase == 1 and shell.stage.get_arena(1).has_node("Boss"), "Completed phase leaves the immortal boss present")
	check(combat.damage_for_arena("labyrinth") == 0, "Other arenas remain untouched")
	check(shell.combat_presentation.active_effect_count() <= 16, "Rapid hit presentation stays in the fixed effect pool")

func press(code: Key) -> void:
	key(code, true)
	key(code, false)

func key(code: Key, down: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	root.push_input(event, true)
