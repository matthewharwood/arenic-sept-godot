extends SceneTree
## Pure rules. No scenes, imported art, renderer, input device or audio playback.

const Combat = preload("res://scripts/combat/combat_state.gd")
const CLASSES: Array[String] = ["hunter", "warrior", "thief", "alchemist", "cardinal", "bard", "forager", "merchant"]
const ARENAS: Array[String] = ["labyrinth", "guild_house", "sanctum", "mountain", "bastion", "pawnshop", "crucible", "casino", "gala"]
const BOSS := Rect2i(30, 22, 6, 6)
var _checks: int = 0
var _failures := PackedStringArray()


func _initialize() -> void:
	_check_data()
	_check_targeting()
	_check_melee()
	_check_backstab()
	_check_ground()
	_check_channel()
	_check_cleanse()
	_check_fortune()
	_check_progress_and_registration()
	_check_active_handoff()
	_check_release_phases()
	_check_fast_phases_and_misses()
	_check_channel_aura_phases()
	_check_support_phases()
	_check_invalid_inputs()
	if _failures.is_empty():
		print("Combat checks passed: %d assertions." % _checks)
		quit(0)
	else:
		for failure: String in _failures:
			push_error(failure)
		print("Combat checks failed: %d of %d assertions." % [_failures.size(), _checks])
		quit(1)


func _fixture(class_id: String, cell: Vector2i = Vector2i(30, 15)) -> Dictionary:
	var world := ArenicWorldDefinition.new()
	for index: int in range(9):
		var arena := ArenicArenaDefinition.new()
		arena.arena_id = ARENAS[index]
		arena.grid_slot = Vector2i(index % 3, index / 3)
		world.arenas.append(arena)
	var hero := ArenicHeroState.new()
	hero.definition = ArenicClassDefinition.new()
	hero.definition.class_id = class_id
	hero.definition.skills.append(load("res://data/classes/%s_primary.tres" % class_id).duplicate())
	hero.cell = cell
	var combat := Combat.new()
	combat.configure(world)
	return {"combat": combat, "hero": hero, "world": world}


func _check_data() -> void:
	var ids: Array[String] = ["auto_shot", "bash", "backstab", "acid_flask", "heal", "cleanse", "dig", "fortune"]
	for index: int in range(CLASSES.size()):
		var f: Dictionary = _fixture(CLASSES[index])
		var ability: ArenicClassAbility = f.hero.definition.skills[0]
		_expect(ability.ability_id == ids[index], "Starter uses canonical source ID: " + CLASSES[index])
		_expect(ability.damage == 1, "Every starter hit is normalized to one: " + CLASSES[index])
		_expect(not ability.title.is_empty() and not ability.description.is_empty(), "Starter has actual UI copy.")
		_expect(ability.cooldown_seconds > 0.0, "Starter has a positive cooldown.")
		_expect(ability.release_seconds == (0.26 if CLASSES[index] in ["hunter", "alchemist"] else 0.0), "Only the two starter projectiles have an authored release delay.")


