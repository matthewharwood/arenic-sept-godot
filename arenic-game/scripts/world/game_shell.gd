class_name ArenicGameShell
extends Node
## One navigation authority; HUD survives stage swaps and camera zooms.
@export var stage_scene: PackedScene
@export var entry_sequence: PackedScene
var stage: ArenicOverworldStage
var selected_index: int = 0
var zoomed: bool = false
var sequence_active: bool = false
var _sequence: ArenicWorldSequence
var hero: ArenicHeroState
var _hero_input := ArenicHeroInput.new()
var music: ArenicArenaMusicDirector
@onready var hud: ArenicWorldHUD = $HUD/HUDOutline

func _ready() -> void:
	ArenicDisplayPolicy.apply_game_layout(get_window())
	music = ArenicArenaMusicDirector.new()
	music.name = "ArenaMusic"
	add_child(music)
	hud.world_rect_changed.connect(_update_view_rect)
	hud.toggle_requested.connect(toggle_view)
	replace_stage(stage_scene)
	if entry_sequence != null:
		play_sequence(entry_sequence)

func replace_stage(packed: PackedScene) -> void:
	if packed == null:
		push_error("GameShell needs a stage scene.")
		return
	var instance := packed.instantiate()
	var candidate := instance as ArenicOverworldStage
	if candidate == null:
		instance.free()
		push_error("GameShell stage must extend ArenicOverworldStage.")
		return
	if candidate.world == null or not candidate.world.validation_errors().is_empty():
		push_error("Replacement stage needs a valid nine-arena world definition.")
		candidate.free()
		return
	var run_hero: ArenicHeroState = RunSetup.get_hero()
	if candidate.world.index_for_id(run_hero.arena_id) < 0:
		candidate.free()
		push_error("Replacement stage must contain the current hero arena: " + run_hero.arena_id)
		return
	_stop_sequence()
	if is_instance_valid(stage):
		$ContentSlot.remove_child(stage)
		stage.queue_free()
	stage = candidate
	stage.overview_changed.connect(hud.set_overview_mix)
	$ContentSlot.add_child(stage)
	hud.set_overview_mix(stage.overview_mix)
	music.configure(stage)
	_hero_input.clear()
	hero = run_hero
	stage.mount_hero(hero)
	selected_index = stage.world.index_for_id(hero.arena_id)
	zoomed = false
	stage.select_arena(selected_index)
	_update_view_rect()
	_frame(false)
	_update_hud()

func select_arena(index: int) -> void:
	if sequence_active or not is_instance_valid(stage) or index < 0 or index >= stage.world.arenas.size():
		return
	_hero_input.clear()
	selected_index = index
	stage.select_arena(index)
	if zoomed:
		_frame(true)
	_update_hud()

func toggle_view() -> void:
	set_zoomed(not zoomed)

func set_zoomed(value: bool) -> void:
	if sequence_active or not is_instance_valid(stage):
		return
	_hero_input.clear()
	zoomed = value
	_frame(true)
	_update_hud()

func _frame(animated: bool) -> void:
	var bounds := ArenicGridMath.arena_rect(stage.world.arenas[selected_index].grid_slot) if zoomed else ArenicGridMath.world_rect()
	stage.camera_rig.frame_bounds(bounds, animated)

func _update_view_rect() -> void:
	if is_instance_valid(stage):
		stage.set_view_rect(hud.get_world_rect())

