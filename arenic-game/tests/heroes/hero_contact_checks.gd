extends SceneTree
## Integer contact decisions and the real conductor/combat ordering boundary.

var _checks: int = 0
var _failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_arrivals()
	_check_paths()
	_check_seam()
	_check_batch()
	_check_playback()
	_check_paused()
	_check_restart()
	_check_capacity()
	print("Hero contact checks: %d assertions %s." % [_checks, "FAILED" if _failed else "passed"])
	quit(1 if _failed else 0)


func _fixture(cells: Array[Vector2i], selected: int = -1, class_id: String = "forager") -> Dictionary:
	var combat := ArenicCombatState.new()
	var world := load("res://data/world/arenia.tres") as ArenicWorldDefinition
	combat.configure(world)
	var heroes: Array = []
	var lookup: Dictionary = {}
	for index: int in cells.size():
		var hero := ArenicHeroState.new()
		hero.identity_id = index
		hero.definition = load("res://data/classes/%s.tres" % class_id)
		hero.arena_id = "guild_house"
		hero.cell = cells[index]
		hero.selected = index == selected
		heroes.append(hero)
		lookup[hero.ally_id()] = hero
	combat.sync_allies(heroes)
	var encounter := ArenicEncounterState.new()
	encounter.configure(world, ArenicEncounterCatalog.new(), combat)
	encounter.roster_lookup = func() -> Array: return heroes
	encounter.performer_lookup = func(actor: String) -> ArenicHeroState: return lookup.get(actor)
	return {"combat": combat, "encounter": encounter, "heroes": heroes, "world": world}


func _victims(fixture: Dictionary, before: Dictionary) -> Array:
	var contacts: Array[Dictionary] = ArenicHeroContact.resolve(before, fixture.heroes, fixture.combat)
	var identities: Array = []
	for contact: Dictionary in contacts:
		identities.append(contact.identity)
	return identities


func _check_arrivals() -> void:
	for selected: int in [-1, 0, 1]:
		var f := _fixture([Vector2i(10, 10), Vector2i(11, 10)], selected)
		var before := ArenicHeroContact.capture(f.heroes, f.combat)
		f.heroes[0].cell = Vector2i(11, 10)
		_check(_victims(f, before) == [1], "A stationary occupant loses to one arriving mover regardless of selection %d." % selected)
	var simultaneous := _fixture([Vector2i(10, 10), Vector2i(12, 10)], 0)
	var before := ArenicHeroContact.capture(simultaneous.heroes, simultaneous.combat)
	simultaneous.heroes[0].cell = Vector2i(11, 10)
	simultaneous.heroes[1].cell = Vector2i(11, 10)
	_check(_victims(simultaneous, before) == [0], "Selected mover loses a simultaneous arrival even when its identity is earlier.")
	var contacts := ArenicHeroContact.resolve(before, simultaneous.heroes, simultaneous.combat)
	_check(contacts[0].selected and contacts[0].survivor == 1 and contacts[0].cause == "arrival", "Frozen provenance retains selection, survivor and actual arrival cause.")
	simultaneous.heroes.reverse()
	_check(_victims(simultaneous, before) == [0], "Roster iteration order cannot change simultaneous winners.")
	for snapshot: Dictionary in before.values():
		snapshot.selected = false
	_check(_victims(simultaneous, before) == [1], "Without selection, earlier stable identity survives.")
	var three := _fixture([Vector2i(10, 10), Vector2i(12, 10), Vector2i(11, 9), Vector2i(11, 10)], 0)
	before = ArenicHeroContact.capture(three.heroes, three.combat)
	for index: int in 3:
		three.heroes[index].cell = Vector2i(11, 10)
	_check(_victims(three, before) == [0, 2, 3], "Three movers and an occupant choose one nonselected mover, with all other victims frozen.")


