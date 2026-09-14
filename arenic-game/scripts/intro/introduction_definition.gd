class_name ArenicIntroductionDefinition
extends Resource
## Inspector-editable prologue text, pacing and appearance.
@export var npc: ArenicNpcDefinition
@export_multiline var quote: String = ""
@export var quote_author: String = ""
@export_range(0.0, 10.0, 0.25) var quote_seconds: float = 2.0
@export var dialogue: Array[ArenicDialogueBeat] = []
@export var gate_frames: SpriteFrames
@export_range(0.1, 5.0, 0.1) var unlock_seconds: float = 1.4

func validation_errors() -> PackedStringArray:
	var errors: PackedStringArray = []
	if npc == null or npc.npc_id.is_empty() or npc.portrait == null or npc.sprite_frames == null:
		errors.append("Introduction requires a complete NPC definition.")
	if npc != null and (npc.arena_id != "guild_house" or not ArenicGridMath.tile_valid(npc.cell)):
		errors.append("Introduction NPC must stand inside the Guild House.")
	if npc != null:
		if npc.interaction_marker == null:
			errors.append("Introduction NPC requires an interaction marker.")
		else:
			errors.append_array(npc.interaction_marker.validation_errors())
			if npc.interaction_marker.target_id != npc.npc_id or npc.interaction_marker.target_kind != ArenicInteractionMarkerDefinition.TargetKind.NPC:
				errors.append("Introduction marker must target its NPC identity.")
	if quote.is_empty() or quote_author.is_empty() or dialogue.size() != 4:
		errors.append("Introduction requires its opening quote and exactly four dialogue beats.")
	if not is_finite(quote_seconds) or quote_seconds < 0.0 or quote_seconds > 10.0:
		errors.append("Opening quote timing is invalid.")
	for beat: ArenicDialogueBeat in dialogue:
		if beat == null or beat.text.is_empty() or beat.text.length() > 256 or not is_finite(beat.min_read_seconds) or beat.min_read_seconds < 0.0 or beat.min_read_seconds > 10.0:
			errors.append("Dialogue text and read timing must be bounded.")
	if gate_frames == null or not is_finite(unlock_seconds) or unlock_seconds <= 0.0 or unlock_seconds > 5.0:
		errors.append("Introduction requires bounded gate animation data.")
	elif not gate_frames.has_animation("locked") or not gate_frames.has_animation("opening") or not gate_frames.has_animation("open"):
		errors.append("Gate frames require locked, opening, and open animations.")
	return errors
