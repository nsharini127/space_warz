extends Node2D


var vel: Vector2
var timer: float = 0.0
var lifetime: float = 0.4
var trail: Array = []


func _ready():
	var angle = randf() * TAU
	var speed = randf_range(80, 160)
	vel = Vector2(cos(angle), sin(angle)) * speed
	lifetime = randf_range(0.3, 0.5)


func _process(delta: float):
	timer += delta
	position += vel * delta
	vel *= 0.95  # Friction

	trail.append(Vector2(global_position))
	if trail.size() > 6:
		trail.pop_front()

	queue_redraw()

	if timer >= lifetime:
		queue_free()


func _draw():
	var t = timer / lifetime
	var alpha = 1.0 - t
	var size = 2.0 * (1.0 - t)
	draw_circle(Vector2.ZERO, size, Color(1, 0.7, 0.3, alpha))
