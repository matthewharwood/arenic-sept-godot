class_name ArenicCombatState
extends RefCounted
## One run's authoritative combat ledger. No nodes, art bounds or audio clocks.
## Distances use occupied grid cells and the Chebyshev metric (diagonals count).

signal progress_changed(arena_id: String)
signal ability_cast(ability_id: String, arena_id: String, origin: Vector2i, target_cell: Vector2i, facing: String)
signal damage_applied(arena_id: String, enemy_id: String, amount: int)
## Ordered simulation events; observers never infer a phase from a rendered frame.
signal ability_phase(ability_id: String, phase: String, arena_id: String, cell: Vector2, cast_id: int)

const HERO_ALLY_ID: String = "hero"
const MAX_TICKS_PER_CALL: int = 64
const TIME_EPSILON: float = 0.000000001

var phase_damage: int = 20:
	set(value):
		phase_damage = maxi(1, value)

var _world: ArenicWorldDefinition
var _arenas: Dictionary = {}
var _cooldown: float = 0.0
var _active: ArenicClassAbility
var _owner: ArenicHeroState
var _arena: String = ""
var _origin: Vector2i
var _facing: String = "n"
var _target_id: String = ""
var _target_cell: Vector2i
var _elapsed: float = 0.0
var _tick_debt: float = 0.0
var _loot_bonus: float = 0.0
var _hero_arena: String = ""
var _cast_serial: int = 0
var _active_cast_id: int = 0
var _released: bool = false
var _release_seconds: float = 0.0


func configure(world: ArenicWorldDefinition) -> void:
	if world == null:
		return
	_world = world
	for arena: ArenicArenaDefinition in world.arenas:
		if arena == null or arena.arena_id.is_empty():
			continue
		if not _arenas.has(arena.arena_id):
			_arenas[arena.arena_id] = {"damage": 0, "enemies": {}, "allies": {}}
		var authored: Variant = arena.get("phase_damage")
		_arenas[arena.arena_id]["phase_damage"] = maxi(1, int(authored)) if authored != null else 0


## Re-registering changes geometry/facing without resetting damage or progress.
func register_enemy(arena_id: String, enemy_id: String, footprint: Rect2i, facing: String = "n") -> bool:
	if not _known_arena(arena_id) or enemy_id.is_empty() or not _valid_footprint(footprint) or facing not in ["n", "e", "s", "w"]:
		return false
	var enemies: Dictionary = _arenas[arena_id]["enemies"]
	var total: int = int(enemies.get(enemy_id, {}).get("damage", 0))
	enemies[enemy_id] = {"footprint": footprint, "facing": facing, "damage": total}
	return true


## Support actors are gameplay state only; registering one never spawns a hero.
## Re-registration deliberately replaces health/debuffs; movement uses move_ally.
func register_ally(arena_id: String, actor_id: String, cell: Vector2i, health: int = 1, max_health: int = 1, debuffs: PackedStringArray = PackedStringArray()) -> void:
	if not _known_arena(arena_id) or actor_id.is_empty() or not ArenicGridMath.tile_valid(cell):
		return
	var cap: int = maxi(1, max_health)
	_arenas[arena_id]["allies"][actor_id] = {"cell": cell, "health": clampi(health, 0, cap), "max_health": cap, "debuffs": debuffs.duplicate()}


func move_ally(arena_id: String, actor_id: String, cell: Vector2i) -> void:
	if _known_arena(arena_id) and ArenicGridMath.tile_valid(cell) and _arenas[arena_id]["allies"].has(actor_id):
		_arenas[arena_id]["allies"][actor_id]["cell"] = cell


func ally_status(arena_id: String, actor_id: String) -> Dictionary:
	if not _arenas.has(arena_id):
		return {}
	return _arenas[arena_id]["allies"].get(actor_id, {}).duplicate(true)


func damage_for_arena(arena_id: String) -> int:
	return int(_arenas.get(arena_id, {}).get("damage", 0))


func damage_for_enemy(arena_id: String, enemy_id: String) -> int:
	return int(_arenas.get(arena_id, {}).get("enemies", {}).get(enemy_id, {}).get("damage", 0))


