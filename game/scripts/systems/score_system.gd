extends Node


var current_score: int = 0
var high_score: int = 0


func add_score(points: int):
	current_score += points
	if current_score > high_score:
		high_score = current_score


func reset():
	current_score = 0


func get_score() -> int:
	return current_score


func get_high_score() -> int:
	return high_score
