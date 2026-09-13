class_name ArenicSaveCodec
extends RefCounted
## Explicit, value-only persistence boundary. Resources are resolved from the
## trusted catalog; saves never contain paths, objects, scripts, or callables.
## Decimal strings retain signed-64-bit counters through JSON and IndexedDB.
const SCHEMA_VERSION: int = 1
const MAX_HEROES: int = 320
const MAX_STAFF_EVENTS: int = 14400
const MAX_TOTAL_EVENTS: int = 1000000
const MAX_POOLS: int = 6400
const WORLD: ArenicWorldDefinition = preload("res://data/world/arenia.tres")
const CLASSES: ArenicClassCatalog = preload("res://data/classes/catalog.tres")
const ENCOUNTERS: ArenicEncounterCatalog = preload("res://data/encounters/catalog.tres")
const CURVE: ArenicRecruitmentCurve = preload("res://data/guild/recruitment.tres")
const FACES: Array[String] = ["n", "e", "s", "w"]


static func capture_run(run: Node, shell: Node = null) -> Dictionary:
	var roster: Array = []
	for hero: ArenicHeroState in run.heroes:
		var recordings: Dictionary = {}
		for arena: String in hero.recordings:
			recordings[arena] = _staff(hero.recordings[arena])
		roster.append({"identity": hero.identity_id, "class_id": hero.definition.class_id,
			"level": str(hero.level), "experience": str(hero.experience),
			"experience_to_next_level": str(hero.experience_to_next_level),
			"arena_id": hero.arena_id, "cell": _v(hero.cell), "facing": hero.facing, "selected": hero.selected,
			"recordings": recordings})
	var run_data: Dictionary = {"selected_class": run.selected_class.class_id if run.selected_class != null else "",
		"heroes": roster, "selected_identity": run.selected_identity,
		"arena_selection": run.arena_selection.duplicate(), "next_identity": run._next_identity,
		"prospected": str(run.prospected), "seed": run.run_seed, "rolls_claimed": run.recruitment.rolls_claimed if run.recruitment != null else 0,
		"combat": _combat(run.combat) if run.combat != null else {}}
	return {"schema_version": SCHEMA_VERSION, "scene": "class_selection" if run.selected_class == null else "game",
		"selection_index": 0, "run": run_data,
		"world": _world(shell) if shell != null and shell.encounter != null else {}}


static func _staff(recording: ArenicRecording) -> Dictionary:
	return {"start_cell": _v(recording.start_cell), "events": _events(recording.events)}


static func _events(events: Array[ArenicTimelineEvent]) -> Array:
	var result: Array = []
	for event: ArenicTimelineEvent in events:
		result.append({"tick": event.tick, "action": String(event.action_id), "delta": _v(event.delta), "slot": event.slot})
	return result


static func _combat(combat: ArenicCombatState) -> Dictionary:
	var arenas: Dictionary = {}
	for arena_id: String in combat._arenas:
		var arena: Dictionary = combat._arenas[arena_id]
		var enemies: Dictionary = {}
		for enemy_id: String in arena.enemies:
			var enemy: Dictionary = arena.enemies[enemy_id]
			enemies[enemy_id] = {"footprint": _r(enemy.footprint), "facing": enemy.facing, "damage": str(enemy.damage)}
		var allies: Dictionary = {}
		for actor_id: String in arena.allies:
			var ally: Dictionary = arena.allies[actor_id]
			allies[actor_id] = {"cell": _v(ally.cell), "health": str(ally.health), "max_health": str(ally.max_health), "debuffs": Array(ally.debuffs)}
		arenas[arena_id] = {"damage": str(arena.damage), "phase_damage": str(arena.get("phase_damage", 0)), "enemies": enemies, "allies": allies}
	var casts: Dictionary = {}
	for caster_id: String in combat._casts:
		var cast: ArenicCombatState.Cast = combat._casts[caster_id]
		casts[caster_id] = {"owner": cast.owner.identity_id, "ability_id": cast.ability.ability_id,
			"arena": cast.arena, "origin": _v(cast.origin), "facing": cast.facing,
			"target_id": cast.target_id, "target_cell": _v(cast.target_cell), "elapsed": cast.elapsed,
			"tick_debt": cast.tick_debt, "cast_id": str(cast.cast_id), "released": cast.released,
			"release_seconds": cast.release_seconds, "loot_bonus": cast.loot_bonus}
	return {"phase_damage": str(combat.phase_damage), "arenas": arenas,
		"casts": casts, "cooldowns": combat._cooldowns.duplicate(), "cast_serial": str(combat._cast_serial)}


