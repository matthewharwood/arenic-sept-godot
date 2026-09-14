extends SceneTree
## Offline intent compiler. This script is copied into a disposable project;
## it is never part of the game PCK or a runtime test/mutation interface.
const VERSION: int = 1
const SEED: int = 20260913
const ARENA: String = "labyrinth"
const LENGTH: int = 7200
const STEP: float = 1.0 / 60.0
const CLASSES: Array[String] = ["hunter", "cardinal", "warrior", "thief", "bard", "merchant", "alchemist", "forager"]
const CODEC: GDScript = preload("res://scripts/persistence/save_codec.gd")

class Stage:
	extends Node
	var world: ArenicWorldDefinition = CODEC.WORLD
	func select_arena(_index: int) -> void: pass
	func sync_heroes(_identity: int, _selected: bool, _ghost: Callable) -> void: pass
class Music:
	extends Node
	var clocks: Dictionary[StringName, ArenicArenaMusicClock] = {}
	func seek_arena(id: StringName, at: float) -> void: clocks[id].seek(at)
	func set_clock_running(id: StringName, running: bool) -> void: clocks[id].running = running
class Presentation:
	extends Node
	func restore_active(_snapshot: Dictionary) -> void: pass
class WorldState:
	extends Node
	var encounter := ArenicEncounterState.new()
	var session := ArenicRecordingSession.new()
	var combat: ArenicCombatState
	var heroes: Array[ArenicHeroState] = []
	var hero: ArenicHeroState
	var selected_index: int = CODEC.WORLD.index_for_id(ARENA)
	var zoomed: bool = true
	var stage := Stage.new()
	var music := Music.new()
	var combat_presentation := Presentation.new()
	var modal: ArenicModal
	func setup(run: Node) -> void:
		heroes = run.heroes
		hero = heroes[0]
		combat = run.combat
		encounter.configure(CODEC.WORLD, CODEC.ENCOUNTERS, combat)
		encounter.performer_lookup = func(id: String) -> ArenicHeroState: return CODEC._hero_for_ally(heroes, id)
		encounter.roster_lookup = func() -> Array: return heroes
		for definition: ArenicArenaDefinition in CODEC.WORLD.arenas:
			var clock := ArenicArenaMusicClock.new()
			clock.configure(120.0, 0.0)
			music.clocks[StringName(definition.arena_id)] = clock
		add_child(stage)
		add_child(music)
		add_child(combat_presentation)
	func _frame(_animate: bool) -> void: pass
	func _sync_boss_placement() -> void: pass
	func _sync_dig_markers() -> void: pass
	func _sync_gathering() -> void: pass
	func _update_hud() -> void: pass
	func _close_overworld_menu() -> void: pass
	func _is_ghost(member: ArenicHeroState) -> bool: return encounter.is_ghost(member)
	func _open_modal(_arena: String, _title: String, _detail: String, _options: Array, _focused: int, _context: Dictionary) -> void: pass

