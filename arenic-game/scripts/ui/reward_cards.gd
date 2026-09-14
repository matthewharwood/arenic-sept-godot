class_name ArenicRewardCards
extends Control
## Transient reward presentation. The caller owns offers, awards and clocks.
## A concealed card never exposes its item through labels, tooltips or snapshots.

signal card_chosen(index: int)
signal deferred
signal dismissed

const DISPLAY_FONT: Font = preload("res://assets/fonts/PPMigra-Extrabold.ttf")
const BODY_FONT: Font = preload("res://assets/fonts/Barlow-Regular.ttf")
const PORTRAIT_CUTOUT: Shader = preload("res://scripts/character_creation/portrait_cutout.gdshader")
const CARD_COUNT: int = 3
const REVEAL_STAGGER: float = 0.11
const REVEAL_DURATION: float = 0.26
const FLIP_DURATION: float = 0.34

var _arena: ArenicArenaDefinition
var _theme: ArenicArenaTheme
var _mode: String = ""
var _open: bool = false
var _elapsed: float = 0.0
var _chosen: int = -1
var _flipping: bool = false
var _flip_elapsed: float = 0.0
var _result: Dictionary = {}
var _result_visible: bool = false
var _shade: ColorRect
var _panel: Panel
var _eyebrow: Label
var _title: Label
var _detail: Label
var _footer: Label
var _later: Button
var _continue: Button
var _cards: Array[RewardCard] = []
var _previous_focus: WeakRef


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_force_pass_scroll_events = false
	focus_mode = Control.FOCUS_ALL
	_build()
	resized.connect(_layout)
	_layout()
	hide()
	set_process(false)


func open_heroes(arena: ArenicArenaDefinition, offers: Array[ArenicClassDefinition]) -> void:
	if offers.size() != CARD_COUNT or arena == null or arena.visual_theme == null:
		return
	for offer: ArenicClassDefinition in offers:
		if offer == null:
			return
	_begin(arena, "heroes")
	_title.text = "A new ally"
	_detail.text = "Choose one hero to join your guild."
	_footer.text = "1 / 2 / 3  Choose · Battles continue"
	_later.text = "Later · Esc"
	_later.tooltip_text = "Keep this offer. Press N when you are ready."
	for index: int in CARD_COUNT:
		_cards[index].show_hero(offers[index], index)
	_layout()


func open_loot(arena: ArenicArenaDefinition, cards: Array[Dictionary]) -> void:
	if cards.size() != CARD_COUNT or arena == null or arena.visual_theme == null:
		return
	_begin(arena, "loot")
	_title.text = "Spoils of battle"
	_detail.text = "Three sealed cards. Reveal one piece of equipment."
	_footer.text = "1 / 2 / 3  Reveal · Battles continue"
	_later.text = "Later · Esc"
	_later.tooltip_text = "Keep this reward for later."
	for index: int in CARD_COUNT:
		_cards[index].show_back(arena, index)
	_layout()


## An award must be accepted by the model before this is called. The second
## half of the flip shows that exact result; it never rolls or upgrades an item.
func show_loot_result(index: int, item: Dictionary) -> void:
	if not _open or _mode != "loot" or index < 0 or index >= CARD_COUNT or item.is_empty() or _flipping or _result_visible:
		return
	if _chosen >= 0 and index != _chosen:
		return
	_chosen = index
	_result = item.duplicate(true)
	_flipping = true
	_flip_elapsed = 0.0
	_later.hide()
	for card: RewardCard in _cards:
		card.disabled = true
	_footer.text = "Added to your collection · Battles continue"
	set_process(true)


func close() -> void:
	if not _open:
		return
	_open = false
	_mode = ""
	_chosen = -1
	_result.clear()
	_result_visible = false
	_flipping = false
	hide()
	set_process(false)
	if _previous_focus != null:
		var previous: Control = _previous_focus.get_ref() as Control
		if is_instance_valid(previous) and previous.is_visible_in_tree() and previous.focus_mode != Control.FOCUS_NONE:
			previous.grab_focus()
	_previous_focus = null


func is_open() -> bool:
	return _open


