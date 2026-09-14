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
	_check_projectile_speed()
	_check_melee()
	_check_dig()
	_check_backstab()
	_check_ground()
	_check_channel()
	_check_channel_presentation_pose()
	_check_cleanse()
	_check_cleanse_dots()
	_check_cleanse_dot_stacking()
	_check_cleanse_dot_capacity()
	_check_fortune()
	_check_progress_and_registration()
	_check_damage_attribution()
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
	_expect(c.cooldown_remaining(h) == 0.0 and c.active_remaining(h) == 0.0, "Availability lookup is read-only.")
	var signals: Array = []
	var casters: Array = []
	c.ability_cast.connect(func(caster: String, id: String, arena: String, origin: Vector2i, target: Vector2i, facing: String):
		signals.append([id, arena, origin, target, facing])
		casters.append(caster))
	_expect(c.try_cast(h).is_empty(), "Hunter starts its shot.")
	_expect(signals == [["auto_shot", "guild_house", Vector2i(30, 15), Vector2i(30, 22), "n"]], "Cast signal gives windup, footprint edge target and correct facing.")
	_expect(casters == [h.ally_id()], "The cast signal names the caster, so a presenter animates the right hero.")
	_expect(c.damage_for_arena("guild_house") == 0, "Projectile does not deal damage at launch.")
	c.tick(0.6875, h)
	_expect(c.damage_for_arena("guild_house") == 0, "Hunter hit waits for landing.")
	c.tick(0.01, h)
	_expect(c.damage_for_arena("guild_house") == 1 and c.active_remaining(h) == 0.0, "Seven-tile Hunter shot lands after 0.26 seconds plus 7/16 seconds of flight.")
	_expect(not c.try_cast(h).is_empty(), "Cooldown remains after a shot lands.")
	c.tick(1.8025, h)
	_expect(c.cooldown_remaining(h) == 0.0, "Hunter can shoot again at2.5 seconds.")
	h.cell = Vector2i(30, 13)
	_expect(not c.try_cast(h).is_empty() and c.cooldown_remaining(h) == 0.0, "Outside edge range rejects without spending cooldown.")
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


## Dig is not a melee attack: it needs no target, no adjacency and no range, and
## it deals no damage by itself. What it does to the ground is the dig field's,
## and dig_checks covers that.
func _check_dig() -> void:
	var f := _fixture("forager", Vector2i(4, 4))
	var c: RefCounted = f.combat
	var h: ArenicHeroState = f.hero
	c.register_enemy("guild_house", "boss", BOSS)
	_expect(h.definition.skills[0].effect_kind == "dig", "The Forager's starter places ground.")
	_expect(c.cast_unavailable_reason(h).is_empty(), "Dig is available with no enemy anywhere near.")
	var seen: Array = []
	c.ability_cast.connect(func(caster: String, id: String, arena: String, origin: Vector2i, target: Vector2i, facing: String):
		seen.append([id, arena, origin]))
	_expect(c.try_cast(h).is_empty(), "Dig casts from open ground.")
	_expect(seen == [["dig", "guild_house", Vector2i(4, 4)]], "It publishes the tile underfoot, which is what breaks the ground.")
	_expect(c.damage_for_arena("guild_house") == 0, "And deals no damage on its own.")
	_expect(c.active_cast_snapshot(h).is_empty(), "Dig is instant: it leaves nothing in flight.")
	_expect(not c.try_cast(h).is_empty() and c.cooldown_remaining(h) > 0.0, "It still spends a cooldown like any other cast.")
	c.tick(2.0, h)
	h.cell = Vector2i(30, 22)
	_expect(c.try_cast(h).is_empty(), "Standing inside a target is no obstacle to digging.")


func _check_melee() -> void:
	for class_id: String in ["warrior"]:
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
		c.tick(0.29, h)
		_expect(not c.try_cast(h).is_empty(), "Backstab rejects a repeat before 0.5 seconds.")
		c.tick(0.01, h)
		_expect(is_zero_approx(c.cooldown_remaining(h)) and c.try_cast(h).is_empty(), "Backstab is ready exactly 0.5 seconds after cast start.")
		c.tick(0.2, h)
		_expect(c.damage_for_arena("guild_house") == 2, "The next Backstab still has its own 0.2-second windup.")
		c.tick(0.3, h)
		for cell: Vector2i in [positions[facing][1], positions[facing][2]]:
			h.cell = cell
			_expect(not c.try_cast(h).is_empty(), "Backstab rejects front/side for facing " + facing)
		_expect(c.damage_for_arena("guild_house") == 2, "Rejected backstabs do not damage.")
		h.cell = positions[facing][0]
		c.try_cast(h)
		var opposite: String = {"n": "s", "s": "n", "e": "w", "w": "e"}[facing]
		c.register_enemy("guild_house", "boss", BOSS, opposite)
		c.tick(0.2, h)
		_expect(c.damage_for_arena("guild_house") == 2, "Target turning during windup defeats the backstab.")


