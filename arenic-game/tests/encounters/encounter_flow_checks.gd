extends SceneTree
## The real shell performing a real score: footprints move on the beat, landings
## strike the actual ledger, and a struck hero returns to the Guild House.
## Godot --headless --path arenic-game --script res://tests/encounters/encounter_flow_checks.gd

const SHELL_PATH: String = "res://scenes/game/game_shell.tscn"
const RETIRE_AUDIO: GDScript = preload("res://tests/support/audio_retirement.gd")
const LABYRINTH: String = "labyrinth"
const SANCTUM: String = "sanctum"
const CENTRE: Rect2i = Rect2i(30, 12, 6, 6)
const STATION_ONE: Rect2i = Rect2i(30, 20, 6, 6)
const STATION_TWO: Rect2i = Rect2i(30, 4, 6, 6)
## Inside station one's seven-tile blast, and outside the footprint it lands on.
const STRUCK_CELL: Vector2i = Vector2i(33, 17)
## Beyond that blast, and clear of the arena's other stations for one landing.
const SAFE_CELL: Vector2i = Vector2i(33, 4)
## A support actor standing inside the same circle.
const DUMMY_CELL: Vector2i = Vector2i(33, 19)

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
		push_error("Encounter flow: " + message)


func _run() -> void:
	create_timer(40.0).timeout.connect(func():
		push_error("Encounter flow timed out")
		quit(1))
	var packed := load(SHELL_PATH) as PackedScene
	setup = root.get_node("RunSetup")
	setup.begin_new_game()
	setup.intro_step = 6 # Established gameplay fixture; prologue is tested separately.
	setup.choose_class(load("res://data/classes/hunter.tres"))
	# Preserve this fixture’s released one-HP encounter contract.
	setup.combat.encounter_effects.ruleset = ArenicActorEffects.LEGACY
	shell = packed.instantiate()
	root.add_child(shell)
	await process_frame

	check(Engine.physics_ticks_per_second == ArenicCycleClock.TICKS_PER_SECOND, "The project pins one simulation tick to one physics step")
	check(shell.encounter.cycle_ticks(LABYRINTH) == ArenicCycleClock.CYCLE_TICKS, "The Labyrinth cycle is exactly two minutes of ticks")
	check(shell.encounter != null, "The shell mounts a conductor for the run")
	check(shell.encounter.scored_arena_ids() == PackedStringArray([LABYRINTH]), "Only the authored Labyrinth has a battle sequence today")
	check(shell.encounter.arena_ids().size() == 9, "Every arena runs a cycle, so a hero can record wherever it stands")
	check(_footprint(LABYRINTH) == CENTRE, "The Labyrinth boss opens the cycle at the arena centre")
	var sanctum_rest: Rect2i = _footprint(SANCTUM)
	check(sanctum_rest.size == Vector2i(6, 6), "An arena without a score keeps its authored resting footprint")

	await _check_jump_moves_the_ledger()
	await _check_blast_defeats_and_respawns()
	await _check_blast_spares_distant_heroes()
	await _check_cycle_loops(sanctum_rest)
	await _check_stage_swap_keeps_the_cycle()
	_finish()


## A landing moves gameplay occupancy, and accumulated damage travels with it.
func _check_jump_moves_the_ledger() -> void:
	shell.combat.register_ally(LABYRINTH, "training_dummy", DUMMY_CELL)
	# Seed the ledger directly; this check is about what a jump preserves, not
	# about how damage is dealt, which combat/flow_checks already covers.
	var before: int = shell.combat.damage_for_enemy(LABYRINTH, ArenicCombatState.boss_enemy_id(LABYRINTH))
	shell.combat.register_enemy(LABYRINTH, "seed_target", Rect2i(2, 2, 1, 1))
	var seeded: ArenicHeroState = shell.hero
	var before_arena: String = seeded.arena_id
	seeded.arena_id = LABYRINTH
	shell.combat.apply_hazard_damage(LABYRINTH, ArenicCombatState.boss_enemy_id(LABYRINTH), 3)
	seeded.arena_id = before_arena
	var resolved: int = shell.encounter.beats_resolved
	shell.encounter.seek(LABYRINTH, 468)
	await _advance_ticks(24)
	check(shell.encounter.beats_resolved == resolved + 1, "Crossing one beat resolves exactly one landing")
	check(_footprint(LABYRINTH) == STATION_ONE, "The boss now occupies the ground it jumped to")
	check(shell.combat.damage_for_enemy(LABYRINTH, ArenicCombatState.boss_enemy_id(LABYRINTH)) == before + 3, "A jump moves the target without resetting its damage")
	check(shell.combat.ally_defeated_at(LABYRINTH, "training_dummy"), "A support actor standing in the blast is struck")