## Shell routes this before its gameplay bindings. Pointer events still need
## to reach the card buttons; the full-screen Control contains them at GUI time.
func consume_input(event: InputEvent) -> bool:
	if not _open:
		return false
	if event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag:
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		if not event.ctrl_pressed and not event.alt_pressed and not event.meta_pressed and not event.shift_pressed:
			var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			if key == KEY_ESCAPE:
				if _result_visible:
					_finish()
				else:
					_defer()
			elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and _result_visible:
				_finish()
			elif key in [KEY_1, KEY_2, KEY_3]:
				_choose(key - KEY_1)
	return true


func snapshot() -> Dictionary:
	var cards: Array[Dictionary] = []
	for index: int in _cards.size():
		var card: RewardCard = _cards[index]
		cards.append({"index": index, "revealed": card.face_up,
			"visible": _open and card.modulate.a > 0.01, "alpha": card.modulate.a,
			"title": card.item_title.text if card.face_up else "Sealed reward",
			"class_id": card.class_id if card.face_up else "",
			"item_id": str(_result.get("id", "")) if _result_visible and index == _chosen else "",
			"rect": _rect(card.get_global_rect()), "center": [card.get_global_rect().get_center().x, card.get_global_rect().get_center().y], "enabled": not card.disabled})
	return {"open": _open, "mode": _mode, "arena_id": _arena.arena_id if _arena != null else "",
		"chosen": _chosen, "result_visible": _result_visible, "cards": cards,
		"panel_rect": _rect(_panel.get_global_rect()) if _panel != null else {},
		"later_rect": _rect(_later.get_global_rect()) if _later != null else {},
		"continue_rect": _rect(_continue.get_global_rect()) if _continue != null else {}}


static func _rect(value: Rect2) -> Dictionary:
	return {"x": value.position.x, "y": value.position.y, "width": value.size.x, "height": value.size.y}


func _begin(arena: ArenicArenaDefinition, mode: String) -> void:
	if not _open:
		var previous: Control = get_viewport().gui_get_focus_owner()
		_previous_focus = weakref(previous) if previous != null else null
	_arena = arena
	_theme = arena.visual_theme
	_mode = mode
	_open = true
	_elapsed = 0.0
	_chosen = -1
	_result.clear()
	_result_visible = false
	_flipping = false
	_eyebrow.text = arena.display_name.to_upper() + (" · RECRUITMENT" if mode == "heroes" else " · ARENA REWARD")
	for card: RewardCard in _cards:
		card.configure(_theme)
		card.scale = Vector2.ONE
		card.modulate.a = 0.0
		card.disabled = true
	_later.show()
	_continue.hide()
	_apply_theme()
	show()
	grab_focus()
	set_process(true)


func _process(delta: float) -> void:
	_elapsed += maxf(0.0, delta)
	for index: int in CARD_COUNT:
		var progress: float = clampf((_elapsed - index * REVEAL_STAGGER) / REVEAL_DURATION, 0.0, 1.0)
		var eased: float = 1.0 - pow(1.0 - progress, 3.0)
		var card: RewardCard = _cards[index]
		card.modulate.a = eased
		card.position.y = card.home_y + (1.0 - eased) * 10.0
		if _chosen < 0:
			card.disabled = _elapsed < REVEAL_DURATION + (CARD_COUNT - 1) * REVEAL_STAGGER
	if _flipping:
		_flip_elapsed += maxf(0.0, delta)
		var progress: float = clampf(_flip_elapsed / FLIP_DURATION, 0.0, 1.0)
		_cards[_chosen].scale.x = maxf(0.015, absf(1.0 - progress * 2.0))
		if progress >= 0.5 and not _result_visible:
			_result_visible = true
			_cards[_chosen].show_item(_result, _chosen)
			_detail.text = "Yours to keep."
			for index: int in CARD_COUNT:
				if index != _chosen:
					_cards[index].modulate.a = 0.38
		if progress >= 1.0:
			_flipping = false
			_continue.show()
			_cards[_chosen].scale.x = 1.0
	if _result_visible:
		for index: int in CARD_COUNT:
			if index != _chosen:
				_cards[index].modulate.a = 0.38
	if not _flipping and _elapsed >= REVEAL_DURATION + (CARD_COUNT - 1) * REVEAL_STAGGER:
		set_process(false)