func _check_targeting() -> void:
	var f := _fixture("hunter")
	var c: RefCounted = f.combat
	var h: ArenicHeroState = f.hero
	c.register_enemy("guild_house", "training", BOSS)
	_expect(c.cast_unavailable_reason(h).is_empty(), "Guild spawn is seven cells from training target edge, within range eight.")
	_expect(c.cooldown_remaining() == 0.0 and c.active_remaining() == 0.0, "Availability lookup is read-only.")
	var signals: Array = []
	c.ability_cast.connect(func(id: String, arena: String, origin: Vector2i, target: Vector2i, facing: String): signals.append([id, arena, origin, target, facing]))
	_expect(c.try_cast(h).is_empty(), "Hunter starts its shot.")
	_expect(signals == [["auto_shot", "guild_house", Vector2i(30, 15), Vector2i(30, 22), "n"]], "Cast signal gives windup, footprint edge target and correct facing.")
	_expect(c.damage_for_arena("guild_house") == 0, "Projectile does not deal damage at launch.")
	c.tick(0.74, h)
	_expect(c.damage_for_arena("guild_house") == 0, "Hunter hit waits for landing.")
	c.tick(0.01, h)
	_expect(c.damage_for_arena("guild_house") == 1 and c.active_remaining() == 0.0, "Hunter lands exactly at0.75 seconds.")
	_expect(not c.try_cast(h).is_empty(), "Cooldown remains after a shot lands.")
	c.tick(1.75, h)
	_expect(c.cooldown_remaining() == 0.0, "Hunter can shoot again at2.5 seconds.")
	h.cell = Vector2i(30, 13)
	_expect(not c.try_cast(h).is_empty() and c.cooldown_remaining() == 0.0, "Outside edge range rejects without spending cooldown.")
	h.cell = Vector2i(30, 14)
	_expect(c.try_cast(h).is_empty(), "Exact eight-cell boundary is included.")
	c.tick(1.0, h)
	_expect(c.damage_for_enemy("guild_house", "training") == 2, "Immortal target keeps accumulating damage.")
	f = _fixture("hunter", Vector2i(10, 10))
	c = f.combat
	h = f.hero
	c.register_enemy("guild_house", "z", Rect2i(12, 10, 1, 1))
	c.register_enemy("guild_house", "a", Rect2i(8, 10, 1, 1))
	c.register_enemy("sanctum", "remote", Rect2i(10, 10, 1, 1))
	c.try_cast(h)
	c.tick(1.0, h)
	_expect(c.damage_for_enemy("guild_house", "a") == 1 and c.damage_for_enemy("guild_house", "z") == 0, "Equal edge distance ties use stable enemy ID, never insertion order.")
	_expect(c.damage_for_arena("sanctum") == 0 and h.facing == "w", "Targeting never reaches another arena and faces the selected target.")
	c.tick(2.0, h)
	c.register_enemy("guild_house", "near", Rect2i(11, 11, 1, 1))
	c.try_cast(h)
	c.tick(1.0, h)
	_expect(c.damage_for_enemy("guild_house", "near") == 1 and h.facing == "n", "Nearest edge wins; equal-axis diagonal uses vertical facing.")


func _check_melee() -> void:
	for class_id: String in ["warrior", "forager"]:
		var f := _fixture(class_id, Vector2i(29, 21))
		var c: RefCounted = f.combat
		var h: ArenicHeroState = f.hero
		c.register_enemy("guild_house", "boss", BOSS)
		_expect(c.try_cast(h).is_empty(), class_id + " includes diagonal adjacency.")
		c.tick(h.definition.skills[0].cast_seconds, h)
		_expect(c.damage_for_enemy("guild_house", "boss") == 1, class_id + " lands one normalized hit.")
		c.tick(2.0, h)
		h.cell = Vector2i(28, 21)
		_expect(not c.try_cast(h).is_empty(), class_id + " excludes distance two.")
		h.cell = Vector2i(30, 22)
		_expect(not c.try_cast(h).is_empty(), class_id + " requires adjacency, not overlapping the target.")
		h.cell = Vector2i(29, 21)
		c.try_cast(h)
		h.cell.x -= 1
		c.tick(2.0, h)
		_expect(c.damage_for_arena("guild_house") == 1, class_id + " cannot hit after moving beyond adjacency during windup.")


func _check_backstab() -> void:
	var positions := {"n": [Vector2i(32, 21), Vector2i(32, 28), Vector2i(29, 24)], "s": [Vector2i(32, 28), Vector2i(32, 21), Vector2i(36, 24)], "e": [Vector2i(29, 24), Vector2i(36, 24), Vector2i(32, 21)], "w": [Vector2i(36, 24), Vector2i(29, 24), Vector2i(32, 28)]}
	for facing: String in positions:
		var f := _fixture("thief", positions[facing][0])
		var c: RefCounted = f.combat
		var h: ArenicHeroState = f.hero
		c.register_enemy("guild_house", "boss", BOSS, facing)
		_expect(c.try_cast(h).is_empty(), "Backstab accepts rear edge for facing " + facing)
		c.tick(0.2, h)
		_expect(c.damage_for_arena("guild_house") == 1, "Backstab hits once for facing " + facing)
		c.tick(2.0, h)
		for cell: Vector2i in [positions[facing][1], positions[facing][2]]:
			h.cell = cell
			_expect(not c.try_cast(h).is_empty(), "Backstab rejects front/side for facing " + facing)
		_expect(c.damage_for_arena("guild_house") == 1, "Rejected backstabs do not damage.")
		h.cell = positions[facing][0]
		c.try_cast(h)
		var opposite: String = {"n": "s", "s": "n", "e": "w", "w": "e"}[facing]
		c.register_enemy("guild_house", "boss", BOSS, opposite)
		c.tick(0.2, h)
		_expect(c.damage_for_arena("guild_house") == 1, "Target turning during windup defeats the backstab.")


