class_name ArenicGameEvent
extends RefCounted
## A transient observation of an effect already applied by a state owner.
## Severity describes the occurrence; importance describes player attention.
## Neither the envelope nor the bus chooses text, color, sound, or game rules.
enum Severity { DEBUG, INFO, WARNING, ERROR }
enum Importance { LOW, NORMAL, HIGH }

const MAX_TYPE_CHARACTERS: int = 96
const MAX_PAYLOAD_KEYS: int = 32
const MAX_KEY_CHARACTERS: int = 96
const MAX_STRING_CHARACTERS: int = 256

var event_type: StringName = &""
var payload: Dictionary = {}
var severity: Severity = Severity.INFO
var importance: Importance = Importance.NORMAL
## Delivery metadata belongs to the current bus lifetime, never to saved state.
var sequence: int = 0
var observed_msec: int = 0


static func create(type: StringName, data: Dictionary, event_severity: Severity = Severity.INFO, event_importance: Importance = Importance.NORMAL) -> ArenicGameEvent:
	var event := ArenicGameEvent.new()
	event.event_type = type
	event.payload = data
	event.severity = event_severity
	event.importance = event_importance
	# Validate before copying: nested/cyclic objects and oversized dictionaries
	# must be rejected without an unbounded deep-copy operation.
	if event.validation_error().is_empty():
		event.payload = data.duplicate(true)
	return event


func validation_error() -> String:
	if not _identifier(String(event_type), MAX_TYPE_CHARACTERS):
		return "Event type must contain 1–96 visible characters without whitespace."
	if severity < Severity.DEBUG or severity > Severity.ERROR:
		return "Unknown event severity."
	if importance < Importance.LOW or importance > Importance.HIGH:
		return "Unknown event importance."
	if payload.size() > MAX_PAYLOAD_KEYS:
		return "Event payload exceeds 32 keys."
	for key: Variant in payload:
		if not key is String or not _identifier(key, MAX_KEY_CHARACTERS):
			return "Event payload keys must contain 1–96 visible string characters without whitespace."
		var value: Variant = payload[key]
		if value is String:
			if value.length() > MAX_STRING_CHARACTERS:
				return "Event payload string exceeds 256 characters."
		elif value is float:
			if not is_finite(value):
				return "Event payload numbers must be finite."
		elif not (value is int or value is bool):
			return "Event payload values must be flat strings, integers, finite floats, or booleans."
	return ""


func copy_for_delivery(delivery_sequence: int, delivery_msec: int) -> ArenicGameEvent:
	var copy := create(event_type, payload, severity, importance)
	copy.sequence = delivery_sequence
	copy.observed_msec = delivery_msec
	return copy


static func _identifier(value: String, maximum: int) -> bool:
	if value.is_empty() or value.length() > maximum:
		return false
	for character: String in value:
		var codepoint := character.unicode_at(0)
		if codepoint <= 32 or codepoint == 127:
			return false
	return true
