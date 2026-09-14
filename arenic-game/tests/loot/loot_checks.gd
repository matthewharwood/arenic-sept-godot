extends SceneTree
var checks: int = 0
var failed: bool = false

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failed = true
		push_error("Loot: " + message)

func _run() -> void:
	var loot := ArenicLootState.new()
	check(ArenicLootState.TABLE.validation_errors().is_empty(), "All 100 original items and six authored probability rows validate")
	check(loot.complete_cycle("guild_house", 100, 1).is_empty(), "Training damage never creates equipment")
	check(loot.complete_cycle("sanctum", 0, 1).is_empty(), "Empty natural cycle creates no equipment")
	loot.observe_cycle_progress("sanctum", 0, 1, false, 7200)
	check(loot.complete_cycle("sanctum", 0, 2).is_empty(), "Participating without positive combat damage creates no equipment")
	loot.observe_cycle_progress("sanctum", 20, 0, false, 7200)
	check(loot.complete_cycle("sanctum", 20, 3).is_empty(), "Damage without participating heroes creates no equipment")
	loot.observe_cycle_progress("sanctum", 40, 1, false, 3600)
	var partial: Dictionary = JSON.parse_string(JSON.stringify(loot.snapshot()))
	var restored := ArenicLootState.new()
	restored.restore(partial)
	loot.observe_cycle_progress("sanctum", 60, 1, false, 3600)
	restored.observe_cycle_progress("sanctum", 60, 1, false, 3600)
	check(not loot.complete_cycle("sanctum", 60, 4).is_empty(), "A natural positive-damage cycle awards exactly one banked card draw")
	restored.complete_cycle("sanctum", 60, 4)
	check(loot.snapshot() == restored.snapshot(), "Partial-cycle reload preserves damage baseline and future work exactly")
	check(loot.completed_damage == 40 and loot.completed_hero_ticks == 7200, "Completed progression includes only this eligible cycle")
	check(loot.complete_cycle("sanctum", 60, 4).is_empty() and loot.pending_count() == 1, "Duplicate cycle completion cannot duplicate its reward")
	var before: Dictionary = loot.peek(42)
	check(before.cards.size() == 3 and before.cards[0].id != before.cards[1].id and before.cards[1].id != before.cards[2].id and before.cards[0].id != before.cards[2].id, "Each unopened reward has three distinct concealed equipment outcomes")
	loot.observe_cycle_progress("sanctum", 80, 1, false, 3600)
	loot.reset_cycle("sanctum", 80, 5)
	check(loot.pending_count() == 1 and loot.completed_damage == 40, "Manual restart discards partial work without issuing equipment")
	check(loot.peek(42) == before and restored.peek(42) == before, "Later, reset, and JSON reload cannot reroll an earned draw")
	check(loot.peek(43).cards != before.cards, "Run seed participates in deterministic equipment draws")
	check(loot.claim(before.token, -1, 42).is_empty() and loot.pending_count() == 1, "Out-of-range card clicks cannot consume a reward")
	var receipt: Dictionary = loot.claim(before.token, 1, 42)
	check(receipt == before.cards[1] and loot.pending_count() == 0, "Choosing a card awards that single equipment outcome")
	check(loot.inventory_rows().size() == 1 and loot.inventory_rows()[0].count == 1 and loot.claimed_count() == 1, "Claimed equipment is aggregated by bounded catalog identity")
	check(loot.claim(before.token, 0, 42).is_empty() and loot.claimed_count() == 1, "A stale/double click cannot award a second item")
	var late := ArenicLootState.new()
	late.completed_damage = 2000000
	late.completed_hero_ticks = 46080000
	late.completed_full_ticks = 23040000
	check(late.quality_band(false) == 4 and late.quality_band(true) == 5, "Ultimate rarity requires all eight arenas currently fully deployed")
	late.completed_full_ticks -= 1
	check(late.quality_band(true) == 4, "One tick short of ten full-deployment waves cannot access Mythic")
	var rarity_counts: Array[int] = [0, 0, 0, 0, 0, 0]
	for ordinal: int in 1000:
		for item: Dictionary in late._draw("loot-v1:sanctum:0:%d" % ordinal, 0, 42):
			rarity_counts[ArenicLootTable.RARITIES.find(item.rarity)] += 1
	check(rarity_counts[3] == 0 and rarity_counts[4] == 0 and rarity_counts[5] == 0, "Early reward draws cannot produce Epic, Legendary, or Mythic equipment")
	check(rarity_counts[0] > 2300 and rarity_counts[1] > 350 and rarity_counts[2] > 10, "Fixed early seed sample reflects common/magic-heavy authored odds")
	_check_codec()
	print("Loot checks: %d assertions, %s." % [checks, "FAILED" if failed else "passed"])
	quit(1 if failed else 0)

