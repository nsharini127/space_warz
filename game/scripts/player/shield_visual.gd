## Visual indicator for the player's shield buff.
## Draws a pulsing circular shield around the player.
extends Node2D


var _time: float = 0.0
var _player: CharacterBody2D = null


func setup(player: CharacterBody2D) -> void:
	_player = player


func _process(delta: float) -> void:
	_time += delta

	if _player and _player.has_shield:
		visible = true
		queue_redraw()
	else:
		visible = false


func _draw() -> void:
	if not visible:
		return

	var radius: float = 18.0 + sin(_time * 4.0) * 2.0
	var alpha: float = 0.3 + sin(_time * 3.0) * 0.1

	# Outer ring
	draw_arc(Vector2.ZERO, radius, 0, TAU, 32, Color(0.3, 1.0, 1.0, alpha), 1.5)
	# Inner glow
	draw_arc(Vector2.ZERO, radius - 2, 0, TAU, 32, Color(0.5, 1.0, 1.0, alpha * 0.5), 1.0)
