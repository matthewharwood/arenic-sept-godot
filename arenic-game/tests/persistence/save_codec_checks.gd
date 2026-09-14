extends SceneTree
## Pure domain round trips, precision, hostile payloads and future-tick equality.
const CODEC: GDScript = preload("res://scripts/persistence/save_codec.gd")
var checks: int = 0
var failed: bool = false

class RunFixture:
	extends Node
	var selected_class: ArenicClassDefinition
	var heroes: Array[ArenicHeroState] = []
	var selected_identity: int = -1
	var arena_selection: Dictionary[String, int] = {}
	var combat: ArenicCombatState
	var recruitment: ArenicRecruitmentState
	var gathering: ArenicGatheringState
	var loot: ArenicLootState
	var prospected: int = 0
	var run_seed: int = 1234
	var intro_step: int = 0
	var _next_identity: int = 0
	func begin_new_game() -> void:
		selected_class = null
		heroes.clear()
		selected_identity = -1
		arena_selection.clear()
		combat = null
		recruitment = null
		gathering = null
		loot = null
		prospected = 0
		intro_step = 0
		_next_identity = 0
	func get_recruitment() -> ArenicRecruitmentState:
		if recruitment == null:
			recruitment = ArenicRecruitmentState.new()
			recruitment.configure(CODEC.CURVE, CODEC.MAX_HEROES)
		return recruitment
	func get_combat() -> ArenicCombatState:
		if combat == null:
			combat = ArenicCombatState.new()
		return combat
	func get_gathering() -> ArenicGatheringState:
		if gathering == null:
			gathering = ArenicGatheringState.new()
			gathering.configure(load("res://data/guild/gathering.tres"))
		return gathering
	func get_loot() -> ArenicLootState:
		if loot == null:
			loot = ArenicLootState.new()
		return loot

class StageFixture:
	extends Node
	var world: ArenicWorldDefinition = CODEC.WORLD
	func select_arena(_index: int) -> void:
		pass
	func sync_heroes(_identity: int, _selected: bool, _ghost: Callable) -> void:
		pass

class MusicFixture:
	extends Node
	var clocks: Dictionary[StringName, ArenicArenaMusicClock] = {}
	func seek_arena(id: StringName, at: float) -> void:
		clocks[id].seek(at)
	func set_clock_running(id: StringName, running: bool) -> void:
		clocks[id].running = running

class PresentationFixture:
	extends Node
	func clear() -> void:
		pass
	func restore_active(_snapshot: Dictionary) -> void:
		pass

class ShellFixture:
	extends Node
	var encounter := ArenicEncounterState.new()
	var session := ArenicRecordingSession.new()
	var combat: ArenicCombatState
	var heroes: Array[ArenicHeroState] = []
	var hero: ArenicHeroState
	var selected_index: int = 0
	var zoomed: bool = true
	var stage := StageFixture.new()
	var music := MusicFixture.new()
	var combat_presentation := PresentationFixture.new()
	var modal: ArenicModal
	func configure(run: RunFixture) -> void:
		heroes = run.heroes
		hero = heroes[0]
		selected_index = CODEC.WORLD.index_for_id(hero.arena_id)
		combat = run.combat
		encounter.configure(CODEC.WORLD, CODEC.ENCOUNTERS, combat)
		encounter.performer_lookup = func(id: String) -> ArenicHeroState:
			return CODEC._hero_for_ally(heroes, id)
		for arena: ArenicArenaDefinition in CODEC.WORLD.arenas:
			var clock := ArenicArenaMusicClock.new()
			clock.configure(arena.music.loop_seconds, 12.5)
			music.clocks[StringName(arena.arena_id)] = clock
		add_child(stage)
		add_child(music)
		add_child(combat_presentation)
	func _frame(_animate: bool) -> void:
		pass
	func _sync_boss_placement() -> void:
		pass
	func _sync_dig_markers() -> void:
		pass
	func _sync_gathering() -> void:
		pass
	func _update_hud() -> void:
		pass
	func _close_overworld_menu() -> void:
		pass
	func _is_ghost(member: ArenicHeroState) -> bool:
		return encounter.is_ghost(member)
	func _open_modal(_arena: String, _title: String, _detail: String, _options: Array, _focused: int, _context: Dictionary) -> void:
		pass


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("Save codec: " + message)


