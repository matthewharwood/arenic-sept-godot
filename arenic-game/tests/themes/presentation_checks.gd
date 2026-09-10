extends SceneTree
## Run with a real renderer after the visible game stops:
## Godot --path arenic-game --script res://tests/themes/presentation_checks.gd
## Checks scene/material boundaries; theme_checks.gd owns primitive/conversion tests.

const SHELL_PATH: String = "res://scenes/game/game_shell.tscn"
const ARENA_PATH: String = "res://scenes/world/arena.tscn"
const ATLAS_METADATA: String = "res://assets/environment/arena_decorations.json"
const FLOOR_SHADER: String = "res://shaders/themes/arena_surface.gdshader"
const ATMOSPHERE_SHADER: String = "res://shaders/themes/arena_atmosphere.gdshader"
const FLOOR_TOKENS: PackedStringArray = ["base_100", "base_200", "base_300", "base_content", "primary", "secondary", "accent"]
const ATMOSPHERE_TOKENS: PackedStringArray = ["base_100", "base_300", "primary", "secondary", "accent"]
const SAMPLE_CELLS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(65, 0), Vector2i(0, 30), Vector2i(65, 30), Vector2i(32, 15)]
const SAFE_RECT: Rect2 = Rect2(13.0, 35.0, 1254.0, 589.0)
const WATCHDOG_SECONDS: float = 10.0
const SWARM_COUNTS: Array[int] = [12, 14, 12, 16, 13, 10, 14, 12, 16]
const SWARM_MOTES: Array[int] = [2, 0, 1, 0, 1, 2, 3, 1, 1]
const SWARM_SCALES: Array[float] = [0.11, 0.07, 0.10, 0.06, 0.09, 0.09, 0.08, 0.10, 0.09]

# Load GameShell only after autoload initialization: its script references RunSetup.
var _shell: Variant
var _probe: ArenicArenaView
var _watchdog: Timer
var _started_ms: int = 0
var _checks: int = 0
var _done: bool = false
var _materials: Dictionary = {}
var _atlas_regions: Dictionary = {}
var _manifest: Dictionary
var _atlas_image: Image
var _tile_mesh: Mesh
var _swarm_mesh: Mesh
var _swarm_materials: Dictionary = {}
var _swarm_instances: int = 0


func _initialize() -> void:
	_started_ms = Time.get_ticks_msec()
	_run.call_deferred()


func _run() -> void:
	_watchdog = Timer.new()
	_watchdog.one_shot = true
	_watchdog.wait_time = WATCHDOG_SECONDS
	_watchdog.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_watchdog)
	_watchdog.timeout.connect(func(): _finish(1, "Presentation checks exceeded the ten-second watchdog."))
	_watchdog.start()
	if not _check(DisplayServer.get_name() != "headless", "Use a real renderer; the dummy backend cannot verify MultiMesh geometry."):
		return
	var metadata: Variant = JSON.parse_string(FileAccess.get_file_as_string(ATLAS_METADATA))
	if not _check(metadata is Dictionary and metadata.has("arenas") and metadata.has("meta"), "Decoration export metadata loads."):
		return
	_manifest = metadata
	var packed := load(SHELL_PATH) as PackedScene
	if not _check(packed != null, "Actual game shell loads."):
		return
	root.size = Vector2i(1280, 720)
	_shell = packed.instantiate()
	if not _check(_shell != null, "Actual game shell instantiates."):
		return
	root.add_child(_shell)
	await process_frame
	await process_frame
	if _done:
		return
	if not _check(_shell.stage.world.arenas.size() == 9 and _manifest.arenas.size() == 9, "Scene and decoration export contain nine arenas."):
		return
	if not _check(_shell.hud.get_world_rect().is_equal_approx(SAFE_RECT), "Themed chrome preserves the exact native play area."):
		return
	for index: int in range(9):
		var arena: ArenicArenaView = _shell.stage.get_arena(index)
		if not _check_arena(arena, index):
			return
	if not _check(_materials.size() == 27 and _atlas_regions.size() == 27, "Nine floors and eighteen atmosphere materials are isolated; all 27 exported prop frames are used."):
		return
	if not _check(_swarm_instances == 119 and _swarm_materials.size() == 9, "Nine isolated swarm draws preserve the source total of 119 bounded motes."):
		return
	if not _check_instance_isolation() or not _check_atmosphere_controls() or not _check_overview_labels():
		return
	for index: int in range(9):
		if not _check_focused_style(index):
			return
	_finish(0, "Presentation checks passed: %d assertions; nine styles, isolated materials, 108 native props, actor clearance, camera scale and themed HUD/labels." % _checks)


