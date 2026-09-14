class_name ArenicCombatState
extends RefCounted
## One run's authoritative combat ledger. No nodes, art bounds or audio clocks.
## Distances use occupied grid cells and the Chebyshev metric (diagonals count).

signal progress_changed(arena_id: String)
signal ability_cast(caster_id: String, ability_id: String, arena_id: String, origin: Vector2i, target_cell: Vector2i, facing: String)
signal damage_applied(arena_id: String, enemy_id: String, amount: int)
signal damage_reported(caster_id: String, ability_id: String, arena_id: String, enemy_id: String, amount: int)
## Ordered simulation events; observers never infer a phase from a rendered frame.
signal ability_phase(caster_id: String, ability_id: String, phase: String, arena_id: String, cell: Vector2, cast_id: int)
## An ability put something on the ground: broken tiles, a pool of acid. The
## ledger does not own arena ground, so it announces the landing and the arena's
## cycle state does the rest. Instant abilities land at cast; thrown ones land
## when they resolve. One door for live casts and ghost playback alike.
signal ability_landed(caster_id: String, ability_id: String, arena_id: String, area: Rect2i, rules: ArenicClassAbility)
## A support actor reached zero health. Relocation and respawn belong to the shell.
signal ally_defeated(arena_id: String, actor_id: String)
## Contact provenance is transient. Every victim is already down before this
## signal, and the ordinary defeat signal follows for the same victim.
signal hero_contact_defeated(arena_id: String, actor_id: String, contact: Dictionary)

const HERO_ALLY_PREFIX: String = "hero:"
const BOSS_ENEMY_PREFIX: String = "boss:"
const MAX_TICKS_PER_CALL: int = 64
const MAX_ENEMY_DOTS: int = 6400
const ENEMY_DOT_TICKS_PER_SECOND: int = 60
const MAX_ENEMY_DOT_DURATION_TICKS: int = 7200
## Thrown/delayed abilities resolve once at their frozen arrival time.
const THROWN_KINDS: PackedStringArray = ["target", "ground", "flask"]
const TIME_EPSILON: float = 0.000000001

var phase_damage: int = 20:
	set(value):
		phase_damage = maxi(1, value)

## One caster's in-flight ability. Every caster owns its own, so a ghost
## replaying its staff can never contend with the player's cast or with another
## ghost's — which is what makes forty recorded heroes in one arena possible.
class Cast:
	extends RefCounted
	var ability: ArenicClassAbility
	var owner: ArenicHeroState
	var arena: String = ""
	var origin: Vector2i
	var facing: String = "n"
	var target_id: String = ""
	var target_cell: Vector2i
	var elapsed: float = 0.0
	var tick_debt: float = 0.0
	var cast_id: int = 0
	var released: bool = false
	var release_seconds: float = 0.0
	## Total accepted duration, frozen so data edits and restores cannot retime a shot.
	var resolve_seconds: float = 0.0
	var loot_bonus: float = 0.0

	func remaining() -> float:
		if ability.effect_kind == "channel" and ability.duration_seconds == 0.0:
			return INF
		return maxf(0.0, resolve_seconds - elapsed)

	func is_channel() -> bool:
		return ability.effect_kind == "channel"

## Each application owns its accepted rules and clock debt; it never refreshes
## another stack or follows its caster to a different arena.
class EnemyDot:
	extends RefCounted
	var caster_id: String = ""
	var ability_id: String = ""
	var arena: String = ""
	var enemy_id: String = ""
	var remaining_ticks: int = 0
	var interval_ticks: int = 0
	var tick_debt: int = 0
	var damage: int = 1

## Transient read-only encounter geometry, rebuilt on configure/restore.
var encounter_effects := ArenicActorEffects.new()
var direct_bonus_lookup: Callable = Callable()
signal boss_wound(arena_id: String, actor_id: String, event_id: String, amount: int)

var enemy_pose_lookup: Callable = Callable()
## Transient encounter pause ownership, rebound on configure/restore.
var arena_paused_lookup: Callable = Callable()

var _world: ArenicWorldDefinition
var _arenas: Dictionary = {}
## Caster key to its in-flight cast, and to its own cooldown.
var _casts: Dictionary[String, Cast] = {}
var _cooldowns: Dictionary[String, float] = {}
var _hero_arenas: Dictionary[String, String] = {}
var _cast_serial: int = 0
var _enemy_dots: Array[EnemyDot] = []


func configure(world: ArenicWorldDefinition) -> void:
	if world == null:
		return
	if encounter_effects.fingerprint.is_empty():
		encounter_effects.fingerprint = ArenicContentIdentity.fingerprint(encounter_effects.ruleset)
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


## The one place an arena's boss ledger key is spelled.
static func boss_enemy_id(arena_id: String) -> String:
	return BOSS_ENEMY_PREFIX + arena_id


## The one place a hero's ledger key is spelled. Guild members share the ledger,
## so each needs its own entry; the run identity is what distinguishes them.
static func hero_ally_id(identity_id: int) -> String:
	return HERO_ALLY_PREFIX + str(identity_id)


## Support actors present in an arena, in a stable order.
func ally_ids(arena_id: String) -> PackedStringArray:
	var ids: Array = _arenas.get(arena_id, {}).get("allies", {}).keys()
	ids.sort()
	return PackedStringArray(ids)


