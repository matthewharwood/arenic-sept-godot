extends SceneTree
## A guild of more than one: identity, views, the ledger, and Tab between them.
## Godot --headless --path arenic-game --script res://tests/heroes/guild_checks.gd

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
		push_error("Guild: " + message)


func _run() -> void:
	create_timer(30.0).timeout.connect(func():
		push_error("Guild checks timed out")
		quit(1))
	setup = root.get_node("RunSetup")
	setup.begin_new_game()
	setup.intro_step = 6 # Established gameplay fixture; prologue is tested separately.
	setup.choose_class(load("res://data/classes/hunter.tres"))
	shell = load(SHELL_PATH).instantiate()
	root.add_child(shell)
	await process_frame

	check(shell.heroes.size() == 1, "A run opens with one founding guild member")
	var founder: ArenicHeroState = shell.hero
	check(founder.identity_id == 0 and founder.ally_id() == "hero:0", "Guild members are keyed by run identity")
	check(founder.arena_id == GUILD and founder.cell == Vector2i(30, 15), "The founder stands in the Guild House")

	# A recruit arrives at the Guild House, unrecorded and controllable.
	var recruit: ArenicHeroState = setup.recruit(load("res://data/classes/warrior.tres"))
	await process_frame
	check(recruit != null and recruit.identity_id == 1, "A recruit takes the next run identity")
	check(shell.heroes.size() == 2 and setup.heroes_in(GUILD).size() == 2, "Both members stand in the Guild House")
	check(shell.stage.hero_views.size() == 2, "Every guild member has its own view")
	check(shell.stage.hero_views[0] != shell.stage.hero_views[1], "Members are drawn separately, not sharing one sprite")
	check(shell.hero == founder, "Recruiting does not steal control from the current hero")

	await _check_independent_ledger(founder, recruit)
	await _check_tab_cycles(founder, recruit)
	await _check_independent_travel(recruit)
	for frame: int in 12:
		await physics_frame
	_check_hud(founder)
	_check_cap()
	await _finish()


## Each member owns a ledger entry; one is never a stand-in for another.
func _check_independent_ledger(founder: ArenicHeroState, recruit: ArenicHeroState) -> void:
	# Both arrive on the same Guild House tile, so separate them first. Two
	# frames, because an assignment can land after this frame's step already ran.
	recruit.cell = Vector2i(40, 20)
	await physics_frame
	await physics_frame
	var first: Dictionary = shell.combat.ally_status(GUILD, founder.ally_id())
	var second: Dictionary = shell.combat.ally_status(GUILD, recruit.ally_id())
	check(not first.is_empty() and not second.is_empty(), "The ledger tracks every guild member")
	check(shell.combat.ally_ids(GUILD).size() == 2, "Two members occupy two ledger entries")
	# Strike the member the player is NOT controlling. A free member walks home
	# like any other; only a folded ghost dies in place, which recording_flow
	# covers. The founder, outside the radius, is untouched either way.
	var struck_from: Vector2i = recruit.cell
	# Put the controlled hero somewhere distinctive so "it did not move" means
	# something, then confirm another member's death leaves it alone.
	founder.cell = Vector2i(12, 9)
	await physics_frame
	await physics_frame
	shell.combat.apply_blast(GUILD, Vector2(recruit.cell), 0.4)
	check(recruit.cell == Vector2i(30, 15) and recruit.cell != struck_from, "A struck free member returns to the Guild House")
	check(not shell.combat.ally_defeated_at(GUILD, recruit.ally_id()), "And is restored when it gets there")
	check(not shell.combat.ally_defeated_at(GUILD, founder.ally_id()), "A member outside the radius is untouched")
	check(shell.hero == founder and founder.cell == Vector2i(12, 9), "Another member dying neither moves nor deselects the controlled hero")
	await physics_frame
	# Separate them again for the checks that follow.
	recruit.cell = Vector2i(40, 20)
	await physics_frame
	await physics_frame


## Tab finds the hero when away, and switches between members when already there.
func _check_tab_cycles(founder: ArenicHeroState, recruit: ArenicHeroState) -> void:
	shell.select_hero()
	await process_frame
	check(shell.zoomed and shell.hero == founder and founder.selected, "Tab focuses and selects the controlled member")
	shell.select_hero()
	await process_frame
	check(shell.hero == recruit and recruit.selected and not founder.selected, "Tab again advances to the next member in the arena")
	check(shell.stage.selected_identity == recruit.identity_id, "Only the controlled member wears the selection ring")
	shell.select_hero()
	await process_frame
	check(shell.hero == founder, "Tab wraps back around the members present")


## Members move independently, and travel carries a member's own state.
func _check_independent_travel(recruit: ArenicHeroState) -> void:
	var before: Vector2i = recruit.cell
	shell.hero.step(Vector2i.RIGHT, shell.stage.world)
	await physics_frame
	check(recruit.cell == before, "Moving the controlled member leaves the others where they stand")
	recruit.arena_id = LABYRINTH
	recruit.cell = Vector2i(10, 10)
	await physics_frame
	await physics_frame
	check(shell.combat.ally_status(LABYRINTH, recruit.ally_id()).get("cell") == Vector2i(10, 10), "A travelling member's ledger entry follows it")
	check(shell.combat.ally_status(GUILD, recruit.ally_id()).is_empty(), "It leaves no entry behind in the arena it left")
	check(setup.heroes_in(GUILD).size() == 1 and setup.heroes_in(LABYRINTH).size() == 1, "The guild reports who stands where")
	await process_frame
	check(shell.stage.hero_views[recruit.identity_id].get_parent() == shell.stage.get_arena(shell.stage.world.index_for_id(LABYRINTH)).get_node("ContentSlot"), "Its view reparents into the arena it walked to")


## The strip shows who is here; the map counts who is everywhere.
func _check_hud(founder: ArenicHeroState) -> void:
	var strip := shell.hud.get_node("BottomStrip/CharacterRoster") as ArenicRosterStrip
	check(strip.entries.size() == 1, "The strip lists only the members in the focused arena")
	check(int(strip.entries[0].identity) == founder.identity_id, "It names the member actually standing there")
	var labyrinth_cell := shell.hud.get_node("BottomStrip/ArenaCell%d" % shell.stage.world.index_for_id(LABYRINTH)) as Button
	# The map answers "where is my guild working", not "where is everyone": a
	# member standing idle somewhere is not activity, so the cell still reads X.
	check(labyrinth_cell.text == "X", "An unrecorded member standing in an arena is not activity")
	check(labyrinth_cell.tooltip_text.contains("0 ghosts") and labyrinth_cell.tooltip_text.contains("1 here"), "But the tooltip still reports who is standing there: %s" % labyrinth_cell.tooltip_text)


func _check_cap() -> void:
	check(setup.MAX_GUILD == 320, "The guild is capped at three hundred and twenty")


func _finish() -> void:
	shell.free()
	await process_frame
	check(await RETIRE_AUDIO.wait_for_mixer(self), "Stopped audio resources retire before test exit")
	print("Guild checks: %d assertions, %s." % [checks, "FAILED" if failed else "passed"])
	quit(1 if failed else 0)
