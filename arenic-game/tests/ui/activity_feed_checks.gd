extends SceneTree
## Real event messages, bounded projection, then the owning shell's adapters.
const WORLD: ArenicWorldDefinition = preload("res://data/world/arenia.tres")
const RETIRE_AUDIO: GDScript = preload("res://tests/support/audio_retirement.gd")
var checks: int = 0
var failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("Activity feed: " + message)


func _run() -> void:
	create_timer(30.0).timeout.connect(func():
		push_error("Activity feed checks timed out")
		quit(1))
	var bus := ArenicEventBus.new()
	var feed := ArenicActivityFeed.new()
	feed.configure(WORLD)
	feed.bind(bus)
	check(feed.entries.is_empty() and feed.attention.is_empty(), "Fresh feed invents no history")
	for hit: int in 1000:
		bus.dispatch(_damage("guild_house", 1))
	check(feed.entries.is_empty(), "Individual hits do not append individual rows")
	feed.advance(0.99)
	check(feed.entries.is_empty(), "Damage waits for its bounded aggregation window")
	feed.advance(0.01)
	check(feed.entries.size() == 1 and feed.entries[0].text == "Dean · Auto Shot · 1000 damage · Guild House", "One thousand hits retain the exact hero and attack total")
	check(feed.entries[0].kind == "damage" and feed.entries[0].severity == ArenicGameEvent.Severity.DEBUG and feed.entries[0].importance == ArenicGameEvent.Importance.LOW, "Damage is low importance without losing severity metadata")
	feed.advance(5.0)
	check(feed.entries.size() == 1, "Empty windows never invent damage")
	for arena: ArenicArenaDefinition in WORLD.arenas:
		bus.dispatch(_damage(arena.arena_id, 2))
	bus.dispatch(_damage("unknown", 99))
	check(feed._pending_damage.size() == 9, "The same source in nine known arenas keeps nine separate totals")
	feed.advance(1.0)
	check(feed.entries.size() == 10, "One summary is emitted for each active arena")
	bus.dispatch(_damage("guild_house", 7))
	feed.configure(null)
	feed.advance(1.0)
	check(feed._pending_damage.is_empty() and feed.entries.size() == 10, "Removing world configuration drops pending damage without looking up missing arena names")
	feed.configure(WORLD)
	bus.dispatch(ArenicGameEvent.create(&"recruit.ready", {"available": 2}, ArenicGameEvent.Severity.INFO, ArenicGameEvent.Importance.HIGH))
	var attention_sequence: int = feed.attention.sequence
	check(feed.attention.text.contains("2 heroes") and feed.attention.severity == ArenicGameEvent.Severity.INFO and feed.attention.importance == ArenicGameEvent.Importance.HIGH, "Important recruitment remains informational, not an error")
	var size_before: int = feed.entries.size()
	bus.dispatch(ArenicGameEvent.create(&"recruit.ready", {"available": 2}))
	check(feed.entries.size() == size_before and feed.attention.sequence == attention_sequence, "Unchanged readiness cannot repeat a notification")
	bus.dispatch(ArenicGameEvent.create(&"recruit.ready", {"available": 1}, ArenicGameEvent.Severity.INFO, ArenicGameEvent.Importance.HIGH))
	check(feed.entries.size() == size_before and feed.attention.text.contains("1 hero is"), "Claiming updates current attention without a new reward row")
	bus.dispatch(ArenicGameEvent.create(&"recruit.ready", {"available": 0}))
	check(feed.attention.is_empty(), "Claiming the last available roll clears recruitment attention")
	bus.dispatch(ArenicGameEvent.create(&"recruit.ready", {"available": 1}, ArenicGameEvent.Severity.INFO, ArenicGameEvent.Importance.HIGH))
	check(feed.entries.size() == size_before + 1, "A newly earned roll after a claim notifies again")
	for notice: int in 130:
		bus.dispatch(ArenicGameEvent.create(&"notice", {"text": "Status %d" % notice}))
	check(feed.entries.size() == ArenicActivityFeed.MAX_ENTRIES and feed.entries[0].text == "Status 30", "History retains exactly the newest 100 rows")
	check(not feed.attention.is_empty(), "Routine activity cannot bury an unclaimed recruitment reward")
	var last_sequence: int = feed.entries[-1].sequence
	for event: ArenicGameEvent in [
		ArenicGameEvent.create(&"raid.damage", {"arena_id": "guild_house", "amount": -1}),
		ArenicGameEvent.create(&"recruit.ready", {"available": "2"}),
		ArenicGameEvent.create(&"hero.defeated", {"hero_id": 999, "hero_name": "Ghost", "arena_id": "guild_house", "recorded": false}),
		ArenicGameEvent.create(&"recording.status", {"hero_id": 0, "hero_name": "Hero", "arena_id": "guild_house", "status": "enraged"}),
		ArenicGameEvent.create(&"future.event", {"text": "Unknown future consumers remain independent"}),
	]:
		bus.dispatch(event)
	feed.advance(1.0)
	check(feed.entries[-1].sequence == last_sequence and feed._pending_damage.is_empty(), "Malformed and unknown events leave this consumer untouched")
	feed.unbind()
	bus.dispatch(ArenicGameEvent.create(&"notice", {"text": "After teardown"}))
	check(feed.entries[-1].sequence == last_sequence, "Teardown unsubscribes the feed")
	_check_damage_attribution()
	_check_ready_projection()
	await _check_shell()
	print("Activity feed checks: %d assertions, %s." % [checks, "FAILED" if failed else "passed"])
	quit(1 if failed else 0)


