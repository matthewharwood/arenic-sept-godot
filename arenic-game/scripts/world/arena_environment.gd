class_name ArenicArenaEnvironment
extends Node3D
## Flat presentation layers. They never own collision, movement, or camera state.
const ATMOSPHERE = preload("res://shaders/themes/arena_atmosphere.gdshader")
const SURFACE = preload("res://shaders/themes/arena_surface.gdshader")
const ATLAS_PATH: String = "res://assets/environment/arena_decorations.png"
const TILE_PIXELS: float = 19.0
const PROP_PIXELS: int = 76
const COLOR_TOKENS: PackedStringArray = ["base_100", "base_200", "base_300", "base_content", "primary", "secondary", "accent"]
## Insets leave the middle and all four travel corridors open. Art has no collision.
const PROP_CELLS: Array[Vector2i] = [
	Vector2i(4, 26), Vector2i(14, 27), Vector2i(24, 28),
	Vector2i(43, 28), Vector2i(54, 27), Vector2i(61, 24),
	Vector2i(4, 5), Vector2i(14, 3), Vector2i(24, 2),
	Vector2i(43, 2), Vector2i(54, 3), Vector2i(61, 6),
]
## Pause advancement before an AnimationPlayer owns atmosphere_time for seeking.
@export var atmosphere_time: float = 0.0
@export var atmosphere_playing: bool = true
@export_range(0.0, 1.0, 0.01) var effect_strength: float = 1.0:
	set(value):
		effect_strength = clampf(value, 0.0, 1.0)

var _materials: Array[ShaderMaterial] = []
var _surface: ShaderMaterial
var _theme: ArenicArenaTheme
var _swarm: ArenicArenaSwarm
var _tiles: ArenicArenaTiles
var _overview_mix: float = 0.0
var _regions_ready: bool = false
var _props: Array[Sprite3D] = []
var _prop_positions: PackedVector3Array = []


func configure(definition: ArenicArenaDefinition, tiles: ArenicArenaTiles) -> void:
	_theme = definition.visual_theme
	if _theme == null:
		push_error("Arena is missing its visual theme: " + definition.arena_id)
		return
	_surface = _material(SURFACE)
	# Explicit transparent ordering also holds while cinematic cameras tilt.
	_surface.render_priority = -10
	_surface.set_shader_parameter("identity", _theme.atmosphere_id)
	_tiles = tiles
	tiles.material_override = _surface
	tiles.set_overview_mix(_overview_mix)
	_add_atmosphere("Backdrop", false, -0.02)
	_add_atmosphere("Foreground", true, 0.002)
	_swarm = ArenicArenaSwarm.new()
	_swarm.name = "Swarm"
	add_child(_swarm)
	_swarm.configure(_theme)
	_build_decorations()


## Called once by the stage after all arenas are mounted. Slot order, not list
## order or theme identity, determines which four palettes meet at each seam.
func configure_regions(world: ArenicWorldDefinition) -> void:
	if _surface == null or world == null or not world.validation_errors().is_empty():
		push_error("Regional blending needs a configured arena and a valid world.")
		return
	var floors := PackedVector3Array()
	var backdrops := PackedVector3Array()
	var dots := PackedVector3Array()
	floors.resize(ArenicGridMath.ARENA_COUNT)
	backdrops.resize(ArenicGridMath.ARENA_COUNT)
	dots.resize(ArenicGridMath.ARENA_COUNT)
	for arena: ArenicArenaDefinition in world.arenas:
		var theme: ArenicArenaTheme = arena.visual_theme
		if theme == null:
			push_error("Regional blending needs all nine arena themes.")
			return
		var index: int = arena.grid_slot.y * ArenicGridMath.WORLD_COLUMNS + arena.grid_slot.x
		var base: Color = theme.linear_color("base_100")
		floors[index] = _rgb(base.lerp(theme.linear_color("base_200"), 0.34))
		backdrops[index] = _rgb(theme.linear_color("base_300").lerp(base, 0.25))
		dots[index] = _rgb(base.lerp(theme.linear_color("base_content"), 0.4))
	var materials: Array[ShaderMaterial] = [_surface]
	materials.append_array(_materials)
	for material: ShaderMaterial in materials:
		material.set_shader_parameter("region_floor_colors", floors)
		material.set_shader_parameter("region_backdrop_colors", backdrops)
		material.set_shader_parameter("region_dot_colors", dots)
		material.set_shader_parameter("region_world_origin", ArenicGridMath.world_rect().position)
		material.set_shader_parameter("region_arena_size", Vector2(ArenicGridMath.ARENA_WIDTH, ArenicGridMath.ARENA_HEIGHT))
		material.set_shader_parameter("regions_ready", true)
	_regions_ready = true
	set_overview_mix(_overview_mix)


