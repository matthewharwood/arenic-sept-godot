extends Node
## Disposable driver mounted only by preview-rewards.py. Uses the production
## shell, catalog and reward models; no player slot exists in this application.
var shell: ArenicGameShell
var _last_kind: String = "heroes"

func _ready() -> void:
	set_process_input(false)
	_start.call_deferred()

func _start() -> void:
	var save: Node = get_node("/root/SaveGames")
	if not save.storage_ready:
		await save.initialized
	save.set_process(false)
	var run: Node = get_node("/root/RunSetup")
	run.begin_new_game()
	run.choose_class(ArenicSaveCodec._class_for("hunter"))
	run.intro_step = ArenicSaveCodec.INTRO_COMPLETE
	run.heroes[0].arena_id = "sanctum"
	run.heroes[0].cell = Vector2i(29, 4)
	run.arena_selection.clear()
	run.remember_selection("sanctum", run.heroes[0].identity_id)
	# The minimum normal recruitment threshold supplies the first three cards.
	run.prospected = run.get_recruitment().next_threshold(0)
	get_tree().change_scene_to_file("res://scenes/game/game_shell.tscn")
	await get_tree().scene_changed
	shell = get_tree().current_scene as ArenicGameShell
	# Viewport input traverses the scene tree in reverse. Keep practice hotkeys
	# ahead of the production shell, whose open cards correctly consume input.
	get_parent().move_child(self, get_parent().get_child_count() - 1)
	shell.select_arena(shell.stage.world.index_for_id("sanctum"))
	shell.set_zoomed(true)
	shell.stage.camera_rig.cancel_motion()
	shell._frame(false)
	DisplayServer.window_set_title("Reward practice • F6 Heroes • F7 Loot • F8 Arena theme")
	_show_heroes()
	set_process_input(true)

func _clear_views() -> void:
	shell._defer_reward()
	shell._close_overworld_menu()
	if not shell.session.is_idle():
		shell._cancel_active_recording("Practice switched to reward cards.")
	if shell.modal.is_open():
		var source: String = shell.modal.arena_id
		shell.modal.close()
		shell._resume_arena(source)

func _show_heroes() -> void:
	_clear_views()
	var run: Node = get_node("/root/RunSetup")
	var recruitment: ArenicRecruitmentState = run.get_recruitment()
	if recruitment.rolls_available(shell._total_earnings()) <= 0:
		var threshold: int = recruitment.next_threshold(shell._total_earnings())
		run.prospected += maxi(0, threshold - shell._total_earnings())
	_last_kind = "heroes"
	shell._update_hud()
	shell._open_roll()

func _show_loot(grant: bool = true) -> void:
	_clear_views()
	if grant or shell.loot.pending_count() == 0:
		var source: String = shell.stage.world.arenas[shell.selected_index].arena_id
		if source not in ArenicLootState.ARENAS:
			source = "sanctum"
		# Author a practice completion through the same model API as a natural
		# boundary. The ordinary reset keeps ground and reward serials aligned.
		var cycle: int = shell.encounter.dig_field(source).cycle
		shell.loot.reset_cycle(source, shell.combat.damage_for_arena(source), cycle)
		shell.combat.apply_hazard_damage(source, ArenicCombatState.boss_enemy_id(source), 40)
		shell.loot.observe_cycle_progress(source, shell.combat.damage_for_arena(source), 1, false, 7200)
		shell.loot.complete_cycle(source, shell.combat.damage_for_arena(source), cycle + 1)
		shell.encounter.restart(source, false)
		shell.encounter.set_restart_pending(source, false)
	_last_kind = "loot"
	shell._auto_hero_reward = false
	shell._update_hud()
	shell._open_loot()

func _next_theme() -> void:
	var arena: String = shell.stage.world.arenas[shell.selected_index].arena_id
	var next: int = (ArenicLootState.ARENAS.find(arena) + 1) % ArenicLootState.ARENAS.size()
	_clear_views()
	shell.select_arena(shell.stage.world.index_for_id(ArenicLootState.ARENAS[next]))
	shell.set_zoomed(true)
	shell.stage.camera_rig.cancel_motion()
	shell._frame(false)
	if _last_kind == "loot":
		_show_loot(false)
	else:
		_show_heroes()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or shell == null:
		return
	match event.physical_keycode:
		KEY_F6:
			_show_heroes()
		KEY_F7:
			_show_loot()
		KEY_F8:
			_next_theme()
		_:
			return
	get_viewport().set_input_as_handled()
