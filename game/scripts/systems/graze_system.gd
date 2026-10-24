extends Area2D


signal graze_triggered(pos: Vector2)

var graze_count: int = 0
var graze_cooldowns: Dictionary = {}


func _ready():
	collision_layer = 0
	collision_mask = 8  # EnemyBullet layer
	area_entered.connect(_on_area_entered)

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 16.0
	shape.shape = circle
	add_child(shape)


func _on_area_entered(area: Area2D):
	if !area.is_in_group("enemy_bullet"):
		return

	var id = area.get_instance_id()
	if graze_cooldowns.has(id):
		return

	graze_cooldowns[id] = true
	graze_count += 1
	graze_triggered.emit(area.global_position)

	# Spawn spark effect
	_spawn_spark(area.global_position)


func _spawn_spark(pos: Vector2):
	var spark = Node2D.new()
	spark.global_position = pos
	spark.set_script(preload("res://scripts/effects/graze_spark.gd"))
	get_tree().current_scene.add_child(spark)


func reset():
	graze_count = 0
	graze_cooldowns.clear()


func _process(_delta: float):
	# Clean up references to freed bullets
	var to_remove: Array = []
	for id in graze_cooldowns:
		if !is_instance_id_valid(id):
			to_remove.append(id)
	for id in to_remove:
		graze_cooldowns.erase(id)
