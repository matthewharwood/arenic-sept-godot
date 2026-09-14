extends SceneTree
## Disposable build tool: real constructors + the shipping codec, no renderer or
## storage adapter. Browser tests hydrate these through the normal Continue flow.
const SETUP: GDScript = preload("res://scripts/character_creation/run_setup.gd")
const IDS: Array[String] = ["hunter", "bard", "merchant", "warrior", "cardinal", "alchemist", "forager", "thief"]


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Expected fixture output directory")
		quit(1)
		return
	for id: String in IDS:
		if not _write(args[0], id, false):
			quit(1)
			return
	if not _write(args[0], "hunter", true):
		quit(1)
		return
	print("Browser fixtures: 9 canonical documents validated.")
	quit()


func _write(directory: String, id: String, gathering: bool) -> bool:
	var setup: Node = SETUP.new()
	setup.begin_new_game()
	setup.run_seed = 42
	setup.intro_step = ArenicSaveCodec.INTRO_COMPLETE
	setup.choose_class(load("res://data/classes/%s.tres" % id))
	setup.heroes[0].selected = false
	if gathering:
		var definition: ArenicGatheringDefinition = setup.get_gathering().definition
		var source: Vector2i = definition.wood_sources[0]
		for cell: Vector2i in definition.wood_sources:
			if cell.y < source.y:
				source = cell
		setup.heroes[0].cell = source + Vector2i(2, 0)
	setup.get_combat().configure(ArenicSaveCodec.WORLD)
	setup.get_combat().sync_allies(setup.heroes)
	var name: String = id + ("-gathering" if gathering else "")
	var payload := ArenicSaveCodec.capture_run(setup)
	var raw := ArenicSaveDocument.encode({"slot": 0, "run_id": name.sha256_text(),
		"revision": 1, "seed": setup.run_seed, "created_at": 0, "updated_at": 0}, payload)
	setup.free()
	var decoded := ArenicSaveDocument.decode(raw, 0)
	if not decoded.ok:
		push_error("Fixture %s failed: %s" % [name, decoded.error])
		return false
	var file := FileAccess.open(directory.path_join(name + ".json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write fixture " + name)
		return false
	file.store_string(raw)
	file.close()
	return true