## A boss landing. Hero abilities keep the Chebyshev metric because they are
## authored against tile reach; an authored blast is a drawn circle, so it uses
## true radial distance from the landing footprint's center. Returns the actors
## it defeated. Targets remain immortal: only support actors can be struck.
func apply_blast(arena_id: String, center: Vector2, radius_tiles: float) -> PackedStringArray:
	var defeated := PackedStringArray()
	if not _arenas.has(arena_id) or not is_finite(radius_tiles) or radius_tiles <= 0.0 or not center.is_finite():
		return defeated
	var allies: Dictionary = _arenas[arena_id]["allies"]
	for actor_id: String in ally_ids(arena_id):
		var ally: Dictionary = allies[actor_id]
		if int(ally["health"]) <= 0:
			continue
		if center.distance_to(Vector2(ally["cell"])) > radius_tiles:
			continue
		ally["health"] = 0
		defeated.append(actor_id)
	# The whole landing resolves before anyone is told, so a listener that
	# respawns or relocates an actor cannot change who else this blast struck.
	for actor_id: String in defeated:
		_notify_defeat(arena_id, actor_id)
	return defeated


## Damage to every support actor standing in an area. Acid burns whoever is in
## it, so a hero walking through their own pool takes it too. Returns the actors
## this defeated; relocation and respawn belong to the shell, exactly as with a
## blast.
func damage_allies_in(arena_id: String, area: Rect2i, amount: int) -> PackedStringArray:
	var defeated := PackedStringArray()
	if not _arenas.has(arena_id) or amount <= 0:
		return defeated
	var allies: Dictionary = _arenas[arena_id]["allies"]
	for actor_id: String in ally_ids(arena_id):
		var ally: Dictionary = allies[actor_id]
		if int(ally["health"]) <= 0 or not area.has_point(Vector2i(ally["cell"])):
			continue
		ally["health"] = maxi(0, int(ally["health"]) - amount)
		if int(ally["health"]) <= 0:
			defeated.append(actor_id)
	# The whole burn resolves before anyone is told, so a listener that respawns
	# an actor cannot change who else was standing in it.
	for actor_id: String in defeated:
		_notify_defeat(arena_id, actor_id)
	return defeated


func ally_defeated_at(arena_id: String, actor_id: String) -> bool:
	var ally: Dictionary = _arenas.get(arena_id, {}).get("allies", {}).get(actor_id, {})
	return not ally.is_empty() and int(ally["health"]) <= 0


## Logical world-grid centers, including continuous coordinates across seams.
func hero_contact_cell(hero: ArenicHeroState) -> Vector2i:
	var index: int = _world.index_for_id(hero.arena_id) if _world != null else -1
	if index < 0:
		return hero.cell
	var slot: Vector2i = _world.arenas[index].grid_slot
	return Vector2i(slot.x * ArenicGridMath.GRID_WIDTH + hero.cell.x,
		slot.y * ArenicGridMath.GRID_HEIGHT - hero.cell.y)


## Apply the frozen batch before notifying observers: respawning the first
## victim cannot change another contact, or let a defeated cast resolve.
func defeat_hero_contacts(contacts: Array[Dictionary]) -> void:
	var applied: Array[Dictionary] = []
	for contact: Dictionary in contacts:
		var ally: Dictionary = _arenas.get(contact.arena, {}).get("allies", {}).get(contact.actor, {})
		if ally.is_empty() or int(ally.health) <= 0:
			continue
		ally.health = 0
		applied.append(contact)
	for contact: Dictionary in applied:
		var cast: Cast = _casts.get(contact.actor)
		if cast != null:
			_finish(cast, "cancel")
	for contact: Dictionary in applied:
		hero_contact_defeated.emit(contact.arena, contact.actor, contact.duplicate())
		_notify_defeat(contact.arena, contact.actor)


## Moves the hero's ledger entry to wherever the hero now stands and restores it.
## Respawning grants no cast, cooldown, damage, or phase change.
func respawn_hero_ally(hero: ArenicHeroState) -> void:
	if not _valid_hero(hero):
		return
	cancel_active(hero)
	encounter_effects.cleanse(hero.ally_id())
	_ensure_ally(hero)
	var ally: Dictionary = _arenas[hero.arena_id]["allies"][hero.ally_id()]
	ally["health"] = int(ally["max_health"])
	ally["debuffs"] = PackedStringArray()


## Cancels one caster's active ability, not only a held channel. Death and
## respawn use this; ordinary key-up still goes through cancel_channel.
func cancel_active(caster: ArenicHeroState) -> void:
	var cast: Cast = _casts.get(_key(caster))
	if cast != null:
		_finish(cast, "cancel")


## Restores a support actor to full health where it stands. A ghost struck by a
## landing is revived by its arena's next restart rather than relocated, so its
## staff keeps replaying from the same tile.
func revive_ally(arena_id: String, actor_id: String) -> void:
	var allies: Dictionary = _arenas.get(arena_id, {}).get("allies", {})
	if not allies.has(actor_id):
		return
	allies[actor_id]["health"] = int(allies[actor_id]["max_health"])
	allies[actor_id]["debuffs"] = PackedStringArray()


