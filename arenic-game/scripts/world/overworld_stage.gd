class_name ArenicOverworldStage
extends Node3D
## Stable world instance: both navigation and future sequences address this scene.
@export var world: ArenicWorldDefinition
var selected_index: int = 0
@onready var camera_rig: ArenicCameraRig = $CameraRig
@onready var labels: ArenicWorldLabels = $Labels/WorldLabels
var _arenas: Array[ArenicArenaView] = []
var hero_view: ArenicHeroView

func _ready() -> void:
	if world == null:
		push_error("OverworldStage needs its world definition.")
		return
	var errors := world.validation_errors()
	if not errors.is_empty():
		push_error("Invalid overworld: " + "; ".join(errors))
		return
	for child in $Arenas.get_children():
		if child is ArenicArenaView:
			_arenas.append(child)
	labels.configure(world, camera_rig)
	labels.clip_rectangle = get_viewport().get_visible_rect()
	camera_rig.frame_bounds(ArenicGridMath.world_rect(), false)

func _process(_delta: float) -> void:
	for index in _arenas.size():
		var arena := _arenas[index]
		arena.visible = camera_rig.view_span.x > ArenicGridMath.ARENA_WIDTH + 0.01 or index == selected_index

func select_arena(index: int) -> void:
	if index < 0 or index >= world.arenas.size():
		return
	selected_index = index
	labels.selected_index = index

func get_arena(index: int) -> ArenicArenaView:
	return _arenas[index] if index >= 0 and index < _arenas.size() else null

func set_view_rect(rectangle: Rect2) -> void:
	camera_rig.set_view_rect(rectangle)
	labels.clip_rectangle = rectangle

func arena_at_screen(point: Vector2) -> int:
	if not labels.clip_rectangle.has_point(point):
		return -1
	var world_point := camera_rig.screen_to_world(point)
	if not world_point.is_finite():
		return -1
	for index in world.arenas.size():
		if camera_rig.view_span.x <= ArenicGridMath.ARENA_WIDTH + 0.01 and index != selected_index:
			continue
		if ArenicGridMath.arena_rect(world.arenas[index].grid_slot).has_point(Vector2(world_point.x, world_point.z)):
			return index
	return -1

func mount_hero(hero: ArenicHeroState) -> void:
	if is_instance_valid(hero_view):
		hero_view.free()
	if hero == null or hero.definition == null or hero.definition.world_sprite_frames == null:
		push_error("Chosen hero needs an authored world sprite.")
		return
	hero_view = ArenicHeroView.new()
	hero_view.name = "Hero"
	hero_view.configure(hero)
	var arena := get_arena(world.index_for_id(hero.arena_id))
	if arena == null:
		hero_view.free()
		push_error("Chosen hero is in an unknown arena.")
		return
	arena.get_node("ContentSlot").add_child(hero_view)
	sync_hero(false)

func sync_hero(show_selection: bool) -> void:
	if not is_instance_valid(hero_view):
		return
	var arena := get_arena(world.index_for_id(hero_view.state.arena_id))
	if arena == null:
		return
	var content := arena.get_node("ContentSlot")
	if hero_view.get_parent() != content:
		hero_view.reparent(content, false)
	hero_view.sync(arena.definition, show_selection)

func hero_at_screen(point: Vector2) -> bool:
	if not is_instance_valid(hero_view):
		return false
	var index := world.index_for_id(hero_view.state.arena_id)
	if index != arena_at_screen(point):
		return false
	var world_point := camera_rig.screen_to_world(point)
	return ArenicGridMath.world_to_tile(world.arenas[index].grid_slot, world_point) == hero_view.state.cell