func _damage(arena_id: String, amount: int, hero_id: int = 0, hero_name: String = "Dean", ability_id: String = "auto_shot", ability_name: String = "Auto Shot") -> ArenicGameEvent:
	return ArenicGameEvent.create(&"raid.damage", {"arena_id": arena_id, "amount": amount, "hero_id": hero_id,
		"hero_name": hero_name, "ability_id": ability_id, "ability_name": ability_name}, ArenicGameEvent.Severity.DEBUG, ArenicGameEvent.Importance.LOW)


func _check_damage_attribution() -> void:
	var feed := ArenicActivityFeed.new()
	feed.configure(WORLD)
	feed.consume(_damage("labyrinth", 2))
	feed.consume(_damage("labyrinth", 3))
	feed.consume(_damage("labyrinth", 4, 1, "King"))
	feed.consume(_damage("labyrinth", 7, 0, "Dean", "bash", "Bash"))
	feed.advance(1.0)
	check(feed.entries.size() == 3, "Different heroes and attacks never collapse into one arena total")
	var totals: Dictionary = {}
	for entry: Dictionary in feed.entries:
		totals["%d/%s" % [entry.hero_id, entry.ability_id]] = entry.amount
	check(totals == {"0/auto_shot": 5, "1/auto_shot": 4, "0/bash": 7}, "Attributed totals preserve exact source identity and attack")
	feed.consume(_damage("guild_house", 2, -1, "", "acid_flask", "Acid Flask"))
	feed.consume(_damage("guild_house", 1, -1, "", "environment", "Environment"))
	feed.advance(1.0)
	check(feed.entries[-2].text == "Unknown hero · Acid Flask · 2 damage · Guild House", "Legacy hazard ownership is explicitly unknown instead of borrowing the selected hero")
	check(feed.entries[-1].text == "Environment · 1 damage · Guild House", "Unattributed environmental damage does not invent a hero or attack")
	feed.consume(_damage("labyrinth", 1, 3, "A\nLong\tName", "auto_shot", "Auto\u2028\u2029Shot"))
	feed.advance(1.0)
	check(feed.entries[-1].text.begins_with("A Long Name · Auto Shot"), "Source labels cannot insert extra compact feed rows")
	for event: ArenicGameEvent in [_damage("guild_house", -1), _damage("guild_house", 1, 320),
		_damage("guild_house", 1, -1, "Pretend hero"), _damage("guild_house", 1, 0, ""),
		_damage("guild_house", 1, 0, "Dean", ""), _damage("guild_house", 1, 0, "Dean", "auto_shot", "")]:
		feed.consume(event)
	var malformed := _damage("guild_house", 1, -1, "")
	malformed.payload.hero_name = 1
	feed.consume(malformed)
	check(feed._pending_damage.is_empty(), "Malformed attribution never enters the aggregation queue")
	feed.consume(_damage("labyrinth", ArenicActivityFeed.MAX_TOTAL))
	feed.consume(_damage("labyrinth", 1))
	feed.advance(1.0)
	check(feed.entries[-1].amount == ArenicActivityFeed.MAX_TOTAL, "Presentation aggregation saturates without overflowing a damage total")
	feed = ArenicActivityFeed.new()
	feed.configure(WORLD)
	for identity: int in range(ArenicActivityFeed.MAX_PENDING_DAMAGE + 1):
		feed.consume(_damage("guild_house", 1, identity, "Hero %d" % identity))
	check(feed._pending_damage.size() == 1 and feed.entries.size() == ArenicActivityFeed.MAX_ENTRIES, "A full source queue flushes before accepting another hero without merging identities")
	feed.advance(1.0)
	check(feed._pending_damage.is_empty() and feed.entries.size() == ArenicActivityFeed.MAX_ENTRIES and feed.entries[-1].hero_id == ArenicActivityFeed.MAX_PENDING_DAMAGE, "Burst history remains bounded while the latest source is retained")