## The stage supplies camera scale; neither presentation nor tiles own the camera.
func set_overview_mix(value: float) -> void:
	_overview_mix = clampf(value, 0.0, 1.0) if is_finite(value) else 0.0
	if _tiles != null:
		_tiles.set_overview_mix(_overview_mix)
	for material: ShaderMaterial in _materials:
		material.set_shader_parameter("overview_mix", _overview_mix)
	var amount: float = _overview_mix if _regions_ready else 0.0
	for index in _props.size():
		var prop: Sprite3D = _props[index]
		var phase: float = float(index) * 2.39996 + float(_theme.atmosphere_id) * 1.618
		var displacement := Vector3(sin(phase) * 0.30, 0.0, cos(phase * 1.37) * 0.20)
		var position_on_floor: Vector3 = _prop_positions[index] + displacement * amount
		# The full sprite canvas (including its half-pixel offset) stays in its biome.
		var half_canvas: float = PROP_PIXELS * ArenicGridMath.TILE_SIZE / TILE_PIXELS * 0.5 + prop.pixel_size
		position_on_floor.x = clampf(position_on_floor.x, -ArenicGridMath.ARENA_WIDTH * 0.5 + half_canvas, ArenicGridMath.ARENA_WIDTH * 0.5 - half_canvas)
		position_on_floor.z = clampf(position_on_floor.z, -ArenicGridMath.ARENA_HEIGHT * 0.5 + half_canvas, ArenicGridMath.ARENA_HEIGHT * 0.5 - half_canvas)
		prop.position = _prop_positions[index] if amount == 0.0 else position_on_floor
		prop.modulate.a = lerpf(1.0, 0.57, amount)


static func _rgb(color: Color) -> Vector3:
	return Vector3(color.r, color.g, color.b)


func _process(delta: float) -> void:
	# Paused visible arenas still upload authored seeks to their own materials.
	if atmosphere_playing:
		atmosphere_time = fmod(atmosphere_time + delta, 3600.0)
	if not is_visible_in_tree():
		return
	if _surface != null:
		_surface.set_shader_parameter("atmosphere_time", atmosphere_time)
		_surface.set_shader_parameter("strength", effect_strength)
	if _swarm != null:
		_swarm.set_presentation(atmosphere_time, effect_strength)
	for material in _materials:
		material.set_shader_parameter("atmosphere_time", atmosphere_time)
		material.set_shader_parameter("strength", effect_strength)


func _material(shader: Shader) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	for token in COLOR_TOKENS:
		material.set_shader_parameter(token, _theme.color(token))
	return material


func _add_atmosphere(layer_name: String, foreground: bool, elevation: float) -> void:
	var material := _material(ATMOSPHERE)
	material.render_priority = -5 if foreground else -30
	var prefix: String = "foreground" if foreground else "backdrop"
	for parameter in ["style", "scale", "drift", "coverage", "vignette", "speed"]:
		material.set_shader_parameter(parameter, _theme.get(prefix + "_" + parameter))
	material.set_shader_parameter("foreground", foreground)
	_materials.append(material)
	var plane := PlaneMesh.new()
	plane.size = Vector2(ArenicGridMath.ARENA_WIDTH, ArenicGridMath.ARENA_HEIGHT)
	plane.material = material
	var layer := MeshInstance3D.new()
	layer.name = layer_name
	layer.mesh = plane
	layer.position.y = elevation
	layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(layer)


func _build_decorations() -> void:
	var atlas := load(ATLAS_PATH) as Texture2D
	if atlas == null:
		push_error("Missing arena decoration atlas.")
		return
	var root := Node3D.new()
	root.name = "Decorations"
	add_child(root)
	for index in range(PROP_CELLS.size()):
		var region := AtlasTexture.new()
		region.atlas = atlas
		region.region = Rect2((index % 3) * PROP_PIXELS, _theme.atmosphere_id * PROP_PIXELS, PROP_PIXELS, PROP_PIXELS)
		var prop := Sprite3D.new()
		prop.name = "Prop%02d" % index
		prop.texture = region
		prop.pixel_size = ArenicGridMath.TILE_SIZE / TILE_PIXELS
		prop.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		prop.shaded = false
		prop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		prop.rotation.x = -PI * 0.5
		prop.position = ArenicArenaTiles.tile_center(PROP_CELLS[index]) + Vector3(0.0, 0.004, 0.0)
		# Even canvases need half a native pixel to share the odd-cell raster grid.
		prop.offset = Vector2(0.5, 0.5)
		root.add_child(prop)
		_props.append(prop)
		_prop_positions.append(prop.position)
