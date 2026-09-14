class_name ArenicContentIdentity
extends RefCounted
## Run-wide immutable build identity pins every cached take and active draft.
## Presentation fields deliberately do not participate. An unavailable revision
## is rejected by SaveGames before hydration, preserving the original slot.
const SCORE: ArenicMaskScore = preload("res://data/encounters/v2/cardinal_normal_1.tres")
const CLASSES: ArenicClassCatalog = preload("res://data/classes/catalog.tres")
const RULE_FIELDS: PackedStringArray = ["ability_id", "effect_kind", "damage", "cooldown_seconds", "range_tiles", "cast_seconds", "projectile_speed_tiles_per_second", "release_seconds", "duration_seconds", "tick_seconds", "enemy_dot_duration_seconds", "enemy_dot_tick_seconds", "enemy_dot_damage", "requires_adjacent", "requires_backstab", "area_size", "radius_tiles", "loot_bonus_per_ally"]

static func fingerprint(ruleset: String) -> String:
	if ruleset == ArenicActorEffects.LEGACY:
		return ArenicActorEffects.LEGACY
	var build: Array = []
	for hero: ArenicClassDefinition in CLASSES.classes:
		var abilities: Array = []
		for ability: ArenicClassAbility in hero.skills:
			var values: Array = []
			for field: String in RULE_FIELDS:
				var value: Variant = ability.get(field)
				values.append([value.x, value.y] if value is Vector2i else value)
			abilities.append(values)
		build.append([hero.class_id, abilities])
	return JSON.stringify([ArenicActorEffects.RULESET, 60, 66, 31, 4, SCORE.content_hash(), build]).sha256_text()
