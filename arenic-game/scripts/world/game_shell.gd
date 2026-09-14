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
var gathering: ArenicGatheringState
var gathering_view: ArenicGatheringSiteView
var _contact_deaths: Dictionary = {}
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
var _cast_feedback: String = "" # Compact presentation paired with the full notice.
var _notice_seconds: float = 0.0
@onready var hud: ArenicWorldHUD = $HUD/HUDOutline
## One decision at a time, above the HUD. It pauses exactly one arena; the
## handler below then resumes, restarts or re-arms that arena deliberately.
var modal: ArenicModal
## Informational tabs own input only; they never pause or become save state.
var overworld_menu: ArenicOverworldMenu
## The one in-flight recording, if any.
var session := ArenicRecordingSession.new()
## Damage earns guild rolls; a roll recruits. Owned by the run so it survives a
## stage swap along with the guild it grows.
var recruitment: ArenicRecruitmentState
var loot: ArenicLootState
## Rewards consume input, never arena time. Only their ledgers are durable.
var reward_cards: ArenicRewardCards
var _reward_kind: String = ""
var _reward_offers: Array[ArenicClassDefinition] = []
var _loot_offer: Dictionary = {}
var _auto_hero_reward: bool = false
var _auto_loot_reward: bool = false
var _loot_participants: Dictionary[String, int] = {}
var _full_loot_deployment: bool = false
var _marker_countdown: int = 1
## Session-scoped messages are projections of model events, never save authority.
var events := ArenicEventBus.new()
var activity_feed := ArenicActivityFeed.new()
var _events_ready: bool = false
var _reported_recruits: int = -1
var _reported_save_error: String = ""
var introduction: ArenicGuildIntroduction
## Visual history never becomes combat or save authority.
var arena_rewind: ArenicArenaRewind
var restart_overlay: ArenicArenaRestartOverlay

func _ready() -> void:
	ArenicDisplayPolicy.apply_game_layout(get_window())
	music = ArenicArenaMusicDirector.new()
	music.name = "ArenaMusic"
	add_child(music)
	sound = ArenicGameplayAudio.new()
	sound.name = "GameplayAudio"
	add_child(sound)
	restart_overlay = ArenicArenaRestartOverlay.new()
	restart_overlay.name = "ArenaRestartOverlay"
	$HUD.add_child(restart_overlay)
	modal = ArenicModal.new()
	modal.name = "Modal"
	modal.chosen.connect(_on_modal_choice)
	$HUD.add_child(modal)
	var menu_layer := CanvasLayer.new()
	menu_layer.name = "OverworldMenuLayer"
	menu_layer.layer = 22
	add_child(menu_layer)
	overworld_menu = ArenicOverworldMenu.new()
	overworld_menu.name = "OverworldMenu"
	menu_layer.add_child(overworld_menu)
	overworld_menu.closed.connect(_clear_menu_input)
	overworld_menu.loot_requested.connect(func() -> void:
		_close_overworld_menu()
		_open_loot())
	var reward_layer := CanvasLayer.new()
	reward_layer.name = "RewardLayer"
	reward_layer.layer = 23
	add_child(reward_layer)
	reward_cards = ArenicRewardCards.new()
	reward_cards.name = "RewardCards"
	reward_layer.add_child(reward_cards)
	reward_cards.card_chosen.connect(_on_reward_card)
	reward_cards.deferred.connect(_defer_reward)
	reward_cards.dismissed.connect(_close_reward_cards)
	loot = RunSetup.get_loot()
	hud.overworld_action_requested.connect(_open_overworld_action)
	hud.world_rect_changed.connect(_update_view_rect)
	hud.toggle_requested.connect(toggle_view)
	hud.ability_requested.connect(_on_ability_requested)
	hud.ability_released.connect(_on_ability_released)
	hud.arena_requested.connect(paginate_arena)
	# The guild grows mid-run, so a recruit is mounted where it arrives rather
	# than waiting for a stage swap to notice it.
	RunSetup.hero_recruited.connect(_on_hero_recruited)
	hud.record_requested.connect(_handle_record_key)
	hud.recruitment_requested.connect(_open_roll)
	hud.loot_requested.connect(_open_loot)
	hud.set_health_source(func(member: ArenicHeroState) -> Dictionary:
		return combat.ally_status(member.arena_id, member.ally_id()) if combat != null else {})
	hud.set_ghost_source(_is_ghost)
	hud.hero_requested.connect(_on_hud_hero_requested)
	replace_stage(stage_scene)
	if not SaveGames.attach_shell(self):
		set_physics_process(false)
		return
	_restore_restarts()
	activity_feed.configure(stage.world)
	activity_feed.bind(events)
	hud.set_activity_feed(activity_feed)
	_events_ready = true
	_publish_recruitment()
	if not session.is_idle():
		_publish_recording("countdown" if session.is_counting_down() else ("paused" if encounter.is_paused(session.arena_id) else "recording"))
	hud.save_title_requested.connect(_save_and_title)
	SaveGames.status_changed.connect(hud.set_save_status)
	SaveGames.status_changed.connect(_on_save_status)
	hud.set_save_status("Saved" if SaveGames.active_slot >= 0 else "Preview")
	_mount_introduction()
	if entry_sequence != null and SaveGames.active_slot < 0 and not intro_locked():
		play_sequence(entry_sequence)


func intro_locked() -> bool:
	return RunSetup.intro_step < ArenicGuildIntroduction.COMPLETE


func _mount_introduction() -> void:
	introduction = ArenicGuildIntroduction.new()
	introduction.name = "GuildIntroduction"
	introduction.definition = load("res://data/intro/guild_introduction.tres")
	$HUD.add_child(introduction)
	introduction.step_requested.connect(_advance_introduction)
	if intro_locked():
		selected_index = stage.world.index_for_id("guild_house")
		hero.selected = true
		zoomed = true
		stage.select_arena(selected_index)
		_frame(false)
		_hero_input.clear()
		_cancel_cast_input()
	introduction.bind(self)
	_update_hud()


func _advance_introduction(next_step: int) -> void:
	if not intro_locked() or next_step != RunSetup.intro_step + 1:
		return
	RunSetup.intro_step = next_step
	_hero_input.clear()
	_cancel_cast_input()
	introduction.set_step(next_step)
	if not intro_locked():
		events.dispatch(ArenicGameEvent.create(&"notice", {"text": "The Guild House doors are open. Press R to begin your first recording."}))
	_update_hud()
	SaveGames.flush.call_deferred()


func _walk_introduction() -> void:
	var direction: Vector2i = _hero_input.consume()
	if not introduction.can_walk() or direction == Vector2i.ZERO:
		return
	var previous: Vector2i = hero.cell
	var facing: String = hero.facing
	# All seams remain closed, including diagonal corners and routes outside
	# the visible gate artwork. The NPC is never an enemy or damage target.
	if hero.step_within_arena(direction):
		if combat.is_occupied("guild_house", hero.cell) or hero.cell == introduction.definition.npc.cell:
			hero.cell = previous
			hero.facing = facing
		stage.sync_heroes(hero.identity_id, true)
	combat.sync_allies(heroes)
	_update_hud()


