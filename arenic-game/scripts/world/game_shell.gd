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
## The guild, and the member the player currently controls. `hero` is always a
## member of `heroes`; nothing downstream may assume it is the only one.
var heroes: Array[ArenicHeroState] = []
var hero: ArenicHeroState
var _hero_input := ArenicHeroInput.new()
var music: ArenicArenaMusicDirector
var combat: ArenicCombatState
var encounter: ArenicEncounterState
var combat_presentation: ArenicCombatPresentation
const ENCOUNTERS: ArenicEncounterCatalog = preload("res://data/encounters/catalog.tres")
## Where a defeated hero returns. The Guild House has no authored battle score,
## so a respawn is never immediately struck again.
const RESPAWN_ARENA: String = "guild_house"
const RESPAWN_CELL: Vector2i = Vector2i(30, 15)
const RESPAWN_FACING: String = "n"
## Floor markers refresh at 10 Hz; the simulation still runs at 60.
const MARKER_INTERVAL_TICKS: int = 6
var sound: ArenicGameplayAudio
const MOVEMENT_SOUNDS: ArenicMovementSoundProfile = preload("res://data/audio/movement.tres")
var _cast_queued: bool = false
var _space_held: bool = false
var _slot_held: bool = false
var _button_held: bool = false
var _combat_hud_elapsed: float = 0.0
var _cast_notice: String = ""
var _notice_seconds: float = 0.0
@onready var hud: ArenicWorldHUD = $HUD/HUDOutline
## One decision at a time, above the HUD. It pauses exactly one arena; the
## handler below then resumes, restarts or re-arms that arena deliberately.
var modal: ArenicModal
## The one in-flight recording, if any.
var session := ArenicRecordingSession.new()
## Damage earns guild rolls; a roll recruits. Owned by the run so it survives a
## stage swap along with the guild it grows.
var recruitment: ArenicRecruitmentState
var _marker_countdown: int = 1

func _ready() -> void:
	ArenicDisplayPolicy.apply_game_layout(get_window())
	music = ArenicArenaMusicDirector.new()
	music.name = "ArenaMusic"
	add_child(music)
	sound = ArenicGameplayAudio.new()
	sound.name = "GameplayAudio"
	add_child(sound)
	modal = ArenicModal.new()
	modal.name = "Modal"
	modal.chosen.connect(_on_modal_choice)
	$HUD.add_child(modal)
	hud.world_rect_changed.connect(_update_view_rect)
	hud.toggle_requested.connect(toggle_view)
	hud.ability_requested.connect(_on_ability_requested)
	hud.ability_released.connect(_on_ability_released)
	hud.arena_requested.connect(paginate_arena)
	# The guild grows mid-run, so a recruit is mounted where it arrives rather
	# than waiting for a stage swap to notice it.
	RunSetup.hero_recruited.connect(_on_hero_recruited)
	hud.record_requested.connect(_handle_record_key)
	hud.set_health_source(func(member: ArenicHeroState) -> Dictionary:
		return combat.ally_status(member.arena_id, member.ally_id()) if combat != null else {})
	hud.set_ghost_source(_is_ghost)
	hud.hero_requested.connect(_on_hud_hero_requested)
	replace_stage(stage_scene)
	if not SaveGames.attach_shell(self):
		set_physics_process(false)
		return
	hud.save_title_requested.connect(_save_and_title)
	SaveGames.status_changed.connect(hud.set_save_status)
	hud.set_save_status("Saved" if SaveGames.active_slot >= 0 else "Preview")
	if entry_sequence != null and SaveGames.active_slot < 0:
		play_sequence(entry_sequence)


func _save_and_title() -> void:
	await SaveGames.return_to_title()

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
	heroes = RunSetup.get_heroes()
	recruitment = RunSetup.get_recruitment()
	hero = run_hero
	stage.mount_heroes(heroes)
	stage.sync_heroes(hero.identity_id, false)
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

## Deliberate navigation: focus an arena AND take control of whoever it hands
## you. Every other caller of select_arena is following a hero that already
## moved, so only this path adopts a default.
func paginate_arena(index: int) -> void:
	if sequence_active or not is_instance_valid(stage) or index == selected_index:
		select_arena(index)
		return
	select_arena(index)
	_adopt_arena_default()