## Returns one caster to a clean slate: no cast in flight, no cooldown left.
## Every arena restart does this to its ghosts, because a staff that replays
## against a half-spent cooldown would produce a different cycle each time.
func reset_caster(caster: ArenicHeroState) -> void:
	cancel_active(caster)
	_cooldowns.erase(_key(caster))


## Ground damage retains the caster that created it, even after their cast ends.
## Legacy ground and ledger fixtures can omit provenance. They still count
## toward the arena exactly like a hit, without inventing a responsible hero.
func apply_hazard_damage(arena_id: String, enemy_id: String, amount: int, caster_id: String = "", ability_id: String = "") -> void:
	if not _arenas.has(arena_id) or not _arenas[arena_id]["enemies"].has(enemy_id) or amount <= 0:
		return
	_arenas[arena_id]["damage"] += amount
	_arenas[arena_id]["enemies"][enemy_id]["damage"] += amount
	damage_applied.emit(arena_id, enemy_id, amount)
	damage_reported.emit(caster_id, ability_id, arena_id, enemy_id, amount)
	progress_changed.emit(arena_id)


## The encounter calls this once for each running arena's 60Hz step. Existing
## DOTs remain attached to enemy identities during movement and airborne poses.
## Commit this whole tick before observing it, so callbacks see a coherent save.
func advance_enemy_dots(arena_id: String) -> void:
	if not _arenas.has(arena_id) or _enemy_dots.is_empty():
		return
	var surviving: Array[EnemyDot] = []
	var due: Array[EnemyDot] = []
	for dot: EnemyDot in _enemy_dots:
		if dot.arena == arena_id:
			dot.remaining_ticks -= 1
			dot.tick_debt += 1
			if dot.tick_debt >= dot.interval_ticks:
				dot.tick_debt -= dot.interval_ticks
				if _arenas[arena_id]["enemies"].has(dot.enemy_id):
					_arenas[arena_id]["damage"] += dot.damage
					_arenas[arena_id]["enemies"][dot.enemy_id]["damage"] += dot.damage
					due.append(dot)
		if dot.remaining_ticks > 0:
			surviving.append(dot)
	_enemy_dots = surviving
	for dot: EnemyDot in due:
		damage_applied.emit(dot.arena, dot.enemy_id, dot.damage)
		damage_reported.emit(dot.caster_id, dot.ability_id, dot.arena, dot.enemy_id, dot.damage)
		progress_changed.emit(dot.arena)


func clear_enemy_dots(arena_id: String) -> void:
	var surviving: Array[EnemyDot] = []
	for dot: EnemyDot in _enemy_dots:
		if dot.arena != arena_id:
			surviving.append(dot)
	_enemy_dots = surviving


## A bounded read-only HUD projection: one row per ability with its next expiry.
## Different frozen rules may coexist after an Inspector edit or a restored save.
func enemy_dot_effects(arena_id: String, enemy_id: String) -> Array[Dictionary]:
	var grouped: Dictionary = {}
	for dot: EnemyDot in _enemy_dots:
		if dot.arena != arena_id or dot.enemy_id != enemy_id:
			continue
		if not grouped.has(dot.ability_id):
			grouped[dot.ability_id] = {"ticks": dot.remaining_ticks, "stacks": 0, "damage": dot.damage, "interval": dot.interval_ticks, "uniform": true}
		var row: Dictionary = grouped[dot.ability_id]
		row.ticks = mini(row.ticks, dot.remaining_ticks)
		row.stacks += 1
		row.uniform = row.uniform and row.damage == dot.damage and row.interval == dot.interval_ticks
	var result: Array[Dictionary] = []
	var abilities: Array = grouped.keys()
	abilities.sort()
	for ability_id: String in abilities:
		var row: Dictionary = grouped[ability_id]
		var remaining: float = float(row.ticks) / ENEMY_DOT_TICKS_PER_SECOND
		var rule: String = "%d damage every %.2fs per stack" % [row.damage, float(row.interval) / ENEMY_DOT_TICKS_PER_SECOND] if row.uniform else "Each stack keeps its accepted timing and damage"
		result.append({"id": ability_id, "name": _enemy_dot_name(ability_id), "remaining_seconds": remaining,
			"stacks": row.stacks, "beneficial": false,
			"detail": "%d independent stack%s. %s. Next expires in %.2fs." % [row.stacks, "" if row.stacks == 1 else "s", rule, remaining]})
	return result


static func _enemy_dot_name(ability_id: String) -> String:
	var catalog := load("res://data/classes/catalog.tres") as ArenicClassCatalog
	if catalog != null:
		for definition: ArenicClassDefinition in catalog.classes:
			for ability: ArenicClassAbility in definition.skills:
				if ability != null and ability.ability_id == ability_id:
					return ability.title
	return ability_id.capitalize()


## Every point of damage the run has dealt anywhere. Cumulative and monotonic:
## it is the currency guild rolls are earned against, not a balance to spend.
func total_damage() -> int:
	var total: int = 0
	for arena: Dictionary in _arenas.values():
		total += int(arena["damage"])
	return total


func damage_for_arena(arena_id: String) -> int:
	return int(_arenas.get(arena_id, {}).get("damage", 0))


func damage_for_enemy(arena_id: String, enemy_id: String) -> int:
	return int(_arenas.get(arena_id, {}).get("enemies", {}).get(enemy_id, {}).get("damage", 0))