static func _world(shell: Node) -> Dictionary:
	var encounter: ArenicEncounterState = shell.encounter
	var arenas: Dictionary = {}
	for arena_id: String in encounter.arena_ids():
		var clock: ArenicCycleClock = encounter._clocks[arena_id]
		var ground: ArenicDigField = encounter.dig_field(arena_id)
		var dug: Array = []
		for index: int in ground.dug_cells():
			dug.append([index, ground._dug[index]])
		var pools: Array = []
		for pool: ArenicAcidField.Pool in encounter.acid_field(arena_id)._pools:
			pools.append({"area": _r(pool.area), "ticks_left": pool.ticks_left, "span": pool.span,
				"tick_ticks": pool.tick_ticks, "debt": pool.debt, "damage": str(pool.damage)})
		var timeline: ArenicArenaTimeline = encounter.timeline(arena_id)
		var active: Array = []
		for performer: String in timeline.performers():
			if performer.begins_with(ArenicCombatState.HERO_ALLY_PREFIX):
				active.append(performer)
		arenas[arena_id] = {"tick": clock.tick, "paused": clock.paused,
			"ground": {"cycle": str(ground.cycle), "values": Array(ground._values), "dug": dug},
			"pools": pools, "active": active, "orders": timeline._orders.duplicate(), "next_order": timeline._next_order}
	var music: Dictionary = {}
	for arena_id: StringName in shell.music.clocks:
		var clock: ArenicArenaMusicClock = shell.music.clocks[arena_id]
		music[String(arena_id)] = {"position": clock.elapsed_seconds, "running": clock.running}
	var session: ArenicRecordingSession = shell.session
	return {"selected_index": shell.selected_index, "zoomed": shell.zoomed,
		"difficulty": encounter.difficulty, "beats_resolved": str(encounter.beats_resolved),
		"dig_bonus": encounter.dig_bonus, "arenas": arenas, "music": music,
		"session": {"state": int(session.state), "countdown_left": session.countdown_left,
			"identity": session.identity, "arena_id": session.arena_id,
			"start_cell": _v(session.start_cell), "events": _events(session.events)},
		"modal": _modal(shell.modal)}


static func _modal(modal: ArenicModal) -> Dictionary:
	if modal == null or not modal.is_open():
		return {}
	var options: Array = []
	for index: int in modal._choices.size():
		options.append([modal._buttons[index].text.trim_prefix("%d  " % (index + 1)), String(modal._choices[index])])
	var context: Dictionary = {}
	if modal._context.has("step"):
		context["step"] = _v(modal._context.step)
	return {"arena_id": modal.arena_id, "title": modal._title.text, "detail": modal._detail.text,
		"options": options, "focused": modal._focused, "context": context}


static func restore_run(payload: Dictionary, run: Node) -> bool:
	if not validate(payload).is_empty():
		return false
	var data: Dictionary = payload.run
	run.begin_new_game()
	run.selected_class = _class_for(data.selected_class)
	for saved: Dictionary in data.heroes:
		var hero := ArenicHeroState.new()
		hero.identity_id = int(saved.identity)
		hero.definition = _class_for(saved.class_id)
		hero.level = int(saved.level)
		hero.experience = int(saved.experience)
		hero.experience_to_next_level = int(saved.experience_to_next_level)
		hero.arena_id = saved.arena_id
		hero.cell = _vec(saved.cell)
		hero.facing = saved.facing
		hero.selected = saved.selected
		for arena_id: String in saved.recordings:
			hero.recordings[arena_id] = _read_staff(saved.recordings[arena_id])
		run.heroes.append(hero)
	run.selected_identity = int(data.selected_identity)
	for arena_id: String in data.arena_selection:
		run.arena_selection[arena_id] = int(data.arena_selection[arena_id])
	run._next_identity = int(data.next_identity)
	run.prospected = int(data.prospected)
	run.run_seed = int(data.seed)
	var recruitment: ArenicRecruitmentState = run.get_recruitment()
	recruitment.rolls_claimed = int(data.rolls_claimed)
	if not data.combat.is_empty():
		_restore_combat(data.combat, run.get_combat(), run.heroes)
	return true