func _check_arena(arena: ArenicArenaView, index: int) -> bool:
	if not _check(arena != null and arena.definition == _shell.stage.world.arenas[index], "Scene arena matches its world definition."):
		return false
	var definition: ArenicArenaDefinition = arena.definition
	var theme: ArenicArenaTheme = definition.visual_theme
	if not _check(theme != null and theme.atmosphere_id == index, "Arena carries its own presentation identity."):
		return false
	var tiles := arena.get_node_or_null("Tiles") as ArenicArenaTiles
	var environment := arena.get_node_or_null("EnvironmentLayers") as ArenicArenaEnvironment
	if not _check(tiles != null and environment != null, "Native tiles and independent environment layers exist."):
		return false
	var floor_material := tiles.material_override as ShaderMaterial
	if not _check_material(floor_material, FLOOR_SHADER, theme, FLOOR_TOKENS):
		return false
	if not _check(floor_material.get_shader_parameter("identity") == index, "Floor selects the matching authored motif."):
		return false
	if not _check(floor_material.render_priority == -10, "Transparent floor sorts above the swarm and below the foreground veil."):
		return false
	var lattice: MultiMesh = tiles.multimesh
	if not _check(lattice != null and lattice.instance_count == 66 * 31 and lattice.use_custom_data, "Themed floor retains all 2,046 independent cells and motif coordinates."):
		return false
	var mesh := lattice.mesh as PlaneMesh
	if not _check(mesh != null and mesh.size.is_equal_approx(Vector2.ONE * ArenicGridMath.TILE_SIZE), "Themed floor keeps native one-cell geometry."):
		return false
	if _tile_mesh == null:
		_tile_mesh = mesh
	if not _check(mesh == _tile_mesh and mesh.material is StandardMaterial3D, "Theme overrides do not mutate the shared fallback mesh/material."):
		return false
	for cell: Vector2i in SAMPLE_CELLS:
		var instance: int = cell.y * 66 + cell.x
		var placement: Transform3D = tiles.global_transform * lattice.get_instance_transform(instance)
		var encoded: Color = lattice.get_instance_custom_data(instance)
		if not _check(placement.origin.is_equal_approx(ArenicGridMath.tile_to_world(definition.grid_slot, cell)) and placement.basis.is_equal_approx(Basis.IDENTITY), "Theme leaves corner/center geometry on the authoritative lattice."):
			return false
		if not _check(encoded.r == float(cell.x) / 128.0 and encoded.g == float(30 - cell.y) / 32.0 and encoded.b == 0.0 and encoded.a == 0.0, "GPU motif seeds remain exact bounded binary fractions across renderers."):
			return false
		if not _check(Vector2(roundf(encoded.r * 128.0), roundf(encoded.g * 32.0)) == Vector2(cell.x, 30 - cell.y), "Decoded GPU motif coordinates preserve every cell and north/south orientation."):
			return false
	var backdrop := environment.get_node_or_null("Backdrop") as MeshInstance3D
	var foreground := environment.get_node_or_null("Foreground") as MeshInstance3D
	if not _check(backdrop != null and foreground != null, "Both atmosphere voices are mounted."):
		return false
	for layer: MeshInstance3D in [backdrop, foreground]:
		var plane := layer.mesh as PlaneMesh
		if not _check(plane != null and plane.size.is_equal_approx(Vector2(16.5, 7.75)), "Atmosphere planes use the unchanged arena footprint."):
			return false
		var material := plane.material as ShaderMaterial
		if not _check_material(material, ATMOSPHERE_SHADER, theme, ATMOSPHERE_TOKENS):
			return false
		var is_foreground: bool = layer == foreground
		if not _check(material.render_priority == (-5 if is_foreground else -30), "Explicit atmosphere sort order survives cinematic camera movement."):
			return false
		var prefix: String = "foreground_" if is_foreground else "backdrop_"
		if not _check(material.get_shader_parameter("foreground") == is_foreground, "Atmosphere branch matches its physical layer."):
			return false
		for voice: String in ["style", "scale", "drift", "coverage", "vignette", "speed"]:
			if not _check(material.get_shader_parameter(voice) == theme.get(prefix + voice), "Source atmosphere voice reaches its shader: " + prefix + voice):
				return false
	if not _check(backdrop.global_position.y < tiles.global_position.y and tiles.global_position.y < foreground.global_position.y, "Layer ordering places the backdrop below the floor and veil above it."):
		return false
	if not _check(environment.find_children("*", "CollisionObject3D", true, false).is_empty(), "Presentation layers introduce no gameplay collision."):
		return false
	return _check_decorations(arena, environment, foreground, index) and _check_swarm(arena, index)