func _check_ready_projection() -> void:
	var bus := ArenicEventBus.new()
	var feed := ArenicActivityFeed.new()
	feed.configure(WORLD)
	feed.bind(bus)
	var view := ArenicActivityFeedView.new()
	root.add_child(view)
	view.set_feed(feed)
	bus.dispatch(ArenicGameEvent.create(&"recruit.ready", {"available": 1}, ArenicGameEvent.Severity.INFO, ArenicGameEvent.Importance.HIGH))
	view._refresh()
	check(" ".join(view.snapshot().lines).contains("ready to recruit"), "Compact feed shows current recruitment availability")
	bus.dispatch(ArenicGameEvent.create(&"recruit.ready", {"available": 0}, ArenicGameEvent.Severity.INFO, ArenicGameEvent.Importance.HIGH))
	view._refresh()
	check(feed.attention.is_empty() and not " ".join(view.snapshot().lines).contains("ready to recruit"), "Claiming the last roll cannot expose an obsolete compact recruitment reminder")
	check(feed.entries.size() == 1 and feed.entries[0].event_type == "recruit.ready", "Clearing current attention retains the historical recruitment event")
	view.toggle_expanded()
	view._refresh()
	check(view._history.get_parsed_text().contains("1 hero is ready to recruit"), "Expanded history still includes the past recruitment event")
	feed.unbind()
	root.remove_child(view)
	view.free()


