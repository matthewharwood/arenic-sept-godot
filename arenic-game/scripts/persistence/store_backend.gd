class_name ArenicSaveBackend
extends RefCounted
## Storage boundary only: callers await every operation on either platform.
## expected_revision=0 creates; -1 deletes an explicitly invalid record only.
## Deletion compares the reviewed run identity too; empty matches only no identity.
const SLOT_COUNT: int = 8
const MAX_RECORD_BYTES: int = 64 * 1024 * 1024
const MAX_REVISION: int = 2147483647


func read_all() -> Dictionary:
	return failure("Save storage is not configured.")


func write_record(_slot: int, _expected_revision: int, _record: String) -> Dictionary:
	return failure("Save storage is not configured.")


func delete_record(_slot: int, _expected_revision: int, _expected_run_id: String = "") -> Dictionary:
	return failure("Save storage is not configured.")


static func failure(message: String) -> Dictionary:
	return {"ok": false, "error": message}


static func record_run_id(record: String) -> String:
	var parser := JSON.new()
	if record.to_utf8_buffer().size() <= MAX_RECORD_BYTES and parser.parse(record) == OK and parser.data is Dictionary:
		var value: Variant = parser.data.get("run_id", "")
		return value if value is String else ""
	return ""


static func record_revision(record: String) -> int:
	if record.is_empty():
		return 0
	if record.to_utf8_buffer().size() > MAX_RECORD_BYTES:
		return -1
	var parser := JSON.new()
	if parser.parse(record) != OK or not parser.data is Dictionary:
		return -1
	var value: Variant = parser.data.get("revision")
	if not (value is int or value is float):
		return -1
	if not is_finite(float(value)) or float(value) != floorf(float(value)):
		return -1
	if float(value) < 1.0 or float(value) > float(MAX_REVISION):
		return -1
	if parser.data.has("payload_json") or parser.data.has("checksum"):
		var payload: Variant = parser.data.get("payload_json")
		var checksum: Variant = parser.data.get("checksum")
		if not payload is String or not checksum is String or payload.sha256_text() != checksum:
			return -1
	return int(value)


static func write_error(slot: int, expected_revision: int, record: String) -> String:
	if slot < 0 or slot >= SLOT_COUNT:
		return "Save slot must be between 1 and 8."
	if expected_revision < 0 or expected_revision >= MAX_REVISION:
		return "Save revision is invalid or exhausted. Reload this slot."
	if record.to_utf8_buffer().size() > MAX_RECORD_BYTES:
		return "This save exceeds the 64 MiB slot limit. Progress was not truncated."
	if record_revision(record) != expected_revision + 1:
		return "Save data must contain a valid next revision and payload checksum."
	return ""


static func delete_error(slot: int, expected_revision: int) -> String:
	if slot < 0 or slot >= SLOT_COUNT:
		return "Save slot must be between 1 and 8."
	if expected_revision < -1 or expected_revision > MAX_REVISION:
		return "Save revision is invalid. Reload the slot list."
	return ""
