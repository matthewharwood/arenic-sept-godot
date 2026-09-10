class_name ArenicOverworldAtmosphere
extends CanvasLayer
## One connected coast and two bounded cloud draws; no screen copy or refraction.
## Clock is explicit and seekable for future cinematics. A full cycle is six minutes.
const SKY: Shader = preload("res://shaders/themes/overworld_sky.gdshader")
const CLOUDS: Shader = preload("res://shaders/themes/overworld_clouds.gdshader")
@export_range(120.0, 600.0, 1.0) var cloud_period_seconds: float = 360.0
@export var atmosphere_time: float = 0.0
@export var atmosphere_playing: bool = true
var overview_mix: float = 0.0
var _sky: ColorRect
var _clouds: ColorRect
var _sky_material: ShaderMaterial
var _cloud_material: ShaderMaterial
var _rig: ArenicCameraRig
var _land_rect := Rect2()
var _land_origin := Vector2.ZERO
var _land_u := Vector2.ZERO
var _land_v := Vector2.ZERO
var _land_size := Vector2.ONE
var _coast_valid: bool = false
var _last_focus := Vector3(INF, INF, INF)
var _last_span := Vector2(INF, INF)
var _last_basis := Basis()
var _last_size := Vector2.ZERO

func configure(rig: ArenicCameraRig, world: ArenicWorldDefinition) -> void:
	layer = 4 # Coast sits above world sprites but below arena labels.
	_rig = rig
	var noise := FastNoiseLite.new()
	noise.seed = 49127
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.017
	noise.fractal_octaves = 4
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.seamless_blend_skirt = 0.2
	texture.noise = noise
	_sky_material = ShaderMaterial.new()
	_sky_material.shader = SKY
	_cloud_material = ShaderMaterial.new()
	_cloud_material.shader = CLOUDS
	var cool: ArenicArenaTheme = world.arenas[0].visual_theme
	var warm: ArenicArenaTheme = world.arenas[7].visual_theme
	var low := cool.color("base_300").lerp(cool.color("primary"), 0.10)
	var high := cool.color("base_200").lerp(warm.color("secondary"), 0.18)
	var mist := cool.color("base_content").lerp(warm.color("secondary"), 0.14)
	_sky_material.set_shader_parameter("sky_low", low)
	_sky_material.set_shader_parameter("sky_high", high)
	for material: ShaderMaterial in [_sky_material, _cloud_material]:
		material.set_shader_parameter("cloud_noise", texture)
		material.set_shader_parameter("mist_ink", mist)
	_sky = _rectangle("CoastAndSky", _sky_material, self)
	var foreground := CanvasLayer.new()
	foreground.name = "ForegroundClouds"
	foreground.layer = 21 # The faintest veil can also pass over persistent HUD chrome.
	add_child(foreground)
	_clouds = _rectangle("DriftingClouds", _cloud_material, foreground)
	get_viewport().size_changed.connect(sync_projection)
	sync_projection()
	set_overview_mix(0.0)

func _rectangle(node_name: String, material: ShaderMaterial, parent: Node) -> ColorRect:
	var rectangle := ColorRect.new()
	rectangle.name = node_name
	rectangle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rectangle.material = material
	parent.add_child(rectangle)
	return rectangle

func set_overview_mix(value: float) -> void:
	overview_mix = clampf(value, 0.0, 1.0) if is_finite(value) else 0.0
	if _sky == null:
		return
	for material: ShaderMaterial in [_sky_material, _cloud_material]:
		material.set_shader_parameter("overview_mix", overview_mix)
	_clouds.visible = overview_mix > 0.001
	_sky.visible = _clouds.visible and _coast_valid
	set_process(_clouds.visible)
	if _clouds.visible:
		sync_projection()

func _process(delta: float) -> void:
	if atmosphere_playing:
		atmosphere_time = fposmod(atmosphere_time + delta, cloud_period_seconds)
	var phase: float = fposmod(atmosphere_time, cloud_period_seconds) / cloud_period_seconds
	_sky_material.set_shader_parameter("cloud_phase", phase)
	_cloud_material.set_shader_parameter("cloud_phase", phase)
	sync_projection()

func sync_projection(force: bool = false) -> void:
	if not is_inside_tree() or not is_instance_valid(_rig) or not _rig.is_inside_tree() or _sky == null:
		return
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	if not force and _last_size == viewport_size and _last_focus == _rig.focus_world and _last_span == _rig.view_span and _last_basis == _rig.global_basis:
		return
	_last_size = viewport_size
	_last_focus = _rig.focus_world
	_last_span = _rig.view_span
	_last_basis = _rig.global_basis
	_sky.size = viewport_size
	_clouds.size = viewport_size
	_sky_material.set_shader_parameter("viewport_size", viewport_size)
	var bounds := ArenicGridMath.world_rect()
	var first := true
	for point: Vector2 in [bounds.position, bounds.end, Vector2(bounds.position.x, bounds.end.y), Vector2(bounds.end.x, bounds.position.y)]:
		var screen := _rig.world_to_screen(Vector3(point.x, 0.0, point.y))
		if not screen.is_finite():
			_coast_valid = false
			_sky.visible = false
			return
		if first:
			_land_rect = Rect2(screen, Vector2.ZERO)
			first = false
		else:
			_land_rect = _land_rect.expand(screen)
	_sky_material.set_shader_parameter("land_rect", Vector4(_land_rect.position.x, _land_rect.position.y, _land_rect.size.x, _land_rect.size.y))
	_land_origin = _rig.world_to_screen(Vector3(bounds.position.x, 0.0, bounds.position.y))
	var axis_x := _rig.world_to_screen(Vector3(bounds.end.x, 0.0, bounds.position.y)) - _land_origin
	var axis_y := _rig.world_to_screen(Vector3(bounds.position.x, 0.0, bounds.end.y)) - _land_origin
	var determinant: float = axis_x.cross(axis_y)
	_land_size = Vector2(axis_x.length(), axis_y.length())
	_coast_valid = absf(determinant) > 0.01 and _land_size.x > 1.0 and _land_size.y > 1.0
	_sky.visible = _coast_valid and overview_mix > 0.001
	if not _coast_valid:
		return # An edge-on plane has no invertible coast; keep the sky veil only.
	_land_u = Vector2(axis_y.y, -axis_y.x) / determinant
	_land_v = Vector2(-axis_x.y, axis_x.x) / determinant
	_sky_material.set_shader_parameter("land_origin", _land_origin)
	_sky_material.set_shader_parameter("land_u", _land_u)
	_sky_material.set_shader_parameter("land_v", _land_v)
	_sky_material.set_shader_parameter("land_size", _land_size)

## The world is orthographic: its projected ground plane is affine even when a
## sequence rotates or tilts the camera. Picking uses the middle of the coast fade.
func contains_land_point(point: Vector2) -> bool:
	if overview_mix < 0.999 or not _coast_valid:
		return true
	var relative := point - _land_origin
	var uv := Vector2(relative.dot(_land_u), relative.dot(_land_v))
	var radius: float = minf(_land_size.x, _land_size.y) * 0.20
	var q := ((uv - Vector2(0.5, 0.5)) * _land_size).abs() - _land_size * 0.5 + Vector2(20.0 + radius, 18.0 + radius)
	var distance: float = q.max(Vector2.ZERO).length() + minf(maxf(q.x, q.y), 0.0) - radius
	return distance <= 0.0