func _save_and_title() -> void:
	await SaveGames.return_to_title()


func _process(delta: float) -> void:
	activity_feed.advance(delta)


func _exit_tree() -> void:
	# The subscription and feed reference each other. End that transient lifetime
	# explicitly instead of retaining a past shell's messages in a reference cycle.
	activity_feed.unbind()


func _publish_recruitment() -> void:
	if not _events_ready or recruitment == null or combat == null:
		return
	var available: int = recruitment.rolls_available(_total_earnings())
	if available == _reported_recruits:
		return
	if _reported_recruits >= 0 and available > _reported_recruits:
		_auto_hero_reward = true
	_reported_recruits = available
	events.dispatch(ArenicGameEvent.create(&"recruit.ready", {"available": available}, ArenicGameEvent.Severity.INFO, ArenicGameEvent.Importance.HIGH))


func _on_save_status(message: String) -> void:
	if not _events_ready:
		return
	# The facade owns error classification. "Saving…" during a retry does not
	# become another error merely because the previous failure is still visible.
	if not SaveGames.last_error.is_empty() and message == SaveGames.last_error:
		var display: String = message.replace("\n", " ").replace("\r", " ").replace("\t", " ").strip_edges().left(256)
		if display == _reported_save_error or display.is_empty():
			return
		_reported_save_error = display
		events.dispatch(ArenicGameEvent.create(&"notice", {"text": display}, ArenicGameEvent.Severity.ERROR, ArenicGameEvent.Importance.HIGH))
	elif message == "Saved" and SaveGames.last_error.is_empty() and not _reported_save_error.is_empty():
		_reported_save_error = ""
		events.dispatch(ArenicGameEvent.create(&"notice", {"text": "Saving recovered. Your progress is saved."}))


func _publish_recording(status: String, member: ArenicHeroState = null, arena_id: String = "") -> void:
	if not _events_ready:
		return
	var owner: ArenicHeroState = member if member != null else RunSetup.hero_for(session.identity)
	if owner == null:
		return
	var arena: String = arena_id if not arena_id.is_empty() else session.arena_id
	events.dispatch(ArenicGameEvent.create(&"recording.status", {"hero_id": owner.identity_id,
		"hero_name": owner.display_name(), "arena_id": arena, "status": status}))

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
	_close_overworld_menu()
	_stop_sequence()
	if is_instance_valid(stage):
		$ContentSlot.remove_child(stage)
		stage.queue_free()
	stage = candidate
	if _events_ready:
		activity_feed.configure(stage.world)
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
	if not is_instance_valid(arena_rewind):
		arena_rewind = ArenicArenaRewind.new()
		arena_rewind.name = "ArenaRewind"
		add_child(arena_rewind)
	_restore_restarts()
	sound.configure(stage, hero, combat, MOVEMENT_SOUNDS)
	selected_index = stage.world.index_for_id(hero.arena_id)
	zoomed = false
	stage.select_arena(selected_index)
	_update_view_rect()
	_frame(false)
	if is_instance_valid(introduction):
		introduction.mount_world(stage)
		if intro_locked():
			zoomed = true
			_frame(false)
	_update_hud()

func select_arena(index: int) -> void:
	if intro_locked():
		return
	if sequence_active or not is_instance_valid(stage) or index < 0 or index >= stage.world.arenas.size():
		return
	_hero_input.clear()
	_cancel_cast_input()
	_close_overworld_menu()
	if selected_index != index and _reward_open():
		_close_reward_cards() # Death/relocation returns to the actual arena view.
	if not session.is_idle() and stage.world.arenas[index].arena_id != session.arena_id:
		_cancel_active_recording("You left the arena. The take was discarded.")
	selected_index = index
	stage.select_arena(index)
	_adopt_arena_default()
	_clear_overview_selection()
	if zoomed:
		_frame(true)
	_update_hud()

## HUD navigation shares the same arena-scoped selection as every other path.
func paginate_arena(index: int) -> void:
	if intro_locked():
		return
	if sequence_active or not is_instance_valid(stage) or index == selected_index:
		select_arena(index)
		return
	select_arena(index)


## Hands control to the member this arena remembers, or to the first one standing
## there if it remembers nobody. Empty arenas retain identity memory only;
## no remote hero remains selected or receives input.
func _adopt_arena_default() -> void:
	if not is_instance_valid(stage):
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
	if intro_locked():
		return
	if sequence_active or not is_instance_valid(stage):
		return
	_hero_input.clear()
	_cancel_cast_input()
	_close_overworld_menu()
	zoomed = value
	_frame(true)
	_update_hud()

func _frame(animated: bool) -> void:
	var bounds := ArenicGridMath.arena_rect(stage.world.arenas[selected_index].grid_slot) if zoomed else ArenicGridMath.world_rect()
	stage.camera_rig.frame_bounds(bounds, animated)

func _update_view_rect() -> void:
	if is_instance_valid(stage):
		stage.set_view_rect(hud.get_world_rect())
	if is_instance_valid(restart_overlay):
		var bounds: Rect2 = hud.get_world_rect()
		restart_overlay.position = bounds.position
		restart_overlay.size = bounds.size

func _update_hud() -> void:
	_clear_overview_selection()
	music.set_focus(StringName(stage.world.arenas[selected_index].arena_id), zoomed)
	sound.set_focus(stage.world.arenas[selected_index].arena_id, zoomed and not sequence_active)
	var definition := hero.definition
	var local_hero: bool = hero.arena_id == stage.world.arenas[selected_index].arena_id
	hud.set_context(stage.world.arenas[selected_index], hero.display_name() if local_hero else "", definition.display_name if local_hero else "", zoomed)
	hud.set_hero_control(_hero_in_focused_arena(), hero.selected)
	stage.sync_heroes(hero.identity_id, _hero_in_focused_arena(), _is_ghost, _is_defeated_ghost)
	_update_combat_hud()
	_update_restart_overlay()

func _clear_overview_selection() -> void:
	for member: ArenicHeroState in heroes:
		if not zoomed or member.arena_id != stage.world.arenas[selected_index].arena_id:
			member.selected = false

func _overworld_menu_open() -> bool:
	return is_instance_valid(overworld_menu) and overworld_menu.is_open()

func _clear_menu_input() -> void:
	_hero_input.clear()
	_cancel_cast_input()

func _close_overworld_menu() -> void:
	if is_instance_valid(overworld_menu):
		overworld_menu.close()

func _open_overworld_action(action: StringName) -> void:
	if zoomed or intro_locked() or sequence_active or _reward_open() or not is_instance_valid(stage):
		return
	if modal.is_open() or ArenicOverworldActions.index_for(action) < 0:
		return
	_clear_menu_input()
	hud.hide_overlays()
	overworld_menu.configure(stage.world.arenas[selected_index].visual_theme)
	overworld_menu.set_loot_inventory(loot.inventory_rows(), loot.pending_count())
	overworld_menu.open_action(action)

