class_name ArenicGuildIntroduction
extends Control
## Presentation for a saved seven-step introduction. Timers are intentionally
## transient: reload repeats only the current line's short reading interval.
signal step_requested(step: int)
signal released

const COMPLETE: int = 6
const PORTRAIT_UNDERLAP: float = 64.0
const BODY: Font = preload("res://assets/fonts/Barlow-Regular.ttf")
const DISPLAY: Font = preload("res://assets/fonts/PPMigra-Extrabold.ttf")
const SPACEBAR_PATH: String = "res://assets/icons/controls/spacebar.svg"
@export var definition: ArenicIntroductionDefinition
var step: int = COMPLETE
var elapsed: float = 0.0
var opening: bool = false
var _opening_elapsed: float = 0.0
var _reminder: bool = false
var _shell: ArenicGameShell
var _world_root: Node3D
var _keeper: AnimatedSprite3D
var _gates: Array[AnimatedSprite3D] = []
var _quote: ColorRect
var _quote_text: Label
var _author: Label
var _begin: Button
var _scrim: ColorRect
var _card: ArenicDialogueFrame
var _portrait_clip: Control
var _portrait: TextureRect
var _speaker: Label
var _role: Label
var _line: Label
var _progress: Label
var _next: Button
var _marker: ArenicInteractionMarker
var _keeper_talk: Button
var _chapter: Label
var _palette := ArenicArenaTheme.new()
var _layout_queued: bool = false
var _laying_out: bool = false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_palette.palette = {"paper": Vector3(0.965, 0.008, 80), "paper_edge": Vector3(0.89, 0.027, 82), "ink": Vector3(0.22, 0.02, 300), "violet": Vector3(0.28, 0.042, 302), "gold": Vector3(0.63, 0.09, 78), "gold_light": Vector3(0.84, 0.066, 84), "muted": Vector3(0.48, 0.02, 300), "keycap_tint": Vector3(1.0, 0.0, 0.0)}
	_quote = ColorRect.new()
	_quote.name = "OpeningQuote"
	_quote.color = _palette.color("paper")
	add_child(_quote)
	_quote_text = _label(_quote, "Quote", 34, DISPLAY)
	_quote_text.text = "“" + definition.quote + "”"
	_quote_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quote_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_author = _label(_quote, "Author", 17)
	_author.text = "— " + definition.quote_author
	_author.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_begin = _spacebar_button(_quote, "Begin", "Begin")
	_scrim = ColorRect.new()
	_scrim.name = "DialogueScrim"
	_scrim.color = _palette.color("ink", 0.24)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scrim)
	_card = ArenicDialogueFrame.new()
	_card.name = "Dialogue"
	_card.palette = _palette
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_card)
	_portrait_clip = Control.new()
	_portrait_clip.name = "PortraitClip"
	_portrait_clip.clip_contents = true
	_portrait_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_portrait_clip)
	_portrait = TextureRect.new()
	_portrait.name = "Portrait"
	_portrait.texture = definition.npc.dialogue_portrait if definition.npc.dialogue_portrait != null else definition.npc.portrait
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The cutout overlaps the frame, but its hem is hidden behind the HUD edge.
	# Only the portrait is clipped; dialogue controls keep their own layout.
	_portrait_clip.add_child(_portrait)
	_speaker = _label(_card, "Speaker", 23, DISPLAY)
	_speaker.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speaker.text = definition.npc.display_name
	_speaker.add_theme_color_override("font_color", _palette.color("paper"))
	_role = _label(_card, "Role", 11)
	_role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_role.text = definition.npc.role.to_upper()
	_role.add_theme_color_override("font_color", _palette.color("gold_light"))
	_line = _label(_card, "Line", 24)
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line.add_theme_constant_override("line_spacing", 2)
	_progress = _label(_card, "Progress", 11)
	_progress.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_progress.add_theme_color_override("font_color", _palette.color("muted"))
	_next = _spacebar_button(_card, "Next", "Continue")
	_next.add_theme_font_size_override("font_size", 14)
	_marker = ArenicInteractionMarker.new()
	_marker.name = "NpcMarker"
	_marker.definition = definition.npc.interaction_marker
	_marker.pressed.connect(advance)
	add_child(_marker)
	# Completed NPCs keep pointer conversation on the sprite, without claiming
	# that another quest is waiting to be accepted or turned in.
	_keeper_talk = Button.new()
	_keeper_talk.name = "KeeperTalkTarget"
	_keeper_talk.focus_mode = Control.FOCUS_NONE
	_keeper_talk.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_keeper_talk.tooltip_text = "%s · Space or click to talk" % definition.npc.display_name
	for style: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		_keeper_talk.add_theme_stylebox_override(style, StyleBoxEmpty.new())
	_keeper_talk.pressed.connect(advance)
	_keeper_talk.size = Vector2(32, 32)
	_keeper_talk.visible = false
	add_child(_keeper_talk)
	_chapter = _label(self, "Chapter", 13)
	_chapter.text = "GUILD HOUSE   /   THE FIRST THREAD"
	_chapter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chapter.add_theme_color_override("font_color", _palette.color("gold"))
	resized.connect(_queue_layout)
	theme_changed.connect(_queue_layout)
	for control: Control in [_speaker, _role, _line, _progress, _next, _begin]:
		control.minimum_size_changed.connect(_queue_layout)
		control.theme_changed.connect(_queue_layout)
	definition.changed.connect(_refresh)
	definition.npc.changed.connect(_refresh)
	for beat: ArenicDialogueBeat in definition.dialogue:
		beat.changed.connect(_refresh)
	_refresh()

