class_name ArenicGroundOverlay
extends MultiMeshInstance3D
## Tinted tiles on the arena floor.
##
## Two things use it. Broken ground answers *have I already dug here* — a second
## dig yields nothing — and burns hot while a boss is standing in the trap. Acid
## answers *where is the pool and how long has it got*, fading as it dries.
##
## One MultiMesh per layer: a busy Forager breaks dozens of tiles a cycle and a
## pool covers nine, and none of them may cost a node.

## Ground effects lie UNDER everything that stands on them. A boss wading
## through acid must be drawn over the pool, not swallowed by it, so these
## heights stay below the boss sprite's own lift and the priorities stay below
## the default a Sprite3D renders at.
const FLOOR_BASE: float = 0.004
const FLOOR_STEP: float = 0.002
## Far enough below zero that any sprite, at any default priority, wins.
const SORT_FLOOR: int = -8

var _material: StandardMaterial3D
var _cells := PackedInt32Array()
var _colors := PackedColorArray()


func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE * ArenicGridMath.TILE_SIZE * 0.78
	# Laid flat on the floor, like every other ground marker in the arena.
	quad.orientation = PlaneMesh.FACE_Y
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.vertex_color_use_as_albedo = true
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = _material
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = quad
	multimesh.instance_count = 0
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Layers stack among themselves — acid reads over broken ground — while the
## whole stack stays beneath anything standing in it.
func set_elevation(order: int) -> void:
	var layer: int = maxi(1, order)
	position.y = FLOOR_BASE + FLOOR_STEP * float(layer)
	_material.render_priority = SORT_FLOOR + layer


## Where this layer sorts against the sprites standing on it.
func sort_order() -> int:
	return _material.render_priority if _material != null else 0


## `cells` are cell indices; `colors` matches it one for one.
func set_cells(cells: PackedInt32Array, colors: PackedColorArray) -> void:
	if cells == _cells and colors == _colors:
		return
	_cells = cells.duplicate()
	_colors = colors.duplicate()
	multimesh.instance_count = cells.size()
	for slot: int in cells.size():
		var point: Vector3 = ArenicArenaTiles.tile_center(ArenicDigField.cell_of(cells[slot]))
		multimesh.set_instance_transform(slot, Transform3D(Basis.IDENTITY, point))
		multimesh.set_instance_color(slot, colors[slot] if slot < colors.size() else Color.WHITE)