func _choose(index: int) -> void:
	if not _open or _chosen >= 0 or index < 0 or index >= CARD_COUNT or _cards[index].disabled:
		return
	_chosen = index
	for card: RewardCard in _cards:
		card.disabled = true
	card_chosen.emit(index)


func _defer() -> void:
	if not _open or _flipping:
		return
	close()
	deferred.emit()


func _finish() -> void:
	if not _open or not _result_visible or _flipping:
		return
	close()
	dismissed.emit()


func _gui_input(_event: InputEvent) -> void:
	if _open:
		accept_event()


func _build() -> void:
	_shade = ColorRect.new()
	_shade.name = "Shade"
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = Panel.new()
	_panel.name = "Panel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_eyebrow = _label(_panel, "Arena", BODY_FONT, 11)
	_title = _label(_panel, "Title", DISPLAY_FONT, 32)
	_detail = _label(_panel, "Detail", BODY_FONT, 14)
	_footer = _label(_panel, "KeyboardGuide", BODY_FONT, 12)
	for index: int in CARD_COUNT:
		var card := RewardCard.new()
		card.name = "Card%d" % (index + 1)
		_panel.add_child(card)
		card.pressed.connect(_choose.bind(index))
		_cards.append(card)
	_later = _button("Later", "Later · Esc")
	_later.pressed.connect(_defer)
	_continue = _button("Continue", "Continue · Enter")
	_continue.pressed.connect(_finish)


