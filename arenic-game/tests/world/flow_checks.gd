extends SceneTree
## Run only after the visible game stops: Godot --headless --path <project> --script <this file>.
## Uses existing scenes/resources. No fixtures are saved and no project data is changed.

const SHELL_PATH: String = "res://scenes/game/game_shell.tscn"
const BARD_PATH: String = "res://data/classes/bard.tres"
const TIMEOUT_SECONDS: float = 5.0
const TOP_DOWN: Vector3 = Vector3(-PI * 0.5, 0.0, 0.0)

class HeldSequence:
	extends ArenicWorldSequence
	var started_inside_tree: bool = false
	var cancel_count: int = 0

	func start(world_stage: ArenicOverworldStage) -> void:
		stage = world_stage
		started_inside_tree = is_inside_tree()
		stage.camera_rig.rotation = Vector3(-0.9, 0.2, 0.1)

	func cancel() -> void:
		cancel_count += 1
		finish()

var _shell: Variant
var _run_setup: Node
var _saved_class: Resource
var _watchdog: Timer
var _retired_stages: Array[Node] = []
var _checks: int = 0
var _finished_count: int = 0
var _done: bool = false
var _started_ms: int = 0


func _initialize() -> void:
	_started_ms = Time.get_ticks_msec()
	_run.call_deferred()


func _run() -> void:
	_watchdog = Timer.new()
	_watchdog.one_shot = true
	_watchdog.wait_time = TIMEOUT_SECONDS
	_watchdog.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_watchdog)
	_watchdog.timeout.connect(_on_timeout)
	_watchdog.start()
	_run_setup = root.get_node_or_null("RunSetup")
	if not _check(_run_setup != null, "RunSetup autoload is present."):
		return
	_saved_class = _run_setup.get("selected_class") as Resource
	_run_setup.call("begin_new_game")
	_run_setup.set("intro_step", 6) # This fixture tests established navigation.
	var packed: PackedScene = load(SHELL_PATH) as PackedScene
	if not _check(packed != null, "GameShell scene loads."):
		return
	var instance: Node = packed.instantiate()
	if not _check(instance != null, "GameShell scene instantiates."):
		return
	if not _check(instance.get_script() != null and instance.get_script().get_global_name() == "ArenicGameShell", "GameShell uses ArenicGameShell."):
		instance.free()
		return
	_shell = instance
	root.add_child(_shell)
	await process_frame
	await process_frame
	if _done:
		return
	if not _check(is_instance_valid(_shell.stage), "Shell instantiates an overworld stage."):
		return
	if not _check(is_instance_valid(_shell.hud), "Shell has a native HUD instance."):
		return
	if not _check(_shell.selected_index == 1 and _shell.stage.selected_index == 1, "Direct scene launch starts the default Hunter in Guild House."):
		return
	if not _check_world(_shell.stage):
		return
	var hud_id: int = _shell.hud.get_instance_id()
	for index in range(9):
		_shell.select_arena(index)
		var bounds: Rect2 = ArenicGridMath.arena_rect(_shell.stage.world.arenas[index].grid_slot)
		_shell.stage.camera_rig.frame_bounds(bounds, false)
		if not _check(_shell.selected_index == index and _shell.stage.selected_index == index, "Selection reaches arena %d." % index):
			return
		var center: Vector2 = bounds.get_center()
		if not _check(_shell.stage.camera_rig.focus_world.is_equal_approx(Vector3(center.x, 0.0, center.y)), "Camera endpoint centers arena %d." % index):
			return
		if not _check(_shell.stage.camera_rig.view_span.is_equal_approx(bounds.size), "Camera endpoint frames arena %d." % index):
			return
	if not _check_double_click():
		return
	var old_stage: ArenicOverworldStage = _shell.stage
	var old_stage_id: int = old_stage.get_instance_id()
	_retired_stages.append(old_stage)
	_shell.replace_stage(_shell.stage_scene)
	if not _check(_shell.stage.get_instance_id() != old_stage_id, "Stage replacement creates a different stage."):
		return
	if not _check(_shell.hud.get_instance_id() == hud_id, "Stage replacement preserves the HUD instance."):
		return
	await process_frame
	if _done:
		return
	if not _check(not is_instance_valid(old_stage), "Retired stage is freed after replacement."):
		return
	var bard: Resource = load(BARD_PATH)
	if not _check(bard != null, "Existing Bard class resource loads."):
		return
	_run_setup.call("choose_class", bard)
	_retired_stages.append(_shell.stage)
	_shell.replace_stage(_shell.stage_scene)
	if not _check(_shell.selected_index == 1 and _shell.stage.selected_index == 1, "Bard choice starts in Guild House/index 1 after replacement."):
		return
	if not _check(_shell.hud.get_instance_id() == hud_id, "Bard stage replacement also preserves the HUD."):
		return
	if not _check_world(_shell.stage):
		return
	if not _check_sequence_boundary():
		return
	await process_frame
	if _done:
		return
	if not _check(_shell.stage.get_node("SequenceSlot").get_child_count() == 0, "Finished sequence is removed from the stage."):
		return
	_finish(0, "Flow checks passed: %d assertions." % _checks)