var run: Node
var world: WorldState
var score: ArenicEncounterScore = CODEC.ENCOUNTERS.score_for(ARENA, "normal")
var staffs: Array[ArenicRecording] = []
var grid := AStarGrid2D.new()
var pending_casts: Array[ArenicHeroState] = []
var stats: Dictionary = {}
var at_tick: int = 0
var output: String
var diagnostics: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	output = OS.get_cmdline_user_args()[0]
	diagnostics = OS.get_cmdline_user_args()[1]
	run = root.get_node("RunSetup")
	grid.region = Rect2i(0, 0, 66, 31)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	grid.update()
	_build(false)
	_reset_stats()
	for tick: int in LENGTH:
		at_tick = tick
		var before: Dictionary = ArenicHeroContact.capture(world.heroes, world.combat)
		_plan_moves(tick)
		world.encounter.tick(world.combat, 1, before, _planning_effects)
		if tick % 1200 == 1199:
			print("Planned %d/7200 ticks: %d damage; %d deaths." % [tick + 1, world.combat.damage_for_arena(ARENA), stats.deaths.size()])
	var planned: Dictionary = stats.duplicate(true)
	var planned_damage: int = world.combat.damage_for_arena(ARENA)
	var planned_prospected: int = run.prospected
	_write_debug("planning.json", {"statistics": planned, "damage": planned_damage, "prospected": planned_prospected})
	world.free()
	_build(true)
	world.encounter.set_restart_pending(ARENA, true)
	var payload: Dictionary = CODEC.capture_run(run, world)
	var errors: PackedStringArray = CODEC.validate(payload)
	if not errors.is_empty():
		_fail("Fixture validation: " + str(errors)); return
	var metadata: Dictionary = {"slot": 0, "run_id": "arenic:hunter-full-arena:v1".sha256_text(), "revision": 1, "created_at": 1789257600, "updated_at": 1789257600, "seed": SEED}
	var document: String = ArenicSaveDocument.encode(metadata, payload)
	var decoded: Dictionary = ArenicSaveDocument.decode(document, 0)
	if not decoded.ok:
		_fail("Document validation: " + str(decoded)); return
	world.free()
	if not CODEC.restore_run(decoded.payload, run):
		_fail("Run hydration failed"); return
	world = WorldState.new()
	world.setup(run)
	_wire()
	if not CODEC.restore_shell(decoded.payload, world) or _canonical(CODEC.capture_run(run, world)) != _canonical(payload):
		_write_debug("roundtrip-before.json", payload)
		_write_debug("roundtrip-after.json", CODEC.capture_run(run, world))
		_fail("Exact codec round trip failed"); return
	_reset_stats()
	world.encounter.set_restart_pending(ARENA, false) # Offline proof starts after the UI-owned initial countdown.
	for tick: int in LENGTH:
		at_tick = tick
		world.encounter.tick(world.combat, 1, {}, world.combat.tick.bind(STEP))
	var actual_damage: int = world.combat.damage_for_arena(ARENA)
	if stats != planned or actual_damage != planned_damage or run.prospected != planned_prospected:
		_write_debug("planning-report.json", {"planned": planned, "replayed": stats, "planned_damage": planned_damage, "damage": actual_damage, "planned_prospected": planned_prospected, "prospected": run.prospected})
		_fail("Compiled intentions did not exactly reproduce their real-model planning simulation"); return
	var roster: Array[Dictionary] = []
	var total_events: int = 0
	for hero: ArenicHeroState in world.heroes:
		var staff: ArenicRecording = hero.recordings[ARENA]
		if staff.last_tick() != 7199:
			_fail("A staff does not cover the complete 7200-tick intent interval"); return
		var detail: Dictionary = stats.heroes[str(hero.identity_id)].duplicate(true)
		detail.moves = staff.events.filter(func(event: ArenicTimelineEvent) -> bool: return event.action_id == ArenicTimelineEvent.MOVE).size()
		detail.merge({"identity": hero.identity_id, "name": hero.display_name(), "class": hero.definition.class_id, "level": hero.level, "ability": hero.definition.skills[0].ability_id, "start_cell": [staff.start_cell.x, staff.start_cell.y], "events": staff.events.size(), "first_tick": staff.events[0].tick, "last_tick": staff.last_tick()})
		roster.append(detail)
		total_events += staff.events.size()
	var manifest: Dictionary = {"fixture_id": "hunter-full-arena", "fixture_version": VERSION, "seed": SEED, "payload_schema": CODEC.SCHEMA_VERSION, "save_slot": 0, "arena_id": ARENA, "boss_class": "hunter", "difficulty": "normal", "ticks": LENGTH, "ticks_per_second": 60, "initial_restart_pending": true, "initial_countdown_seconds": 3, "initial_damage": 0, "hero_count": 40, "per_class": 5, "selected_heroes": 0, "total_recorded_events": total_events, "save_sha256": document.sha256_text(), "simulation": {"ticks_executed": LENGTH, "damage": actual_damage, "prospected": run.prospected, "survivors_before_reset": stats.survivors, "deaths": stats.deaths, "per_class": stats.classes, "exact_replay": true, "codec_round_trip": true}, "staffs": roster}
	_write("manifest.json", manifest)
	var file := FileAccess.open(output.path_join("save.arenic.json"), FileAccess.WRITE)
	file.store_string(document)
	file.close()
	print("Hunter fixture passed: 40 ghosts, %d intents, 7200 replay ticks, %d damage, %d prospecting, %d survivors before reset." % [total_events, actual_damage, run.prospected, stats.survivors])
	world.free()
	quit(0)