func _check_paths() -> void:
	var f := _fixture([Vector2i(10, 10), Vector2i(11, 10)], 0)
	var before := ArenicHeroContact.capture(f.heroes, f.combat)
	f.heroes[0].cell = Vector2i(11, 10)
	f.heroes[1].cell = Vector2i(10, 10)
	_check(_victims(f, before) == [0], "Opposing moves through the same edge collide halfway.")
	var contacts := ArenicHeroContact.resolve(before, f.heroes, f.combat)
	_check(contacts[0].cause == "crossing", "A swap publishes a crossing, not an endpoint arrival.")
	f = _fixture([Vector2i(10, 10), Vector2i(11, 10)], 1)
	before = ArenicHeroContact.capture(f.heroes, f.combat)
	f.heroes[0].cell = Vector2i(11, 11)
	f.heroes[1].cell = Vector2i(10, 11)
	_check(_victims(f, before) == [1], "Diagonal X paths at the same fractional time collide.")
	f = _fixture([Vector2i(10, 10), Vector2i(11, 10)])
	before = ArenicHeroContact.capture(f.heroes, f.combat)
	f.heroes[0].cell = Vector2i(11, 10)
	f.heroes[1].cell = Vector2i(12, 10)
	_check(_victims(f, before).is_empty(), "Following into a vacated tile is safe.")
	f = _fixture([Vector2i(10, 10), Vector2i(11, 10)])
	_check(_victims(f, ArenicHeroContact.capture(f.heroes, f.combat)).is_empty(), "Adjacent cells touching at their visual edges are safe.")
	f = _fixture([Vector2i(10, 10), Vector2i(11, 9)])
	before = ArenicHeroContact.capture(f.heroes, f.combat)
	f.heroes[0].cell = Vector2i(12, 10)
	f.heroes[1].cell = Vector2i(11, 12)
	_check(_victims(f, before).is_empty(), "Geometric paths crossing at different times do not collide.")


func _check_seam() -> void:
	var f := _fixture([Vector2i(65, 10), Vector2i(0, 10)], 0)
	var left: ArenicArenaDefinition = f.world.arenas[f.world.index_for_slot(Vector2i(0, 1))]
	var right: ArenicArenaDefinition = f.world.arenas[f.world.index_for_slot(Vector2i(1, 1))]
	f.heroes[0].arena_id = left.arena_id
	f.heroes[1].arena_id = right.arena_id
	f.combat.sync_allies(f.heroes)
	var before := ArenicHeroContact.capture(f.heroes, f.combat)
	_check(f.heroes[0].step(Vector2i.RIGHT, f.world) and f.heroes[1].step(Vector2i.LEFT, f.world), "The real travel API accepts the two opposing seam steps.")
	_check(_victims(f, before) == [0], "A seam swap collides in continuous integer world-grid coordinates.")
	f.encounter.resolve_contacts(f.combat, before)
	_check(f.combat.ally_defeated_at(right.arena_id, "hero:0") and not f.combat.ally_defeated_at(left.arena_id, "hero:1"), "Contact health follows the moved hero into the destination arena.")


func _check_batch() -> void:
	var f := _fixture([Vector2i(10, 10), Vector2i(12, 10), Vector2i(11, 9)], 0)
	var before := ArenicHeroContact.capture(f.heroes, f.combat)
	for hero: ArenicHeroState in f.heroes:
		hero.cell = Vector2i(11, 10)
	var observations: Array = []
	var reference: WeakRef = weakref(f.combat)
	f.combat.hero_contact_defeated.connect(func(arena: String, actor: String, contact: Dictionary):
		var combat: ArenicCombatState = reference.get_ref()
		observations.append(["contact", actor, combat.ally_defeated_at(arena, "hero:0"), combat.ally_defeated_at(arena, "hero:2"), contact.selected]))
	f.combat.ally_defeated.connect(func(_arena: String, actor: String): observations.append(["defeat", actor]))
	f.encounter.resolve_contacts(f.combat, before)
	_check(observations.size() == 4 and observations[0] == ["contact", "hero:0", true, true, true], "Every victim is already dead before the first contact observer runs.")
	_check(observations[1] == ["defeat", "hero:0"] and observations[2][1] == "hero:2" and observations[3] == ["defeat", "hero:2"], "Contact precedes ordinary defeat once per victim in stable identity order.")
	_check(not f.combat.try_cast(f.heroes[0]).is_empty(), "A defeated hero cannot accept a new cast.")
	_check(f.encounter.resolve_contacts(f.combat).is_empty(), "Dead ghost smoke does not collide again or kill the survivor.")


