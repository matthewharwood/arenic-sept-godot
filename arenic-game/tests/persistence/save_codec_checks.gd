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
	var prospected: int = 0
	var run_seed: int = 1234
	var _next_identity: int = 0
	func begin_new_game() -> void:
		selected_class = null
		heroes.clear()
		selected_identity = -1
		arena_selection.clear()
		combat = null
		recruitment = null
		prospected = 0
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
		combat = run.combat
		encounter.configure(CODEC.WORLD, CODEC.ENCOUNTERS, combat)
		encounter.performer_lookup = func(id: String) -> ArenicHeroState:
			return CODEC._hero_for_ally(heroes, id)
		for arena: ArenicArenaDefinition in CODEC.WORLD.arenas:
			var clock := ArenicArenaMusicClock.new()
			clock.configure(120.0, 12.5)
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
	func _update_hud() -> void:
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
	selection.selection_index = 5
	var empty := RunFixture.new()
	check(CODEC.restore_run(selection, empty), "Pending class selection restores without spawning a hero")
	check(empty.heroes.is_empty(), "Continue preserves unfinished class selection")
	empty.free()
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
	shell.encounter.dig_field("guild_house").dig(Vector2i(35, 15))
	shell.encounter.dig_field("guild_house")._dug[ArenicDigField.index_of(Vector2i(35, 15))] = 479
	shell.encounter.acid_field("guild_house").spawn(Rect2i(34, 14, 3, 3), run.heroes[1].definition.skills[0])
	shell.encounter.acid_field("guild_house")._pools[0].debt = 59
	shell.session.arm(run.heroes[0])
	shell.session.state = ArenicRecordingSession.State.RECORDING
	shell.session.countdown_left = 0
	shell.session.capture(ArenicTimelineEvent.move(30, Vector2i(0, 1)))
	var saved: Dictionary = CODEC.capture_run(run, shell)
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
	for tick: int in 12:
		shell.combat.tick(1.0 / 60.0)
		shell.encounter.tick(shell.combat)
		resumed.combat.tick(1.0 / 60.0)
		resumed.encounter.tick(resumed.combat)
	check(JSON.stringify(CODEC.capture_run(restored, resumed)) == JSON.stringify(CODEC.capture_run(run, shell)), "Restored simulation resolves the same next 12 ticks, including ghost moves and hazard damage")
	var corrupt: Dictionary = saved.duplicate(true)
	corrupt.schema_version = 2
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