func _build(with_staffs: bool) -> void:
	run.begin_new_game()
	run.intro_step = CODEC.INTRO_COMPLETE
	run.run_seed = SEED
	run.choose_class(CODEC._class_for(CLASSES[0]))
	for identity: int in range(1, 40):
		run.recruit(CODEC._class_for(CLASSES[identity / 5]))
	for hero: ArenicHeroState in run.heroes:
		var id: int = hero.identity_id
		hero.arena_id = ARENA
		hero.cell = Vector2i(20 + id % 5 if id < 20 else 40 + id % 5, 5 + (id % 20) / 5 * 5)
		hero.selected = false
		if not with_staffs:
			staffs.append(ArenicRecording.create(hero.cell, []))
		hero.recordings[ARENA] = staffs[id] if with_staffs else ArenicRecording.create(hero.cell, [])
	run.arena_selection.clear()
	run.arena_selection[ARENA] = 0
	run.combat.configure(CODEC.WORLD)
	run.combat.sync_allies(run.heroes)
	world = WorldState.new()
	world.setup(run)
	_wire()
	for hero: ArenicHeroState in run.heroes:
		world.encounter.timeline(ARENA).fold(hero.ally_id(), hero.recordings[ARENA])
	world.encounter.restart(ARENA, false)

func _wire() -> void:
	world.combat.ability_landed.connect(_landed)
	world.combat.ability_cast.connect(_cast)
	world.combat.damage_reported.connect(_damage)
	world.combat.ally_defeated.connect(_defeated)
	world.encounter.tile_dug.connect(_dug)
	world.encounter.arena_restarting.connect(_restarting)

func _reset_stats() -> void:
	stats = {"heroes": {}, "classes": {}, "deaths": [], "survivors": 40}
	for hero: ArenicHeroState in world.heroes:
		stats.heroes[str(hero.identity_id)] = {"casts": 0, "damage": 0, "moves": 0, "prospected": 0, "last_cast_tick": -1}
		stats.classes[hero.definition.class_id] = {"casts": 0, "damage": 0, "prospected": 0}

