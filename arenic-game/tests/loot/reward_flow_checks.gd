extends SceneTree
## Actual encounter boundaries and reward controls share one saved loot owner.
const ARENA: String = "sanctum"
var checks: int = 0
var failed: bool = false
var shell: Variant
var run: Node

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("Reward flow: " + message)

func _run() -> void:
	create_timer(40.0).timeout.connect(func(): quit(1))
	run = root.get_node("RunSetup")
	run.begin_new_game()
	run.intro_step = 6
	run.choose_class(load("res://data/classes/hunter.tres"))
	shell = load("res://scenes/game/game_shell.tscn").instantiate()
	root.add_child(shell)
	shell.set_physics_process(false)
	shell.set_process(false)
	await process_frame
	var hero: ArenicHeroState = shell.hero
	run.forget_selection(hero.arena_id, hero.identity_id)
	hero.arena_id = ARENA
	hero.cell = Vector2i(37, 4)
	var recording := ArenicRecording.create(hero.cell, [ArenicTimelineEvent.move(120, Vector2i.DOWN)])
	hero.recordings[ARENA] = recording
	shell.encounter.fold_ghost(hero, recording)
	shell.encounter.set_restart_pending(ARENA, false)
	shell.arena_rewind.configure(shell.stage, shell.combat_presentation)
	shell.combat.sync_allies(shell.heroes)
	run.remember_selection(ARENA, hero.identity_id)
	shell.select_arena(shell.stage.world.index_for_id(ARENA))
	shell.stage.camera_rig.cancel_motion()
	shell.combat.apply_hazard_damage(ARENA, ArenicCombatState.boss_enemy_id(ARENA), 12)
	shell.encounter.seek(ARENA, 7198)
	check(shell.loot.pending_count() == 0, "Damage alone does not grant equipment before a completed cycle")
	shell._physics_process(1.0 / 60.0)
	check(shell.loot.pending_count() == 0, "The penultimate tick cannot award early")
	shell._physics_process(1.0 / 60.0)
	check(shell.loot.pending_count() == 1, "The actual natural final tick awards one damage-qualified cycle draw")
	check(shell.reward_cards.is_open() and shell.reward_cards.snapshot().mode == "loot", "The new cycle draw opens the three-card presentation automatically")
	check(not shell.modal.is_open() and shell.encounter.is_ghost(hero), "Rewards preserve the ghost fold and do not open a pausing decision")
	shell.reward_cards._process(0.6)
	var cards: Array = shell.reward_cards.snapshot().cards
	check(cards.size() == 3 and cards.all(func(card: Dictionary): return card.enabled and not card.revealed and card.item_id.is_empty()), "All three loot cards arrive concealed with no leaked item identity")
	var original: Dictionary = shell.loot.peek(run.run_seed, ARENA)
	shell.reward_cards.consume_input(_key(KEY_ESCAPE))
	check(not shell.reward_cards.is_open() and shell.loot.pending_count() == 1, "Escape defers the draw without consuming it")
	shell._open_loot()
	check(shell.loot.peek(run.run_seed, ARENA) == original, "Reopening preserves the same three preselected prizes")
	# Finish only the existing rewind/countdown; the reward panel stays open.
	shell._physics_process(9.0)
	shell._physics_process(1.0 / 60.0)
	var at: int = shell.encounter.cycle_position(ARENA)
	shell._physics_process(1.0 / 60.0)
	check(shell.encounter.cycle_position(ARENA) == at + 1 and not shell.encounter.is_paused(ARENA), "The next arena loop advances while the reward cards stay open")
	shell.reward_cards._process(0.6)
	_click(shell.reward_cards.get_node("Panel/Card2").get_global_rect().get_center())
	check(shell.loot.pending_count() == 0 and _owned() == 1, "A real card pointer click transfers exactly one equipment item into inventory")
	shell.reward_cards._process(0.4)
	cards = shell.reward_cards.snapshot().cards
	check(cards.filter(func(card: Dictionary): return card.revealed).size() == 1 and not cards[1].item_id.is_empty(), "Only the chosen card flips and names its owned item")
	_click(shell.reward_cards.get_node("Panel/Card1").get_global_rect().get_center())
	shell.reward_cards.consume_input(_key(KEY_3))
	check(_owned() == 1, "Queued pointer and keyboard attempts cannot claim a second prize")
	var saved: Dictionary = ArenicSaveCodec.capture_run(run, shell)
	check(ArenicSaveCodec.validate(saved).is_empty() and saved.world.modal.is_empty(), "An open prize presentation saves only its committed ledger, never animation or a modal")
	shell.reward_cards.consume_input(_key(KEY_ENTER))
	check(not shell.reward_cards.is_open(), "Enter dismisses the completed prize")
	# Damage during an abandoned take does not turn manual restarting into loot.
	shell.combat.apply_hazard_damage(ARENA, ArenicCombatState.boss_enemy_id(ARENA), 3)
	shell._physics_process(1.0 / 60.0)
	shell.encounter.restart(ARENA, false)
	check(shell.loot.pending_count() == 0 and _owned() == 1, "Explicit restart discards only cycle progress and never awards another draw")
	shell._physics_process(9.0)
	shell.encounter.seek(ARENA, 7199)
	shell._physics_process(1.0 / 60.0)
	check(shell.loot.pending_count() == 0, "A following zero-damage completion cannot reuse the previous cycle's damage")
	# Guild House training/resource cycles never qualify as boss loot.
	shell.combat.apply_hazard_damage("guild_house", ArenicCombatState.boss_enemy_id("guild_house"), 2)
	shell.encounter.seek("guild_house", 7199)
	shell._physics_process(1.0 / 60.0)
	check(shell.loot.pending_count() == 0, "The unscored Guild House cycle cannot grant arena equipment")
	check(ArenicSaveCodec.validate(ArenicSaveCodec.capture_run(run, shell)).is_empty(), "Natural and explicit resets retain matching saved loot and arena cycle serials")
	# A free hero can still be struck while a non-pausing reward is open. The
	# resulting arena focus change must retire its old themed presentation.
	shell._physics_process(9.0)
	shell._physics_process(1.0 / 60.0)
	shell.encounter.unfold_ghost(hero)
	run.prospected = 40
	shell._open_roll()
	var banked: int = shell.recruitment.rolls_available(shell._total_earnings())
	check(shell.reward_cards.is_open() and banked > 0, "A free arena hero can defer a banked recruitment while the fight runs")
	var before_death: int = shell.encounter.cycle_position(ARENA)
	shell.combat.wound_ally(ARENA, hero.ally_id(), 4, "fixture.reward_death")
	check(hero.arena_id == "guild_house" and not shell.reward_cards.is_open(), "Death moves home and closes the old arena's card presentation")
	check(shell.recruitment.rolls_available(shell._total_earnings()) == banked and _owned() == 1, "Closing on arena change preserves the unclaimed roll and all owned equipment")
	check(shell.encounter.cycle_position(ARENA) == before_death and not shell.encounter.is_paused(ARENA), "Reward dismissal during death never resets or pauses the source fight")
	root.remove_child(shell)
	shell.free()
	await preload("res://tests/support/audio_retirement.gd").wait_for_mixer(self)
	print("Reward flow checks: %d assertions, %s." % [checks, "FAILED" if failed else "passed"])
	quit(1 if failed else 0)

func _owned() -> int:
	var total: int = 0
	for row: Dictionary in shell.loot.inventory_rows():
		total += int(row.count)
	return total

func _key(key: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = true
	return event

func _click(at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = at
	event.global_position = at
	root.push_input(event, true)
	event = event.duplicate() as InputEventMouseButton
	event.pressed = false
	root.push_input(event, true)