func _input(event: InputEvent) -> void:
	if _reward_open():
		reward_cards.consume_input(event)
		# Card buttons need the GUI pointer pass. Keyboard is owned here once.
		if not (event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag):
			get_viewport().set_input_as_handled()
		return
	if _overworld_menu_open() or (is_instance_valid(modal) and modal.is_open()):
		return
	# Release is observed even when a Control consumes the matching mouse/key event.
	if event is InputEventKey and not event.pressed and (event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE):
		_space_held = false
		_release_channel_if_needed(true)
	elif event is InputEventKey and not event.pressed and (event.keycode == KEY_1 or event.physical_keycode == KEY_1):
		_slot_held = false
		_release_channel_if_needed(true)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_button_held = false
		_release_channel_if_needed(true)

func _unhandled_input(event: InputEvent) -> void:
	if _reward_open():
		get_viewport().set_input_as_handled()
		return
	if _overworld_menu_open() or (is_instance_valid(modal) and modal.is_open()):
		return
	if not is_instance_valid(stage):
		return
	# The save/menu path stays available while onboarding owns gameplay input.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_H and not event.ctrl_pressed and not event.meta_pressed and not event.alt_pressed:
		hud.toggle_help()
		get_viewport().set_input_as_handled()
		return
	if is_instance_valid(introduction):
		if introduction.intercept(event):
			_hero_input.clear()
			_cancel_cast_input()
			get_viewport().set_input_as_handled()
			return
		if intro_locked():
			if introduction.can_walk() and event is InputEventKey:
				_hero_input.accept(event)
			get_viewport().set_input_as_handled()
			return
	if sequence_active:
		if event.is_action_pressed("ui_cancel"):
			_sequence.cancel()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if not zoomed and not event.ctrl_pressed and not event.meta_pressed and not event.alt_pressed and not event.shift_pressed:
			var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			var action: StringName = ArenicOverworldActions.action_for_key(key)
			if not action.is_empty():
				_open_overworld_action(action)
				get_viewport().set_input_as_handled()
				return
		var handled := true
		if (event.keycode == KEY_SPACE or event.physical_keycode == KEY_SPACE) and not event.ctrl_pressed and not event.meta_pressed and not event.alt_pressed:
			_space_held = true
			_queue_cast()
		elif (event.keycode == KEY_1 or event.physical_keycode == KEY_1) and not event.ctrl_pressed and not event.meta_pressed and not event.alt_pressed:
			_slot_held = true
			_queue_cast()
		elif event.keycode in [KEY_2, KEY_3, KEY_4] and not event.ctrl_pressed and not event.meta_pressed and not event.alt_pressed:
			pass # The four positions are fixed; unassigned slots never cast a different ability.
		elif event.keycode == KEY_C and not event.ctrl_pressed and not event.meta_pressed and not event.alt_pressed:
			hud.toggle_chat()
		elif event.is_action_pressed("ui_cancel") and hud.is_chat_expanded():
			hud.toggle_chat()
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
		elif not zoomed and event.is_action_pressed("ui_left"):
			_move_selection(Vector2i.LEFT)
		elif not zoomed and event.is_action_pressed("ui_right"):
			_move_selection(Vector2i.RIGHT)
		elif not zoomed and event.is_action_pressed("ui_up"):
			_move_selection(Vector2i.UP)
		elif not zoomed and event.is_action_pressed("ui_down"):
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
	if intro_locked():
		return
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
	_close_overworld_menu()
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

## Tab selects or cycles only the viewed arena. Empty arenas never redirect
## control or the camera to a remembered hero elsewhere.
func select_hero() -> void:
	if intro_locked():
		return
	if sequence_active or hero == null:
		return
	var present: Array[ArenicHeroState] = RunSetup.heroes_in(stage.world.arenas[selected_index].arena_id)
	if present.is_empty():
		_clear_overview_selection()
		return
	if hero not in present:
		_adopt_arena_default()
	if _hero_in_focused_arena() and hero.selected and present.size() > 1:
		var at: int = present.find(hero)
		_select_identity(present[(at + 1) % present.size()].identity_id)
		_update_hud()
		return
	select_arena(stage.world.index_for_id(hero.arena_id))
	set_zoomed(true)
	_select_identity(hero.identity_id)
	_update_hud()


## The one place control moves between guild members. Input state belongs to the
## hero that owned it, so it is cleared rather than inherited.
func _select_identity(identity_id: int) -> void:
	if not RunSetup.select(identity_id):
		return
	_hero_input.clear()
	_cancel_cast_input()
	hero = RunSetup.get_hero()
	_clear_overview_selection()
	if is_instance_valid(stage):
		stage.sync_heroes(hero.identity_id, _hero_in_focused_arena())

func _physics_process(delta: float) -> void:
	if not is_instance_valid(stage) or hero == null or combat == null:
		return
	if intro_locked() and is_instance_valid(introduction):
		_walk_introduction()
		return
	_reconcile_recording()
	_prepare_loot_step()
	# Complete presentation first, but release its simulation hold only after
	# this step: the full countdown ends on canonical tick zero.
	var finished_restarts: Array[String] = arena_rewind.advance(delta)
	# The countdown holds its arena at tick zero and swallows every input.
	if session.is_counting_down():
		# Only the recording arena is paused. Existing workers and ghosts in
		# other arenas keep their own cycle while this countdown is displayed.
		_hero_input.clear()
		_cast_queued = false
		if not sequence_active and encounter != null:
			encounter.tick(combat, 1, {}, _advance_player_combat.bind(delta))
			_sync_boss_placement()
			stage.sync_heroes(hero.identity_id, _hero_in_focused_arena(), _is_ghost, _is_defeated_ghost)
			_sync_gathering()
		if session.advance_countdown():
			encounter.set_paused(session.arena_id, false)
			_publish_recording("recording")
		_hero_input.clear()
		_finish_restarts(finished_restarts)
		_update_hud()
		return
	var movement_snapshot: Dictionary = ArenicHeroContact.capture(heroes, combat)
	var direction := _hero_input.consume()
	if encounter.is_restart_pending(hero.arena_id):
		direction = Vector2i.ZERO
		_hero_input.clear()
	# Arrows never drive a ghost. Ask before taking it out of the score, because
	# breaking out is a decision about the whole arena, not just this hero.
	if direction != Vector2i.ZERO and _hero_in_focused_arena() and hero.selected and encounter.is_ghost(hero):
		_open_modal(hero.arena_id, "Break out of the recording?",
			"Take control unfolds this hero. The arena keeps playing.",
			[["Take control", ArenicModal.TAKE_CONTROL], ["Restart arena", ArenicModal.RESTART_ARENA], ["Cancel", ArenicModal.CANCEL]], 2)
		direction = Vector2i.ZERO
	if direction != Vector2i.ZERO and _hero_in_focused_arena() and hero.selected:
		combat.cancel_channel(hero)
		var previous_arena: String = hero.arena_id
		var previous_cell: Vector2i = hero.cell
		var previous_facing: String = hero.facing
		# Validate the actual exit before discarding: a blocked move is not leaving.
		var stepped: bool = hero.step(direction, stage.world)
		if stepped:
			if encounter.is_restart_pending(hero.arena_id) or combat.is_occupied(hero.arena_id, hero.cell) or (is_instance_valid(introduction) and hero.arena_id == "guild_house" and hero.cell == introduction.definition.npc.cell):
				hero.arena_id = previous_arena
				hero.cell = previous_cell
				hero.facing = previous_facing
				sound.movement(previous_arena, previous_cell, true)
			else:
				if hero.arena_id != previous_arena:
					if session.owns(hero):
						_cancel_active_recording("You left the arena. The take was discarded.")
					_relocate_selection(hero, previous_arena)
					select_arena(stage.world.index_for_id(hero.arena_id))
					_offer_stored_staff()
				sound.movement(hero.arena_id, hero.cell)
				_capture(ArenicTimelineEvent.move(encounter.cycle_position(previous_arena), direction))
			stage.sync_heroes(hero.identity_id, true)
		else:
			sound.movement(previous_arena, previous_cell, true)
	if not sequence_active:
		if encounter != null:
			encounter.tick(combat, 1, movement_snapshot, _advance_player_combat.bind(delta))
			_reconcile_recording()
			_check_recording_full()
		else:
			_advance_player_combat(delta)
	_sync_boss_placement()
	_sync_dig_markers()
	# Guild members move without player input — a recruit arriving, a member
	# relocating, and shortly a ghost replaying its staff. Views follow the
	# ledger every tick rather than only when a key is pressed.
	if hero != null:
		stage.sync_heroes(hero.identity_id, _hero_in_focused_arena(), _is_ghost, _is_defeated_ghost)
	_sync_gathering()
	combat_presentation.sync_active()
	_finish_restarts(finished_restarts)
	_notice_seconds = maxf(0.0, _notice_seconds - delta)
	_combat_hud_elapsed += delta
	if _combat_hud_elapsed >= 0.1:
		_combat_hud_elapsed = 0.0
		_update_combat_hud()
	_drain_reward_attention()


