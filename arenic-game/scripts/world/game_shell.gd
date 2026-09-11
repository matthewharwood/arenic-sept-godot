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
var combat: ArenicCombatState
var combat_presentation: ArenicCombatPresentation
var sound: ArenicGameplayAudio
const MOVEMENT_SOUNDS: ArenicMovementSoundProfile = preload("res://data/audio/movement.tres")
var _cast_queued: bool = false
var _space_held: bool = false
var _button_held: bool = false
var _combat_hud_elapsed: float = 0.0
var _cast_notice: String = ""
var _notice_seconds: float = 0.0
@onready var hud: ArenicWorldHUD = $HUD/HUDOutline

func _ready() -> void:
	ArenicDisplayPolicy.apply_game_layout(get_window())
	music = ArenicArenaMusicDirector.new()
	music.name = "ArenaMusic"
	add_child(music)
	sound = ArenicGameplayAudio.new()
	sound.name = "GameplayAudio"
	add_child(sound)
	hud.world_rect_changed.connect(_update_view_rect)
	hud.toggle_requested.connect(toggle_view)
	hud.ability_requested.connect(_on_ability_requested)
	hud.ability_released.connect(_on_ability_released)
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
	_mount_combat()
	sound.configure(stage, hero, combat, MOVEMENT_SOUNDS)
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
	_cancel_cast_input()
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
	_cancel_cast_input()
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
	sound.set_focus(stage.world.arenas[selected_index].arena_id, zoomed and not sequence_active)
	var definition := hero.definition
	hud.set_context(stage.world.arenas[selected_index], definition.character_name, definition.display_name, zoomed)
	hud.set_hero_control(_hero_in_focused_arena(), hero.selected)
	stage.sync_hero(_hero_in_focused_arena())
	_update_combat_hud()

func _input(event: InputEvent) -> void:
	# Release is observed even when a Control consumes the matching mouse/key event.
	if event is InputEventKey and not event.pressed and (event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE):
		_space_held = false
		_release_channel_if_needed()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_button_held = false
		_release_channel_if_needed()

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
		if (event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE) and not event.ctrl_pressed and not event.meta_pressed and not event.alt_pressed:
			_space_held = true
			_queue_cast()
		elif event.keycode == KEY_TAB and not event.ctrl_pressed and not event.meta_pressed and not event.alt_pressed:
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
				if not hero.selected:
					_cancel_cast_input()
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
	_cancel_cast_input()
	stage.sync_hero(false)
	sound.set_focus("", false)
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
	_cancel_cast_input()
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

func _physics_process(delta: float) -> void:
	if not is_instance_valid(stage) or hero == null or combat == null:
		return
	var direction := _hero_input.consume()
	if direction != Vector2i.ZERO and _hero_in_focused_arena() and hero.selected:
		combat.cancel_channel()
		var previous_arena: String = hero.arena_id
		var previous_cell: Vector2i = hero.cell
		var previous_facing: String = hero.facing
		if hero.step(direction, stage.world):
			if combat.is_occupied(hero.arena_id, hero.cell):
				hero.arena_id = previous_arena
				hero.cell = previous_cell
				hero.facing = previous_facing
				sound.movement(previous_arena, previous_cell, true)
			else:
				if hero.arena_id != previous_arena:
					select_arena(stage.world.index_for_id(hero.arena_id))
				sound.movement(hero.arena_id, hero.cell)
			stage.sync_hero(true)
		else:
			sound.movement(previous_arena, previous_cell, true)
	if _cast_queued:
		_cast_queued = false
		if _hero_in_focused_arena() and hero.selected:
			_cast_notice = combat.try_cast(hero)
			_notice_seconds = 2.0 if not _cast_notice.is_empty() else 0.0
	_release_channel_if_needed()
	if not sequence_active:
		combat.tick(delta, hero)
	combat_presentation.sync_active(combat.is_channeling(), combat.active_remaining() if hero.definition.class_id == "merchant" else 0.0)
	_notice_seconds = maxf(0.0, _notice_seconds - delta)
	_combat_hud_elapsed += delta
	if _combat_hud_elapsed >= 0.1:
		_combat_hud_elapsed = 0.0
		_update_combat_hud()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_hero_input.clear()
		_cancel_cast_input()

