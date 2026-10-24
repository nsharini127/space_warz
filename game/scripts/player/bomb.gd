extends Node2D


signal bomb_finished
signal convert_bullets_to_gems

var radius: float = 0.0
var max_radius: float = 300.0
var expand_speed: float = 400.0
var lifetime: float = 1.5
var timer: float = 0.0
var active: bool = false


func activate():
	active = true
	radius = 0.0
	timer = 0.0
	convert_bullets_to_gems.emit()


func _process(delta: float):
	if !active:
		return

	timer += delta
	radius = min(radius + expand_speed * delta, max_radius)
	queue_redraw()

	if timer >= lifetime:
		active = false
		bomb_finished.emit()
		queue_free()


func _draw():
	if !active:
		return

	var alpha = 1.0 - (timer / lifetime)
	var ring_color = Color(1, 1, 1, alpha * 0.6)
	var inner_color = Color(0.5, 0.8, 1.0, alpha * 0.15)

	# Inner glow fill
	draw_circle(Vector2.ZERO, radius, inner_color)
	# Outer ring
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, ring_color, 3.0)
	# Secondary ring
	if radius > 30:
		var ring2_color = Color(0.8, 0.9, 1.0, alpha * 0.3)
		draw_arc(Vector2.ZERO, radius * 0.7, 0, TAU, 48, ring2_color, 2.0)
