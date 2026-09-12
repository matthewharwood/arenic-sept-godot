extends SceneTree
## Damage earns rolls, a roll deploys a hero, and the guild grows.
## Godot --headless --path arenic-game --script res://tests/heroes/recruitment_checks.gd

const SHELL_PATH: String = "res://scenes/game/game_shell.tscn"
const RETIRE_AUDIO: GDScript = preload("res://tests/support/audio_retirement.gd")
const GUILD: String = "guild_house"

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
		push_error("Recruitment: " + message)


func _run() -> void:
	create_timer(40.0).timeout.connect(func():
		push_error("Recruitment checks timed out")
		quit(1))
	_check_curve()
	_check_offers()
	setup = root.get_node("RunSetup")
	setup.begin_new_game()
	setup.choose_class(load("res://data/classes/hunter.tres"))
	shell = load(SHELL_PATH).instantiate()
	root.add_child(shell)
	await process_frame
	await _check_earning()
	await _check_claiming()
	await _check_declining()
	await _finish()


## Each roll costs more than the one before, and the table is bounded.
func _check_curve() -> void:
	var curve := load("res://data/guild/recruitment.tres") as ArenicRecruitmentCurve
	check(curve != null and curve.validation_errors().is_empty(), "The authored curve satisfies its contract")
	check(curve.cost_of(0) == 40, "The first hero costs about one cycle of a single ghost")
	check(curve.cost_of(1) > curve.cost_of(0), "Every roll costs more than the one before it")
	check(curve.total_for(2) == curve.cost_of(0) + curve.cost_of(1), "Thresholds are cumulative")
	check(curve.cost_of(400) <= ArenicRecruitmentCurve.MAX_COST, "Geometric growth is clamped rather than overflowing")
	var state := ArenicRecruitmentState.new()
	state.configure(curve, 320)
	check(state.rolls_earned(0) == 0, "No damage earns no rolls")
	check(state.rolls_earned(39) == 0 and state.rolls_earned(40) == 1, "A roll is earned exactly on its threshold")
	check(state.rolls_earned(curve.total_for(3)) == 3, "Crossing three thresholds earns three rolls")
	check(state.next_threshold(40) == curve.total_for(2), "The read-out points at the next threshold, not the one just passed")
	var progress: Dictionary = state.progress(50)
	check(int(progress.available) == 1 and int(progress.toward) == 10, "Progress measures from the last threshold crossed")


## A roll shows the same offers however long it is left unopened.
func _check_offers() -> void:
	var curve := load("res://data/guild/recruitment.tres") as ArenicRecruitmentCurve
	var catalog := load("res://data/classes/catalog.tres") as ArenicClassCatalog
	var state := ArenicRecruitmentState.new()
	state.configure(curve, 320)
	var first: Array[ArenicClassDefinition] = state.offers(0, catalog)
	check(first.size() == curve.offers_per_roll, "A roll presents its authored number of offers")
	var ids: Dictionary = {}
	for definition: ArenicClassDefinition in first:
		ids[definition.class_id] = true
	check(ids.size() == first.size(), "One roll never offers the same class twice")
	var again: Array[ArenicClassDefinition] = state.offers(0, catalog)
	check(again.map(func(d): return d.class_id) == first.map(func(d): return d.class_id), "The same roll always shows the same offers")
	var second: Array[ArenicClassDefinition] = state.offers(1, catalog)
	check(second.map(func(d): return d.class_id) != first.map(func(d): return d.class_id), "A later roll draws its own offers")


## Damage dealt anywhere accumulates toward the next hero.
func _check_earning() -> void:
	await physics_frame
	check(shell.recruitment != null, "The run owns its recruitment state")
	check(shell.combat.total_damage() == 0, "A new run has dealt no damage")
	check(shell.recruitment.rolls_available(0) == 0, "And has earned no rolls")
	# Damage from any arena counts toward the same total.
	shell.combat.apply_hazard_damage(GUILD, ArenicCombatState.boss_enemy_id(GUILD), 25)
	shell.combat.apply_hazard_damage("labyrinth", ArenicCombatState.boss_enemy_id("labyrinth"), 15)
	check(shell.combat.total_damage() == 40, "Damage in every arena feeds one running total")
	check(shell.recruitment.rolls_available(shell.combat.total_damage()) == 1, "Crossing the threshold banks a roll")
	for frame: int in 10:
		await physics_frame
	var readout := shell.hud.get_node("TopStrip/GuildRolls") as Label
	check(readout.text.contains("1 roll") and readout.text.contains("[N]"), "The read-out says a roll is waiting: %s" % readout.text)


## Claiming deploys a hero to the Guild House, unrecorded.
func _check_claiming() -> void:
	var before: int = shell.heroes.size()
	shell._open_roll()
	check(shell.modal.is_open(), "N opens the roll")
	var offers: Array[ArenicClassDefinition] = shell.recruitment.offers(0, setup.class_catalog())
	shell.modal.choose(0)
	await physics_frame
	check(shell.heroes.size() == before + 1, "Claiming adds one guild member")
	var recruit: ArenicHeroState = shell.heroes[shell.heroes.size() - 1]
	check(recruit.definition.class_id == offers[0].class_id, "The member is the class that was picked")
	check(recruit.arena_id == GUILD and recruit.cell == Vector2i(30, 15), "They deploy to the Guild House")
	check(recruit.recordings.is_empty() and not shell.encounter.is_ghost(recruit), "A recruit arrives unrecorded and controllable")
	check(shell.recruitment.rolls_claimed == 1, "The roll is spent")
	check(shell.recruitment.rolls_available(shell.combat.total_damage()) == 0, "And cannot be claimed twice")
	check(shell.stage.hero_views.has(recruit.identity_id), "The recruit is drawn where it arrived")
	shell._open_roll()
	check(not shell.modal.is_open(), "With no roll banked there is nothing to open")


## Declining keeps the roll for later.
func _check_declining() -> void:
	shell.combat.apply_hazard_damage(GUILD, ArenicCombatState.boss_enemy_id(GUILD), 500)
	var banked: int = shell.recruitment.rolls_available(shell.combat.total_damage())
	check(banked >= 1, "More damage banks more rolls")
	var before: int = shell.heroes.size()
	shell._open_roll()
	check(shell.modal.is_open(), "A banked roll opens")
	shell.modal.choose(shell.recruitment.curve.offers_per_roll) # "Later"
	await physics_frame
	check(shell.heroes.size() == before, "Declining recruits nobody")
	check(shell.recruitment.rolls_available(shell.combat.total_damage()) == banked, "And keeps the roll banked")
	check(not shell.encounter.is_paused(shell.hero.arena_id), "Declining resumes the arena it paused")


func _finish() -> void:
	shell.free()
	await process_frame
	check(await RETIRE_AUDIO.wait_for_mixer(self), "Stopped audio resources retire before test exit")
	print("Recruitment checks: %d assertions, %s." % [checks, "FAILED" if failed else "passed"])
	quit(1 if failed else 0)
