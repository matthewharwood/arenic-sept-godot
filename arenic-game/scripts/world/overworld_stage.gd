class_name ArenicOverworldStage
extends Node3D
## Stable world instance: both navigation and future sequences address this scene.
signal overview_changed(value: float)
@export var world: ArenicWorldDefinition
var selected_index: int = 0
@onready var camera_rig: ArenicCameraRig = $CameraRig
@onready var labels: ArenicWorldLabels = $Labels/WorldLabels
var _arenas: Array[ArenicArenaView] = []
## One view per guild member, keyed by run identity. A hero is drawn in the
## arena it currently stands in, so views reparent as heroes travel.
var hero_views: Dictionary[int, ArenicHeroView] = {}
var selected_identity: int = -1
## The controlled hero's view. Ability presentation animates the caster, and
## only the controlled hero casts live; recorded casts will resolve through
## their own performer's view when ghost playback arrives.
var hero_view: ArenicHeroView:
	get:
		return hero_views.get(selected_identity)
var transition: ArenicArenaTransition
var atmosphere: ArenicOverworldAtmosphere
var overview_mix: float = -1.0
var _cull_dirty: bool = true
var _all_visible: bool = false
var _last_focus: Vector3
var _last_span: Vector2
var _last_basis: Basis

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
	for arena: ArenicArenaView in _arenas:
		var environment := arena.get_node("EnvironmentLayers") as ArenicArenaEnvironment
		environment.configure_regions(world)
	atmosphere = ArenicOverworldAtmosphere.new()
	atmosphere.name = "OverworldAtmosphere"
	add_child(atmosphere)
	atmosphere.configure(camera_rig, world)
	transition = ArenicArenaTransition.new()
	transition.name = "Transition"
	add_child(transition)
	transition.configure(camera_rig, world.arenas[0].visual_theme)
	camera_rig.motion_started.connect(_on_motion_started)
	camera_rig.motion_advanced.connect(_sync_overview_presentation)
	camera_rig.settled.connect(_sync_overview_presentation)
	var environment_node := $WorldEnvironment as WorldEnvironment
	environment_node.environment = environment_node.environment.duplicate()
	environment_node.environment.background_color = world.arenas[0].visual_theme.color("base_300")
	labels.configure(world, camera_rig)
	labels.clip_rectangle = get_viewport().get_visible_rect()
	camera_rig.frame_bounds(ArenicGridMath.world_rect(), false)

func _process(_delta: float) -> void:
	_sync_overview_presentation()
	# Tweens update after node processing. Show the swept world synchronously at
	# motion start; renderer frustum culling handles the nine bounded arenas.
	if camera_rig.motion_active or camera_rig.sequence_owned:
		_show_all_arenas()
		_cull_dirty = true
		return
	if not _cull_dirty and _last_focus == camera_rig.focus_world and _last_span == camera_rig.view_span and _last_basis == camera_rig.global_basis:
		return
	_cull_dirty = false
	_last_focus = camera_rig.focus_world
	_last_span = camera_rig.view_span
	_last_basis = camera_rig.global_basis
	var rectangle: Rect2 = labels.clip_rectangle
	var visible_bounds := Rect2()
	var first: bool = true
	for point: Vector2 in [rectangle.position, rectangle.end, Vector2(rectangle.position.x, rectangle.end.y), Vector2(rectangle.end.x, rectangle.position.y)]:
		var hit: Vector3 = camera_rig.screen_to_world(point)
		if not hit.is_finite():
			_show_all_arenas()
			return
		var flat := Vector2(hit.x, hit.z)
		if first:
			visible_bounds = Rect2(flat, Vector2.ZERO)
			first = false
		else:
			visible_bounds = visible_bounds.expand(flat)
	# Exclude numerical edge contact, well below a rendered pixel.
	visible_bounds = visible_bounds.grow(-0.00001)
	for arena: ArenicArenaView in _arenas:
		arena.visible = visible_bounds.intersects(ArenicGridMath.arena_rect(arena.definition.grid_slot))
	_all_visible = false

func _sync_overview_presentation(_progress: float = 1.0) -> void:
	if not is_inside_tree() or not is_instance_valid(atmosphere) or not atmosphere.is_inside_tree():
		return # Camera teardown also emits progress; the presentation may be detached.
	# Derive presentation from the actual camera span, also during cinematic seeks.
	var value: float = smoothstep(22.0, 46.0, camera_rig.view_span.x)
	atmosphere.sync_projection()
	if value == overview_mix:
		return
	overview_mix = value
	for arena: ArenicArenaView in _arenas:
		(arena.get_node("EnvironmentLayers") as ArenicArenaEnvironment).set_overview_mix(value)
	atmosphere.set_overview_mix(value)
	overview_changed.emit(value)

