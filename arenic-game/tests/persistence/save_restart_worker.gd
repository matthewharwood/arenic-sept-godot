extends SceneTree
## Test-only process entry point; exports exclude the complete tests directory.
var directory: String
var mode: String
var save: Node
var run: Node
var snapshot: Dictionary = {}
var shell: Variant


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	if arguments.size() != 3 or arguments[0] != "--restart-worker":
		quit(2)
		return
	directory = arguments[1]
	mode = arguments[2]
	save = root.get_node("SaveGames")
	run = root.get_node("RunSetup")
	if not save.storage_ready:
		await save.initialized
	save.set_process(false)
	save.backend = ArenicNativeSaveBackend.new(directory.path_join("store"))
	if not await save.refresh():
		_finish(false, save.last_error)
		return
	if mode == "writer":
		await _write_game()
	elif mode == "reader":
		await _read_game()
	elif mode == "legacy-reader":
		await _read_game(1, "legacy-expected.json")
	elif mode == "legacy-two-reader":
		await _read_game(2, "legacy-two-expected.json")
	elif mode == "legacy-three-reader":
		await _read_game(3, "legacy-three-expected.json")
	elif mode == "legacy-four-reader":
		await _read_game(4, "legacy-four-expected.json")
	elif mode == "legacy-five-reader":
		await _read_game(5, "legacy-five-expected.json")
	elif mode == "legacy-six-reader":
		await _read_game(6, "legacy-six-expected.json")
	elif mode == "intro-writer":
		await _write_intro()
	elif mode == "intro-reader":
		await _read_intro()
	elif mode == "cardinal-writer":
		await _write_cardinal()
	elif mode == "cardinal-reader":
		await _read_cardinal()
	elif mode == "abilities-writer":
		await _write_abilities()
	elif mode == "abilities-reader":
		await _read_abilities()
	elif mode == "loot-writer":
		await _write_loot()
	elif mode == "loot-reader":
		await _read_loot()
	elif mode == "channels-writer":
		await _write_channels()
	elif mode == "channels-reader":
		await _read_channels()
	elif mode == "scope-writer":
		await _write_scope()
	elif mode == "scope-reader":
		await _read_scope()
	elif mode == "death-writer":
		await _write_death()
	elif mode == "death-reader":
		await _read_death()
	elif mode == "pending-writer":
		await _write_pending()
	elif mode == "pending-reader":
		await _read_pending()
	else:
		_finish(false, "Unknown worker mode")


func _freeze_scene() -> void:
	if current_scene != null and current_scene.scene_file_path == save.GAME_SCENE:
		shell = current_scene
		shell.set_physics_process(false)
		shell.music.set_process(false)
		snapshot = ArenicSaveCodec.capture_run(run, shell)
		snapshot.selection_index = save.selection_index