func enemy_footprint(arena_id: String, enemy_id: String) -> Rect2i:
	return _arenas.get(arena_id, {}).get("enemies", {}).get(enemy_id, {}).get("footprint", Rect2i())


func is_occupied(arena_id: String, cell: Vector2i) -> bool:
	for enemy: Dictionary in _arenas.get(arena_id, {}).get("enemies", {}).values():
		if enemy["footprint"].has_point(cell):
			return true
	return false


func phase_size(arena_id: String) -> int:
	var authored: int = int(_arenas.get(arena_id, {}).get("phase_damage", 0))
	return authored if authored > 0 else phase_damage


func completed_phases(arena_id: String) -> int:
	@warning_ignore("integer_division")
	return damage_for_arena(arena_id) / phase_size(arena_id)


func damage_in_phase(arena_id: String) -> int:
	return damage_for_arena(arena_id) % phase_size(arena_id)


func cooldown_remaining() -> float:
	return _cooldown


func active_remaining() -> float:
	if _active == null:
		return 0.0
	if _active.effect_kind == "channel" and _active.duration_seconds == 0.0:
		return INF
	var duration: float = _active.cast_seconds if _active.effect_kind in ["target", "ground"] else _active.duration_seconds
	return maxf(0.0, duration - _elapsed)


func is_channeling() -> bool:
	return _active != null and _active.effect_kind == "channel"


func fortune_loot_bonus() -> float:
	return _loot_bonus


## Value-only handoff when a stage/presenter is replaced; never restarts timers.
## Auras report the caster's current position; projectiles keep their cast origin.
func active_cast_snapshot() -> Dictionary:
	if _active == null:
		return {}
	var follows: bool = _active.effect_kind == "aura"
	return {
		"ability_id": _active.ability_id,
		"effect_kind": _active.effect_kind,
		"arena_id": _owner.arena_id if follows else _arena,
		"origin": _owner.cell if follows else _origin,
		"target_cell": _owner.cell if follows else _target_cell,
		"facing": _owner.facing if follows else _facing,
		"elapsed": _elapsed,
		"remaining": active_remaining(),
		"is_channeling": is_channeling(),
		"cast_seconds": _active.cast_seconds,
		"duration_seconds": _active.duration_seconds,
		"cast_id": _active_cast_id,
		"released": _released,
		"release_seconds": _release_seconds,
	}


## Read-only availability, suitable for HUD hints. It never spends a cooldown.
func cast_unavailable_reason(hero: ArenicHeroState) -> String:
	if not _valid_hero(hero):
		return "Choose a hero in an arena first."
	if _active != null:
		return "Your ability is already active."
	if _cooldown > TIME_EPSILON:
		return "Your ability is cooling down."
	if hero.definition.skills.is_empty() or hero.definition.skills[0] == null:
		return "This hero has no starter ability."
	var ability: ArenicClassAbility = hero.definition.skills[0]
	if not _valid_ability(ability):
		return "This ability is not ready."
	if ability.effect_kind in ["target", "ground", "channel"] and _nearest_enemy(hero.arena_id, hero.cell, ability).is_empty():
		return "Move behind an adjacent enemy." if ability.requires_backstab else "No enemy is in range."
	return ""