func _check_swarm(arena: ArenicArenaView, index: int) -> bool:
	var swarm := arena.get_node_or_null("EnvironmentLayers/Swarm") as MultiMeshInstance3D
	if not _check(swarm != null and swarm.get_script() != null and swarm.get_script().get_global_name() == "ArenicArenaSwarm", "Each arena mounts its bounded native swarm."):
		return false
	var instances: MultiMesh = swarm.multimesh
	if not _check(instances != null and instances.instance_count == SWARM_COUNTS[index] and instances.instance_count <= 16 and instances.use_custom_data, "Swarm density matches the source count and stays bounded to sixteen motes."):
		return false
	_swarm_instances += instances.instance_count
	if not _check(swarm.transform.is_equal_approx(Transform3D.IDENTITY), "Shader-driven swarm uses the arena's unchanged local coordinate frame."):
		return false
	var mesh := instances.mesh as PlaneMesh
	if not _check(mesh != null and mesh.orientation == PlaneMesh.FACE_Y and mesh.size.is_equal_approx(Vector2.ONE), "Flat swarm shares a normalized overhead quad."):
		return false
	if _swarm_mesh == null:
		_swarm_mesh = mesh
	if not _check(mesh == _swarm_mesh and mesh.material == null, "All swarms share immutable geometry with no palette baked onto the quad."):
		return false
	var material := swarm.material_override as ShaderMaterial
	if not _check(material != null and material.shader.resource_path == "res://shaders/themes/arena_swarm.gdshader", "Swarm uses its dedicated GPU motion/mask shader."):
		return false
	if not _check(material.render_priority == -20, "Shader-displaced swarm sorts between the backdrop and floor."):
		return false
	var material_id: int = material.get_instance_id()
	if not _check(not _swarm_materials.has(material_id) and not _materials.has(material_id), "Swarm uniforms are private to this arena and separate from its floor/atmosphere."):
		return false
	_swarm_materials[material_id] = true
	if not _check(material.get_shader_parameter("motion") == index and material.get_shader_parameter("mote") == SWARM_MOTES[index] and is_equal_approx(float(material.get_shader_parameter("source_scale")), SWARM_SCALES[index]), "Swarm selects the source motion, silhouette and nominal scale for its arena."):
		return false
	var primary: Color = material.get_shader_parameter("primary")
	if not _check(primary.is_equal_approx(arena.definition.visual_theme.color("primary")), "Swarm follows its own arena's primary palette color."):
		return false
	var bounds: AABB = instances.custom_aabb
	if not _check(bounds.position.is_equal_approx(Vector3(-8.25, -0.01, -3.875)) and bounds.size.is_equal_approx(Vector3(16.5, 0.01, 7.75)), "GPU displacement declares the complete arena-local slab for renderer culling."):
		return false
	if not _check(bounds.end.y <= 0.0 and bounds.has_point(Vector3(0.0, -0.005, 0.0)), "Swarm culling bounds remain below the floor and actor planes."):
		return false
	for mote_index: int in range(instances.instance_count):
		var transform: Transform3D = instances.get_instance_transform(mote_index)
		var metadata: Color = instances.get_instance_custom_data(mote_index)
		var lift_sign: float = -1.0 if index == 6 and mote_index % 2 == 1 else 1.0
		if not _check(transform.is_equal_approx(Transform3D.IDENTITY), "Mote transforms remain fixed; shader time owns motion."):
			return false
		var opposing_lift: float = 1.0 if lift_sign < 0.0 else 0.0
		if not _check(metadata == Color(float(mote_index) / 16.0, opposing_lift, float(instances.instance_count) / 16.0, 0.0), "GPU swarm seeds remain exact bounded binary fractions across renderers."):
			return false
		var decoded_index: int = roundi(metadata.r * 16.0)
		var decoded_count: int = roundi(metadata.b * 16.0)
		if not _check(decoded_index == mote_index and decoded_count == instances.instance_count and 1.0 - 2.0 * metadata.g == lift_sign, "Shader decoding retains original phase index, source-home count and opposing signed lift."):
			return false
	return true


