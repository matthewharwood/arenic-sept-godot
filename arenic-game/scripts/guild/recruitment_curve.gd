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
## The first few rolls teach the original growing thresholds. A linear tail
## then lets income from a growing guild keep pace with its next recruit.

## A clamp, not a balance value: unbounded geometric growth would overflow.
const MAX_COST: int = 1_000_000_000

## About one two-minute cycle of a single committed Hunter ghost.
@export_range(1, 1000000, 1) var first_roll_damage: int = 40
@export_range(1.0, 8.0, 0.01) var growth: float = 1.6
@export_range(1, 16, 1) var growth_rolls: int = 4
@export_range(1, 10000, 1) var late_cost_step: int = 48
## Choices presented per roll. One slot of the modal is always the way out.
@export_range(1, 3, 1) var offers_per_roll: int = 3


func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	if first_roll_damage <= 0:
		errors.append("The first roll must cost positive damage.")
	if not is_finite(growth) or growth < 1.0:
		errors.append("Roll cost must not shrink; growth is at least one.")
	if growth_rolls < 1 or growth_rolls > 16 or late_cost_step < 1:
		errors.append("Recruitment needs a bounded opening curve and positive late cost step.")
	if offers_per_roll < 1 or offers_per_roll > 3:
		errors.append("A roll presents one to three offers, leaving room to decline.")
	return errors


## Damage the `roll_index`-th roll costs on its own, counting from zero.
func cost_of(roll_index: int) -> int:
	var cost: float = float(first_roll_damage)
	for step: int in mini(maxi(0, roll_index), growth_rolls - 1):
		cost *= growth
		if cost >= float(MAX_COST):
			return MAX_COST
	var opening_cost: int = clampi(roundi(cost), 1, MAX_COST)
	var later: int = maxi(0, roll_index - growth_rolls + 1)
	if later > (MAX_COST - opening_cost) / late_cost_step:
		return MAX_COST
	return opening_cost + later * late_cost_step


## Cumulative damage needed to have earned `roll_count` rolls.
func total_for(roll_count: int) -> int:
	var total: int = 0
	for index: int in maxi(0, roll_count):
		total = mini(MAX_COST, total + cost_of(index))
	return total


func _get_validation_conditions() -> Array:
	return ArenicDoctorConditions.from_errors(validation_errors())