func _write_game() -> void:
	if not await save.create_game(42):
		_finish(false, save.last_error)
		return
	if change_scene_to_file(save.CLASS_SCENE) != OK:
		_finish(false, "Class scene failed")
		return
	await scene_changed
	var classes: Variant = current_scene
	if classes == null:
		_finish(false, "Expected the actual class selection scene")
		return
	classes._select_class(1, false)
	# This case measures established gameplay; separate workers persist a live intro beat.
	run.intro_step = ArenicSaveCodec.INTRO_COMPLETE
	scene_changed.connect(_freeze_scene, CONNECT_ONE_SHOT)
	classes._confirm_class()
	await scene_changed
	if shell == null:
		_finish(false, "Class confirmation did not construct the game shell")
		return
	# Make real progress through the owning models. All points remain in the
	# Guild House, avoiding a renderer or an enemy footprint as a test input.
	shell.hero.step(Vector2i(1, 0), shell.stage.world)
	shell.hero.gain_experience(37)
	shell.hero.selected = false
	shell.combat.sync_allies(shell.heroes)
	run.prospected = 107
	shell.set_zoomed(true)
	shell.encounter.seek("guild_house", 1234)
	var alchemist: ArenicHeroState = run.recruit(ArenicSaveCodec._class_for("alchemist"))
	var forager: ArenicHeroState = run.recruit(ArenicSaveCodec._class_for("forager"))
	shell.combat.sync_allies(shell.heroes)
	# Normal landing adapters establish the enduring caster identity. Keep both
	# hazards one tick from damage when the pending decision is resumed.
	var target: Vector2i = shell.combat.enemy_footprint("guild_house", ArenicCombatState.boss_enemy_id("guild_house")).position
	shell.encounter.apply_landing("dig", "guild_house", Rect2i(target, Vector2i.ONE), forager.definition.skills[0], forager.ally_id())
	shell.encounter.dig_field("guild_house")._dug[ArenicDigField.index_of(target)] = ArenicDigField.HAZARD_TICKS - 1
	shell.encounter.apply_landing("acid_flask", "guild_house", Rect2i(target, Vector2i.ONE), alchemist.definition.skills[0], alchemist.ally_id())
	shell.encounter.acid_field("guild_house")._pools[0].debt = 59
	var hunter: ArenicHeroState = run.recruit(ArenicSaveCodec._class_for("hunter"))
	shell.combat.sync_allies(shell.heroes)
	if not shell.combat.try_cast(hunter).is_empty():
		_finish(false, "Restart fixture Hunter could not start Auto Shot")
		return
	shell.combat.tick(0.1)
	# Two real Bard casts retain independent five-second stacks and attribution.
	# Neither the cast delta nor presentation may advance their arena tick clock.
	for index: int in 2:
		var bard: ArenicHeroState = run.recruit(ArenicSaveCodec._class_for("bard"))
		bard.cell = target + Vector2i(-1, index)
		shell.combat.sync_allies(shell.heroes)
		if not shell.combat.try_cast(bard).is_empty():
			_finish(false, "Restart fixture Bard could not apply Cleanse")
			return
		for tick: int in (41 if index == 0 else 18):
			shell.combat.advance_enemy_dots("guild_house")
	if shell.combat._enemy_dots.size() != 2 or shell.combat._enemy_dots[0].tick_debt != 59 or shell.combat._enemy_dots[1].tick_debt != 18:
		_finish(false, "Restart fixture did not create the two expected staggered DOTs")
		return
	# Three real bags cover partial fill, full carry, and a half-finished unload.
	var gathering: ArenicGatheringState = run.get_gathering()
	run.heroes[0].cell = gathering.definition.wood_sources[0]
	run.heroes[1].cell = gathering.definition.gold_sources[0]
	run.heroes[2].cell = gathering.definition.wood_sources[1]
	shell.combat.sync_allies(shell.heroes)
	for tick: int in 300:
		gathering.advance([run.heroes[1], run.heroes[2]], shell.combat)
	for tick: int in 150:
		gathering.advance([run.heroes[0]], shell.combat)
	run.heroes[1].cell = gathering.definition.gold_dropoff
	shell.combat.sync_allies(shell.heroes)
	for tick: int in 30:
		gathering.advance([run.heroes[1]], shell.combat)
	gathering.wood_total = 9007199254740993
	gathering.gold_total = 37
	shell.music.seek_arena(&"guild_house", 34.125)
	shell._open_modal("guild_house", "Continue this run?", "A pending decision survives a process restart.", [["Continue", ArenicModal.CANCEL]])
	if not await save.flush():
		_finish(false, save.last_error)
		return
	var readback: Dictionary = await save.backend.read_all()
	var decoded: Dictionary = ArenicSaveDocument.decode(readback.records["0"], 0)
	if not decoded.ok:
		_finish(false, decoded.error)
		return
	_write_json(directory.path_join("expected.json"), {"run_id": decoded.metadata.run_id, "payload": decoded.payload})
	# Real legacy files pass through the same adapter and fresh-process Continue.
	for version: int in [1, 2, 3, 4, 5, 6]:
		var legacy: Dictionary = decoded.payload.duplicate(true)
		legacy.schema_version = version
		legacy.run.erase("loot")
		legacy.run.combat.erase("encounter")
		if version == 1:
			legacy.run.erase("intro_step")
		var expected: Dictionary = decoded.payload.duplicate(true)
		expected.run.combat.encounter = {"ruleset": ArenicActorEffects.LEGACY, "fingerprint": ArenicActorEffects.LEGACY, "actors": {}}
		if version < 6:
			legacy.run.erase("gathering")
			expected.run.gathering = {"wood_total": "0", "gold_total": "0", "bags": []}
		if version < 5:
			legacy.run.combat.erase("enemy_dots")
			expected.run.combat.enemy_dots = []
		if version < 4:
			for caster: String in legacy.run.combat.casts:
				legacy.run.combat.casts[caster].erase("resolve_seconds")
				expected.run.combat.casts[caster].resolve_seconds = 0.75
		for arena_id: String in legacy.world.arenas:
			legacy.world.arenas[arena_id].erase("restart_pending")
			if version >= 3:
				continue # Schema 3 already knew the exact hazard caster.
			for tile: Array in legacy.world.arenas[arena_id].ground.dug:
				tile.resize(2)
			for pool: Dictionary in legacy.world.arenas[arena_id].pools:
				pool.erase("caster_id")
			for tile: Array in expected.world.arenas[arena_id].ground.dug:
				tile[2] = ""
			for pool: Dictionary in expected.world.arenas[arena_id].pools:
				pool.caster_id = ""
		var metadata: Dictionary = decoded.metadata.duplicate(true)
		metadata.slot = version
		metadata.run_id = ["b", "c", "d", "e", "f", "a"][version - 1].repeat(64)
		metadata.revision = 1
		var result: Dictionary = await save.backend.write_record(version, 0, ArenicSaveDocument.encode(metadata, legacy))
		if not result.ok:
			_finish(false, result.error)
			return
		_write_json(directory.path_join(["legacy-expected.json", "legacy-two-expected.json", "legacy-three-expected.json", "legacy-four-expected.json", "legacy-five-expected.json", "legacy-six-expected.json"][version - 1]), {"run_id": metadata.run_id, "payload": expected})
	await _retire_scene()
	_finish(true)


