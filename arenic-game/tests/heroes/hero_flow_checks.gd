extends SceneTree
## Exercises real viewport input, class handoff and scene ownership without a renderer.
const SHELL_PATH: String = "res://scenes/game/game_shell.tscn"
const RETIRE_AUDIO: GDScript = preload("res://tests/support/audio_retirement.gd")
const CLASSES: Array[String] = ["hunter", "bard", "merchant", "warrior", "cardinal", "alchemist", "forager", "thief"]
var checks: int = 0
var failed: bool = false
var shell: Variant
var setup: Node

class HeldSequence:
	extends ArenicWorldSequence
	func start(world_stage: ArenicOverworldStage) -> void:
		stage = world_stage

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("Hero flow: " + message)

func _run() -> void:
	create_timer(15.0).timeout.connect(func():
		push_error("Hero flow test timed out")
		quit(1))
	var packed_shell := load(SHELL_PATH) as PackedScene
	setup = root.get_node("RunSetup")
	for class_id in CLASSES:
		setup.begin_new_game()
		setup.choose_class(load("res://data/classes/" + class_id + ".tres"))
		shell = packed_shell.instantiate()
		root.add_child(shell)
		await process_frame
		check(shell.hero == setup.get_hero() and shell.hero.definition == setup.selected_class, class_id + " uses the actual chosen class/state")
		check(shell.hero.arena_id == "guild_house" and shell.hero.cell == Vector2i(30, 15), class_id + " spawns in Guild House")
		check(shell.selected_index == 1 and not shell.zoomed, class_id + " begins with Guild House highlighted in overview")
		var view: ArenicHeroView = shell.stage.hero_view
		check(is_instance_valid(view) and view.sprite.sprite_frames == setup.selected_class.world_sprite_frames, class_id + " mounts correct native art")
		check(view.get_parent() == shell.stage.get_arena(1).get_node("ContentSlot"), class_id + " mounts in Guild House content")
		for facing in ["n", "e", "s", "w"]:
			check(view.sprite.sprite_frames.has_animation("idle_" + facing), class_id + " has direction " + facing)
		check(is_equal_approx(view.sprite.pixel_size * 19.0, ArenicGridMath.TILE_SIZE), class_id + " occupies one tile")
		check(view.sprite.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, class_id + " uses nearest sampling")
		if class_id != "thief":
			shell.free()
			await process_frame
	# Keep the final class for interaction/ownership checks.
	press(KEY_TAB)
	check(shell.zoomed and shell.selected_index == 1 and shell.hero.selected, "Tab focuses and selects the hero")
	shell.stage.camera_rig.frame_bounds(ArenicGridMath.arena_rect(Vector2i(1, 0)), false)
	var initial: Vector2i = shell.hero.cell
	press(KEY_RIGHT)
	await physics_frame
	await physics_frame
	check(shell.hero.cell == initial + Vector2i.RIGHT and shell.hero.facing == "e", "Real arrow input moves one tile and turns east")
	check(shell.selected_index == 1, "Movement does not navigate the arena camera")
	var after_step: Vector2i = shell.hero.cell
	press(KEY_RIGHT, true)
	await physics_frame
	await physics_frame
	check(shell.hero.cell == after_step, "Key echo never repeats movement")
	var p: Vector2 = shell.stage.camera_rig.world_to_screen(ArenicGridMath.tile_to_world(Vector2i(1, 0), shell.hero.cell))
	click(p + Vector2(76, 0))
	check(not shell.hero.selected, "Clicking an empty tile deselects")
	press(KEY_LEFT)
	await physics_frame
	await physics_frame
	check(shell.hero.cell == after_step and shell.selected_index == 1, "Deselected hero neither moves nor redirects arrow input to map")
	click(p)
	check(shell.hero.selected, "Clicking the hero tile selects")
	press(KEY_UP)
	press(KEY_RIGHT)
	await physics_frame
	await physics_frame
	check(shell.hero.cell == after_step + Vector2i(1, 1), "Same-tick presses combine into one diagonal")
	var before_cancel: Vector2i = shell.hero.cell
	press(KEY_LEFT)
	press(KEY_RIGHT)
	await physics_frame
	await physics_frame
	check(shell.hero.cell == before_cancel, "Opposite presses cancel")
	# Navigation changes clear pending movement; returning restores position.
	press(KEY_RIGHT)
	press(KEY_B)
	await physics_frame
	await physics_frame
	check(shell.selected_index == 8 and shell.hero.cell == before_cancel, "Arena hotkey clears pending hero intent")
	press(KEY_TAB)
	check(shell.selected_index == 1 and shell.hero.selected, "Tab finds the hero from a different arena")
	var hero: ArenicHeroState = shell.hero
	hero.identity_id = 812
	hero.level = 7
	hero.gain_experience(49)
	var identity_before: Array = [hero.identity_id, hero.display_name(), hero.level, hero.experience, hero.experience_to_next_level]
	var hud: ArenicWorldHUD = shell.hud
	var old_view_id: int = shell.stage.hero_view.get_instance_id()
	shell.replace_stage(shell.stage_scene)
	check(shell.hero == hero and shell.hero.cell == before_cancel, "Stage swap preserves authoritative hero and tile")
	check([shell.hero.identity_id, shell.hero.display_name(), shell.hero.level, shell.hero.experience, shell.hero.experience_to_next_level] == identity_before, "Stage swap preserves stable identity, authored name and progression")
	check(shell.stage.hero_view.get_instance_id() != old_view_id and shell.hud == hud, "Stage swap replaces view but retains HUD")
	# Sequence acquisition cancels queued movement and ignores inputs until released.
	shell.select_hero()
	press(KEY_RIGHT)
	var source := HeldSequence.new()
	var packed := PackedScene.new()
	check(packed.pack(source) == OK, "Sequence test fixture packs")
	source.free()
	shell.play_sequence(packed)
	press(KEY_DOWN)
	await physics_frame
	await physics_frame
	check(shell.hero.cell == before_cancel, "Cinematic ownership suppresses and flushes movement")
	press(KEY_ESCAPE)
	await process_frame
	check(not shell.sequence_active, "Escape releases sequence ownership")
	await physics_frame
	await physics_frame
	check(shell.hero.cell == before_cancel, "No stale movement after cinematic")
	# Exercise a real edge step, reparent and camera follow, then return.
	shell.hero.cell = Vector2i(65, 15)
	shell.stage.sync_heroes(shell.hero.identity_id, true)
	press(KEY_RIGHT)
	await physics_frame
	await physics_frame
	check(shell.hero.arena_id == "sanctum" and shell.hero.cell == Vector2i(0, 15), "Edge input walks into Sanctum at opposite edge")
	check(shell.selected_index == 2 and shell.zoomed, "Focused camera follows the crossing")
	check(shell.stage.hero_view.get_parent() == shell.stage.get_arena(2).get_node("ContentSlot"), "Hero view reparents into destination arena")
	press(KEY_LEFT)
	await physics_frame
	await physics_frame
	check(shell.hero.arena_id == "guild_house" and shell.hero.cell == Vector2i(65, 15), "Return edge input is symmetric")
	# Fixed scale: every tile remains 19 px; selection and sprite use the same center.
	shell.stage.camera_rig.frame_bounds(ArenicGridMath.arena_rect(Vector2i(1, 0)), false)
	var center := ArenicGridMath.tile_to_world(Vector2i(1, 0), shell.hero.cell)
	check(shell.stage.hero_view.global_position.is_equal_approx(center + Vector3(0, 0.025, 0)), "Sprite stays on authoritative tile center")
	var screen: Vector2 = shell.stage.camera_rig.world_to_screen(center)
	check(shell.stage.hero_at_screen(screen) == shell.hero.identity_id, "Projected hero center picks that guild member")
	check(shell.stage.hero_at_screen(Vector2(640, 680)) < 0, "HUD is excluded from hero picking")
	shell.free()
	setup.begin_new_game()
	await process_frame
	# This suite mounts a real shell, so it plays real sound. Godot retires a
	# stopped playback on the mixer thread and releases it on a later main-thread
	# update; exiting before that leaves the streams alive and the run reports a
	# resource leak. Every other shell-mounting suite waits the same way.
	check(await RETIRE_AUDIO.wait_for_mixer(self), "Stopped audio resources retire before test exit")
	print("Hero flow checks: %d assertions, %s." % [checks, "FAILED" if failed else "passed"])
	quit(1 if failed else 0)

func press(key: Key, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	event.echo = echo
	root.push_input(event, true)
	var released := event.duplicate() as InputEventKey
	released.pressed = false
	released.echo = false
	root.push_input(released, true)

func click(position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	root.push_input(event, true)
	var released := event.duplicate() as InputEventMouseButton
	released.pressed = false
	root.push_input(released, true)