static func restore_shell(payload: Dictionary, shell: Node) -> bool:
	if not validate(payload).is_empty() or payload.scene != "game":
		return false
	if payload.world.is_empty():
		return true
	var data: Dictionary = payload.world
	var encounter: ArenicEncounterState = shell.encounter
	encounter.configure(shell.stage.world, ENCOUNTERS, shell.combat, data.difficulty)
	encounter.beats_resolved = int(data.beats_resolved)
	encounter.dig_bonus = int(data.dig_bonus)
	for arena_id: String in data.arenas:
		var saved: Dictionary = data.arenas[arena_id]
		var clock: ArenicCycleClock = encounter._clocks[arena_id]
		clock.seek(int(saved.tick))
		clock.paused = saved.paused
		var field: ArenicDigField = encounter.dig_field(arena_id)
		field.cycle = int(saved.ground.cycle)
		field._values = PackedByteArray(saved.ground.values)
		field._dug.clear()
		for entry: Array in saved.ground.dug:
			field._dug[int(entry[0])] = int(entry[1])
		var acid: ArenicAcidField = encounter.acid_field(arena_id)
		acid.clear()
		for value: Dictionary in saved.pools:
			var pool := ArenicAcidField.Pool.new()
			pool.area = _rect(value.area)
			pool.ticks_left = int(value.ticks_left)
			pool.span = int(value.span)
			pool.tick_ticks = int(value.tick_ticks)
			pool.debt = int(value.debt)
			pool.damage = int(value.damage)
			acid._pools.append(pool)
		var timeline: ArenicArenaTimeline = encounter.timeline(arena_id)
		# Boss staves come from trusted authored data. Hero membership and the
		# historical ordering are durable, while merged events/cursor are derived.
		for performer: String in timeline.performers():
			if performer.begins_with(ArenicCombatState.HERO_ALLY_PREFIX):
				timeline._staves.erase(performer)
		timeline._orders.clear()
		for performer: String in saved.orders:
			timeline._orders[performer] = int(saved.orders[performer])
		timeline._next_order = int(saved.next_order)
		for performer: String in saved.active:
			var hero: ArenicHeroState = _hero_for_ally(shell.heroes, performer)
			timeline._staves[performer] = hero.recordings[arena_id]
		timeline._rebuild()
		timeline.seek_to(clock.tick)
	# Configure derives boss footprints and may re-register actors; restore the
	# ledger last so exact health, target geometry and in-flight casts win.
	_restore_combat(payload.run.combat, shell.combat, shell.heroes)
	var saved_session: Dictionary = data.session
	shell.session.state = int(saved_session.state) as ArenicRecordingSession.State
	shell.session.countdown_left = int(saved_session.countdown_left)
	shell.session.identity = int(saved_session.identity)
	shell.session.performer = ArenicCombatState.hero_ally_id(int(saved_session.identity)) if int(saved_session.identity) >= 0 else ""
	shell.session.arena_id = saved_session.arena_id
	shell.session.start_cell = _vec(saved_session.start_cell)
	shell.session.events = _read_events(saved_session.events)
	for arena_id: String in data.music:
		shell.music.seek_arena(StringName(arena_id), float(data.music[arena_id].position))
		shell.music.set_clock_running(StringName(arena_id), data.music[arena_id].running)
	shell.selected_index = int(data.selected_index)
	shell.zoomed = data.zoomed
	shell.stage.select_arena(shell.selected_index)
	shell.stage.sync_heroes(shell.hero.identity_id, shell.zoomed, shell._is_ghost)
	shell._frame(false)
	shell._sync_boss_placement()
	shell._sync_dig_markers()
	shell._update_hud()
	shell.combat_presentation.restore_active(shell.combat.active_cast_snapshot(shell.hero))
	if not data.modal.is_empty():
		var modal: Dictionary = data.modal
		var context: Dictionary = {}
		if modal.context.has("step"):
			context.step = _vec(modal.context.step)
		shell._open_modal(modal.arena_id, modal.title, modal.detail, modal.options, int(modal.focused), context)
	return true