func _advance_player_combat(delta: float) -> void:
	if _cast_queued:
		_cast_queued = false
		if _hero_in_focused_arena() and hero.selected and not encounter.is_restart_pending(hero.arena_id):
			_cast_notice = combat.try_cast(hero)
			_cast_feedback = combat.cast_unavailable_reason(hero, true) if not _cast_notice.is_empty() else ""
			_notice_seconds = 2.0 if not _cast_notice.is_empty() else 0.0
			if _cast_notice.is_empty():
				_capture(ArenicTimelineEvent.ability(encounter.cycle_position(hero.arena_id), 1))
	_release_channel_if_needed()
	combat.sync_allies(heroes)
	combat.tick(delta, hero)

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
			combat.damage_reported.disconnect(_on_damage_reported)
			combat.ally_defeated.disconnect(_on_ally_defeated)
			combat.hero_contact_defeated.disconnect(_on_hero_contact_defeated)
		combat = run_combat
		combat.progress_changed.connect(_on_progress_changed)
		combat.ability_cast.connect(_on_ability_cast)
		combat.ability_landed.connect(_on_ability_landed)
		combat.damage_reported.connect(_on_damage_reported)
		combat.ally_defeated.connect(_on_ally_defeated)
		combat.hero_contact_defeated.connect(_on_hero_contact_defeated)
	combat.configure(stage.world)
	combat.sync_allies(heroes)
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
		encounter.arena_advanced.connect(_on_arena_advanced)
		encounter.arena_cycle_completed.connect(_on_arena_cycle_completed)
		encounter.arena_restarting.connect(_on_arena_restarting)
		encounter.arena_restarted.connect(_on_arena_restarted)
	encounter.roster_lookup = func() -> Array: return heroes
	encounter.performer_lookup = func(performer: String) -> ArenicHeroState:
		for member: ArenicHeroState in heroes:
			if member.ally_id() == performer:
				return member
		return null
	encounter.configure(stage.world, ENCOUNTERS, combat)
	music.cycle_source = encounter
	music.suspension_lookup = func() -> bool: return intro_locked() or sequence_active
	_mount_gathering()
	_sync_boss_placement()
	combat_presentation = ArenicCombatPresentation.new()
	combat_presentation.name = "CombatPresentation"
	stage.add_child(combat_presentation)
	combat_presentation.configure(stage, combat.enemy_presentation_pose, combat.is_channeling, combat.active_cast_snapshot)
	combat_presentation.arena_paused_lookup = encounter.is_paused
	for member: ArenicHeroState in heroes:
		combat_presentation.restore_active(combat.active_cast_snapshot(member))


func _mount_gathering() -> void:
	gathering = RunSetup.get_gathering()
	if is_instance_valid(gathering_view):
		gathering_view.free()
	gathering_view = ArenicGatheringSiteView.new()
	gathering_view.name = "GatheringSites"
	var index: int = stage.world.index_for_id(ArenicGatheringState.ARENA_ID)
	stage.get_arena(index).add_child(gathering_view)
	gathering_view.configure(gathering.definition)
	_sync_gathering()


func _sync_gathering() -> void:
	if gathering == null or not is_instance_valid(stage):
		return
	for member: ArenicHeroState in heroes:
		var view: ArenicHeroView = stage.hero_views.get(member.identity_id)
		if is_instance_valid(view):
			view.set_gathering_status({} if combat.ally_defeated_at(member.arena_id, member.ally_id()) else gathering.snapshot_for(member))


## Freeze deployment once for this shared simulation step so simultaneous wraps
## do not change another arena's reward merely because its loop resets first.
func _prepare_loot_step() -> void:
	_loot_participants.clear()
	_full_loot_deployment = true
	for arena: ArenicArenaDefinition in stage.world.arenas:
		if arena.arena_id == ArenicGatheringState.ARENA_ID:
			continue
		_loot_participants[arena.arena_id] = 0
		if encounter.ghost_count(arena.arena_id) < ArenicEncounterState.MAX_GHOSTS_PER_ARENA or encounter.is_paused(arena.arena_id):
			_full_loot_deployment = false
	for member: ArenicHeroState in heroes:
		if _loot_participants.has(member.arena_id) and (encounter.is_ghost(member) or not combat.ally_defeated_at(member.arena_id, member.ally_id())):
			_loot_participants[member.arena_id] = mini(ArenicEncounterState.MAX_GHOSTS_PER_ARENA, _loot_participants[member.arena_id] + 1)


func _on_arena_cycle_completed(arena_id: String) -> void:
	if loot == null or arena_id == ArenicGatheringState.ARENA_ID or intro_locked():
		return
	var awarded: Dictionary = loot.complete_cycle(arena_id, combat.damage_for_arena(arena_id), encounter.dig_field(arena_id).cycle + 1)
	if not awarded.is_empty():
		_auto_loot_reward = true
		_update_recruitment_hud()
		if _events_ready:
			var arena: ArenicArenaDefinition = stage.world.arenas[stage.world.index_for_id(arena_id)]
			events.dispatch(ArenicGameEvent.create(&"notice", {"text": "%s completed a battle. A loot draw is ready." % arena.display_name}))
		SaveGames.checkpoint.call_deferred()


