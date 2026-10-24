extends Node2D


var text: String = "100"
var timer: float = 0.0
var lifetime: float = 0.6
var rise_speed: float = 40.0
var font_size: int = 8
var color: Color = Color.WHITE


func setup(score_text: String, col: Color = Color.WHITE, big: bool = false):
	text = score_text
	color = col
	if big:
		font_size = 12
		lifetime = 0.8


func _process(delta: float):
	timer += delta
	position.y -= rise_speed * delta
	rise_speed *= 0.97

	queue_redraw()

	if timer >= lifetime:
		queue_free()


func _draw():
	var t = timer / lifetime
	var alpha = 1.0 - t * t
	var col = Color(color.r, color.g, color.b, alpha)
	var font = ThemeDB.fallback_font
	if font:
		draw_string(font, Vector2(-20, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 40, font_size, col)