## Hands control to the member this arena remembers, or to the first one standing
## there if it remembers nobody. An arena with no members changes nothing: there
## is no one to hand control to, so you keep the hero you had.
func _adopt_arena_default() -> void:
	if not is_instance_valid(stage) or session.is_recording() or session.is_counting_down():
		return
	var arena_id: String = stage.world.arenas[selected_index].arena_id
	var present: Array[ArenicHeroState] = RunSetup.heroes_in(arena_id)
	if present.is_empty():
		return
	var remembered: int = RunSetup.selection_for(arena_id)
	for member: ArenicHeroState in present:
		if member.identity_id == remembered:
			_select_identity(remembered)
			return
	# Never visited, or the remembered member has since walked out: the first
	# one standing here takes over, and becomes what this arena remembers.
	_select_identity(present[0].identity_id)


## Keeps an arena's memory in step with where a member actually stands. A member
## that walks out takes its arena's default with it, so that arena will offer
## whoever is still there rather than someone who has gone.
func _relocate_selection(member: ArenicHeroState, from_arena: String) -> void:
	if member == null or from_arena == member.arena_id:
		return
	RunSetup.forget_selection(from_arena, member.identity_id)
	if member == hero:
		RunSetup.remember_selection(member.arena_id, member.identity_id)


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
	hud.set_context(stage.world.arenas[selected_index], hero.display_name(), definition.display_name, zoomed)
	hud.set_hero_control(_hero_in_focused_arena(), hero.selected)
	stage.sync_heroes(hero.identity_id, _hero_in_focused_arena())
	_update_combat_hud()

func _input(event: InputEvent) -> void:
	if is_instance_valid(modal) and modal.is_open():
		return
	# Release is observed even when a Control consumes the matching mouse/key event.
	if event is InputEventKey and not event.pressed and (event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE):
		_space_held = false
		_release_channel_if_needed()
	elif event is InputEventKey and not event.pressed and (event.keycode == KEY_1 or event.physical_keycode == KEY_1):
		_slot_held = false
		_release_channel_if_needed()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_button_held = false
		_release_channel_if_needed()

func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(modal) and modal.is_open():
		return
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
		elif (event.keycode == KEY_1 or event.physical_keycode == KEY_1) and not event.ctrl_pressed and not event.meta_pressed and not event.alt_pressed:
			_slot_held = true
			_queue_cast()
		elif event.keycode in [KEY_2, KEY_3, KEY_4] and not event.ctrl_pressed and not event.meta_pressed and not event.alt_pressed:
			pass # The four positions are fixed; unassigned slots never cast a different ability.
		elif event.keycode == KEY_H and not event.ctrl_pressed and not event.meta_pressed and not event.alt_pressed:
			hud.toggle_help()
		elif event.keycode == KEY_N and not event.ctrl_pressed and not event.meta_pressed and not event.alt_pressed:
			_open_roll()
		elif event.keycode == KEY_R and not event.ctrl_pressed and not event.meta_pressed and not event.alt_pressed:
			_handle_record_key()
		elif session.is_counting_down():
			pass # Nothing registers until capture begins; only R aborts.
		elif event.keycode == KEY_TAB and not event.ctrl_pressed and not event.meta_pressed and not event.alt_pressed:
			# A take always belongs to the hero that started it.
			if not session.is_recording():
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
			paginate_arena(posmod(selected_index - 1, stage.world.arenas.size()))
		elif event.is_action_pressed("world_next"):
			paginate_arena(posmod(selected_index + 1, stage.world.arenas.size()))
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
						paginate_arena(index)
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
				var picked: int = stage.hero_at_screen(event.position)
				if picked >= 0:
					_select_identity(picked)
				else:
					hero.selected = false
					_cancel_cast_input()
				_update_hud()
			else:
				paginate_arena(index)
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
		paginate_arena(index)

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
	stage.sync_heroes(hero.identity_id, false)
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

## Tab. Focuses and selects the controlled hero; with more than one guild member
## standing in the focused arena it advances to the next of them instead, so Tab
## is "find my hero" when away and "switch hero" when already there.
func select_hero() -> void:
	if sequence_active or hero == null:
		return
	var present: Array[ArenicHeroState] = RunSetup.heroes_in(stage.world.arenas[selected_index].arena_id)
	if _hero_in_focused_arena() and hero.selected and present.size() > 1:
		var at: int = present.find(hero)
		_select_identity(present[(at + 1) % present.size()].identity_id)
		_update_hud()
		return
	hero.selected = true
	_select_identity(hero.identity_id)
	select_arena(stage.world.index_for_id(hero.arena_id))
	set_zoomed(true)


