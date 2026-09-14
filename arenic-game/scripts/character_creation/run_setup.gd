extends Node

signal class_chosen(definition: ArenicClassDefinition)
signal hero_recruited(hero: ArenicHeroState)

## In-memory run state survives stage swaps. A new game resets both ledgers.
## The guild grows over a run, so heroes are a roster from the start even while
## it holds exactly one: nothing downstream may assume a single hero.
const GUILD_ARENA: String = "guild_house"
const GUILD_CELL: Vector2i = Vector2i(30, 15)
const MAX_GUILD: int = 320

var selected_class: ArenicClassDefinition
var heroes: Array[ArenicHeroState] = []
var selected_identity: int = -1
## The member each arena hands control to when you arrive there. An arena
## remembers whoever you last selected in it, so walking a patrol of arenas picks
## up where you left off rather than resetting to the top of the roster.
var arena_selection: Dictionary[String, int] = {}
var combat: ArenicCombatState
var recruitment: ArenicRecruitmentState
var gathering: ArenicGatheringState
var loot: ArenicLootState
## Everything digging has yielded this run. Damage is one income; broken ground
## is the other, and both count toward the same guild rolls.
var prospected: int = 0
## Stable domain seed; a slot's random identity is independent of its fixture.
var run_seed: int = 1
## Next prologue beat: quote (0), beckoning (1), dialogue (2-5), complete (6).
## Animation/read timers are presentation; this checkpoint alone survives reload.
var intro_step: int = 0
var _next_identity: int = 0
const RECRUITMENT_CURVE: ArenicRecruitmentCurve = preload("res://data/guild/recruitment.tres")
const GATHERING: ArenicGatheringDefinition = preload("res://data/guild/gathering.tres")
const CLASSES: ArenicClassCatalog = preload("res://data/classes/catalog.tres")


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
	run_seed = 1
	intro_step = 0
	_next_identity = 0


func choose_class(definition: ArenicClassDefinition) -> void:
	if definition == null:
		return
	selected_class = definition
	heroes.clear()
	selected_identity = -1
	arena_selection.clear()
	_next_identity = 0
	combat = ArenicCombatState.new()
	combat.encounter_effects.ruleset = ArenicActorEffects.RULESET
	var founder: ArenicHeroState = recruit(definition)
	if intro_step == 0:
		founder.cell = Vector2i(33, 15) # New-game center; Continue restores its saved placement.
	class_chosen.emit(definition)


## Adds a guild member at the Guild House. New heroes arrive unrecorded: they
## are controllable until the player commits a staff for them somewhere.
func recruit(definition: ArenicClassDefinition) -> ArenicHeroState:
	if definition == null or heroes.size() >= MAX_GUILD:
		return null
	var hero := ArenicHeroState.new()
	hero.definition = definition
	hero.identity_id = _next_identity
	hero.arena_id = GUILD_ARENA
	hero.cell = ArenicHeroPlacement.for_hero(GUILD_ARENA, GUILD_CELL, heroes, combat)
	if hero.cell == ArenicHeroPlacement.NONE:
		return null
	hero.facing = "n"
	hero.selected = heroes.is_empty()
	_next_identity += 1
	heroes.append(hero)
	if selected_identity < 0:
		# The founding member is selected without going through select(), so its
		# arena is told here rather than left with nothing to remember.
		selected_identity = hero.identity_id
		remember_selection(hero.arena_id, hero.identity_id)
	hero_recruited.emit(hero)
	return hero


## Records who an arena should hand control to next time. Called wherever
## selection actually changes, so the memory cannot drift from the selection.
func remember_selection(arena_id: String, identity_id: int) -> void:
	if not arena_id.is_empty() and identity_id >= 0:
		arena_selection[arena_id] = identity_id


## Forgets an arena's default, but only if `identity_id` is the member it was
## holding. Another member leaving must not erase a memory that is still valid.
func forget_selection(arena_id: String, identity_id: int) -> void:
	if arena_selection.get(arena_id, -1) == identity_id:
		arena_selection.erase(arena_id)


## The member an arena remembers, or -1 when it has never been visited — or when
## the member it remembered has since walked out.
func selection_for(arena_id: String) -> int:
	return int(arena_selection.get(arena_id, -1))


func get_heroes() -> Array[ArenicHeroState]:
	if heroes.is_empty():
		recruit(selected_class if selected_class != null else load("res://data/classes/hunter.tres") as ArenicClassDefinition)
	return heroes


## The hero the player currently controls. Never null once a run exists.
func get_hero() -> ArenicHeroState:
	var roster: Array[ArenicHeroState] = get_heroes()
	for hero: ArenicHeroState in roster:
		if hero.identity_id == selected_identity:
			return hero
	selected_identity = roster[0].identity_id
	return roster[0]


func hero_for(identity_id: int) -> ArenicHeroState:
	for hero: ArenicHeroState in heroes:
		if hero.identity_id == identity_id:
			return hero
	return null


func select(identity_id: int) -> bool:
	var hero: ArenicHeroState = hero_for(identity_id)
	if hero == null:
		return false
	selected_identity = identity_id
	for member: ArenicHeroState in heroes:
		member.selected = member.identity_id == identity_id
	# Selection and an arena's memory of it change together, in one place, so
	# the two cannot drift apart.
	remember_selection(hero.arena_id, identity_id)
	return true


## Guild members standing in one arena, in a stable order.
func heroes_in(arena_id: String) -> Array[ArenicHeroState]:
	var present: Array[ArenicHeroState] = []
	for hero: ArenicHeroState in heroes:
		if hero.arena_id == arena_id:
			present.append(hero)
	return present


func get_recruitment() -> ArenicRecruitmentState:
	if recruitment == null:
		recruitment = ArenicRecruitmentState.new()
		recruitment.configure(RECRUITMENT_CURVE, MAX_GUILD)
	return recruitment


func class_catalog() -> ArenicClassCatalog:
	return CLASSES


func get_combat() -> ArenicCombatState:
	if combat == null:
		combat = ArenicCombatState.new()
	return combat


func get_gathering() -> ArenicGatheringState:
	if gathering == null:
		gathering = ArenicGatheringState.new()
		gathering.configure(GATHERING)
	return gathering


func get_loot() -> ArenicLootState:
	if loot == null:
		loot = ArenicLootState.new()
	return loot