func enemy_footprint(arena_id: String, enemy_id: String) -> Rect2i:
	if enemy_pose_lookup.is_valid():
		var pose: Dictionary = enemy_pose_lookup.call(arena_id, enemy_id)
		if not pose.is_empty():
			return Rect2i() if pose.airborne else pose.footprint
	return _arenas.get(arena_id, {}).get("enemies", {}).get(enemy_id, {}).get("footprint", Rect2i())


## Visual attachment point for an existing identity, including its airborne
## center/lift. This does not change ground hit eligibility or a cast's aim.
func enemy_presentation_pose(arena_id: String, enemy_id: String) -> Dictionary:
	var enemy: Dictionary = _arenas.get(arena_id, {}).get("enemies", {}).get(enemy_id, {})
	if enemy.is_empty():
		return {}
	if enemy_pose_lookup.is_valid():
		var pose: Dictionary = enemy_pose_lookup.call(arena_id, enemy_id)
		if pose.has("center") and pose.has("lift"):
			return {"center": pose.center, "lift": pose.lift, "footprint": pose.footprint, "facing": pose.get("facing", enemy.facing)}
	var footprint: Rect2i = enemy.footprint
	return {"center": Vector2(footprint.position) + Vector2(footprint.size - Vector2i.ONE) * 0.5, "lift": 0.0, "footprint": footprint}


func is_occupied(arena_id: String, cell: Vector2i) -> bool:
	return not enemy_at(arena_id, cell).is_empty()


## Every enemy whose footprint touches an area, in a stable order.
func enemies_in(arena_id: String, area: Rect2i) -> PackedStringArray:
	var found := PackedStringArray()
	for id: String in _enemy_ids(arena_id):
		var footprint: Rect2i = enemy_footprint(arena_id, id)
		if footprint.has_area() and area.intersects(footprint):
			found.append(id)
	return found


## The enemy standing on a cell, or an empty string. Stable order, so broken
## ground under two overlapping targets always damages the same one.
func enemy_at(arena_id: String, cell: Vector2i) -> String:
	for id: String in _enemy_ids(arena_id):
		if enemy_footprint(arena_id, id).has_point(cell):
			return id
	return ""


func phase_size(arena_id: String) -> int:
	var authored: int = int(_arenas.get(arena_id, {}).get("phase_damage", 0))
	return authored if authored > 0 else phase_damage


func completed_phases(arena_id: String) -> int:
	@warning_ignore("integer_division")
	return damage_for_arena(arena_id) / phase_size(arena_id)


func damage_in_phase(arena_id: String) -> int:
	return damage_for_arena(arena_id) % phase_size(arena_id)


## Every cast query is scoped to a caster: with ghosts in the arena there is no
## single "the" cast, and aggregating would make the hotbar report someone else.
func cooldown_remaining(caster: ArenicHeroState) -> float:
	return float(_cooldowns.get(_key(caster), 0.0))


func active_remaining(caster: ArenicHeroState) -> float:
	var cast: Cast = _casts.get(_key(caster))
	return cast.remaining() if cast != null else 0.0


func is_channeling(caster: ArenicHeroState) -> bool:
	var cast: Cast = _casts.get(_key(caster))
	return cast != null and cast.is_channel()


func fortune_loot_bonus(caster: ArenicHeroState) -> float:
	var cast: Cast = _casts.get(_key(caster))
	return cast.loot_bonus if cast != null else 0.0


## Casters with an ability in flight, in a stable order so two runs advance them
## identically.
func casting_ids() -> PackedStringArray:
	var ids: Array = _casts.keys()
	ids.sort()
	return PackedStringArray(ids)


static func _key(caster: ArenicHeroState) -> String:
	return caster.ally_id() if caster != null else ""


## Value-only handoff when a stage/presenter is replaced; never restarts timers.
## Auras report the caster's current position; projectiles keep their cast origin.
func active_cast_snapshot(caster: ArenicHeroState) -> Dictionary:
	var cast: Cast = _casts.get(_key(caster))
	if cast == null:
		return {}
	var follows: bool = cast.ability.effect_kind == "aura"
	return {
		"caster_id": _key(caster),
		"caster_identity": caster.identity_id,
		"ability_id": cast.ability.ability_id,
		"effect_kind": cast.ability.effect_kind,
		"arena_id": cast.owner.arena_id if follows else cast.arena,
		"origin": cast.owner.cell if follows else cast.origin,
		"target_cell": cast.owner.cell if follows else cast.target_cell,
		"target_id": cast.target_id,
		"facing": cast.owner.facing if follows else cast.facing,
		"elapsed": cast.elapsed,
		"remaining": cast.remaining(),
		"is_channeling": cast.is_channel(),
		"cast_seconds": cast.resolve_seconds,
		"duration_seconds": cast.ability.duration_seconds,
		"cast_id": cast.cast_id,
		"released": cast.released,
		"release_seconds": cast.release_seconds,
	}


