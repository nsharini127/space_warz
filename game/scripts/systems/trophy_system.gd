## Mid-run trophy/achievement system.
## Trophies unlock during gameplay and grant instant bonuses.
extends Node

signal trophy_unlocked(trophy_id: String, trophy_name: String, bonus_text: String)

## Trophy definitions
const TROPHIES = {
	"first_blood": {
		"name": "First Blood",
		"description": "Kill your first enemy",
		"bonus": "score",
		"bonus_value": 500,
		"bonus_text": "+500 Score",
	},
	"combo_king": {
		"name": "Combo King",
		"description": "Reach a combo of 10",
		"bonus": "score",
		"bonus_value": 2000,
		"bonus_text": "+2000 Score",
	},
	"survivor": {
		"name": "Survivor",
		"description": "Survive 2 minutes without taking damage",
		"bonus": "heal",
		"bonus_value": 1,
		"bonus_text": "+1 HP",
	},
	"boss_slayer": {
		"name": "Boss Slayer",
		"description": "Defeat your first boss",
		"bonus": "score",
		"bonus_value": 3000,
		"bonus_text": "+3000 Score",
	},
	"arsenal": {
		"name": "Arsenal",
		"description": "Collect 4 or more weapons",
		"bonus": "damage",
		"bonus_value": 1,
		"bonus_text": "+1 Damage",
	},
	"fever_master": {
		"name": "Fever Master",
		"description": "Trigger Fever Mode 3 times",
		"bonus": "score",
		"bonus_value": 5000,
		"bonus_text": "+5000 Score",
	},
	"graze_ace": {
		"name": "Graze Ace",
		"description": "Graze 50 bullets",
		"bonus": "score",
		"bonus_value": 1500,
		"bonus_text": "+1500 Score",
	},
	"untouchable": {
		"name": "Untouchable",
		"description": "Clear a wave without taking damage",
		"bonus": "heal",
		"bonus_value": 1,
		"bonus_text": "+1 HP",
	},
}

var unlocked: Dictionary = {}  # trophy_id -> true
var fever_count: int = 0
var no_damage_timer: float = 0.0
var took_damage_this_wave: bool = false


func reset():
	unlocked.clear()
	fever_count = 0
	no_damage_timer = 0.0
	took_damage_this_wave = false


func update(delta: float):
	no_damage_timer += delta
	# Check time-based trophies each update
	if no_damage_timer >= 120.0:
		_try_unlock("survivor")


## Call this when an enemy is killed
func on_enemy_killed(total_kills: int):
	if total_kills == 1:
		_try_unlock("first_blood")


## Call this when combo changes
func on_combo_update(combo: int):
	if combo >= 10:
		_try_unlock("combo_king")


## Call this when player takes damage
func on_player_hit():
	no_damage_timer = 0.0
	took_damage_this_wave = true


## Call this when a boss is defeated
func on_boss_defeated():
	_try_unlock("boss_slayer")


## Call this when fever activates
func on_fever_started():
	fever_count += 1
	if fever_count >= 3:
		_try_unlock("fever_master")


## Call this when weapon count changes
func on_weapon_count_changed(count: int):
	if count >= 4:
		_try_unlock("arsenal")


## Call this when graze count changes
func on_graze_update(graze_count: int):
	if graze_count >= 50:
		_try_unlock("graze_ace")


## Call this when a wave completes
func on_wave_completed():
	if !took_damage_this_wave:
		_try_unlock("untouchable")
	took_damage_this_wave = false


## Check time-based trophies (called from update)
func check_time_trophies():
	if no_damage_timer >= 120.0:  # 2 minutes
		_try_unlock("survivor")


func _try_unlock(trophy_id: String):
	if unlocked.has(trophy_id):
		return
	unlocked[trophy_id] = true
	var trophy = TROPHIES[trophy_id]
	trophy_unlocked.emit(trophy_id, trophy.name, trophy.bonus_text)


func get_unlocked_trophies() -> Array:
	var result: Array = []
	for id in unlocked:
		result.append(TROPHIES[id])
	return result


func get_unlocked_count() -> int:
	return unlocked.size()
