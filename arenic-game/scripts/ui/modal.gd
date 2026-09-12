class_name ArenicModal
extends Control
## A keyboard-first confirmation. It presents a choice and reports which one was
## made; it decides nothing and changes no game state.
##
## Pausing belongs to the caller, not here. Every flow that opens a modal pauses
## exactly one arena and then resumes, restarts or re-arms it deliberately on the
## way out, so a modal can never leave an arena stopped by accident — and the
## other eight keep playing the whole time.
##
## Exactly one modal exists at a time. The latch makes a decision single-shot:
## a second press landing in the same frame, or after the modal closed, is
## dropped rather than applied twice.

signal chosen(choice: String, context: Dictionary)

const CANCEL: String = "cancel"
const START_RECORDING: String = "start_recording"
const REPLAY_PREVIOUS: String = "replay_previous"
const CONTINUE_WITHOUT: String = "continue_without"
const COMMIT: String = "commit"
const DISCARD: String = "discard"
const DISCARD_AND_WALK: String = "discard_and_walk"
const TAKE_CONTROL: String = "take_control"
const RESTART_ARENA: String = "restart_arena"
## A roll's offers carry their class in the choice itself, so one generic modal
## can present them without a per-option payload.
const RECRUIT_PREFIX: String = "recruit:"

const DISPLAY_FONT: Font = preload("res://assets/fonts/PPMigra-Extrabold.ttf")
const BODY_FONT: Font = preload("res://assets/fonts/Barlow-Regular.ttf")
const PANEL_SIZE: Vector2 = Vector2(452.0, 172.0)
const BUTTON_HEIGHT: float = 30.0
const MAX_OPTIONS: int = 4

var arena_id: String = ""

var _panel: Panel
var _title: Label
var _detail: Label
var _buttons: Array[Button] = []
var _choices: PackedStringArray = PackedStringArray()
var _focused: int = 0
var _open: bool = false
## Cleared the moment a choice is taken, so a mashed key cannot apply twice.
var _latched: bool = false
var _context: Dictionary = {}
var _panel_style: StyleBoxFlat
var _button_styles: Array[StyleBoxFlat] = []
var _content: Color = Color.WHITE
var _accent: Color = Color.WHITE


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	hide()


func is_open() -> bool:
	return _open


func focused_choice() -> String:
	return _choices[_focused] if _focused >= 0 and _focused < _choices.size() else ""


## Presents one decision. `options` is an array of `[label, choice]` pairs, in
## the order they read. Returns false when a modal is already open, so a caller
## that stashes state alongside a modal only does so if one really opened.
func open(owner_arena: String, visual_theme: ArenicArenaTheme, title: String, detail: String, options: Array, default_index: int = 0, context: Dictionary = {}) -> bool:
	if _open or options.is_empty() or options.size() > MAX_OPTIONS:
		return false
	arena_id = owner_arena
	_context = context.duplicate(true)
	_choices = PackedStringArray()
	for index: int in _buttons.size():
		var button: Button = _buttons[index]
		if index < options.size():
			var option: Array = options[index]
			button.text = "%d  %s" % [index + 1, str(option[0])]
			button.visible = true
			_choices.append(str(option[1]))
		else:
			button.visible = false
	_title.text = title
	_detail.text = detail
	_focused = clampi(default_index, 0, _choices.size() - 1)
	_open = true
	_latched = true
	_apply_theme(visual_theme)
	_layout()
	show()
	return true


## Closes without reporting anything. The caller has already decided what the
## arena does next.
func close() -> void:
	_open = false
	_latched = false
	_context.clear()
	hide()


## Takes the choice at `index`. Single-shot: the latch is spent here.
func choose(index: int) -> void:
	if not _open or not _latched or index < 0 or index >= _choices.size():
		return
	var choice: String = _choices[index]
	var context: Dictionary = _context.duplicate(true)
	_latched = false
	_open = false
	hide()
	_context.clear()
	chosen.emit(choice, context)


