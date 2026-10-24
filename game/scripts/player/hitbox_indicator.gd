extends Node2D


var pulse_time: float = 0.0


func _ready():
	visible = false
	z_index = 10


func _process(delta: float):
	if !visible:
		return
	pulse_time += delta * 4.0
	queue_redraw()


func _draw():
	var alpha = 0.7 + sin(pulse_time) * 0.3
	# Bright center point
	draw_circle(Vector2.ZERO, 2, Color(1, 1, 1, alpha))
	# Cyan glow ring
	draw_circle(Vector2.ZERO, 4, Color(0, 1, 1, alpha * 0.4))
	draw_arc(Vector2.ZERO, 4, 0, TAU, 16, Color(0, 1, 1, alpha * 0.6), 1.0)