func _check_ground() -> void:
	var f := _fixture("alchemist")
	var c: RefCounted = f.combat
	var h: ArenicHeroState = f.hero
	c.register_enemy("guild_house", "first", BOSS)
	c.register_enemy("guild_house", "second", Rect2i(30, 22, 1, 1))
	c.register_enemy("guild_house", "miss", Rect2i(31, 22, 1, 1))
	c.try_cast(h)
	c.cancel_channel()
	c.tick(0.79, h)
	_expect(c.damage_for_arena("guild_house") == 0, "Flask windup is not instant and release does not cancel it.")
	c.tick(0.01, h)
	_expect(c.damage_for_enemy("guild_house", "first") == 1 and c.damage_for_enemy("guild_house", "second") == 1 and c.damage_for_enemy("guild_house", "miss") == 0, "Ground impact hits every occupying footprint once, no adjacent splash.")
	c.tick(4.0, h)
	c.try_cast(h)
	c.register_enemy("guild_house", "first", Rect2i(40, 22, 6, 6))
	c.register_enemy("guild_house", "second", Rect2i(41, 22, 1, 1))
	c.tick(0.8, h)
	_expect(c.damage_for_arena("guild_house") == 2, "Flask keeps its ground cell; moving targets can leave before impact.")


func _check_channel() -> void:
	var f := _fixture("cardinal")
	var c: RefCounted = f.combat
	var h: ArenicHeroState = f.hero
	c.register_enemy("guild_house", "boss", BOSS)
	c.register_ally("guild_house", "hero", h.cell, 0, 3, PackedStringArray(["slow"]))
	c.try_cast(h)
	_expect(c.is_channeling() and is_inf(c.active_remaining()), "Sacrifice remains active until a control cancellation.")
	c.tick(0.99, h)
	_expect(c.damage_for_arena("guild_house") == 0, "Channel first tick is after one second.")
	c.tick(0.01, h)
	c.tick(2.0, h)
	_expect(c.damage_for_arena("guild_house") == 3, "Channel catches up each one-second hit, including exact boundaries.")
	_expect(c.ally_status("guild_house", "hero").health == 0, "Support health does not gate normalized combat or invent a life cost.")
	c.cancel_channel()
	c.tick(10.0, h)
	_expect(not c.is_channeling() and c.damage_for_arena("guild_house") == 3, "Release stops the channel and future ticks.")
	c.try_cast(h)
	h.cell.x += 1
	c.tick(1.0, h)
	_expect(not c.is_channeling() and c.damage_for_arena("guild_house") == 3, "Movement cancels before a due hit.")
	c.try_cast(h)
	h.arena_id = "sanctum"
	c.tick(1.0, h)
	_expect(not c.is_channeling() and c.damage_for_arena("guild_house") == 3 and c.damage_for_arena("sanctum") == 0, "Arena change cancels before a due hit.")
	h.arena_id = "guild_house"
	c.try_cast(h)
	c.tick(130.0, h)
	_expect(c.damage_for_arena("guild_house") == 67, "Held-channel catchup is bounded to64 ticks per call.")
	c.tick(0.0, h)
	c.tick(0.0, h)
	_expect(c.damage_for_arena("guild_house") == 133, "Bounded catchup preserves all pending hit debt.")


