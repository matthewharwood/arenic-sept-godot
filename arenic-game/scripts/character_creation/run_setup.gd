extends Node

signal class_chosen(definition: ArenicClassDefinition)

## In-memory run state survives stage swaps. A new game resets both ledgers.
var selected_class: ArenicClassDefinition
var hero: ArenicHeroState
var combat: ArenicCombatState


func begin_new_game() -> void:
	selected_class = null
	hero = null
	combat = null


func choose_class(definition: ArenicClassDefinition) -> void:
	if definition == null:
		return
	selected_class = definition
	hero = ArenicHeroState.new()
	hero.definition = definition
	combat = ArenicCombatState.new()
	class_chosen.emit(definition)

func get_hero() -> ArenicHeroState:
	if hero == null:
		hero = ArenicHeroState.new()
		hero.definition = selected_class if selected_class != null else load("res://data/classes/hunter.tres") as ArenicClassDefinition
	return hero

func get_combat() -> ArenicCombatState:
	if combat == null:
		combat = ArenicCombatState.new()
	return combat
