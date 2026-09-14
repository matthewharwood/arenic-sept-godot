class_name ArenicActivityFeed
extends RefCounted
## Transient subscriber, not a gameplay ledger. A new shell starts fresh and
## publishes current actionable state after hydration; no old damage is replayed.
signal changed

const MAX_ENTRIES: int = 100
const MAX_ARENAS: int = 9
const MAX_PENDING_DAMAGE: int = 100
const DAMAGE_WINDOW_SECONDS: float = 1.0
const MAX_TOTAL: int = 9223372036854775807
const RECORDING_STATUSES: Array[String] = ["countdown", "recording", "paused", "resumed", "committed", "discarded", "cancelled"]

var entries: Array[Dictionary] = []
## Current unclaimed recruitment remains visible even when damage rows roll on.
var attention: Dictionary = {}
var _bus: ArenicEventBus
var _arena_names: Dictionary[String, String] = {}
var _pending_damage: Dictionary[String, Dictionary] = {}
var _elapsed: float = 0.0
var _ready_count: int = -1


func bind(bus: ArenicEventBus) -> void:
	if _bus == bus:
		return
	unbind()
	_bus = bus
	if _bus != null:
		_bus.subscribe(consume)


func unbind() -> void:
	if _bus != null:
		_bus.unsubscribe(consume)
	_bus = null


func configure(world: ArenicWorldDefinition) -> void:
	_arena_names.clear()
	if world == null:
		_pending_damage.clear()
		return
	for arena: ArenicArenaDefinition in world.arenas.slice(0, MAX_ARENAS):
		if arena != null:
			_arena_names[arena.arena_id] = arena.display_name
	for key: String in _pending_damage.keys():
		if not _arena_names.has(_pending_damage[key].event.payload.arena_id):
			_pending_damage.erase(key)


## The bus accepts future message types; this consumer validates the vocabulary
## it understands and ignores unknown/malformed payloads without side effects.
func consume(event: ArenicGameEvent) -> void:
	if event == null:
		return
	var data: Dictionary = event.payload
	match event.event_type:
		&"raid.damage":
			if not _damage_payload(data):
				return
			# Stable identities, not the selected hero or a last-cast cache. Two
			# heroes using the same attack must keep separate totals in the feed.
			var key: String = JSON.stringify([data.arena_id, data.hero_id, data.ability_id])
			if not _pending_damage.has(key) and _pending_damage.size() >= MAX_PENDING_DAMAGE:
				_flush_damage()
			var pending: Dictionary = _pending_damage.get(key, {"amount": 0, "event": event})
			pending.amount = int(pending.amount) + mini(int(data.amount), MAX_TOTAL - int(pending.amount))
			pending.event = event
			_pending_damage[key] = pending
		&"recruit.ready":
			if not _fields(data, ["available"]) or not data.available is int or data.available < 0 or data.available > 320:
				return
			var available: int = int(data.available)
			if available == _ready_count:
				return
			var previous: int = _ready_count
			_ready_count = available
			if available <= 0:
				attention = {}
				changed.emit()
				return
			var text: String = "%d %s ready to recruit. Press N." % [available, "hero is" if available == 1 else "heroes are"]
			attention = _entry(text, "reward", event)
			# A decrease updates the action count without inventing a new reward.
			if previous < 0 or available > previous:
				_append(attention)
			changed.emit()
		&"guild.hero_recruited":
			if not _fields(data, ["hero_id", "hero_name"]) or not _hero(data.hero_id) or not _name(data.hero_name):
				return
			_publish("%s joined the guild at the Guild House." % data.hero_name, "reward", event)
		&"hero.defeated":
			var keys: Array = ["hero_id", "hero_name", "arena_id", "recorded"]
			if data.has("cause"):
				keys.append("cause")
				if data.cause not in ["attack", "contact"]:
					return
			if not _fields(data, keys) or not _hero(data.hero_id) or not _name(data.hero_name) or not _arena(data.arena_id) or not data.recorded is bool:
				return
			var outcome: String = "Returns next cycle." if data.recorded else "Returned to the Guild House."
			var incident: String = "touched another hero in" if data.get("cause", "") == "contact" else "down in"
			_publish("%s %s %s. %s" % [data.hero_name, incident, _arena_names[data.arena_id], outcome], "defeat", event)
		&"recording.status":
			if not _fields(data, ["hero_id", "hero_name", "arena_id", "status"]) or not _hero(data.hero_id) or not _name(data.hero_name) or not _arena(data.arena_id) or data.status not in RECORDING_STATUSES:
				return
			var description: String = {"countdown": "Recording countdown in progress", "recording": "Recording in progress",
				"paused": "Recording paused for a decision", "resumed": "Recording resumed", "committed": "Recording saved",
				"discarded": "Recording stopped and discarded", "cancelled": "Recording countdown cancelled"}[data.status]
			_publish("%s — %s in %s." % [description, data.hero_name, _arena_names[data.arena_id]], "recording", event)
		&"notice":
			if _fields(data, ["text"]) and _name(data.text):
				_publish(data.text, "notice", event)