func _on_motion_started(_duration: float) -> void:
	_show_all_arenas()
	_cull_dirty = true

func _show_all_arenas() -> void:
	if _all_visible:
		return
	for arena: ArenicArenaView in _arenas:
		arena.visible = true
	_all_visible = true

func select_arena(index: int) -> void:
	if index < 0 or index >= world.arenas.size():
		return
	selected_index = index
	labels.selected_index = index
	transition.set_theme(world.arenas[index].visual_theme)
	$WorldEnvironment.environment.background_color = world.arenas[index].visual_theme.color("base_300")

func get_arena(index: int) -> ArenicArenaView:
	return _arenas[index] if index >= 0 and index < _arenas.size() else null

func set_view_rect(rectangle: Rect2) -> void:
	camera_rig.set_view_rect(rectangle)
	labels.clip_rectangle = rectangle
	transition.set_view_rect(rectangle)
	atmosphere.sync_projection(true)
	_cull_dirty = true

func arena_at_screen(point: Vector2) -> int:
	if not labels.clip_rectangle.has_point(point) or not atmosphere.contains_land_point(point):
		return -1
	var world_point := camera_rig.screen_to_world(point)
	if not world_point.is_finite():
		return -1
	for index in world.arenas.size():
		if not _arenas[index].is_visible_in_tree():
			continue
		if ArenicGridMath.arena_rect(world.arenas[index].grid_slot).has_point(Vector2(world_point.x, world_point.z)):
			return index
	return -1

func mount_heroes(heroes: Array) -> void:
	for view: ArenicHeroView in hero_views.values():
		if is_instance_valid(view):
			view.free()
	hero_views.clear()
	for hero: ArenicHeroState in heroes:
		_mount_hero(hero)

## Adds one guild member's view. Called again as the guild grows; a hero that
## already has a view keeps it rather than being rebuilt mid-cycle.
func _mount_hero(hero: ArenicHeroState) -> void:
	if hero == null or hero.definition == null or hero.definition.world_sprite_frames == null:
		push_error("A guild member needs an authored world sprite.")
		return
	if hero_views.has(hero.identity_id) and is_instance_valid(hero_views[hero.identity_id]):
		return
	var arena := get_arena(world.index_for_id(hero.arena_id))
	if arena == null:
		push_error("A guild member is in an unknown arena: " + hero.arena_id)
		return
	var view := ArenicHeroView.new()
	view.name = "Hero%d" % hero.identity_id
	view.configure(hero)
	arena.get_node("ContentSlot").add_child(view)
	hero_views[hero.identity_id] = view

## Draws every guild member where it stands. Only `selected_identity` wears the
## selection ring; the rest are present and visible but unmarked.
func sync_heroes(identity_id: int, show_selection: bool, ghost_check: Callable = Callable(), defeated_check: Callable = Callable()) -> void:
	selected_identity = identity_id
	for identity: int in hero_views.keys():
		var view: ArenicHeroView = hero_views[identity]
		if not is_instance_valid(view):
			hero_views.erase(identity)
			continue
		var arena := get_arena(world.index_for_id(view.state.arena_id))
		if arena == null:
			continue
		var content := arena.get_node("ContentSlot")
		if view.get_parent() != content:
			view.reparent(content, false)
		if ghost_check.is_valid():
			view.set_ghost(bool(ghost_check.call(view.state)))
		if defeated_check.is_valid():
			view.set_defeated(bool(defeated_check.call(view.state)))
		view.sync(arena.definition, show_selection and identity == identity_id)

## The run identity of a guild member under `point`, or -1. Later members win a
## shared tile, matching how they are drawn.
func hero_at_screen(point: Vector2) -> int:
	var found: int = -1
	for identity: int in hero_views.keys():
		var view: ArenicHeroView = hero_views[identity]
		if not is_instance_valid(view):
			continue
		var index := world.index_for_id(view.state.arena_id)
		if index != arena_at_screen(point):
			continue
		var world_point := camera_rig.screen_to_world(point)
		if ArenicGridMath.world_to_tile(world.arenas[index].grid_slot, world_point) == view.state.cell:
			found = identity
	return found
