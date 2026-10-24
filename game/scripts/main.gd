extends Node


func _ready():
	pass


func change_scene(scene_path: String):
	get_tree().change_scene_to_file(scene_path)


func start_game():
	change_scene("res://scenes/game.tscn")


func go_to_title():
	change_scene("res://scenes/main.tscn")