static func _restore_combat(data: Dictionary, combat: ArenicCombatState, heroes: Array) -> void:
	combat.configure(WORLD)
	combat.phase_damage = int(data.phase_damage)
	combat._arenas.clear()
	for arena_id: String in data.arenas:
		var saved: Dictionary = data.arenas[arena_id]
		var enemies: Dictionary = {}
		for enemy_id: String in saved.enemies:
			var enemy: Dictionary = saved.enemies[enemy_id]
			enemies[enemy_id] = {"footprint": _rect(enemy.footprint), "facing": enemy.facing, "damage": int(enemy.damage)}
		var allies: Dictionary = {}
		for actor_id: String in saved.allies:
			var ally: Dictionary = saved.allies[actor_id]
			allies[actor_id] = {"cell": _vec(ally.cell), "health": int(ally.health), "max_health": int(ally.max_health), "debuffs": PackedStringArray(ally.debuffs)}
		combat._arenas[arena_id] = {"damage": int(saved.damage), "phase_damage": int(saved.phase_damage), "enemies": enemies, "allies": allies}
	combat._hero_arenas.clear()
	for hero: ArenicHeroState in heroes:
		combat._hero_arenas[hero.ally_id()] = hero.arena_id
	combat._cooldowns.clear()
	for caster_id: String in data.cooldowns:
		combat._cooldowns[caster_id] = float(data.cooldowns[caster_id])
	combat._cast_serial = int(data.cast_serial)
	combat._casts.clear()
	for caster_id: String in data.casts:
		var value: Dictionary = data.casts[caster_id]
		var cast := ArenicCombatState.Cast.new()
		cast.owner = _hero_for_ally(heroes, caster_id)
		cast.ability = _ability_for(cast.owner.definition, value.ability_id)
		cast.arena = value.arena
		cast.origin = _vec(value.origin)
		cast.facing = value.facing
		cast.target_id = value.target_id
		cast.target_cell = _vec(value.target_cell)
		cast.elapsed = float(value.elapsed)
		cast.tick_debt = float(value.tick_debt)
		cast.cast_id = int(value.cast_id)
		cast.released = value.released
		cast.release_seconds = float(value.release_seconds)
		cast.loot_bonus = float(value.loot_bonus)
		combat._casts[caster_id] = cast


static func _read_staff(data: Dictionary) -> ArenicRecording:
	return ArenicRecording.create(_vec(data.start_cell), _read_events(data.events))


static func _read_events(data: Array) -> Array[ArenicTimelineEvent]:
	var events: Array[ArenicTimelineEvent] = []
	for value: Dictionary in data:
		var event := ArenicTimelineEvent.new()
		event.tick = int(value.tick)
		event.action_id = StringName(value.action)
		event.delta = _vec(value.delta)
		event.slot = int(value.slot)
		events.append(event)
	return events


static func _class_for(id: String) -> ArenicClassDefinition:
	for definition: ArenicClassDefinition in CLASSES.classes:
		if definition.class_id == id:
			return definition
	return null


static func _ability_for(definition: ArenicClassDefinition, id: String) -> ArenicClassAbility:
	for ability: ArenicClassAbility in definition.skills:
		if ability.ability_id == id:
			return ability
	return null


static func _hero_for_ally(heroes: Array, id: String) -> ArenicHeroState:
	for hero: ArenicHeroState in heroes:
		if hero.ally_id() == id:
			return hero
	return null


static func _v(value: Vector2i) -> Array:
	return [value.x, value.y]


static func _r(value: Rect2i) -> Array:
	return [value.position.x, value.position.y, value.size.x, value.size.y]


static func _vec(value: Array) -> Vector2i:
	return Vector2i(int(value[0]), int(value[1]))


static func _rect(value: Array) -> Rect2i:
	return Rect2i(int(value[0]), int(value[1]), int(value[2]), int(value[3]))


## Validate before allocating domain objects or mutating a run. Exact record
## fields make a newly added durable field a deliberate schema decision.
static func validate(payload: Dictionary) -> PackedStringArray:
	var check := Validator.new()
	check.validate_payload(payload)
	return check.errors