func _update_hud() -> void:
	music.set_focus(StringName(stage.world.arenas[selected_index].arena_id), zoomed)
	var definition := hero.definition
	hud.set_context(stage.world.arenas[selected_index], definition.character_name, definition.display_name, zoomed)
	hud.set_hero_control(_hero_in_focused_arena(), hero.selected)
	stage.sync_hero(_hero_in_focused_arena())

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(stage):
		return
	if sequence_active:
		if event.is_action_pressed("ui_cancel"):
			_sequence.cancel()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var handled := true
		if event.keycode == KEY_TAB and not event.ctrl_pressed and not event.meta_pressed and not event.alt_pressed:
			select_hero()
		elif _hero_in_focused_arena() and _hero_input.accept(event):
			if not hero.selected:
				_hero_input.clear()
		elif event.is_action_pressed("world_toggle"):
			toggle_view()
		elif event.is_action_pressed("world_zoom"):
			set_zoomed(true)
		elif event.is_action_pressed("ui_cancel"):
			set_zoomed(false)
		elif event.is_action_pressed("world_previous"):
			select_arena(posmod(selected_index - 1, stage.world.arenas.size()))
		elif event.is_action_pressed("world_next"):
			select_arena(posmod(selected_index + 1, stage.world.arenas.size()))
		elif event.is_action_pressed("ui_left"):
			_move_selection(Vector2i.LEFT)
		elif event.is_action_pressed("ui_right"):
			_move_selection(Vector2i.RIGHT)
		elif event.is_action_pressed("ui_up"):
			_move_selection(Vector2i.UP)
		elif event.is_action_pressed("ui_down"):
			_move_selection(Vector2i.DOWN)
		else:
			handled = false
			if not event.ctrl_pressed and not event.meta_pressed and not event.alt_pressed:
				for index in stage.world.arenas.size():
					if OS.get_keycode_string(event.keycode).to_upper() == stage.world.arenas[index].hotkey.to_upper():
						select_arena(index)
						handled = true
						break
		if handled:
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed:
		var index := stage.arena_at_screen(event.position)
		if index < 0:
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if _hero_in_focused_arena() and index == selected_index:
				_hero_input.clear()
				hero.selected = stage.hero_at_screen(event.position)
				_update_hud()
			else:
				select_arena(index)
			if event.double_click:
				set_zoomed(true)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_zoomed(true)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_zoomed(false)
		else:
			return
		get_viewport().set_input_as_handled()

func _move_selection(direction: Vector2i) -> void:
	var slot := stage.world.arenas[selected_index].grid_slot + direction
	var index := stage.world.index_for_slot(slot)
	if index >= 0:
		select_arena(index)

func play_sequence(packed: PackedScene) -> void:
	if packed == null or not is_instance_valid(stage):
		return
	var instance := packed.instantiate()
	var candidate := instance as ArenicWorldSequence
	if candidate == null:
		instance.free()
		push_error("Entry sequence must extend ArenicWorldSequence.")
		return
	_stop_sequence()
	_sequence = candidate
	sequence_active = true
	_hero_input.clear()
	stage.sync_hero(false)
	stage.camera_rig.acquire_sequence()
	stage.get_node("SequenceSlot").add_child(_sequence)
	_sequence.finished.connect(_on_sequence_finished, CONNECT_ONE_SHOT)
	_sequence.start(stage)

func _on_sequence_finished() -> void:
	if not sequence_active:
		return
	sequence_active = false
	stage.camera_rig.release_sequence()
	if is_instance_valid(_sequence):
		_sequence.queue_free()
	_sequence = null
	_frame(true)
	_update_hud()

func _stop_sequence() -> void:
	if is_instance_valid(_sequence):
		if _sequence.finished.is_connected(_on_sequence_finished):
			_sequence.finished.disconnect(_on_sequence_finished)
		_sequence.cancel()
		_sequence.queue_free()
	_sequence = null
	sequence_active = false
	if is_instance_valid(stage):
		stage.camera_rig.release_sequence()

func _hero_in_focused_arena() -> bool:
	return hero != null and is_instance_valid(stage) and zoomed and not sequence_active and stage.world.arenas[selected_index].arena_id == hero.arena_id

func select_hero() -> void:
	if sequence_active or hero == null:
		return
	hero.selected = true
	select_arena(stage.world.index_for_id(hero.arena_id))
	set_zoomed(true)

func _physics_process(_delta: float) -> void:
	var direction := _hero_input.consume()
	if direction == Vector2i.ZERO or not _hero_in_focused_arena() or not hero.selected:
		return
	var previous_arena := hero.arena_id
	if hero.step(direction, stage.world):
		if hero.arena_id != previous_arena:
			select_arena(stage.world.index_for_id(hero.arena_id))
		else:
			stage.sync_hero(true)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_hero_input.clear()