## The one place control moves between guild members. Input state belongs to the
## hero that owned it, so it is cleared rather than inherited.
func _select_identity(identity_id: int) -> void:
	if not RunSetup.select(identity_id):
		return
	_hero_input.clear()
	_cancel_cast_input()
	hero = RunSetup.get_hero()
	hero.selected = true
	if is_instance_valid(stage):
		stage.sync_heroes(hero.identity_id, _hero_in_focused_arena())

func _physics_process(delta: float) -> void:
	if not is_instance_valid(stage) or hero == null or combat == null:
		return
	# The countdown holds its arena at tick zero and swallows every input.
	if session.is_counting_down():
		if session.advance_countdown():
			encounter.set_paused(session.arena_id, false)
		_hero_input.clear()
		_update_hud()
		return
	var direction := _hero_input.consume()
	# Arrows never drive a ghost. Ask before taking it out of the score, because
	# breaking out is a decision about the whole arena, not just this hero.
	if direction != Vector2i.ZERO and encounter.is_ghost(hero):
		_open_modal(hero.arena_id, "Break out of the recording?",
			"Take control unfolds this hero. The arena keeps playing.",
			[["Take control", ArenicModal.TAKE_CONTROL], ["Restart arena", ArenicModal.RESTART_ARENA], ["Cancel", ArenicModal.CANCEL]], 2)
		direction = Vector2i.ZERO
	if direction != Vector2i.ZERO and _hero_in_focused_arena() and hero.selected:
		combat.cancel_channel(hero)
		var previous_arena: String = hero.arena_id
		var previous_cell: Vector2i = hero.cell
		var previous_facing: String = hero.facing
		# A take belongs to one arena. Stepping into a real neighbour mid-take is
		# a decision, not a silent loss; at the world border it simply clamps.
		if session.owns(hero) and not hero.crossing_arena(direction, stage.world).is_empty():
			_open_modal(session.arena_id, "Like the recording?",
				"Moving out of the arena cancels it.",
				[["Continue recording", ArenicModal.CANCEL], ["Cancel & walk out", ArenicModal.DISCARD_AND_WALK], ["Commit & stay", ArenicModal.COMMIT]], 0,
				{"step": direction})
			return
		var stepped: bool = hero.step_within_arena(direction) if session.owns(hero) else hero.step(direction, stage.world)
		if stepped:
			if combat.is_occupied(hero.arena_id, hero.cell):
				hero.arena_id = previous_arena
				hero.cell = previous_cell
				hero.facing = previous_facing
				sound.movement(previous_arena, previous_cell, true)
			else:
				if hero.arena_id != previous_arena:
					_relocate_selection(hero, previous_arena)
					select_arena(stage.world.index_for_id(hero.arena_id))
					_offer_stored_staff()
				sound.movement(hero.arena_id, hero.cell)
				_capture(ArenicTimelineEvent.move(encounter.cycle_position(previous_arena), direction))
			stage.sync_heroes(hero.identity_id, true)
		else:
			sound.movement(previous_arena, previous_cell, true)
	if _cast_queued:
		_cast_queued = false
		if _hero_in_focused_arena() and hero.selected:
			_cast_notice = combat.try_cast(hero)
			_notice_seconds = 2.0 if not _cast_notice.is_empty() else 0.0
			if _cast_notice.is_empty():
				_capture(ArenicTimelineEvent.ability(encounter.cycle_position(hero.arena_id), 1))
	_release_channel_if_needed()
	if not sequence_active:
		combat.sync_allies(heroes)
		combat.tick(delta, hero)
		# After combat, so ally cells are already synced when a landing resolves.
		# One physics step is exactly one simulation tick; the encounter never
		# reads delta, so a slow frame drops a tick rather than skewing one.
		if encounter != null:
			encounter.tick(combat)
			_check_recording_full()
	_sync_boss_placement()
	_sync_dig_markers()
	# Guild members move without player input — a recruit arriving, a member
	# relocating, and shortly a ghost replaying its staff. Views follow the
	# ledger every tick rather than only when a key is pressed.
	if hero != null:
		stage.sync_heroes(hero.identity_id, _hero_in_focused_arena(), _is_ghost)
	combat_presentation.sync_active(combat.is_channeling(hero), combat.active_remaining(hero) if hero.definition.class_id == "merchant" else 0.0)
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
			combat.ability_landed.disconnect(_on_ability_landed)
			combat.damage_applied.disconnect(_on_damage_applied)
			combat.ally_defeated.disconnect(_on_ally_defeated)
		combat = run_combat
		combat.progress_changed.connect(_on_progress_changed)
		combat.ability_cast.connect(_on_ability_cast)
		combat.ability_landed.connect(_on_ability_landed)
		combat.damage_applied.connect(_on_damage_applied)
		combat.ally_defeated.connect(_on_ally_defeated)
	combat.configure(stage.world)
	for arena: ArenicArenaDefinition in stage.world.arenas:
		if arena.boss != null or arena.training_target_frames != null:
			combat.register_enemy(arena.arena_id, ArenicCombatState.boss_enemy_id(arena.arena_id), Rect2i(arena.boss_origin_cell, arena.boss_combat_size), arena.boss_facing)
		stage.get_arena(stage.world.index_for_id(arena.arena_id)).set_damage_phase(combat.completed_phases(arena.arena_id))
	# The conductor places every scored boss on its cycle-zero beat, overriding
	# the arena's authored resting footprint without resolving that beat.
	if encounter == null:
		encounter = ArenicEncounterState.new()
		encounter.beat_resolved.connect(_on_beat_resolved)
		encounter.tile_dug.connect(_on_tile_dug)
	encounter.performer_lookup = func(performer: String) -> ArenicHeroState:
		for member: ArenicHeroState in heroes:
			if member.ally_id() == performer:
				return member
		return null
	encounter.configure(stage.world, ENCOUNTERS, combat)
	_sync_boss_placement()
	combat_presentation = ArenicCombatPresentation.new()
	combat_presentation.name = "CombatPresentation"
	stage.add_child(combat_presentation)
	combat_presentation.configure(stage)
	combat_presentation.restore_active(combat.active_cast_snapshot(hero))