func _read_game(slot: int = 0, expected_file: String = "expected.json") -> void:
	var expected: Variant = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join(expected_file)))
	if not expected is Dictionary or not save.has_saves():
		_finish(false, "Fresh process did not discover the written slot")
		return
	scene_changed.connect(_freeze_scene, CONNECT_ONE_SHOT)
	if not await save.continue_game(slot):
		_finish(false, save.last_error)
		return
	await scene_changed
	if shell == null:
		_finish(false, "Continue did not open the game shell")
		return
	if run.intro_step != ArenicSaveCodec.INTRO_COMPLETE:
		_finish(false, "Established or migrated run unexpectedly re-entered the prologue")
		return
	var continued_id: String = save._metadata.run_id
	var equal: bool = _canonical(snapshot) == _canonical(expected.payload)
	var before: int = shell.encounter.cycle_position("guild_house")
	# The restored modal owns the paused arena. Choosing its real button action
	# must release that pause before the next simulation tick.
	if not shell.modal.is_open():
		_finish(false, "The pending decision was not restored")
		return
	var reports: Array = []
	shell.combat.damage_reported.connect(func(caster: String, ability: String, _arena: String, _enemy: String, _amount: int) -> void: reports.append([caster, ability]))
	var dot_reports: Array = []
	shell.combat.damage_reported.connect(func(caster: String, ability: String, arena: String, enemy: String, amount: int) -> void:
		if ability == "cleanse":
			dot_reports.append([caster, arena, enemy, amount]))
	shell.modal.choose(0)
	shell.set_physics_process(true)
	await physics_frame
	await physics_frame
	shell.set_physics_process(false)
	var advanced: bool = shell.encounter.cycle_position("guild_house") > before
	var source_ok: bool = reports.has(["hero:2" if slot not in [1, 2] else "", "dig"]) and reports.has(["hero:1" if slot not in [1, 2] else "", "acid_flask"])
	var hunter: ArenicHeroState = run.heroes[3]
	var remaining: float = shell.combat.active_remaining(hunter)
	var before_hit: int = reports.count([hunter.ally_id(), "auto_shot"])
	if remaining > 0.00001:
		shell.combat.tick(remaining - 0.00001)
	var stayed_pending: bool = reports.count([hunter.ally_id(), "auto_shot"]) == before_hit
	shell.combat.tick(0.00001)
	var projectile_ok: bool = remaining > 0.00001 and stayed_pending and reports.count([hunter.ally_id(), "auto_shot"]) == before_hit + 1 and shell.combat.active_remaining(hunter) == 0.0
	var dot_ok: bool = _continue_dot_stacks(slot, dot_reports)
	var gathering_ok: bool = _continue_gathering(slot)
	await _retire_scene()
	_finish(equal and advanced and source_ok and projectile_ok and dot_ok and gathering_ok and continued_id == expected.run_id,
		"Restored snapshot, simulation, hazard, DOT or gathering differs: " + str({"equal": equal, "advanced": advanced, "source": source_ok, "projectile": projectile_ok, "dots": dot_ok, "gathering": gathering_ok, "reports": reports}) if not equal or not advanced or not source_ok or not projectile_ok or not dot_ok or not gathering_ok else "",
		{"written_run_id": expected.run_id, "continued_run_id": continued_id, "payload_equal": equal, "advanced": advanced, "hazard_sources_equal": source_ok, "projectile_continued": projectile_ok, "dots_continued": dot_ok, "gathering_continued": gathering_ok})


func _continue_dot_stacks(slot: int, reports: Array) -> bool:
	if slot not in [0, 5, 6]:
		# Historical immediate Cleanse damage remains in the ledger; an old cast
		# cannot manufacture a new lasting effect during migration or Continue.
		return shell.combat._enemy_dots.is_empty() and reports.is_empty()
	if shell.combat._enemy_dots.size() != 2:
		return false
	var elapsed: int = 241 - shell.combat._enemy_dots[0].remaining_ticks
	var target: String = ArenicCombatState.boss_enemy_id("guild_house")
	var expected: Array = [["hero:4", "guild_house", target, 1]]
	if elapsed < 1 or elapsed > 2 or reports != expected:
		return false
	# Check every future tick against the accepted, staggered schedule. This
	# crosses both expiry endpoints and one extra tick without replaying a cast.
	for tick: int in range(elapsed + 1, 284):
		shell.combat.advance_enemy_dots("guild_house")
		if tick in [1, 61, 121, 181, 241]:
			expected.append(["hero:4", "guild_house", target, 1])
		if tick in [42, 102, 162, 222, 282]:
			expected.append(["hero:5", "guild_house", target, 1])
		if reports != expected:
			return false
		if tick == 241 and (shell.combat._enemy_dots.size() != 1 or shell.combat._enemy_dots[0].caster_id != "hero:5"):
			return false
	return reports.size() == 10 and shell.combat._enemy_dots.is_empty()


func _continue_gathering(slot: int) -> bool:
	var gathering: ArenicGatheringState = run.get_gathering()
	if slot in [1, 2, 3, 4, 5]:
		# The resumed scene can begin fresh work; migration cannot invent a bank
		# or carry over the later schema's partially completed bags.
		return snapshot.run.gathering == {"wood_total": "0", "gold_total": "0", "bags": []} and gathering.wood_total == 0 and gathering.gold_total == 0
	var elapsed: int = int(gathering.snapshot_for(run.heroes[0]).fill_ticks) - 150
	if elapsed < 1 or elapsed > 2 or gathering.snapshot_for(run.heroes[1]).unload_ticks != 30 + elapsed or gathering.snapshot_for(run.heroes[2]).fill_ticks != 300:
		return false
	if gathering.wood_total != 9007199254740993 or gathering.gold_total != 37:
		return false
	var events: Array[Dictionary] = []
	for tick: int in range(elapsed + 1, 151):
		events.append_array(gathering.advance(run.heroes, shell.combat))
		if tick < 30 and not events.is_empty():
			return false
		if tick == 30 and events != [{"kind": "deposited", "hero_id": 1, "resource": "gold", "amount": 10}]:
			return false
		if tick == 149 and gathering.snapshot_for(run.heroes[0]).fill_ticks != 299:
			return false
	if gathering.snapshot_for(run.heroes[0]).fill_ticks != 300 or gathering.gold_total != 47:
		return false
	run.heroes[0].cell = gathering.definition.wood_dropoff
	run.heroes[2].cell = gathering.definition.wood_dropoff + Vector2i.RIGHT
	shell.combat.sync_allies(shell.heroes)
	for tick: int in 60:
		events.append_array(gathering.advance(run.heroes, shell.combat))
		if tick < 59 and events.size() != 1:
			return false
	return events == [{"kind": "deposited", "hero_id": 1, "resource": "gold", "amount": 10}, {"kind": "deposited", "hero_id": 0, "resource": "wood", "amount": 10}, {"kind": "deposited", "hero_id": 2, "resource": "wood", "amount": 10}] and gathering.wood_total == 9007199254741013 and gathering._bags.is_empty()