## The flask is aimed, not targeted, and what it leaves behind does the work.
## What the pool then does to whoever stands in it is the acid field's, and
## dig_checks covers that.
func _check_ground() -> void:
	var f := _fixture("alchemist", Vector2i(30, 18))
	var c: RefCounted = f.combat
	var h: ArenicHeroState = f.hero
	c.register_enemy("guild_house", "first", BOSS)
	h.facing = "n"
	var landings: Array = []
	c.ability_landed.connect(func(caster: String, id: String, arena: String, area: Rect2i, rules: ArenicClassAbility):
		landings.append([id, arena, area]))
	_expect(c.cast_unavailable_reason(h).is_empty(), "A flask needs no target in range.")
	_expect(c.try_cast(h).is_empty(), "It throws from open ground.")
	c.cancel_channel(h)
	c.tick(0.79, h)
	_expect(landings.is_empty() and c.damage_for_arena("guild_house") == 0, "Flask flight is not instant and release does not cancel it.")
	c.tick(0.01, h)
	# Thrown north three tiles from (30,18), so the 3x3 is centred on (30,21).
	_expect(landings == [["acid_flask", "guild_house", Rect2i(29, 20, 3, 3)]], "It lands three tiles along the facing, as a three-by-three.")
	_expect(c.damage_for_arena("guild_house") == 0, "The impact itself deals no damage; the pool does.")
	_expect(c.active_cast_snapshot(h).is_empty(), "And the flask is spent once it lands.")
	# Aim is taken at CAST time, so a target that wanders off is simply missed.
	c.tick(4.0, h)
	h.facing = "e"
	c.try_cast(h)
	h.facing = "w"
	c.tick(0.8, h)
	_expect(Rect2i(landings[1][2]).position.x > 30, "The throw keeps the facing it was cast with, not the one it lands with.")


func _check_channel() -> void:
	var f := _fixture("cardinal")
	var c: RefCounted = f.combat
	var h: ArenicHeroState = f.hero
	c.register_enemy("guild_house", "boss", BOSS)
	c.register_ally("guild_house", "hero", h.cell, 0, 3, PackedStringArray(["slow"]))
	c.try_cast(h)
	_expect(c.is_channeling(h) and is_inf(c.active_remaining(h)), "Sacrifice remains active until a control cancellation.")
	c.tick(0.99, h)
	_expect(c.damage_for_arena("guild_house") == 0, "Channel first tick is after one second.")
	c.tick(0.01, h)
	c.tick(2.0, h)
	_expect(c.damage_for_arena("guild_house") == 3, "Channel catches up each one-second hit, including exact boundaries.")
	_expect(c.ally_status("guild_house", "hero").health == 0, "Support health does not gate normalized combat or invent a life cost.")
	c.cancel_channel(h)
	c.tick(10.0, h)
	_expect(not c.is_channeling(h) and c.damage_for_arena("guild_house") == 3, "Release stops the channel and future ticks.")
	c.try_cast(h)
	h.cell.x += 1
	c.tick(1.0, h)
	_expect(not c.is_channeling(h) and c.damage_for_arena("guild_house") == 3, "Movement cancels before a due hit.")
	c.try_cast(h)
	h.arena_id = "sanctum"
	c.tick(1.0, h)
	_expect(not c.is_channeling(h) and c.damage_for_arena("guild_house") == 3 and c.damage_for_arena("sanctum") == 0, "Arena change cancels before a due hit.")
	h.arena_id = "guild_house"
	c.try_cast(h)
	c.tick(130.0, h)
	_expect(c.damage_for_arena("guild_house") == 67, "Held-channel catchup is bounded to64 ticks per call.")
	c.tick(0.0, h)
	c.tick(0.0, h)
	_expect(c.damage_for_arena("guild_house") == 133, "Bounded catchup preserves all pending hit debt.")