func _on_arena_advanced(arena_id: String) -> void:
	if loot != null and arena_id != ArenicGatheringState.ARENA_ID and not intro_locked():
		loot.observe_cycle_progress(arena_id, combat.damage_for_arena(arena_id), _loot_participants.get(arena_id, 0), _full_loot_deployment)
	if arena_id != ArenicGatheringState.ARENA_ID or gathering == null or intro_locked():
		return
	for entry: Dictionary in gathering.advance(heroes, combat):
		var worker: ArenicHeroState = RunSetup.hero_for(int(entry.hero_id))
		if _events_ready and worker != null:
			events.dispatch(ArenicGameEvent.create(&"notice", {"text": "%s deposited %d %s." % [worker.display_name(), entry.amount, entry.resource]}))


func _on_arena_restarted(arena_id: String) -> void:
	if loot != null and arena_id != ArenicGatheringState.ARENA_ID:
		loot.reset_cycle(arena_id, combat.damage_for_arena(arena_id), encounter.dig_field(arena_id).cycle)
	if is_instance_valid(arena_rewind) and arena_rewind.is_active(arena_id):
		encounter.set_restart_pending(arena_id, true)
	if is_instance_valid(combat_presentation):
		combat_presentation.clear_arena(arena_id, func(identity: int) -> bool:
			var member: ArenicHeroState = RunSetup.hero_for(identity)
			return member != null and encounter.is_ghost(member))
	if gathering != null and arena_id == ArenicGatheringState.ARENA_ID:
		gathering.restart(heroes)
	music.synchronize_cycles()


func _on_hero_contact_defeated(_arena_id: String, actor_id: String, contact: Dictionary) -> void:
	_contact_deaths[actor_id] = contact

func _on_progress_changed(arena_id: String) -> void:
	_publish_recruitment()
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
	var cast: Dictionary = combat.active_cast_snapshot(caster)
	combat_presentation.show_cast(caster.identity_id, ability_id, arena_id, origin, target_cell, facing, caster.definition.skills[0], str(cast.get("target_id", "")), int(cast.get("cast_id", 0)))


## Relayed to the conductor, which owns arena ground. The shell is a Node and is
## disconnected when it is freed; the conductor is not, and subscribing it
## directly to the run-long ledger would keep every past one alive.
func _on_ability_landed(caster_id: String, ability_id: String, arena_id: String, area: Rect2i, rules: ArenicClassAbility) -> void:
	if encounter != null:
		encounter.apply_landing(ability_id, arena_id, area, rules, caster_id)


func _hero_for_ally(caster_id: String) -> ArenicHeroState:
	for member: ArenicHeroState in heroes:
		if member.ally_id() == caster_id:
			return member
	return null

func _on_damage_reported(caster_id: String, ability_id: String, arena_id: String, enemy_id: String, amount: int) -> void:
	var source: ArenicHeroState = _hero_for_ally(caster_id)
	var footprint: Rect2i = combat.enemy_footprint(arena_id, enemy_id)
	var center: Vector2 = Vector2(footprint.position) + Vector2(footprint.size - Vector2i.ONE) * 0.5
	var cast: Dictionary = combat.active_cast_snapshot(source) if source != null else {}
	combat_presentation.show_hit(source.identity_id if source != null else -1, ability_id, arena_id, center, amount, str(cast.get("facing", source.facing if source != null else "n")))
	if not _events_ready:
		return
	var caster: ArenicHeroState = _hero_for_ally(caster_id)
	var source_id: String = ability_id if not ability_id.is_empty() else "environment"
	var ability_name: String = "Environment"
	var rules: ArenicClassAbility
	if caster != null:
		for skill: ArenicClassAbility in caster.definition.skills:
			if skill != null and skill.ability_id == source_id:
				rules = skill
				break
	else:
		# A migrated pool can know its ability without knowing its old thrower.
		# Only authored catalog entries supply names; never infer them from IDs.
		for definition: ArenicClassDefinition in RunSetup.class_catalog().classes:
			for skill: ArenicClassAbility in definition.skills:
				if skill != null and skill.ability_id == source_id:
					rules = skill
					break
			if rules != null:
				break
	if rules != null:
		ability_name = rules.title
	events.dispatch(ArenicGameEvent.create(&"raid.damage", {
		"arena_id": arena_id, "amount": amount,
		"hero_id": caster.identity_id if caster != null else -1,
		"hero_name": caster.display_name() if caster != null else "",
		"ability_id": source_id, "ability_name": ability_name,
	}, ArenicGameEvent.Severity.DEBUG, ArenicGameEvent.Importance.LOW))

func _queue_cast() -> void:
	if intro_locked() or not zoomed or _overworld_menu_open() or _reward_open() or encounter.is_restart_pending(hero.arena_id):
		return
	if _hero_in_focused_arena() and hero.selected:
		_cast_queued = true # One input per physics tick, no key-repeat queue.
	else:
		_cast_notice = "Tab to focus and select your hero."
		_cast_feedback = "Focus hero"
		_notice_seconds = 2.0
		_update_combat_hud()

func _on_ability_requested() -> void:
	if not zoomed or _overworld_menu_open() or _reward_open():
		return
	_button_held = true
	_queue_cast()

func _on_ability_released() -> void:
	if _overworld_menu_open():
		return
	_button_held = false
	_release_channel_if_needed(true)

func _release_channel_if_needed(explicit_release: bool = false) -> void:
	if not explicit_release and encounter != null and hero != null and encounter.is_restart_pending(hero.arena_id):
		return
	if not _space_held and not _slot_held and not _button_held and combat != null and not _is_ghost(hero):
		combat.cancel_channel(hero)

func _cancel_cast_input() -> void:
	_cast_queued = false
	_space_held = false
	_slot_held = false
	_button_held = false
	if combat != null and not _is_ghost(hero):
		combat.cancel_channel(hero)

func _update_combat_hud() -> void:
	if combat == null or hero == null or not is_instance_valid(stage):
		return
	var arena: ArenicArenaDefinition = stage.world.arenas[selected_index]
	hud.set_damage_progress(combat.damage_for_arena(arena.arena_id), combat.phase_size(arena.arena_id))
	hud.set_boss_effects(encounter.boss_effects(arena.arena_id) if encounter != null else [])
	hud.set_encounter_cue(encounter.score_readout(arena.arena_id) if encounter != null and zoomed else "")
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
	var feedback: String = "" if here else ("Focus hero" if hero.arena_id == arena.arena_id else "No hero here")
	if hero.arena_id != arena.arena_id:
		hint = "No hero in this arena."
	if here and combat.cooldown_remaining(hero) <= 0.0 and combat.active_remaining(hero) <= 0.0 and not unavailable.is_empty():
		hint = unavailable
		feedback = combat.cast_unavailable_reason(hero, true)
	if _notice_seconds > 0.0:
		hint = _cast_notice
		feedback = _cast_feedback
	var restarting: bool = encounter.is_restart_pending(hero.arena_id)
	if restarting:
		feedback = "Rewinding" if arena_rewind.phase(hero.arena_id) == "rewind" else "Get ready"
		hint = "The arena will resume after the countdown."
	var enabled: bool = here and not restarting and (combat.is_channeling(hero) or unavailable.is_empty())
	hud.set_ability_context(ability.title, hint, combat.cooldown_remaining(hero), combat.active_remaining(hero), enabled, feedback)
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
	if loot != null:
		hud.set_loot(loot.pending_count())


