class_name ArenicEventBus
extends RefCounted
## Synchronous observations, not commands or a durable event log.
## Each observer gets an isolated envelope and payload. Subscription changes
## during delivery apply to the next dispatch; freed receivers are skipped.
## Recursive dispatch is rejected instead of building an unbounded event queue.
const MAX_SUBSCRIBERS: int = 32
const MAX_SEQUENCE: int = 9223372036854775807

var last_error: String = ""
var _subscribers: Array[Callable] = []
var _sequence: int = 0
var _dispatching: bool = false


func subscribe(callback: Callable) -> bool:
	_prune_subscribers()
	if not callback.is_valid():
		return _reject("Event subscriber must be a valid Callable.")
	if callback.get_argument_count() != 1:
		return _reject("Event subscriber must accept exactly one event argument.")
	if _subscribers.has(callback):
		return _reject("Event subscriber is already registered.")
	if _subscribers.size() >= MAX_SUBSCRIBERS:
		return _reject("Event bus supports at most 32 subscribers.")
	_subscribers.append(callback)
	last_error = ""
	return true


func unsubscribe(callback: Callable) -> bool:
	_prune_subscribers()
	if not _subscribers.has(callback):
		return _reject("Event subscriber is not registered.")
	_subscribers.erase(callback)
	last_error = ""
	return true


func dispatch(event: ArenicGameEvent) -> bool:
	if _dispatching:
		return _reject("Observers cannot dispatch recursively on the same event bus.")
	if event == null:
		return _reject("Cannot dispatch a missing event.")
	var invalid := event.validation_error()
	if not invalid.is_empty():
		return _reject(invalid)
	if _sequence >= MAX_SEQUENCE:
		return _reject("Event bus sequence is exhausted.")
	_prune_subscribers()
	_sequence += 1
	# Copy before invoking any observer: even a callback that holds the original
	# publisher-owned event cannot alter the snapshot delivered to later observers.
	var snapshot := event.copy_for_delivery(_sequence, Time.get_ticks_msec())
	var subscribers := _subscribers.duplicate()
	_dispatching = true
	for callback: Callable in subscribers:
		if callback.is_valid():
			callback.call(snapshot.copy_for_delivery(snapshot.sequence, snapshot.observed_msec))
	_dispatching = false
	_prune_subscribers()
	last_error = ""
	return true


func _prune_subscribers() -> void:
	for index: int in range(_subscribers.size() - 1, -1, -1):
		if not _subscribers[index].is_valid():
			_subscribers.remove_at(index)


func _reject(message: String) -> bool:
	last_error = message
	return false