func _on_progress_changed(arena_id: String) -> void:
	if not is_instance_valid(stage):
		return
	var index: int = stage.world.index_for_id(arena_id)
	if index < 0:
		return
	stage.get_arena(index).set_damage_phase(combat.completed_phases(arena_id))
	if index == selected_index:
		hud.set_damage_progress(combat.damage_for_arena(arena_id), combat.phase_size(arena_id))

func _on_ability_cast(caster_id: String, ability_id: String, arena_id: String, origin: Vector2i, target_cell: Vector2i, facing: String) -> void:
	stage.sync_heroes(hero.identity_id, _hero_in_focused_arena())
	var caster: ArenicHeroState = _hero_for_ally(caster_id)
	if caster == null:
		return
	combat_presentation.show_cast(caster.identity_id, ability_id, arena_id, origin, target_cell, facing, caster.definition.skills[0])


## Relayed to the conductor, which owns arena ground. The shell is a Node and is
## disconnected when it is freed; the conductor is not, and subscribing it
## directly to the run-long ledger would keep every past one alive.
func _on_ability_landed(_caster_id: String, ability_id: String, arena_id: String, area: Rect2i, rules: ArenicClassAbility) -> void:
	if encounter != null:
		encounter.apply_landing(ability_id, arena_id, area, rules)


func _hero_for_ally(caster_id: String) -> ArenicHeroState:
	for member: ArenicHeroState in heroes:
		if member.ally_id() == caster_id:
			return member
	return null

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
	if not _space_held and not _slot_held and not _button_held and combat != null:
		combat.cancel_channel(hero)

func _cancel_cast_input() -> void:
	_cast_queued = false
	_space_held = false
	_slot_held = false
	_button_held = false
	if combat != null:
		combat.cancel_channel(hero)
	if is_instance_valid(combat_presentation):
		combat_presentation.cancel_channel()