func _run() -> void:
	var run := RunFixture.new()
	var selection: Dictionary = CODEC.capture_run(run)
	check(CODEC.validate(selection).is_empty(), "Empty class selection is a valid slot")
	check(selection.scene == "class_selection", "Class-selection scene is explicit")
	check(CODEC.validate(JSON.parse_string(JSON.stringify(selection))).is_empty(), "Pending class selection survives actual JSON numeric decoding")
	selection.selection_index = 5
	var empty := RunFixture.new()
	check(CODEC.restore_run(selection, empty), "Pending class selection restores without spawning a hero")
	check(empty.heroes.is_empty(), "Continue preserves unfinished class selection")
	empty.free()
	run.intro_step = CODEC.INTRO_COMPLETE # Rich fixture is an established guild.
	for class_id: String in ["hunter", "alchemist", "forager"]:
		var hero := ArenicHeroState.new()
		hero.identity_id = run.heroes.size()
		hero.definition = CODEC._class_for(class_id)
		hero.cell = Vector2i(30 + hero.identity_id, 15)
		hero.selected = hero.identity_id == 0
		run.heroes.append(hero)
	run.selected_class = run.heroes[0].definition
	run.selected_identity = 0
	run._next_identity = 3
	run.arena_selection.guild_house = 0
	run.prospected = 9007199254740993
	run.heroes[0].experience = ArenicHeroState.MAX_EXPERIENCE
	run.get_recruitment().rolls_claimed = 2
	var combat: ArenicCombatState = run.get_combat()
	combat.configure(CODEC.WORLD)
	combat.sync_allies(run.heroes)
	combat.register_enemy("guild_house", "fixture", Rect2i(35, 15, 1, 1))
	combat._arenas.guild_house.damage = 9007199254740995
	combat._arenas.guild_house.enemies.fixture.damage = 9007199254740995
	combat._arenas.guild_house.allies["hero:0"].max_health = 3
	combat._arenas.guild_house.allies["hero:0"].health = 2
	combat._arenas.guild_house.allies["hero:0"].debuffs = PackedStringArray(["poison"])
	check(combat.try_cast(run.heroes[1]).is_empty(), "Fixture starts a real flask cast")
	combat.tick(0.125)
	var shell := ShellFixture.new()
	shell.configure(run)
	var recording := ArenicRecording.create(Vector2i(32, 15), [ArenicTimelineEvent.move(40, Vector2i(1, 0)), ArenicTimelineEvent.ability(42, 1)])
	run.heroes[2].recordings.guild_house = recording
	var timeline: ArenicArenaTimeline = shell.encounter.timeline("guild_house")
	timeline.fold("hero:2", recording)
	shell.encounter.seek("guild_house", 35)
	shell.encounter.dig_field("guild_house").dig(Vector2i(35, 15), "hero:2")
	shell.encounter.dig_field("guild_house")._dug[ArenicDigField.index_of(Vector2i(35, 15))] = 479
	shell.encounter.acid_field("guild_house").spawn(Rect2i(34, 14, 3, 3), run.heroes[1].definition.skills[0], "hero:1")
	shell.encounter.acid_field("guild_house")._pools[0].debt = 59
	shell.session.arm(run.heroes[0])
	shell.session.state = ArenicRecordingSession.State.RECORDING
	shell.session.countdown_left = 0
	shell.session.capture(ArenicTimelineEvent.move(30, Vector2i(0, 1)))
	var saved: Dictionary = CODEC.capture_run(run, shell)
	_check_intro_contract(selection, saved)
	_check_hazard_contract(saved)
	_check_projectile_contract()
	_check_released_timing_catalog_edits()
	_check_enemy_dot_contract()
	_check_gathering_contract()
	_check_clearing_gathering_compatibility()
	_check_tavern_dropoff_compatibility()
	_check_restart_pending_contract()
	var validation: PackedStringArray = CODEC.validate(saved)
	check(validation.is_empty(), "Rich gameplay fixture is valid: " + str(validation))
	check(saved.run.prospected == "9007199254740993", "64-bit earnings use exact decimal strings")
	check(saved.run.heroes[0].experience == "9223372036854775807", "Maximum XP survives encoding")
	var json: String = JSON.stringify(saved)
	var parsed: Variant = JSON.parse_string(json)
	check(parsed is Dictionary and CODEC.validate(parsed).is_empty(), "Actual JSON round trip is validated: " + str(CODEC.validate(parsed)))
	var restored := RunFixture.new()
	check(CODEC.restore_run(parsed, restored), "Run restoration succeeds")
	if failed:
		for object: Node in [shell, run, restored]:
			object.free()
		quit(1)
		return
	check(restored.prospected == run.prospected and restored.heroes[0].experience == ArenicHeroState.MAX_EXPERIENCE, "64-bit progress is exact after JSON decoding")
	check(restored.run_seed == run.run_seed and restored._next_identity == 3, "Seed and stable identity allocator survive")
	check(restored.recruitment.rolls_claimed == 2, "Claimed rolls survive")
	var resumed := ShellFixture.new()
	resumed.configure(restored)
	check(CODEC.restore_shell(parsed, resumed), "World restoration succeeds")
	var recaptured: Dictionary = CODEC.capture_run(restored, resumed)
	check(JSON.stringify(recaptured) == JSON.stringify(saved), "Every declared durable field round-trips exactly")
	check(resumed.encounter.is_ghost(restored.heroes[2]), "Folded ghost membership survives")
	check(resumed.session.is_recording() and resumed.session.events.size() == 1, "In-flight draft survives")
	check(resumed.combat.ally_status("guild_house", "hero:0").debuffs == PackedStringArray(["poison"]), "Health and debuffs survive")
	check(resumed.combat.active_cast_snapshot(restored.heroes[1]).elapsed == 0.125, "In-flight cast phase survives")
	check(resumed.encounter.dig_field("guild_house")._dug == shell.encounter.dig_field("guild_house")._dug, "Hazard debt survives")
	check(resumed.encounter.acid_field("guild_house")._pools[0].debt == 59, "Acid tick debt survives")
	check(resumed.encounter.dig_field("guild_house")._owners == shell.encounter.dig_field("guild_house")._owners, "First digger ownership survives")
	check(resumed.encounter.acid_field("guild_house")._pools[0].caster_id == "hero:1", "Lingering acid retains its original Alchemist")
	var original_reports: Array = []
	var resumed_reports: Array = []
	shell.combat.damage_reported.connect(func(caster: String, ability: String, arena: String, enemy: String, amount: int) -> void: original_reports.append([arena, enemy, amount, caster, ability]))
	resumed.combat.damage_reported.connect(func(caster: String, ability: String, arena: String, enemy: String, amount: int) -> void: resumed_reports.append([arena, enemy, amount, caster, ability]))
	for tick: int in 12:
		shell.combat.tick(1.0 / 60.0)
		shell.encounter.tick(shell.combat)
		resumed.combat.tick(1.0 / 60.0)
		resumed.encounter.tick(resumed.combat)
	check(JSON.stringify(CODEC.capture_run(restored, resumed)) == JSON.stringify(CODEC.capture_run(run, shell)), "Restored simulation resolves the same next 12 ticks, including ghost moves and hazard damage")
	check(not original_reports.is_empty() and original_reports == resumed_reports, "Future hazard observations preserve exact caster and attack after JSON restore")
	check(original_reports.has(["guild_house", "fixture", 1, "hero:2", "dig"]), "Restored broken ground reports the first digger")
	check(original_reports.has(["guild_house", "fixture", 1, "hero:1", "acid_flask"]), "Restored pool reports the original flask caster")
	var corrupt: Dictionary = saved.duplicate(true)
	corrupt.schema_version = CODEC.SCHEMA_VERSION + 1
	check(not CODEC.validate(corrupt).is_empty(), "Unknown schema is rejected")
	corrupt = saved.duplicate(true)
	corrupt.run.heroes[0].class_id = "res://arbitrary_script.gd"
	check(not CODEC.validate(corrupt).is_empty(), "Saves cannot load arbitrary resources")
	corrupt = saved.duplicate(true)
	corrupt.run.heroes[1].identity = 0
	check(not CODEC.validate(corrupt).is_empty(), "Duplicate stable identities are rejected")
	corrupt = saved.duplicate(true)
	corrupt.run.prospected = "9223372036854775808"
	check(not CODEC.validate(corrupt).is_empty(), "Integer overflow is rejected")
	corrupt = saved.duplicate(true)
	corrupt.run.combat.casts["hero:1"].elapsed = INF
	check(not CODEC.validate(corrupt).is_empty(), "Non-finite cast timers are rejected")
	corrupt = saved.duplicate(true)
	corrupt.world.arenas.guild_house.active.append("hero:999")
	check(not CODEC.validate(corrupt).is_empty(), "Unknown ghost references are rejected")
	corrupt = saved.duplicate(true)
	corrupt.world.session.events[0].tick = 7200
	check(not CODEC.validate(corrupt).is_empty(), "Out-of-cycle recording events are rejected")
	corrupt = saved.duplicate(true)
	corrupt.world.arenas.guild_house.paused = true
	check(not CODEC.validate(corrupt).is_empty(), "Paused arena cannot lose its owning decision")
	corrupt = saved.duplicate(true)
	corrupt.run.extra_future_state = 1
	check(not CODEC.validate(corrupt).is_empty(), "Unknown durable fields require a schema migration")
	var hostile_paths: Array = [
		["run", "selected_class"], ["run", "heroes"], ["run", "next_identity"],
		["run", "heroes", 0, "cell"], ["run", "heroes", 0, "selected"],
		["run", "combat", "arenas", "guild_house"],
		["run", "combat", "arenas", "guild_house", "enemies", "fixture", "footprint"],
		["run", "combat", "arenas", "guild_house", "allies", "hero:0", "debuffs"],
		["run", "combat", "casts", "hero:1", "owner"],
		["run", "combat", "casts", "hero:1", "arena"],
		["run", "combat", "casts", "hero:1", "target_id"],
		["run", "combat", "cooldowns", "hero:1"],
		["world", "arenas", "guild_house", "orders", "hero:2"],
		["world", "arenas", "guild_house", "ground", "values"],
		["world", "arenas", "guild_house", "ground", "dug", 0],
		["world", "arenas", "guild_house", "pools", 0, "span"],
		["world", "session", "identity"], ["world", "session", "events"],
		["world", "music", "guild_house", "position"], ["world", "modal"],
	]
	for path: Array in hostile_paths:
		var invalid: Dictionary = JSON.parse_string(JSON.stringify(saved))
		var owner: Variant = invalid
		for part: Variant in path.slice(0, -1):
			owner = owner[part]
		owner[path[-1]] = {"invalid": null}
		check(not CODEC.validate(invalid).is_empty(), "Hostile field type is rejected safely: " + str(path))
	var before: String = JSON.stringify(CODEC.capture_run(restored, resumed))
	check(not CODEC.restore_run(corrupt, restored), "Invalid payload never partially restores")
	check(JSON.stringify(CODEC.capture_run(restored, resumed)) == before, "Rejected restore leaves current progress untouched")
	for object: Node in [shell, resumed, run, restored]:
		object.free()
	print("Save codec checks: %d" % checks)
	quit(1 if failed else 0)


