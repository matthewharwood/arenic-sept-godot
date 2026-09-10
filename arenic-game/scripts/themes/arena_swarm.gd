class_name ArenicArenaSwarm
extends MultiMeshInstance3D
## Attach at the arena center, with an identity local transform.
## Source: matthewharwood/arenic, 32acbd243471d731bf9e2904d02939b7b07d4bdf
## crates/arenic_game/src/{arena,swarm}.rs (identical on source main 60da2157).
## One immutable quad mesh; one MultiMesh/material per arena; 119 instances total.
## Motion runs entirely on the GPU. The caller owns time and reduced-motion state.

const SWARM_SHADER: Shader = preload("res://shaders/themes/arena_swarm.gdshader")
const ELEVATION: float = -0.005
const PIXELS_PER_UNIT: float = 76.0
## Raw data: count, mote (Spark=0, Flake=1, Dart=2, Bubble=3), motion, source scale.
## Motion discriminants follow Patrol through BeatDrift in arena_swarm.gdshader.
const _SPECS: Dictionary = {
	"labyrinth": Vector4(12, 2, 0, 0.11),
	"guild_house": Vector4(14, 0, 1, 0.07),
	"sanctum": Vector4(12, 1, 2, 0.10),
	"mountain": Vector4(16, 0, 3, 0.06),
	"bastion": Vector4(13, 1, 4, 0.09),
	"pawnshop": Vector4(10, 2, 5, 0.09),
	"crucible": Vector4(14, 3, 6, 0.08),
	"casino": Vector4(12, 1, 7, 0.10),
	"gala": Vector4(16, 1, 8, 0.09),
}

static var _shared_mesh: PlaneMesh
var _material: ShaderMaterial
var _arena_id: String = ""
var _time: float = 0.0
var _strength: float = 1.0


func configure(theme: ArenicArenaTheme) -> void:
	if theme == null or not _SPECS.has(theme.arena_id):
		push_error("Sky-swarm requires a canonical arena theme.")
		visible = false
		return
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SWARM_SHADER
		# Vertex displacement cannot alone determine transparent draw order.
		_material.render_priority = -20
		material_override = _material
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material.set_shader_parameter(&"primary", theme.color("primary"))
	if _arena_id != theme.arena_id or multimesh == null:
		_arena_id = theme.arena_id
		var spec: Vector4 = _SPECS[_arena_id]
		var count: int = int(spec.x)
		_material.set_shader_parameter(&"mote", int(spec.y))
		_material.set_shader_parameter(&"motion", int(spec.z))
		_material.set_shader_parameter(&"source_scale", spec.w)
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.use_custom_data = true
		instances.mesh = _quad_mesh()
		instances.instance_count = count
		# Shader vertices occupy this fixed arena-local slab, not their identity origins.
		instances.custom_aabb = AABB(Vector3(-8.25, -0.01, -3.875), Vector3(16.5, 0.01, 7.75))
		for index: int in range(count):
			var opposing_lift: float = 1.0 if int(spec.z) == 6 and index % 2 == 1 else 0.0
			instances.set_instance_transform(index, Transform3D.IDENTITY)
			# Compatibility/Web stores custom data as half floats. Binary fractions
			# preserve these bounded integer seeds exactly in every renderer; the
			# shader reconstructs the original phase, signed lift and golden-angle home.
			instances.set_instance_custom_data(index, Color(float(index) / 16.0, opposing_lift, float(count) / 16.0, 0.0))
		multimesh = instances
	_material.set_shader_parameter(&"atmosphere_time", _time)
	_material.set_shader_parameter(&"strength", _strength)
	visible = _strength > 0.0


## No per-instance CPU updates, new resources or container allocation per frame.
## Pass a frozen time for reduced motion; strength=0 hides the whole draw call.
func set_presentation(time: float, strength: float) -> void:
	if not is_finite(time) or not is_finite(strength):
		return
	var next_strength: float = clampf(strength, 0.0, 1.0)
	if _time != time:
		_time = time
		if _material != null:
			_material.set_shader_parameter(&"atmosphere_time", _time)
	if _strength != next_strength:
		_strength = next_strength
		if _material != null:
			_material.set_shader_parameter(&"strength", _strength)
	visible = _material != null and _strength > 0.0


static func _quad_mesh() -> PlaneMesh:
	if _shared_mesh == null:
		_shared_mesh = PlaneMesh.new()
		_shared_mesh.orientation = PlaneMesh.FACE_Y
		_shared_mesh.size = Vector2.ONE
	return _shared_mesh
