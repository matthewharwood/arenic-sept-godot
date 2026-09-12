class_name ArenicBossBlastRing
extends Node3D
## Provisional landing telegraph: a flat ring on the ground the boss is falling
## toward, plus a brief flash when it lands. It reads authored geometry and never
## decides who is struck; the ledger resolves that on the beat.
##
## Deliberately primitive. Authored blast artwork replaces this node wholesale.

const SEGMENTS: int = 48
const FLASH_SECONDS: float = 0.32
## How long lethal ground is marked before the landing. The arc itself is short,
## and an unannounced instant kill is not readable, so the telegraph starts
## before the boss leaves. It never shows for less than the authored arc.
const TELEGRAPH_TICKS: int = 150
const GROUND_LIFT: float = 0.012
## Ring weight in tiles, wide enough to read at overview scale without hiding the floor.
const THICKNESS_TILES: float = 0.34

var _warning: MeshInstance3D
var _flash: MeshInstance3D
var _warning_material: StandardMaterial3D
var _flash_material: StandardMaterial3D
var _tint: Color = Color(1.0, 0.32, 0.32)
var _flash_age: float = FLASH_SECONDS
var _radius: float = 0.0


func _ready() -> void:
	_warning_material = _make_material()
	_flash_material = _make_material()
	_warning = _make_ring("Warning", _warning_material, 1)
	_flash = _make_ring("Flash", _flash_material, 2)
	_warning.visible = false
	_flash.visible = false
	set_process(false)


## Themed from the arena so the telegraph belongs to its biome, biased toward the
## HUD's negative token because it marks lethal ground.
func configure(visual_theme: ArenicArenaTheme) -> void:
	if visual_theme == null:
		return
	_tint = ArenicHudTokens.color("negative", visual_theme).lerp(visual_theme.color("primary"), 0.22)


## `until` counts ticks down to the landing; the ring brightens as the boss falls.
func show_warning(center: Vector2, radius_tiles: float, until: int, travel_ticks: int) -> void:
	var window: int = maxi(TELEGRAPH_TICKS, travel_ticks)
	if radius_tiles <= 0.0 or until <= 0 or until > window:
		_warning.visible = false
		return
	_place(_warning, center, radius_tiles)
	var approach: float = clampf(1.0 - float(until) / float(window), 0.0, 1.0)
	_warning_material.albedo_color = Color(_tint, lerpf(0.10, 0.58, approach))
	_warning.visible = true


func hide_warning() -> void:
	if _warning != null:
		_warning.visible = false


func strike(center: Vector2, radius_tiles: float) -> void:
	if radius_tiles <= 0.0:
		return
	_radius = radius_tiles
	_place(_flash, center, radius_tiles)
	_flash_age = 0.0
	_flash.visible = true
	set_process(true)


func _process(delta: float) -> void:
	_flash_age += delta
	var progress: float = clampf(_flash_age / FLASH_SECONDS, 0.0, 1.0)
	if progress >= 1.0:
		_flash.visible = false
		set_process(false)
		return
	# The struck ring expands slightly past the authored radius and fades out.
	var scale_tiles: float = lerpf(1.0, 1.12, progress)
	_flash.scale = Vector3.ONE * scale_tiles
	_flash_material.albedo_color = Color(_tint, lerpf(0.85, 0.0, progress))


func _place(ring: MeshInstance3D, center: Vector2, radius_tiles: float) -> void:
	var mesh := ring.mesh as ImmediateMesh
	_build(mesh, radius_tiles)
	ring.scale = Vector3.ONE
	ring.position = ArenicArenaTiles.tile_point(center) + Vector3(0.0, GROUND_LIFT, 0.0)


func _build(mesh: ImmediateMesh, radius_tiles: float) -> void:
	var outer: float = radius_tiles * ArenicGridMath.TILE_SIZE
	var inner: float = maxf(0.0, outer - THICKNESS_TILES * ArenicGridMath.TILE_SIZE)
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for step: int in SEGMENTS + 1:
		var angle: float = TAU * float(step) / float(SEGMENTS)
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		mesh.surface_add_vertex(direction * inner)
		mesh.surface_add_vertex(direction * outer)
	mesh.surface_end()


func _make_ring(node_name: String, material: StandardMaterial3D, priority: int) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = ImmediateMesh.new()
	instance.material_override = material
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material.render_priority = priority
	add_child(instance)
	return instance


func _make_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.no_depth_test = true
	material.albedo_color = Color(_tint, 0.0)
	return material