func _check_playback() -> void:
	# Fold the selected performer first and put ABILITY before MOVE in its staff;
	# physics contact must still precede both that ability and active projectiles.
	var f := _fixture([Vector2i(10, 10), Vector2i(12, 10)], 0, "hunter")
	f.combat.register_enemy("guild_house", "target", Rect2i(11, 12, 1, 1))
	_check(f.combat.try_cast(f.heroes[0]).is_empty(), "The future contact victim launches a real projectile before moving.")
	var a := ArenicRecording.create(f.heroes[0].cell, [ArenicTimelineEvent.ability(0, 1), ArenicTimelineEvent.move(0, Vector2i.RIGHT)])
	var b := ArenicRecording.create(f.heroes[1].cell, [ArenicTimelineEvent.move(0, Vector2i.LEFT), ArenicTimelineEvent.ability(0, 1)])
	f.encounter.timeline("guild_house").fold("hero:0", a)
	f.encounter.timeline("guild_house").fold("hero:1", b)
	var casts: Array = []
	f.combat.ability_cast.connect(func(caster: String, _ability: String, _arena: String, _origin: Vector2i, _target: Vector2i, _facing: String): casts.append(caster))
	var callbacks: Array = []
	var combat_ref: WeakRef = weakref(f.combat)
	f.encounter.tick(f.combat, 1, {}, func():
		var combat: ArenicCombatState = combat_ref.get_ref()
		callbacks.append(combat.ally_defeated_at("guild_house", "hero:0"))
		combat.tick(2.0))
	_check(callbacks == [true], "All due ghost movement and contact precede the live/combat callback exactly once.")
	_check(f.heroes[0].cell == f.heroes[1].cell and f.combat.ally_defeated_at("guild_house", "hero:0"), "The earlier-folded selected ghost loses to the simultaneous later mover.")
	_check(f.combat.total_damage() == 0 and not f.combat._casts.has("hero:0"), "A contact victim's old projectile is canceled before arrival damage.")
	_check(casts == ["hero:1"], "The victim's earlier ordered ABILITY is suppressed; the survivor still casts.")
	f.combat.tick(2.0)
	_check(f.combat.total_damage() == 1, "The surviving ghost's cast resolves normally.")
	# A shell may immediately revive/unfold a selected contact victim. Its already
	# collected ABILITY must remain suppressed for the rest of this exact step.
	f = _fixture([Vector2i(10, 10), Vector2i(12, 10)], 0)
	f.encounter.timeline("guild_house").fold("hero:0", a)
	f.encounter.timeline("guild_house").fold("hero:1", b)
	var victim: ArenicHeroState = f.heroes[0]
	combat_ref = weakref(f.combat)
	f.combat.ally_defeated.connect(func(_arena: String, _actor: String):
		var combat: ArenicCombatState = combat_ref.get_ref()
		victim.cell = Vector2i(30, 15)
		combat.respawn_hero_ally(victim))
	casts = []
	f.combat.ability_cast.connect(func(caster: String, _ability: String, _arena: String, _origin: Vector2i, _target: Vector2i, _facing: String): casts.append(caster))
	f.encounter.tick(f.combat)
	_check(not f.combat.ally_defeated_at("guild_house", "hero:0") and victim.cell == Vector2i(30, 15), "A synchronous shell-style respawn can restore the selected victim.")
	_check(casts == ["hero:1"], "Immediate revival does not replay the victim's collected ability after contact.")