func _update_recording_hud() -> void:
	if zoomed and hero != null and is_instance_valid(stage) and hero.arena_id != stage.world.arenas[selected_index].arena_id:
		hud.set_recording_state("Record", "No hero in this arena.", false)
		return
	if hero != null and encounter.is_restart_pending(hero.arena_id):
		var reversing: bool = arena_rewind.phase(hero.arena_id) == "rewind"
		hud.set_recording_state("Rewind" if reversing else "Ready", "The next loop begins after 3–2–1.", false, "«" if reversing else str(arena_rewind.countdown_seconds(hero.arena_id)))
	elif session.is_counting_down():
		hud.set_recording_state("Record", "Recording begins at zero. R aborts.", true, "%d" % session.countdown_seconds())
	elif session.is_recording():
		hud.set_recording_state("REC", "R to commit, keep recording, or discard.", true, encounter.cycle_label(session.arena_id))
	elif hero != null and encounter.is_ghost(hero):
		hud.set_recording_state("Ghost", "This hero is playing its staff. R to record over it.", false)
	else:
		hud.set_recording_state("Record", "R records a two-minute staff for this hero in this arena.", false)


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
			view.set_score_view(encounter.mask_score(arena_id), encounter.cycle_position(arena_id))


## Broken ground pays the guild, not the arena: it is income toward the next
## hero rather than damage on the boss.
func _on_tile_dug(arena_id: String, cell: Vector2i, value: int) -> void:
	RunSetup.prospected += value
	_publish_recruitment()
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
	var contact: Dictionary = _contact_deaths.get(actor_id, {})
	_contact_deaths.erase(actor_id)
	if gathering != null:
		gathering.clear_hero(struck.identity_id)
	if _events_ready:
		events.dispatch(ArenicGameEvent.create(&"hero.defeated", {"hero_id": struck.identity_id,
			"hero_name": struck.display_name(), "arena_id": arena_id, "recorded": encounter.is_ghost(struck) and (contact.is_empty() or not bool(contact.selected)), "cause": "contact" if not contact.is_empty() else "attack"},
			ArenicGameEvent.Severity.WARNING, ArenicGameEvent.Importance.HIGH))
	if session.owns(struck):
		_cancel_active_recording("You died mid-recording. The take was discarded.")
		_respawn_free_hero(struck)
		if struck == hero:
			set_zoomed(true)
		return
	# A GHOST dies in place. Walking it home would resume its recorded intent in
	# the wrong arena and destroy replay; instead it lies where it fell and rises
	# with the next cycle. Because the pattern is fixed and its intent is fixed,
	# it will die at the same tick every cycle until the staff is re-recorded —
	# which is exactly the feedback that teaches a better path.
	if not contact.is_empty() and bool(contact.selected) and encounter.is_ghost(struck):
		encounter.unfold_ghost(struck)
		# The cached staff stays available, but selected collision victims return home.
	if encounter.is_ghost(struck):
		if is_instance_valid(stage):
			var view: ArenicHeroView = stage.hero_views.get(struck.identity_id)
			if is_instance_valid(view):
				view.set_ghost(true)
				view.set_defeated(true, true)
		return
	_respawn_free_hero(struck)
	if struck == hero and not contact.is_empty():
		_cast_notice = "You touched another hero. Respawned at an empty Guild House tile."
		_cast_feedback = "Collision"


## Leaving a dead ghost's recording uses the same recovery as a free defeat.
## This moves/restores existing state without publishing another defeat event.
func _respawn_free_hero(struck: ArenicHeroState) -> void:
	var fell_in: String = struck.arena_id
	if session.owns(struck):
		_cancel_active_recording("You died mid-recording. The take was discarded.")
	struck.arena_id = RESPAWN_ARENA
	struck.cell = ArenicHeroPlacement.for_hero(RESPAWN_ARENA, RESPAWN_CELL, heroes, combat, struck.identity_id)
	assert(struck.cell != ArenicHeroPlacement.NONE, "The bounded guild must have an empty respawn tile.")
	struck.facing = RESPAWN_FACING
	combat.respawn_hero_ally(struck)
	_relocate_selection(struck, fell_in)
	if struck != hero:
		if zoomed and stage.world.arenas[selected_index].arena_id == struck.arena_id and RunSetup.heroes_in(struck.arena_id).size() == 1:
			_select_identity(struck.identity_id)
		return # Another member arriving never moves the camera away.
	_hero_input.clear()
	_cancel_cast_input()
	_cast_notice = "You were defeated. Respawned at the Guild House."
	_cast_feedback = "Respawned"
	_notice_seconds = 3.0
	if not is_instance_valid(stage):
		return
	select_arena(stage.world.index_for_id(hero.arena_id))
	stage.sync_heroes(hero.identity_id, _hero_in_focused_arena(), _is_ghost, _is_defeated_ghost)
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

func _is_defeated_ghost(member: ArenicHeroState) -> bool:
	return _is_ghost(member) and combat != null and combat.ally_defeated_at(member.arena_id, member.ally_id())


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
	_cast_feedback = "Arena full"
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


## N and the top navigation reopen a banked choice without rerolling it.
func _open_roll() -> void:
	if not _can_open_reward():
		return
	if recruitment.rolls_available(_total_earnings()) <= 0 or heroes.size() >= RunSetup.MAX_GUILD:
		var next_at: int = recruitment.next_threshold(_total_earnings())
		_cast_notice = "No hero ready. Keep fighting to earn the next one." if next_at > 0 else "The guild is full."
		_cast_feedback = "No heroes ready"
		_notice_seconds = 2.5
		_update_hud()
		return
	_reward_offers = recruitment.offers(recruitment.rolls_claimed, RunSetup.class_catalog())
	if _reward_offers.is_empty():
		return
	_prepare_reward_view()
	_reward_kind = "heroes"
	_auto_hero_reward = false
	reward_cards.open_heroes(stage.world.arenas[selected_index], _reward_offers)


func _open_loot() -> void:
	if not _can_open_reward() or loot == null or loot.pending_count() <= 0:
		return
	_loot_offer = loot.peek(RunSetup.run_seed, stage.world.arenas[selected_index].arena_id)
	if _loot_offer.is_empty():
		return
	_prepare_reward_view()
	_reward_kind = "loot"
	_auto_loot_reward = false
	var cards: Array[Dictionary] = []
	for item: Dictionary in _loot_offer.cards:
		cards.append(item)
	reward_cards.open_loot(stage.world.arenas[selected_index], cards)