func _check_cleanse() -> void:
	var f := _fixture("bard", Vector2i(10, 10))
	var c: RefCounted = f.combat
	var h: ArenicHeroState = f.hero
	var area: Rect2i = Combat.area_rect(h.cell, Vector2i(4, 4))
	_expect(area == Rect2i(9, 9, 4, 4), "Cleanse has exactly sixteen cells, biased positive for its even dimensions.")
	var expected_hits: int = 0
	for y: int in range(8, 14):
		for x: int in range(8, 14):
			var cell := Vector2i(x, y)
			var id := "%d,%d" % [x, y]
			c.register_enemy("guild_house", id, Rect2i(cell, Vector2i.ONE))
			c.register_ally("guild_house", id, cell, 1, 3, PackedStringArray(["slow", "poison"]))
			if area.has_point(cell):
				expected_hits += 1
	c.register_enemy("sanctum", "remote", area)
	c.register_ally("guild_house", "hero", h.cell, 0, 1, PackedStringArray(["stun"]))
	c.try_cast(h)
	_expect(c.damage_for_arena("guild_house") == expected_hits and expected_hits == 16, "Cleanse damages all sixteen occupied area cells once.")
	_expect(c.damage_for_arena("sanctum") == 0, "Cleanse cannot affect another arena.")
	for y: int in range(8, 14):
		for x: int in range(8, 14):
			var inside: bool = area.has_point(Vector2i(x, y))
			var status: Dictionary = c.ally_status("guild_house", "%d,%d" % [x, y])
			_expect(status.health == (2 if inside else 1) and status.debuffs.is_empty() == inside, "Cleanse heals one and clears debuffs only inside exact area.")
	_expect(c.ally_status("guild_house", "hero").health == 1, "Caster support can be healed from zero.")
	c.tick(4.0, h)
	c.try_cast(h)
	_expect(c.ally_status("guild_house", "hero").health == 1, "Healing never exceeds support health cap.")
	var copy: Dictionary = c.ally_status("guild_house", "hero")
	copy.health = 99
	_expect(c.ally_status("guild_house", "hero").health == 1, "Support readback cannot mutate authoritative state.")
	for edge: Vector2i in [Vector2i.ZERO, Vector2i(65, 30)]:
		var bounds: Rect2i = Combat.area_rect(edge, Vector2i(4, 4))
		_expect(bounds.size == Vector2i(4, 4) and bounds.has_point(edge) and ArenicGridMath.tile_valid(bounds.position) and ArenicGridMath.tile_valid(bounds.end - Vector2i.ONE), "Cleanse retains exact4x4 size at arena borders.")


func _check_fortune() -> void:
	var f := _fixture("merchant", Vector2i(10, 10))
	var c: RefCounted = f.combat
	var h: ArenicHeroState = f.hero
	c.register_enemy("guild_house", "diagonal", Rect2i(12, 12, 1, 1))
	c.register_enemy("guild_house", "outside", Rect2i(13, 12, 1, 1))
	c.register_enemy("sanctum", "remote", Rect2i(12, 12, 1, 1))
	c.register_ally("guild_house", "ally", Vector2i(8, 8))
	c.register_ally("guild_house", "far", Vector2i(7, 8))
	c.try_cast(h)
	_expect(not c.try_cast(h).is_empty() and c.active_remaining() == 20.0, "Fortune does not stack or reset on recast.")
	c.tick(0.99, h)
	_expect(c.damage_for_arena("guild_house") == 0, "Fortune does not add an extra time-zero hit.")
	c.cancel_channel()
	c.tick(0.01, h)
	_expect(c.damage_for_enemy("guild_house", "diagonal") == 1 and c.damage_for_enemy("guild_house", "outside") == 0, "Radius two includes diagonal boundary and excludes radius three.")
	_expect(is_equal_approx(c.fortune_loot_bonus(), 0.05), "Nearby ally data hook excludes self and distant allies.")
	c.tick(19.0, h)
	_expect(c.damage_for_enemy("guild_house", "diagonal") == 20 and c.active_remaining() == 0.0, "Fortune produces exactly twenty one-second ticks, including its endpoint.")
	_expect(c.fortune_loot_bonus() == 0.0, "Temporary loot bonus clears when aura ends.")
	c.tick(100.0, h)
	_expect(c.damage_for_enemy("guild_house", "diagonal") == 20 and c.damage_for_arena("sanctum") == 0, "Expired aura adds no further damage or remote hits.")
	c.try_cast(h)
	c.tick(1.0, h)
	h.arena_id = "sanctum"
	c.tick(2.0, h)
	_expect(c.damage_for_enemy("guild_house", "diagonal") == 21 and c.damage_for_enemy("sanctum", "remote") == 2, "Active aura follows caster across arena boundaries, never hitting the old arena.")
	h.cell = Vector2i(30, 15)
	c.tick(1.0, h)
	_expect(c.damage_for_enemy("sanctum", "remote") == 2, "Aura range follows movement each tick.")
	f = _fixture("merchant", Vector2i(10, 10))
	c = f.combat
	h = f.hero
	c.register_enemy("guild_house", "boss", Rect2i(12, 12, 1, 1))
	c.try_cast(h)
	for index: int in range(200):
		c.tick(0.1, h)
	_expect(c.damage_for_arena("guild_house") == 20 and c.active_remaining() == 0.0, "Fractional simulation steps have the same twenty ticks as one large step.")
	c.tick(20.0, h)
	c.try_cast(h)
	c.tick(1000000.0, h)
	_expect(c.damage_for_arena("guild_house") == 40, "Large delta clamps finite aura at its twenty-second lifetime.")


