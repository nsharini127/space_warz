extends Node2D


var lifetime: float = 0.2
var timer: float = 0.0
var spark_size: float = 3.0


func _process(delta: float):
	timer += delta
	queue_redraw()
	if timer >= lifetime:
		queue_free()


func _draw():
	var t = timer / lifetime
	var alpha = 1.0 - t
	var size = spark_size * (1.0 + t)
	var col = Color(1, 1, 1, alpha)
	draw_circle(Vector2.ZERO, size, col)