func _check_material(material: ShaderMaterial, expected_shader: String, theme: ArenicArenaTheme, tokens: PackedStringArray) -> bool:
	if not _check(material != null and material.shader != null and material.shader.resource_path == expected_shader, "Scene uses the intended presentation shader."):
		return false
	var id: int = material.get_instance_id()
	if not _check(not _materials.has(id), "Every floor and atmosphere layer owns its material instance."):
		return false
	_materials[id] = true
	for token: String in tokens:
		var value: Variant = material.get_shader_parameter(token)
		if not _check(value is Color and value.is_equal_approx(theme.color(token)), "Source-color uniform is assigned from this arena's theme: " + token):
			return false
	return true


func _check_decorations(arena: ArenicArenaView, environment: ArenicArenaEnvironment, foreground: MeshInstance3D, index: int) -> bool:
	var decorations := environment.get_node_or_null("Decorations") as Node3D
	if not _check(decorations != null and decorations.get_child_count() == 12, "Each arena has twelve bounded decorative placements."):
		return false
	var exported_arena: Dictionary = _manifest.arenas[index]
	if not _check(exported_arena.id == arena.definition.arena_id and exported_arena.props.size() == 3, "Runtime arena selects its own three exported prop identities."):
		return false
	var boss := arena.get_node_or_null("Boss") as AnimatedSprite3D
	if boss != null and not _check(boss.render_priority == 0, "Boss art sorts above all transparent environment layers."):
		return false
	for prop_index: int in range(decorations.get_child_count()):
		var prop := decorations.get_child(prop_index) as Sprite3D
		if not _check(prop != null and prop.texture is AtlasTexture, "Each decoration uses a native atlas frame."):
			return false
		var atlas := prop.texture as AtlasTexture
		var expected_frame: Array = exported_arena.props[prop_index % 3].rect
		var expected := Rect2(expected_frame[0], expected_frame[1], expected_frame[2], expected_frame[3])
		if not _check(atlas.region == expected and atlas.region.size == Vector2(76.0, 76.0), "Atlas region matches source metadata without trimming or row bleed."):
			return false
		if not _check(atlas.atlas != null and atlas.atlas.get_size() == Vector2(_manifest.meta.size.w, _manifest.meta.size.h), "Atlas dimensions match the native export manifest."):
			return false
		if _atlas_image == null:
			_atlas_image = atlas.atlas.get_image()
			if not _check(_atlas_image != null and not _atlas_image.is_empty() and not _atlas_image.has_mipmaps(), "Native atlas is readable and has no generated mipmaps."):
				return false
		if not _atlas_regions.has(expected):
			var image: Image = _atlas_image.get_region(Rect2i(expected))
			if not _check(image.get_used_rect().has_area(), "Exported decoration frame contains non-transparent artwork."):
				return false
			_atlas_regions[expected] = true
		if not _check(prop.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST and is_equal_approx(prop.pixel_size * 19.0, ArenicGridMath.TILE_SIZE), "Decorations use nearest sampling at the same native pixel scale as actors."):
			return false
		if not _check(prop.centered and prop.offset.is_equal_approx(Vector2(0.5, 0.5)) and is_equal_approx(prop.rotation.x, -PI * 0.5), "Even decoration canvases align to the odd-cell raster and face the overhead camera."):
			return false
		if not _check(prop.global_position.y > foreground.global_position.y and prop.global_position.y < 0.01, "Decorations clear the atmosphere while remaining below all actors."):
			return false
		if boss != null and not _check(prop.global_position.y < boss.global_position.y, "Decorative sprites cannot occlude boss art from above."):
			return false
		var canvas_half: float = prop.pixel_size * 38.0
		var prop_bounds := Rect2(Vector2(prop.global_position.x, prop.global_position.z) - Vector2.ONE * canvas_half, Vector2.ONE * canvas_half * 2.0)
		if not _check(ArenicGridMath.arena_rect(arena.definition.grid_slot).encloses(prop_bounds), "Decoration canvases remain inside their own arena."):
			return false
	return true