## A presentation clock, independent of damage, encounter ticks and save timing.
func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	_elapsed += minf(delta, DAMAGE_WINDOW_SECONDS)
	if _elapsed < DAMAGE_WINDOW_SECONDS:
		return
	_elapsed = 0.0
	_flush_damage()


## Early flush at capacity preserves attribution without an unbounded queue.
## History still retains only the most recent MAX_ENTRIES observations.
func _flush_damage() -> void:
	if _pending_damage.is_empty():
		return
	var keys: Array = _pending_damage.keys()
	keys.sort()
	for key: String in keys:
		var pending: Dictionary = _pending_damage[key]
		var data: Dictionary = pending.event.payload
		var source: String = _display_name(data.ability_name)
		if data.hero_id >= 0:
			source = "%s · %s" % [_display_name(data.hero_name), source]
		elif data.ability_id != "environment":
			source = "Unknown hero · " + source
		var entry: Dictionary = _entry("%s · %d damage · %s" % [source, pending.amount, _arena_names[data.arena_id]], "damage", pending.event)
		entry.merge(data)
		entry.amount = pending.amount
		_append(entry)
	_pending_damage.clear()
	changed.emit()


func _damage_payload(data: Dictionary) -> bool:
	if not _fields(data, ["arena_id", "amount", "hero_id", "hero_name", "ability_id", "ability_name"]):
		return false
	if not _arena(data.arena_id) or not data.amount is int or data.amount <= 0 or not data.hero_id is int or not data.hero_name is String:
		return false
	if data.hero_id == -1:
		if data.hero_name != "":
			return false
	elif not _hero(data.hero_id) or not _name(data.hero_name):
		return false
	return data.ability_id is String and ArenicGameEvent._identifier(data.ability_id, 64) and _name(data.ability_name)


static func _display_name(value: String) -> String:
	return " ".join(value.replace("\n", " ").replace("\r", " ").replace("\t", " ").replace("\u2028", " ").replace("\u2029", " ").split(" ", false))


func _publish(text: String, kind: String, event: ArenicGameEvent) -> void:
	_append(_entry(text, kind, event))
	changed.emit()


func _entry(text: String, kind: String, event: ArenicGameEvent) -> Dictionary:
	return {"text": text, "kind": kind, "severity": int(event.severity), "importance": int(event.importance),
		"event_type": String(event.event_type), "sequence": event.sequence}


func _append(entry: Dictionary) -> void:
	entries.append(entry.duplicate(true))
	if entries.size() > MAX_ENTRIES:
		entries.pop_front()


func _arena(value: Variant) -> bool:
	return value is String and _arena_names.has(value)


static func _hero(value: Variant) -> bool:
	return value is int and value >= 0 and value < 320


static func _name(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty() and value.length() <= 256


static func _fields(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size():
		return false
	for key: String in keys:
		if not value.has(key):
			return false
	return true
