class_name ArenicInteractionMarkerDefinition
extends Resource
## Authored identity and presentation shared by NPCs and environmental objects.
## The owning interaction supplies progress; this resource never stores a save.
enum Kind { STANDARD, CAMPAIGN, REPEATABLE, SPECIAL, URGENT, TRAVEL }
enum TargetKind { NPC, ENVIRONMENT }

@export var marker_id: String = ""
@export var target_id: String = ""
@export var display_name: String = ""
@export var target_kind: TargetKind = TargetKind.NPC
@export var kind: Kind = Kind.STANDARD
@export_range(8.0, 96.0, 1.0) var head_offset: float = 24.0
## Optional brown campaign crest. Leave off for a plain overhead symbol.
@export var campaign_frame: bool = false

func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	for identity: String in [marker_id, target_id]:
		if identity.is_empty() or identity.length() > 64 or not identity.is_valid_identifier():
			errors.append("Marker and target identities must be stable identifiers of 1–64 characters.")
	if display_name.strip_edges().is_empty() or display_name.length() > 96:
		errors.append("Marker display name must contain 1–96 characters.")
	if target_kind < TargetKind.NPC or target_kind > TargetKind.ENVIRONMENT:
		errors.append("Marker target kind is invalid.")
	if kind < Kind.STANDARD or kind > Kind.TRAVEL:
		errors.append("Marker presentation kind is invalid.")
	if not is_finite(head_offset) or head_offset < 8.0 or head_offset > 96.0:
		errors.append("Marker head offset must be finite and within 8–96 pixels.")
	return errors
