extends Node
## Disposable practice driver. Added as an autoload only by preview-cardinal.py;
## the exporter excludes this entire directory. Never opens a production save.
var shell: ArenicGameShell
var _paused: bool = false
var _capture_dir: String = ""
var _initial_tick: int = 0

func _ready() -> void:
	set_process_input(false)
	_start.call_deferred()

func _start() -> void:
	var save: Node = get_node("/root/SaveGames")
	if not save.storage_ready:
		await save.initialized
	save.set_process(false)
	var run: Node = get_node("/root/RunSetup")
	var class_id: String = "hunter"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--cardinal-class="):
			class_id = arg.trim_prefix("--cardinal-class=")
		elif arg.begins_with("--cardinal-tick="):
			_initial_tick = clampi(int(arg.trim_prefix("--cardinal-tick=")), 0, 7199)
		elif arg.begins_with("--cardinal-capture="):
			_capture_dir = arg.trim_prefix("--cardinal-capture=")
	run.begin_new_game()
	run.choose_class(ArenicSaveCodec._class_for(class_id))
	run.intro_step = 6
	run.heroes[0].arena_id = "sanctum"
	run.heroes[0].cell = Vector2i(29, 4)
	run.arena_selection.clear()
	run.remember_selection("sanctum", run.heroes[0].identity_id)
	get_tree().change_scene_to_file("res://scenes/game/game_shell.tscn")
	await get_tree().scene_changed
	shell = get_tree().current_scene as ArenicGameShell
	shell.select_arena(shell.stage.world.index_for_id("sanctum"))
	shell.set_zoomed(true)
	shell.stage.camera_rig.cancel_motion()
	shell._frame(false)
	_restart(_initial_tick)
	set_process_input(true)
	if not _capture_dir.is_empty():
		_capture.call_deferred()

func _restart(tick: int = 0) -> void:
	shell._close_overworld_menu()
	shell.modal.close()
	shell.session.clear()
	shell.encounter.unfold_ghost(shell.hero)
	shell.hero.arena_id = "sanctum"
	shell.hero.cell = Vector2i(29, 4)
	shell.combat.respawn_hero_ally(shell.hero)
	shell.encounter.restart("sanctum", false)
	shell.encounter.set_restart_pending("sanctum", false)
	shell.encounter.set_paused("sanctum", false)
	shell.encounter.seek("sanctum", tick)
	shell._select_identity(shell.hero.identity_id)
	shell.select_arena(shell.stage.world.index_for_id("sanctum"))
	shell.set_zoomed(true)
	shell._frame(false)
	shell._sync_boss_placement()
	shell._update_hud()

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or shell == null:
		return
	match event.physical_keycode:
		KEY_F6:
			var current: int = shell.encounter.cycle_position("sanctum")
			var target: int = 7200
			for note: ArenicScoreEvent in ArenicContentIdentity.SCORE.events:
				if note.cue_tick > current:
					target = mini(target, note.cue_tick)
			_restart(target if target < 7200 else 0)
		KEY_F7:
			_restart()
		KEY_F8:
			_paused = not _paused
			shell.set_physics_process(not _paused)
		_:
			return
	get_viewport().set_input_as_handled()

func _capture() -> void:
	shell.set_physics_process(false)
	for tick: int in [330, 2190 - 60, 3210, 6510, 6900]:
		_restart(tick)
		for frame: int in 8:
			await RenderingServer.frame_post_draw
		var picture: Image = get_viewport().get_texture().get_image()
		picture.save_png(_capture_dir.path_join("cardinal-%d.png" % tick))
	get_tree().quit()
