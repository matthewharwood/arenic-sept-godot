extends SceneTree
## Godot --headless --path arenic-game --script res://tests/themes/region_checks.gd
## Material contracts and reversible presentation; renderer QA verifies the shaders.

const WORLD: ArenicWorldDefinition = preload("res://data/world/arenia.tres")
const ARENA: PackedScene = preload("res://scenes/world/arena.tscn")
const PARAMETERS: PackedStringArray = ["region_floor_colors", "region_backdrop_colors", "region_dot_colors"]
var _arenas: Array[ArenicArenaView] = []
var _watchdog: Timer
var _done: bool = false
var _checks: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_watchdog = Timer.new()
	_watchdog.one_shot = true
	_watchdog.timeout.connect(func() -> void: _finish(1, "Regional checks exceeded five seconds."))
	root.add_child(_watchdog)
	_watchdog.start(5.0)
	# Reverse catalogue order to test the actual slot contract, not list order.
	var reordered := ArenicWorldDefinition.new()
	reordered.arenas.assign(WORLD.arenas)
	reordered.arenas.reverse()
	if not _check(reordered.validation_errors().is_empty(), "Reordered world remains valid."):
		return
	for definition: ArenicArenaDefinition in WORLD.arenas:
		var arena := ARENA.instantiate() as ArenicArenaView
		arena.definition = definition
		_arenas.append(arena)
		root.add_child(arena)
		var environment := arena.get_node("EnvironmentLayers") as ArenicArenaEnvironment
		environment.atmosphere_playing = false
		environment.configure_regions(reordered)
		if not _check_arena(arena, environment):
			return
	_finish(0, "Regional checks passed: %d assertions; slot palettes, bounded blend, isolated materials and reversible props." % _checks)


func _check_arena(arena: ArenicArenaView, environment: ArenicArenaEnvironment) -> bool:
	var tiles := arena.get_node("Tiles") as ArenicArenaTiles
	var surface := tiles.material_override as ShaderMaterial
	var materials: Array[ShaderMaterial] = [surface]
	for layer_name: String in ["Backdrop", "Foreground"]:
		var layer := environment.get_node(layer_name) as MeshInstance3D
		materials.append(layer.mesh.surface_get_material(0) as ShaderMaterial)
	for material: ShaderMaterial in materials:
		if not _check(material != null and material.get_shader_parameter("regions_ready") == true, "All three arena materials have a complete regional palette."):
			return false
		for parameter: String in PARAMETERS:
			var value: Variant = material.get_shader_parameter(parameter)
			if not _check(value is PackedVector3Array and value.size() == 9, "Regional palette is a bounded array of nine linear RGB colors."):
				return false
			if not _check(value == surface.get_shader_parameter(parameter), "Floor and atmosphere use identical slot palettes."):
				return false
	for definition: ArenicArenaDefinition in WORLD.arenas:
		var index: int = definition.grid_slot.y * 3 + definition.grid_slot.x
		var actual: PackedVector3Array = surface.get_shader_parameter("region_floor_colors")
		var expected: Color = definition.visual_theme.linear_color("base_100").lerp(definition.visual_theme.linear_color("base_200"), 0.34)
		if not _check(actual[index].is_equal_approx(Vector3(expected.r, expected.g, expected.b)), "Palette lookup follows grid slot even when the catalogue is reversed."):
			return false
	var props: Array[Node] = environment.get_node("Decorations").get_children()
	var positions := PackedVector3Array()
	for node: Node in props:
		positions.append((node as Sprite3D).position)
	var boss := arena.get_node_or_null("Boss") as AnimatedSprite3D
	var boss_position: Vector3 = boss.position if boss != null else Vector3.ZERO
	var boss_color: Color = boss.modulate if boss != null else Color.WHITE
	environment.set_overview_mix(2.0)
	if _arenas.size() > 1:
		var first_tiles := _arenas[0].get_node("Tiles") as ArenicArenaTiles
		var first_surface := first_tiles.material_override as ShaderMaterial
		if not _check(surface != first_surface and first_surface.get_shader_parameter("overview_mix") == 0.0, "Changing one arena leaves another arena material and blend untouched."):
			return false
	for material: ShaderMaterial in materials:
		if not _check(material.get_shader_parameter("overview_mix") == 1.0, "Overview mix clamps at one across all layers."):
			return false
	for node: Node in props:
		if not _check(is_equal_approx((node as Sprite3D).modulate.a, 0.57), "Overview subdues the repeated perimeter props."):
			return false
	if boss != null and not _check(boss.position == boss_position and boss.modulate == boss_color, "Regional blending leaves actor placement and color unchanged."):
		return false
	environment.set_overview_mix(-1.0)
	for material: ShaderMaterial in materials:
		if not _check(material.get_shader_parameter("overview_mix") == 0.0, "Focused mix clamps to exact zero."):
			return false
	for index in props.size():
		var prop := props[index] as Sprite3D
		if not _check(prop.position == positions[index] and prop.modulate.a == 1.0, "Focus restores every original prop position and opacity exactly."):
			return false
	environment.set_overview_mix(NAN)
	return _check(surface.get_shader_parameter("overview_mix") == 0.0, "A nonfinite blend cannot reach the shader.")


func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_finish(1, "Regional assertion failed: " + message)
	return condition


func _finish(code: int, message: String) -> void:
	if _done:
		return
	_done = true
	for arena: ArenicArenaView in _arenas:
		arena.free()
	if is_instance_valid(_watchdog):
		_watchdog.stop()
		_watchdog.queue_free()
	print(message)
	quit(code)
