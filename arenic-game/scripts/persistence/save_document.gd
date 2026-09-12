class_name ArenicSaveDocument
extends RefCounted
## Transport envelope is separate from gameplay schema and authored content.
## Hash the exact payload text so native int64 values and JS parsing agree.
const FORMAT_VERSION: int = 1
const CONTENT_VERSION: int = 1


static func encode(metadata: Dictionary, payload: Dictionary) -> String:
	var document := metadata.duplicate(true)
	document["format_version"] = FORMAT_VERSION
	document["content_version"] = CONTENT_VERSION
	document["payload_json"] = JSON.stringify(payload, "", true, true)
	document["checksum"] = str(document.payload_json).sha256_text()
	return JSON.stringify(document, "", true, true)


static func decode(text: String, slot: int) -> Dictionary:
	if text.to_utf8_buffer().size() > ArenicSaveBackend.MAX_RECORD_BYTES:
		return _failure("Save exceeds the supported size.")
	var parser := JSON.new()
	if parser.parse(text) != OK or not parser.data is Dictionary:
		return _failure("This save is damaged.")
	var document: Dictionary = parser.data
	if document.get("format_version") != FORMAT_VERSION or document.get("content_version") != CONTENT_VERSION:
		return _failure("This save needs a different game version.", "incompatible")
	if not _integer(document.get("slot"), 0, 7) or int(document.slot) != slot:
		return _failure("Save slot identity is invalid.")
	if not _hex(document.get("run_id"), 64) or not _integer(document.get("revision"), 1, 2147483647):
		return _failure("Save identity or revision is invalid.")
	if not _integer(document.get("seed"), 1, 2147483647):
		return _failure("Save seed is invalid.")
	if not _integer(document.get("created_at"), 0, 9007199254740991) or not _integer(document.get("updated_at"), 0, 9007199254740991):
		return _failure("Save timestamps are invalid.")
	if not document.get("payload_json") is String or not _hex(document.get("checksum"), 64):
		return _failure("Save payload is missing.")
	if str(document.payload_json).sha256_text() != document.checksum:
		return _failure("Save checksum failed; the saved data is damaged.")
	if parser.parse(document.payload_json) != OK or not parser.data is Dictionary:
		return _failure("Save payload is damaged.")
	var migration := ArenicSaveMigrations.upgrade(parser.data)
	if not migration.ok:
		return _failure(migration.error, "incompatible")
	var errors := ArenicSaveCodec.validate(migration.payload)
	if not errors.is_empty():
		return _failure("Save state is invalid: " + errors[0])
	if migration.payload.run.seed != document.seed:
		return _failure("Save seed identity does not match its state.")
	return {"ok": true, "state": "ready", "metadata": document, "payload": migration.payload, "error": ""}


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and value >= minimum and value <= maximum


static func _hex(value: Variant, length: int) -> bool:
	if not value is String or value.length() != length:
		return false
	for character: String in value:
		if not character in "0123456789abcdef":
			return false
	return true


static func _failure(message: String, state: String = "invalid") -> Dictionary:
	return {"ok": false, "state": state, "error": message}