func _update_combat_hud() -> void:
	if combat == null or hero == null or not is_instance_valid(stage):
		return
	var arena: ArenicArenaDefinition = stage.world.arenas[selected_index]
	hud.set_damage_progress(combat.damage_for_arena(arena.arena_id), combat.phase_size(arena.arena_id))
	var health: Dictionary = combat.ally_status(hero.arena_id, hero.ally_id())
	hud.set_run_context(stage.world, hero, selected_index, health, _hero_effects(health), heroes)
	if hero.definition.skills.is_empty():
		return
	var ability: ArenicClassAbility = hero.definition.skills[0]
	var hint: String = "1 / SPACE  Cast · nearest enemy"
	if ability.effect_kind == "channel":
		hint = "Hold 1 / SPACE or button · release to stop"
	elif ability.requires_backstab:
		hint = "1 / SPACE  Cast · adjacent, behind target"
	elif ability.effect_kind == "cleanse":
		hint = "1 / SPACE  Cast · 4 × 4 cleanse + damage"
	elif ability.effect_kind == "aura":
		hint = "1 / SPACE  Cast · 2-tile aura, 20 seconds"
	else:
		hint = "1 / SPACE  Cast · range %d tile%s" % [ability.range_tiles, "" if ability.range_tiles == 1 else "s"]
	if not _hero_in_focused_arena() or not hero.selected:
		hint = "TAB  Focus and select your hero"
	var here: bool = _hero_in_focused_arena() and hero.selected
	var unavailable: String = combat.cast_unavailable_reason(hero)
	if here and combat.cooldown_remaining(hero) <= 0.0 and combat.active_remaining(hero) <= 0.0 and not unavailable.is_empty():
		hint = unavailable
	if _notice_seconds > 0.0:
		hint = _cast_notice
	var enabled: bool = here and (combat.is_channeling(hero) or unavailable.is_empty())
	hud.set_ability_context(ability.title, hint, combat.cooldown_remaining(hero), combat.active_remaining(hero), enabled)
	_update_recording_hud()
	_update_recruitment_hud()
	_update_activity_hud()


## What the guild is actually running, arena by arena.
func _update_activity_hud() -> void:
	if encounter == null or not is_instance_valid(stage):
		return
	var counts := PackedInt32Array()
	for arena: ArenicArenaDefinition in stage.world.arenas:
		counts.append(encounter.ghost_count(arena.arena_id))
	hud.set_arena_activity(counts)


func _update_recruitment_hud() -> void:
	if recruitment == null or combat == null:
		return
	hud.set_recruitment(recruitment.progress(_total_earnings()))


func _update_recording_hud() -> void:
	if session.is_counting_down():
		hud.set_recording_state("%d" % session.countdown_seconds(), "Recording begins at zero. R aborts.", true)
	elif session.is_recording():
		hud.set_recording_state("REC  %s" % encounter.cycle_label(session.arena_id), "R to commit, keep recording, or discard.", true)
	elif hero != null and encounter.is_ghost(hero):
		hud.set_recording_state("Ghost\nR", "This hero is playing its staff. R to record over it.", false)
	else:
		hud.set_recording_state("Record\nR", "R records a two-minute staff for this hero in this arena.", false)


## Draws every scored boss where its cycle currently places it. Presentation
## runs for all nine arenas, not only the focused one, so a sequence stays
## continuous when the camera arrives.
func _sync_boss_placement() -> void:
	if encounter == null or not is_instance_valid(stage):
		return
	for arena_id: String in encounter.arena_ids():
		var index: int = stage.world.index_for_id(arena_id)
		var view: ArenicArenaView = stage.get_arena(index)
		if view != null:
			view.set_boss_placement(encounter.boss_placement(arena_id))


## Broken ground pays the guild, not the arena: it is income toward the next
## hero rather than damage on the boss.
func _on_tile_dug(arena_id: String, cell: Vector2i, value: int) -> void:
	RunSetup.prospected += value
	if not is_instance_valid(stage):
		return
	var view: ArenicArenaView = stage.get_arena(stage.world.index_for_id(arena_id))
	if view != null:
		view.show_dig(cell, value)


## Damage dealt plus ground broken: the run's whole income toward the next roll.
func _total_earnings() -> int:
	return (combat.total_damage() if combat != null else 0) + RunSetup.prospected


func _on_beat_resolved(arena_id: String, action_id: String, center: Vector2, radius_tiles: float) -> void:
	if action_id != "boss_jump" or radius_tiles <= 0.0 or not is_instance_valid(stage):
		return
	var view: ArenicArenaView = stage.get_arena(stage.world.index_for_id(arena_id))
	if view != null:
		view.show_blast(center, radius_tiles)


