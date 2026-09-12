@tool
class_name ArenicDoctorConditions
extends RefCounted

## Adapts the project's existing deterministic data-contract diagnostics for
## Godot Doctor. Keep rules in their domain resources; do not duplicate them in
## a plugin-specific validator.
##
## This script is also compiled by clean Web exports, which deliberately omit
## every editor plugin. Keep the add-on type dynamic so exported game scripts do
## not have a hard parse-time dependency on Godot Doctor.
const VALIDATION_CONDITION_PATH := "res://addons/godot_doctor/core/primitives/validation_condition.gd"
const ERROR_SEVERITY := 2 # ValidationCondition.Severity.ERROR in Godot Doctor 2.2.0.


static func from_errors(errors: PackedStringArray) -> Array:
	var conditions: Array = []
	if not ResourceLoader.exists(VALIDATION_CONDITION_PATH):
		return conditions
	var condition_script := load(VALIDATION_CONDITION_PATH) as Script
	if condition_script == null:
		return conditions
	for error: String in errors:
		conditions.append(
			condition_script.call("simple", false, error, ERROR_SEVERITY)
		)
	return conditions