func bind(shell: ArenicGameShell) -> void:
	_shell = shell
	if not shell.hud.world_rect_changed.is_connected(_queue_layout):
		shell.hud.world_rect_changed.connect(_queue_layout)
	mount_world(shell.stage)
	set_step(RunSetup.intro_step)

func mount_world(stage: ArenicOverworldStage) -> void:
	if is_instance_valid(_world_root):
		_world_root.queue_free()
	_world_root = Node3D.new()
	_world_root.name = "GuildIntroduction"
	stage.get_arena(stage.world.index_for_id(definition.npc.arena_id)).get_node("ContentSlot").add_child(_world_root)
	_keeper = _sprite(definition.npc.sprite_frames, "Keeper")
	if int(definition.npc.sprite_frames.get_frame_texture("idle_s", 0).get_width()) % 2 == 0:
		_keeper.offset = Vector2(0.5, 0.5)
	_keeper.global_position = ArenicGridMath.tile_to_world(Vector2i(1, 0), definition.npc.cell) + Vector3(0, 0.04, 0)
	_keeper.play("idle_s")
	_keeper.animation_finished.connect(func(): _keeper.play("idle_s"))
	_gates.clear()
	# Guild House has three connections into the surrounding eight-arena world.
	# The gate pivot is the passage center; collision remains the shell's rule.
	for gate: Dictionary in [{"cell": Vector2i(1, 15), "turn": PI * 0.5}, {"cell": Vector2i(64, 15), "turn": -PI * 0.5}, {"cell": Vector2i(33, 1), "turn": PI}]:
		var sprite := _sprite(definition.gate_frames, "Gate%d" % _gates.size())
		sprite.offset = Vector2(0, -9)
		sprite.rotate_y(float(gate.turn))
		sprite.global_position = ArenicGridMath.tile_to_world(Vector2i(1, 0), gate.cell) + Vector3(0, 0.045, 0)
		sprite.play("open" if step == COMPLETE else "locked")
		_gates.append(sprite)

func _sprite(frames: SpriteFrames, node_name: String) -> AnimatedSprite3D:
	var sprite := AnimatedSprite3D.new()
	sprite.name = node_name
	sprite.sprite_frames = frames
	sprite.pixel_size = ArenicGridMath.TILE_SIZE / 19.0
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.rotation.x = -PI * 0.5
	_world_root.add_child(sprite)
	return sprite

func set_step(value: int) -> void:
	step = clampi(value, 0, COMPLETE)
	elapsed = 0.0
	opening = false
	_opening_elapsed = 0.0
	_reminder = false
	for gate: AnimatedSprite3D in _gates:
		gate.play("open" if step == COMPLETE else "locked")
	if step == 1 and is_instance_valid(_keeper):
		_keeper.play("beckon_s")
	_refresh()

func is_locked() -> bool:
	return step < COMPLETE

func can_walk() -> bool:
	return step == 1 and not opening