func _check_intro_contract(selection: Dictionary, saved: Dictionary) -> void:
	check(selection.run.intro_step == 0, "A new pending game begins at the opening quote")
	var intro: Dictionary = selection.duplicate(true)
	intro.scene = "game"
	intro.run.heroes = [saved.run.heroes[0].duplicate(true)]
	intro.run.heroes[0].recordings = {}
	intro.run.selected_class = intro.run.heroes[0].class_id
	intro.run.selected_identity = intro.run.heroes[0].identity
	intro.run.next_identity = 1
	intro.run.arena_selection = {"guild_house": intro.run.selected_identity}
	for step: int in range(CODEC.INTRO_COMPLETE + 1):
		var checkpoint: Dictionary = intro.duplicate(true)
		checkpoint.run.intro_step = step
		var parsed: Dictionary = JSON.parse_string(JSON.stringify(checkpoint))
		var resumed := RunFixture.new()
		check(CODEC.restore_run(parsed, resumed) and resumed.intro_step == step,
			"Prologue step %d survives JSON and model restoration" % step)
		check(CODEC.capture_run(resumed).run.intro_step == step,
			"Prologue step %d remains authoritative after capture" % step)
		resumed.free()
	for value: Variant in [-1, 7, 0.5, "1", true, null]:
		var corrupt: Dictionary = saved.duplicate(true)
		corrupt.run.intro_step = value
		var untouched := RunFixture.new()
		untouched.intro_step = 4
		check(not CODEC.restore_run(corrupt, untouched) and untouched.intro_step == 4,
			"Invalid prologue step fails before replacing the run: " + str(value))
		untouched.free()
	for current: Dictionary in [selection, saved]:
		var legacy: Dictionary = _legacy_payload(current, 1)
		var original: String = JSON.stringify(legacy, "", true, true)
		var migrated: Dictionary = ArenicSaveMigrations.upgrade(legacy)
		check(migrated.ok and migrated.payload.run.intro_step == CODEC.INTRO_COMPLETE,
			"Legacy %s skips the new-game prologue" % current.scene)
		var expected: Dictionary = _unknown_hazard_owners(current)
		expected.run.intro_step = CODEC.INTRO_COMPLETE
		check(JSON.stringify(migrated.payload, "", true, true) == JSON.stringify(expected, "", true, true),
			"Migration changes only schema, the prologue checkpoint, and unknown hazard owners")
		check(JSON.stringify(legacy, "", true, true) == original, "Migration preserves its input record")
		var metadata := {"slot": 0, "run_id": "a".repeat(64), "revision": 7,
			"created_at": 1, "updated_at": 2, "seed": legacy.run.seed}
		var document: String = ArenicSaveDocument.encode(metadata, legacy)
		var decoded: Dictionary = ArenicSaveDocument.decode(document, 0)
		check(decoded.ok and decoded.payload.run.intro_step == CODEC.INTRO_COMPLETE
			and decoded.metadata.run_id == metadata.run_id and decoded.metadata.revision == 7,
			"A checksum-valid old document hydrates through the production migration boundary")
		var malformed: Dictionary = legacy.duplicate(true)
		malformed.run.erase("heroes")
		check(not ArenicSaveMigrations.upgrade(malformed).ok, "Malformed legacy state is rejected before migration")
		malformed = legacy.duplicate(true)
		malformed.run.intro_step = 2
		check(not ArenicSaveMigrations.upgrade(malformed).ok, "Legacy schema cannot smuggle a future field")
	var intro_run := RunFixture.new()
	CODEC.restore_run(intro, intro_run)
	intro_run.get_combat().configure(CODEC.WORLD)
	intro_run.get_combat().sync_allies(intro_run.heroes)
	var intro_shell := ShellFixture.new()
	intro_shell.configure(intro_run)
	intro_shell.selected_index = CODEC.WORLD.index_for_id("guild_house")
	var initialized: Dictionary = CODEC.capture_run(intro_run, intro_shell)
	check(CODEC.validate(initialized).is_empty(), "An initialized locked prologue has a complete valid world")
	var invalid_view: Dictionary = initialized.duplicate(true)
	invalid_view.world.zoomed = false
	check(CODEC.validate(invalid_view).has("An unfinished prologue must stay focused on the Guild House."),
		"Locked intro navigation cannot restore to overview")
	intro_shell.session.arm(intro_run.heroes[0])
	check(CODEC.validate(CODEC.capture_run(intro_run, intro_shell)).has("An unfinished prologue cannot contain a recording session."),
		"Locked intro cannot retain an active recording countdown")
	intro_shell.free()
	intro_run.free()
	var away: Dictionary = intro.duplicate(true)
	away.run.heroes[0].arena_id = "labyrinth"
	away.run.arena_selection = {"labyrinth": away.run.selected_identity}
	check(not CODEC.validate(away).is_empty(), "An unfinished prologue cannot move the founder to an arena")
	away = saved.duplicate(true)
	away.run.intro_step = 1
	check(not CODEC.validate(away).is_empty(), "An established multi-hero guild cannot claim an unfinished prologue")
	away = intro.duplicate(true)
	away.run.heroes[0].recordings = saved.run.heroes[2].recordings.duplicate(true)
	check(not CODEC.validate(away).is_empty(), "The locked founder cannot already have a committed recording")
	away = selection.duplicate(true)
	away.run.intro_step = 3
	check(not CODEC.validate(away).is_empty(), "A pending class selection cannot skip into dialogue")
	var future: Dictionary = saved.duplicate(true)
	future.schema_version = CODEC.SCHEMA_VERSION + 1
	check(not ArenicSaveMigrations.upgrade(future).ok, "Future schema remains unsupported and preserved")


func _unknown_hazard_owners(payload: Dictionary) -> Dictionary:
	var copy := payload.duplicate(true)
	if not copy.world.is_empty():
		for arena: Dictionary in copy.world.arenas.values():
			for tile: Array in arena.ground.dug:
				tile[2] = ""
			for pool: Dictionary in arena.pools:
				pool.caster_id = ""
	return copy


func _legacy_payload(payload: Dictionary, version: int) -> Dictionary:
	var legacy := payload.duplicate(true)
	legacy.schema_version = version
	if version < 11:
		legacy.run.erase("loot")
	if version < 10 and not legacy.run.combat.is_empty():
		legacy.run.combat.erase("encounter")
	if version < 7 and not legacy.world.is_empty():
		for arena: Dictionary in legacy.world.arenas.values():
			arena.erase("restart_pending")
	if version < 6:
		legacy.run.erase("gathering")
	if version == 1:
		legacy.run.erase("intro_step")
	if not legacy.run.combat.is_empty():
		if version < 5:
			legacy.run.combat.erase("enemy_dots")
		if version < 4:
			for cast: Dictionary in legacy.run.combat.casts.values():
				cast.erase("resolve_seconds")
	if version < 3 and not legacy.world.is_empty():
		for arena: Dictionary in legacy.world.arenas.values():
			for tile: Array in arena.ground.dug:
				tile.resize(2)
			for pool: Dictionary in arena.pools:
				pool.erase("caster_id")
	return legacy


func _check_hazard_contract(saved: Dictionary) -> void:
	for field: String in ["ground", "pool"]:
		for owner: Variant in ["hero:999", "hero:0", "hero:1" if field == "ground" else "hero:2", 1, null, {}]:
			var corrupt := saved.duplicate(true)
			if field == "ground":
				corrupt.world.arenas.guild_house.ground.dug[0][2] = owner
			else:
				corrupt.world.arenas.guild_house.pools[0].caster_id = owner
			check(not CODEC.validate(corrupt).is_empty(), "Reject unknown, wrong-class or malformed %s owner: %s" % [field, str(owner)])
	var unknown := _unknown_hazard_owners(saved)
	check(CODEC.validate(unknown).is_empty(), "Unknown hazard ownership is explicit and valid")
	for version: int in [1, 2]:
		var legacy := _legacy_payload(saved, version)
		var before: String = JSON.stringify(legacy, "", true, true)
		var migrated: Dictionary = ArenicSaveMigrations.upgrade(JSON.parse_string(before))
		check(migrated.ok and migrated.payload.schema_version == CODEC.SCHEMA_VERSION, "Released schema %d upgrades through current schema %d" % [version, CODEC.SCHEMA_VERSION])
		check(migrated.ok and _json_values(migrated.payload) == _json_values(unknown), "Schema %d preserves every field and marks lost ownership unknown" % version)
		check(JSON.stringify(legacy, "", true, true) == before, "Schema %d migration leaves original input untouched" % version)
		for mutation: String in ["extra_pool", "extra_ground", "future_pool_owner", "future_tile_owner", "bad_debt", "oversized_tiles"]:
			var bad := legacy.duplicate(true)
			match mutation:
				"extra_pool": bad.world.arenas.guild_house.pools[0].unexpected = true
				"extra_ground": bad.world.arenas.guild_house.ground.unexpected = true
				"future_pool_owner": bad.world.arenas.guild_house.pools[0].caster_id = "hero:1"
				"future_tile_owner": bad.world.arenas.guild_house.ground.dug[0].append("hero:2")
				"bad_debt": bad.world.arenas.guild_house.ground.dug[0][1] = -1
				"oversized_tiles": bad.world.arenas.guild_house.ground.dug.resize(ArenicDigField.CELLS + 1)
			check(not ArenicSaveMigrations.upgrade(bad).ok, "Schema %d rejects %s without hiding invalid historical state" % [version, mutation])