func _can_open_reward() -> bool:
	return is_instance_valid(stage) and is_instance_valid(reward_cards) and hero != null and recruitment != null and combat != null and not intro_locked() and not sequence_active and session.is_idle() and not modal.is_open() and not _overworld_menu_open() and not _reward_open()


func _reward_open() -> bool:
	return is_instance_valid(reward_cards) and reward_cards.is_open()


func _prepare_reward_view() -> void:
	_clear_menu_input()
	hud.hide_overlays()


func _close_reward_cards() -> void:
	if is_instance_valid(reward_cards):
		reward_cards.close()
	_reward_kind = ""
	_reward_offers.clear()
	_loot_offer.clear()
	_clear_menu_input()


func _defer_reward() -> void:
	# Later acknowledges the current batch. Another completion may ask again;
	# all existing choices remain banked in the two top navigation controls.
	_auto_hero_reward = false
	_auto_loot_reward = false
	_close_reward_cards()


func _on_reward_card(index: int) -> void:
	if not _reward_open() or index < 0 or index >= 3:
		return
	if _reward_kind == "heroes":
		if index >= _reward_offers.size():
			return
		var class_id: String = _reward_offers[index].class_id
		_close_reward_cards()
		_claim_roll(class_id)
		_update_hud()
	elif _reward_kind == "loot" and not _loot_offer.is_empty():
		var item: Dictionary = loot.claim(_loot_offer.token, index, RunSetup.run_seed)
		_loot_offer.clear() # A queued second click cannot claim another chest.
		if item.is_empty():
			_close_reward_cards()
			return
		reward_cards.show_loot_result(index, item)
		_update_recruitment_hud()
		if _events_ready:
			events.dispatch(ArenicGameEvent.create(&"notice", {"text": "%s equipment found: %s." % [str(item.rarity).capitalize(), item.name]}))
		SaveGames.checkpoint.call_deferred()


func _drain_reward_attention() -> void:
	if not _can_open_reward():
		return
	if _auto_hero_reward:
		_auto_hero_reward = false
		if recruitment.rolls_available(_total_earnings()) > 0 and heroes.size() < RunSetup.MAX_GUILD:
			_open_roll()
			return
	if _auto_loot_reward:
		_auto_loot_reward = false
		_open_loot()


## No card animation is a save authority. A pre-card recruitment modal is
## normalized to the same banked offer and its old arena pause is released.
func _restore_reward_presentation() -> void:
	_close_reward_cards()
	_auto_hero_reward = false
	_auto_loot_reward = false
	if modal.is_open():
		for choice: String in modal._choices:
			if choice.begins_with(ArenicModal.RECRUIT_PREFIX):
				var source: String = modal.arena_id
				modal.close()
				_resume_arena(source)
				_auto_hero_reward = true
				break


## Validate against the current earned offer before spending it. A repeated
## input, stale modal or arbitrary class ID cannot manufacture a guild member.
func _claim_roll(class_id: String) -> void:
	if recruitment.rolls_available(_total_earnings()) <= 0 or heroes.size() >= RunSetup.MAX_GUILD:
		return
	for definition: ArenicClassDefinition in recruitment.offers(recruitment.rolls_claimed, RunSetup.class_catalog()):
		if definition.class_id != class_id:
			continue
		var recruit: ArenicHeroState = RunSetup.recruit(definition)
		if recruit != null:
			recruitment.claim()
			_publish_recruitment()
			_cast_notice = "%s joined the guild at the Guild House." % recruit.display_name()
			_cast_feedback = "Recruited"
			_notice_seconds = 3.0
			SaveGames.checkpoint.call_deferred()
		return


## R — the context-sensitive record key. There is no modal where there is no
## real choice: a hero with no staff here goes straight to the countdown.
func _handle_record_key() -> void:
	if intro_locked() or _overworld_menu_open() or _reward_open() or not zoomed:
		return
	if hero == null or not is_instance_valid(stage) or encounter.is_restart_pending(hero.arena_id):
		return
	if not session.is_idle() and (not session.owns(hero) or not _hero_in_focused_arena()):
		return
	if session.is_counting_down():
		# Nothing has been captured yet, so aborting costs nothing.
		var owner: ArenicHeroState = RunSetup.hero_for(session.identity)
		var arena_id: String = session.arena_id
		session.clear()
		_resume_arena(hero.arena_id)
		_publish_recording("cancelled", owner, arena_id)
		_update_hud()
		return
	if session.is_recording():
		_open_modal(session.arena_id, "Like the recording?",
			"Commit folds this draft into the arena's timeline.",
			[["Commit", ArenicModal.COMMIT], ["Keep recording", ArenicModal.CANCEL], ["Discard", ArenicModal.DISCARD]], 1)
		return
	if not _hero_in_focused_arena() or not hero.selected:
		_cast_notice = "Tab to focus and select a hero first."
		_cast_feedback = "Focus hero"
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
	encounter.restart(hero.arena_id, false)
	encounter.set_paused(hero.arena_id, true)
	encounter.snap_ghosts(hero.arena_id, hero.identity_id)
	session.arm(hero)
	music.synchronize_cycles()
	_hero_input.clear()
	_cancel_cast_input()
	_publish_recording("countdown")
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
		encounter.restart(arena_id)
		_cast_notice = "The arena filled up. Your staff is saved; press R to fold it in later."
		_cast_feedback = "Staff saved"
		_notice_seconds = 4.0
	_publish_recording("committed", owner, arena_id)
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
	_close_overworld_menu()
	_close_reward_cards()
	# Only this arena stops. The other eight keep performing, which is what makes
	# watching another arena mid-decision safe.
	if encounter != null:
		encounter.set_paused(owner_arena, true)
	_hero_input.clear()
	if session.is_recording() and session.arena_id == owner_arena:
		_publish_recording("paused")
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
			var owner: ArenicHeroState = RunSetup.hero_for(session.identity)
			session.clear()
			_resume_arena(owner_arena)
			_publish_recording("discarded", owner, owner_arena)
		ArenicModal.DISCARD_AND_WALK:
			# Throw the take away, THEN perform the step that interrupted it.
			var owner: ArenicHeroState = RunSetup.hero_for(session.identity)
			session.clear()
			_resume_arena(owner_arena)
			_publish_recording("discarded", owner, owner_arena)
			var step: Vector2i = context.get("step", Vector2i.ZERO)
			var left: String = hero.arena_id
			if step != Vector2i.ZERO and hero.step(step, stage.world) and hero.arena_id != left:
				_relocate_selection(hero, left)
				select_arena(stage.world.index_for_id(hero.arena_id))
				_offer_stored_staff()
		ArenicModal.TAKE_CONTROL:
			# The events leave the score and the arena keeps playing right where
			# it left off. This is the one path that does not rewind.
			var was_defeated: bool = _is_defeated_ghost(hero)
			encounter.unfold_ghost(hero)
			_resume_arena(owner_arena)
			if was_defeated:
				_respawn_free_hero(hero)
		ArenicModal.RESTART_ARENA:
			# "I made a mistake": rewind everything; the hero stays folded.
			encounter.restart(owner_arena)
		ArenicModal.COMMIT_DEATH, ArenicModal.RETURN_HOME:
			var owner: ArenicHeroState = RunSetup.hero_for(session.identity)
			_cancel_active_recording("You died mid-recording. The take was discarded.")
			if owner != null:
				_respawn_free_hero(owner)
				set_zoomed(true)
		ArenicModal.COMMIT:
			_commit_recording()
		ArenicModal.START_RECORDING:
			if encounter.is_ghost(hero):
				if _is_defeated_ghost(hero):
					# The new take restarts this arena. Unfolding first removes
					# its owner from that restart's normal ghost revival pass.
					combat.reset_caster(hero)
					combat.revive_ally(hero.arena_id, hero.ally_id())
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
		if session.is_recording() and session.arena_id == owner_arena:
			_publish_recording("resumed")