## Read-only availability, suitable for HUD hints. It never spends a cooldown.
func cast_unavailable_reason(hero: ArenicHeroState, compact: bool = false) -> String:
	if not _valid_hero(hero):
		return "Select hero" if compact else "Choose a hero in an arena first."
	if ally_defeated_at(hero.arena_id, hero.ally_id()):
		return "Defeated" if compact else "This hero is defeated."
	if _casts.has(_key(hero)):
		return "Active" if compact else "Your ability is already active."
	if float(_cooldowns.get(_key(hero), 0.0)) > TIME_EPSILON:
		return "Cooldown" if compact else "Your ability is cooling down."
	if hero.definition.skills.is_empty() or hero.definition.skills[0] == null:
		return "No ability" if compact else "This hero has no starter ability."
	var ability: ArenicClassAbility = hero.definition.skills[0]
	if not _valid_ability(ability):
		return "Not ready" if compact else "This ability is not ready."
	if ability.enemy_dot_duration_seconds > 0.0:
		var target_count: int = enemies_in(hero.arena_id, area_rect(hero.cell, ability.area_size)).size()
		if target_count > MAX_ENEMY_DOTS - _enemy_dots.size():
			return "DOT limit" if compact else "Too many enemy damage-over-time stacks are active. Wait for a stack to expire."
	if ability.effect_kind in ["target", "ground", "channel"] and _nearest_enemy(hero.arena_id, hero.cell, ability).is_empty():
		if compact:
			return "Get behind" if ability.requires_backstab else "No target"
		return "Move behind an adjacent enemy." if ability.requires_backstab else "No enemy is in range."
	return ""


## Returns a user-facing rejection; only accepted casts consume a cooldown.
func try_cast(hero: ArenicHeroState) -> String:
	var unavailable: String = cast_unavailable_reason(hero)
	if not unavailable.is_empty():
		return unavailable
	var ability: ArenicClassAbility = hero.definition.skills[0]
	var cleanse_targets := PackedStringArray()
	var accepted_dots: Array[EnemyDot] = []
	if ability.effect_kind == "cleanse":
		cleanse_targets = enemies_in(hero.arena_id, area_rect(hero.cell, ability.area_size))
		if ability.enemy_dot_duration_seconds > 0.0:
			for enemy_id: String in cleanse_targets:
				var dot := EnemyDot.new()
				dot.caster_id = hero.ally_id()
				dot.ability_id = ability.ability_id
				dot.arena = hero.arena_id
				dot.enemy_id = enemy_id
				dot.remaining_ticks = roundi(ability.enemy_dot_duration_seconds * ENEMY_DOT_TICKS_PER_SECOND)
				dot.interval_ticks = roundi(ability.enemy_dot_tick_seconds * ENEMY_DOT_TICKS_PER_SECOND)
				dot.damage = ability.enemy_dot_damage
				accepted_dots.append(dot)
	_ensure_ally(hero)
	var target: String = ""
	var target_cell: Vector2i = hero.cell
	if ability.effect_kind == "flask":
		# A skill shot: it goes where the hero is facing, whatever is there.
		target_cell = throw_target(hero, ability.range_tiles)
	elif ability.effect_kind in ["target", "ground", "channel"]:
		target = _nearest_enemy(hero.arena_id, hero.cell, ability)
		if target.is_empty():
			return "Move behind an adjacent enemy." if ability.requires_backstab else "No enemy is in range."
		target_cell = nearest_cell(hero.cell, enemy_footprint(hero.arena_id, target))
		var direction: Vector2i = target_cell - hero.cell
		if direction != Vector2i.ZERO:
			hero.facing = ("n" if direction.y > 0 else "s") if absi(direction.y) >= absi(direction.x) else ("e" if direction.x > 0 else "w")
	var caster_id: String = hero.ally_id()
	_cooldowns[caster_id] = ability.cooldown_seconds
	_cast_serial += 1
	var cast_id: int = _cast_serial
	# Reserve every accepted target before any observer can attempt another cast.
	_enemy_dots.append_array(accepted_dots)
	var cast: Cast = null
	if ability.effect_kind not in ["cleanse", "dig"]:
		cast = Cast.new()
		cast.ability = ability
		cast.owner = hero
		cast.arena = hero.arena_id
		cast.origin = hero.cell
		cast.facing = hero.facing
		cast.target_id = target
		cast.target_cell = target_cell
		cast.cast_id = cast_id
		cast.resolve_seconds = ability.resolve_seconds(cast.origin, target_cell) if ability.effect_kind in THROWN_KINDS else ability.duration_seconds
		cast.release_seconds = minf(ability.release_seconds, cast.resolve_seconds) if ability.effect_kind in THROWN_KINDS else 0.0
		_casts[caster_id] = cast
	# Publish the cast before its hits, so effects can attach before hit feedback.
	ability_cast.emit(caster_id, ability.ability_id, hero.arena_id, hero.cell, target_cell, hero.facing)
	if ability.effect_kind == "dig":
		ability_landed.emit(caster_id, ability.ability_id, hero.arena_id, Rect2i(hero.cell, Vector2i.ONE), ability)
		# The ground is not the ledger's to own: the arena's dig field listens to
		# ability_cast above and breaks the tile. One door for live and recorded
		# casts alike, so a ghost digs exactly where its take did.
		ability_phase.emit(caster_id, ability.ability_id, "cast", hero.arena_id, Vector2(hero.cell), cast_id)
		ability_phase.emit(caster_id, ability.ability_id, "end", hero.arena_id, Vector2(hero.cell), cast_id)
	elif ability.effect_kind == "cleanse":
		ability_phase.emit(caster_id, ability.ability_id, "cast", hero.arena_id, Vector2(hero.cell), cast_id)
		_cleanse(hero, ability, cast_id, cleanse_targets)
		ability_phase.emit(caster_id, ability.ability_id, "end", hero.arena_id, Vector2(hero.cell), cast_id)
	elif _casts.get(caster_id) == cast:
		if cast.release_seconds > 0.0:
			ability_phase.emit(caster_id, ability.ability_id, "charge", cast.arena, Vector2(cast.origin), cast_id)
		else:
			_release(cast)
		if _casts.get(caster_id) == cast and ability.effect_kind in THROWN_KINDS and cast.resolve_seconds == 0.0:
			_resolve_cast(cast)
	return ""