## A struck hero returns to the Guild House. Level, experience, arena damage and
## phase progress all survive; only position and health are restored.
func _on_ally_defeated(arena_id: String, actor_id: String) -> void:
	var struck: ArenicHeroState = _hero_for_ally(actor_id)
	if struck == null or struck.arena_id != arena_id:
		return
	# A GHOST dies in place. Walking it home would resume its recorded intent in
	# the wrong arena and destroy replay; instead it lies where it fell and rises
	# with the next cycle. Because the pattern is fixed and its intent is fixed,
	# it will die at the same tick every cycle until the staff is re-recorded —
	# which is exactly the feedback that teaches a better path.
	if encounter.is_ghost(struck):
		return
	var fell_in: String = struck.arena_id
	struck.arena_id = RESPAWN_ARENA
	struck.cell = RESPAWN_CELL
	struck.facing = RESPAWN_FACING
	combat.respawn_hero_ally(struck)
	_relocate_selection(struck, fell_in)
	if struck != hero:
		return # A free guild member walks home quietly; only yours interrupts.
	_hero_input.clear()
	_cancel_cast_input()
	if session.owns(hero):
		# A take cannot survive its own hero being killed out of the arena.
		session.clear()
		_cast_notice = "You died mid-recording. The take was discarded."
	else:
		_cast_notice = "You were caught in the blast. Respawned at the Guild House."
	_notice_seconds = 3.0
	if not is_instance_valid(stage):
		return
	select_arena(stage.world.index_for_id(hero.arena_id))
	stage.sync_heroes(hero.identity_id, _hero_in_focused_arena())
	_update_hud()


## Broken ground is drawn for the focused arena only: the markers exist to stop
## you digging the same tile twice and to show a boss standing in a trap, and
## neither reads at overview scale.
##
## Rebuilding the cell lists means sorting arrays and testing every dug tile
## against every target. That is presentation, not simulation, so it runs at a
## tenth of the tick rate rather than competing with the model for frame time.
func _sync_dig_markers() -> void:
	if encounter == null or not is_instance_valid(stage):
		return
	_marker_countdown -= 1
	if _marker_countdown > 0:
		return
	_marker_countdown = MARKER_INTERVAL_TICKS
	var arena_id: String = stage.world.arenas[selected_index].arena_id
	var view: ArenicArenaView = stage.get_arena(selected_index)
	var field: ArenicDigField = encounter.dig_field(arena_id)
	if view == null or field == null:
		return
	view.set_dig_ground(field.dug_cells(), field.overlapped_cells(combat))
	var acid: ArenicAcidField = encounter.acid_field(arena_id)
	if acid != null:
		var pools: Dictionary = acid.overlay()
		view.set_acid_pools(pools["cells"], pools["strengths"])


func _is_ghost(member: ArenicHeroState) -> bool:
	return encounter != null and encounter.is_ghost(member)


## Capture is written where the live effect happened, so the committed staff and
## the take that produced it can never disagree.
func _capture(event: ArenicTimelineEvent) -> void:
	if session.owns(hero):
		session.capture(event)


## The two-minute staff is full. Pause the arena before it wraps and ask, rather
## than silently recording over the take from the top.
func _check_recording_full() -> void:
	if not session.is_recording() or modal.is_open():
		return
	if encounter.cycle_position(session.arena_id) < encounter.cycle_ticks(session.arena_id) - 1:
		return
	_open_modal(session.arena_id, "Time's up — like the recording?",
		"The two-minute cycle is full.",
		[["Commit", ArenicModal.COMMIT], ["Discard", ArenicModal.DISCARD]], 0)


## An arena holds at most forty ghosts. Refused before the countdown rather than
## after a full take, so nobody spends two minutes recording into a closed arena.
func _arena_has_room() -> bool:
	if encounter.can_fold_ghost(hero):
		return true
	_cast_notice = "%s already holds %d ghosts." % [stage.world.arenas[stage.world.index_for_id(hero.arena_id)].display_name, ArenicEncounterState.MAX_GHOSTS_PER_ARENA]
	_notice_seconds = 3.0
	_update_hud()
	return false


## Walking into an arena this hero has already recorded for: fold the old staff
## back in, or stay free and decide later with R.
func _offer_stored_staff() -> void:
	if hero == null or not hero.recordings.has(hero.arena_id) or encounter.is_ghost(hero):
		return
	_open_modal(hero.arena_id, "You have a staff here",
		"Replaying folds it back in and restarts the arena.",
		[["Replay previous", ArenicModal.REPLAY_PREVIOUS], ["Continue without", ArenicModal.CANCEL]], 1)


