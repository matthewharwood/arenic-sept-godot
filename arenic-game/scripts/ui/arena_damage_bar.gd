class_name ArenicArenaDamageBar
extends ColorRect
## One shallow procedural draw; completed layers remain beneath the current fill.

const BAR_SHADER: Shader = preload("res://shaders/ui/arena_damage_bar.gdshader")

var total_damage: int = 0
var phase_damage: int = 20
var completed_phases: int = 0
var current_damage: int = 0
var _shader_material: ShaderMaterial
var _theme: ArenicArenaTheme


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = BAR_SHADER
	material = _shader_material
	resized.connect(_update_size)
	_apply_theme()
	_apply_progress()
	_update_size()


func set_visual_theme(value: ArenicArenaTheme) -> void:
	if is_node_ready() and value == _theme:
		return
	_theme = value
	if is_node_ready():
		_apply_theme()


func set_progress(total: int, per_phase: int = 20) -> void:
	var next_total: int = maxi(0, total)
	var next_phase: int = maxi(1, per_phase)
	if is_node_ready() and next_total == total_damage and next_phase == phase_damage:
		return
	total_damage = next_total
	phase_damage = next_phase
	@warning_ignore("integer_division")
	completed_phases = total_damage / phase_damage
	current_damage = total_damage % phase_damage
	if is_node_ready():
		_apply_progress()


func _apply_progress() -> void:
	_shader_material.set_shader_parameter("fill_fraction", float(current_damage) / float(phase_damage))
	_shader_material.set_shader_parameter("has_foundation", completed_phases > 0)


func _apply_theme() -> void:
	if _theme == null:
		visible = false
		return
	visible = true
	_shader_material.set_shader_parameter("pattern_id", _theme.atmosphere_id)
	_shader_material.set_shader_parameter("bed_color", _theme.color("base_300"))
	_shader_material.set_shader_parameter("primary_color", _theme.color("primary"))
	_shader_material.set_shader_parameter("secondary_color", _theme.color("secondary"))
	_shader_material.set_shader_parameter("accent_color", _theme.color("accent"))
	_shader_material.set_shader_parameter("light_color", _theme.color("base_content"))


func _update_size() -> void:
	_shader_material.set_shader_parameter("logical_size", Vector2(maxf(size.x, 1.0), maxf(size.y, 1.0)))