func _mount_combat() -> void:
	var run_combat: ArenicCombatState = RunSetup.get_combat()
	if combat != run_combat:
		if combat != null:
			combat.progress_changed.disconnect(_on_progress_changed)
			combat.ability_cast.disconnect(_on_ability_cast)
			combat.damage_applied.disconnect(_on_damage_applied)
		combat = run_combat
		combat.progress_changed.connect(_on_progress_changed)
		combat.ability_cast.connect(_on_ability_cast)
		combat.damage_applied.connect(_on_damage_applied)
	combat.configure(stage.world)
	for arena: ArenicArenaDefinition in stage.world.arenas:
		if arena.boss != null or arena.training_target_frames != null:
			combat.register_enemy(arena.arena_id, "boss:" + arena.arena_id, Rect2i(arena.boss_origin_cell, arena.boss_combat_size), arena.boss_facing)
		stage.get_arena(stage.world.index_for_id(arena.arena_id)).set_damage_phase(combat.completed_phases(arena.arena_id))
	combat_presentation = ArenicCombatPresentation.new()
	combat_presentation.name = "CombatPresentation"
	stage.add_child(combat_presentation)
	combat_presentation.configure(stage)
	combat_presentation.restore_active(combat.active_cast_snapshot())

func _on_progress_changed(arena_id: String) -> void:
	if not is_instance_valid(stage):
		return
	var index: int = stage.world.index_for_id(arena_id)
	if index < 0:
		return
	stage.get_arena(index).set_damage_phase(combat.completed_phases(arena_id))
	if index == selected_index:
		hud.set_damage_progress(combat.damage_for_arena(arena_id), combat.phase_size(arena_id))

func _on_ability_cast(ability_id: String, arena_id: String, origin: Vector2i, target_cell: Vector2i, facing: String) -> void:
	stage.sync_hero(_hero_in_focused_arena())
	combat_presentation.show_cast(ability_id, arena_id, origin, target_cell, facing, hero.definition.skills[0])

func _on_damage_applied(arena_id: String, enemy_id: String, amount: int) -> void:
	var footprint: Rect2i = combat.enemy_footprint(arena_id, enemy_id)
	var center: Vector2 = Vector2(footprint.position) + Vector2(footprint.size - Vector2i.ONE) * 0.5
	combat_presentation.show_hit(arena_id, center, amount)

func _queue_cast() -> void:
	if _hero_in_focused_arena() and hero.selected:
		_cast_queued = true # One input per physics tick, no key-repeat queue.
	else:
		_cast_notice = "Tab to focus and select your hero."
		_notice_seconds = 2.0
		_update_combat_hud()

func _on_ability_requested() -> void:
	_button_held = true
	_queue_cast()

func _on_ability_released() -> void:
	_button_held = false
	_release_channel_if_needed()

func _release_channel_if_needed() -> void:
	if not _space_held and not _button_held and combat != null:
		combat.cancel_channel()

func _cancel_cast_input() -> void:
	_cast_queued = false
	_space_held = false
	_button_held = false
	if combat != null:
		combat.cancel_channel()
	if is_instance_valid(combat_presentation):
		combat_presentation.cancel_channel()

func _update_combat_hud() -> void:
	if combat == null or hero == null or not is_instance_valid(stage):
		return
	var arena: ArenicArenaDefinition = stage.world.arenas[selected_index]
	hud.set_damage_progress(combat.damage_for_arena(arena.arena_id), combat.phase_size(arena.arena_id))
	if hero.definition.skills.is_empty():
		return
	var ability: ArenicClassAbility = hero.definition.skills[0]
	var hint: String = "SPACE  Cast · nearest enemy"
	if ability.effect_kind == "channel":
		hint = "Hold SPACE or button · release to stop"
	elif ability.requires_backstab:
		hint = "SPACE  Cast · adjacent, behind target"
	elif ability.effect_kind == "cleanse":
		hint = "SPACE  Cast · 4 × 4 cleanse + damage"
	elif ability.effect_kind == "aura":
		hint = "SPACE  Cast · 2-tile aura, 20 seconds"
	else:
		hint = "SPACE  Cast · range %d tile%s" % [ability.range_tiles, "" if ability.range_tiles == 1 else "s"]
	if not _hero_in_focused_arena() or not hero.selected:
		hint = "TAB  Focus and select your hero"
	var here: bool = _hero_in_focused_arena() and hero.selected
	var unavailable: String = combat.cast_unavailable_reason(hero)
	if here and combat.cooldown_remaining() <= 0.0 and combat.active_remaining() <= 0.0 and not unavailable.is_empty():
		hint = unavailable
	if _notice_seconds > 0.0:
		hint = _cast_notice
	var enabled: bool = here and (combat.is_channeling() or unavailable.is_empty())
	hud.set_ability_context(ability.title, hint, combat.cooldown_remaining(), combat.active_remaining(), enabled)
