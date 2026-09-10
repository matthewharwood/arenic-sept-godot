extends Control
## Isolated visual smoke view. No game scenes, arena rules, or resources are changed.

const CATALOG_PATH: String = "res://data/bosses/catalog.tres"
const DIRECTIONS: PackedStringArray = ["n", "e", "s", "w"]

var _cards: Array[Dictionary] = []
var _direction: int = 1
var _appearance: int = 0
var _paused: bool = false
var _pause_button: Button
var _direction_label: Label


func _ready() -> void:
	# Keep one texture pixel equal to one viewport pixel in this inspection scene.
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var paper_theme := load("res://scenes/title/paper_theme.tres") as Theme
	var ink: Color = paper_theme.get_color("font_color", "Label")
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	var heading := Label.new()
	heading.text = "Boss source review · 114 × 114 native pixels"
	heading.add_theme_color_override("font_color", ink)
	column.add_child(heading)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	column.add_child(controls)
	var turn := Button.new()
	turn.text = "Turn clockwise"
	turn.pressed.connect(_turn)
	controls.add_child(turn)
	var change := Button.new()
	change.text = "Next appearance"
	change.pressed.connect(_next_appearance)
	controls.add_child(change)
	_pause_button = Button.new()
	_pause_button.text = "Pause"
	_pause_button.pressed.connect(_toggle_pause)
	controls.add_child(_pause_button)
	_direction_label = Label.new()
	_direction_label.add_theme_color_override("font_color", ink)
	controls.add_child(_direction_label)
	var catalog := load(CATALOG_PATH) as ArenicBossCatalog
	if catalog == null:
		_show_error(column, "Boss catalog could not load.")
		return
	var errors := catalog.validation_errors()
	if not errors.is_empty():
		_show_error(column, "\n".join(errors))
		return
	var grid := GridContainer.new()
	grid.columns = 4
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	column.add_child(grid)
	for boss in catalog.bosses:
		_add_card(grid, boss)
	var help := Label.new()
	help.add_theme_color_override("font_color", ink)
	help.text = "Right arrow: turn · Up arrow: appearance · Space: pause   |   Pivot 57,57 · appearance only"
	column.add_child(help)
	_refresh()
	print("Boss visual review loaded: 8 native-size AnimatedSprite2D instances.")


func _add_card(grid: GridContainer, boss: ArenicBossDefinition) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var title := Label.new()
	title.text = boss.display_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	var stage := Control.new()
	stage.custom_minimum_size = Vector2(180, 150)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(stage)
	var sprite := AnimatedSprite2D.new()
	sprite.name = boss.boss_id.capitalize() + "Sprite"
	sprite.sprite_frames = boss.sprite_frames
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	sprite.offset = -Vector2(boss.sprite_pivot_px)
	stage.add_child(sprite)
	stage.resized.connect(func() -> void: sprite.position = (stage.size * 0.5).round())
	sprite.position = (stage.size * 0.5).round()
	var caption := Label.new()
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(caption)
	_cards.append({"boss": boss, "sprite": sprite, "caption": caption})


func _refresh() -> void:
	_direction_label.text = "Facing: " + DIRECTIONS[_direction].to_upper()
	for card in _cards:
		var boss: ArenicBossDefinition = card["boss"]
		var state: ArenicBossVisualState = boss.visual_states[_appearance % boss.visual_states.size()]
		var sprite: AnimatedSprite2D = card["sprite"]
		var tag: String = "%s_%s" % [state.tag_prefix, DIRECTIONS[_direction]]
		sprite.play(tag)
		if _paused:
			sprite.pause()
		var caption: Label = card["caption"]
		caption.text = "%s · %s · %d frames" % [state.state_id.capitalize(), DIRECTIONS[_direction].to_upper(), boss.sprite_frames.get_frame_count(tag)]


func _turn() -> void:
	_direction = (_direction + 1) % DIRECTIONS.size()
	_refresh()


func _next_appearance() -> void:
	# The supplied state counts (1, 4, 6) repeat together after twelve presses.
	_appearance = (_appearance + 1) % 12
	_refresh()


func _toggle_pause() -> void:
	_paused = not _paused
	_pause_button.text = "Play" if _paused else "Pause"
	for card in _cards:
		var sprite: AnimatedSprite2D = card["sprite"]
		if _paused:
			sprite.pause()
		else:
			sprite.play()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_RIGHT:
			_turn()
		KEY_UP:
			_next_appearance()
		KEY_SPACE:
			_toggle_pause()
		_:
			return
	get_viewport().set_input_as_handled()


func _show_error(parent: Control, message: String) -> void:
	var error := Label.new()
	error.text = message
	error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(error)
	push_error(message)
