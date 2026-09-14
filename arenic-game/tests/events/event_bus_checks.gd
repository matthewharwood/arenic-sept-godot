extends SceneTree
## Observational delivery, payload isolation, bounded subscriptions, and teardown.
var checks: int = 0
var failed: bool = false


class Observer:
	extends Node
	var received: Array[ArenicGameEvent] = []

	func consume(event: ArenicGameEvent) -> void:
		received.append(event)

	func no_arguments() -> void:
		pass

	func two_arguments(_event: ArenicGameEvent, _other: int) -> void:
		pass


func _initialize() -> void:
	_run.call_deferred()


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failed = true
		push_error("Event bus: " + message)


func _run() -> void:
	_check_delivery()
	_check_isolation()
	_check_rejected_events()
	_check_subscription_bounds()
	_check_dispatch_changes()
	_check_reentrancy()
	print("Event bus checks: %d assertions, %s." % [checks, "FAILED" if failed else "passed"])
	quit(1 if failed else 0)


func _check_delivery() -> void:
	var bus := ArenicEventBus.new()
	var observer := Observer.new()
	var source := {"arena_id": "guild_house", "hero_id": 3, "amount": 17, "ratio": 0.25, "ready": true}
	var event := ArenicGameEvent.create(&"hero.ready", source, ArenicGameEvent.Severity.INFO, ArenicGameEvent.Importance.HIGH)
	check(event.severity == ArenicGameEvent.Severity.INFO and event.importance == ArenicGameEvent.Importance.HIGH, "Importance is independent from informational severity")
	source["amount"] = 999
	check(event.payload.amount == 17, "Construction snapshots the caller's payload dictionary")
	check(bus.dispatch(event), "A valid observation is accepted without subscribers")
	check(bus.subscribe(observer.consume), "An event observer subscribes")
	check(observer.received.is_empty(), "Subscribing never replays previous observations")
	check(not bus.subscribe(observer.consume), "Duplicate subscription is rejected")
	event.sequence = 1234
	event.observed_msec = -100
	check(bus.dispatch(event), "A current observation is delivered synchronously")
	check(observer.received.size() == 1, "A subscriber receives an accepted dispatch once")
	var delivered: ArenicGameEvent = observer.received[0]
	check(delivered.event_type == &"hero.ready" and delivered.payload.amount == 17, "The event type and flat payload reach the observer")
	check(delivered.sequence == 2 and delivered.observed_msec >= 0, "The bus assigns monotonic metadata instead of trusting publisher metadata")
	check(event.sequence == 1234 and event.observed_msec == -100, "Delivery metadata does not mutate the publisher-owned event")
	check(bus.unsubscribe(observer.consume), "Registered observers can unsubscribe")
	check(not bus.unsubscribe(observer.consume), "Unsubscribing an absent observer reports no change")
	check(bus.dispatch(ArenicGameEvent.create(&"future.type", {})), "Unknown future event types need no bus catalog change")
	check(observer.received.size() == 1, "An unsubscribed observer receives no later event")
	observer.free()


func _check_isolation() -> void:
	var bus := ArenicEventBus.new()
	var original := ArenicGameEvent.create(&"combat.damage", {"amount": 17}, ArenicGameEvent.Severity.DEBUG, ArenicGameEvent.Importance.LOW)
	var second := Observer.new()
	var third := Observer.new()
	var mutate := func(event: ArenicGameEvent) -> void:
		event.payload["amount"] = 888
		event.event_type = &"altered.observation"
		event.severity = ArenicGameEvent.Severity.ERROR
		event.sequence = 999
		original.payload["amount"] = 777
		original.event_type = &"altered.publisher"
	bus.subscribe(mutate)
	bus.subscribe(second.consume)
	bus.subscribe(third.consume)
	check(bus.dispatch(original), "Observers may own and edit their delivered copy")
	check(second.received[0].payload.amount == 17 and second.received[0].event_type == &"combat.damage", "Neither observer nor publisher mutation changes a later delivery")
	check(second.received[0].severity == ArenicGameEvent.Severity.DEBUG and second.received[0].importance == ArenicGameEvent.Importance.LOW, "Copies preserve distinct severity and importance")
	check(second.received[0].sequence == 1 and third.received[0].sequence == 1, "Every observer receives the same bus sequence")
	check(second.received[0].observed_msec == third.received[0].observed_msec, "Every observer receives the same observation timestamp")
	second.received[0].payload["amount"] = 444
	check(third.received[0].payload.amount == 17, "Stored deliveries remain isolated after dispatch returns")
	second.free()
	third.free()


