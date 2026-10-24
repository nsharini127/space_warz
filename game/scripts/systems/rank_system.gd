extends Node


var rank: float = 0.0  # 0.0 to 1.0
var rank_increase_rate: float = 0.005  # Per second base
var no_death_time: float = 0.0
var no_bomb_time: float = 0.0


func _process(delta: float):
	# Rank increases over time
	rank = min(rank + rank_increase_rate * delta, 1.0)

	# Rank increases faster without deaths/bombs
	no_death_time += delta
	no_bomb_time += delta

	if no_death_time > 30.0:
		rank = min(rank + 0.002 * delta, 1.0)
	if no_bomb_time > 20.0:
		rank = min(rank + 0.001 * delta, 1.0)


func on_player_death():
	rank = max(0.0, rank - 0.3)
	no_death_time = 0.0


func on_bomb_used():
	rank = max(0.0, rank - 0.15)
	no_bomb_time = 0.0


func get_bullet_speed_mult() -> float:
	return 1.0 + rank * 0.5


func get_fire_rate_mult() -> float:
	return 1.0 - rank * 0.3


func get_extra_bullets() -> int:
	if rank > 0.8:
		return 4
	elif rank > 0.6:
		return 3
	elif rank > 0.4:
		return 2
	elif rank > 0.2:
		return 1
	return 0


func reset():
	rank = 0.0
	no_death_time = 0.0
	no_bomb_time = 0.0
