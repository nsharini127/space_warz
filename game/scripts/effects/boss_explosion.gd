extends Node2D


signal boss_explosion_finished

var explosions_remaining: int = 5
var explosion_timer: float = 0.0
var explosion_interval: float = 0.4
var total_timer: float = 0.0
var slowmo_applied: bool = false


func _ready():
	z_index = 20


func _process(delta: float):
	# Use unscaled delta for timing during slowmo
	var real_delta = delta / max(Engine.time_scale, 0.01)
	total_timer += real_delta
	explosion_timer += real_delta

	# Apply slowmo after first explosion
	if !slowmo_applied and explosions_remaining < 5:
		Engine.time_scale = 0.3
		slowmo_applied = true

	if explosion_timer >= explosion_interval and explosions_remaining > 0:
		explosion_timer = 0.0
		explosions_remaining -= 1
		_spawn_sub_explosion()

	if total_timer >= 2.5:
		Engine.time_scale = 1.0
		boss_explosion_finished.emit()
		queue_free()


func _spawn_sub_explosion():
	var offset = Vector2(randf_range(-30, 30), randf_range(-30, 30))
	var exp_node = Node2D.new()
	exp_node.position = offset
	add_child(exp_node)

	# Flash circle
	var flash = _create_flash(exp_node)
	# Sparks
	for i in range(8):
		_create_spark(exp_node)


func _create_flash(parent: Node2D) -> Node2D:
	var flash = Node2D.new()
	flash.set_script(preload("res://scripts/effects/explosion_flash.gd"))
	parent.add_child(flash)
	return flash


func _create_spark(parent: Node2D):
	var spark = Node2D.new()
	spark.set_script(preload("res://scripts/effects/explosion_spark.gd"))
	parent.add_child(spark)