func _json_values(value: Dictionary) -> String:
	# Migration introduces exact integer fields into JSON-decoded float values.
	# Normalize both through JSON once so only representation-equivalent numbers
	# compare equal; every dictionary key, array order, string and value remains.
	return JSON.stringify(JSON.parse_string(JSON.stringify(value, "", true, true)), "", true, true)


func _cast_fixture(class_id: String) -> RunFixture:
	var run := RunFixture.new()
	var hero := ArenicHeroState.new()
	hero.identity_id = 0
	hero.definition = CODEC._class_for(class_id)
	hero.cell = Vector2i(30, 15)
	hero.selected = true
	run.heroes.append(hero)
	run.selected_class = hero.definition
	run.selected_identity = 0
	run._next_identity = 1
	run.intro_step = CODEC.INTRO_COMPLETE
	run.arena_selection.guild_house = 0
	run.get_combat().configure(CODEC.WORLD)
	run.combat.sync_allies(run.heroes)
	run.combat.register_enemy("guild_house", "fixture", Rect2i(35, 15, 1, 1))
	return run


func _check_projectile_contract() -> void:
	for elapsed: float in [0.1, 0.3]:
		var run := _cast_fixture("hunter")
		check(run.combat.try_cast(run.heroes[0]).is_empty(), "Real Auto Shot is accepted for persistence fixture")
		run.combat.tick(elapsed)
		var saved: Dictionary = CODEC.capture_run(run)
		var cast: Dictionary = saved.run.combat.casts["hero:0"]
		check(is_equal_approx(cast.resolve_seconds, 0.26 + 5.0 / 16.0), "Accepted shot freezes windup plus distance-based flight")
		var resumed := RunFixture.new()
		check(CODEC.restore_run(JSON.parse_string(JSON.stringify(saved)), resumed), "Auto Shot restores before and after release")
		check(_json_values(CODEC.capture_run(resumed)) == _json_values(saved), "All active projectile fields survive JSON exactly")
		var remaining: float = run.combat.active_remaining(run.heroes[0])
		for model: ArenicCombatState in [run.combat, resumed.combat]:
			model.tick(remaining - 0.00001)
			check(model.total_damage() == 0, "Original/restored projectile does not hit before frozen arrival")
			model.tick(0.00001)
			check(model.total_damage() == 1 and model.casting_ids().is_empty(), "Original/restored projectile hits once at frozen arrival")
		var legacy := _legacy_payload(saved, 3)
		var before: String = _json_values(legacy)
		var migrated: Dictionary = ArenicSaveMigrations.upgrade(legacy)
		check(migrated.ok and is_equal_approx(migrated.payload.run.combat.casts["hero:0"].resolve_seconds, 0.75), "Schema 3 Auto Shot keeps its original fixed 0.75-second arrival")
		check(_json_values(legacy) == before, "Projectile migration never mutates the old record")
		var expected := saved.duplicate(true)
		expected.run.combat.casts["hero:0"].resolve_seconds = 0.75
		check(migrated.ok and _json_values(migrated.payload) == _json_values(expected), "Schema 3 migration changes only schema and the new frozen arrival")
		var old_run := RunFixture.new()
		check(migrated.ok and CODEC.restore_run(migrated.payload, old_run), "Legacy in-flight shot hydrates through the current codec")
		old_run.combat.tick(0.75 - elapsed - 0.00001)
		check(old_run.combat.total_damage() == 0, "Legacy shot remains pending until its original arrival")
		old_run.combat.tick(0.00001)
		check(old_run.combat.total_damage() == 1, "Legacy shot resolves exactly once at its original arrival")
		for value: Variant in [-1, INF, NAN, "0.75", null, {}, 86401.0, 0.01]:
			var invalid := saved.duplicate(true)
			invalid.run.combat.casts["hero:0"].resolve_seconds = value
			check(not CODEC.validate(invalid).is_empty(), "Invalid arrival rejects safely: " + str(value))
		for mutation: String in ["new_field", "bad_elapsed", "foreign_owner", "extra_field"]:
			var invalid := legacy.duplicate(true)
			match mutation:
				"new_field": invalid.run.combat.casts["hero:0"].resolve_seconds = 0.75
				"bad_elapsed": invalid.run.combat.casts["hero:0"].elapsed = 1.0
				"foreign_owner": invalid.run.combat.casts["hero:0"].owner = 999
				"extra_field": invalid.run.combat.casts["hero:0"].unexpected = true
			check(not ArenicSaveMigrations.upgrade(invalid).ok, "Schema 3 rejects malformed cast: " + mutation)
		for object: Node in [run, resumed, old_run]:
			object.free()
	var held := _cast_fixture("cardinal")
	check(held.combat.try_cast(held.heroes[0]).is_empty(), "Held-channel persistence fixture starts normally")
	held.combat._casts["hero:0"].elapsed = 100000.0
	var saved_held: Dictionary = CODEC.capture_run(held)
	check(saved_held.run.combat.casts["hero:0"].resolve_seconds == 0.0 and CODEC.validate(saved_held).is_empty(), "Indefinite channels retain zero duration and unbounded-by-duration elapsed")
	held.free()


func _check_released_timing_catalog_edits() -> void:
	for class_id: String in ["hunter", "merchant"]:
		var run := _cast_fixture(class_id)
		check(run.combat.try_cast(run.heroes[0]).is_empty(), "Catalog-edit migration fixture accepts " + class_id)
		var legacy: Dictionary = _legacy_payload(CODEC.capture_run(run), 3)
		var ability: ArenicClassAbility = run.heroes[0].definition.skills[0]
		var previous_cast: float = ability.cast_seconds
		var previous_duration: float = ability.duration_seconds
		# A future editor change must affect new casts without rewriting history.
		ability.cast_seconds = 9.0
		ability.duration_seconds = 37.0
		var migrated: Dictionary = ArenicSaveMigrations.upgrade(legacy)
		ability.cast_seconds = previous_cast
		ability.duration_seconds = previous_duration
		var released: float = 0.75 if class_id == "hunter" else 20.0
		check(migrated.ok and is_equal_approx(migrated.payload.run.combat.casts["hero:0"].resolve_seconds, released),
			"Legacy %s arrival ignores edits to current cast and duration resources" % class_id)
		run.free()