func _canonical(value: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(value, "", true, true)), "", true, true)


func _retire_scene() -> void:
	# Release audio voices through the same scene-exit lifecycle as gameplay.
	save.active_slot = -1
	save._shell = null
	if current_scene != null:
		var old: Node = current_scene
		current_scene = null
		root.remove_child(old)
		old.free()
	for frame: int in 3:
		await process_frame


func _write_json(path: String, data: Dictionary) -> bool:
	# File existence is the parent's ready signal. Publish only after closing
	# the complete document; opening the final path exposes an empty file.
	var pending: String = path + ".pending"
	var file := FileAccess.open(pending, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "", true, true))
	var error: Error = file.get_error()
	file.close()
	return error == OK and DirAccess.rename_absolute(pending, path) == OK


func _finish(ok: bool, error: String = "", extra: Dictionary = {}) -> void:
	var result: Dictionary = {"ok": ok, "error": error}
	result.merge(extra)
	if not _write_json(directory.path_join(mode + "-result.json"), result):
		push_error("Restart worker could not publish its complete result")
		quit(2)
		return
	quit(0 if ok else 1)


func _write_intro() -> void:
	if not await save.create_game(42) or run.intro_step != 0:
		_finish(false, "A fresh run must start at the quote")
		return
	if change_scene_to_file(save.CLASS_SCENE) != OK:
		_finish(false, "Intro class scene failed")
		return
	await scene_changed
	var classes: Variant = current_scene
	classes._select_class(1, false)
	# Set an intermediate durable beat at the model boundary. Native intro/UI
	# checks exercise the real dialogue actions; this case isolates process storage.
	run.intro_step = 3
	scene_changed.connect(_freeze_scene, CONNECT_ONE_SHOT)
	classes._confirm_class()
	await scene_changed
	if shell == null or run.intro_step != 3 or not await save.flush():
		_finish(false, "Intermediate prologue checkpoint did not commit")
		return
	var records: Dictionary = await save.backend.read_all()
	var decoded: Dictionary = ArenicSaveDocument.decode(records.records[str(save.active_slot)], save.active_slot)
	_write_json(directory.path_join("intro-expected.json"), {"slot": save.active_slot,
		"run_id": decoded.metadata.run_id, "payload": decoded.payload})
	await _retire_scene()
	_finish(true)


func _read_intro() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("intro-expected.json")))
	scene_changed.connect(_freeze_scene, CONNECT_ONE_SHOT)
	if not await save.continue_game(int(expected.slot)):
		_finish(false, save.last_error)
		return
	await scene_changed
	var equal: bool = shell != null and run.intro_step == 3 and _canonical(snapshot) == _canonical(expected.payload)
	var identity_equal: bool = save._metadata.run_id == expected.run_id
	await _retire_scene()
	_finish(equal and identity_equal, "Intermediate prologue beat or its run identity did not survive restart" if not equal or not identity_equal else "",
		{"intro_step": run.intro_step, "payload_equal": equal})


func _write_pending() -> void:
	scene_changed.connect(_freeze_scene, CONNECT_ONE_SHOT)
	if not await save.continue_game(0):
		_finish(false, save.last_error)
		return
	await scene_changed
	if shell == null:
		_finish(false, "Pending-restart writer did not restore the real saved shell")
		return
	# Earlier continuation workers may have checkpointed their real choice.
	# Either accepted continuation is valid; dismiss a decision only if present.
	if shell.modal.is_open():
		shell.modal.choose(0)
	var damage: int = shell.combat.damage_for_arena("guild_house")
	var wood: int = run.get_gathering().wood_total
	var gold: int = run.get_gathering().gold_total
	# Exercise the real reset/shell signal boundary, then save while its visual
	# controller holds at zero. Rewind history itself is intentionally unsaved.
	shell.encounter.restart("guild_house")
	if not shell.encounter.is_restart_pending("guild_house") or shell.encounter.cycle_position("guild_house") != 0 or shell.combat.damage_for_arena("guild_house") != damage or run.gathering.wood_total != wood or run.gathering.gold_total != gold:
		_finish(false, "Canonical reset did not preserve progress and enter pending presentation")
		return
	if not await save.flush():
		_finish(false, save.last_error)
		return
	var records: Dictionary = await save.backend.read_all()
	var decoded: Dictionary = ArenicSaveDocument.decode(records.records["0"], 0)
	if not decoded.ok or not decoded.payload.world.arenas.guild_house.restart_pending:
		_finish(false, "Pending restart was not committed through the native adapter")
		return
	_write_json(directory.path_join("pending-expected.json"), {"run_id": decoded.metadata.run_id, "payload": decoded.payload})
	await _retire_scene()
	_finish(true)