func _check_world(stage: ArenicOverworldStage) -> bool:
	if not _check(stage.world != null and stage.world.arenas.size() == 9, "World has nine arena resources."):
		return false
	if not _check(stage.world.validation_errors().is_empty(), "World resource validation succeeds."):
		return false
	if not _check(stage.get_node("Arenas").get_child_count() == 9, "Stage contains nine native arena nodes."):
		return false
	for index in range(9):
		var arena: ArenicArenaView = stage.get_arena(index)
		if not _check(is_instance_valid(arena) and arena is Node3D, "Arena %d is a native ArenicArenaView." % index):
			return false
		if not _check(arena.definition != null and arena.definition.arena_id == stage.world.arenas[index].arena_id, "Arena %d matches its ordered resource." % index):
			return false
	var camera: Camera3D = stage.camera_rig.get_node("Camera3D") as Camera3D
	return _check(camera != null and camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "Rig uses a native orthographic Camera3D.")


func _check_double_click() -> bool:
	_shell.set_zoomed(false)
	_shell.stage.camera_rig.frame_bounds(ArenicGridMath.world_rect(), false)
	var target_index: int = 4
	var slot: Vector2i = _shell.stage.world.arenas[target_index].grid_slot
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.double_click = true
	click.position = _shell.stage.camera_rig.world_to_screen(ArenicGridMath.arena_center(slot))
	if not _check(click.position.is_finite(), "Double-click target projects into the viewport."):
		return false
	_shell._unhandled_input(click)
	return _check(_shell.selected_index == target_index and _shell.zoomed, "Double-click selects Bastion and zooms in.")


func _check_sequence_boundary() -> bool:
	var source := HeldSequence.new()
	var packed := PackedScene.new()
	var pack_error: Error = packed.pack(source)
	source.free()
	if not _check(pack_error == OK, "Held sequence packs in memory."):
		return false
	var probe: Node = packed.instantiate()
	var supports_inner_class: bool = probe is HeldSequence and probe is ArenicWorldSequence
	if is_instance_valid(probe):
		probe.free()
	if not _check(supports_inner_class, "Packed scene preserves the held sequence type."):
		return false
	var rig: ArenicCameraRig = _shell.stage.camera_rig
	var selected_before: int = _shell.selected_index
	var zoomed_before: bool = _shell.zoomed
	_shell.play_sequence(packed)
	if not _check(_shell.sequence_active and rig.sequence_owned, "Held sequence acquires exclusive camera ownership."):
		return false
	if not _check(_shell.stage.get_node("SequenceSlot").get_child_count() == 1, "Held sequence is attached to SequenceSlot."):
		return false
	var sequence: HeldSequence = _shell.stage.get_node("SequenceSlot").get_child(0) as HeldSequence
	if not _check(sequence != null and sequence.stage == _shell.stage and sequence.started_inside_tree, "Sequence starts after add_child and receives the active stage."):
		return false
	sequence.finished.connect(_on_held_finished)
	var focus_before: Vector3 = rig.focus_world
	var span_before: Vector2 = rig.view_span
	_shell.select_arena(0)
	_shell.toggle_view()
	rig.frame_bounds(ArenicGridMath.arena_rect(Vector2i.ZERO), false)
	if not _check(_shell.selected_index == selected_before and _shell.zoomed == zoomed_before, "Normal select/toggle calls yield to the sequence."):
		return false
	if not _check(rig.focus_world.is_equal_approx(focus_before) and rig.view_span.is_equal_approx(span_before), "Normal camera framing yields to the sequence."):
		return false
	if not _check(not rig.rotation.is_equal_approx(TOP_DOWN), "Held sequence changes camera orientation."):
		return false
	sequence.cancel()
	if not _check(sequence.cancel_count == 1 and _finished_count == 1, "Cancel calls finish and emits finished once."):
		return false
	if not _check(not _shell.sequence_active and not rig.sequence_owned, "Sequence cancellation returns camera ownership."):
		return false
	return _check(rig.rotation.is_equal_approx(TOP_DOWN), "Cancellation restores the top-down camera rotation.")


func _on_held_finished() -> void:
	_finished_count += 1


func _check(condition: bool, message: String) -> bool:
	if _done:
		return false
	_checks += 1
	if Time.get_ticks_msec() - _started_ms >= int(TIMEOUT_SECONDS * 1000.0):
		_on_timeout()
		return false
	if not condition:
		_finish(1, "Flow assertion failed: " + message)
		return false
	return true


func _on_timeout() -> void:
	_finish(1, "Flow checks exceeded the five-second watchdog.")


func _finish(code: int, message: String) -> void:
	if _done:
		return
	_done = true
	_watchdog.stop()
	_cleanup.call_deferred(code, message)


func _cleanup(code: int, message: String) -> void:
	if is_instance_valid(_shell):
		_shell.free()
	for retired in _retired_stages:
		if is_instance_valid(retired):
			retired.free()
	_retired_stages.clear()
	if is_instance_valid(_run_setup):
		_run_setup.set("selected_class", _saved_class)
	if is_instance_valid(_watchdog):
		_watchdog.free()
	# AudioServer retires stopped looping playbacks on the audio thread.
	# Give it a mixer tick before terminating this short scene-flow test.
	await create_timer(0.10).timeout
	# Complete main-loop cleanup even if one slow frame consumed the timer.
	await process_frame
	await process_frame
	print(message)
	quit(code)