## The hero dies where the circle lands and returns to the Guild House intact.
func _check_blast_defeats_and_respawns() -> void:
	shell.hero.level = 4
	shell.hero.experience = 250
	var arena_damage: int = shell.combat.damage_for_arena(LABYRINTH)
	_place_hero(LABYRINTH, STRUCK_CELL)
	shell.encounter.seek(LABYRINTH, 2148)
	await physics_frame
	check(shell.combat.ally_status(LABYRINTH, shell.hero.ally_id())["cell"] == STRUCK_CELL, "The ledger tracks the hero into the scored arena")
	await _advance_ticks(24)
	check(shell.hero.arena_id == "guild_house" and shell.hero.cell == Vector2i(30, 15), "A struck hero respawns at the Guild House")
	check(not shell.combat.ally_defeated_at("guild_house", shell.hero.ally_id()), "The respawned hero is alive again")
	var status: Dictionary = shell.combat.ally_status("guild_house", shell.hero.ally_id())
	check(int(status["health"]) == int(status["max_health"]), "Respawning restores health to full")
	check(shell.hero.level == 4 and shell.hero.experience == 250, "Death costs no level or experience")
	check(shell.combat.damage_for_arena(LABYRINTH) == arena_damage, "A landing deals no damage to the arena ledger")
	check(shell.selected_index == shell.stage.world.index_for_id("guild_house"), "Navigation follows the hero home")


## The same landing leaves a hero outside its radius untouched.
func _check_blast_spares_distant_heroes() -> void:
	_place_hero(LABYRINTH, SAFE_CELL)
	shell.encounter.seek(LABYRINTH, 3828)
	await _advance_ticks(24)
	check(_footprint(LABYRINTH) == STATION_ONE, "The distant landing still resolved")
	check(shell.hero.arena_id == LABYRINTH and shell.hero.cell == SAFE_CELL, "A hero beyond the blast radius is untouched")
	check(not shell.combat.ally_defeated_at(LABYRINTH, shell.hero.ally_id()), "Surviving the blast leaves the hero alive")


## The cycle wraps back to its opening beat without a seam, and a scoreless
## arena never moves at all.
func _check_cycle_loops(sanctum_rest: Rect2i) -> void:
	_place_hero("guild_house", Vector2i(30, 15))
	shell.encounter.seek(LABYRINTH, 6768)
	await _advance_ticks(24)
	check(_footprint(LABYRINTH) == Rect2i(6, 12, 6, 6), "The final station of the cycle resolves")
	shell.encounter.seek(LABYRINTH, 7188)
	await _advance_ticks(24)
	check(_footprint(LABYRINTH) == CENTRE, "Wrapping past two minutes returns the boss to the opening beat")
	check(shell.encounter.cycle_position(LABYRINTH) < 60, "The cycle position wrapped rather than running past its duration")
	check(_footprint(SANCTUM) == sanctum_rest, "An arena without a score never moves its boss")
	check(not shell.encounter.is_restart_pending(LABYRINTH) and not shell.arena_rewind.is_active(LABYRINTH), "An empty boss arena wraps without a hold that could affect the hero at home")
	# Populate the arena again: subsequent wraps retain the ordinary countdown.
	_place_hero(LABYRINTH, Vector2i(65, 30))
	# A span longer than the cycle resolves every lap it actually covered. The
	# clock counts whole ticks, so a lap that elapsed is a lap that happened.
	var resolved: int = shell.encounter.beats_resolved
	shell.encounter.seek(LABYRINTH, 600)
	var remaining: int = 24000
	while remaining > 0:
		if shell.encounter.is_restart_pending(LABYRINTH):
			_complete_restart(LABYRINTH)
		var span: int = mini(remaining, shell.encounter.cycle_ticks(LABYRINTH) - shell.encounter.cycle_position(LABYRINTH))
		shell.encounter.tick(shell.combat, span)
		remaining -= span
	# Ticks 600..24599: 15 beats left in the opening lap, 17 in each of two full
	# laps, then 7 before the span ends at tick 2999 of the fourth.
	check(shell.encounter.beats_resolved == resolved + 56, "Every landing in every elapsed lap resolves, none of them twice")
	check(shell.encounter.cycle_position(LABYRINTH) == 3000, "Three full laps and forty seconds land the cycle on tick 3000")
	var stored: Rect2i = shell.combat._arenas[LABYRINTH].enemies[ArenicCombatState.boss_enemy_id(LABYRINTH)].footprint
	check(stored == STATION_TWO, "The ledger stands on the last landing actually played, not the one now due")
	check(_footprint(LABYRINTH) == Rect2i(54, 12, 6, 6), "Current collision derives the landing now due before the ledger resolves its beat")