func _check_enemy_dot_contract() -> void:
	var run := _cast_fixture("bard")
	for class_id: String in ["bard", "hunter"]:
		var member := ArenicHeroState.new()
		member.identity_id = run.heroes.size()
		member.definition = CODEC._class_for(class_id)
		member.cell = Vector2i(30, 15 + member.identity_id)
		run.heroes.append(member)
	run._next_identity = run.heroes.size()
	run.combat.sync_allies(run.heroes)
	run.combat.register_enemy("guild_house", "fixture", Rect2i(31, 15, 1, 1))
	check(run.combat.try_cast(run.heroes[0]).is_empty(), "First real Cleanse accepts a persistent enemy stack")
	for tick: int in 41:
		run.combat.advance_enemy_dots("guild_house")
	check(run.combat.try_cast(run.heroes[1]).is_empty(), "Second Bard adds an independent Cleanse stack")
	for tick: int in 18:
		run.combat.advance_enemy_dots("guild_house")
	var saved: Dictionary = CODEC.capture_run(run)
	check(CODEC.validate(saved).is_empty(), "Partway-through-two-stacks snapshot is valid")
	check(saved.run.combat.enemy_dots == [
		{"caster_id": "hero:0", "ability_id": "cleanse", "arena": "guild_house", "enemy_id": "fixture", "remaining_ticks": 241, "interval_ticks": 60, "tick_debt": 59, "damage": 1},
		{"caster_id": "hero:1", "ability_id": "cleanse", "arena": "guild_house", "enemy_id": "fixture", "remaining_ticks": 282, "interval_ticks": 60, "tick_debt": 18, "damage": 1}],
		"Capture preserves stack order, source, target, accepted timing and independent debt")
	var resumed := RunFixture.new()
	var ability: ArenicClassAbility = run.heroes[0].definition.skills[0]
	var duration: float = ability.enemy_dot_duration_seconds
	var interval: float = ability.enemy_dot_tick_seconds
	var damage: int = ability.enemy_dot_damage
	ability.enemy_dot_duration_seconds = 9.0
	ability.enemy_dot_tick_seconds = 0.5
	ability.enemy_dot_damage = 7
	var restored: bool = CODEC.restore_run(JSON.parse_string(JSON.stringify(saved)), resumed)
	ability.enemy_dot_duration_seconds = duration
	ability.enemy_dot_tick_seconds = interval
	ability.enemy_dot_damage = damage
	check(restored and _json_values(CODEC.capture_run(resumed)) == _json_values(saved),
		"JSON restore retains accepted stack values despite later Inspector changes")
	var original_reports: Array = []
	var resumed_reports: Array = []
	run.combat.damage_reported.connect(func(caster: String, attack: String, arena: String, enemy: String, amount: int) -> void: original_reports.append([caster, attack, arena, enemy, amount]))
	resumed.combat.damage_reported.connect(func(caster: String, attack: String, arena: String, enemy: String, amount: int) -> void: resumed_reports.append([caster, attack, arena, enemy, amount]))
	check(run.combat.total_damage() == 2 and resumed.combat.total_damage() == 2,
		"Hydration neither repeats Cleanse's immediate hits nor advances its first DOT tick")
	for elapsed: int in range(1, 284):
		run.combat.advance_enemy_dots("guild_house")
		resumed.combat.advance_enemy_dots("guild_house")
		if elapsed == 1:
			check(resumed_reports == [["hero:0", "cleanse", "guild_house", "fixture", 1]],
				"Only the first caster's saved due tick fires after one arena tick")
		if elapsed == 240:
			check(resumed.combat._enemy_dots.size() == 2, "Both staggered stacks survive until the first exact expiry")
		if elapsed == 241:
			check(resumed.combat._enemy_dots.size() == 1 and resumed.combat._enemy_dots[0].caster_id == "hero:1",
				"The first stack applies its endpoint tick then expires without refreshing the second")
		if elapsed == 282:
			check(resumed.combat._enemy_dots.is_empty() and resumed_reports.size() == 10,
				"The second stack independently applies its last tick and expires")
	check(original_reports == resumed_reports and original_reports.size() == 10,
		"Original and restored stacks produce identical ordered source observations")
	check(_json_values(CODEC.capture_run(run)) == _json_values(CODEC.capture_run(resumed)) and resumed.combat.total_damage() == 12,
		"Simulation stays identical through both expiries and produces no post-expiry hit")

	var mutations: Dictionary = {
		"caster_id": ["", "hero:999", "hero:2", 1, {}, null],
		"ability_id": ["heal", "auto_shot", "", {}, 1, null],
		"arena": ["missing", "labyrinth", 1, {}, null],
		"enemy_id": ["missing", "", 1, {}, null],
		"remaining_ticks": [0, -1, 7201, 1.5, "1", true, INF, NAN],
		"interval_ticks": [0, 2, 601, 60.5, "60", false, INF, NAN],
		"tick_debt": [-1, 60, 0.5, "0", true, INF, NAN],
		"damage": [0, 101, 1.5, "1", false, INF, NAN],
	}
	for field: String in mutations:
		for value: Variant in mutations[field]:
			var invalid: Dictionary = saved.duplicate(true)
			invalid.run.combat.enemy_dots[0][field] = value
			check(not CODEC.validate(invalid).is_empty(), "Invalid DOT %s rejects safely: %s" % [field, str(value)])
	for collection: Variant in [null, {}, [null], [{"caster_id": "hero:0"}]]:
		var invalid: Dictionary = saved.duplicate(true)
		invalid.run.combat.enemy_dots = collection
		check(not CODEC.validate(invalid).is_empty(), "Malformed DOT collection fails before hydration")
	var capacity: Dictionary = saved.duplicate(true)
	capacity.run.combat.enemy_dots.resize(CODEC.MAX_ENEMY_DOTS)
	capacity.run.combat.enemy_dots.fill(saved.run.combat.enemy_dots[0])
	check(CODEC.validate(capacity).is_empty(), "The declared 6,400-stack save capacity remains representable")
	capacity.run.combat.enemy_dots.append(saved.run.combat.enemy_dots[0])
	check(not CODEC.validate(capacity).is_empty(), "An oversized stack array rejects without truncation")
	var extra: Dictionary = saved.duplicate(true)
	extra.run.combat.enemy_dots[0].future_effect = true
	check(not CODEC.restore_run(extra, resumed), "Unknown stack fields reject before replacing a live run")
	check(resumed.combat._enemy_dots.is_empty() and resumed.combat.total_damage() == 12,
		"Failed DOT restoration leaves the existing live combat untouched")
	for version: int in [1, 2, 3, 4]:
		var legacy: Dictionary = _legacy_payload(saved, version)
		var before: String = _json_values(legacy)
		var migrated: Dictionary = ArenicSaveMigrations.upgrade(legacy)
		var expected: Dictionary = saved.duplicate(true)
		expected.run.combat.enemy_dots = []
		check(migrated.ok and _json_values(migrated.payload) == _json_values(expected),
			"Schema %d upgrades without inventing retroactive DOTs or changing old damage" % version)
		check(_json_values(legacy) == before, "Schema %d migration preserves its complete input" % version)
		legacy.run.combat.enemy_dots = []
		check(not ArenicSaveMigrations.upgrade(legacy).ok, "Schema %d cannot smuggle a future DOT field" % version)
	for boundary: int in [2, 3, 4]:
		var historical: Dictionary = ArenicSaveMigrations.upgrade(_legacy_payload(saved, 1), boundary)
		check(historical.ok and historical.payload.schema_version == boundary,
			"Historical migration target %d still validates through the latest complete contract" % boundary)
	var future: Dictionary = saved.duplicate(true)
	future.schema_version = CODEC.SCHEMA_VERSION + 1
	var future_before: String = _json_values(future)
	check(not ArenicSaveMigrations.upgrade(future).ok and _json_values(future) == future_before,
		"Unknown future DOT schemas remain preserved and unsupported")
	run.free()
	resumed.free()


func _check_clearing_gathering_compatibility() -> void:
	var run := _cast_fixture("hunter")
	var state: ArenicGatheringState = run.get_gathering()
	var indoor_rules := state.definition.duplicate(true) as ArenicGatheringDefinition
	indoor_rules.gold_sources = [Vector2i(53, 9), Vector2i(53, 23)]
	state.configure(indoor_rules)
	run.heroes[0].cell = Vector2i(53, 9)
	run.combat.sync_allies(run.heroes)
	for tick: int in 157:
		state.advance(run.heroes, run.combat)
	state.wood_total = 9007199254740993
	state.gold_total = 37
	var saved: Dictionary = CODEC.capture_run(run)
	check(saved.schema_version == CODEC.SCHEMA_VERSION and CODEC.validate(saved).is_empty(), "A bag at the old mine remains a valid current save")
	var resumed := RunFixture.new()
	check(CODEC.restore_run(JSON.parse_string(JSON.stringify(saved)), resumed), "Schema6 restores existing progress directly after mine geometry changes")
	check(resumed.gathering.definition.gold_sources == [Vector2i(7, 24), Vector2i(56, 7)], "Restored runs use the current authored outdoor mine positions")
	check(_json_values(CODEC._gathering(resumed.gathering)) == _json_values(saved.run.gathering) and resumed.heroes[0].cell == Vector2i(53, 9), "Geometry reauthoring preserves exact banks, frozen bag rules and the hero's saved position")
	resumed.gathering.advance(resumed.heroes, resumed.combat)
	check(resumed.gathering.snapshot_for(resumed.heroes[0]).fill_ticks == 157 and resumed.gathering.snapshot_for(resumed.heroes[0]).phase == "carrying", "An old mine cell stops gathering without discarding or silently filling its partial bag")
	resumed.heroes[0].cell = resumed.gathering.definition.gold_sources[0]
	resumed.combat.sync_allies(resumed.heroes)
	for tick: int in 142:
		resumed.gathering.advance(resumed.heroes, resumed.combat)
	check(resumed.gathering.snapshot_for(resumed.heroes[0]).fill_ticks == 299, "Moving to the new mine resumes only the bag's remaining accepted fill ticks")
	resumed.gathering.advance(resumed.heroes, resumed.combat)
	check(resumed.gathering.snapshot_for(resumed.heroes[0]).phase == "full", "The old bag fills exactly on its original 300th work tick")
	resumed.heroes[0].cell = resumed.gathering.definition.gold_dropoff
	resumed.combat.sync_allies(resumed.heroes)
	for tick: int in 59:
		resumed.gathering.advance(resumed.heroes, resumed.combat)
	check(resumed.gathering.gold_total == 37, "An old bag cannot award its resource before the final unload tick")
	resumed.gathering.advance(resumed.heroes, resumed.combat)
	check(resumed.gathering.gold_total == 47 and resumed.gathering.wood_total == 9007199254740993, "The preserved bag deposits once while unrelated large bank totals remain exact")
	check(CODEC.validate(CODEC.capture_run(resumed)).is_empty(), "The resumed old bag's finished state still satisfies schema 6")
	run.free()
	resumed.free()