func _check_channel_presentation_pose() -> void:
	var fixture: Dictionary = _fixture("cardinal")
	var combat: RefCounted = fixture.combat
	var hero: ArenicHeroState = fixture.hero
	combat.register_enemy("guild_house", "boss", BOSS)
	combat.try_cast(hero)
	var accepted: Dictionary = combat.active_cast_snapshot(hero)
	_expect(accepted.target_id == "boss", "Channel handoff preserves the actual accepted target identity.")
	var pose: Dictionary = combat.enemy_presentation_pose("guild_house", "boss")
	_expect(pose.center == Vector2(32.5, 24.5) and pose.lift == 0.0, "An ordinary enemy attaches at its even-footprint center.")
	pose.center = Vector2.ZERO
	_expect(combat.enemy_presentation_pose("guild_house", "boss").center == Vector2(32.5, 24.5), "Presentation poses cannot mutate the enemy ledger.")
	var moving: Dictionary = {"center": Vector2(37.5, 19.5), "lift": 4.0, "footprint": Rect2i(35, 17, 6, 6), "airborne": true}
	combat.enemy_pose_lookup = func(_arena: String, _enemy: String) -> Dictionary: return moving
	_expect(combat.enemy_presentation_pose("guild_house", "boss").center == moving.center and combat.enemy_presentation_pose("guild_house", "boss").lift == 4.0, "The same target follows its derived airborne center and lift.")
	_expect(combat.enemy_footprint("guild_house", "boss").size == Vector2i.ZERO, "Visual attachment never makes an airborne boss hittable.")
	combat.tick(1.0, hero)
	_expect(combat.damage_for_arena("guild_house") == 0 and combat.is_channeling(hero), "The channel stays held through a jump without awarding an airborne tick.")
	moving.airborne = false
	moving.lift = 0.0
	combat.tick(1.0, hero)
	_expect(combat.damage_for_arena("guild_house") == 1 and combat.active_cast_snapshot(hero).target_id == "boss", "Landing resumes the existing channel tick on its original identity.")
	_expect(combat.active_cast_snapshot(hero).target_cell == accepted.target_cell, "Derived beam motion leaves accepted cast geometry unchanged.")
	_expect(combat.enemy_presentation_pose("guild_house", "missing").is_empty(), "Missing target identities never inherit another enemy's pose.")


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


func _check_cleanse_dots() -> void:
	var fixture: Dictionary = _fixture("bard", Vector2i(10, 10))
	var combat: RefCounted = fixture.combat
	var hero: ArenicHeroState = fixture.hero
	combat.register_enemy("guild_house", "large", Rect2i(11, 10, 6, 6))
	combat.register_enemy("guild_house", "outside", Rect2i(13, 9, 1, 1))
	combat.register_enemy("sanctum", "remote", Rect2i(11, 10, 1, 1))
	var phases: Array = []
	var casts: Array = []
	var reports: Array = []
	combat.ability_cast.connect(func(caster: String, ability: String, arena: String, _origin: Vector2i, _target: Vector2i, _facing: String): casts.append([caster, ability, arena]))
	combat.ability_phase.connect(func(_caster: String, _ability: String, phase: String, _arena: String, _cell: Vector2, _serial: int): phases.append(phase))
	combat.damage_reported.connect(func(caster: String, ability: String, arena: String, enemy: String, amount: int): reports.append([caster, ability, arena, enemy, amount]))
	_expect(combat.try_cast(hero).is_empty(), "Cleanse accepts a large intersecting enemy.")
	_expect(combat._enemy_dots.size() == 1 and combat.damage_for_arena("guild_house") == 1, "A footprint gets one initial hit and one DOT stack, regardless of intersecting cell count.")
	_expect(combat._enemy_dots[0].remaining_ticks == 300 and combat._enemy_dots[0].interval_ticks == 60 and combat._enemy_dots[0].tick_debt == 0 and combat._enemy_dots[0].damage == 1, "Authored five-second Cleanse freezes 300 ticks and a 60-tick interval.")
	var initial_phases: Array = phases.duplicate()
	combat.tick(20.0, hero)
	for _tick: int in range(60):
		combat.advance_enemy_dots("sanctum")
	_expect(combat._enemy_dots[0].remaining_ticks == 300 and combat.damage_for_arena("guild_house") == 1, "Combat delta and another arena's clock cannot advance an attached DOT.")
	for _tick: int in range(59):
		combat.advance_enemy_dots("guild_house")
	_expect(combat.damage_for_enemy("guild_house", "large") == 1 and combat._enemy_dots[0].tick_debt == 59, "The first DOT hit waits for exactly one arena second.")
	combat.advance_enemy_dots("guild_house")
	_expect(combat.damage_for_enemy("guild_house", "large") == 2 and combat._enemy_dots[0].tick_debt == 0, "The sixtieth arena tick applies the first attached hit.")
	for _tick: int in range(239):
		combat.advance_enemy_dots("guild_house")
	_expect(combat.damage_for_enemy("guild_house", "large") == 5 and combat._enemy_dots[0].remaining_ticks == 1, "A stack has four periodic hits immediately before its five-second endpoint.")
	combat.advance_enemy_dots("guild_house")
	_expect(combat.damage_for_enemy("guild_house", "large") == 6 and combat._enemy_dots.is_empty(), "The final due hit occurs at expiry, then the stack is removed.")
	for _tick: int in range(60):
		combat.advance_enemy_dots("guild_house")
	_expect(combat.damage_for_enemy("guild_house", "large") == 6 and reports.size() == 6, "An expired stack cannot deal a sixth periodic hit.")
	_expect(combat.damage_for_enemy("guild_house", "outside") == 0 and combat.damage_for_arena("sanctum") == 0, "DOT application never extends the area or crosses arena identity.")
	_expect(casts.size() == 1 and phases == initial_phases, "Periodic damage emits no fresh cast, impact animation or cast sound phase.")
	var attribution_matches: bool = true
	for report: Array in reports:
		attribution_matches = attribution_matches and report == [hero.ally_id(), "cleanse", "guild_house", "large", 1]
	_expect(attribution_matches, "Every initial and periodic hit reports the original caster, ability and target.")
	_expect(combat.enemy_dot_effects("guild_house", "large").is_empty(), "The readout disappears when the last real stack expires.")