## Returns a user-facing rejection; only accepted casts consume a cooldown.
func try_cast(hero: ArenicHeroState) -> String:
	var unavailable: String = cast_unavailable_reason(hero)
	if not unavailable.is_empty():
		return unavailable
	var ability: ArenicClassAbility = hero.definition.skills[0]
	_sync_hero(hero)
	var target: String = ""
	var target_cell: Vector2i = hero.cell
	if ability.effect_kind in ["target", "ground", "channel"]:
		target = _nearest_enemy(hero.arena_id, hero.cell, ability)
		if target.is_empty():
			return "Move behind an adjacent enemy." if ability.requires_backstab else "No enemy is in range."
		target_cell = nearest_cell(hero.cell, _arenas[hero.arena_id]["enemies"][target]["footprint"])
		var direction: Vector2i = target_cell - hero.cell
		if direction != Vector2i.ZERO:
			hero.facing = ("n" if direction.y > 0 else "s") if absi(direction.y) >= absi(direction.x) else ("e" if direction.x > 0 else "w")
	_cooldown = ability.cooldown_seconds
	_cast_serial += 1
	var cast_id: int = _cast_serial
	if ability.effect_kind != "cleanse":
		_active = ability
		_owner = hero
		_arena = hero.arena_id
		_origin = hero.cell
		_facing = hero.facing
		_target_id = target
		_target_cell = target_cell
		_elapsed = 0.0
		_tick_debt = 0.0
		_active_cast_id = cast_id
		_released = false
		_release_seconds = minf(ability.release_seconds, ability.cast_seconds) if ability.effect_kind in ["target", "ground"] else 0.0
	# Publish the cast before its hits, so effects can attach before hit feedback.
	ability_cast.emit(ability.ability_id, hero.arena_id, hero.cell, target_cell, hero.facing)
	if ability.effect_kind == "cleanse":
		ability_phase.emit(ability.ability_id, "cast", hero.arena_id, Vector2(hero.cell), cast_id)
		_cleanse(hero, ability, cast_id)
		ability_phase.emit(ability.ability_id, "end", hero.arena_id, Vector2(hero.cell), cast_id)
	elif _active != null and _active_cast_id == cast_id:
		if _release_seconds > 0.0:
			ability_phase.emit(ability.ability_id, "charge", _arena, Vector2(_origin), cast_id)
		else:
			_release_active()
		if _active != null and _active_cast_id == cast_id and ability.effect_kind in ["target", "ground"] and ability.cast_seconds == 0.0:
			_resolve_cast()
	return ""


## Run once per simulation step, including overview. No background timer exists.
func tick(delta: float, hero: ArenicHeroState) -> void:
	if not is_finite(delta) or delta < 0.0:
		return
	if _valid_hero(hero):
		_sync_hero(hero)
	_cooldown = maxf(0.0, _cooldown - delta)
	if _active == null:
		return
	if not _valid_hero(hero) or hero != _owner:
		_finish_active("cancel")
		return
	if is_channeling() and (hero.arena_id != _arena or hero.cell != _origin):
		cancel_channel()
		return
	var step: float = delta
	if _active.effect_kind != "channel" or _active.duration_seconds > 0.0:
		step = minf(delta, active_remaining())
	_elapsed += step
	if not _released and _elapsed + TIME_EPSILON >= _release_seconds:
		_release_active()
		if _active == null:
			return
	if _active.effect_kind in ["target", "ground"]:
		if active_remaining() <= TIME_EPSILON:
			_resolve_cast()
		return
	_tick_debt += step
	# A finite aura has at most duration/tick hits. Held channels catch up in a
	# bounded batch and retain remaining debt, avoiding an unbounded hitch loop.
	var budget: int = MAX_TICKS_PER_CALL
	while _active != null and _tick_debt + TIME_EPSILON >= _active.tick_seconds and budget > 0:
		_tick_debt = maxf(0.0, _tick_debt - _active.tick_seconds)
		budget -= 1
		if _active.effect_kind == "aura":
			_aura_tick(hero)
		else:
			_channel_tick(hero)
	if _active != null and _active.duration_seconds > 0.0 and active_remaining() <= TIME_EPSILON and _tick_debt + TIME_EPSILON < _active.tick_seconds:
		_finish_active("end")


## Cancels only a held channel. Fortune and an airborne flask survive key-up.
func cancel_channel() -> void:
	if is_channeling():
		_finish_active("cancel")


static func nearest_cell(cell: Vector2i, footprint: Rect2i) -> Vector2i:
	return cell.clamp(footprint.position, footprint.end - Vector2i.ONE)


static func distance_to_footprint(cell: Vector2i, footprint: Rect2i) -> int:
	var difference: Vector2i = (cell - nearest_cell(cell, footprint)).abs()
	return maxi(difference.x, difference.y)


## Even-sized Cleanse is biased +X/+Y, then kept fully inside the arena.
static func area_rect(cell: Vector2i, size: Vector2i) -> Rect2i:
	@warning_ignore("integer_division")
	var offset := Vector2i((size.x - 1) / 2, (size.y - 1) / 2)
	var limit := Vector2i(ArenicGridMath.GRID_WIDTH, ArenicGridMath.GRID_HEIGHT) - size
	return Rect2i((cell - offset).clamp(Vector2i.ZERO, limit), size)