func _check_instance_isolation() -> bool:
	var packed := load(ARENA_PATH) as PackedScene
	_probe = packed.instantiate() as ArenicArenaView
	_probe.definition = _shell.stage.world.arenas[0]
	root.add_child(_probe)
	_probe.visible = false
	var original := _shell.stage.get_arena(0).get_node("Tiles") as ArenicArenaTiles
	var duplicate := _probe.get_node("Tiles") as ArenicArenaTiles
	var first := original.material_override as ShaderMaterial
	var second := duplicate.material_override as ShaderMaterial
	if not _check(first != second and original.multimesh.mesh == duplicate.multimesh.mesh, "Two instances of the same arena share geometry but never mutable theme materials."):
		return false
	second.set_shader_parameter("identity", 77)
	if not _check(first.get_shader_parameter("identity") == 0, "Changing one scene instance's motif cannot retheme another instance."):
		return false
	_probe.free()
	_probe = null
	return true


func _check_atmosphere_controls() -> bool:
	# Exercise actual arena instances without advancing unrelated simulation.
	_shell.set_zoomed(false)
	_shell.stage.camera_rig.frame_bounds(ArenicGridMath.world_rect(), false)
	_shell.stage._process(0.0)
	var first := _shell.stage.get_arena(0).get_node("EnvironmentLayers") as ArenicArenaEnvironment
	var neighbor := _shell.stage.get_arena(1).get_node("EnvironmentLayers") as ArenicArenaEnvironment
	var first_swarm := first.get_node("Swarm") as MultiMeshInstance3D
	var original_instances: MultiMesh = first_swarm.multimesh
	var original_swarm_material: Material = first_swarm.material_override
	var saved: Array = [
		[first, first.atmosphere_time, first.atmosphere_playing, first.effect_strength],
		[neighbor, neighbor.atmosphere_time, neighbor.atmosphere_playing, neighbor.effect_strength],
	]
	first.atmosphere_playing = false
	neighbor.atmosphere_playing = false
	first.atmosphere_time = 12.5
	neighbor.atmosphere_time = 7.25
	first.effect_strength = 0.25
	neighbor.effect_strength = 0.8
	first._process(0.5)
	neighbor._process(0.5)
	if not _check(is_equal_approx(first.atmosphere_time, 12.5) and is_equal_approx(neighbor.atmosphere_time, 7.25), "Paused atmosphere clocks hold their own authored times."):
		return false
	if not _check_atmosphere_values(first, 12.5, 0.25) or not _check_atmosphere_values(neighbor, 7.25, 0.8):
		return false
	# A seek and a fade must upload even when playback is paused.
	first.atmosphere_time = 94.125
	first.effect_strength = 0.0
	first._process(0.5)
	if not _check(is_equal_approx(first.atmosphere_time, 94.125), "Seeking a paused atmosphere remains stable on the following frame."):
		return false
	if not _check_atmosphere_values(first, 94.125, 0.0) or not _check_atmosphere_values(neighbor, 7.25, 0.8):
		return false
	first.effect_strength = 0.5
	first._process(0.0)
	if not _check_atmosphere_values(first, 94.125, 0.5):
		return false
	first.effect_strength = 1.0
	first._process(0.0)
	if not _check_atmosphere_values(first, 94.125, 1.0):
		return false
	first.effect_strength = -0.25
	first._process(0.0)
	if not _check(is_equal_approx(first.effect_strength, 0.0), "Scripted fade values clamp at the lower bound.") or not _check_atmosphere_values(first, 94.125, 0.0):
		return false
	first.effect_strength = 1.25
	first._process(0.0)
	if not _check(is_equal_approx(first.effect_strength, 1.0), "Scripted fade values clamp at the upper bound.") or not _check_atmosphere_values(first, 94.125, 1.0):
		return false
	first.atmosphere_playing = true
	first._process(0.125)
	if not _check(is_equal_approx(first.atmosphere_time, 94.25), "Resuming advances from the seek position by elapsed seconds."):
		return false
	if not _check_atmosphere_values(first, 94.25, 1.0) or not _check_atmosphere_values(neighbor, 7.25, 0.8):
		return false
	if not _check(is_equal_approx(neighbor.atmosphere_time, 7.25) and not neighbor.atmosphere_playing and is_equal_approx(neighbor.effect_strength, 0.8), "Pause, seek and fade controls do not change a neighboring arena."):
		return false
	if not _check(first_swarm.multimesh == original_instances and first_swarm.material_override == original_swarm_material, "Pause, seek and fade update uniforms without reallocating swarm geometry or materials."):
		return false
	for entry: Array in saved:
		var environment: ArenicArenaEnvironment = entry[0]
		environment.atmosphere_time = entry[1]
		environment.atmosphere_playing = entry[2]
		environment.effect_strength = entry[3]
		environment._process(0.0)
	return true