func _check_progress_and_registration() -> void:
	var f := _fixture("hunter")
	var c: RefCounted = f.combat
	var h: ArenicHeroState = f.hero
	var world: ArenicWorldDefinition = f.world
	c.register_enemy("guild_house", "boss", BOSS)
	var hits: Array = []
	var progress: Array = []
	c.damage_applied.connect(func(arena: String, enemy: String, amount: int): hits.append([arena, enemy, amount]))
	c.progress_changed.connect(func(arena: String): progress.append(arena))
	for index: int in range(43):
		c.try_cast(h)
		c.tick(2.5, h)
	_expect(c.damage_for_arena("guild_house") == 43 and c.completed_phases("guild_house") == 2 and c.damage_in_phase("guild_house") == 3, "Absolute cumulative damage carries through multiple twenty-damage phases.")
	c.configure(world)
	c.configure(world)
	c.register_enemy("guild_house", "boss", BOSS, "s")
	_expect(c.damage_for_enemy("guild_house", "boss") == 43 and c.damage_for_arena("guild_house") == 43, "Stage/configuration and target re-registration preserve totals.")
	c.register_enemy("sanctum", "boss", BOSS)
	h.arena_id = "sanctum"
	c.try_cast(h)
	c.tick(2.5, h)
	_expect(c.damage_for_arena("sanctum") == 1 and c.damage_for_arena("guild_house") == 43, "Identical enemy IDs in different arenas have independent totals.")
	_expect(hits.size() == 44 and progress.size() == 44, "Every normalized hit publishes exactly one damage and progress signal.")
	for hit: Array in hits:
		_expect(hit[2] == 1, "Each damage signal carries a normalized one-point hit.")
	world.arenas[1].set("phase_damage", 7)
	c.configure(world)
	_expect(c.completed_phases("guild_house") == 6 and c.damage_in_phase("guild_house") == 1, "Authored absolute phase threshold is independent per arena.")
	_expect(c.enemy_footprint("guild_house", "boss") == BOSS and c.is_occupied("guild_house", Vector2i(35, 27)), "Occupancy covers last occupied footprint cell.")
	_expect(not c.is_occupied("guild_house", Vector2i(36, 27)) and not c.is_occupied("guild_house", Vector2i(35, 28)), "Occupancy excludes both end edges.")


