extends Node2D


var timer: float = 0.0
var lifetime: float = 0.3
var max_radius: float = 25.0


func _process(delta: float):
	timer += delta
	queue_redraw()
	if timer >= lifetime:
		queue_free()


func _draw():
	var t = timer / lifetime
	var radius = max_radius * (0.5 + t * 0.5)
	var alpha = 1.0 - t
	draw_circle(Vector2.ZERO, radius, Color(1, 1, 1, alpha * 0.8))
	draw_circle(Vector2.ZERO, radius * 0.6, Color(1, 0.8, 0.4, alpha * 0.5))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(1, 0.5, 0.2, alpha), 2.0)