func _check_paused() -> void:
	var f := _fixture([Vector2i(10, 10), Vector2i(11, 10)], 0)
	f.encounter.set_paused("guild_house", true)
	var before := ArenicHeroContact.capture(f.heroes, f.combat)
	f.heroes[0].cell = Vector2i(11, 10)
	var advanced: Array = []
	f.encounter.arena_advanced.connect(func(arena: String): advanced.append(arena))
	f.encounter.tick(f.combat, 1, before)
	_check(f.combat.ally_defeated_at("guild_house", "hero:1"), "A paused arena's stationary hero is still physical to incoming live movement.")
	_check(f.encounter.cycle_position("guild_house") == 0 and "guild_house" not in advanced, "Contact resolution does not advance the paused arena or its work clock.")
	_check(advanced.size() == 8, "Every other unpaused arena emits one work boundary.")
	f.encounter.set_paused("guild_house", false)
	advanced.clear()
	f.encounter.tick(f.combat, 3)
	_check(advanced.size() == 27 and f.encounter.cycle_position("guild_house") == 3, "Multi-step calls advance every arena once per step with fresh snapshots.")


func _check_restart() -> void:
	var f := _fixture([Vector2i(5, 5), Vector2i(10, 10)], 1)
	f.encounter.timeline("guild_house").fold("hero:0", ArenicRecording.create(Vector2i(10, 10), []))
	var resets: Array = []
	var combat_ref: WeakRef = weakref(f.combat)
	f.encounter.arena_restarted.connect(func(arena: String): resets.append([arena, (combat_ref.get_ref() as ArenicCombatState).ally_defeated_at(arena, "hero:1")]))
	f.encounter.restart("guild_house")
	_check(f.heroes[0].cell == Vector2i(10, 10) and f.combat.ally_defeated_at("guild_house", "hero:1"), "A rewinding ghost displaces the stationary occupant at its start tile.")
	_check(resets == [["guild_house", true]], "Reset contact is resolved before restart subscribers observe the new cycle.")
	f = _fixture([Vector2i(10, 10), Vector2i(10, 10)], 0)
	f.encounter.timeline("guild_house").fold("hero:0", ArenicRecording.create(Vector2i(10, 10), []))
	f.encounter.timeline("guild_house").fold("hero:1", ArenicRecording.create(Vector2i(10, 10), []))
	f.combat.register_ally("guild_house", "hero:0", Vector2i(10, 10), 0)
	f.encounter._clocks["guild_house"].seek(ArenicCycleClock.CYCLE_TICKS - 1)
	f.encounter.tick(f.combat)
	_check(f.encounter.cycle_position("guild_house") == 0 and f.combat.ally_defeated_at("guild_house", "hero:0") and not f.combat.ally_defeated_at("guild_house", "hero:1"), "Natural reset revives then resolves overlapping starts, including formerly dead smoke.")
	f = _fixture([Vector2i(5, 5), Vector2i(10, 10)], 0)
	f.encounter.timeline("guild_house").fold("hero:0", ArenicRecording.create(Vector2i(15, 15), []))
	f.encounter.restart("guild_house")
	_check(not f.combat.ally_defeated_at("guild_house", "hero:1"), "A rewind teleport does not sweep through an unrelated stationary hero.")


func _check_capacity() -> void:
	var cells: Array[Vector2i] = []
	for index: int in 320:
		cells.append(Vector2i(index % 64, index / 64))
	var f := _fixture(cells)
	var before := ArenicHeroContact.capture(f.heroes, f.combat)
	_check(before.size() == 320 and _victims(f, before).is_empty(), "The complete bounded guild resolves without truncation or false contacts.")
	f.heroes[319].cell = f.heroes[318].cell
	_check(_victims(f, before) == [318], "High identities obey the same stationary-victim rule.")


func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_failed = true
		push_error(message)
	return condition