func _check_tavern_dropoff_compatibility() -> void:
	var run := _cast_fixture("hunter")
	var second := ArenicHeroState.new()
	second.identity_id = 1
	second.definition = CODEC._class_for("forager")
	second.selected = false
	run.heroes.append(second)
	run._next_identity = 2
	var gathering: ArenicGatheringState = run.get_gathering()
	var old_rules := gathering.definition.duplicate(true) as ArenicGatheringDefinition
	old_rules.wood_dropoff = Vector2i(25, 8)
	old_rules.gold_dropoff = Vector2i(41, 8)
	check(gathering.configure(old_rules), "The previous dropoff layout can construct a genuine pre-change work checkpoint")
	run.heroes[0].cell = old_rules.wood_sources[0]
	second.cell = old_rules.gold_sources[0]
	run.combat.sync_allies(run.heroes)
	for tick: int in 300:
		gathering.advance(run.heroes, run.combat)
	run.heroes[0].cell = old_rules.wood_dropoff
	second.cell = old_rules.gold_dropoff
	run.combat.sync_allies(run.heroes)
	for tick: int in 31:
		gathering.advance([second], run.combat)
	for hero: ArenicHeroState in run.heroes:
		hero.recordings["guild_house"] = ArenicRecording.create(hero.cell, [ArenicTimelineEvent.move(60, Vector2i.RIGHT), ArenicTimelineEvent.move(120, Vector2i.LEFT)])
	gathering.wood_total = 9007199254740993
	gathering.gold_total = 37
	var saved: Dictionary = CODEC.capture_run(run)
	check(saved.schema_version == CODEC.SCHEMA_VERSION and CODEC.validate(saved).is_empty(), "Full and partly unloaded bags at old dropoffs remain valid without position migration")
	check(saved.run.gathering.bags[0].fill_ticks == 300 and saved.run.gathering.bags[0].unload_ticks == 0 and saved.run.gathering.bags[1].fill_ticks == 300 and saved.run.gathering.bags[1].unload_ticks == 31, "The checkpoint contains a full wood bag and the gold bag's exact 31 of 60 unload ticks")
	var resumed := RunFixture.new()
	check(CODEC.restore_run(JSON.parse_string(JSON.stringify(saved)), resumed), "Existing dropoff progress restores directly through the shared JSON codec")
	if resumed.gathering == null:
		run.free()
		resumed.free()
		return
	check(resumed.gathering.definition.wood_dropoff == Vector2i(23, 21) and resumed.gathering.definition.gold_dropoff == Vector2i(42, 21), "Restored gathering uses the current left and right tavern dropoffs")
	check(_json_values(CODEC.capture_run(resumed)) == _json_values(saved), "Restore preserves all bank and bag counters, hero positions and cached recorded routes before simulation resumes")
	var events: Array[Dictionary] = resumed.gathering.advance(resumed.heroes, resumed.combat)
	check(events.is_empty() and resumed.gathering.snapshot_for(resumed.heroes[0]).unload_ticks == 0 and resumed.gathering.snapshot_for(resumed.heroes[1]).unload_ticks == 0, "The first resumed tick stops old-site unloading without generating a deposit")
	for tick: int in 60:
		events.append_array(resumed.gathering.advance(resumed.heroes, resumed.combat))
	check(events.is_empty() and resumed.gathering.wood_total == 9007199254740993 and resumed.gathering.gold_total == 37, "Remaining at either old dropoff cannot credit banked resources")
	check(resumed.gathering.snapshot_for(resumed.heroes[0]).fill_ticks == 300 and resumed.gathering.snapshot_for(resumed.heroes[1]).fill_ticks == 300 and resumed.heroes[0].cell == old_rules.wood_dropoff and resumed.heroes[1].cell == old_rules.gold_dropoff, "Stopping old-site work retains both full bags and the original hero positions")
	var stopped: Dictionary = CODEC.capture_run(resumed)
	check(_json_values({"heroes": stopped.run.heroes}) == _json_values({"heroes": saved.run.heroes}) and CODEC.validate(stopped).is_empty(), "Derived dropoff changes never rewrite saved movement routes or require an invalid intermediate checkpoint")
	resumed.heroes[0].cell = resumed.gathering.definition.wood_dropoff
	resumed.heroes[1].cell = resumed.gathering.definition.gold_dropoff
	resumed.combat.sync_allies(resumed.heroes)
	for tick: int in 59:
		events.append_array(resumed.gathering.advance(resumed.heroes, resumed.combat))
	check(events.is_empty() and resumed.gathering.snapshot_for(resumed.heroes[0]).unload_ticks == 59 and resumed.gathering.snapshot_for(resumed.heroes[1]).unload_ticks == 59, "Carrying to the new dropoffs requires a complete uninterrupted unload under each bag's frozen duration")
	events.append_array(resumed.gathering.advance(resumed.heroes, resumed.combat))
	check(events == [{"kind": "deposited", "hero_id": 0, "resource": "wood", "amount": 10}, {"kind": "deposited", "hero_id": 1, "resource": "gold", "amount": 10}], "Both preserved bags deposit once on the exact final tick with their original identity and amount")
	check(resumed.gathering.wood_total == 9007199254741003 and resumed.gathering.gold_total == 47 and resumed.gathering._bags.is_empty(), "New-site deposits preserve exact 64-bit banks and clear only the delivered bags")
	for tick: int in 120:
		events.append_array(resumed.gathering.advance(resumed.heroes, resumed.combat))
	check(events.size() == 2 and resumed.gathering.wood_total == 9007199254741003 and resumed.gathering.gold_total == 47, "Empty heroes cannot repeat a delivery after the dropoff relocation")
	check(CODEC.validate(CODEC.capture_run(resumed)).is_empty(), "The completed relocation scenario still satisfies the unchanged schema 6")
	run.free()
	resumed.free()