func _read_pending() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("pending-expected.json")))
	scene_changed.connect(_freeze_scene, CONNECT_ONE_SHOT)
	if not await save.continue_game(0):
		_finish(false, save.last_error)
		return
	await scene_changed
	if shell == null:
		_finish(false, "Pending restart did not Continue into the actual shell")
		return
	var exact: bool = _canonical(snapshot) == _canonical(expected.payload) and save._metadata.run_id == expected.run_id
	var begins: bool = shell.encounter.is_restart_pending("guild_house") and shell.encounter.cycle_position("guild_house") == 0 and shell.arena_rewind.phase("guild_house") == "countdown" and shell.arena_rewind.countdown_seconds("guild_house") == 3
	var cycle: int = shell.encounter.dig_field("guild_house").cycle
	var damage: int = shell.combat.damage_for_arena("guild_house")
	var wood: int = run.gathering.wood_total
	var gold: int = run.gathering.gold_total
	var remote_tick: int = shell.encounter.cycle_position("sanctum")
	for tick: int in 179:
		shell._physics_process(1.0 / 60.0)
	var held: bool = shell.encounter.is_restart_pending("guild_house") and shell.encounter.cycle_position("guild_house") == 0 and shell.combat.damage_for_arena("guild_house") == damage and run.gathering.wood_total == wood and run.gathering.gold_total == gold
	var remote: bool = shell.encounter.cycle_position("sanctum") == (remote_tick + 179) % ArenicCycleClock.CYCLE_TICKS
	shell._physics_process(1.0 / 60.0)
	var released: bool = not shell.encounter.is_restart_pending("guild_house") and shell.encounter.cycle_position("guild_house") == 0 and shell.encounter.dig_field("guild_house").cycle == cycle
	shell._physics_process(1.0 / 60.0)
	var advanced: bool = shell.encounter.cycle_position("guild_house") == 1
	await _retire_scene()
	var passed: bool = exact and begins and held and remote and released and advanced
	_finish(passed, "Pending restart process proof failed: " + str({"exact": exact, "begins": begins, "held": held, "remote": remote, "released": released, "advanced": advanced}) if not passed else "")


func _write_death() -> void:
	scene_changed.connect(_freeze_scene, CONNECT_ONE_SHOT)
	if not await save.continue_game(0):
		_finish(false, save.last_error)
		return
	await scene_changed
	shell.modal.close()
	shell.session.clear()
	for arena: String in shell.encounter.arena_ids():
		shell.encounter._clocks[arena].restart_pending = false
		shell.encounter.set_paused(arena, false)
	shell.encounter.unfold_ghost(shell.hero)
	shell.hero.arena_id = "labyrinth"
	shell.hero.cell = Vector2i(31, 24)
	shell.hero.selected = true
	run.arena_selection.clear()
	run.remember_selection("labyrinth", shell.hero.identity_id)
	shell.gathering.clear_hero(shell.hero.identity_id)
	shell.combat.respawn_hero_ally(shell.hero)
	shell.select_arena(0)
	shell.set_zoomed(true)
	shell.session.arm(shell.hero)
	shell.session.state = ArenicRecordingSession.State.RECORDING
	shell.session.countdown_left = 0
	shell.session.capture(ArenicTimelineEvent.ability(120, 1))
	shell.encounter.seek("labyrinth", 480)
	shell._physics_process(1.0 / 60.0)
	if not shell.session.is_idle() or shell.hero.arena_id != "guild_house" or not await save.flush():
		_finish(false, "The cancelled recording did not save: " + save.last_error)
		return
	var records: Dictionary = await save.backend.read_all()
	var decoded: Dictionary = ArenicSaveDocument.decode(records.records["0"], 0)
	_write_json(directory.path_join("death-expected.json"), {"payload": decoded.payload})
	await _retire_scene()
	_finish(true)


func _read_death() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("death-expected.json")))
	scene_changed.connect(_freeze_scene, CONNECT_ONE_SHOT)
	if not await save.continue_game(0):
		_finish(false, save.last_error)
		return
	await scene_changed
	var equal: bool = _canonical(snapshot) == _canonical(expected.payload)
	var restored: bool = not shell.modal.is_open() and not shell.encounter.is_paused("labyrinth") and shell.encounter.cycle_position("labyrinth") == 481
	var returned: bool = shell.hero.arena_id == "guild_house" and shell.zoomed and shell.session.is_idle() and shell.session.events.is_empty()
	shell._physics_process(1.0 / 60.0)
	var continued: bool = shell.encounter.cycle_position("labyrinth") == 482
	await _retire_scene()
	_finish(equal and restored and returned and continued, "Cancelled recording did not round-trip and continue its arena" if not (equal and restored and returned and continued) else "")