func _input(event: InputEvent) -> void:
	if not _open or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	match key:
		KEY_LEFT, KEY_UP:
			_move_focus(-1)
		KEY_RIGHT, KEY_DOWN:
			_move_focus(1)
		KEY_ENTER, KEY_KP_ENTER:
			choose(_focused)
		KEY_ESCAPE:
			# Esc is always the safe way out: the cancelling option if the modal
			# carries one, otherwise the last, which is the conventional place.
			var safe: int = _choices.find(CANCEL)
			choose(safe if safe >= 0 else _choices.size() - 1)
		KEY_1, KEY_2, KEY_3, KEY_4:
			choose(key - KEY_1)
		_:
			pass
	# A modal owns the keyboard while it is up; nothing behind it may also act.
	get_viewport().set_input_as_handled()


func _move_focus(step: int) -> void:
	if _choices.is_empty():
		return
	_focused = posmod(_focused + step, _choices.size())
	_apply_focus()


func _build() -> void:
	_panel = Panel.new()
	_panel.name = "Dialog"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel_style = StyleBoxFlat.new()
	_panel_style.set_corner_radius_all(0)
	_panel_style.set_border_width_all(1)
	_panel.add_theme_stylebox_override("panel", _panel_style)
	add_child(_panel)
	_title = _label("Title", DISPLAY_FONT, 21)
	_detail = _label("Detail", BODY_FONT, 12)
	for index: int in MAX_OPTIONS:
		var button := Button.new()
		button.name = "Option%d" % index
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.add_theme_font_override("font", BODY_FONT)
		button.add_theme_font_size_override("font_size", 12)
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var style := StyleBoxFlat.new()
		style.set_corner_radius_all(0)
		style.set_border_width_all(1)
		_button_styles.append(style)
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			button.add_theme_stylebox_override(state, style)
		button.pressed.connect(choose.bind(index))
		_panel.add_child(button)
		_buttons.append(button)


func _label(node_name: String, font: Font, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	_panel.add_child(label)
	return label


## A modal belongs to the arena that opened it, so it wears that arena's colours.
func _apply_theme(visual_theme: ArenicArenaTheme) -> void:
	_content = ArenicHudTokens.color("content", visual_theme)
	_accent = visual_theme.color("primary") if visual_theme != null else _content
	var surface: Color = visual_theme.color("base_300") if visual_theme != null else Color(0.06, 0.07, 0.1)
	_panel_style.bg_color = Color(surface, 0.97)
	_panel_style.border_color = Color(_content, 0.5)
	_title.add_theme_color_override("font_color", _content)
	_detail.add_theme_color_override("font_color", Color(_content, 0.74))
	for style: StyleBoxFlat in _button_styles:
		style.bg_color = Color(_content, 0.06)
		style.border_color = Color(_content, 0.34)
	_apply_focus()


func _apply_focus() -> void:
	for index: int in _buttons.size():
		var style: StyleBoxFlat = _button_styles[index]
		var focused: bool = index == _focused
		style.bg_color = Color(_accent, 0.26) if focused else Color(_content, 0.06)
		style.border_color = _accent if focused else Color(_content, 0.34)
		_buttons[index].add_theme_color_override("font_color", _content)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_layout()


func _layout() -> void:
	if _panel == null:
		return
	var origin := Vector2(roundf((size.x - PANEL_SIZE.x) * 0.5), roundf((size.y - PANEL_SIZE.y) * 0.5))
	_panel.position = origin
	_panel.size = PANEL_SIZE
	_title.position = Vector2(20.0, 18.0)
	_title.size = Vector2(PANEL_SIZE.x - 40.0, 26.0)
	_detail.position = Vector2(20.0, 50.0)
	_detail.size = Vector2(PANEL_SIZE.x - 40.0, 44.0)
	var count: int = maxi(1, _choices.size())
	var gap: float = 8.0
	var usable: float = PANEL_SIZE.x - 40.0 - gap * float(count - 1)
	var width: float = usable / float(count)
	for index: int in _buttons.size():
		if index >= count:
			continue
		_buttons[index].position = Vector2(20.0 + float(index) * (width + gap), PANEL_SIZE.y - BUTTON_HEIGHT - 20.0)
		_buttons[index].size = Vector2(width, BUTTON_HEIGHT)