func _check_cleanse_dot_stacking() -> void:
	var fixture: Dictionary = _fixture("bard", Vector2i(10, 10))
	var combat: RefCounted = fixture.combat
	var first: ArenicHeroState = fixture.hero
	first.identity_id = 3
	var second := ArenicHeroState.new()
	second.identity_id = 9
	second.definition = first.definition
	second.cell = first.cell
	var ability: ArenicClassAbility = first.definition.skills[0]
	combat.register_enemy("guild_house", "boss", Rect2i(11, 10, 1, 1))
	var reports: Array = []
	combat.damage_reported.connect(func(caster: String, attack: String, arena: String, enemy: String, amount: int): reports.append([caster, attack, arena, enemy, amount]))
	_expect(combat.try_cast(first).is_empty(), "The first Bard applies its own stack.")
	for _tick: int in range(60):
		combat.advance_enemy_dots("guild_house")
	_expect(combat.try_cast(second).is_empty(), "A second Bard stacks Cleanse without resetting the first Bard's timer.")
	_expect(combat._enemy_dots.size() == 2 and combat._enemy_dots[0].remaining_ticks == 240 and combat._enemy_dots[1].remaining_ticks == 300, "Staggered casts retain independent expiry ticks in acceptance order.")
	var effects: Array[Dictionary] = combat.enemy_dot_effects("guild_house", "boss")
	_expect(effects.size() == 1 and effects[0].id == "cleanse" and effects[0].name == "Cleanse" and effects[0].stacks == 2 and not effects[0].beneficial and effects[0].remaining_seconds == 4.0, "The derived row groups the actual ability and shows its next expiry.")
	effects[0].stacks = 99
	_expect(combat.enemy_dot_effects("guild_house", "boss")[0].stacks == 2, "HUD projection mutation cannot change real stack state.")
	first.arena_id = "sanctum"
	second.arena_id = "sanctum"
	first.cell = Vector2i(1, 1)
	second.cell = Vector2i(60, 29)
	combat.register_enemy("guild_house", "boss", Rect2i(40, 20, 1, 1))
	combat.enemy_pose_lookup = func(arena: String, _enemy: String) -> Dictionary:
		return {"airborne": true, "footprint": Rect2i(40, 20, 1, 1)} if arena == "guild_house" else {}
	ability.enemy_dot_duration_seconds = 1.0
	ability.enemy_dot_tick_seconds = 0.1
	ability.enemy_dot_damage = 7
	_expect(not combat.enemy_footprint("guild_house", "boss").has_area(), "The moved target is genuinely airborne and cannot accept a fresh ground hit.")
	for _tick: int in range(240):
		combat.advance_enemy_dots("guild_house")
	_expect(combat.damage_for_enemy("guild_house", "boss") == 11 and combat._enemy_dots.size() == 1 and combat._enemy_dots[0].caster_id == second.ally_id() and combat._enemy_dots[0].remaining_ticks == 60, "Movement, jumping and caster travel preserve both stacks; only the older stack expires.")
	_expect(combat._enemy_dots[0].interval_ticks == 60 and combat._enemy_dots[0].damage == 1, "Editing the shared ability cannot change already accepted DOT timing or damage.")
	for _tick: int in range(60):
		combat.advance_enemy_dots("guild_house")
	_expect(combat.damage_for_enemy("guild_house", "boss") == 12 and combat._enemy_dots.is_empty(), "Each caster contributes one immediate hit plus exactly five periodic hits.")
	var first_hits: int = 0
	var second_hits: int = 0
	var valid_reports: bool = true
	for report: Array in reports:
		first_hits += 1 if report[0] == first.ally_id() else 0
		second_hits += 1 if report[0] == second.ally_id() else 0
		valid_reports = valid_reports and report.slice(1) == ["cleanse", "guild_house", "boss", 1]
	_expect(first_hits == 6 and second_hits == 6 and valid_reports, "Stacked damage retains each remote caster's source attribution through expiry.")
	combat.tick(4.0, first)
	first.cell = Vector2i(10, 10)
	combat.register_enemy("sanctum", "new", Rect2i(11, 10, 1, 1))
	_expect(combat.try_cast(first).is_empty(), "A later cast accepts the edited Inspector settings.")
	_expect(combat._enemy_dots[0].remaining_ticks == 60 and combat._enemy_dots[0].interval_ticks == 6 and combat._enemy_dots[0].damage == 7, "Only a new stack freezes the new one-second, ten-hertz, seven-damage rules.")
	for _tick: int in range(60):
		combat.advance_enemy_dots("sanctum")
	_expect(combat.damage_for_enemy("sanctum", "new") == 71 and combat._enemy_dots.is_empty(), "Edited rules produce ten periodic hits plus the unchanged initial hit.")