## Run once per simulation step, including overview. No background timer exists.
## Advances EVERY caster's cooldown and cast, in a stable order. `present` is a
## convenience: a hero passed here is ensured in the ledger first, so a
## single-hero fixture needs no separate sync_allies call.
func tick(delta: float, present: ArenicHeroState = null) -> void:
	if not is_finite(delta) or delta < 0.0:
		return
	if _valid_hero(present):
		_ensure_ally(present)
	for caster_id: String in _cooldowns.keys():
		if _arena_paused(_hero_arenas.get(caster_id, "")):
			continue
		var left: float = maxf(0.0, float(_cooldowns[caster_id]) - delta)
		if left <= 0.0:
			_cooldowns.erase(caster_id)
		else:
			_cooldowns[caster_id] = left
	for caster_id: String in casting_ids():
		var cast: Cast = _casts.get(caster_id)
		if cast != null and not _arena_paused(cast.arena):
			_advance(cast, delta)


func _arena_paused(arena_id: String) -> bool:
	return arena_paused_lookup.is_valid() and bool(arena_paused_lookup.call(arena_id))


func _advance(cast: Cast, delta: float) -> void:
	var hero: ArenicHeroState = cast.owner
	if not _valid_hero(hero):
		_finish(cast, "cancel")
		return
	# A channel is held on one tile: moving or changing arena drops it.
	if cast.is_channel() and (hero.arena_id != cast.arena or hero.cell != cast.origin):
		_finish(cast, "cancel")
		return
	var step: float = delta
	if not cast.is_channel() or cast.ability.duration_seconds > 0.0:
		step = minf(delta, cast.remaining())
	cast.elapsed += step
	if not cast.released and cast.elapsed + TIME_EPSILON >= cast.release_seconds:
		_release(cast)
		if not _is_live(cast):
			return
	if cast.ability.effect_kind in THROWN_KINDS:
		if cast.remaining() <= TIME_EPSILON:
			_resolve_cast(cast)
		return
	cast.tick_debt += step
	# A finite aura has at most duration/tick hits. Held channels catch up in a
	# bounded batch and retain remaining debt, avoiding an unbounded hitch loop.
	var budget: int = MAX_TICKS_PER_CALL
	while _is_live(cast) and cast.tick_debt + TIME_EPSILON >= cast.ability.tick_seconds and budget > 0:
		cast.tick_debt = maxf(0.0, cast.tick_debt - cast.ability.tick_seconds)
		budget -= 1
		if cast.ability.effect_kind == "aura":
			_aura_tick(cast)
		else:
			_channel_tick(cast)
	if _is_live(cast) and cast.ability.duration_seconds > 0.0 and cast.remaining() <= TIME_EPSILON and cast.tick_debt + TIME_EPSILON < cast.ability.tick_seconds:
		_finish(cast, "end")


func _is_live(cast: Cast) -> bool:
	return _casts.get(cast.owner.ally_id()) == cast


## Cancels one caster's held channel. Fortune and an airborne flask survive key-up.
func cancel_channel(caster: ArenicHeroState) -> void:
	var cast: Cast = _casts.get(_key(caster))
	if cast != null and cast.is_channel():
		_finish(cast, "cancel")


static func nearest_cell(cell: Vector2i, footprint: Rect2i) -> Vector2i:
	return cell.clamp(footprint.position, footprint.end - Vector2i.ONE)


static func distance_to_footprint(cell: Vector2i, footprint: Rect2i) -> int:
	var difference: Vector2i = (cell - nearest_cell(cell, footprint)).abs()
	return maxi(difference.x, difference.y)


## Where a thrown ability lands: `distance` tiles along the caster's facing,
## clamped inside the arena. Nothing blocks it, so a flask thrown at a wall lands
## against the wall rather than vanishing.
static func throw_target(hero: ArenicHeroState, distance: int) -> Vector2i:
	var step := Vector2i.ZERO
	match hero.facing:
		"n": step = Vector2i(0, 1)
		"s": step = Vector2i(0, -1)
		"e": step = Vector2i(1, 0)
		"w": step = Vector2i(-1, 0)
	var limit := Vector2i(ArenicGridMath.GRID_WIDTH - 1, ArenicGridMath.GRID_HEIGHT - 1)
	return (hero.cell + step * maxi(0, distance)).clamp(Vector2i.ZERO, limit)


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
		var footprint: Rect2i = enemy_footprint(arena_id, id)
		if not footprint.has_area():
			continue
		var distance: int = distance_to_footprint(cell, footprint)
		if distance >= best or (ability.requires_adjacent and distance != 1):
			continue
		if ability.requires_backstab and not _behind(cell, footprint, enemy_presentation_pose(arena_id, id).get("facing", enemy["facing"])):
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