func _check_restart_pending_contract() -> void:
	var run := _cast_fixture("hunter")
	var remote := ArenicHeroState.new()
	remote.identity_id = 1
	remote.definition = CODEC._class_for("hunter")
	remote.selected = false
	remote.arena_id = "sanctum"
	remote.cell = Vector2i(30, 15)
	run.heroes.append(remote)
	run._next_identity = 2
	run.combat.sync_allies(run.heroes)
	run.combat.register_enemy("sanctum", "fixture", Rect2i(35, 15, 1, 1))
	var shell := ShellFixture.new()
	shell.configure(run)
	run.get_gathering().wood_total = 9007199254740993
	run.gathering.gold_total = 37
	run.combat.apply_hazard_damage("guild_house", "fixture", 17)
	check(run.combat.try_cast(run.heroes[0]).is_empty() and run.combat.try_cast(remote).is_empty(), "Real free-hero projectiles begin in two independent arenas")
	run.combat.tick(0.1)
	var cooldown: float = run.combat.cooldown_remaining(run.heroes[0])
	var cast_before: Dictionary = run.combat.active_cast_snapshot(run.heroes[0])
	check(shell.encounter.set_restart_pending("guild_house", true) and shell.encounter.is_paused("guild_house") and not shell.encounter._clocks.guild_house.paused, "Restart waiting holds cycle zero independently of the modal/recording pause flag")
	shell.encounter.set_paused("guild_house", true)
	shell.encounter.set_restart_pending("guild_house", false)
	check(shell.encounter.is_paused("guild_house"), "Completing a restart cannot release an independently owned decision pause")
	shell.encounter.set_restart_pending("guild_house", true)
	shell.encounter.set_paused("guild_house", false)
	check(shell.encounter.is_paused("guild_house"), "Closing a decision cannot release a pending restart")
	for tick: int in 120:
		shell.encounter.tick(run.combat, 1, {}, run.combat.tick.bind(1.0 / 60.0))
	check(shell.encounter.cycle_position("guild_house") == 0 and shell.encounter.cycle_position("sanctum") == 120, "Only the pending arena holds while other arena clocks advance")
	check(run.combat.active_cast_snapshot(run.heroes[0]) == cast_before and run.combat.cooldown_remaining(run.heroes[0]) == cooldown, "A pending arena freezes the free caster's complete shot and cooldown, not just its score")
	check(run.combat.damage_for_arena("guild_house") == 17 and run.combat.damage_for_arena("sanctum") == 1, "Frozen shots cannot deal damage while a remote projectile still resolves once")
	var saved: Dictionary = CODEC.capture_run(run, shell)
	check(saved.schema_version == CODEC.SCHEMA_VERSION and saved.world.arenas.guild_house.restart_pending and not saved.world.arenas.guild_house.paused and CODEC.validate(saved).is_empty(), "The explicit schema7 continuation bit saves without forging a decision or recording countdown")
	var restored := RunFixture.new()
	check(CODEC.restore_run(JSON.parse_string(JSON.stringify(saved, "", true, true)), restored), "Pending restart run state survives actual JSON decoding")
	var restored_shell := ShellFixture.new()
	restored_shell.configure(restored)
	check(CODEC.restore_shell(JSON.parse_string(JSON.stringify(saved, "", true, true)), restored_shell), "Pending restart world state restores before simulation resumes")
	check(_json_values(CODEC.capture_run(restored, restored_shell)) == _json_values(saved), "Hydration preserves all accepted ledgers, banks, timers and canonical cycle-zero state without another reset")
	var ground_cycle: int = restored_shell.encounter.dig_field("guild_house").cycle
	restored_shell.encounter.tick(restored.combat, 1, {}, restored.combat.tick.bind(1.0 / 60.0))
	check(restored_shell.encounter.cycle_position("guild_house") == 0 and restored.combat.active_cast_snapshot(restored.heroes[0]) == cast_before, "Restored pending state remains inert until the transient countdown explicitly releases it")
	restored_shell.encounter.set_restart_pending("guild_house", false)
	for tick: int in 60:
		restored_shell.encounter.tick(restored.combat, 1, {}, restored.combat.tick.bind(1.0 / 60.0))
	check(restored.combat.damage_for_arena("guild_house") == 18 and restored.combat.active_cast_snapshot(restored.heroes[0]).is_empty(), "After release the preserved projectile finishes once from its frozen elapsed time")
	check(restored_shell.encounter.dig_field("guild_house").cycle == ground_cycle and restored.gathering.wood_total == 9007199254740993 and restored.gathering.gold_total == 37, "Countdown completion never repeats the reset or changes cumulative resource banks")
	check(not restored_shell.encounter.set_restart_pending("guild_house", true), "A pending restart cannot be introduced at a nonzero simulation tick")
	for invalid: Variant in [null, 1, 0.0, "true", [], {}]:
		var bad: Dictionary = saved.duplicate(true)
		bad.world.arenas.guild_house.restart_pending = invalid
		check(not CODEC.validate(bad).is_empty(), "Restart continuation accepts only a real boolean")
	var bad: Dictionary = saved.duplicate(true)
	bad.world.arenas.guild_house.tick = 1
	check(not CODEC.validate(bad).is_empty(), "A saved restart cannot hold a noncanonical cycle tick")
	bad = saved.duplicate(true)
	bad.world.arenas.guild_house.history = []
	check(not CODEC.validate(bad).is_empty(), "Transient rewind history cannot enter the durable arena record")
	bad = saved.duplicate(true)
	bad.world.session = {"state": ArenicRecordingSession.State.COUNTDOWN, "countdown_left": 180, "identity": 0, "arena_id": "guild_house", "start_cell": [30, 15], "events": []}
	bad.world.arenas.guild_house.paused = true
	check(not CODEC.validate(bad).is_empty(), "Recording and replay countdowns cannot double-own one arena")
	bad.world.session.identity = 1
	bad.world.session.arena_id = "sanctum"
	bad.world.arenas.guild_house.paused = false
	bad.world.arenas.sanctum.paused = true
	bad.world.arenas.sanctum.tick = 0
	check(CODEC.validate(bad).is_empty(), "Another arena's recording countdown remains independent of a pending replay")
	var legacy: Dictionary = _legacy_payload(saved, 6)
	var source_before: String = _json_values(legacy)
	var expected: Dictionary = saved.duplicate(true)
	expected.world.arenas.guild_house.restart_pending = false
	expected.run.loot.arenas.sanctum.baseline = "1" # Existing remote damage is not retroactive loot.
	var migrated: Dictionary = ArenicSaveMigrations.upgrade(legacy)
	check(migrated.ok and _json_values(migrated.payload) == _json_values(expected), "Schema6 retains every field and adds false without inferring a countdown from tick zero")
	check(_json_values(legacy) == source_before, "The schema6 source remains unchanged by migration")
	legacy.world.arenas.guild_house.restart_pending = false
	check(not ArenicSaveMigrations.upgrade(legacy).ok, "A schema6 record cannot smuggle the future restart field")
	legacy = _legacy_payload(saved, 6)
	legacy.world.arenas.guild_house.tick = -1
	check(not ArenicSaveMigrations.upgrade(legacy).ok, "Schema6 migration still validates original malformed clock fields")
	_check_restart_signals(run, shell)
	restored_shell.free()
	restored.free()
	shell.free()
	run.free()


func _check_restart_signals(run: RunFixture, shell: ShellFixture) -> void:
	var observed: Array[Dictionary] = []
	var conductor: ArenicEncounterState = shell.encounter
	var reference: WeakRef = weakref(conductor)
	conductor.arena_restarting.connect(func(arena_id: String, end_tick: int, rewind: bool):
		var active: ArenicEncounterState = reference.get_ref()
		observed.append({"arena": arena_id, "end": end_tick, "tick": active.cycle_position(arena_id), "rewind": rewind}))
	conductor.set_restart_pending("guild_house", false)
	conductor.seek("guild_house", 123)
	conductor.restart("guild_house", false)
	check(observed == [{"arena": "guild_house", "end": 123, "tick": 123, "rewind": false}] and conductor.cycle_position("guild_house") == 0, "Recording setup announces its pre-reset position with rewind=false before seeking zero")
	observed.clear()
	conductor.seek("guild_house", ArenicCycleClock.CYCLE_TICKS - 1)
	conductor.tick(run.combat)
	check(observed == [{"arena": "guild_house", "end": 7200, "tick": 7199, "rewind": false}] and conductor.cycle_position("guild_house") == 0, "An unrecorded clearing announces its full duration and resets once without a cosmetic hold")