func _check_atmosphere_values(environment: ArenicArenaEnvironment, expected_time: float, expected_strength: float) -> bool:
	var tiles := environment.get_parent().get_node("Tiles") as ArenicArenaTiles
	var swarm := environment.get_node("Swarm") as MultiMeshInstance3D
	var materials: Dictionary = {"Floor": tiles.material_override, "Swarm": swarm.material_override}
	if not _check(swarm.visible == (expected_strength > 0.0), "Zero strength hides the swarm draw; positive strength restores it."):
		return false
	for layer_name: String in ["Backdrop", "Foreground"]:
		var layer := environment.get_node(layer_name) as MeshInstance3D
		var plane := layer.mesh as PlaneMesh
		materials[layer_name] = plane.material
	for layer_name: String in materials:
		var material: ShaderMaterial = materials[layer_name]
		if not _check(is_equal_approx(float(material.get_shader_parameter("atmosphere_time")), expected_time), "Seek/playback time reaches the arena's " + layer_name + " material."):
			return false
		if not _check(is_equal_approx(float(material.get_shader_parameter("strength")), expected_strength), "Fade strength reaches the arena's " + layer_name + " material."):
			return false
	return true
func _check_overview_labels() -> bool:
	_shell.set_zoomed(false)
	_shell.stage.camera_rig.frame_bounds(ArenicGridMath.world_rect(), false)
	var labels: ArenicWorldLabels = _shell.stage.labels
	labels._process(0.0)
	if not _check(labels.get_child_count() == 9, "Overview builds one compact label stack per arena."):
		return false
	for index: int in range(9):
		var arena: ArenicArenaDefinition = _shell.stage.world.arenas[index]
		var card := labels.get_child(index) as Control
		var title := card.get_node("ArenaName") as Label
		var key := card.get_node("Hotkey") as Label
		var badge := key.get_theme_stylebox("normal") as StyleBoxFlat
		if not _check(card.visible and SAFE_RECT.encloses(card.get_global_rect()), "Overview labels stay within the world band."):
			return false
		if not _check(title.text == arena.display_name and title.get_theme_color("font_color").is_equal_approx(ArenicWorldLabels.title_ink(arena.visual_theme)), "Overview arena title uses its own palette."):
			return false
		if not _check(key.text == arena.hotkey and badge.bg_color.is_equal_approx(arena.visual_theme.color("primary")), "Each hotkey badge has its own arena's accent."):
			return false
		var text_width: float = title.get_theme_font("font").get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, title.get_theme_font_size("font_size")).x
		if not _check(text_width <= title.size.x, "Measured Migra title fits without cropping."):
			return false
	return true


