class_name ArenicArenaTiles
extends MultiMeshInstance3D
## Attach beneath an Arena positioned at ArenicGridMath.arena_center(slot).
## Every instance is a real 0.25-unit XZ tile; the shared texture is 19 x 19.
## Shared geometry/fallback texture stay immutable; each arena owns a theme material.

const Grid = preload("res://scripts/world/grid_math.gd")
const TILE_PIXELS: int = 19
const CENTER_PIXEL: int = 9
const TILE_COUNT: int = Grid.GRID_WIDTH * Grid.GRID_HEIGHT
const CENTER_GRAY: Color = Color(0.6, 0.6, 0.6, 1.0)

static var _shared_tile_mesh: PlaneMesh
var _initialized: bool = false
var _overview_mix: float = 0.0


func _ready() -> void:
	if _initialized:
		return
	var tiles: MultiMesh = MultiMesh.new()
	tiles.transform_format = MultiMesh.TRANSFORM_3D
	tiles.use_custom_data = true
	tiles.mesh = _get_tile_mesh()
	tiles.instance_count = TILE_COUNT
	for row: int in range(Grid.GRID_HEIGHT):
		for column: int in range(Grid.GRID_WIDTH):
			var cell: Vector2i = Vector2i(column, row)
			var index: int = row * Grid.GRID_WIDTH + column
			tiles.set_instance_transform(index, Transform3D(Basis.IDENTITY, tile_center(cell)))
			# Binary fractions keep bounded motif coordinates exact even in the
			# Compatibility/Web half-float custom-data buffer. Shader decodes them.
			tiles.set_instance_custom_data(index, Color(float(column) / 128.0, float(Grid.GRID_HEIGHT - 1 - row) / 32.0, 0.0, 0.0))
	# Each arena owns its transforms; only the immutable visual resources are shared.
	multimesh = tiles
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_initialized = true


## The environment owns the unique material; geometry remains immutable.
func set_overview_mix(value: float) -> void:
	_overview_mix = clampf(value, 0.0, 1.0) if is_finite(value) else 0.0
	var material := material_override as ShaderMaterial
	if material != null:
		material.set_shader_parameter("overview_mix", _overview_mix)


## Equals tile_to_world(slot, cell) - arena_center(slot) for every arena slot.
## Local tile rows advance toward -Z, matching the authoritative grid mapping.
static func tile_center(cell: Vector2i) -> Vector3:
	return tile_point(Vector2(cell))


## The same local mapping for a fractional tile coordinate. An even footprint is
## centered on a half tile, and a boss in flight is between tiles entirely, so
## motion and blast geometry need the continuous form.
static func tile_point(cell: Vector2) -> Vector3:
	return Vector3(
		(cell.x - (Grid.GRID_WIDTH - 1) * 0.5) * Grid.TILE_SIZE,
		0.0,
		((Grid.GRID_HEIGHT - 1) * 0.5 - cell.y) * Grid.TILE_SIZE
	)


static func _get_tile_mesh() -> PlaneMesh:
	if _shared_tile_mesh != null:
		return _shared_tile_mesh
	var image: Image = Image.create_empty(TILE_PIXELS, TILE_PIXELS, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	image.set_pixel(CENTER_PIXEL, CENTER_PIXEL, CENTER_GRAY)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.texture_repeat = false
	material.disable_fog = true
	material.albedo_color = Color.WHITE
	material.albedo_texture = ImageTexture.create_from_image(image)
	var tile: PlaneMesh = PlaneMesh.new()
	tile.size = Vector2(Grid.TILE_SIZE, Grid.TILE_SIZE)
	tile.orientation = PlaneMesh.FACE_Y
	tile.material = material
	_shared_tile_mesh = tile
	return _shared_tile_mesh