func _on_hero_recruited(recruit: ArenicHeroState) -> void:
	if not is_instance_valid(stage) or recruit == null:
		return
	if _events_ready:
		events.dispatch(ArenicGameEvent.create(&"guild.hero_recruited", {"hero_id": recruit.identity_id, "hero_name": recruit.display_name()}))
	heroes = RunSetup.get_heroes()
	stage.mount_heroes(heroes)
	if RunSetup.heroes_in(recruit.arena_id).size() == 1:
		RunSetup.remember_selection(recruit.arena_id, recruit.identity_id)
		if stage.world.arenas[selected_index].arena_id == recruit.arena_id:
			_select_identity(recruit.identity_id)
	stage.sync_heroes(hero.identity_id if hero != null else -1, _hero_in_focused_arena())
	_update_hud()


func _on_hud_hero_requested(identity: int) -> void:
	if _overworld_menu_open() or intro_locked() or sequence_active:
		return
	if hero != null and identity == hero.identity_id:
		select_hero()
		return
	var requested: ArenicHeroState = RunSetup.hero_for(identity)
	if requested != null:
		select_arena(stage.world.index_for_id(requested.arena_id))
		set_zoomed(true)
		_select_identity(identity)
		_update_hud()


func _hero_effects(health: Dictionary) -> Array[Dictionary]:
	var effects: Array[Dictionary] = []
	for debuff: String in health.get("debuffs", PackedStringArray()):
		# The current combat ledger has untimed debuffs; do not invent an expiry.
		effects.append({"name": debuff, "beneficial": false, "remaining_seconds": -1.0, "stacks": 1})
	var active: Dictionary = combat.active_cast_snapshot(hero)
	if active.get("effect_kind", "") == "aura" and not hero.definition.skills.is_empty():
		effects.append({"name": hero.definition.skills[0].title, "beneficial": true, "remaining_seconds": float(active.get("remaining", 0.0)), "stacks": 1})
	if encounter != null:
		effects.append_array(encounter.actor_effects(hero.arena_id, hero.ally_id()))
	return effects


## Seal actual observed poses before the one canonical reset changes the ledger.
func _on_arena_restarting(arena_id: String, end_tick: int, rewind: bool) -> void:
	if not is_instance_valid(arena_rewind):
		return
	if not rewind or RunSetup.heroes_in(arena_id).is_empty():
		arena_rewind.clear_history(arena_id)
		return
	_sync_boss_placement()
	stage.sync_heroes(hero.identity_id, _hero_in_focused_arena(), _is_ghost, _is_defeated_ghost)
	arena_rewind.capture(arena_id, end_tick)
	arena_rewind.begin(arena_id, end_tick)
	if hero.arena_id == arena_id:
		_hero_input.clear()
		_cast_queued = false # Accepted free casts and held channels pause in place.


## Restore intentionally starts a fresh countdown, without resetting twice or
## reconstructing old gameplay effects from the visual tape.
func _restore_restarts() -> void:
	if not is_instance_valid(arena_rewind) or encounter == null:
		return
	# In-place hydration and stage replacement both discard the old visual tape.
	arena_rewind.configure(stage, combat_presentation)
	for arena_id: String in encounter.arena_ids():
		if encounter.is_restart_pending(arena_id) and RunSetup.heroes_in(arena_id).is_empty():
			# Old saves can contain a cosmetic hold for an empty arena. Its
			# canonical reset already happened; there is nobody to count in.
			encounter.set_restart_pending(arena_id, false)
		if encounter.is_restart_pending(arena_id):
			arena_rewind.begin(arena_id, 0, false)
		else:
			arena_rewind.clear_history(arena_id)
			arena_rewind.capture(arena_id, encounter.cycle_position(arena_id))


func _finish_restarts(finished: Array[String]) -> void:
	for arena_id: String in finished:
		encounter.set_restart_pending(arena_id, false)
		if hero.arena_id == arena_id:
			_hero_input.clear()
	for arena_id: String in encounter.arena_ids():
		if not encounter.is_paused(arena_id):
			arena_rewind.capture(arena_id, encounter.cycle_position(arena_id))
	_update_restart_overlay()


func _update_restart_overlay() -> void:
	if not is_instance_valid(restart_overlay) or not is_instance_valid(arena_rewind) or not is_instance_valid(stage):
		return
	var arena: ArenicArenaDefinition = stage.world.arenas[selected_index]
	var phase: String = arena_rewind.phase(arena.arena_id) if zoomed and not intro_locked() else ""
	restart_overlay.present(phase, arena_rewind.countdown_seconds(arena.arena_id), arena_rewind.display_tick(arena.arena_id), arena.visual_theme)


## Discard only the in-flight take. Never restart, seek, refold, or clear the
## arena's existing performers; its next tick remains the next tick.
func _cancel_active_recording(reason: String) -> void:
	if session.is_idle():
		return
	var owner: ArenicHeroState = RunSetup.hero_for(session.identity)
	var source: String = session.arena_id
	session.clear()
	if modal.is_open() and modal.arena_id == source:
		modal.close()
	_resume_arena(source)
	_publish_recording("discarded", owner, source)
	_cast_notice = reason
	_cast_feedback = "Take discarded"
	_notice_seconds = 3.0


## Covers restored legacy death decisions and relocations outside player input.
## It runs before capture/countdown work as well as after the combat step.
func _reconcile_recording() -> void:
	if session.is_idle():
		return
	var owner: ArenicHeroState = RunSetup.hero_for(session.identity)
	if owner == null:
		_cancel_active_recording("The recording hero is unavailable. The take was discarded.")
	elif combat.ally_defeated_at(owner.arena_id, owner.ally_id()):
		_cancel_active_recording("You died mid-recording. The take was discarded.")
		_respawn_free_hero(owner)
		if owner == hero:
			set_zoomed(true)
	elif owner.arena_id != session.arena_id or stage.world.arenas[selected_index].arena_id != session.arena_id:
		_cancel_active_recording("You left the arena. The take was discarded.")