func _check_cleanse_dot_capacity() -> void:
	var fixture: Dictionary = _fixture("bard", Vector2i(10, 10))
	var combat: RefCounted = fixture.combat
	var hero: ArenicHeroState = fixture.hero
	combat.register_enemy("guild_house", "first", Rect2i(12, 10, 1, 1))
	var all_accepted: bool = true
	for _stack: int in range(Combat.MAX_ENEMY_DOTS - 1):
		combat.reset_caster(hero)
		all_accepted = combat.try_cast(hero).is_empty() and all_accepted
	_expect(all_accepted and combat._enemy_dots.size() == Combat.MAX_ENEMY_DOTS - 1, "Real accepted casts can fill the bounded stack collection up to its last free entry.")
	combat.register_enemy("guild_house", "second", Rect2i(9, 9, 1, 1))
	combat.register_ally("guild_house", hero.ally_id(), hero.cell, 1, 3, PackedStringArray(["slow"]))
	combat.reset_caster(hero)
	var before_damage: int = combat.total_damage()
	var before_serial: int = combat._cast_serial
	_expect(combat.cast_unavailable_reason(hero, true) == "DOT limit" and not combat.try_cast(hero).is_empty(), "Two affected targets reject the whole cast when only one stack slot remains.")
	var status: Dictionary = combat.ally_status("guild_house", hero.ally_id())
	_expect(combat.total_damage() == before_damage and combat._cast_serial == before_serial and combat.cooldown_remaining(hero) == 0.0 and combat._enemy_dots.size() == Combat.MAX_ENEMY_DOTS - 1, "Capacity rejection spends no cooldown, initial damage, cast event or partial stack.")
	_expect(status.health == 1 and status.debuffs == PackedStringArray(["slow"]), "Capacity rejection cannot partially heal or clear ally debuffs.")
	hero.cell = Vector2i(11, 10)
	var other := ArenicHeroState.new()
	other.identity_id = 7
	other.definition = hero.definition
	other.cell = hero.cell
	var nested_results: Array[String] = []
	var weak_combat: WeakRef = weakref(combat)
	combat.ability_cast.connect(func(_caster: String, _ability: String, _arena: String, _origin: Vector2i, _target: Vector2i, _facing: String): nested_results.append(weak_combat.get_ref().try_cast(other)))
	_expect(combat.try_cast(hero).is_empty() and combat._enemy_dots.size() == Combat.MAX_ENEMY_DOTS, "One affected target fits the exact capacity boundary.")
	_expect(nested_results.size() == 1 and not nested_results[0].is_empty(), "Accepted stacks reserve capacity before cast observers can request another cast.")
	combat.reset_caster(hero)
	_expect(not combat.try_cast(hero).is_empty(), "The next stack is rejected at the full global bound.")
	combat.clear_enemy_dots("sanctum")
	_expect(combat._enemy_dots.size() == Combat.MAX_ENEMY_DOTS, "Clearing another arena cannot remove this arena's stacks.")
	combat.clear_enemy_dots("guild_house")
	_expect(combat._enemy_dots.is_empty() and combat.total_damage() == Combat.MAX_ENEMY_DOTS, "Cycle clearing frees every matching stack while retaining earned damage.")


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
	_expect(not c.try_cast(h).is_empty() and c.active_remaining(h) == 20.0, "Fortune does not stack or reset on recast.")
	c.tick(0.99, h)
	_expect(c.damage_for_arena("guild_house") == 0, "Fortune does not add an extra time-zero hit.")
	c.cancel_channel(h)
	c.tick(0.01, h)
	_expect(c.damage_for_enemy("guild_house", "diagonal") == 1 and c.damage_for_enemy("guild_house", "outside") == 0, "Radius two includes diagonal boundary and excludes radius three.")
	_expect(is_equal_approx(c.fortune_loot_bonus(h), 0.05), "Nearby ally data hook excludes self and distant allies.")
	c.tick(19.0, h)
	_expect(c.damage_for_enemy("guild_house", "diagonal") == 20 and c.active_remaining(h) == 0.0, "Fortune produces exactly twenty one-second ticks, including its endpoint.")
	_expect(c.fortune_loot_bonus(h) == 0.0, "Temporary loot bonus clears when aura ends.")
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
	_expect(c.damage_for_arena("guild_house") == 20 and c.active_remaining(h) == 0.0, "Fractional simulation steps have the same twenty ticks as one large step.")
	c.tick(20.0, h)
	c.try_cast(h)
	c.tick(1000000.0, h)
	_expect(c.damage_for_arena("guild_house") == 40, "Large delta clamps finite aura at its twenty-second lifetime.")