## N — claims a banked guild roll. Rolls are earned by damage and never expire,
## so this is always the player's move to make rather than an interruption.
func _open_roll() -> void:
	if hero == null or recruitment == null or combat == null or session.is_recording():
		return
	if recruitment.rolls_available(_total_earnings()) <= 0:
		var next_at: int = recruitment.next_threshold(_total_earnings())
		_cast_notice = "No roll ready. Next at %d damage." % next_at if next_at > 0 else "The guild is full."
		_notice_seconds = 2.5
		_update_hud()
		return
	if heroes.size() >= RunSetup.MAX_GUILD:
		_cast_notice = "The guild is full."
		_notice_seconds = 2.5
		_update_hud()
		return
	var offers: Array[ArenicClassDefinition] = recruitment.offers(recruitment.rolls_claimed, RunSetup.class_catalog())
	if offers.is_empty():
		return
	var options: Array = []
	for definition: ArenicClassDefinition in offers:
		options.append([definition.display_name, ArenicModal.RECRUIT_PREFIX + definition.class_id])
	options.append(["Later", ArenicModal.CANCEL])
	_open_modal(hero.arena_id, "A hero answers the call",
		"They deploy to the Guild House, unrecorded. Declining keeps the roll.",
		options, 0)


## Spends the roll and deploys the recruit. Declining a roll never spends it.
func _claim_roll(class_id: String) -> void:
	var catalog: ArenicClassCatalog = RunSetup.class_catalog()
	for definition: ArenicClassDefinition in catalog.classes:
		if definition.class_id != class_id:
			continue
		var recruit: ArenicHeroState = RunSetup.recruit(definition)
		if recruit != null:
			recruitment.claim()
			_cast_notice = "%s joined the guild at the Guild House." % recruit.display_name()
			_notice_seconds = 3.0
		return


## R — the context-sensitive record key. There is no modal where there is no
## real choice: a hero with no staff here goes straight to the countdown.
func _handle_record_key() -> void:
	if hero == null or not is_instance_valid(stage):
		return
	if session.is_counting_down():
		# Nothing has been captured yet, so aborting costs nothing.
		session.clear()
		_resume_arena(hero.arena_id)
		_update_hud()
		return
	if session.is_recording():
		_open_modal(session.arena_id, "Like the recording?",
			"Commit folds this draft into the arena's timeline.",
			[["Commit", ArenicModal.COMMIT], ["Keep recording", ArenicModal.CANCEL], ["Discard", ArenicModal.DISCARD]], 1)
		return
	if not _hero_in_focused_arena() or not hero.selected:
		_cast_notice = "Tab to focus and select a hero first."
		_notice_seconds = 2.0
		_update_hud()
		return
	if encounter.is_ghost(hero):
		_open_modal(hero.arena_id, "Record over this ghost?",
			"Record new unfolds it and starts the countdown.",
			[["Record new", ArenicModal.START_RECORDING], ["Cancel", ArenicModal.CANCEL]], 1)
		return
	if not _arena_has_room():
		return
	if hero.recordings.has(hero.arena_id):
		_open_modal(hero.arena_id, "This hero has a staff here",
			"Record new replaces it. Replay folds the old one back in.",
			[["Record new", ArenicModal.START_RECORDING], ["Replay previous", ArenicModal.REPLAY_PREVIOUS], ["Cancel", ArenicModal.CANCEL]], 2)
		return
	_arm_countdown()


## Holds the recording arena at tick zero and returns its ghosts to their starts,
## so a take always begins from the same frame of the cycle.
func _arm_countdown() -> void:
	encounter.restart(hero.arena_id)
	encounter.set_paused(hero.arena_id, true)
	encounter.snap_ghosts(hero.arena_id, hero.identity_id)
	session.arm(hero)
	_hero_input.clear()
	_cancel_cast_input()
	_update_hud()


## Folds the draft in, caches it, and restarts the arena. Commit and replay share
## this tail so the two paths cannot drift.
func _commit_recording() -> void:
	var owner: ArenicHeroState = RunSetup.hero_for(session.identity)
	if owner == null:
		session.clear()
		return
	var arena_id: String = session.arena_id
	var recording: ArenicRecording = session.take()
	owner.recordings[arena_id] = recording
	# The take is always cached, even if the arena filled up mid-recording: the
	# work is not thrown away, it simply waits for room.
	if encounter.can_fold_ghost(owner):
		encounter.fold_ghost(owner, recording)
	else:
		_cast_notice = "The arena filled up. Your staff is saved; press R to fold it in later."
		_notice_seconds = 4.0
	_update_hud()


