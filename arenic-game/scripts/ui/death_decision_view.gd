class_name ArenicDeathDecisionView
extends RefCounted
## Presentation is derived from the saved modal choices; it owns no gameplay.

static func red() -> Color:
	var theme := ArenicArenaTheme.new()
	theme.palette = {"loss": Vector3(0.61, 0.215, 20.0)}
	return theme.color("loss")


static func apply_theme(modal: ArenicModal) -> void:
	modal._content = ArenicHudTokens.color("selected_content")
	modal._accent = red()
	modal._panel_style.bg_color = modal._accent
	modal._panel_style.border_color = modal._accent
	modal._title.add_theme_color_override("font_color", modal._content)
	modal._buttons[0].text = "Commit\nRecording\n1"
	modal._buttons[1].text = "Give Up,\nReturn to Guild House\n2"


static func apply_focus(modal: ArenicModal) -> void:
	for index: int in modal._buttons.size():
		var style: StyleBoxFlat = modal._button_styles[index]
		style.set_corner_radius_all(9)
		style.bg_color = modal._content
		style.border_color = ArenicHudTokens.color("map_active")
		style.set_border_width_all(2 if index == modal._focused else 1)
		modal._buttons[index].add_theme_color_override("font_color", modal._accent)


static func layout(modal: ArenicModal) -> void:
	var scale: float = minf(modal.size.x / 1280.0, modal.size.y / 720.0)
	var extent: Vector2 = Vector2(1280, 720) * scale
	var origin: Vector2 = (modal.size - extent) * 0.5
	modal._panel.position = origin + Vector2(50, 60) * scale
	modal._panel.size = Vector2(1180, 600) * scale
	modal._title.position = Vector2(20, 195) * scale
	modal._title.size = Vector2(1140, 120) * scale
	modal._title.add_theme_font_size_override("font_size", roundi(110 * scale))
	modal._buttons[0].position = Vector2(425, 367) * scale
	modal._buttons[0].size = Vector2(110, 96) * scale
	modal._buttons[1].position = Vector2(565, 367) * scale
	modal._buttons[1].size = Vector2(220, 96) * scale
	for button: Button in modal._buttons:
		button.add_theme_font_size_override("font_size", maxi(12, roundi(20 * scale)))