func near_keeper() -> bool:
	return _shell != null and _shell.hero != null and _shell._hero_in_focused_arena() and _shell.hero.arena_id == definition.npc.arena_id and Vector2(_shell.hero.cell).distance_to(Vector2(definition.npc.cell)) <= definition.npc.interaction_radius

func can_talk() -> bool:
	return near_keeper() and _shell.session.is_idle() and not _shell.modal.is_open() and not _shell.encounter.is_ghost(_shell.hero)

func intercept(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo and not event.ctrl_pressed and not event.meta_pressed and not event.alt_pressed:
		if event.keycode in [KEY_SPACE, KEY_ENTER] and (is_locked() or _reminder or (event.keycode == KEY_SPACE and can_talk())):
			advance()
			return true
		if _reminder and event.keycode == KEY_ESCAPE:
			_reminder = false
			_refresh()
			return true
	return false

func advance() -> void:
	if opening:
		return
	if _reminder:
		_reminder = false
		_refresh()
		return
	if step == COMPLETE:
		if can_talk():
			_reminder = true
			_refresh()
		return
	if step == 0:
		if elapsed >= definition.quote_seconds:
			step_requested.emit(1)
	elif step == 1:
		if can_talk():
			step_requested.emit(2)
	elif elapsed >= definition.dialogue[step - 2].min_read_seconds:
		if step < 5:
			step_requested.emit(step + 1)
		else:
			opening = true
			_opening_elapsed = 0.0
			for gate: AnimatedSprite3D in _gates:
				gate.play("opening")
			_refresh()

func _process(delta: float) -> void:
	if _shell == null:
		return
	if _reminder and not can_talk():
		_reminder = false
		_refresh()
	elapsed = minf(elapsed + delta, 60.0)
	if opening:
		_opening_elapsed += delta
		if _opening_elapsed >= definition.unlock_seconds:
			opening = false
			step_requested.emit(COMPLETE)
			released.emit()
	var reading: bool = step >= 2 and step <= 5
	_begin.disabled = elapsed < definition.quote_seconds
	_next.disabled = reading and elapsed < definition.dialogue[step - 2].min_read_seconds
	_update_marker()

func marker_state() -> ArenicInteractionMarker.State:
	if opening or step in [0, COMPLETE]:
		return ArenicInteractionMarker.State.HIDDEN
	if step == 1:
		return ArenicInteractionMarker.State.AVAILABLE
	if step == 5 and elapsed >= definition.dialogue[3].min_read_seconds:
		return ArenicInteractionMarker.State.READY
	return ArenicInteractionMarker.State.ACCEPTED

func _update_marker() -> void:
	_marker.set_state(marker_state())
	if _shell == null or not is_instance_valid(_keeper):
		_marker.visible = false
		_keeper_talk.visible = false
		return
	var camera: Camera3D = _shell.stage.camera_rig.get_node("Camera3D")
	var world_rect: Rect2 = _shell.hud.get_global_transform() * _shell.hud.get_world_rect()
	var present: bool = _shell.zoomed and _shell.stage.world.arenas[_shell.selected_index].arena_id == definition.npc.arena_id and not _shell.sequence_active
	_marker.project_to(_keeper, camera, world_rect, present, step == 1 and can_talk())
	if present and step == COMPLETE and not _reminder and can_talk() and not camera.is_position_behind(_keeper.global_position):
		var point: Vector2 = get_global_transform().affine_inverse() * camera.unproject_position(_keeper.global_position)
		_keeper_talk.position = point - _keeper_talk.size * 0.5
		_keeper_talk.visible = world_rect.encloses(_keeper_talk.get_global_rect())
	else:
		_keeper_talk.visible = false

func _refresh() -> void:
	if not is_node_ready():
		return
	_speaker.text = definition.npc.display_name
	_role.text = definition.npc.role.to_upper()
	_quote.visible = step == 0
	_card.visible = (step >= 2 and step <= 5 and not opening) or _reminder
	_portrait_clip.visible = _card.visible
	_scrim.visible = _card.visible
	_chapter.visible = step > 0 and step < COMPLETE
	_marker.definition = definition.npc.interaction_marker
	_update_marker()
	if _reminder:
		_line.text = "Press R. Move and attack. Press R again, then Commit. Your echo repeats while you guide another hero."
		_progress.text = "THE ART OF RECORDING"
		_next.text = "Back"
		_next.disabled = false
	elif step >= 2 and step <= 5:
		_line.text = definition.dialogue[step - 2].text
		_progress.text = "%02d / 04" % (step - 1)
		_next.text = "Open the doors" if step == 5 else "Continue"
		_next.disabled = elapsed < definition.dialogue[step - 2].min_read_seconds
	_layout()

func snapshot() -> Dictionary:
	return {"step": step, "locked": is_locked(), "opening": opening, "elapsed": elapsed, "near_npc": near_keeper(), "quote_visible": _quote.visible, "dialogue_visible": _card.visible, "line": _line.text, "npc_cell": [definition.npc.cell.x, definition.npc.cell.y], "gate_animations": _gates.map(func(gate: AnimatedSprite3D) -> String: return String(gate.animation)), "begin_center": _point(_begin), "next_center": _point(_next), "marker": _marker.snapshot(), "talk_target_visible": _keeper_talk.visible, "talk_center": _point(_keeper_talk)}

func _layout() -> void:
	if _card == null or _laying_out:
		return
	_laying_out = true
	_layout_queued = false
	_quote.size = size
	_quote_text.position = Vector2((size.x - 900) * 0.5, size.y * 0.32)
	_quote_text.size = Vector2(900, 160)
	_author.position = Vector2((size.x - 500) * 0.5, size.y * 0.32 + 175)
	_author.size = Vector2(500, 30)
	var begin_minimum: Vector2 = _begin.get_combined_minimum_size()
	_begin.size = Vector2(maxf(210.0, begin_minimum.x + 30.0), maxf(44.0, begin_minimum.y + 6.0))
	_begin.position = Vector2((size.x - _begin.size.x) * 0.5, size.y - 98.0 - _begin.size.y)
	# Engine canvas scaling owns output density. At 1280x720 the portrait keeps
	# its authored composition; narrower logical canvases reserve a text column.
	var left: float = (size.x - 1280.0) * 0.5
	var hud_edge: float = maxf(0.0, size.y - ArenicWorldHUD.BOTTOM_HEIGHT)
	if is_instance_valid(_shell) and is_instance_valid(_shell.hud):
		var hud_to_local: Transform2D = get_global_transform().affine_inverse() * _shell.hud.get_global_transform()
		hud_edge = clampf((hud_to_local * Vector2(0.0, _shell.hud.get_world_rect().end.y)).y, 0.0, size.y)
	_scrim.size = Vector2(size.x, hud_edge)
	_portrait_clip.size = Vector2(size.x, hud_edge)
	var portrait_scale: float = minf(1.0, size.x / 1280.0)
	_portrait.size = Vector2(370, 500) * portrait_scale
	_portrait.position = Vector2(maxf(16.0, left + 70.0), hud_edge + PORTRAIT_UNDERLAP * portrait_scale - _portrait.size.y)
	var card_left: float = maxf(24.0, left + 320.0)
	var card_right: float = minf(size.x - 24.0, left + 1200.0)
	var content_left: float = maxf(card_left + 54.0, _portrait.get_rect().end.x + 38.0) - card_left
	var content_width: float = maxf(1.0, card_right - card_left - content_left - 42.0)
	# Natural font width chooses the plate width; Label's own shaping decides
	# wrapped heights, including theme fonts, newlines, spacing and minimums.
	var plate_text_width: float = minf(content_width - 10.0, maxf(_natural_width(_speaker), _natural_width(_role)))
	plate_text_width = maxf(1.0, plate_text_width)
	var speaker_height: float = _measure_label(_speaker, plate_text_width)
	var role_height: float = _measure_label(_role, plate_text_width) if not _role.text.is_empty() else 0.0
	_role.visible = role_height > 0.0
	var role_gap: float = 4.0 if role_height > 0.0 else 0.0
	var plate_height: float = 24.0 + speaker_height + role_gap + role_height
	var plate := Rect2(content_left - 26.0, 13.0 - plate_height, plate_text_width + 52.0, plate_height)
	_card.nameplate_rect = plate
	_speaker.position = plate.position + Vector2(26, 10)
	_role.position = _speaker.position + Vector2(0, speaker_height + role_gap)
	_line.position = Vector2(content_left, 30.0)
	var body_height: float = _measure_label(_line, content_width)
	var footer_top: float = _line.position.y + body_height + 18.0
	var next_minimum: Vector2 = _next.get_combined_minimum_size()
	_next.size = Vector2(maxf(160.0, next_minimum.x + 30.0), maxf(24.0, next_minimum.y + 6.0))
	var progress_width: float = content_width - _next.size.x - 20.0
	var footer_height: float
	if progress_width >= minf(100.0, _natural_width(_progress)):
		var progress_height: float = _measure_label(_progress, progress_width)
		footer_height = maxf(progress_height, _next.size.y)
		_progress.position = Vector2(content_left, footer_top + (footer_height - progress_height) * 0.5)
		_next.position = Vector2(content_left + content_width - _next.size.x, footer_top + (footer_height - _next.size.y) * 0.5)
	else:
		# A narrow column keeps both footer items readable in separate rows.
		var progress_height: float = _measure_label(_progress, content_width)
		_progress.position = Vector2(content_left, footer_top)
		_next.position = Vector2(content_left + maxf(0.0, content_width - _next.size.x), footer_top + progress_height + 10.0)
		footer_height = progress_height + 10.0 + _next.size.y
	_card.size = Vector2(card_right - card_left, footer_top + footer_height + 24.0)
	_card.position = Vector2(card_left, hud_edge - 22.0 - _card.size.y)
	_chapter.position = Vector2((size.x - 560) * 0.5, 58)
	_chapter.size = Vector2(560, 26)
	_laying_out = false

func _queue_layout() -> void:
	if not _laying_out and not _layout_queued and is_node_ready():
		_layout_queued = true
		_apply_queued_layout.call_deferred()

func _apply_queued_layout() -> void:
	if _layout_queued:
		_layout()

func _measure_label(label: Label, width: float) -> float:
	label.size.x = width
	# Setting the wrap width shapes synchronously once the label is in-tree.
	# get_minimum_size() avoids the previous height retained by Control.size.
	var height: float = ceilf(maxf(label.get_minimum_size().y, label.custom_minimum_size.y))
	label.size = Vector2(width, height)
	return height

func _natural_width(label: Label) -> float:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	if label.label_settings != null:
		if label.label_settings.font != null:
			font = label.label_settings.font
		font_size = label.label_settings.font_size
	var paragraph := TextParagraph.new()
	paragraph.add_string(label.text, font, font_size, label.language)
	return ceilf(maxf(paragraph.get_non_wrapped_size().x, label.custom_minimum_size.x))

func _style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _palette.color("paper")
	style.border_color = _palette.color("gold")
	style.set_border_width_all(1)
	return style

func _label(parent: Node, node_name: String, font_size: int, font: Font = BODY) -> Label:
	var label := Label.new()
	label.name = node_name
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", _palette.color("ink"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

## A native Button icon participates in minimum size and disabled/pressed
## styling, and leaves the entire keycap clickable through the same action.
func _spacebar_button(parent: Node, node_name: String, text: String) -> Button:
	var button: Button = _button(parent, node_name, text, advance)
	button.icon = load(SPACEBAR_PATH) as Texture2D
	button.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	button.add_theme_constant_override("h_separation", 12)
	button.tooltip_text = "Press Space or Enter, or click to continue."
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		var style := button.get_theme_stylebox(state) as StyleBoxFlat
		style.content_margin_left = 10.0
		style.content_margin_right = 10.0
		style.content_margin_top = 4.0
		style.content_margin_bottom = 4.0
	# Neutral modulation preserves the two-color icon in every button state.
	for state: String in ["normal", "hover", "pressed", "disabled", "hover_pressed", "focus"]:
		button.add_theme_color_override("icon_" + state + "_color", _palette.color("keycap_tint"))
	return button

func _button(parent: Node, node_name: String, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", BODY)
	button.add_theme_font_size_override("font_size", 15)
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		button.add_theme_stylebox_override(state, _style())
	button.add_theme_color_override("font_color", _palette.color("ink"))
	button.add_theme_color_override("font_hover_color", _palette.color("ink"))
	button.add_theme_color_override("font_pressed_color", _palette.color("gold"))
	button.add_theme_color_override("font_disabled_color", _palette.color("muted"))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _exit_tree() -> void:
	if is_instance_valid(_world_root):
		_world_root.queue_free()


func _point(control: Control) -> Array[float]:
	var center: Vector2 = control.get_global_rect().get_center()
	return [center.x, center.y]
