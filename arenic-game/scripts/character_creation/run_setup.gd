extends Node

signal class_chosen(definition: ArenicClassDefinition)

## In-memory new-game choice. This is not a save file or combat state.
var selected_class: ArenicClassDefinition
var hero: ArenicHeroState


func begin_new_game() -> void:
	selected_class = null
	hero = null


func choose_class(definition: ArenicClassDefinition) -> void:
	if definition == null:
		return
	selected_class = definition
	hero = ArenicHeroState.new()
	hero.definition = definition
	class_chosen.emit(definition)

func get_hero() -> ArenicHeroState:
	if hero == null:
		hero = ArenicHeroState.new()
		hero.definition = selected_class if selected_class != null else load("res://data/classes/hunter.tres") as ArenicClassDefinition
	return hero