func _check_invalid_inputs() -> void:
	var f := _fixture("hunter")
	var c: RefCounted = f.combat
	var h: ArenicHeroState = f.hero
	c.register_enemy("guild_house", "invalid", Rect2i(-1, 0, 2, 2))
	c.register_enemy("guild_house", "empty", Rect2i(2, 2, 0, 1))
	c.register_enemy("missing", "remote", BOSS)
	_expect(not c.try_cast(h).is_empty() and c.cooldown_remaining() == 0.0, "Malformed and remote targets are not registered.")
	_expect(not c.try_cast(null).is_empty(), "Missing hero returns an explicit reason.")
	c.register_enemy("guild_house", "boss", BOSS)
	c.try_cast(h)
	for delta: float in [-1.0, INF, -INF, NAN]:
		c.tick(delta, h)
		_expect(c.damage_for_arena("guild_house") == 0 and c.cooldown_remaining() == 2.5 and c.active_remaining() == 0.75, "Invalid time cannot change an accepted cast.")
	c.tick(2.5, h)
	h.definition.skills[0].cooldown_seconds = NAN
	_expect(not c.try_cast(h).is_empty(), "Invalid authored timing is rejected explicitly.")
	_expect(c.damage_for_arena("unknown") == 0 and c.damage_for_enemy("unknown", "missing") == 0 and c.enemy_footprint("unknown", "missing") == Rect2i(), "Unknown readback is safe and side-effect free.")


func _check_active_handoff() -> void:
	var f := _fixture("hunter")
	var c: RefCounted = f.combat
	var h: ArenicHeroState = f.hero
	c.register_enemy("guild_house", "boss", BOSS)
	_expect(c.active_cast_snapshot().is_empty(), "Idle combat has no presentation handoff.")
	c.try_cast(h)
	c.tick(0.3, h)
	var before: Dictionary = c.active_cast_snapshot()
	c.configure(f.world)
	c.register_enemy("guild_house", "boss", BOSS)
	_expect(c.active_cast_snapshot() == before, "Reconfiguration preserves authoritative projectile timing and geometry.")
	_expect(before.ability_id == "auto_shot" and before.arena_id == "guild_house" and before.origin == Vector2i(30, 15) and before.target_cell == Vector2i(30, 22) and before.facing == "n" and is_equal_approx(before.remaining, 0.45), "Projectile handoff identifies exact in-flight state.")
	before.origin = Vector2i.ZERO
	_expect(c.active_cast_snapshot().origin == Vector2i(30, 15), "Presenter snapshot cannot mutate authoritative origin.")
	c.tick(0.45, h)
	_expect(c.damage_for_arena("guild_house") == 1 and c.active_cast_snapshot().is_empty(), "Restoring a presenter neither restarts nor duplicates the pending hit.")
	f = _fixture("merchant")
	c = f.combat
	h = f.hero
	c.try_cast(h)
	c.tick(4.25, h)
	h.arena_id = "sanctum"
	h.cell = Vector2i(5, 6)
	c.configure(f.world)
	var aura: Dictionary = c.active_cast_snapshot()
	_expect(aura.ability_id == "fortune" and aura.arena_id == "sanctum" and aura.origin == h.cell and aura.target_cell == h.cell and aura.elapsed == 4.25 and aura.remaining == 15.75, "Fortune handoff follows current caster location and retains remaining duration.")
	c.cancel_channel()
	_expect(c.active_cast_snapshot() == aura, "Channel cancellation cannot erase Fortune during stage replacement.")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _phase_log(combat: RefCounted) -> Array:
	var events: Array = []
	combat.ability_phase.connect(func(ability: String, phase: String, arena: String, cell: Vector2, cast_id: int): events.append({"ability": ability, "phase": phase, "arena": arena, "cell": cell, "cast_id": cast_id}))
	return events


func _phase_names(events: Array) -> Array[String]:
	var names: Array[String] = []
	for event: Dictionary in events:
		names.append(event.phase)
	return names


