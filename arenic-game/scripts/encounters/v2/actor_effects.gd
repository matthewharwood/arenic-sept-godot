class_name ArenicActorEffects
extends RefCounted
## Actor-owned cycle facts. The source arena clock owns delayed wounds even if
## an actor walks elsewhere. Fonts and claims never masquerade as cleansable DOTs.
const LEGACY: String = "legacy-1"
const RULESET: String = "cardinal-1"
var ruleset: String = LEGACY
var fingerprint: String = ""
var actors: Dictionary = {}

func state(arena: String, actor: String) -> Dictionary:
	if not actors.has(arena):
		actors[arena] = {}
	if not actors[arena].has(actor):
		actors[arena][actor] = {"attunement": "", "exposures": [], "claims": []}
	return actors[arena][actor]

func attunement(arena: String, actor: String) -> String:
	return actors.get(arena, {}).get(actor, {}).get("attunement", "")

func enter_fonts(score: ArenicMaskScore, combat: ArenicCombatState) -> void:
	for actor: String in combat.ally_ids(score.arena_id):
		var ally: Dictionary = combat.ally_status(score.arena_id, actor)
		if ally.health <= 0:
			continue
		if ally.cell == score.sun_font:
			state(score.arena_id, actor).attunement = "sun"
		elif ally.cell == score.moon_font:
			state(score.arena_id, actor).attunement = "moon"

func expose(score: ArenicMaskScore, event: ArenicScoreEvent, actor: String) -> void:
	var stacks: Array = state(score.arena_id, actor).exposures
	for stack: Dictionary in stacks:
		if stack.event_id == event.event_id:
			return
	var incoming: Dictionary = {"event_id": event.event_id, "due_tick": event.at_tick + score.exposure_delay_ticks, "damage": score.exposure_damage}
	if stacks.size() == 4:
		push_warning("Exposure reached its four-stack bound for " + actor)
		if stacks[-1].due_tick <= incoming.due_tick:
			return
		stacks.pop_back()
	stacks.append(incoming)
	stacks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.due_tick < b.due_tick if a.due_tick != b.due_tick else a.event_id < b.event_id)

func cleanse(actor: String) -> void:
	for arena: Dictionary in actors.values():
		if arena.has(actor):
			arena[actor].exposures.clear()

func clear_actor(actor: String) -> void:
	for arena: Dictionary in actors.values():
		arena.erase(actor)

func advance(arena_id: String, tick: int, combat: ArenicCombatState) -> void:
	var present: Dictionary = actors.get(arena_id, {})
	var ids: Array = present.keys()
	ids.sort()
	for actor: String in ids:
		# Signals can relocate and clear an actor; retain only this tick's work.
		var stacks: Array = present[actor].exposures
		var due: Array = stacks.filter(func(stack: Dictionary) -> bool: return int(stack.due_tick) == tick)
		present[actor].exposures = stacks.filter(func(stack: Dictionary) -> bool: return int(stack.due_tick) >= tick)
		for stack: Dictionary in due:
			var location: String = combat.ally_arena(actor)
			if not location.is_empty():
				combat.wound_ally(location, actor, int(stack.damage), stack.event_id + ".exposure")

func claim(score: ArenicMaskScore, tick: int, actor: String) -> int:
	for event: ArenicScoreEvent in score.events:
		if event.kind != "window" or tick < event.at_tick or tick >= event.end_tick or attunement(score.arena_id, actor) != event.attunement_bonus:
			continue
		var personal: Dictionary = state(score.arena_id, actor)
		if event.event_id not in personal.claims:
			personal.claims.append(event.event_id)
			return score.bonus_damage
	return 0