func _check_codec() -> void:
	var run: Node = root.get_node("RunSetup")
	run.begin_new_game()
	run.choose_class(ArenicSaveCodec.CLASSES.classes[0])
	run.intro_step = ArenicSaveCodec.INTRO_COMPLETE
	var combat: ArenicCombatState = run.get_combat()
	combat.configure(ArenicSaveCodec.WORLD)
	combat.sync_allies(run.heroes)
	var enemy: String = ArenicCombatState.boss_enemy_id("sanctum")
	combat.register_enemy("sanctum", enemy, Rect2i(29, 12, 6, 6))
	combat.apply_hazard_damage("sanctum", enemy, 40)
	var loot: ArenicLootState = run.get_loot()
	loot.observe_cycle_progress("sanctum", 40, 1, false, 7200)
	loot.complete_cycle("sanctum", 40, 1)
	var offer: Dictionary = loot.peek(run.run_seed)
	loot.claim(offer.token, 2, run.run_seed)
	combat.apply_hazard_damage("sanctum", enemy, 5)
	loot.observe_cycle_progress("sanctum", 45, 1, false, 300)
	var payload: Dictionary = ArenicSaveCodec.capture_run(run)
	check(ArenicSaveCodec.validate(payload).is_empty(), "Current schema accepts a claimed reward and exact partial-cycle work")
	check(ArenicSaveCodec.restore_run(JSON.parse_string(JSON.stringify(payload)), run), "Equipment and pending work restore through the shared model codec")
	check(run.get_loot().snapshot() == payload.run.loot, "All authoritative equipment state survives JSON exactly")
	for mutation: String in ["unknown_item", "overclaimed", "extra_arena", "missing_arena", "substituted_arena", "unearned_work", "future_revision", "baseline", "overflow", "wrong_inventory_total", "full_work", "unknown_field", "numeric_count", "uneared_band"]:
		var bad: Dictionary = payload.duplicate(true)
		match mutation:
			"unknown_item": bad.run.loot.inventory = {"missing_item": "1"}
			"overclaimed": bad.run.loot.arenas.sanctum.claimed[0] = "2"
			"extra_arena": bad.run.loot.arenas.guild_house = bad.run.loot.arenas.sanctum
			"missing_arena": bad.run.loot.arenas.erase("gala")
			"substituted_arena":
				bad.run.loot.arenas.guild_house = bad.run.loot.arenas.gala
				bad.run.loot.arenas.erase("gala")
			"unearned_work": bad.run.loot.hero_ticks = "2304001"
			"future_revision": bad.run.loot.revision = "loot-v2"
			"baseline": bad.run.loot.arenas.sanctum.baseline = "46"
			"overflow": bad.run.loot.cycles = "9223372036854775808"
			"wrong_inventory_total": bad.run.loot.inventory = {}
			"full_work": bad.run.loot.arenas.sanctum.full_ticks = "301"
			"unknown_field": bad.run.loot.equipped = true
			"numeric_count": bad.run.loot.cycles = 1
			"uneared_band": bad.run.loot.arenas.sanctum.earned[5] = "1"
		var before: Dictionary = run.get_loot().snapshot()
		check(not ArenicSaveCodec.restore_run(bad, run) and run.get_loot().snapshot() == before, "Malformed loot fails transactionally: " + mutation)
	var legacy: Dictionary = payload.duplicate(true)
	legacy.schema_version = 10
	legacy.run.erase("loot")
	var old_fingerprint: String = legacy.run.combat.encounter.fingerprint
	var migrated: Dictionary = ArenicSaveMigrations.upgrade(legacy)
	check(migrated.ok and migrated.payload.schema_version == 11, "Released schema10 has an explicit validated equipment migration")
	if migrated.ok:
		check(migrated.payload.run.loot.cycles == "0" and migrated.payload.run.loot.arenas.sanctum.baseline == "45", "Migration creates no retroactive reward and starts from existing damage")
		check(migrated.payload.run.combat.encounter.fingerprint == old_fingerprint, "Equipment migration preserves committed combat content identity")
	legacy.run.loot = payload.run.loot
	check(not ArenicSaveMigrations.upgrade(legacy).ok, "Old schema cannot smuggle future reward state")