func _check_release_phases() -> void:
	var f := _fixture("hunter")
	var c: RefCounted = f.combat
	var h: ArenicHeroState = f.hero
	var events: Array = _phase_log(c)
	_expect(not c.try_cast(h).is_empty() and events.is_empty(), "Rejected casts publish no lifecycle events.")
	c.register_enemy("guild_house", "boss", BOSS)
	c.try_cast(h)
	_expect(_phase_names(events) == ["charge"] and events[0].cast_id == 1, "First accepted cast starts one charge with ID1; rejection consumed no ID.")
	var charging: Dictionary = c.active_cast_snapshot()
	_expect(charging.cast_id == 1 and not charging.released and charging.release_seconds == 0.26, "Charging snapshot identifies its loop without replaying a cast.")
	c.configure(f.world)
	_expect(c.active_cast_snapshot() == charging and events.size() == 1, "Stage reconfiguration emits nothing and preserves charging identity.")
	c.tick(0.25, h)
	_expect(_phase_names(events) == ["charge"], "Charge stays active until its actual release boundary.")
	c.tick(0.01, h)
	_expect(_phase_names(events) == ["charge", "cast"] and c.damage_for_arena("guild_house") == 0, "Actual release precedes landing and does not deal damage.")
	var released: Dictionary = c.active_cast_snapshot()
	_expect(released.released and released.cast_id == 1 and released.release_seconds == 0.26, "Released snapshot distinguishes a flight from a charging loop.")
	c.configure(f.world)
	c.tick(0.49, h)
	_expect(_phase_names(events) == ["charge", "cast", "impact", "end"], "Projectile sound phases remain ordered across snapshot restoration.")
	_expect(events[2].cell == Vector2(32.5, 24.5), "Impact uses the precise occupied-cell boss center, including half cells.")
	for event: Dictionary in events:
		_expect(event.ability == "auto_shot" and event.arena == "guild_house" and event.cast_id == 1, "Every phase retains its accepted-cast identity.")
	c.try_cast(h)
	_expect(events.size() == 4, "Cooldown rejection produces no sound lifecycle event.")
	c.tick(1.75, h)
	c.try_cast(h)
	_expect(events[-1].phase == "charge" and events[-1].cast_id == 2, "Next accepted cast receives the next monotonic ID.")
	c.tick(0.1, null)
	_expect(_phase_names(events).slice(4) == ["charge", "cancel"] and c.active_cast_snapshot().is_empty(), "Interrupted windup stops its charge without release or impact.")
	c.tick(5.0, h)
	_expect(events.size() == 6, "An interrupted charge cannot release later.")


func _check_fast_phases_and_misses() -> void:
	var f := _fixture("hunter")
	var c: RefCounted = f.combat
	var h: ArenicHeroState = f.hero
	var events: Array = _phase_log(c)
	h.definition.skills[0].cast_seconds = 0.01
	c.register_enemy("guild_house", "boss", BOSS)
	c.try_cast(h)
	_expect(c.active_cast_snapshot().release_seconds == 0.01, "Release delay cannot outlast a shortened projectile hit time.")
	c.tick(1.0, h)
	_expect(_phase_names(events) == ["charge", "cast", "impact", "end"] and c.damage_for_arena("guild_house") == 1, "One large step delivers release and impact in order without polling losses.")
	f = _fixture("hunter")
	c = f.combat
	h = f.hero
	events = _phase_log(c)
	h.definition.skills[0].cast_seconds = 0.0
	c.register_enemy("guild_house", "boss", BOSS)
	c.try_cast(h)
	_expect(_phase_names(events) == ["cast", "impact", "end"] and c.damage_for_arena("guild_house") == 1, "A zero-time cast delivers cast then impact synchronously with no charge.")
	f = _fixture("warrior", Vector2i(30, 21))
	c = f.combat
	h = f.hero
	events = _phase_log(c)
	c.register_enemy("guild_house", "boss", BOSS)
	c.try_cast(h)
	h.cell = Vector2i(10, 10)
	c.tick(0.35, h)
	_expect(_phase_names(events) == ["cast", "end"] and c.damage_for_arena("guild_house") == 0, "A melee miss emits no phantom impact.")
	f = _fixture("alchemist")
	c = f.combat
	h = f.hero
	events = _phase_log(c)
	c.register_enemy("guild_house", "boss", BOSS)
	c.try_cast(h)
	c.register_enemy("guild_house", "boss", Rect2i(40, 22, 6, 6))
	c.tick(0.8, h)
	_expect(_phase_names(events) == ["charge", "cast", "end"] and c.damage_for_arena("guild_house") == 0, "An empty ground impact produces no phantom target-hit sound.")
	c.tick(5.0, h)
	h.definition.skills[0].release_seconds = NAN
	var before: int = events.size()
	_expect(not c.try_cast(h).is_empty() and events.size() == before, "Invalid authored release timing is rejected without events.")