func _nearest_enemy(arena_id: String, cell: Vector2i, ability: ArenicClassAbility) -> String:
	var result: String = ""
	var best: int = ability.range_tiles + 1
	for id: String in _enemy_ids(arena_id):
		var enemy: Dictionary = _arenas[arena_id]["enemies"][id]
		var footprint: Rect2i = enemy["footprint"]
		var distance: int = distance_to_footprint(cell, footprint)
		if distance >= best or (ability.requires_adjacent and distance != 1):
			continue
		if ability.requires_backstab and not _behind(cell, footprint, enemy["facing"]):
			continue
		result = id
		best = distance
	return result


static func _behind(cell: Vector2i, footprint: Rect2i, facing: String) -> bool:
	match facing:
		"n": return cell.y < footprint.position.y
		"s": return cell.y >= footprint.end.y
		"e": return cell.x < footprint.position.x
		"w": return cell.x >= footprint.end.x
	return false


func _ground_hit() -> void:
	for id: String in _enemy_ids(_arena):
		if _arenas[_arena]["enemies"][id]["footprint"].has_point(_target_cell):
			_hit(_arena, id, _active.damage, _active.ability_id, _active_cast_id)


func _resolve_cast() -> void:
	if _active == null:
		return
	if _active.effect_kind == "ground":
		_ground_hit()
	else:
		var enemy: Dictionary = _arenas[_arena]["enemies"][_target_id]
		var in_reach: bool = not _active.requires_adjacent or (_owner.arena_id == _arena and distance_to_footprint(_owner.cell, enemy["footprint"]) == 1)
		var behind: bool = not _active.requires_backstab or _behind(_owner.cell, enemy["footprint"], enemy["facing"])
		if in_reach and behind:
			_hit(_arena, _target_id, _active.damage, _active.ability_id, _active_cast_id)
	_finish_active("end")


func _channel_tick(hero: ArenicHeroState) -> void:
	var enemy: Dictionary = _arenas[_arena]["enemies"].get(_target_id, {})
	if not enemy.is_empty() and distance_to_footprint(hero.cell, enemy["footprint"]) <= _active.range_tiles:
		_hit(_arena, _target_id, _active.damage, _active.ability_id, _active_cast_id)


func _aura_tick(hero: ArenicHeroState) -> void:
	for id: String in _enemy_ids(hero.arena_id):
		if distance_to_footprint(hero.cell, _arenas[hero.arena_id]["enemies"][id]["footprint"]) <= _active.radius_tiles:
			_hit(hero.arena_id, id, _active.damage, _active.ability_id, _active_cast_id)
	var nearby: int = 0
	for id: String in _arenas[hero.arena_id]["allies"]:
		var ally: Dictionary = _arenas[hero.arena_id]["allies"][id]
		var difference: Vector2i = (hero.cell - Vector2i(ally["cell"])).abs()
		if id != HERO_ALLY_ID and maxi(difference.x, difference.y) <= _active.radius_tiles:
			nearby += 1
	_loot_bonus = nearby * _active.loot_bonus_per_ally


func _cleanse(hero: ArenicHeroState, ability: ArenicClassAbility, cast_id: int) -> void:
	var area: Rect2i = area_rect(hero.cell, ability.area_size)
	for id: String in _enemy_ids(hero.arena_id):
		if area.intersects(_arenas[hero.arena_id]["enemies"][id]["footprint"]):
			_hit(hero.arena_id, id, ability.damage, ability.ability_id, cast_id)
	for ally: Dictionary in _arenas[hero.arena_id]["allies"].values():
		if area.has_point(ally["cell"]):
			var changed: bool = ally["health"] < ally["max_health"] or not ally["debuffs"].is_empty()
			ally["health"] = mini(ally["max_health"], ally["health"] + 1)
			ally["debuffs"] = PackedStringArray()
			if changed:
				ability_phase.emit(ability.ability_id, "impact", hero.arena_id, Vector2(ally["cell"]), cast_id)


