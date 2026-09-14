extends SceneTree
## Authored DOT boundaries are shared by Doctor and combat acceptance.
var checks: int = 0
var failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("Class ability: " + message)


func _run() -> void:
	var catalog := load("res://data/classes/catalog.tres") as ArenicClassCatalog
	check(catalog.validation_errors().is_empty(), "Every authored class passes the same DOT contract used by Doctor")
	var bard := load("res://data/classes/bard_primary.tres") as ArenicClassAbility
	check(bard.effect_kind == "cleanse" and bard.enemy_dot_duration_seconds == 5.0 and bard.enemy_dot_tick_seconds == 1.0 and bard.enemy_dot_damage == 1, "Bard authors five one-second damage ticks per independent stack")
	var default_ability := ArenicClassAbility.new()
	check(default_ability.enemy_dot_duration_seconds == 0.0 and default_ability.validation_errors().is_empty(), "Unchanged abilities default to disabled DOTs without requiring Cleanse")
	for duration: float in [1.0 / 60.0, 0.024, 5.0, 120.0]:
		var candidate := bard.duplicate() as ArenicClassAbility
		candidate.enemy_dot_duration_seconds = duration
		check(candidate.enemy_dot_error().is_empty(), "Duration %s accepts bounded 60 Hz quantization" % duration)
		check(candidate.enemy_dot_duration_seconds == duration, "Validation never rewrites authored seconds")
	for duration: float in [-0.1, NAN, INF, 120.01, 0.001]:
		var candidate := bard.duplicate() as ArenicClassAbility
		candidate.enemy_dot_duration_seconds = duration
		check(candidate.enemy_dot_error().contains("enemy_dot_duration_seconds"), "Invalid or sub-tick duration %s is rejected before quantization" % duration)
	for interval: float in [0.05, 0.077, 10.0]:
		var candidate := bard.duplicate() as ArenicClassAbility
		candidate.enemy_dot_tick_seconds = interval
		check(candidate.enemy_dot_error().is_empty(), "Interval %s accepts the bounded integer-tick model" % interval)
	for interval: float in [0.0, -1.0, 0.049, 10.01, NAN, INF]:
		var candidate := bard.duplicate() as ArenicClassAbility
		candidate.enemy_dot_tick_seconds = interval
		check(candidate.enemy_dot_error().contains("enemy_dot_tick_seconds"), "Invalid interval %s is rejected" % interval)
	for damage: int in [1, 100]:
		var candidate := bard.duplicate() as ArenicClassAbility
		candidate.enemy_dot_damage = damage
		check(candidate.enemy_dot_error().is_empty(), "Damage %d accepts the authored boundary" % damage)
	for damage: int in [0, 101]:
		var candidate := bard.duplicate() as ArenicClassAbility
		candidate.enemy_dot_damage = damage
		check(candidate.enemy_dot_error().contains("enemy_dot_damage"), "Damage %d outside the authored range is rejected" % damage)
	var unsupported := bard.duplicate() as ArenicClassAbility
	unsupported.effect_kind = "target"
	check(unsupported.enemy_dot_error().contains("cleanse"), "An enabled DOT cannot silently attach to a different effect kind")
	unsupported.enemy_dot_duration_seconds = 0.0
	check(unsupported.validation_errors().is_empty(), "A zero duration explicitly disables DOT behavior for any effect kind")
	unsupported.enemy_dot_damage = 0
	check(not unsupported.validation_errors().is_empty(), "Disabled fields retain valid authored bounds before later Inspector enablement")
	# Catalog entries and skills are external resources inside typed arrays.
	# Copy each mutable level explicitly; duplicate(true) retains those references.
	var invalid_catalog := catalog.duplicate() as ArenicClassCatalog
	invalid_catalog.classes = catalog.classes.duplicate()
	invalid_catalog.classes[0] = catalog.classes[0].duplicate() as ArenicClassDefinition
	invalid_catalog.classes[0].skills = catalog.classes[0].skills.duplicate()
	invalid_catalog.classes[0].skills[0] = catalog.classes[0].skills[0].duplicate() as ArenicClassAbility
	invalid_catalog.classes[0].skills[0].enemy_dot_duration_seconds = 5.0
	invalid_catalog.classes[0].skills[0].effect_kind = "target"
	var errors: PackedStringArray = invalid_catalog.validation_errors()
	check(errors.size() == 1 and errors[0].contains(invalid_catalog.classes[0].class_id) and errors[0].contains("cleanse"), "Catalog validation reports the owning class and shared ability diagnostic")
	check(catalog.validation_errors().is_empty() and bard.enemy_dot_duration_seconds == 5.0, "Invalid in-memory fixtures leave the authored catalog and Bard unchanged")
	print("Class ability checks: %d assertions, %s." % [checks, "FAILED" if failed else "passed"])
	quit(1 if failed else 0)
