@tool
class_name ArenicClassCard
extends Button

@export var definition: ArenicClassDefinition:
	set(value):
		definition = value
		if is_node_ready():
			_refresh_content()

@onready var _icon: TextureRect = $Icon
@onready var _caption: Label = $Caption


func _ready() -> void:
	if not toggled.is_connected(_update_tint):
		toggled.connect(_update_tint)
	_refresh_content()


func _refresh_content() -> void:
	if definition != null:
		_icon.texture = definition.icon
		_caption.text = definition.display_name
	_update_tint(button_pressed)


func _update_tint(selected: bool) -> void:
	var tint := get_theme_color("font_pressed_color" if selected else "font_color")
	_icon.self_modulate = tint
	_caption.add_theme_color_override("font_color", tint)