func _hit(arena_id: String, enemy_id: String, amount: int, ability_id: String, cast_id: int) -> void:
	_arenas[arena_id]["damage"] += amount
	_arenas[arena_id]["enemies"][enemy_id]["damage"] += amount
	damage_applied.emit(arena_id, enemy_id, amount)
	progress_changed.emit(arena_id)
	var footprint: Rect2i = _arenas[arena_id]["enemies"][enemy_id]["footprint"]
	var center: Vector2 = Vector2(footprint.position) + Vector2(footprint.size - Vector2i.ONE) * 0.5
	ability_phase.emit(ability_id, "impact", arena_id, center, cast_id)


func _sync_hero(hero: ArenicHeroState) -> void:
	if _hero_arena == hero.arena_id and _arenas[_hero_arena]["allies"].has(HERO_ALLY_ID):
		_arenas[_hero_arena]["allies"][HERO_ALLY_ID]["cell"] = hero.cell
		return
	var support: Dictionary = {}
	for arena: Dictionary in _arenas.values():
		if arena["allies"].has(HERO_ALLY_ID):
			support = arena["allies"][HERO_ALLY_ID]
			arena["allies"].erase(HERO_ALLY_ID)
	if support.is_empty():
		register_ally(hero.arena_id, HERO_ALLY_ID, hero.cell)
	else:
		support["cell"] = hero.cell
		_arenas[hero.arena_id]["allies"][HERO_ALLY_ID] = support
	_hero_arena = hero.arena_id


func _release_active() -> void:
	if _active == null or _released:
		return
	_released = true
	var cast_id: int = _active_cast_id
	ability_phase.emit(_active.ability_id, "cast", _arena, Vector2(_origin), cast_id)
	if _active != null and _active_cast_id == cast_id and _active.effect_kind in ["channel", "aura"]:
		ability_phase.emit(_active.ability_id, "sustain", _arena, Vector2(_origin), cast_id)


func _finish_active(phase: String) -> void:
	if _active == null:
		return
	var ability_id: String = _active.ability_id
	var cast_id: int = _active_cast_id
	var follows: bool = _active.effect_kind == "aura"
	var arena_id: String = _owner.arena_id if follows else _arena
	var cell: Vector2 = Vector2(_owner.cell if follows else _origin)
	_active = null
	_owner = null
	_elapsed = 0.0
	_tick_debt = 0.0
	_loot_bonus = 0.0
	_active_cast_id = 0
	_released = false
	_release_seconds = 0.0
	ability_phase.emit(ability_id, phase, arena_id, cell, cast_id)


func _enemy_ids(arena_id: String) -> Array:
	var ids: Array = _arenas.get(arena_id, {}).get("enemies", {}).keys()
	ids.sort()
	return ids


func _known_arena(id: String) -> bool:
	return _world != null and _world.index_for_id(id) >= 0 and _arenas.has(id)


func _valid_hero(hero: ArenicHeroState) -> bool:
	return hero != null and hero.definition != null and _known_arena(hero.arena_id) and ArenicGridMath.tile_valid(hero.cell)


static func _valid_footprint(rect: Rect2i) -> bool:
	return rect.size.x > 0 and rect.size.y > 0 and ArenicGridMath.tile_valid(rect.position) and ArenicGridMath.tile_valid(rect.end - Vector2i.ONE)


static func _valid_ability(ability: ArenicClassAbility) -> bool:
	return not ability.ability_id.is_empty() and ability.effect_kind in ["target", "ground", "channel", "cleanse", "aura"] and ability.damage > 0 \
		and is_finite(ability.cooldown_seconds) and ability.cooldown_seconds >= 0.0 and ability.range_tiles >= 0 \
		and is_finite(ability.cast_seconds) and ability.cast_seconds >= 0.0 \
		and is_finite(ability.release_seconds) and ability.release_seconds >= 0.0 \
		and is_finite(ability.duration_seconds) and ability.duration_seconds >= 0.0 \
		and is_finite(ability.tick_seconds) and ability.tick_seconds >= 0.05 \
		and (ability.effect_kind != "aura" or ability.duration_seconds > 0.0) and ability.radius_tiles >= 0 \
		and ability.area_size.x > 0 and ability.area_size.y > 0 \
		and ability.area_size.x <= ArenicGridMath.GRID_WIDTH and ability.area_size.y <= ArenicGridMath.GRID_HEIGHT \
		and is_finite(ability.loot_bonus_per_ally) and ability.loot_bonus_per_ally >= 0.0
