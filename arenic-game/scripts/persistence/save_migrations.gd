class_name ArenicSaveMigrations
extends RefCounted
## Pure, sequential payload upgrades. Add each released vN -> vN+1 function
## here and retain fixtures for both versions. Never hydrate an unknown shape.
const CURRENT_VERSION: int = 1
const STEPS: Dictionary = {}


static func upgrade(payload: Dictionary, target: int = CURRENT_VERSION, steps: Dictionary = STEPS) -> Dictionary:
	var version: Variant = payload.get("schema_version")
	if not version is float and not version is int:
		return {"ok": false, "error": "Missing save schema version."}
	if not is_finite(float(version)) or float(version) != floorf(float(version)) or version < 1 or version > target:
		return {"ok": false, "error": "This save needs a different game version."}
	var upgraded := payload.duplicate(true)
	for source: int in range(int(version), target):
		if not steps.has(source) or not steps[source] is Callable:
			return {"ok": false, "error": "No migration exists for this older save. You can remove its slot."}
		var result: Variant = steps[source].call(upgraded)
		if not result is Dictionary or result.get("schema_version") != source + 1:
			return {"ok": false, "error": "Save migration failed; the original is preserved."}
		upgraded = result
	return {"ok": true, "payload": upgraded}