func _check_damage_attribution() -> void:
	var f := _fixture("hunter", Vector2i(29, 21))
	var c: RefCounted = f.combat
	var hunter: ArenicHeroState = f.hero
	var warrior: ArenicHeroState = _fixture("warrior", Vector2i(29, 21)).hero
	hunter.identity_id = 11
	warrior.identity_id = 12
	c.register_enemy("guild_house", "boss", BOSS)
	var reports: Array = []
	var legacy: Array = []
	c.damage_reported.connect(func(caster: String, ability: String, arena: String, enemy: String, amount: int): reports.append([caster, ability, arena, enemy, amount]))
	c.damage_applied.connect(func(arena: String, enemy: String, amount: int): legacy.append([arena, enemy, amount]))
	_expect(c.try_cast(hunter).is_empty() and c.try_cast(warrior).is_empty(), "Two independent casters can attack the same target.")
	c.tick(1.0)
	_expect(reports.size() == 2 and reports.has([hunter.ally_id(), "auto_shot", "guild_house", "boss", 1]) and reports.has([warrior.ally_id(), "bash", "guild_house", "boss", 1]), "Each accepted direct hit reports its own caster and attack, independent of selection.")
	_expect(legacy.size() == 2 and c.total_damage() == 2, "Attribution leaves the existing three-argument damage signal and totals unchanged.")
	c.apply_hazard_damage("guild_house", "boss", 3, hunter.ally_id(), "acid_flask")
	_expect(reports.back() == [hunter.ally_id(), "acid_flask", "guild_house", "boss", 3] and legacy.size() == 3, "An accepted hazard preserves supplied provenance once alongside its presentation signal.")
	c.apply_hazard_damage("guild_house", "boss", 1)
	_expect(reports.back() == ["", "", "guild_house", "boss", 1], "A legacy or fixture hazard stays explicitly unattributed.")
	c.apply_hazard_damage("unknown", "boss", 1, hunter.ally_id(), "dig")
	c.apply_hazard_damage("guild_house", "missing", 1, hunter.ally_id(), "dig")
	c.apply_hazard_damage("guild_house", "boss", 0, hunter.ally_id(), "dig")
	_expect(reports.size() == 4 and legacy.size() == 4 and c.total_damage() == 6, "Rejected hazard damage publishes no report and changes no ledger.")


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
	_expect(not c.try_cast(h).is_empty() and c.cooldown_remaining(h) == 0.0, "Malformed and remote targets are not registered.")
	_expect(not c.try_cast(null).is_empty(), "Missing hero returns an explicit reason.")
	c.register_enemy("guild_house", "boss", BOSS)
	c.try_cast(h)
	for delta: float in [-1.0, INF, -INF, NAN]:
		c.tick(delta, h)
		_expect(c.damage_for_arena("guild_house") == 0 and c.cooldown_remaining(h) == 2.5 and is_equal_approx(c.active_remaining(h), 0.6975), "Invalid time cannot change an accepted cast.")
	c.tick(2.5, h)
	h.definition.skills[0].cooldown_seconds = NAN
	_expect(not c.try_cast(h).is_empty(), "Invalid authored timing is rejected explicitly.")
	_expect(c.damage_for_arena("unknown") == 0 and c.damage_for_enemy("unknown", "missing") == 0 and c.enemy_footprint("unknown", "missing") == Rect2i(), "Unknown readback is safe and side-effect free.")


