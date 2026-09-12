class_name ArenicSaveSeed
extends RefCounted
## Deterministic development fixture, constructed through normal domain APIs
## and persisted through the same codec and backend as a player-created run.
const DEFINITION: String = "res://data/dev/founders_v1.json"


static func apply(run: Node, seed_value: int) -> PackedStringArray:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DEFINITION))
	if not valid_definition(data):
		return PackedStringArray(["Invalid development seed definition."])
	if seed_value < 1 or seed_value > 2147483647:
		return PackedStringArray(["Development seed must be between 1 and 2147483647."])
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var classes: Array[ArenicClassDefinition] = run.class_catalog().classes
	run.begin_new_game()
	run.run_seed = seed_value
	run.choose_class(classes[rng.randi_range(0, classes.size() - 1)])
	for index: int in range(1, int(data.roster_size)):
		var hero: ArenicHeroState = run.recruit(classes[rng.randi_range(0, classes.size() - 1)])
		hero.cell = Vector2i(int(data.starting_cell[0]) + index, int(data.starting_cell[1]))
	run.prospected = int(data.prospected)
	return ArenicSaveCodec.validate(ArenicSaveCodec.capture_run(run))


static func valid_definition(data: Variant) -> bool:
	if not data is Dictionary or data.size() != 4 or data.get("version") != 1 or not ArenicSaveDocument._integer(data.get("roster_size"), 1, 8):
		return false
	var earnings: Variant = data.get("prospected")
	var cell: Variant = data.get("starting_cell")
	return earnings is String and earnings.is_valid_int() and int(earnings) >= 0 and str(int(earnings)) == earnings and cell is Array and cell.size() == 2 and ArenicSaveDocument._integer(cell[0], 0, ArenicGridMath.GRID_WIDTH - 8) and ArenicSaveDocument._integer(cell[1], 0, ArenicGridMath.GRID_HEIGHT - 1)