func _check_channel_aura_phases() -> void:
	var f := _fixture("cardinal")
	var c: RefCounted = f.combat
	var h: ArenicHeroState = f.hero
	var events: Array = _phase_log(c)
	c.register_enemy("guild_house", "boss", BOSS)
	c.try_cast(h)
	_expect(_phase_names(events) == ["cast", "sustain"] and c.active_cast_snapshot().released, "Channel activation starts its sustain after immediate release.")
	c.tick(2.0, h)
	c.cancel_channel()
	_expect(_phase_names(events) == ["cast", "sustain", "impact", "impact", "cancel"], "Channel release cancels sustain after its actual one-second hits.")
	c.cancel_channel()
	c.tick(5.0, h)
	_expect(events.size() == 5, "Repeated release and later simulation cannot restart a channel loop.")
	c.try_cast(h)
	h.cell.x += 1
	c.tick(1.0, h)
	_expect(_phase_names(events).slice(5) == ["cast", "sustain", "cancel"], "Movement interruption ends sustain before a due hit.")
	f = _fixture("merchant", Vector2i(10, 10))
	c = f.combat
	h = f.hero
	events = _phase_log(c)
	c.register_enemy("guild_house", "boss", Rect2i(12, 12, 1, 1))
	c.try_cast(h)
	_expect(_phase_names(events) == ["cast", "sustain"], "Fortune starts a sustain without a time-zero impact.")
	c.tick(20.0, h)
	_expect(events.size() == 23 and events[-1].phase == "end", "Fortune emits cast, sustain, twenty impacts, then ordinary expiry.")
	for index: int in range(2, 22):
		_expect(events[index].phase == "impact" and events[index].ability == "fortune" and events[index].cast_id == 1 and events[index].cell == Vector2(12, 12), "Every actual Fortune hit is delivered individually to the observer.")
	c.tick(100.0, h)
	_expect(events.size() == 23 and c.damage_for_arena("guild_house") == 20, "Aura expiry stops its loop and all further impacts.")


func _check_support_phases() -> void:
	var f := _fixture("bard", Vector2i(10, 10))
	var c: RefCounted = f.combat
	var h: ArenicHeroState = f.hero
	var events: Array = _phase_log(c)
	c.register_ally("guild_house", "hero", h.cell, 0, 1, PackedStringArray(["slow"]))
	c.register_enemy("guild_house", "enemy", Rect2i(11, 11, 1, 1))
	c.try_cast(h)
	_expect(_phase_names(events) == ["cast", "impact", "impact", "end"], "Instant Cleanse synchronously reports both damage and support application.")
	_expect(events[1].cell == Vector2(11, 11) and events[2].cell == Vector2(10, 10), "Support and enemy impacts use their actual application cells.")
	for event: Dictionary in events:
		_expect(event.ability == "cleanse" and event.cast_id == 1, "Instant Cleanse carries explicit identity without an active-cast slot.")
	_expect(c.active_cast_snapshot().is_empty() and c.ally_status("guild_house", "hero").health == 1 and c.ally_status("guild_house", "hero").debuffs.is_empty(), "Lifecycle events do not change instant support rules.")
	f = _fixture("bard", Vector2i(10, 10))
	c = f.combat
	h = f.hero
	events = _phase_log(c)
	c.register_ally("guild_house", "full", Vector2i(11, 11), 1, 1, PackedStringArray(["poison"]))
	c.try_cast(h)
	_expect(_phase_names(events) == ["cast", "impact", "end"], "Clearing a debuff at full health is still a real support application.")
	c.tick(4.0, h)
	c.try_cast(h)
	_expect(_phase_names(events).slice(3) == ["cast", "end"] and events[-1].cast_id == 2, "A fully healthy, clean, empty area has no phantom impact; accepted cast IDs still advance.")