class Validator:
	extends RefCounted
	var errors := PackedStringArray()
	var heroes: Dictionary = {}
	var event_count: int = 0
	var phase: String = ""

	func fail(message: String) -> bool:
		if errors.size() < 16:
			errors.append(message)
		return false

	func record(value: Variant, fields: Array, label: String) -> bool:
		if not value is Dictionary or value.size() != fields.size():
			return fail(label + " has missing or unknown fields.")
		for key: Variant in fields:
			if not value.has(key):
				return fail(label + " is missing " + str(key) + ".")
		return true

	func table(value: Variant, maximum: int, label: String) -> bool:
		if not value is Dictionary or value.size() > maximum:
			return fail(label + " is not a bounded dictionary.")
		for key: Variant in value:
			if not text(key, 96, false):
				return fail(label + " has an invalid key.")
		return true

	func list(value: Variant, maximum: int) -> bool:
		return value is Array and value.size() <= maximum

	func integer(value: Variant, low: int, high: int) -> bool:
		return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and float(value) >= low and float(value) <= high

	func decimal(value: Variant, positive: bool = false) -> bool:
		if not value is String or value.length() < 1 or value.length() > 19 or not value.is_valid_int():
			return false
		var parsed: int = value.to_int()
		return parsed >= (1 if positive else 0) and str(parsed) == value

	func number(value: Variant, maximum: float = 1000000000000.0) -> bool:
		return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0.0 and float(value) <= maximum

	func text(value: Variant, maximum: int, empty: bool = true) -> bool:
		return value is String and value.length() <= maximum and (empty or not value.is_empty())

	func cell(value: Variant) -> bool:
		return list(value, 2) and value.size() == 2 and integer(value[0], 0, ArenicGridMath.GRID_WIDTH - 1) and integer(value[1], 0, ArenicGridMath.GRID_HEIGHT - 1)

	func step(value: Variant, allow_zero: bool = true) -> bool:
		return list(value, 2) and value.size() == 2 and integer(value[0], -1, 1) and integer(value[1], -1, 1) and (allow_zero or value[0] != 0 or value[1] != 0)

	func rect(value: Variant, outside: bool = false) -> bool:
		if not list(value, 4) or value.size() != 4:
			return false
		var width: int = ArenicGridMath.GRID_WIDTH
		var height: int = ArenicGridMath.GRID_HEIGHT
		if not integer(value[0], -width if outside else 0, width - 1) or not integer(value[1], -height if outside else 0, height - 1) or not integer(value[2], 1, width) or not integer(value[3], 1, height):
			return false
		return outside or (value[0] + value[2] <= width and value[1] + value[3] <= height)

	func arena(value: Variant) -> bool:
		return value is String and WORLD.index_for_id(value) >= 0

	func hero_key(value: Variant) -> bool:
		return value is String and heroes.has(value)

	func validate_payload(data: Dictionary) -> void:
		if not record(data, ["schema_version", "scene", "selection_index", "run", "world"], "Save payload"):
			return
		if not integer(data.schema_version, SCHEMA_VERSION, SCHEMA_VERSION):
			fail("Unsupported game state schema version.")
			return
		if data.scene not in ["class_selection", "game"] or not integer(data.selection_index, 0, CLASSES.classes.size() - 1):
			fail("Invalid saved scene or class selection.")
			return
		phase = data.scene
		if not record(data.run, ["selected_class", "heroes", "selected_identity", "arena_selection", "next_identity", "prospected", "seed", "rolls_claimed", "combat"], "Run"):
			return
		var run: Dictionary = data.run
		if not text(run.selected_class, 64) or (run.selected_class != "" and ArenicSaveCodec._class_for(run.selected_class) == null) or not list(run.heroes, MAX_HEROES):
			fail("Invalid class or guild roster.")
			return
		if not integer(run.next_identity, 0, MAX_HEROES) or not integer(run.selected_identity, -1, MAX_HEROES - 1) or not decimal(run.prospected) or not integer(run.seed, 0, 2147483647) or not integer(run.rolls_claimed, 0, MAX_HEROES):
			fail("Invalid run counters.")
			return
		for value: Variant in run.heroes:
			validate_hero(value)
		if not errors.is_empty():
			return
		if phase == "class_selection":
			if not run.heroes.is_empty() or run.selected_class != "" or run.selected_identity != -1 or run.next_identity != 0 or run.prospected != "0" or run.rolls_claimed != 0 or run.combat != {} or data.world != {}:
				fail("Class selection cannot contain an active game.")
		else:
			if run.selected_class == "" or run.heroes.is_empty() or not heroes.has(ArenicCombatState.hero_ally_id(int(run.selected_identity))):
				fail("A game must have a valid founding class and selected hero.")
			for value: Dictionary in run.heroes:
				if int(value.identity) >= int(run.next_identity):
					fail("Next hero identity would collide with the guild.")
		if not table(run.arena_selection, 9, "Arena selections"):
			return
		for arena_id: String in run.arena_selection:
			var id: Variant = run.arena_selection[arena_id]
			if not arena(arena_id) or not integer(id, 0, MAX_HEROES - 1) or not hero_key(ArenicCombatState.hero_ally_id(int(id))):
				fail("Arena selection references an unknown hero.")
			elif heroes[ArenicCombatState.hero_ally_id(int(id))].arena_id != arena_id:
				fail("Arena selection references a hero in another arena.")
		if not run.combat is Dictionary or not data.world is Dictionary:
			fail("Combat and world must be records.")
			return
		if not run.combat.is_empty():
			validate_combat(run.combat)
		if not data.world.is_empty():
			if run.combat.is_empty():
				fail("A world needs its combat ledger.")
			validate_world(data.world)

	func validate_hero(value: Variant) -> void:
		if not record(value, ["identity", "class_id", "level", "experience", "experience_to_next_level", "arena_id", "cell", "facing", "selected", "recordings"], "Hero"):
			return
		var hero: Dictionary = value
		if not integer(hero.identity, 0, MAX_HEROES - 1) or not text(hero.class_id, 64, false) or ArenicSaveCodec._class_for(hero.class_id) == null or not decimal(hero.level, true) or not decimal(hero.experience) or not decimal(hero.experience_to_next_level, true) or not arena(hero.arena_id) or not cell(hero.cell) or hero.facing not in FACES or not hero.selected is bool:
			fail("Hero has invalid identity, class, progress, or placement.")
			return
		var id: String = ArenicCombatState.hero_ally_id(int(hero.identity))
		if heroes.has(id):
			fail("Duplicate hero identity.")
			return
		heroes[id] = hero
		if not table(hero.recordings, 9, "Hero recordings"):
			return
		for arena_id: String in hero.recordings:
			if not arena(arena_id):
				fail("Recording references an unknown arena.")
			var staff: Variant = hero.recordings[arena_id]
			if not record(staff, ["start_cell", "events"], "Recording"):
				continue
			if not cell(staff.start_cell):
				fail("Recording has an invalid start cell.")
			validate_events(staff.events)

	func validate_events(value: Variant) -> void:
		if not list(value, MAX_STAFF_EVENTS):
			fail("Recording exceeds the 14,400 event capacity.")
			return
		event_count += value.size()
		if event_count > MAX_TOTAL_EVENTS:
			fail("Save exceeds the 1,000,000 recording event capacity; the last durable save is retained.")
			return
		var previous: int = -1
		for event: Variant in value:
			if not record(event, ["tick", "action", "delta", "slot"], "Recording event"):
				return
			if not integer(event.tick, maxi(0, previous), ArenicCycleClock.CYCLE_TICKS - 1) or event.action not in ["move", "ability"] or not step(event.delta) or not integer(event.slot, 0, 4):
				fail("Invalid or out-of-order recording event.")
				return
			if (event.action == "move" and (not step(event.delta, false) or event.slot != 0)) or (event.action == "ability" and ((event.delta[0] != 0 or event.delta[1] != 0) or event.slot < 1)):
				fail("Recording action payload is invalid.")
				return
			previous = int(event.tick)

	func validate_combat(data: Dictionary) -> void:
		if not record(data, ["phase_damage", "arenas", "casts", "cooldowns", "cast_serial"], "Combat"):
			return
		if not decimal(data.phase_damage, true) or not decimal(data.cast_serial) or not table(data.arenas, 9, "Combat arenas") or not table(data.casts, MAX_HEROES, "Casts") or not table(data.cooldowns, MAX_HEROES, "Cooldowns"):
			fail("Combat has invalid counters or collections.")
			return
		for arena_id: String in data.arenas:
			if not arena(arena_id):
				fail("Combat references an unknown arena.")
			var value: Variant = data.arenas[arena_id]
			if not record(value, ["damage", "phase_damage", "enemies", "allies"], "Combat arena"):
				continue
			if not decimal(value.damage) or not decimal(value.phase_damage) or not table(value.enemies, 512, "Enemies") or not table(value.allies, 512, "Allies"):
				fail("Invalid arena ledger.")
				continue
			for enemy_id: String in value.enemies:
				var enemy: Variant = value.enemies[enemy_id]
				if not record(enemy, ["footprint", "facing", "damage"], "Enemy"):
					continue
				if not rect(enemy.footprint) or enemy.facing not in FACES or not decimal(enemy.damage):
					fail("Invalid enemy geometry or damage.")
			for ally_id: String in value.allies:
				var ally: Variant = value.allies[ally_id]
				if not record(ally, ["cell", "health", "max_health", "debuffs"], "Ally"):
					continue
				if not cell(ally.cell) or not decimal(ally.health) or not decimal(ally.max_health, true) or int(ally.health) > int(ally.max_health) or not list(ally.debuffs, 32):
					fail("Invalid ally status.")
					continue
				for debuff: Variant in ally.debuffs:
					if not text(debuff, 64, false):
						fail("Invalid ally debuff.")
				if ally_id.begins_with(ArenicCombatState.HERO_ALLY_PREFIX) and (not hero_key(ally_id) or heroes[ally_id].arena_id != arena_id or ArenicSaveCodec._vec(heroes[ally_id].cell) != ArenicSaveCodec._vec(ally.cell)):
					fail("Hero health ledger disagrees with its roster placement.")
		for caster_id: String in data.cooldowns:
			if not hero_key(caster_id) or not number(data.cooldowns[caster_id], 86400.0):
				fail("Invalid cooldown or unknown caster.")
		if not errors.is_empty():
			return
		for caster_id: String in data.casts:
			validate_cast(caster_id, data.casts[caster_id], data)

	func validate_cast(caster_id: String, value: Variant, combat: Dictionary) -> void:
		if not record(value, ["owner", "ability_id", "arena", "origin", "facing", "target_id", "target_cell", "elapsed", "tick_debt", "cast_id", "released", "release_seconds", "loot_bonus"], "Cast"):
			return
		if not hero_key(caster_id) or not integer(value.owner, 0, MAX_HEROES - 1) or ArenicCombatState.hero_ally_id(int(value.owner)) != caster_id:
			fail("Cast references an unknown or inconsistent owner.")
			return
		if not text(value.ability_id, 64, false) or ArenicSaveCodec._ability_for(ArenicSaveCodec._class_for(heroes[caster_id].class_id), value.ability_id) == null or not arena(value.arena) or not cell(value.origin) or not cell(value.target_cell) or value.facing not in FACES or not text(value.target_id, 96):
			fail("Invalid cast ability, target, or placement.")
			return
		if not number(value.elapsed) or not number(value.tick_debt, 86400.0) or not decimal(value.cast_id, true) or int(value.cast_id) > int(combat.cast_serial) or not value.released is bool or not number(value.release_seconds, 86400.0) or not number(value.loot_bonus):
			fail("Invalid cast clocks or serial.")
		if not combat.arenas.has(value.arena) or (value.target_id != "" and not combat.arenas[value.arena].enemies.has(value.target_id)):
			fail("Cast target is absent from its arena ledger.")

	func validate_world(data: Dictionary) -> void:
		if not record(data, ["selected_index", "zoomed", "difficulty", "beats_resolved", "dig_bonus", "arenas", "music", "session", "modal"], "World"):
			return
		if not integer(data.selected_index, 0, 8) or not data.zoomed is bool or data.difficulty != "normal" or not decimal(data.beats_resolved) or not integer(data.dig_bonus, 0, 255) or not table(data.arenas, 9, "World arenas") or data.arenas.size() != 9 or not table(data.music, 9, "Music clocks"):
			fail("Invalid navigation, difficulty, clocks, or arena set.")
			return
		for arena_id: String in data.arenas:
			validate_arena(arena_id, data.arenas[arena_id])
		for arena_id: String in data.music:
			var clock: Variant = data.music[arena_id]
			if not record(clock, ["position", "running"], "Music clock"):
				continue
			if not arena(arena_id) or not number(clock.position, 86400.0) or not clock.running is bool:
				fail("Invalid music clock.")
		validate_session(data.session)
		validate_modal(data.modal)
		if not errors.is_empty():
			return
		for arena_id: String in data.arenas:
			if data.arenas[arena_id].paused:
				var countdown: bool = data.session.state == ArenicRecordingSession.State.COUNTDOWN and data.session.arena_id == arena_id
				var decision: bool = not data.modal.is_empty() and data.modal.arena_id == arena_id
				if not countdown and not decision:
					fail("Paused arena has no saved countdown or decision.")

	func validate_arena(arena_id: String, value: Variant) -> void:
		if not arena(arena_id) or not record(value, ["tick", "paused", "ground", "pools", "active", "orders", "next_order"], "World arena"):
			fail("Invalid world arena.")
			return
		if not integer(value.tick, 0, ArenicCycleClock.CYCLE_TICKS - 1) or not value.paused is bool or not list(value.pools, MAX_POOLS) or not list(value.active, ArenicEncounterState.MAX_GHOSTS_PER_ARENA) or not table(value.orders, MAX_HEROES + 1, "Performer order") or not integer(value.next_order, 0, MAX_HEROES + 1):
			fail("Invalid arena clocks or performers.")
			return
		var seen_orders: Dictionary = {}
		for performer: String in value.orders:
			var order: Variant = value.orders[performer]
			if (performer != ArenicCombatState.boss_enemy_id(arena_id) and not hero_key(performer)) or not integer(order, 0, int(value.next_order) - 1) or seen_orders.has(order):
				fail("Invalid or duplicate performer order.")
				continue
			seen_orders[order] = true
		if ENCOUNTERS.score_for(arena_id, "normal") != null and not value.orders.has(ArenicCombatState.boss_enemy_id(arena_id)):
			fail("Authored boss is missing its fold order.")
		var seen: Dictionary = {}
		for performer: Variant in value.active:
			if not hero_key(performer) or seen.has(performer) or not value.orders.has(performer):
				fail("Unknown or duplicate active ghost.")
				continue
			seen[performer] = true
			if heroes[performer].arena_id != arena_id or not heroes[performer].recordings.has(arena_id):
				fail("Ghost is missing its arena or committed recording.")
		if record(value.ground, ["cycle", "values", "dug"], "Ground"):
			var ground: Dictionary = value.ground
			if not decimal(ground.cycle) or not list(ground.values, ArenicDigField.CELLS) or ground.values.size() != ArenicDigField.CELLS or not list(ground.dug, ArenicDigField.CELLS):
				fail("Invalid ground field size or cycle.")
			else:
				for tile: Variant in ground.values:
					if not integer(tile, 1, 255):
						fail("Invalid rolled ground value.")
				var dug: Dictionary = {}
				for entry: Variant in ground.dug:
					if not list(entry, 2) or entry.size() != 2 or not integer(entry[0], 0, ArenicDigField.CELLS - 1) or not integer(entry[1], 0, ArenicDigField.HAZARD_TICKS - 1):
						fail("Invalid dug tile or hazard debt.")
					elif dug.has(entry[0]):
						fail("Duplicate dug tile.")
					else:
						dug[entry[0]] = true
		for pool: Variant in value.pools:
			if not record(pool, ["area", "ticks_left", "span", "tick_ticks", "debt", "damage"], "Acid pool"):
				continue
			if not rect(pool.area, true) or not integer(pool.span, 1, 5184000) or not integer(pool.ticks_left, 1, int(pool.span)) or not integer(pool.tick_ticks, 1, 5184000) or not integer(pool.debt, 0, int(pool.tick_ticks) - 1) or not decimal(pool.damage, true):
				fail("Invalid acid pool geometry, timing, or damage.")

	func validate_session(value: Variant) -> void:
		if not record(value, ["state", "countdown_left", "identity", "arena_id", "start_cell", "events"], "Recording session"):
			return
		if not integer(value.state, 0, 2) or not integer(value.countdown_left, 0, ArenicRecordingSession.COUNTDOWN_TICKS) or not integer(value.identity, -1, MAX_HEROES - 1) or not cell(value.start_cell):
			fail("Invalid recording session state.")
			return
		validate_events(value.events)
		if value.state == ArenicRecordingSession.State.IDLE:
			if value.identity != -1 or value.arena_id != "" or value.countdown_left != 0 or value.events != []:
				fail("Idle recording session contains a draft.")
		else:
			var performer: String = ArenicCombatState.hero_ally_id(int(value.identity))
			if not hero_key(performer) or not arena(value.arena_id) or heroes[performer].arena_id != value.arena_id:
				fail("Recording session references an absent performer.")
			if value.state == ArenicRecordingSession.State.COUNTDOWN and (value.countdown_left < 1 or value.events != []):
				fail("Recording countdown is inconsistent.")
			if value.state == ArenicRecordingSession.State.RECORDING and value.countdown_left != 0:
				fail("Recording retains a countdown.")

	func validate_modal(value: Variant) -> void:
		if value is Dictionary and value.is_empty():
			return
		if not record(value, ["arena_id", "title", "detail", "options", "focused", "context"], "Pending decision"):
			return
		if not arena(value.arena_id) or not text(value.title, 160, false) or not text(value.detail, 1024) or not list(value.options, ArenicModal.MAX_OPTIONS) or value.options.is_empty() or not integer(value.focused, 0, value.options.size() - 1) or not table(value.context, 1, "Decision context"):
			fail("Invalid pending decision.")
			return
		for key: String in value.context:
			if key != "step" or not step(value.context[key], false):
				fail("Unknown decision context.")
		var choices: Array[String] = [ArenicModal.CANCEL, ArenicModal.START_RECORDING, ArenicModal.REPLAY_PREVIOUS, ArenicModal.CONTINUE_WITHOUT, ArenicModal.COMMIT, ArenicModal.DISCARD, ArenicModal.DISCARD_AND_WALK, ArenicModal.TAKE_CONTROL, ArenicModal.RESTART_ARENA]
		for option: Variant in value.options:
			if not list(option, 2) or option.size() != 2 or not text(option[0], 128, false) or not text(option[1], 96, false):
				fail("Invalid decision option.")
				continue
			var recruit: bool = option[1].begins_with(ArenicModal.RECRUIT_PREFIX) and ArenicSaveCodec._class_for(option[1].trim_prefix(ArenicModal.RECRUIT_PREFIX)) != null
			if option[1] not in choices and not recruit:
				fail("Unknown decision action.")