## Opens one decision, pausing only the arena it belongs to. Returns false when
## a modal is already up, so a caller that stashes state alongside one only does
## so if it really opened.
func _open_modal(owner_arena: String, title: String, detail: String, options: Array, default_index: int = 0, context: Dictionary = {}) -> bool:
	if not is_instance_valid(modal) or not is_instance_valid(stage):
		return false
	var index: int = stage.world.index_for_id(owner_arena)
	if index < 0:
		return false
	if not modal.open(owner_arena, stage.world.arenas[index].visual_theme, title, detail, options, default_index, context):
		return false
	# Only this arena stops. The other eight keep performing, which is what makes
	# watching another arena mid-decision safe.
	if encounter != null:
		encounter.set_paused(owner_arena, true)
	_hero_input.clear()
	return true


## Every branch decides for itself how its arena resumes, so a decision can
## never leave one silently stopped.
func _on_modal_choice(choice: String, context: Dictionary) -> void:
	var owner_arena: String = modal.arena_id
	if choice.begins_with(ArenicModal.RECRUIT_PREFIX):
		_claim_roll(choice.substr(ArenicModal.RECRUIT_PREFIX.length()))
		_resume_arena(owner_arena)
		_update_hud()
		return
	match choice:
		ArenicModal.CANCEL:
			_resume_arena(owner_arena)
		ArenicModal.DISCARD:
			# The draft is thrown away; the hero stays selected where it stands.
			session.clear()
			_resume_arena(owner_arena)
		ArenicModal.DISCARD_AND_WALK:
			# Throw the take away, THEN perform the step that interrupted it.
			session.clear()
			_resume_arena(owner_arena)
			var step: Vector2i = context.get("step", Vector2i.ZERO)
			var left: String = hero.arena_id
			if step != Vector2i.ZERO and hero.step(step, stage.world) and hero.arena_id != left:
				_relocate_selection(hero, left)
				select_arena(stage.world.index_for_id(hero.arena_id))
				_offer_stored_staff()
		ArenicModal.TAKE_CONTROL:
			# The events leave the score and the arena keeps playing right where
			# it left off. This is the one path that does not rewind.
			encounter.unfold_ghost(hero)
			_resume_arena(owner_arena)
		ArenicModal.RESTART_ARENA:
			# "I made a mistake": rewind everything; the hero stays folded.
			encounter.restart(owner_arena)
		ArenicModal.COMMIT:
			_commit_recording()
		ArenicModal.START_RECORDING:
			if encounter.is_ghost(hero):
				encounter.unfold_ghost(hero)
			_arm_countdown()
		ArenicModal.REPLAY_PREVIOUS:
			var staff: ArenicRecording = hero.recordings.get(owner_arena)
			if staff != null and _arena_has_room():
				encounter.fold_ghost(hero, staff)
			else:
				_resume_arena(owner_arena)
		_:
			_resume_arena(owner_arena)
	_update_hud()


func _resume_arena(owner_arena: String) -> void:
	if encounter != null:
		encounter.set_paused(owner_arena, false)


func _on_hero_recruited(recruit: ArenicHeroState) -> void:
	if not is_instance_valid(stage) or recruit == null:
		return
	heroes = RunSetup.get_heroes()
	stage.mount_heroes(heroes)
	stage.sync_heroes(hero.identity_id if hero != null else -1, _hero_in_focused_arena())
	_update_hud()


func _on_hud_hero_requested(identity: int) -> void:
	if hero != null and identity == hero.identity_id:
		select_hero()
		return
	if RunSetup.hero_for(identity) != null:
		_select_identity(identity)
		select_arena(stage.world.index_for_id(hero.arena_id))
		set_zoomed(true)


func _hero_effects(health: Dictionary) -> Array[Dictionary]:
	var effects: Array[Dictionary] = []
	for debuff: String in health.get("debuffs", PackedStringArray()):
		# The current combat ledger has untimed debuffs; do not invent an expiry.
		effects.append({"name": debuff, "beneficial": false, "remaining_seconds": -1.0, "stacks": 1})
	var active: Dictionary = combat.active_cast_snapshot(hero)
	if active.get("effect_kind", "") == "aura" and not hero.definition.skills.is_empty():
		effects.append({"name": hero.definition.skills[0].title, "beneficial": true, "remaining_seconds": float(active.get("remaining", 0.0)), "stacks": 1})
	return effects