func _check_gathering_contract() -> void:
	var run := _cast_fixture("hunter")
	for class_id: String in ["bard", "forager"]:
		var member := ArenicHeroState.new()
		member.identity_id = run.heroes.size()
		member.definition = CODEC._class_for(class_id)
		member.selected = false
		run.heroes.append(member)
	run._next_identity = run.heroes.size()
	var gathering: ArenicGatheringState = run.get_gathering()
	run.heroes[0].cell = gathering.definition.wood_sources[0]
	run.heroes[1].cell = gathering.definition.gold_sources[0]
	run.heroes[2].cell = gathering.definition.wood_sources[1]
	run.combat.sync_allies(run.heroes)
	for tick: int in 300:
		gathering.advance([run.heroes[1], run.heroes[2]], run.combat)
	for tick: int in 150:
		gathering.advance([run.heroes[0]], run.combat)
	run.heroes[1].cell = gathering.definition.gold_dropoff
	run.combat.sync_allies(run.heroes)
	for tick: int in 30:
		gathering.advance([run.heroes[1]], run.combat)
	gathering.wood_total = 9007199254740993
	gathering.gold_total = ArenicGatheringState.MAX_TOTAL - 50
	var saved: Dictionary = CODEC.capture_run(run)
	check(CODEC.validate(saved).is_empty(), "Partial, full and half-unloaded bags form a valid checkpoint")
	check(saved.run.gathering.wood_total == "9007199254740993" and saved.run.gathering.gold_total == "9223372036854775757", "Both gathering banks encode exact signed-64-bit decimal totals")
	check(saved.run.gathering.bags.size() == 3 and saved.run.gathering.bags[0].fill_ticks == 150 and saved.run.gathering.bags[1].unload_ticks == 30 and saved.run.gathering.bags[2].fill_ticks == 300, "Capture preserves partial fill, active unloading and full carry independently")
	var resumed := RunFixture.new()
	check(CODEC.restore_run(JSON.parse_string(JSON.stringify(saved)), resumed), "Gathering checkpoint restores through actual JSON decoding")
	if resumed.gathering == null:
		run.free()
		resumed.free()
		return
	check(_json_values(CODEC.capture_run(resumed)) == _json_values(saved), "All bag fields and exact banks round-trip without replaying a deposit")
	var new_rules := gathering.definition.duplicate(true) as ArenicGatheringDefinition
	new_rules.fill_seconds = 1.0
	new_rules.unload_seconds = 2.0
	new_rules.capacity_units = 20
	resumed.gathering.configure(new_rules)
	var original_events: Array[Dictionary] = []
	var resumed_events: Array[Dictionary] = []
	var same_ticks: bool = true
	for elapsed: int in range(1, 151):
		original_events.append_array(gathering.advance(run.heroes, run.combat))
		resumed_events.append_array(resumed.gathering.advance(resumed.heroes, resumed.combat))
		same_ticks = same_ticks and original_events == resumed_events and _json_values(CODEC._gathering(gathering)) == _json_values(CODEC._gathering(resumed.gathering))
		if elapsed == 29:
			check(resumed_events.is_empty(), "Restored half-unload does not deposit before its remaining 30 ticks")
		if elapsed == 30:
			check(resumed_events == [{"kind": "deposited", "hero_id": 1, "resource": "gold", "amount": 10}], "The exact remaining unload tick deposits once under the bag's frozen original rules")
		if elapsed == 149:
			check(resumed.gathering.snapshot_for(resumed.heroes[0]).fill_ticks == 299, "A partial bag resumes with exactly its saved remaining fill time")
	check(same_ticks and resumed.gathering.snapshot_for(resumed.heroes[0]).phase == "full", "Original and restored bags remain identical on every future tick despite new authored rules")
	for identity: int in [0, 2]:
		run.heroes[identity].cell = gathering.definition.wood_dropoff + Vector2i(1 if identity == 2 else 0, 0)
		resumed.heroes[identity].cell = run.heroes[identity].cell
	run.combat.sync_allies(run.heroes)
	resumed.combat.sync_allies(resumed.heroes)
	for tick: int in 60:
		original_events.append_array(gathering.advance(run.heroes, run.combat))
		resumed_events.append_array(resumed.gathering.advance(resumed.heroes, resumed.combat))
	check(original_events == resumed_events and resumed_events.size() == 3 and gathering.wood_total == 9007199254741013 and resumed.gathering.wood_total == gathering.wood_total, "Both full bags deposit the same exact amounts and stable source identities after restore")
	check(_json_values(CODEC.capture_run(run)) == _json_values(CODEC.capture_run(resumed)), "Complete run snapshots still match after all restored bags finish")
	var mutations: Dictionary = {
		"hero_id": [-1, 319, 320, 0.5, "0", true, null],
		"kind": ["", "stone", 1, {}, null],
		"fill_ticks": [0, -1, 301, 0.5, "1", true, INF, NAN],
		"fill_duration_ticks": [0, 7201, 1.5, "300", null],
		"unload_ticks": [-1, 1, 60, 0.5, "0", false],
		"unload_duration_ticks": [0, 601, 1.5, "60", null],
		"capacity_units": [0, 1001, 1.5, "10", null],
	}
	for field: String in mutations:
		for value: Variant in mutations[field]:
			var bad: Dictionary = saved.duplicate(true)
			bad.run.gathering.bags[0][field] = value
			check(not CODEC.validate(bad).is_empty(), "Invalid gathering %s fails before hydration: %s" % [field, str(value)])
	for total: Variant in ["-1", "9223372036854775808", "1.5", 1, INF, null]:
		var bad: Dictionary = saved.duplicate(true)
		bad.run.gathering.gold_total = total
		check(not CODEC.validate(bad).is_empty(), "Malformed or overflowing gathering bank rejects safely")
	for collection: Variant in [null, {}, [null], [saved.run.gathering.bags[0], saved.run.gathering.bags[0]]]:
		var bad: Dictionary = saved.duplicate(true)
		bad.run.gathering.bags = collection
		check(not CODEC.validate(bad).is_empty(), "Malformed or duplicate bag owners reject safely")
	var bad: Dictionary = saved.duplicate(true)
	bad.run.gathering.bags.resize(321)
	check(not CODEC.validate(bad).is_empty(), "Oversized gathering bags reject without truncation")
	bad = saved.duplicate(true)
	bad.run.combat.arenas.guild_house.allies["hero:0"].health = "0"
	check(not CODEC.validate(bad).is_empty(), "A defeated hero cannot restore carried resources")
	bad = saved.duplicate(true)
	bad.run.gathering.bags[0].phase = "gathering"
	var untouched: String = _json_values(CODEC.capture_run(resumed))
	check(not CODEC.restore_run(bad, resumed) and _json_values(CODEC.capture_run(resumed)) == untouched, "Unknown derived bag fields reject without replacing the live run")
	for version: int in range(1, 6):
		var legacy: Dictionary = _legacy_payload(saved, version)
		var before: String = _json_values(legacy)
		var migrated: Dictionary = ArenicSaveMigrations.upgrade(legacy)
		var expected: Dictionary = saved.duplicate(true)
		expected.run.gathering = {"wood_total": "0", "gold_total": "0", "bags": []}
		check(migrated.ok and _json_values(migrated.payload) == _json_values(expected), "Schema %d migrates with empty gathering and preserves existing unrelated progress" % version)
		check(_json_values(legacy) == before, "Gathering migration preserves the schema %d source record" % version)
		legacy.run.gathering = expected.run.gathering
		check(not ArenicSaveMigrations.upgrade(legacy).ok, "Schema %d cannot smuggle a future gathering field" % version)
	var overlap: Dictionary = saved.duplicate(true)
	overlap.run.heroes[1].cell = overlap.run.heroes[0].cell.duplicate()
	overlap.run.combat.arenas.guild_house.allies["hero:1"].cell = overlap.run.heroes[1].cell.duplicate()
	check(not CODEC.validate(overlap).is_empty(), "Current schema rejects living hero overlap instead of accepting an immediate contact death")
	var legacy_overlap: Dictionary = _legacy_payload(overlap, 5)
	var migrated_overlap: Dictionary = ArenicSaveMigrations.upgrade(legacy_overlap)
	check(migrated_overlap.ok and migrated_overlap.payload.run.heroes[0].cell == saved.run.heroes[0].cell and migrated_overlap.payload.run.heroes[1].cell != saved.run.heroes[0].cell, "Old overlapping recruits migrate to distinct cells while retaining the first identity's position")
	check(ArenicSaveMigrations.upgrade(JSON.parse_string(JSON.stringify(legacy_overlap))).ok, "Valid legacy separation accepts whole-number cells from actual JSON float decoding")
	for cell: Variant in [null, {}, [], [12], [12, 9, 0], [-1, 9], [66, 9], [12, 31], [12.5, 9], ["12", 9], [true, 9], [13, 9]]:
		var malformed: Dictionary = legacy_overlap.duplicate(true)
		malformed.run.combat.arenas.guild_house.allies["hero:1"].cell = cell
		var original: String = JSON.stringify(malformed, "", true, true)
		check(not ArenicSaveMigrations.upgrade(malformed).ok, "Legacy separation rejects the later overlapping hero's malformed or mismatched ally cell: " + str(cell))
		check(JSON.stringify(malformed, "", true, true) == original, "Rejected separation preserves the original malformed ally cell")
	var missing_cell: Dictionary = legacy_overlap.duplicate(true)
	missing_cell.run.combat.arenas.guild_house.allies["hero:1"].erase("cell")
	check(not ArenicSaveMigrations.upgrade(missing_cell).ok and not missing_cell.run.combat.arenas.guild_house.allies["hero:1"].has("cell"), "Separation cannot manufacture a missing cell in an existing ally record")
	var missing_ally: Dictionary = legacy_overlap.duplicate(true)
	missing_ally.run.combat.arenas.guild_house.allies.erase("hero:1")
	var migrated_without_ally: Dictionary = ArenicSaveMigrations.upgrade(missing_ally)
	check(migrated_without_ally.ok and migrated_without_ally.payload.run.heroes[1].cell != saved.run.heroes[0].cell, "Separation still supports a legacy hero with no existing ally ledger")
	check(migrated_without_ally.ok and not migrated_without_ally.payload.run.combat.arenas.guild_house.allies.has("hero:1"), "Legacy separation does not invent a new ally ledger where none was present")
	run.free()
	resumed.free()