## Replacing the stage must not restart a battle sequence, or it would drift
## permanently out of step with the arena it plays against.
func _check_stage_swap_keeps_the_cycle() -> void:
	shell.encounter.seek(LABYRINTH, 3000)
	await physics_frame
	var before: int = shell.encounter.cycle_position(LABYRINTH)
	var performed: int = shell.encounter.beats_resolved
	shell.replace_stage(shell.stage_scene)
	await process_frame
	check(absi(shell.encounter.cycle_position(LABYRINTH) - before) <= 30, "A stage swap keeps the arena's cycle position")
	check(shell.encounter.beats_resolved == performed, "Reconfiguring the conductor resolves nothing")
	check(_footprint(LABYRINTH) == Rect2i(54, 12, 6, 6), "The replaced stage places the boss on the beat the cycle stands on, not on beat zero")


func _complete_restart(arena_id: String) -> void:
	var automatic: bool = shell.is_physics_processing()
	shell.set_physics_process(false)
	check(shell.encounter.is_restart_pending(arena_id) and shell.arena_rewind.phase(arena_id) in ["rewind", "countdown"], "The natural loop enters a real cosmetic restart before another score tick")
	var beats: int = shell.encounter.beats_resolved
	var saw_countdown: bool = false
	var held_zero: bool = true
	for tick: int in 902:
		if not shell.encounter.is_restart_pending(arena_id):
			break
		saw_countdown = saw_countdown or shell.arena_rewind.phase(arena_id) == "countdown"
		shell._physics_process(1.0 / 60.0)
		held_zero = held_zero and shell.encounter.cycle_position(arena_id) == 0
	check(saw_countdown and held_zero and not shell.encounter.is_restart_pending(arena_id) and shell.encounter.beats_resolved == beats, "Rewind and countdown hold the score at zero and never resolve a landing")
	shell.set_physics_process(automatic)


func _place_hero(arena_id: String, cell: Vector2i) -> void:
	shell.hero.arena_id = arena_id
	shell.hero.cell = cell
	shell.stage.sync_heroes(shell.hero.identity_id, false)


## Runs real physics frames. One physics step is one simulation tick, so the
## count is exact rather than derived from a clock read.
func _advance_ticks(ticks: int) -> void:
	for frame: int in ticks:
		await physics_frame


func _footprint(arena_id: String) -> Rect2i:
	return shell.combat.enemy_footprint(arena_id, ArenicCombatState.boss_enemy_id(arena_id))


func _finish() -> void:
	shell.free()
	await process_frame
	check(await RETIRE_AUDIO.wait_for_mixer(self), "Stopped audio resources retire before test exit")
	if failed:
		quit(1)
		return
	print("Encounter flow checks passed: %d assertions; authored jumps, blasts, respawn and cycle wrap." % checks)
	quit(0)
