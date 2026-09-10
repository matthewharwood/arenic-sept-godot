extends SceneTree
## Godot --headless --path arenic-game --script res://tests/heroes/hero_checks.gd
## Pure hero state/input checks. No game scene, renderer, autoload, or saved fixture is required.

const TIMEOUT_SECONDS: float = 5.0
const CLASS_IDS: PackedStringArray = ["hunter", "warrior", "thief", "alchemist", "cardinal", "bard", "forager", "merchant"]
const HORIZONTAL_BORDERS: Array = [
	["labyrinth", "guild_house"], ["guild_house", "sanctum"],
	["mountain", "bastion"], ["bastion", "pawnshop"],
	["crucible", "casino"], ["casino", "gala"],
]
const VERTICAL_BORDERS: Array = [
	["labyrinth", "mountain"], ["guild_house", "bastion"], ["sanctum", "pawnshop"],
	["mountain", "crucible"], ["bastion", "casino"], ["pawnshop", "gala"],
]

var _world: ArenicWorldDefinition
var _definition: ArenicClassDefinition
var _watchdog: Timer
var _checks: int = 0
var _crossings: int = 0
var _started_ms: int = 0
var _done: bool = false


func _initialize() -> void:
	_started_ms = Time.get_ticks_msec()
	_run.call_deferred()


func _run() -> void:
	_watchdog = Timer.new()
	_watchdog.one_shot = true
	_watchdog.wait_time = TIMEOUT_SECONDS
	_watchdog.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(_watchdog)
	_watchdog.timeout.connect(_on_timeout)
	_watchdog.start()
	_world = load("res://data/world/arenia.tres") as ArenicWorldDefinition
	if not _check(_world != null and _world.validation_errors().is_empty(), "Existing nine-arena world is valid."):
		return
	if not _check_spawns() or not _check_input() or not _check_steps():
		return
	if not _check_crossings() or not _check_borders() or not _check_invalid():
		return
	_finish(0, "Hero checks passed: %d assertions; all eight class identities and %d directed arena crossings." % [_checks, _crossings])


func _check_spawns() -> bool:
	for id in CLASS_IDS:
		var chosen := load("res://data/classes/%s.tres" % id) as ArenicClassDefinition
		if not _check(chosen != null and chosen.class_id == id, "Matching %s class resource loads." % id):
			return false
		var hero := ArenicHeroState.new()
		hero.definition = chosen
		if not _check(hero.arena_id == "guild_house" and hero.cell == Vector2i(30, 15) and hero.facing == "n" and hero.selected, "%s starts selected in Guild House at (30,15), facing north." % id):
			return false
		if not _step(hero, Vector2i(1, 0), "guild_house", Vector2i(31, 15), true, "e"):
			return false
		if not _check(hero.definition == chosen, "Moving preserves the chosen %s class resource." % id):
			return false
		if id == "hunter":
			_definition = chosen
	return true


func _check_input() -> bool:
	var input := ArenicHeroInput.new()
	if not _check(input.accept(_key(KEY_RIGHT)) and input.consume() == Vector2i(1, 0), "A new right press creates one tile intent."):
		return false
	if not _check(input.consume() == Vector2i.ZERO, "Consuming clears intent; an idle/held tick does not repeat."):
		return false
	if not _check(not input.accept(_key(KEY_RIGHT, true, true)) and not input.accept(_key(KEY_RIGHT, false)) and input.consume() == Vector2i.ZERO, "OS echoes and releases create no movement."):
		return false
	input.accept(_key(KEY_UP))
	input.accept(_key(KEY_RIGHT))
	if not _check(input.consume() == Vector2i(1, 1), "Two axes pressed together produce one diagonal intent."):
		return false
	for key in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
		input.accept(_key(key))
	if not _check(input.consume() == Vector2i.ZERO, "Opposite presses cancel on both axes."):
		return false
	input.accept(_key(KEY_LEFT))
	input.accept(_key(KEY_LEFT))
	if not _check(input.consume() == Vector2i(-1, 0), "Multiple same-direction events before consumption stay bounded to one step."):
		return false
	input.accept(_key(KEY_DOWN))
	input.clear()
	if not _check(input.consume() == Vector2i.ZERO, "Clearing on an input-owner change discards pending movement."):
		return false
	var modified: InputEventKey = _key(KEY_RIGHT)
	modified.ctrl_pressed = true
	if not _check(not input.accept(modified) and not input.accept(_key(KEY_ESCAPE)) and input.consume() == Vector2i.ZERO, "Modified shortcuts and nonmovement keys do not become steps."):
		return false
	var physical: InputEventKey = _key(KEY_RIGHT)
	physical.physical_keycode = KEY_LEFT
	return _check(input.accept(physical) and input.consume() == Vector2i(-1, 0), "Physical arrow identity takes precedence over a conflicting logical code.")