func _write_scope() -> void:
	scene_changed.connect(_freeze_scene, CONNECT_ONE_SHOT)
	if not await save.continue_game(0):
		_finish(false, save.last_error)
		return
	await scene_changed
	shell.modal.close()
	shell.session.clear()
	for arena_id: String in shell.encounter.arena_ids():
		shell.encounter.set_paused(arena_id, false)
	for member: ArenicHeroState in shell.heroes:
		shell.encounter.unfold_ghost(member)
		member.arena_id = "labyrinth"
		member.cell = Vector2i(10 + member.identity_id * 2, 10)
		shell.combat.respawn_hero_ally(member)
		shell.gathering.clear_hero(member.identity_id)
	run.arena_selection.clear()
	shell._select_identity(shell.heroes[0].identity_id)
	shell.select_arena(shell.stage.world.index_for_id("guild_house"))
	shell.set_zoomed(true)
	shell.encounter.set_restart_pending("guild_house", false)
	shell.encounter.set_paused("guild_house", false)
	shell.encounter.seek("guild_house", 1800)
	shell.encounter.restart("labyrinth")
	# Legacy idle arenas could hold a pending countdown even with no residents.
	shell.encounter.seek("sanctum", 0)
	shell.encounter.set_restart_pending("sanctum", true)
	shell.music.synchronize_cycles()
	if not await save.flush():
		_finish(false, save.last_error)
		return
	await _retire_scene()
	_finish(true)


func _read_scope() -> void:
	scene_changed.connect(_freeze_scene, CONNECT_ONE_SHOT)
	if not await save.continue_game(0):
		_finish(false, save.last_error)
		return
	await scene_changed
	var local: bool = shell.stage.world.arenas[shell.selected_index].arena_id == "guild_house" and run.heroes_in("guild_house").is_empty()
	for member: ArenicHeroState in shell.heroes:
		local = local and not member.selected
	var phase: float = shell.music.clocks[&"guild_house"].get_position()
	var synced: bool = is_equal_approx(phase, shell.music.clocks[&"guild_house"].duration_seconds * 0.25)
	var recruit: ArenicHeroState = run.recruit(load("res://data/classes/warrior.tres"))
	var selected: bool = shell.hero == recruit and recruit.selected
	var origin: Vector2i = recruit.cell
	var right := InputEventKey.new()
	right.physical_keycode = KEY_RIGHT
	right.pressed = true
	shell._hero_input.accept(right)
	shell._physics_process(1.0 / 60.0)
	var scoped: bool = recruit.cell == origin + Vector2i.RIGHT and not shell.restart_overlay.visible and shell.encounter.is_restart_pending("labyrinth") and not shell.encounter.is_restart_pending("sanctum")
	await _retire_scene()
	_finish(local and synced and selected and scoped, "Empty-arena selection, music or restart isolation failed process restart" if not (local and synced and selected and scoped) else "")


func _write_cardinal() -> void:
	scene_changed.connect(_freeze_scene, CONNECT_ONE_SHOT)
	if not await save.continue_game(0):
		_finish(false, save.last_error)
		return
	await scene_changed
	shell.modal.close()
	shell.session.clear()
	for arena: String in shell.encounter.arena_ids():
		shell.encounter.set_paused(arena, false)
		shell.encounter.set_restart_pending(arena, false)
	for member: ArenicHeroState in shell.heroes:
		shell.encounter.unfold_ghost(member)
		shell.combat.reset_caster(member)
	var actor: ArenicHeroState = shell.heroes[0]
	actor.arena_id = "sanctum"
	actor.cell = Vector2i(22, 4)
	run.arena_selection.clear()
	shell.combat.respawn_hero_ally(actor)
	shell._select_identity(actor.identity_id)
	shell.select_arena(shell.stage.world.index_for_id("sanctum"))
	shell.set_zoomed(true)
	shell.encounter.seek("sanctum", 0)
	shell.encounter.tick(shell.combat)
	actor.cell = Vector2i(29, 12)
	shell.combat.sync_allies(shell.heroes)
	shell.encounter.seek("sanctum", 1500)
	shell.combat.try_cast(actor)
	actor.cell = Vector2i(43, 4)
	shell.encounter.tick(shell.combat)
	actor.cell = Vector2i(24, 8)
	shell.combat.sync_allies(shell.heroes)
	shell.encounter.seek("sanctum", 2970)
	shell.encounter.tick(shell.combat)
	actor.cell = Vector2i(29, 12)
	shell.combat.sync_allies(shell.heroes)
	shell.encounter.seek("sanctum", 3210)
	var personal: Dictionary = shell.combat.encounter_effects.state("sanctum", actor.ally_id())
	if personal.attunement != "moon" or personal.claims != ["cardinal.1.6"] or personal.exposures.size() != 1:
		_finish(false, "Real Cardinal fixture did not reach its intended personal state: " + str(personal))
		return
	if not await save.flush():
		_finish(false, save.last_error)
		return
	var expected: Dictionary = ArenicSaveCodec.capture_run(run, shell)
	expected.selection_index = save.selection_index
	_write_json(directory.path_join("cardinal-expected.json"), expected)
	await _retire_scene()
	_finish(true)


func _read_cardinal() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("cardinal-expected.json")))
	scene_changed.connect(_freeze_scene, CONNECT_ONE_SHOT)
	if not await save.continue_game(0):
		_finish(false, save.last_error)
		return
	await scene_changed
	var equal: bool = _canonical(snapshot) == _canonical(expected)
	var actor: String = shell.hero.ally_id()
	var before: int = shell.combat.ally_status("sanctum", actor).health
	shell.encounter.tick(shell.combat)
	var wound: bool = shell.combat.ally_status("sanctum", actor).health == before - 1
	shell.encounter.tick(shell.combat)
	var clean: bool = shell.combat.encounter_effects.state("sanctum", actor).exposures.is_empty()
	await _retire_scene()
	_finish(equal and wound and clean, "Cardinal native continuation failed: " + str([equal, wound, clean]) if not (equal and wound and clean) else "")


