class_name ArenicHeroContact
extends RefCounted
## Transient, integer-only contact decisions for one simultaneous movement step.
## Rendering bounds and adjacent tile edges never decide whether heroes touch.

const MAX_HEROES: int = 320


static func capture(heroes: Array, combat: ArenicCombatState) -> Dictionary:
	var snapshot: Dictionary = {}
	if combat == null or heroes.size() > MAX_HEROES:
		return snapshot
	for hero: ArenicHeroState in heroes:
		if hero == null:
			continue
		snapshot[hero.identity_id] = {"arena": hero.arena_id, "cell": hero.cell,
			"point": combat.hero_contact_cell(hero), "selected": hero.selected,
			"alive": not combat.ally_defeated_at(hero.arena_id, hero.ally_id())}
	return snapshot


## Each contact point/time is a group, decided from the original snapshot.
## Victims from all groups are unioned; an earlier signal cannot save somebody
## who already lost a simultaneous contact elsewhere along the same step.
static func resolve(before: Dictionary, heroes: Array, combat: ArenicCombatState, include_crossings: bool = true) -> Array[Dictionary]:
	var victims: Array[Dictionary] = []
	if combat == null or heroes.size() > MAX_HEROES:
		return victims
	var actors: Dictionary = {}
	for hero: ArenicHeroState in heroes:
		if hero == null or combat.ally_defeated_at(hero.arena_id, hero.ally_id()):
			continue # Defeated ghost smoke is not a physical occupant.
		var point: Vector2i = combat.hero_contact_cell(hero)
		var old: Dictionary = before.get(hero.identity_id, {})
		if not bool(old.get("alive", true)):
			continue
		var start: Vector2i = old.get("point", point)
		actors[hero.identity_id] = {"identity": hero.identity_id, "arena": hero.arena_id,
			"actor": hero.ally_id(), "selected": bool(old.get("selected", hero.selected)),
			"start": start, "end": point, "delta": point - start}
	var ids: Array = actors.keys()
	ids.sort()
	var groups: Dictionary = {}
	# Endpoint groups need no pairwise comparisons, especially while all 320
	# heroes are stationary. Only movers require crossing comparisons.
	for identity: int in ids:
		var point: Vector2i = actors[identity].end
		var key := Vector4i(1, 1, point.x, point.y)
		if not groups.has(key):
			groups[key] = {}
		groups[key][identity] = true
	for left_id: int in ids:
		var left: Dictionary = actors[left_id]
		if not include_crossings or left.delta == Vector2i.ZERO:
			continue # Rewinds teleport; they do not sweep through the arena.
		for right_id: int in ids:
			var right: Dictionary = actors[right_id]
			if right_id == left_id or (right.delta != Vector2i.ZERO and right_id < left_id) or left.end == right.end:
				continue
			# Disjoint grid bounds cannot meet, regardless of their timing.
			if maxi(left.start.x, left.end.x) < mini(right.start.x, right.end.x) or maxi(right.start.x, right.end.x) < mini(left.start.x, left.end.x):
				continue
			if maxi(left.start.y, left.end.y) < mini(right.start.y, right.end.y) or maxi(right.start.y, right.end.y) < mini(left.start.y, left.end.y):
				continue
			var time: Vector2i = _contact_time(left, right)
			if time == Vector2i.ZERO:
				continue
			var point_numerator: Vector2i = left.start * time.y + left.delta * time.x
			var key := Vector4i(time.x, time.y, point_numerator.x, point_numerator.y)
			if not groups.has(key):
				groups[key] = {}
			groups[key][left_id] = true
			groups[key][right_id] = true
	var defeated: Dictionary = {}
	for key: Vector4i in groups:
		var members: Array = groups[key].keys()
		if members.size() < 2:
			continue
		members.sort()
		var movers: Array = []
		for identity: int in members:
			if actors[identity].delta != Vector2i.ZERO:
				movers.append(identity)
		var candidates: Array = movers if not movers.is_empty() else members
		var survivor: int = candidates[0]
		for identity: int in candidates:
			if not actors[identity].selected:
				survivor = identity
				break
		var cause: String = "overlap" if movers.is_empty() else ("crossing" if key.x < key.y else "arrival")
		for identity: int in members:
			if identity == survivor or defeated.has(identity):
				continue
			var actor: Dictionary = actors[identity]
			defeated[identity] = {"identity": identity, "arena": actor.arena, "actor": actor.actor,
				"selected": actor.selected, "survivor": survivor, "cause": cause}
	for identity: int in ids:
		if defeated.has(identity):
			victims.append(defeated[identity])
	return victims


## Solve A0 + t*dA == B0 + t*dB with exact fractions, 0 < t <= 1.
## Equal final cells also cover static overlaps created by a cycle rewind.
static func _contact_time(left: Dictionary, right: Dictionary) -> Vector2i:
	if left.end == right.end:
		return Vector2i.ONE
	var distance: Vector2i = right.start - left.start
	var velocity: Vector2i = left.delta - right.delta
	if velocity == Vector2i.ZERO:
		return Vector2i.ZERO
	var numerator: int = distance.x if velocity.x != 0 else distance.y
	var denominator: int = velocity.x if velocity.x != 0 else velocity.y
	if denominator < 0:
		numerator = -numerator
		denominator = -denominator
	if numerator <= 0 or numerator >= denominator:
		return Vector2i.ZERO
	if distance.x * denominator != velocity.x * numerator or distance.y * denominator != velocity.y * numerator:
		return Vector2i.ZERO
	var divisor: int = _gcd(numerator, denominator)
	return Vector2i(numerator / divisor, denominator / divisor)


static func _gcd(left: int, right: int) -> int:
	while right != 0:
		var remainder: int = left % right
		left = right
		right = remainder
	return left
