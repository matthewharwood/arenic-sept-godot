@tool
class_name ArenicRecruitmentCurve
extends Resource
## Damage thresholds that award guild rolls.
##
## Damage dealt anywhere is the run's one currency. Ghosts keep dealing it while
## the player is in another arena, so the curve is really a statement about how
## long a committed staff takes to pay for the next hero — and the next hero is
## what makes the arena after that worth recording.
##
## Each roll costs `growth` times the one before it, so a guild that is already
## earning still has to earn more to keep growing.

## A clamp, not a balance value: unbounded geometric growth would overflow.
const MAX_COST: int = 1_000_000_000

## About one two-minute cycle of a single committed Hunter ghost.
@export_range(1, 1000000, 1) var first_roll_damage: int = 40
@export_range(1.0, 8.0, 0.01) var growth: float = 1.6
## Choices presented per roll. One slot of the modal is always the way out.
@export_range(1, 3, 1) var offers_per_roll: int = 3


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if first_roll_damage <= 0:
		errors.append("The first roll must cost positive damage.")
	if not is_finite(growth) or growth < 1.0:
		errors.append("Roll cost must not shrink; growth is at least one.")
	if offers_per_roll < 1 or offers_per_roll > 3:
		errors.append("A roll presents one to three offers, leaving room to decline.")
	return errors


## Damage the `roll_index`-th roll costs on its own, counting from zero.
func cost_of(roll_index: int) -> int:
	var cost: float = float(first_roll_damage)
	for step: int in maxi(0, roll_index):
		cost *= growth
		if cost >= float(MAX_COST):
			return MAX_COST
	return clampi(roundi(cost), 1, MAX_COST)


## Cumulative damage needed to have earned `roll_count` rolls.
func total_for(roll_count: int) -> int:
	var total: int = 0
	for index: int in maxi(0, roll_count):
		total = mini(MAX_COST, total + cost_of(index))
	return total


func _get_validation_conditions() -> Array:
	return ArenicDoctorConditions.from_errors(validation_errors())