func _check_focused_style(index: int) -> bool:
	_shell.select_arena(index)
	_shell.set_zoomed(true)
	var arena: ArenicArenaView = _shell.stage.get_arena(index)
	var rig: ArenicCameraRig = _shell.stage.camera_rig
	rig.frame_bounds(ArenicGridMath.arena_rect(arena.definition.grid_slot), false)
	_shell.stage.labels._process(0.0)
	var top := _shell.hud.get_node("TopStrip") as Panel
	var bottom := _shell.hud.get_node("BottomStrip") as Panel
	var top_style := top.get_theme_stylebox("panel") as StyleBoxFlat
	var bottom_style := bottom.get_theme_stylebox("panel") as StyleBoxFlat
	if not _check(top_style.bg_color.is_equal_approx(arena.definition.visual_theme.color("base_100")) and bottom_style.bg_color.is_equal_approx(top_style.bg_color), "Selected arena rethemes both persistent HUD strips."):
		return false
	if not _check(_shell.hud.get_world_rect().is_equal_approx(SAFE_RECT), "All nine styles preserve native play-area dimensions."):
		return false
	for card: Node in _shell.stage.labels.get_children():
		if not _check(not (card as Control).visible, "Focused arena view removes every overview label."):
			return false
	for action: String in ["Roster", "Loot", "Auction", "Craft"]:
		var button := bottom.get_node(action) as Button
		if not _check(button.disabled and button.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Unavailable actions remain dormant and do not intercept world input."):
			return false
	var cell_center: Vector3 = ArenicGridMath.tile_to_world(arena.definition.grid_slot, Vector2i(32, 15))
	var screen: Vector2 = rig.world_to_screen(cell_center)
	var next: Vector2 = rig.world_to_screen(cell_center + Vector3(ArenicGridMath.TILE_SIZE, 0.0, 0.0))
	if not _check(absf(screen.distance_to(next) - 19.0) < 0.01, "Every themed arena focuses at exactly nineteen screen pixels per tile."):
		return false
	var prop := arena.get_node("EnvironmentLayers/Decorations/Prop00") as Sprite3D
	var local_top_left := Vector3(prop.offset.x - 38.0, prop.offset.y + 38.0, 0.0) * prop.pixel_size
	var upper_left: Vector2 = rig.world_to_screen(prop.global_transform * local_top_left)
	if not _check(upper_left.distance_to(upper_left.round()) < 0.01, "Native 76px decoration canvas begins on an integer screen pixel."):
		return false
	var hero: ArenicHeroView = _shell.stage.hero_view
	var selection := hero.get_node("Selection") as Sprite3D
	if not _check(hero.sprite.render_priority == 0 and selection.render_priority == 0, "Hero and selection sort above all transparent environment layers."):
		return false
	if not _check(hero.sprite.global_position.y > prop.global_position.y and selection.global_position.y > prop.global_position.y, "Actor and its selection marker remain above decoration layers."):
		return false
	return true


func _check(condition: bool, message: String) -> bool:
	if _done:
		return false
	if Time.get_ticks_msec() - _started_ms >= int(WATCHDOG_SECONDS * 1000.0):
		_finish(1, "Presentation checks exceeded the ten-second watchdog.")
		return false
	_checks += 1
	if not condition:
		_finish(1, "Presentation assertion failed: " + message)
		return false
	return true


func _finish(code: int, message: String) -> void:
	if _done:
		return
	_done = true
	if is_instance_valid(_probe):
		_probe.free()
	if is_instance_valid(_shell):
		_shell.free()
	if is_instance_valid(_watchdog):
		_watchdog.stop()
		_watchdog.queue_free()
	print(message)
	quit(code)