func _write_channels() -> void:
	scene_changed.connect(_freeze_scene, CONNECT_ONE_SHOT)
	if not await save.continue_game(0):
		_finish(false, save.last_error)
		return
	await scene_changed
	shell.modal.close()
	shell.session.clear()
	for arena: String in shell.encounter.arena_ids():
		shell.encounter.set_paused(arena, false)
		shell.encounter.set_restart_pending(arena, false)
	for member: ArenicHeroState in shell.heroes:
		shell.combat.reset_caster(member)
	var ids: Array[int] = []
	for index: int in 2:
		var cardinal: ArenicHeroState = run.recruit(load("res://data/classes/cardinal.tres"))
		cardinal.arena_id = "labyrinth"
		cardinal.cell = Vector2i(22 + index * 2, 17)
		shell.combat.respawn_hero_ally(cardinal)
		shell._relocate_selection(cardinal, "guild_house")
		ids.append(cardinal.identity_id)
	var observer: ArenicHeroState = shell.heroes[0]
	shell.select_arena(shell.stage.world.index_for_id(observer.arena_id))
	shell._select_identity(observer.identity_id)
	shell.set_zoomed(true)
	shell.encounter.seek("labyrinth", 0)
	shell._sync_boss_placement()
	shell.stage.sync_heroes(shell.hero.identity_id, false)
	for identity: int in ids:
		var cardinal: ArenicHeroState = run.hero_for(identity)
		if not shell.combat.try_cast(cardinal).is_empty():
			_finish(false, "Cardinal persistence fixture could not channel")
			return
		shell.combat.tick(0.25, cardinal)
	shell.combat_presentation._process(0.25)
	shell._open_modal("labyrinth", "Continue channels?", "Both caster-owned beams survive this save.", [["Continue", ArenicModal.CANCEL]])
	if not await save.flush():
		_finish(false, save.last_error)
		return
	_write_json(directory.path_join("channels-expected.json"), {"ids":ids, "payload":ArenicSaveCodec.capture_run(run, shell)})
	await _retire_scene()
	_finish(true)


func _read_channels() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("channels-expected.json")))
	scene_changed.connect(_freeze_scene, CONNECT_ONE_SHOT)
	if not await save.continue_game(0):
		_finish(false, save.last_error)
		return
	await scene_changed
	var equal: bool = _canonical(ArenicSaveCodec.capture_run(run, shell)) == _canonical(expected.payload)
	var channels: Array[Dictionary] = shell.combat_presentation.channel_snapshots()
	var visible: bool = channels.size() == 2
	for channel: Dictionary in channels:
		visible = visible and expected.ids.any(func(identity: Variant) -> bool: return int(identity) == int(channel.caster)) and channel.visible and channel.segments > 0
	var victim: ArenicHeroState = run.hero_for(int(expected.ids[0]))
	shell.combat.cancel_channel(victim)
	shell.combat_presentation._process(0.0)
	channels = shell.combat_presentation.channel_snapshots()
	var isolated: bool = channels.size() == 1 and channels[0].caster == int(expected.ids[1]) and channels[0].visible
	await _retire_scene()
	_finish(equal and visible and isolated, "Concurrent channel native restore failed: " + str([equal, visible, isolated]) if not (equal and visible and isolated) else "")


func _write_abilities() -> void:
	scene_changed.connect(_freeze_scene, CONNECT_ONE_SHOT)
	if not await save.continue_game(0):
		_finish(false, save.last_error)
		return
	await scene_changed
	shell.modal.close()
	shell.session.clear()
	for arena: String in shell.encounter.arena_ids():
		shell.encounter.set_paused(arena, false)
		shell.encounter.set_restart_pending(arena, false)
	for member: ArenicHeroState in shell.heroes:
		shell.combat.reset_caster(member)
		if member.arena_id == "labyrinth":
			shell._respawn_free_hero(member)
	var ids: Array[int] = []
	var classes: Array[String] = ["merchant", "merchant", "hunter", "hunter", "alchemist", "alchemist"]
	for index: int in classes.size():
		var cardinal: ArenicHeroState = run.recruit(load("res://data/classes/%s.tres" % classes[index]))
		cardinal.arena_id = "labyrinth"
		cardinal.cell = Vector2i(22 + index, 17)
		shell.combat.respawn_hero_ally(cardinal)
		shell._relocate_selection(cardinal, "guild_house")
		ids.append(cardinal.identity_id)
	var observer: ArenicHeroState = shell.heroes[0]
	shell.select_arena(shell.stage.world.index_for_id(observer.arena_id))
	shell._select_identity(observer.identity_id)
	shell.set_zoomed(true)
	shell.encounter.seek("labyrinth", 0)
	shell._sync_boss_placement()
	shell.stage.sync_heroes(shell.hero.identity_id, false)
	for identity: int in ids:
		var cardinal: ArenicHeroState = run.hero_for(identity)
		if not shell.combat.try_cast(cardinal).is_empty():
			_finish(false, "Mixed-ability persistence fixture could not channel")
			return
	shell.combat.tick(0.1)
	shell.combat_presentation._process(0.1)
	shell._open_modal("labyrinth", "Continue abilities?", "Every caster-owned projectile and aura survives this save.", [["Continue", ArenicModal.CANCEL]])
	if not await save.flush():
		_finish(false, save.last_error)
		return
	_write_json(directory.path_join("abilities-expected.json"), {"ids":ids, "payload":ArenicSaveCodec.capture_run(run, shell)})
	await _retire_scene()
	_finish(true)