func _check_steps() -> bool:
	var examples: Array = [
		[Vector2i(1, 0), Vector2i(31, 15), "e"], [Vector2i(-1, 0), Vector2i(29, 15), "w"],
		[Vector2i(0, 1), Vector2i(30, 16), "n"], [Vector2i(0, -1), Vector2i(30, 14), "s"],
		[Vector2i(1, 1), Vector2i(31, 16), "n"], [Vector2i(-1, 1), Vector2i(29, 16), "n"],
		[Vector2i(1, -1), Vector2i(31, 14), "s"], [Vector2i(-1, -1), Vector2i(29, 14), "s"],
	]
	for example in examples:
		if not _step(_hero(), example[0], "guild_house", example[1], true, example[2]):
			return false
	var repeated: ArenicHeroState = _hero()
	if not _step(repeated, Vector2i(1, 0), "guild_house", Vector2i(31, 15), true, "e"):
		return false
	return _step(repeated, Vector2i(1, 0), "guild_house", Vector2i(32, 15), true, "e")


func _check_crossings() -> bool:
	# Twelve shared borders, each checked in both directions: 24 directed crossings.
	for border in HORIZONTAL_BORDERS:
		if not _step(_hero(border[0], Vector2i(65, 15)), Vector2i(1, 0), border[1], Vector2i(0, 15), true, "e"):
			return false
		if not _step(_hero(border[1], Vector2i(0, 15)), Vector2i(-1, 0), border[0], Vector2i(65, 15), true, "w"):
			return false
		_crossings += 2
	for border in VERTICAL_BORDERS:
		if not _step(_hero(border[0], Vector2i(30, 0)), Vector2i(0, -1), border[1], Vector2i(30, 30), true, "s"):
			return false
		if not _step(_hero(border[1], Vector2i(30, 30)), Vector2i(0, 1), border[0], Vector2i(30, 0), true, "n"):
			return false
		_crossings += 2
	return true


func _check_borders() -> bool:
	for id in ["labyrinth", "mountain", "crucible"]:
		if not _step(_hero(id, Vector2i(0, 15)), Vector2i(-1, 0), id, Vector2i(0, 15), false, "n"):
			return false
	for id in ["sanctum", "pawnshop", "gala"]:
		if not _step(_hero(id, Vector2i(65, 15)), Vector2i(1, 0), id, Vector2i(65, 15), false, "n"):
			return false
	for id in ["labyrinth", "guild_house", "sanctum"]:
		if not _step(_hero(id, Vector2i(30, 30)), Vector2i(0, 1), id, Vector2i(30, 30), false, "n"):
			return false
	for id in ["crucible", "casino", "gala"]:
		if not _step(_hero(id, Vector2i(30, 0)), Vector2i(0, -1), id, Vector2i(30, 0), false, "n"):
			return false
	var corners: Array = [
		["bastion", Vector2i(65, 30), Vector2i(1, 1), "pawnshop", Vector2i(0, 30), true, "n"],
		["bastion", Vector2i(0, 30), Vector2i(-1, 1), "mountain", Vector2i(65, 30), true, "n"],
		["bastion", Vector2i(65, 0), Vector2i(1, -1), "pawnshop", Vector2i(0, 0), true, "s"],
		["bastion", Vector2i(0, 0), Vector2i(-1, -1), "mountain", Vector2i(65, 0), true, "s"],
		["mountain", Vector2i(0, 30), Vector2i(-1, 1), "labyrinth", Vector2i(0, 0), true, "n"],
		["pawnshop", Vector2i(65, 0), Vector2i(1, -1), "gala", Vector2i(65, 30), true, "s"],
		["labyrinth", Vector2i(0, 15), Vector2i(-1, 1), "labyrinth", Vector2i(0, 16), true, "n"],
		["labyrinth", Vector2i(0, 30), Vector2i(-1, 1), "labyrinth", Vector2i(0, 30), false, "n"],
		["sanctum", Vector2i(65, 30), Vector2i(1, 1), "sanctum", Vector2i(65, 30), false, "n"],
		["crucible", Vector2i(0, 0), Vector2i(-1, -1), "crucible", Vector2i(0, 0), false, "n"],
		["gala", Vector2i(65, 0), Vector2i(1, -1), "gala", Vector2i(65, 0), false, "n"],
	]
	for example in corners:
		if not _step(_hero(example[0], example[1]), example[2], example[3], example[4], example[5], example[6]):
			return false
	return true


