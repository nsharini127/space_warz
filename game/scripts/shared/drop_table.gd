## Service: Centralized drop probability logic.
## All item drop decisions go through this class so drop rates
## can be tuned in a single place.
class_name DropTable

## Drop categories returned by roll_drop().
enum DropType {
	NONE,
	POWER,
	BOMB,
	HEALTH,
	ATTACK_SPEED_BOOST,
	SHIELD,
	INVINCIBILITY,
}

## Base chance that any drop occurs on an enemy kill (0.0 - 1.0).
const BASE_DROP_CHANCE: float = 0.15

## Weights for each drop type when a drop occurs.
## Higher weight = more likely. Relative to total weight sum.
const DROP_WEIGHTS: Dictionary = {
	DropType.POWER: 30,
	DropType.BOMB: 18,
	DropType.HEALTH: 10,
	DropType.ATTACK_SPEED_BOOST: 22,
	DropType.SHIELD: 12,
	DropType.INVINCIBILITY: 8,
}

## Boss enemies always drop items. Returns an array of DropType.
## Bosses drop 2-3 items guaranteed.
static func roll_boss_drops() -> Array[int]:
	var drops: Array[int] = []
	drops.append(DropType.POWER)
	drops.append(DropType.BOMB)
	# 50% chance for a third bonus drop
	if randf() < 0.5:
		drops.append(_weighted_random_drop())
	return drops


## Rolls a single drop for a regular enemy kill.
## Returns DropType.NONE if no drop occurs (75% of the time).
static func roll_enemy_drop() -> int:
	if randf() >= BASE_DROP_CHANCE:
		return DropType.NONE
	return _weighted_random_drop()


## Selects a random drop type based on weights.
static func _weighted_random_drop() -> int:
	var total_weight: int = 0
	for w in DROP_WEIGHTS.values():
		total_weight += w

	var roll: float = randf() * total_weight
	var cumulative: int = 0

	for drop_type in DROP_WEIGHTS:
		cumulative += DROP_WEIGHTS[drop_type]
		if roll <= cumulative:
			return drop_type

	return DropType.POWER  # Fallback