func _check_active_handoff() -> void:
	var f := _fixture("hunter")
	var c: RefCounted = f.combat
	var h: ArenicHeroState = f.hero
	c.register_enemy("guild_house", "boss", BOSS)
	_expect(c.active_cast_snapshot(h).is_empty(), "Idle combat has no presentation handoff.")
	c.try_cast(h)
	c.tick(0.3, h)
	var before: Dictionary = c.active_cast_snapshot(h)
	c.configure(f.world)
	c.register_enemy("guild_house", "boss", BOSS)
	_expect(c.active_cast_snapshot(h) == before, "Reconfiguration preserves authoritative projectile timing and geometry.")
	_expect(before.ability_id == "auto_shot" and before.arena_id == "guild_house" and before.origin == Vector2i(30, 15) and before.target_cell == Vector2i(30, 22) and before.facing == "n" and is_equal_approx(before.remaining, 0.3975), "Projectile handoff identifies exact in-flight state.")
	before.origin = Vector2i.ZERO
	_expect(c.active_cast_snapshot(h).origin == Vector2i(30, 15), "Presenter snapshot cannot mutate authoritative origin.")
	c.tick(0.45, h)
	_expect(c.damage_for_arena("guild_house") == 1 and c.active_cast_snapshot(h).is_empty(), "Restoring a presenter neither restarts nor duplicates the pending hit.")
	f = _fixture("merchant")
	c = f.combat
	h = f.hero
	c.try_cast(h)
	c.tick(4.25, h)
	h.arena_id = "sanctum"
	h.cell = Vector2i(5, 6)
	c.configure(f.world)
	var aura: Dictionary = c.active_cast_snapshot(h)
	_expect(aura.ability_id == "fortune" and aura.arena_id == "sanctum" and aura.origin == h.cell and aura.target_cell == h.cell and aura.elapsed == 4.25 and aura.remaining == 15.75, "Fortune handoff follows current caster location and retains remaining duration.")
	c.cancel_channel(h)
	_expect(c.active_cast_snapshot(h) == aura, "Channel cancellation cannot erase Fortune during stage replacement.")


func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _phase_log(combat: RefCounted) -> Array:
	var events: Array = []
	combat.ability_phase.connect(func(caster: String, ability: String, phase: String, arena: String, cell: Vector2, cast_id: int): events.append({"caster": caster, "ability": ability, "phase": phase, "arena": arena, "cell": cell, "cast_id": cast_id}))
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
	var charging: Dictionary = c.active_cast_snapshot(h)
	_expect(charging.cast_id == 1 and not charging.released and charging.release_seconds == 0.26, "Charging snapshot identifies its loop without replaying a cast.")
	c.configure(f.world)
	_expect(c.active_cast_snapshot(h) == charging and events.size() == 1, "Stage reconfiguration emits nothing and preserves charging identity.")
	c.tick(0.25, h)
	_expect(_phase_names(events) == ["charge"], "Charge stays active until its actual release boundary.")
	c.tick(0.01, h)
	_expect(_phase_names(events) == ["charge", "cast"] and c.damage_for_arena("guild_house") == 0, "Actual release precedes landing and does not deal damage.")
	var released: Dictionary = c.active_cast_snapshot(h)
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
	# Ticking no longer cancels a cast whose owner is not the hero passed in: a
	# cast belongs to its caster, and with ghosts in the arena the old rule would
	# have cancelled every ghost's cast on every frame the player was ticked.
	c.tick(0.1, null)
	_expect(not c.active_cast_snapshot(h).is_empty(), "Advancing the model does not cancel another caster's cast.")
	c.cancel_active(h)
	_expect(_phase_names(events).slice(4) == ["charge", "cancel"] and c.active_cast_snapshot(h).is_empty(), "Interrupted windup stops its charge without release or impact.")
	c.tick(5.0, h)
	_expect(events.size() == 6, "An interrupted charge cannot release later.")