func _button(node_name: String, text: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_override("font", BODY_FONT)
	button.add_theme_font_size_override("font_size", 13)
	button.mouse_force_pass_scroll_events = false
	_panel.add_child(button)
	return button


static func _label(parent: Control, node_name: String, font: Font, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	parent.add_child(label)
	return label


func _apply_theme() -> void:
	_shade.color = _theme.color("base_300", 0.84)
	var style := StyleBoxFlat.new()
	style.bg_color = _theme.color("base_100")
	style.border_color = _theme.color("base_content", 0.23)
	style.set_border_width_all(1)
	_panel.add_theme_stylebox_override("panel", style)
	_eyebrow.add_theme_color_override("font_color", _theme.color("accent"))
	_title.add_theme_color_override("font_color", _theme.color("base_content"))
	_detail.add_theme_color_override("font_color", _theme.color("base_content", 0.72))
	_footer.add_theme_color_override("font_color", _theme.color("base_content", 0.6))
	for button: Button in [_later, _continue]:
		for state: String in ["normal", "hover", "pressed"]:
			var action := StyleBoxFlat.new()
			action.bg_color = _theme.color("base_200") if state == "normal" else _theme.color("base_300").lerp(_theme.color("accent"), 0.1)
			action.border_color = _theme.color("base_content", 0.3) if state == "normal" else _theme.color("accent")
			action.set_border_width_all(1)
			button.add_theme_stylebox_override(state, action)
			button.add_theme_color_override("font_color" if state == "normal" else "font_%s_color" % state, _theme.color("base_content"))
		button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _layout() -> void:
	if _panel == null:
		return
	var compact: bool = size.y < 500.0 or size.x < 800.0
	var margin: float = 16.0 if compact else 28.0
	_panel.size = Vector2(minf(940.0, maxf(0.0, size.x - margin * 2.0)), minf(542.0, maxf(0.0, size.y - margin * 2.0)))
	_panel.position = (size - _panel.size) * 0.5
	var inset: float = 16.0 if compact else 26.0
	var header: float = 84.0 if compact else 110.0
	var footer: float = 50.0 if compact else 66.0
	_eyebrow.position = Vector2(inset, 12.0 if compact else 20.0)
	_eyebrow.size = Vector2(_panel.size.x - inset * 2.0, 16.0)
	_title.position = Vector2(inset, 30.0 if compact else 42.0)
	_title.size = Vector2(_panel.size.x - inset * 2.0, 30.0 if compact else 40.0)
	_title.add_theme_font_size_override("font_size", 25 if compact else 34)
	_detail.position = Vector2(inset, 61.0 if compact else 84.0)
	_detail.size = Vector2(_panel.size.x - inset * 2.0, 19.0)
	_detail.add_theme_font_size_override("font_size", 12 if compact else 14)
	var gap: float = 10.0 if compact else 18.0
	var card_width: float = (_panel.size.x - inset * 2.0 - gap * 2.0) / CARD_COUNT
	var card_height: float = maxf(120.0, _panel.size.y - header - footer)
	for index: int in _cards.size():
		var card: RewardCard = _cards[index]
		card.position = Vector2(inset + index * (card_width + gap), header)
		card.home_y = header
		card.size = Vector2(card_width, card_height)
		card.pivot_offset = card.size * 0.5
		card.layout(compact)
	_footer.position = Vector2(inset, _panel.size.y - footer + 14.0)
	_footer.size = Vector2(maxf(0.0, _panel.size.x - inset * 2.0 - 152.0), 22.0)
	for button: Button in [_later, _continue]:
		button.position = Vector2(_panel.size.x - inset - 144.0, _panel.size.y - footer + 10.0)
		button.size = Vector2(144.0, 30.0)


class RewardCard extends Button:
	var face_up: bool = false
	var class_id: String = ""
	var home_y: float = 0.0
	var item_title: Label
	var _theme: ArenicArenaTheme
	var _portrait: TextureRect
	var _icon: TextureRect
	var _kind: Label
	var _detail: Label
	var _hotkey: Label
	var _rule: ColorRect
	var _back_label: Label
	var _item_slot: String = ""
	var _rarity_color: Color
	var _compact: bool = false

	func _ready() -> void:
		focus_mode = Control.FOCUS_NONE
		mouse_force_pass_scroll_events = false
		_portrait = TextureRect.new()
		_portrait.name = "Portrait"
		_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		var portrait_material := ShaderMaterial.new()
		portrait_material.shader = ArenicRewardCards.PORTRAIT_CUTOUT
		_portrait.material = portrait_material
		add_child(_portrait)
		_icon = TextureRect.new()
		_icon.name = "ClassIcon"
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		add_child(_icon)
		item_title = ArenicRewardCards._label(self, "Name", DISPLAY_FONT, 23)
		_kind = ArenicRewardCards._label(self, "Kind", BODY_FONT, 12)
		_detail = ArenicRewardCards._label(self, "Description", BODY_FONT, 12)
		_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		_hotkey = ArenicRewardCards._label(self, "Hotkey", BODY_FONT, 12)
		_hotkey.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_back_label = ArenicRewardCards._label(self, "Sealed", BODY_FONT, 12)
		_back_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_rule = ColorRect.new()
		_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_rule)

	func configure(arena_theme: ArenicArenaTheme) -> void:
		_theme = arena_theme
		for state: String in ["normal", "hover", "pressed", "disabled"]:
			var style := StyleBoxFlat.new()
			style.bg_color = _theme.color("base_200")
			style.border_color = _theme.color("base_content", 0.22) if state in ["normal", "disabled"] else _theme.color("accent")
			if state in ["hover", "pressed"]:
				style.bg_color = style.bg_color.lerp(_theme.color("accent"), 0.075)
			style.set_border_width_all(1)
			add_theme_stylebox_override(state, style)
		add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		item_title.add_theme_color_override("font_color", _theme.color("base_content"))
		_kind.add_theme_color_override("font_color", _theme.color("accent"))
		_detail.add_theme_color_override("font_color", _theme.color("base_content", 0.68))
		_hotkey.add_theme_color_override("font_color", _theme.color("accent"))
		_back_label.add_theme_color_override("font_color", _theme.color("base_content", 0.65))
		_rule.color = _theme.color("accent", 0.65)
		_rarity_color = _theme.color("accent")

	func show_hero(hero: ArenicClassDefinition, index: int) -> void:
		face_up = true
		class_id = hero.class_id
		_item_slot = ""
		_portrait.texture = hero.portrait
		_portrait.modulate = Color(1.0, 1.0, 1.0)
		_portrait.show()
		_icon.texture = hero.icon
		_icon.show()
		item_title.autowrap_mode = TextServer.AUTOWRAP_OFF
		item_title.max_lines_visible = 1
		item_title.text = hero.character_name
		_kind.text = hero.display_name.to_upper()
		_detail.text = hero.skills[0].title if not hero.skills.is_empty() else "Ready to join your guild"
		_hotkey.text = "[%d]" % (index + 1)
		_back_label.hide()
		for control: Control in [item_title, _kind, _detail, _rule]:
			control.show()
		tooltip_text = "%s · %s" % [hero.character_name, hero.display_name]
		if not hero.skills.is_empty():
			tooltip_text += "\n" + hero.skills[0].title + ": " + hero.skills[0].description
		queue_redraw()

	func show_back(arena: ArenicArenaDefinition, index: int) -> void:
		face_up = false
		class_id = ""
		_item_slot = ""
		_portrait.texture = arena.boss.portrait if arena.boss != null else null
		_portrait.modulate = Color(1.0, 1.0, 1.0, 0.10)
		_portrait.visible = _portrait.texture != null
		_icon.hide()
		for control: Control in [item_title, _kind, _detail, _rule]:
			control.hide()
		item_title.text = ""
		_kind.text = ""
		_detail.text = ""
		_back_label.text = "SEALED REWARD"
		_back_label.show()
		_hotkey.text = "[%d]" % (index + 1)
		tooltip_text = "Reveal one piece of equipment."
		queue_redraw()

	func show_item(item: Dictionary, index: int) -> void:
		face_up = true
		class_id = ""
		_item_slot = str(item.get("slot", "weapon")).to_lower()
		_portrait.hide()
		_icon.hide()
		_back_label.hide()
		item_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item_title.max_lines_visible = 2
		item_title.text = str(item.get("name", "Equipment"))
		var rarity: String = str(item.get("rarity", "common"))
		_rarity_color = rarity_color(rarity, _theme)
		_kind.text = rarity.to_upper() + " · " + _item_slot.capitalize()
		_kind.add_theme_color_override("font_color", _rarity_color)
		_detail.text = "Power %d" % int(item.get("power", 1))
		_hotkey.text = "YOURS"
		_rule.color = _rarity_color
		for control: Control in [item_title, _kind, _detail, _rule]:
			control.show()
		tooltip_text = "%s\n%s\n%s" % [item_title.text, _kind.text, str(item.get("description", ""))]
		layout(_compact)
		queue_redraw()

	static func rarity_color(rarity: String, arena_theme: ArenicArenaTheme) -> Color:
		var palette: Dictionary = {"common": Vector3(0.68, 0.008, 260.0), "magic": Vector3(0.67, 0.15, 250.0), "rare": Vector3(0.78, 0.15, 88.0), "epic": Vector3(0.68, 0.18, 310.0), "legendary": Vector3(0.74, 0.17, 55.0), "mythic": Vector3(0.69, 0.21, 20.0)}
		var primitive: Vector3 = palette.get(rarity.to_lower(), palette.common)
		if arena_theme.color("base_content").get_luminance() < 0.5:
			primitive.x = 0.48
		var converter := ArenicArenaTheme.new()
		converter.palette = {"rarity": primitive}
		return converter.color("rarity")

	func layout(compact: bool) -> void:
		_compact = compact
		var inset: float = 12.0 if compact else 18.0
		var bottom_height: float = (88.0 if compact else 116.0) if not _item_slot.is_empty() else (66.0 if compact else 88.0)
		_portrait.position = Vector2(inset, 6.0)
		_portrait.size = Vector2(size.x - inset * 2.0, maxf(30.0, size.y - bottom_height - 14.0))
		_icon.position = Vector2(inset, inset)
		_icon.size = Vector2(20.0, 20.0) if compact else Vector2(26.0, 26.0)
		_icon.modulate = _theme.color("accent") if _theme != null else Color.WHITE
		_rule.position = Vector2(inset, size.y - bottom_height)
		_rule.size = Vector2(size.x - inset * 2.0, 1.0)
		_kind.position = Vector2(inset, size.y - bottom_height + 7.0)
		_kind.size = Vector2(size.x - inset * 2.0, 15.0)
		_kind.add_theme_font_size_override("font_size", 10 if compact else 12)
		item_title.position = Vector2(inset, size.y - bottom_height + 23.0)
		item_title.size = Vector2(size.x - inset * 2.0, (40.0 if compact else 62.0) if not _item_slot.is_empty() else (23.0 if compact else 32.0))
		item_title.add_theme_font_size_override("font_size", (16 if compact else 22) if not _item_slot.is_empty() else (18 if compact else 25))
		_detail.position = Vector2(inset, size.y - (20.0 if compact else 29.0))
		_detail.size = Vector2(size.x - inset * 2.0 - 22.0, 17.0)
		_detail.add_theme_font_size_override("font_size", 10 if compact else 12)
		_hotkey.position = Vector2(size.x - inset - 40.0, size.y - 21.0)
		_hotkey.size = Vector2(40.0, 16.0)
		_hotkey.add_theme_font_size_override("font_size", 10 if compact else 12)
		_back_label.position = Vector2(inset, size.y * 0.66)
		_back_label.size = Vector2(size.x - inset * 2.0, 22.0)
		_back_label.add_theme_font_size_override("font_size", 10 if compact else 12)
		queue_redraw()

	func _draw() -> void:
		if _theme == null:
			return
		if not face_up:
			var center := Vector2(size.x * 0.5, size.y * 0.41)
			var extent: float = minf(size.x * 0.19, size.y * 0.14)
			var corners := PackedVector2Array([center + Vector2(0, -extent), center + Vector2(extent, 0), center + Vector2(0, extent), center + Vector2(-extent, 0), center + Vector2(0, -extent)])
			draw_polyline(corners, _theme.color("accent", 0.7), 1.0, true)
			draw_line(center + Vector2(-extent * 0.4, 0), center + Vector2(extent * 0.4, 0), _theme.color("accent"), 1.0, true)
			draw_line(center + Vector2(0, -extent * 0.4), center + Vector2(0, extent * 0.4), _theme.color("accent"), 1.0, true)
		elif not _item_slot.is_empty():
			_draw_equipment()

	func _draw_equipment() -> void:
		# Small code-native inventory glyphs communicate slot; they do not claim
		# authored item artwork or a hidden combat/equipment mechanic.
		var center := Vector2(size.x * 0.5, (size.y - (88.0 if _compact else 116.0)) * 0.5)
		var unit: float = minf(size.x * 0.18, (size.y - 66.0) * 0.23)
		var color: Color = _rarity_color
		var width: float = 2.0
		if _item_slot in ["weapon", "main_hand", "off_hand"]:
			draw_line(center + Vector2(-unit, unit), center + Vector2(unit, -unit), color, width, true)
			draw_line(center + Vector2(-unit * 0.65, 0), center + Vector2(0, unit * 0.65), color, width, true)
			draw_polyline(PackedVector2Array([center + Vector2(unit * 0.3, -unit), center + Vector2(unit, -unit), center + Vector2(unit, -unit * 0.3)]), color, width, true)
		elif _item_slot in ["ring", "accessory", "amulet", "necklace"]:
			draw_arc(center + Vector2(0, unit * 0.2), unit * 0.63, 0.0, TAU, 32, color, width, true)
			draw_polyline(PackedVector2Array([center + Vector2(0, -unit), center + Vector2(unit * 0.35, -unit * 0.65), center + Vector2(0, -unit * 0.3), center + Vector2(-unit * 0.35, -unit * 0.65), center + Vector2(0, -unit)]), color, width, true)
		else:
			var points := PackedVector2Array([Vector2(-0.45, -1), Vector2(-1, -0.5), Vector2(-0.6, 0), Vector2(-0.45, -0.15), Vector2(-0.45, 1), Vector2(0.45, 1), Vector2(0.45, -0.15), Vector2(0.6, 0), Vector2(1, -0.5), Vector2(0.45, -1), Vector2(0, -0.7), Vector2(-0.45, -1)])
			for index: int in points.size():
				points[index] = center + points[index] * unit
			draw_polyline(points, color, width, true)