func _ground_hit(cast: Cast) -> void:
	for id: String in _enemy_ids(cast.arena):
		if enemy_footprint(cast.arena, id).has_point(cast.target_cell):
			_hit(cast, cast.arena, id, cast.ability.damage)


func _resolve_cast(cast: Cast) -> void:
	if not _is_live(cast):
		return
	if cast.ability.effect_kind == "flask":
		# The flask itself does nothing on impact; what it leaves behind does.
		ability_landed.emit(cast.owner.ally_id(), cast.ability.ability_id, cast.arena, area_rect(cast.target_cell, cast.ability.area_size), cast.ability)
	elif cast.ability.effect_kind == "ground":
		_ground_hit(cast)
	else:
		var enemy: Dictionary = _arenas[cast.arena]["enemies"][cast.target_id]
		var owner: ArenicHeroState = cast.owner
		var footprint: Rect2i = enemy_footprint(cast.arena, cast.target_id)
		var on_target: bool = footprint.has_area() and (cast.ability.ability_id != "auto_shot" or footprint.has_point(cast.target_cell))
		var in_reach: bool = not cast.ability.requires_adjacent or (owner.arena_id == cast.arena and distance_to_footprint(owner.cell, footprint) == 1)
		var behind: bool = not cast.ability.requires_backstab or _behind(owner.cell, footprint, enemy_presentation_pose(cast.arena, cast.target_id).get("facing", enemy["facing"]))
		if on_target and in_reach and behind:
			_hit(cast, cast.arena, cast.target_id, cast.ability.damage)
	_finish(cast, "end")


func _channel_tick(cast: Cast) -> void:
	var enemy: Dictionary = _arenas[cast.arena]["enemies"].get(cast.target_id, {})
	var footprint: Rect2i = enemy_footprint(cast.arena, cast.target_id)
	if not enemy.is_empty() and footprint.has_area() and distance_to_footprint(cast.owner.cell, footprint) <= cast.ability.range_tiles:
		_hit(cast, cast.arena, cast.target_id, cast.ability.damage)


func _aura_tick(cast: Cast) -> void:
	var hero: ArenicHeroState = cast.owner
	for id: String in _enemy_ids(hero.arena_id):
		var footprint: Rect2i = enemy_footprint(hero.arena_id, id)
		if footprint.has_area() and distance_to_footprint(hero.cell, footprint) <= cast.ability.radius_tiles:
			_hit(cast, hero.arena_id, id, cast.ability.damage)
	var nearby: int = 0
	for id: String in _arenas[hero.arena_id]["allies"]:
		var ally: Dictionary = _arenas[hero.arena_id]["allies"][id]
		var difference: Vector2i = (hero.cell - Vector2i(ally["cell"])).abs()
		if id != hero.ally_id() and maxi(difference.x, difference.y) <= cast.ability.radius_tiles:
			nearby += 1
	cast.loot_bonus = nearby * cast.ability.loot_bonus_per_ally


func _cleanse(hero: ArenicHeroState, ability: ArenicClassAbility, cast_id: int, targets: PackedStringArray) -> void:
	var area: Rect2i = area_rect(hero.cell, ability.area_size)
	for id: String in targets:
		# Cleanse is instant, so it has no stored cast to attribute through.
		var instant := Cast.new()
		instant.ability = ability
		instant.owner = hero
		instant.arena = hero.arena_id
		instant.cast_id = cast_id
		_hit(instant, hero.arena_id, id, ability.damage)
	for actor: String in ally_ids(hero.arena_id):
		var ally: Dictionary = _arenas[hero.arena_id]["allies"][actor]
		if area.has_point(ally["cell"]) and (encounter_effects.ruleset == ArenicActorEffects.LEGACY or int(ally.health) > 0):
			encounter_effects.cleanse(actor)
			var changed: bool = ally["health"] < ally["max_health"] or not ally["debuffs"].is_empty()
			ally["health"] = mini(ally["max_health"], ally["health"] + 1)
			ally["debuffs"] = PackedStringArray()
			if changed:
				ability_phase.emit(hero.ally_id(), ability.ability_id, "impact", hero.arena_id, Vector2(ally["cell"]), cast_id)


func _hit(cast: Cast, arena_id: String, enemy_id: String, amount: int) -> void:
	if amount > 0 and cast.ability.ability_id in ["auto_shot", "bash", "backstab", "cleanse"] and direct_bonus_lookup.is_valid():
		amount += int(direct_bonus_lookup.call(arena_id, enemy_id, cast.owner.ally_id()))
	_arenas[arena_id]["damage"] += amount
	_arenas[arena_id]["enemies"][enemy_id]["damage"] += amount
	damage_applied.emit(arena_id, enemy_id, amount)
	damage_reported.emit(cast.owner.ally_id(), cast.ability.ability_id, arena_id, enemy_id, amount)
	progress_changed.emit(arena_id)
	var footprint: Rect2i = enemy_footprint(arena_id, enemy_id)
	var center: Vector2 = Vector2(footprint.position) + Vector2(footprint.size - Vector2i.ONE) * 0.5
	ability_phase.emit(cast.owner.ally_id(), cast.ability.ability_id, "impact", arena_id, center, cast.cast_id)