func _check_fast_phases_and_misses() -> void:
	var f := _fixture("hunter")
	var c: RefCounted = f.combat
	var h: ArenicHeroState = f.hero
	var events: Array = _phase_log(c)
	h.definition.skills[0].projectile_speed_tiles_per_second = 0.0
	h.definition.skills[0].cast_seconds = 0.01
	c.register_enemy("guild_house", "boss", BOSS)
	c.try_cast(h)
	_expect(c.active_cast_snapshot(h).release_seconds == 0.01, "Release delay cannot outlast a shortened projectile hit time.")
	c.tick(1.0, h)
	_expect(_phase_names(events) == ["charge", "cast", "impact", "end"] and c.damage_for_arena("guild_house") == 1, "One large step delivers release and impact in order without polling losses.")
	f = _fixture("hunter")
	c = f.combat
	h = f.hero
	events = _phase_log(c)
	h.definition.skills[0].projectile_speed_tiles_per_second = 0.0
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
	_expect(_phase_names(events) == ["cast", "sustain"] and c.active_cast_snapshot(h).released, "Channel activation starts its sustain after immediate release.")
	c.tick(2.0, h)
	c.cancel_channel(h)
	_expect(_phase_names(events) == ["cast", "sustain", "impact", "impact", "cancel"], "Channel release cancels sustain after its actual one-second hits.")
	c.cancel_channel(h)
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
	_expect(c.active_cast_snapshot(h).is_empty() and c.ally_status("guild_house", "hero").health == 1 and c.ally_status("guild_house", "hero").debuffs.is_empty(), "Lifecycle events do not change instant support rules.")
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


func _check_projectile_speed() -> void:
	for delta: Vector2i in [Vector2i(1, 0), Vector2i(8, 0), Vector2i(8, 8)]:
		var f: Dictionary = _fixture("hunter", Vector2i(20, 10))
		var c: ArenicCombatState = f.combat
		var h: ArenicHeroState = f.hero
		c.register_enemy("guild_house", "target", Rect2i(h.cell + delta, Vector2i.ONE))
		_expect(c.try_cast(h).is_empty(), "Constant-speed shot accepts axial and diagonal range: %s" % delta)
		var snapshot: Dictionary = c.active_cast_snapshot(h)
		var flight: float = float(snapshot.cast_seconds) - float(snapshot.release_seconds)
		_expect(is_equal_approx(Vector2(delta).length() / flight, 16.0), "Near, far and diagonal arrows share 16 tiles/second.")
		c.tick(float(snapshot.cast_seconds) - 0.001)
		_expect(c.total_damage() == 0, "Arrow cannot hit before distance-based arrival.")
		c.tick(0.001)
		_expect(c.total_damage() == 1 and c.casting_ids().is_empty(), "Arrow hits exactly once at distance-based arrival.")
	var f: Dictionary = _fixture("hunter")
	var c: ArenicCombatState = f.combat
	var h: ArenicHeroState = f.hero
	c.register_enemy("guild_house", "target", BOSS)
	c.try_cast(h)
	var accepted: float = c.active_remaining(h)
	h.definition.skills[0].projectile_speed_tiles_per_second = 32.0
	_expect(is_equal_approx(c.active_remaining(h), accepted), "A data edit does not retime an accepted arrow.")
	c.register_enemy("guild_house", "target", Rect2i(40, 22, 6, 6))
	var events: Array = _phase_log(c)
	c.tick(accepted)
	_expect(c.total_damage() == 0 and not _phase_names(events).has("impact"), "An arrow misses a target that left its aim cell, without impact feedback.")
	c.reset_caster(h)
	for speed: float in [-1.0, 0.001, 121.0, INF, NAN]:
		h.definition.skills[0].projectile_speed_tiles_per_second = speed
		_expect(not c.try_cast(h).is_empty(), "Malformed projectile speed is rejected before accepting a cast.")