func _check_shell() -> void:
	var run: Node = root.get_node("RunSetup")
	var saves: Node = root.get_node("SaveGames")
	if not saves.storage_ready:
		await saves.initialized
	saves.active_slot = -1
	run.begin_new_game()
	run.intro_step = 6 # Established gameplay fixture; prologue is tested separately.
	run.choose_class(load("res://data/classes/hunter.tres"))
	# Preserve this fixture’s released one-HP encounter contract.
	run.combat.encounter_effects.ruleset = ArenicActorEffects.LEGACY
	# Seed an existing ledger without broadcasting old hits. Hydration must show
	# the currently available roll, not pretend that the run just dealt damage.
	run.prospected = 120
	var shell: Variant = load("res://scenes/game/game_shell.tscn").instantiate()
	root.add_child(shell)
	shell.set_physics_process(false)
	shell.set_process(false)
	shell.music.set_process(false)
	var feed: ArenicActivityFeed = shell.activity_feed
	var view: Variant = shell.hud._chat
	check(not feed.attention.is_empty(), "Restored/current recruitment readiness appears on initial bind")
	var important: Dictionary = feed.attention.duplicate(true)
	check(view._entry_color(important) == ArenicHudTokens.color("alert", view._visual_theme) and not view._entry_text(important).contains("Error"), "INFO/HIGH recruitment uses alert emphasis without an error label")
	check(_count(feed, "damage") == 0, "Initialization does not replay historical damage")
	var count_before: int = feed.entries.size()
	for refresh: int in 3:
		shell._update_hud()
		shell._publish_recruitment()
	check(feed.entries.size() == count_before, "Ordinary HUD refreshes do not re-notify readiness")
	var expected_before: Dictionary = ArenicSaveCodec.capture_run(run, shell)
	shell.events.dispatch(ArenicGameEvent.create(&"notice", {"text": "Display-only event"}, ArenicGameEvent.Severity.WARNING))
	feed.advance(1.0)
	check(JSON.stringify(ArenicSaveCodec.capture_run(run, shell)) == JSON.stringify(expected_before), "Event dispatch and feed clocks never mutate serialized gameplay")
	saves._fail("Local test write failed.\nRetry.")
	var error_entry: Dictionary = feed.entries[-1]
	check(error_entry.severity == ArenicGameEvent.Severity.ERROR and error_entry.importance == ArenicGameEvent.Importance.HIGH and not error_entry.text.contains("\n"), "Facade failures publish a sanitized ERROR/HIGH event")
	check(view._entry_color(error_entry) == ArenicHudTokens.color("alert", view._visual_theme) and view._entry_text(error_entry).begins_with("Error"), "Software errors remain distinct from important rewards")
	var error_rows: int = feed.entries.size()
	saves._fail("Local test write failed.\nRetry.")
	check(feed.entries.size() == error_rows, "Repeated identical failures do not spam the activity feed")
	saves.last_error = ""
	saves.status_changed.emit("Saved")
	check(feed.entries[-1].severity == ArenicGameEvent.Severity.INFO and feed.entries[-1].text.contains("recovered"), "A successful save after failure reports recovery")
	shell.combat.register_enemy("guild_house", "feed_fixture", Rect2i(35, 15, 1, 1))
	shell.combat.apply_hazard_damage("guild_house", "feed_fixture", 3)
	shell.combat.apply_hazard_damage("guild_house", "feed_fixture", 4)
	feed.advance(1.0)
	check(_count(feed, "damage") == 1 and feed.entries[-1].text.contains("7 damage"), "Accepted combat damage reaches the feed through the actual shell adapter")
	var damage_entry: Dictionary = feed.entries[-1]
	check(view._entry_color(damage_entry) == ArenicHudTokens.color("debug", view._visual_theme), "Routine damage uses the subdued debug color")
	view._filter.select(1)
	check(not view._matches_filter(damage_entry) and view._matches_filter(important), "Info filter hides debug damage while retaining important recruitment")
	view._filter.select(2)
	check(not view._matches_filter(important) and view._matches_filter(error_entry), "Warnings/errors filter uses severity instead of importance")
	view._filter.select(3)
	check(view._matches_filter(important) and not view._matches_filter(damage_entry), "Important filter uses importance independently of severity")
	view._filter.select(0)
	var input := InputEventKey.new()
	input.keycode = KEY_C
	input.pressed = true
	input.ctrl_pressed = true
	shell._unhandled_input(input)
	check(not shell.hud.is_chat_expanded(), "Modified C does not take over an application shortcut")
	input.ctrl_pressed = false
	shell._unhandled_input(input)
	check(shell.hud.is_chat_expanded(), "C opens the actual activity history")
	var was_zoomed: bool = shell.zoomed
	input.keycode = KEY_ESCAPE
	shell._unhandled_input(input)
	check(not shell.hud.is_chat_expanded() and shell.zoomed == was_zoomed, "Escape closes history before changing camera mode")
	var same_feed: ArenicActivityFeed = shell.activity_feed
	shell.replace_stage(shell.stage_scene)
	check(shell.activity_feed == same_feed and _count(feed, "damage") == 1, "Stage replacement keeps the session's existing feed")
	shell.select_hero()
	shell._handle_record_key()
	check(shell.session.is_counting_down() and feed.entries[-1].kind == "recording", "Actual R flow reports countdown after it starts")
	shell._handle_record_key()
	check(shell.session.is_idle() and feed.entries[-1].text.contains("cancelled"), "Actual second R reports cancellation after clearing the countdown")
	shell._arm_countdown()
	shell.session.countdown_left = 1
	shell._physics_process(1.0 / 60.0)
	check(shell.session.is_recording() and feed.entries[-1].text.contains("in progress"), "Countdown completion reports actual recording start")
	shell._handle_record_key()
	check(shell.modal.is_open() and feed.entries[-1].text.contains("paused"), "Stopping to decide reports paused recording rather than false discard")
	shell.modal.choose(1)
	check(shell.session.is_recording() and feed.entries[-1].text.contains("resumed"), "Keep recording reports resume")
	shell._handle_record_key()
	shell.modal.choose(2)
	check(shell.session.is_idle() and feed.entries[-1].text.contains("discarded"), "Discard reports the real draft loss")
	shell._arm_countdown()
	shell.session.countdown_left = 1
	shell._physics_process(1.0 / 60.0)
	shell._commit_recording()
	check(shell.encounter.is_ghost(shell.hero) and feed.entries[-1].text.contains("saved"), "Commit reports a stored recording")
	shell.combat.sync_allies(shell.heroes)
	shell.combat.damage_allies_in("guild_house", Rect2i(shell.hero.cell, Vector2i.ONE), 1)
	check(feed.entries[-1].kind == "defeat" and feed.entries[-1].text.contains("next cycle"), "A ghost's real defeat is reported before the shell's early return")
	var roll_before: int = shell.recruitment.rolls_claimed
	var offered: Array[ArenicClassDefinition] = shell.recruitment.offers(roll_before, run.class_catalog())
	shell._claim_roll(offered[0].class_id)
	check(shell.recruitment.rolls_claimed == roll_before + 1 and _count(feed, "reward") >= 2, "Claim publishes the actual recruit and refreshes remaining readiness")
	shell.encounter.unfold_ghost(shell.hero)
	shell.combat.revive_ally("guild_house", shell.hero.ally_id())
	shell.combat.damage_allies_in("guild_house", Rect2i(shell.hero.cell, Vector2i.ONE), 1)
	check(feed.entries[-1].kind == "defeat" and feed.entries[-1].text.contains("Returned to the Guild House"), "A free hero's defeat reports its actual respawn behavior")
	var remote: ArenicHeroState = shell.heroes[0]
	shell._on_hud_hero_requested(shell.heroes[1].identity_id)
	check(remote != shell.hero, "The attribution fixture has a different selected hero")
	remote.arena_id = "labyrinth"
	remote.cell = Vector2i(3, 3)
	shell.combat.sync_allies(shell.heroes)
	shell.combat.revive_ally("labyrinth", remote.ally_id())
	shell.combat.register_enemy("labyrinth", "remote_feed_target", Rect2i(4, 3, 1, 1))
	shell.combat.tick(3.0)
	check(shell.combat.try_cast(remote).is_empty(), "A nonselected hero starts an actual remote attack")
	shell.combat.tick(0.75)
	feed.advance(1.0)
	var attack: Dictionary = feed.entries[-1]
	check(attack.hero_id == remote.identity_id and attack.hero_name == remote.display_name()
		and attack.ability_id == "auto_shot" and attack.ability_name == "Auto Shot" and attack.arena_id == "labyrinth"
		and attack.text == "%s · Auto Shot · 1 damage · Labyrinth" % remote.display_name(), "The shell attributes a real remote hit to its caster and authored attack, never the selected hero")
	root.remove_child(shell)
	shell.free()
	await RETIRE_AUDIO.wait_for_mixer(self)
	check(feed._bus == null, "Actual scene exit breaks the subscriber reference cycle")
	run.begin_new_game()


func _count(feed: ArenicActivityFeed, kind: String) -> int:
	var count: int = 0
	for entry: Dictionary in feed.entries:
		if entry.kind == kind:
			count += 1
	return count