func _plan_moves(tick: int) -> void:
	pending_casts.clear()
	grid.fill_solid_region(grid.region, false)
	var placement: Dictionary = world.encounter.boss_placement(ARENA)
	var upcoming: int = (score.index_at(tick) + 1) % score.beats.size()
	var until: int = posmod(score.beats[upcoming].at_tick - tick, LENGTH)
	var threat: Vector2 = score.beats[upcoming].center_cell(Vector2i(6, 6))
	var attack_origin: Vector2i = score.beats[score.index_at(posmod(tick + 180, LENGTH))].boss_origin_cell
	var blocking: Rect2i = world.combat.enemy_footprint(ARENA, ArenicCombatState.boss_enemy_id(ARENA))
	for y: int in 31:
		for x: int in 66:
			var cell := Vector2i(x, y)
			if blocking.has_point(cell) or (until <= 180 and Vector2(cell).distance_to(threat) <= 8.0):
				grid.set_point_solid(cell)
	var hazardous: Dictionary = {}
	for pool: ArenicAcidField.Pool in world.encounter.acid_field(ARENA)._pools:
		grid.fill_solid_region(pool.area, true)
		_mark_rect(hazardous, pool.area)
	for cast: ArenicCombatState.Cast in world.combat._casts.values():
		if cast.ability.ability_id == "acid_flask":
			grid.fill_solid_region(ArenicCombatState.area_rect(cast.target_cell, cast.ability.area_size), true)
			_mark_rect(hazardous, ArenicCombatState.area_rect(cast.target_cell, cast.ability.area_size))
	var occupied: Dictionary = {}
	for hero: ArenicHeroState in world.heroes:
		if not world.combat.ally_defeated_at(ARENA, hero.ally_id()):
			grid.set_point_solid(hero.cell)
			occupied[hero.cell] = true
	for hero: ArenicHeroState in world.heroes:
		if world.combat.ally_defeated_at(ARENA, hero.ally_id()):
			if tick == 7199: staffs[hero.identity_id].events.append(ArenicTimelineEvent.ability(tick, 1))
			continue
		var rank: int = hero.identity_id % 5
		var goal: Vector2i = _goal(hero, rank, attack_origin)
		if hero.identity_id % 6 == tick % 6 and tick < 7199:
			grid.set_point_solid(hero.cell, false)
			var safe_goal: Vector2i = _nearest_open(goal, hero.cell)
			var path: Array[Vector2i] = grid.get_id_path(hero.cell, safe_goal)
			# A newly announced blast can surround a hero's current cell. Walk
			# monotonically outward through its warning area instead of treating
			# the forecast circle as a physical wall that traps the actor inside.
			if until <= 180 and Vector2(hero.cell).distance_to(threat) <= 8.0:
				var escape: Vector2i = hero.cell
				var best_distance: float = Vector2(hero.cell).distance_squared_to(threat)
				for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var candidate: Vector2i = hero.cell + direction
					var distance: float = Vector2(candidate).distance_squared_to(threat)
					if ArenicGridMath.tile_valid(candidate) and not occupied.has(candidate) and not blocking.has_point(candidate) and not hazardous.has(candidate) and distance > best_distance:
						escape = candidate
						best_distance = distance
				path.clear()
				path.append(hero.cell)
				if escape != hero.cell: path.append(escape)
			if path.size() > 1:
				var from: Vector2i = hero.cell
				var direction: Vector2i = path[1] - from
				if hero.step_within_arena(direction):
					staffs[hero.identity_id].events.append(ArenicTimelineEvent.move(tick, direction))
				grid.set_point_solid(from, true) # No following, swapping or diagonal path crossings.
				occupied[hero.cell] = true
			grid.set_point_solid(hero.cell, true)
		if hero.definition.class_id == "alchemist":
			var desired: String = "e" if rank == 4 else "w"
			var target_area: Rect2i = ArenicCombatState.area_rect(ArenicCombatState.throw_target(hero, 3), Vector2i(3, 3))
			var boss: Rect2i = world.combat.enemy_footprint(ARENA, ArenicCombatState.boss_enemy_id(ARENA))
			if (hero.facing != desired or not boss.encloses(target_area) or until < 90) and tick < 7199:
				continue # Facing is recorded only through an actual one-tile movement.
		if hero.definition.class_id == "bard" and world.combat.enemies_in(ARENA, ArenicCombatState.area_rect(hero.cell, hero.definition.skills[0].area_size)).is_empty() and tick < 7199:
			continue
		# Unique per-hero timestamps avoid relying on the recording constructor's
		# unspecified ordering for equal-tick movement and ability events.
		if tick == 7199 or (tick % 6 == (hero.identity_id + 3) % 6 and not _landing_tick(tick)):
			if hero.definition.class_id != "forager" or not world.encounter.dig_field(ARENA).is_dug(hero.cell) or tick == 7199:
				pending_casts.append(hero)

func _planning_effects() -> void:
	world.combat.tick(STEP)
	for hero: ArenicHeroState in pending_casts:
		var accepted: String = world.combat.try_cast(hero)
		if accepted.is_empty() or at_tick == 7199:
			staffs[hero.identity_id].events.append(ArenicTimelineEvent.ability(at_tick, 1))

func _goal(hero: ArenicHeroState, rank: int, origin: Vector2i) -> Vector2i:
	var cell: Vector2i
	match hero.definition.class_id:
		"hunter": cell = origin + Vector2i(11, rank)
		"cardinal": cell = origin + Vector2i(-6, rank)
		"warrior": cell = origin + Vector2i(rank, 6)
		"thief": cell = origin + Vector2i(rank, -1)
		"bard": cell = origin + Vector2i(-1, rank)
		"merchant": cell = origin + Vector2i(6, rank)
		"alchemist":
			cell = origin + (Vector2i(-2, 3) if rank == 4 else Vector2i(7, rank + 1))
			var desired: String = "e" if rank == 4 else "w"
			if hero.cell == cell and hero.facing != desired:
				cell += Vector2i.LEFT if rank == 4 else Vector2i.RIGHT
		"forager":
			var best: float = INF
			cell = hero.cell
			for candidate: Vector2i in _dig_candidates(rank):
				if grid.is_point_solid(candidate) or world.encounter.dig_field(ARENA).is_dug(candidate): continue
				var distance: float = Vector2(hero.cell).distance_squared_to(Vector2(candidate))
				if distance < best:
					cell = candidate
					best = distance
	return cell.clamp(Vector2i.ZERO, Vector2i(65, 30))