func _check_rejected_events() -> void:
	var bus := ArenicEventBus.new()
	var observer := Observer.new()
	bus.subscribe(observer.consume)
	check(not bus.dispatch(null), "Missing events are rejected")
	for type: StringName in [&"", &" ", &"two words", StringName("t".repeat(97)), StringName("bad\ntype")]:
		check(not bus.dispatch(ArenicGameEvent.create(type, {})), "Empty, oversized, and whitespace-bearing event types are rejected")
	for value: Variant in [null, {}, [], Vector2i(1, 2), StringName("not-a-plain-string"), NAN, INF, -INF, "x".repeat(257)]:
		check(not bus.dispatch(ArenicGameEvent.create(&"payload.invalid", {"value": value})), "Non-plain, non-finite, and oversized values are rejected")
	var object := RefCounted.new()
	check(not bus.dispatch(ArenicGameEvent.create(&"payload.invalid", {"value": object})), "Payloads cannot retain runtime objects")
	check(not bus.dispatch(ArenicGameEvent.create(&"payload.invalid", {"value": observer.consume})), "Payloads cannot contain executable Callables")
	var cyclic: Dictionary = {}
	cyclic["self"] = cyclic
	check(not bus.dispatch(ArenicGameEvent.create(&"payload.invalid", {"value": cyclic})), "Cyclic payloads are rejected before any recursive copying")
	cyclic.clear()
	for key: Variant in [3, &"interned_key", "", "bad key", "k".repeat(97)]:
		check(not bus.dispatch(ArenicGameEvent.create(&"payload.invalid", {key: 1})), "Payload keys must be bounded plain string identifiers")
	var oversized: Dictionary = {}
	for index: int in 33:
		oversized["key_%d" % index] = index
	check(not bus.dispatch(ArenicGameEvent.create(&"payload.invalid", oversized)), "A thirty-third payload key is rejected")
	var bad_enum := ArenicGameEvent.create(&"enum.invalid", {})
	bad_enum.set("severity", 99)
	check(not bus.dispatch(bad_enum), "Undefined severity values are rejected")
	bad_enum.severity = ArenicGameEvent.Severity.INFO
	bad_enum.set("importance", -1)
	check(not bus.dispatch(bad_enum), "Undefined importance values are rejected")
	check(observer.received.is_empty(), "Rejected observations never reach subscribers")
	oversized.erase("key_32")
	oversized["key_0"] = "x".repeat(256)
	check(bus.dispatch(ArenicGameEvent.create(StringName("t".repeat(96)), oversized)), "Exactly 32 keys, 256-character values, and a 96-character type are supported")
	check(observer.received[0].sequence == 1, "Rejected observations do not consume sequence numbers")
	observer.free()


func _check_subscription_bounds() -> void:
	var bus := ArenicEventBus.new()
	var observer := Observer.new()
	check(not bus.subscribe(Callable()), "An empty Callable cannot subscribe")
	check(not bus.subscribe(Callable(observer, "missing_method")), "A nonexistent method cannot subscribe")
	check(not bus.subscribe(observer.no_arguments), "A subscriber must accept the event argument")
	check(not bus.subscribe(observer.two_arguments), "A subscriber cannot require extra unbound arguments")
	check(bus.subscribe(observer.two_arguments.bind(1)), "A bound adapter with one remaining event argument is supported")
	check(bus.unsubscribe(observer.two_arguments.bind(1)), "An equivalent bound Callable can unsubscribe")
	var receivers: Array[Observer] = []
	for index: int in ArenicEventBus.MAX_SUBSCRIBERS:
		var receiver := Observer.new()
		receivers.append(receiver)
		check(bus.subscribe(receiver.consume), "Each bounded subscriber position is available")
	check(not bus.subscribe(observer.consume), "A thirty-third subscriber is rejected")
	var expired: Observer = receivers.pop_front()
	var expired_callback := expired.consume
	expired.free()
	check(not bus.subscribe(expired_callback), "A freed receiver cannot subscribe")
	check(bus.subscribe(observer.consume), "Expired receivers release subscriber capacity")
	check(bus.dispatch(ArenicGameEvent.create(&"capacity.test", {})), "Delivery safely skips expired receivers")
	check(observer.received.size() == 1, "The replacement subscriber receives the next event")
	for receiver: Observer in receivers:
		receiver.free()
	observer.free()


func _check_dispatch_changes() -> void:
	var bus := ArenicEventBus.new()
	var second := Observer.new()
	var later := Observer.new()
	var calls := [0]
	var first := func(_event: ArenicGameEvent) -> void:
		calls[0] += 1
		if calls[0] == 1:
			bus.unsubscribe(second.consume)
			bus.subscribe(later.consume)
	bus.subscribe(first)
	bus.subscribe(second.consume)
	check(bus.dispatch(ArenicGameEvent.create(&"subscriptions.first", {})), "Observers can change subscriptions during delivery")
	check(second.received.size() == 1 and later.received.is_empty(), "The current dispatch retains its original subscriber snapshot")
	check(bus.dispatch(ArenicGameEvent.create(&"subscriptions.second", {})), "The following dispatch uses the new subscribers")
	check(second.received.size() == 1 and later.received.size() == 1, "Subscription changes apply to subsequent observations")
	bus.unsubscribe(first) # Release the lambda's intentional bus reference.
	second.free()
	later.free()
	var retired := Observer.new()
	var teardown := func(_event: ArenicGameEvent) -> void:
		retired.free()
	bus.subscribe(teardown)
	bus.subscribe(retired.consume)
	check(bus.dispatch(ArenicGameEvent.create(&"subscriptions.teardown", {})), "A receiver freed by an earlier observer is skipped safely")
	bus.unsubscribe(teardown)


func _check_reentrancy() -> void:
	var bus := ArenicEventBus.new()
	var observer := Observer.new()
	var nested_results: Array[bool] = []
	var recursive := func(_event: ArenicGameEvent) -> void:
		nested_results.append(bus.dispatch(ArenicGameEvent.create(&"recursive.event", {})))
	bus.subscribe(recursive)
	bus.subscribe(observer.consume)
	check(bus.dispatch(ArenicGameEvent.create(&"outer.event", {})), "The outer observation completes")
	check(nested_results == [false], "Recursive dispatch is rejected at one level")
	check(observer.received.size() == 1 and observer.received[0].event_type == &"outer.event", "Recursive rejection cannot duplicate or replace another observer's event")
	bus.unsubscribe(recursive)
	check(bus.dispatch(ArenicGameEvent.create(&"next.event", {})), "The bus remains usable after recursive rejection")
	check(observer.received[1].sequence == 2, "Recursive rejection does not consume the next sequence")
	bus.set("_sequence", ArenicEventBus.MAX_SEQUENCE)
	check(not bus.dispatch(ArenicGameEvent.create(&"overflow.event", {})), "Sequence exhaustion fails instead of wrapping")
	observer.free()