## Moves every guild member's ledger entry to wherever that hero now stands.
## The ONE place a hero record relocates; health and debuffs travel with it, so
## walking between arenas is never a quiet full heal.
func sync_allies(heroes: Array) -> void:
	for hero: ArenicHeroState in heroes:
		_ensure_ally(hero)


func _ensure_ally(hero: ArenicHeroState) -> void:
	if not _valid_hero(hero):
		return
	var ally_id: String = hero.ally_id()
	var known: String = _hero_arenas.get(ally_id, "")
	if known == hero.arena_id and _arenas[known]["allies"].has(ally_id):
		_arenas[known]["allies"][ally_id]["cell"] = hero.cell
		return
	var carried: Dictionary = {}
	for arena: Dictionary in _arenas.values():
		if arena["allies"].has(ally_id):
			carried = arena["allies"][ally_id]
			arena["allies"].erase(ally_id)
	if carried.is_empty():
		var vitality: int = 4 if encounter_effects.ruleset == ArenicActorEffects.RULESET else 1
		register_ally(hero.arena_id, ally_id, hero.cell, vitality, vitality)
	else:
		carried["cell"] = hero.cell
		_arenas[hero.arena_id]["allies"][ally_id] = carried
	_hero_arenas[ally_id] = hero.arena_id


func _release(cast: Cast) -> void:
	if not _is_live(cast) or cast.released:
		return
	cast.released = true
	var caster_id: String = cast.owner.ally_id()
	ability_phase.emit(caster_id, cast.ability.ability_id, "cast", cast.arena, Vector2(cast.origin), cast.cast_id)
	if _is_live(cast) and cast.ability.effect_kind in ["channel", "aura"]:
		ability_phase.emit(caster_id, cast.ability.ability_id, "sustain", cast.arena, Vector2(cast.origin), cast.cast_id)


func _finish(cast: Cast, phase: String) -> void:
	var caster_id: String = cast.owner.ally_id() if cast.owner != null else ""
	if _casts.get(caster_id) != cast:
		return
	var follows: bool = cast.ability.effect_kind == "aura"
	var arena_id: String = cast.owner.arena_id if follows else cast.arena
	var cell: Vector2 = Vector2(cast.owner.cell if follows else cast.origin)
	_casts.erase(caster_id)
	ability_phase.emit(caster_id, cast.ability.ability_id, phase, arena_id, cell, cast.cast_id)


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
	return not ability.ability_id.is_empty() and ability.effect_kind in ["target", "ground", "channel", "cleanse", "aura", "dig", "flask"] and ability.damage > 0 \
		and ability.enemy_dot_error().is_empty() \
		and is_finite(ability.cooldown_seconds) and ability.cooldown_seconds >= 0.0 and ability.range_tiles >= 0 \
		and is_finite(ability.cast_seconds) and ability.cast_seconds >= 0.0 \
		and is_finite(ability.projectile_speed_tiles_per_second) and (ability.projectile_speed_tiles_per_second == 0.0 or (ability.projectile_speed_tiles_per_second >= 0.1 and ability.projectile_speed_tiles_per_second <= 120.0 and ability.effect_kind == "target")) \
		and is_finite(ability.release_seconds) and ability.release_seconds >= 0.0 \
		and is_finite(ability.duration_seconds) and ability.duration_seconds >= 0.0 \
		and is_finite(ability.tick_seconds) and ability.tick_seconds >= 0.05 \
		and (ability.effect_kind != "aura" or ability.duration_seconds > 0.0) and ability.radius_tiles >= 0 \
		and ability.area_size.x > 0 and ability.area_size.y > 0 \
		and ability.area_size.x <= ArenicGridMath.GRID_WIDTH and ability.area_size.y <= ArenicGridMath.GRID_HEIGHT \
		and is_finite(ability.loot_bonus_per_ally) and ability.loot_bonus_per_ally >= 0.0


func ally_arena(actor: String) -> String:
	for arena_id: String in _arenas:
		if _arenas[arena_id].allies.has(actor):
			return arena_id
	return ""


## Personal damage has one death/cast-cancellation boundary, shared by masks and
## delayed Exposure. Crush passes current health, bypassing ordinary wounds.
func wound_ally(arena_id: String, actor: String, amount: int, source: String) -> void:
	var ally: Dictionary = _arenas.get(arena_id, {}).get("allies", {}).get(actor, {})
	if ally.is_empty() or int(ally.health) <= 0 or amount <= 0:
		return
	var applied: int = mini(int(ally.health), amount)
	ally.health = maxi(0, int(ally.health) - amount)
	boss_wound.emit(arena_id, actor, source, applied)
	if ally.health == 0:
		_notify_defeat(arena_id, actor)


func _notify_defeat(arena_id: String, actor: String) -> void:
	if encounter_effects.ruleset == ArenicActorEffects.RULESET:
		var cast: Cast = _casts.get(actor)
		if cast != null:
			_finish(cast, "cancel")
		encounter_effects.cleanse(actor)
	ally_defeated.emit(arena_id, actor)