func _dig_candidates(rank: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for origin: Vector2i in [Vector2i(30, 12), Vector2i(30, 20), Vector2i(30, 4), Vector2i(54, 12), Vector2i(6, 12)]:
		for row: int in 6:
			cells.append(origin + Vector2i(rank, row))
	# After preparing its dedicated boss columns, each Forager keeps prospecting.
	for row: int in 31:
		cells.append(Vector2i(15 + rank * 7, row))
	return cells

func _nearest_open(goal: Vector2i, start: Vector2i) -> Vector2i:
	if not grid.is_point_solid(goal): return goal
	var best: Vector2i = start
	var distance: int = 99999
	for radius: int in range(1, 15):
		for y: int in range(maxi(0, goal.y - radius), mini(30, goal.y + radius) + 1):
			for x: int in range(maxi(0, goal.x - radius), mini(65, goal.x + radius) + 1):
				var cell := Vector2i(x, y)
				if grid.is_point_solid(cell): continue
				var candidate: int = absi(x - start.x) + absi(y - start.y)
				if candidate < distance: best = cell; distance = candidate
		if best != start: return best
	return start

func _mark_rect(cells: Dictionary, area: Rect2i) -> void:
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			cells[Vector2i(x, y)] = true

func _landing_tick(tick: int) -> bool:
	return score.beats[score.index_at(tick)].at_tick == tick

func _landed(caster: String, ability: String, arena: String, area: Rect2i, rules: ArenicClassAbility) -> void:
	world.encounter.apply_landing(ability, arena, area, rules, caster)

func _cast(caster: String, _ability: String, _arena: String, _origin: Vector2i, _target: Vector2i, _facing: String) -> void:
	if stats.is_empty(): return
	var hero: ArenicHeroState = CODEC._hero_for_ally(world.heroes, caster)
	stats.heroes[str(hero.identity_id)].casts += 1
	stats.heroes[str(hero.identity_id)].last_cast_tick = at_tick
	stats.classes[hero.definition.class_id].casts += 1

func _damage(caster: String, _ability: String, _arena: String, _enemy: String, amount: int) -> void:
	var hero: ArenicHeroState = CODEC._hero_for_ally(world.heroes, caster)
	if hero == null: return
	stats.heroes[str(hero.identity_id)].damage += amount
	stats.classes[hero.definition.class_id].damage += amount

func _dug(arena: String, cell: Vector2i, amount: int) -> void:
	run.prospected += amount # Same bounded positive model award as the shell's tile_dug adapter.
	var caster: String = world.encounter.dig_field(arena)._owners[ArenicDigField.index_of(cell)]
	var hero: ArenicHeroState = CODEC._hero_for_ally(world.heroes, caster)
	stats.heroes[str(hero.identity_id)].prospected += amount
	stats.classes[hero.definition.class_id].prospected += amount

func _defeated(arena: String, actor: String) -> void:
	if arena == ARENA: stats.deaths.append({"hero": actor, "tick": at_tick})

func _restarting(arena: String, _tick: int, _rewind: bool) -> void:
	if arena != ARENA or stats.is_empty(): return
	stats.survivors = 0
	for hero: ArenicHeroState in world.heroes:
		if not world.combat.ally_defeated_at(ARENA, hero.ally_id()): stats.survivors += 1

func _canonical(value: Dictionary) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value, "", true, true)), "", true, true)

func _write(name: String, data: Dictionary) -> void:
	var file := FileAccess.open(output.path_join(name), FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t", true, true) + "\n")
	file.close()

func _write_debug(name: String, data: Dictionary) -> void:
	var file := FileAccess.open(diagnostics.path_join(name), FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t", true, true) + "\n")
	file.close()

func _fail(message: String) -> void:
	push_error(message)
	if is_instance_valid(world): world.free()
	quit(1)