func _check_invalid() -> bool:
	for direction in [Vector2i.ZERO, Vector2i(2, 0), Vector2i(-2, 1), Vector2i(0, 2), Vector2i(1, -2)]:
		if not _reject(_hero(), direction, _world, "Zero or oversized intent is rejected without mutation."):
			return false
	if not _reject(_hero(), Vector2i(1, 0), null, "Missing world is rejected."):
		return false
	if not _reject(_hero("missing"), Vector2i(1, 0), _world, "Unknown current arena is rejected."):
		return false
	for cell in [Vector2i(-1, 15), Vector2i(66, 15), Vector2i(30, -1), Vector2i(30, 31)]:
		if not _reject(_hero("guild_house", cell), Vector2i(1, 0), _world, "Invalid current cell is rejected rather than repaired by movement."):
			return false
	var missing_class: ArenicHeroState = _hero()
	missing_class.definition = null
	if not _reject(missing_class, Vector2i(1, 0), _world, "An incomplete hero without a class cannot move."):
		return false
	var incomplete_world := ArenicWorldDefinition.new()
	for arena in _world.arenas:
		if arena.arena_id != "sanctum":
			incomplete_world.arenas.append(arena)
	return _reject(_hero("guild_house", Vector2i(65, 15)), Vector2i(1, 0), incomplete_world, "A missing destination rejects crossing atomically.")


func _hero(arena_id: String = "guild_house", cell: Vector2i = Vector2i(30, 15)) -> ArenicHeroState:
	var hero := ArenicHeroState.new()
	hero.definition = _definition
	hero.arena_id = arena_id
	hero.cell = cell
	return hero


func _key(code: Key, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	event.echo = echo
	return event


func _step(hero: ArenicHeroState, direction: Vector2i, arena_id: String, cell: Vector2i, changed: bool, facing: String) -> bool:
	var before: Array = _snapshot(hero)
	var result: bool = hero.step(direction, _world)
	return _check(result == changed and hero.arena_id == arena_id and hero.cell == cell and hero.facing == facing and hero.definition == before[0] and hero.selected == before[4], "Step %s from %s/%s lands at %s/%s; changed=%s, facing=%s, identity/selection preserved." % [direction, before[1], before[2], arena_id, cell, changed, facing])


func _reject(hero: ArenicHeroState, direction: Vector2i, world: ArenicWorldDefinition, message: String) -> bool:
	var before: Array = _snapshot(hero)
	return _check(not hero.step(direction, world) and _snapshot(hero) == before, message)


func _snapshot(hero: ArenicHeroState) -> Array:
	return [hero.definition, hero.arena_id, hero.cell, hero.facing, hero.selected]


func _check(condition: bool, message: String) -> bool:
	if _done:
		return false
	if Time.get_ticks_msec() - _started_ms >= int(TIMEOUT_SECONDS * 1000.0):
		_on_timeout()
		return false
	_checks += 1
	if not condition:
		_finish(1, "Hero assertion failed: " + message)
		return false
	return true


func _on_timeout() -> void:
	_finish(1, "Hero checks exceeded the five-second watchdog.")


func _finish(code: int, message: String) -> void:
	if _done:
		return
	_done = true
	_watchdog.stop()
	_watchdog.queue_free()
	print(message)
	quit(code)