func _read_abilities() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("abilities-expected.json")))
	scene_changed.connect(_freeze_scene, CONNECT_ONE_SHOT)
	if not await save.continue_game(0):
		_finish(false, save.last_error)
		return
	await scene_changed
	var equal: bool = _canonical(ArenicSaveCodec.capture_run(run, shell)) == _canonical(expected.payload)
	var visuals: Array[Dictionary] = shell.combat_presentation.cast_effect_snapshots()
	var owners: bool = visuals.size() == 6
	for effect: Dictionary in visuals:
		owners = owners and expected.ids.any(func(identity: Variant) -> bool: return int(identity) == int(effect.caster)) and is_equal_approx(effect.age, 0.1)
	shell.combat.cancel_active(run.hero_for(int(expected.ids[0])))
	shell.combat_presentation.sync_active()
	visuals = shell.combat_presentation.cast_effect_snapshots()
	var isolated: bool = visuals.size() == 5 and not shell.combat_presentation._cast_effects.has(int(expected.ids[0])) and shell.combat_presentation._cast_effects.has(int(expected.ids[1]))
	await _retire_scene()
	_finish(equal and owners and isolated, "Mixed ability native restore failed: " + str([equal, owners, isolated]) if not (equal and owners and isolated) else "")


func _write_loot() -> void:
	scene_changed.connect(_freeze_scene, CONNECT_ONE_SHOT)
	if not await save.continue_game(0):
		_finish(false, save.last_error)
		return
	await scene_changed
	shell.modal.close()
	shell.session.clear()
	for arena: String in shell.encounter.arena_ids():
		shell.encounter.set_paused(arena, false)
		shell.encounter.set_restart_pending(arena, false)
	run.loot = ArenicLootState.new()
	var loot: ArenicLootState = run.get_loot()
	for arena: String in ArenicLootState.ARENAS:
		loot.reset_cycle(arena, shell.combat.damage_for_arena(arena), shell.encounter.dig_field(arena).cycle)
	var arena: String = "sanctum"
	var target: String = ArenicCombatState.boss_enemy_id(arena)
	for cycle: int in 2:
		shell.combat.apply_hazard_damage(arena, target, 40)
		loot.observe_cycle_progress(arena, shell.combat.damage_for_arena(arena), 1, false, 7200)
		loot.complete_cycle(arena, shell.combat.damage_for_arena(arena), shell.encounter.dig_field(arena).cycle + 1)
		shell.encounter.restart(arena, false)
		shell.encounter.set_restart_pending(arena, false)
	var first: Dictionary = loot.peek(run.run_seed, arena)
	var item: Dictionary = loot.claim(first.token, 1, run.run_seed)
	shell.combat.apply_hazard_damage(arena, target, 7)
	loot.observe_cycle_progress(arena, shell.combat.damage_for_arena(arena), 1, false, 3600)
	shell.encounter.seek(arena, 3600)
	if loot.pending_count() != 1 or loot.claimed_count() != 1 or not await save.flush():
		_finish(false, "Loot writer could not save its pending reward, claimed item and partial cycle: " + save.last_error)
		return
	_write_json(directory.path_join("loot-expected.json"), {"ledger": loot.snapshot(), "next": loot.peek(run.run_seed, arena), "item": item, "token": first.token})
	await _retire_scene()
	_finish(true)


func _read_loot() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("loot-expected.json")))
	scene_changed.connect(_freeze_scene, CONNECT_ONE_SHOT)
	if not await save.continue_game(0):
		_finish(false, save.last_error)
		return
	await scene_changed
	var loot: ArenicLootState = run.get_loot()
	var exact: bool = _canonical(loot.snapshot()) == _canonical(expected.ledger)
	var fixed_offer: bool = _canonical(loot.peek(run.run_seed, "sanctum")) == _canonical(expected.next)
	var no_duplicate: bool = loot.claim(expected.token, 0, run.run_seed).is_empty()
	var item: Dictionary = loot.claim(expected.next.token, 2, run.run_seed)
	var claimed_once: bool = _canonical(item) == _canonical(expected.next.cards[2]) and loot.pending_count() == 0 and loot.claimed_count() == 2
	var baseline: int = int(expected.ledger.arenas.sanctum.baseline)
	shell.combat.apply_hazard_damage("sanctum", ArenicCombatState.boss_enemy_id("sanctum"), 5)
	loot.observe_cycle_progress("sanctum", shell.combat.damage_for_arena("sanctum"), 1, false, 3600)
	var award: Dictionary = loot.complete_cycle("sanctum", shell.combat.damage_for_arena("sanctum"), shell.encounter.dig_field("sanctum").cycle + 1)
	shell.encounter.restart("sanctum", false)
	shell.encounter.set_restart_pending("sanctum", false)
	var continued: bool = award.get("damage", 0) == 12 and loot.pending_count() == 1 and shell.combat.damage_for_arena("sanctum") == baseline + 12
	var committed: bool = await save.flush()
	await _retire_scene()
	_finish(exact and fixed_offer and no_duplicate and claimed_once and continued and committed,
		"Loot process continuation failed: " + str([exact, fixed_offer, no_duplicate, claimed_once, continued, committed]) if not (exact and fixed_offer and no_duplicate and claimed_once and continued and committed) else "")
