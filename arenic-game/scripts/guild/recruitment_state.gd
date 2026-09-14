class_name ArenicRecruitmentState
extends RefCounted
## Turns a run's accumulated damage into guild rolls, and a roll into offers.
##
## Damage is never spent: it is a lifetime total, and crossing a threshold earns
## a roll that stays banked until it is claimed. That way a player who is deep in
## an arena never loses a reward for not stopping to collect it.
##
## Offers are drawn from a seed derived from the roll's own index, so a roll
## presents the same choices however long the player waits before opening it —
## and a run replays identically.

const SEED_SALT: int = 0x5AFE_C0DE

var curve: ArenicRecruitmentCurve
var rolls_claimed: int = 0
var max_rolls: int = 319
var _thresholds: PackedInt64Array = PackedInt64Array()


func configure(recruitment_curve: ArenicRecruitmentCurve, guild_cap: int) -> void:
	curve = recruitment_curve
	max_rolls = maxi(0, guild_cap - 1) # The founding hero already owns one slot.
	rolls_claimed = 0
	_thresholds = PackedInt64Array()
	if curve == null:
		return
	# Precomputed once: the HUD asks for progress every frame, and walking a
	# geometric series per frame would be wasteful for a fixed table.
	var total: int = 0
	for index: int in max_rolls:
		total += curve.cost_of(index)
		_thresholds.append(total)


## Rolls the run has earned outright, claimed or not.
func rolls_earned(total_damage: int) -> int:
	var earned: int = 0
	for threshold: int in _thresholds:
		if total_damage < threshold:
			break
		earned += 1
	return earned


func rolls_available(total_damage: int) -> int:
	return maxi(0, rolls_earned(total_damage) - rolls_claimed)


## Damage at which the next unearned roll arrives, or zero when the table is
## exhausted and there is nothing further to work toward.
func next_threshold(total_damage: int) -> int:
	var earned: int = rolls_earned(total_damage)
	return int(_thresholds[earned]) if earned < _thresholds.size() else 0


## Everything the read-out needs, in one call.
func progress(total_damage: int) -> Dictionary:
	var earned: int = rolls_earned(total_damage)
	var next: int = next_threshold(total_damage)
	var floor_damage: int = int(_thresholds[earned - 1]) if earned > 0 and earned <= _thresholds.size() else 0
	return {
		"available": maxi(0, earned - rolls_claimed),
		"claimed": rolls_claimed,
		"toward": maxi(0, total_damage - floor_damage),
		"span": maxi(1, next - floor_damage) if next > 0 else 0,
		"next_at": next,
	}


## The classes this roll offers. Distinct within one roll; a class may be offered
## again by a later roll, because a guild wants more than one of most of them.
func offers(roll_index: int, catalog: ArenicClassCatalog) -> Array[ArenicClassDefinition]:
	var result: Array[ArenicClassDefinition] = []
	if catalog == null or catalog.classes.is_empty() or curve == null:
		return result
	var available: Array[ArenicClassDefinition] = catalog.classes.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED_SALT ^ roll_index
	var wanted: int = mini(curve.offers_per_roll, available.size())
	for index: int in wanted:
		result.append(available.pop_at(rng.randi_range(0, available.size() - 1)))
	return result


func claim() -> void:
	rolls_claimed += 1
