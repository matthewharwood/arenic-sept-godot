extends SceneTree
const RETIRE_AUDIO: GDScript = preload("res://tests/support/audio_retirement.gd")
var checks: int = 0
var failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("Introduction: " + message)

func key(shell: Variant, code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	shell._unhandled_input(event)

func _run() -> void:
	create_timer(40).timeout.connect(func(): quit(1))
	var saves: Node = root.get_node("SaveGames")
	if not saves.storage_ready:
		await saves.initialized
	saves.active_slot = -1
	var run: Node = root.get_node("RunSetup")
	run.begin_new_game()
	run.choose_class(load("res://data/classes/thief.tres"))
	var shell: Variant = load("res://scenes/game/game_shell.tscn").instantiate()
	root.add_child(shell)
	shell.set_physics_process(false)
	shell.introduction.set_process(false)
	var intro: Variant = shell.introduction
	check(intro.definition.validation_errors().is_empty(), "Authored NPC, text and gate resources validate")
	check(shell.hero.definition.class_id == "thief" and shell.hero.cell == Vector2i(33, 15), "Selected founder appears at the center")
	check(shell.zoomed and shell.selected_index == 1 and intro.step == 0, "New game begins in close Guild House view with opening quote")
	check(intro.snapshot().quote_visible, "Jung quote is the first visible layer")
	check(intro.snapshot().marker.state == "hidden" and not intro.snapshot().marker.visible, "Quote has no overhead quest marker")
	for code: Key in [KEY_P, KEY_L, KEY_BRACKETRIGHT, KEY_R, KEY_1, KEY_ESCAPE]:
		key(shell, code)
	check(shell.selected_index == 1 and shell.zoomed and shell.session.is_idle() and not shell._cast_queued, "Quote blocks navigation, recording, attacks and Escape bypass")
	shell.paginate_arena(0)
	shell.set_zoomed(false)
	shell._queue_cast()
	check(shell.selected_index == 1 and shell.zoomed and not shell._cast_queued, "Direct HUD actions cannot bypass the lock")
	intro.advance()
	check(run.intro_step == 0, "Opening cannot be skipped before its reading interval")
	intro._process(2.0)
	intro.advance()
	check(run.intro_step == 1 and not intro.snapshot().quote_visible and intro.can_talk(), "Quote advances once to the nearby Keeper")
	check(intro.snapshot().marker.state == "available" and intro.snapshot().marker.glyph == "!", "Keeper offers the lesson with a plain available exclamation mark")
	check(intro.get_node_or_null("NpcBubble") == null and intro._marker.size == Vector2(36, 44), "Overhead prompt is compact and has no text container")
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(640, 300)
	shell._unhandled_input(motion)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(640, 300)
	shell._unhandled_input(click)
	check(run.intro_step == 1, "Pointer motion and floor clicks cannot enter keyboard movement adapter")
	key(shell, KEY_LEFT)
	shell._physics_process(1.0 / 60.0)
	check(shell.hero.cell == Vector2i(32, 15) and ArenicSaveCodec.validate(ArenicSaveCodec.capture_run(run, shell)).is_empty(), "Walking before dialogue keeps hero and saved combat coordinates coherent")
	for cell: Vector2i in [Vector2i(0, 15), Vector2i(65, 15), Vector2i(33, 0)]:
		shell.hero.cell = cell
		var code: Key = KEY_LEFT if cell.x == 0 else (KEY_RIGHT if cell.x == 65 else KEY_DOWN)
		key(shell, code)
		shell._physics_process(1.0 / 60.0)
		check(shell.hero.arena_id == "guild_house" and shell.hero.cell == cell, "Every Guild House seam remains sealed")
	shell.hero.cell = Vector2i(33, 15)
	key(shell, KEY_SPACE)
	check(run.intro_step == 2 and not shell._space_held and not shell._cast_queued, "Space opens dialogue without leaking an attack")
	check(intro.snapshot().marker.state == "accepted" and intro.snapshot().marker.glyph == "?", "Accepting the lesson changes the marker to an in-progress question mark")
	await _dialogue_layout_checks(intro.definition)
	for step: int in range(2, 6):
		intro.advance()
		check(run.intro_step == step and not intro.opening, "Click spamming cannot skip a dialogue beat")
		intro._process(2.75)
		check(intro.snapshot().marker.state == ("ready" if step == 5 else "accepted"), "Only the fully read final beat is ready to finish")
		intro.advance()
		check(run.intro_step == step + 1 if step < 5 else intro.opening, "Each timed beat advances exactly once")
	check(run.intro_step == 5 and intro.opening and shell.intro_locked(), "Final line starts gates before granting passage")
	check(intro.snapshot().marker.state == "hidden", "Gate opening removes the completed interaction marker")
	for gate: String in intro.snapshot().gate_animations:
		check(gate == "opening", "Each exit plays its native opening animation")
	intro._process(1.39)
	check(shell.intro_locked(), "Exits remain locked during animation")
	intro._process(0.02)
	check(run.intro_step == 6 and not shell.intro_locked(), "Completed animation unlocks all routes")
	check(intro.snapshot().marker.state == "hidden" and intro.snapshot().talk_target_visible, "Completed Keeper retains pointer advice on his sprite without a false quest offer")
	intro._keeper_talk.pressed.emit()
	check(intro.snapshot().dialogue_visible and intro.snapshot().marker.state == "hidden", "Pointer advice opens the existing dialogue without reopening the quest")
	intro.advance()
	for gate: String in intro.snapshot().gate_animations:
		check(gate == "open", "Open gate is the stable final pose")
	check(shell.activity_feed.entries[-1].text.contains("doors are open"), "Unlock publishes a real activity notice")
	key(shell, KEY_L)
	check(shell.selected_index == 0, "Arena navigation is released")
	key(shell, KEY_SPACE)
	check(not intro.snapshot().dialogue_visible and not intro.can_talk(), "Keeper cannot be talked to from another focused arena")
	key(shell, KEY_G)
	key(shell, KEY_R)
	check(shell.session.is_counting_down(), "Actual recording is available after the lesson")
	shell.session.clear()
	root.remove_child(shell)
	shell.free()
	await RETIRE_AUDIO.wait_for_mixer(self)
	var resumed: Variant = load("res://scenes/game/game_shell.tscn").instantiate()
	root.add_child(resumed)
	check(resumed.introduction.step == 6 and not resumed.introduction.snapshot().quote_visible, "Completed introduction never replays on a new shell")
	root.remove_child(resumed)
	resumed.free()
	await RETIRE_AUDIO.wait_for_mixer(self)
	run.begin_new_game()
	print("Introduction checks: %d assertions, %s." % [checks, "FAILED" if failed else "passed"])
	quit(1 if failed else 0)

func _dialogue_layout_checks(source: Variant) -> void:
	# A separate presentation and resource copy leave the timed live lesson and
	# authored data untouched while exercising Inspector-style content edits.
	var view: Variant = load("res://scripts/intro/guild_introduction.gd").new()
	view.definition = source.duplicate(true)
	root.add_child(view)
	view.set_process(false)
	view.set_step(2)
	await process_frame
	_check_dialogue_rects(view, "current text")
	var current_height: float = view._card.size.y
	view.definition.dialogue[0].text = "The doors remember every footstep, and every thread carries a story through the quiet halls. ".repeat(4).substr(0, 256)
	view.definition.dialogue[0].emit_changed()
	await process_frame
	check(view._line.text.length() == 256 and view._card.size.y > current_height, "A full 256-character beat grows the panel from shaped lines")
	_check_dialogue_rects(view, "long text")
	var long_height: float = view._card.size.y
	view.definition.dialogue[0].text = "Wait."
	view.definition.dialogue[0].emit_changed()
	await process_frame
	check(view._card.size.y < long_height, "A shorter replacement shrinks the panel")
	var short_height: float = view._card.size.y
	view.definition.dialogue[0].text = "Wait.\n\nListen.\nThe doors remember."
	view.definition.dialogue[0].emit_changed()
	await process_frame
	check(view._line.get_line_count() == 4 and view._card.size.y > short_height, "Explicit newlines and blank paragraphs retain their measured space")
	_check_dialogue_rects(view, "multiline text")
	var short_plate: Vector2 = view._card.nameplate_rect.size
	view.definition.npc.display_name = "The Keeper of Every Forgotten Thread and Every Unspoken Promise"
	view.definition.npc.role = "Caretaker of the eight ancient houses, their quiet halls, and the stories they remember"
	view.definition.npc.emit_changed()
	await process_frame
	check(view._speaker.text == view.definition.npc.display_name and view._role.text == view.definition.npc.role.to_upper() and view._card.nameplate_rect.size.y > short_plate.y, "Changed NPC names and roles resize and wrap their shared plate")
	_check_dialogue_rects(view, "long name and role")
	view.size = Vector2(640, 720)
	await process_frame
	_check_dialogue_rects(view, "narrow canvas")
	check(view._card.get_global_rect().position.y + view._card.nameplate_rect.position.y >= 0.0, "Narrow layout keeps the long nameplate on the canvas")
	view.definition.dialogue[0].text = "The doors remember every footstep, and every thread carries a story through the quiet halls. ".repeat(4).substr(0, 256)
	view.definition.dialogue[0].emit_changed()
	await process_frame
	_check_dialogue_rects(view, "narrow long text")
	view.size = Vector2(1280, 720)
	view.definition.dialogue[0].text = "Wait.\nListen."
	view.definition.dialogue[0].emit_changed()
	await process_frame
	var original_height: float = view._line.size.y
	view._line.add_theme_font_size_override("font_size", 34)
	await process_frame
	check(view._line.size.y > original_height, "Font/theme changes remeasure the body without advancing a dialogue step")
	_check_dialogue_rects(view, "larger font")
	view._line.custom_minimum_size.y = view._line.size.y + 40.0
	await process_frame
	check(view._line.size.y >= view._line.custom_minimum_size.y, "Changed control minimum height moves the footer and frame")
	_check_dialogue_rects(view, "custom minimum")
	await process_frame
	check(not view._layout_queued, "Layout settles after changes instead of scheduling work every frame")
	root.remove_child(view)
	view.free()

func _check_dialogue_rects(view: Variant, scenario: String) -> void:
	var frame := Rect2(Vector2.ZERO, view._card.size)
	var plate: Rect2 = view._card.nameplate_rect
	var body: Rect2 = view._line.get_rect()
	var progress: Rect2 = view._progress.get_rect()
	var next: Rect2 = view._next.get_rect()
	check(frame.encloses(body) and frame.encloses(progress) and frame.encloses(next), "%s: body and footer stay inside the frame" % scenario)
	check(not body.intersects(progress) and not body.intersects(next) and not progress.intersects(next) and body.end.y + 17.0 <= minf(progress.position.y, next.position.y), "%s: body and footer have separate padded rows" % scenario)
	check(plate.encloses(view._speaker.get_rect()) and plate.encloses(view._role.get_rect()) and not view._speaker.get_rect().intersects(view._role.get_rect()) and not plate.intersects(body), "%s: name and role fit their plate without overlapping each other or the body" % scenario)
	var clear_of_portrait: bool = true
	for rect: Rect2 in [body, progress, next, plate]:
		clear_of_portrait = clear_of_portrait and not Rect2(view._card.position + rect.position, rect.size).intersects(view._portrait.get_rect())
	check(clear_of_portrait and view._card.get_rect().end.y <= view.size.y - 118.0, "%s: portrait and lower HUD leave the text clear" % scenario)
	var all_lines_fit: bool = true
	for label: Label in [view._speaker, view._role, view._line, view._progress]:
		all_lines_fit = all_lines_fit and label.size.y >= label.get_minimum_size().y and label.get_visible_line_count() == label.get_line_count()
	check(all_lines_fit, "%s: all shaped lines are visible at their actual font metrics" % scenario)
