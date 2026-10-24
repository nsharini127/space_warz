## Animated trophy unlock popup.
extends Node2D

var trophy_name: String = ""
var bonus_text: String = ""
var timer: float = 0.0
var lifetime: float = 2.5


func setup(p_name: String, p_bonus: String):
	trophy_name = p_name
	bonus_text = p_bonus


func _process(delta: float):
	timer += delta
	if timer >= lifetime:
		queue_free()
		return
	# Float upward slowly
	position.y -= 15.0 * delta
	queue_redraw()


func _draw():
	var progress = timer / lifetime
	var alpha = 1.0 if progress < 0.7 else (1.0 - (progress - 0.7) / 0.3)

	# Background pill (draw first so it's behind text)
	var bg_color = Color(UIColors.PANEL_BG.r, UIColors.PANEL_BG.g, UIColors.PANEL_BG.b, 0.5 * alpha)
	draw_rect(Rect2(-55, -10, 130, 32), bg_color, true)

	# Trophy icon (small star)
	var star_color = Color(UIColors.TROPHY_NAME.r, UIColors.TROPHY_NAME.g, UIColors.TROPHY_NAME.b, alpha)
	_draw_star(Vector2(-50, 0), 6.0, star_color)

	# Trophy name
	var font = ThemeDB.fallback_font
	var name_color = Color(UIColors.TROPHY_NAME.r, UIColors.TROPHY_NAME.g, UIColors.TROPHY_NAME.b, alpha)
	draw_string(font, Vector2(-40, 4), trophy_name, HORIZONTAL_ALIGNMENT_LEFT, -1, UIColors.FONT_BODY, name_color)

	# Bonus text
	var bonus_color = Color(UIColors.TROPHY_BONUS.r, UIColors.TROPHY_BONUS.g, UIColors.TROPHY_BONUS.b, alpha)
	draw_string(font, Vector2(-40, 16), bonus_text, HORIZONTAL_ALIGNMENT_LEFT, -1, UIColors.FONT_SMALL, bonus_color)


func _draw_star(center: Vector2, radius: float, color: Color):
	var points: PackedVector2Array = PackedVector2Array()
	for i in range(10):
		var angle = i * TAU / 10.0 - PI / 2.0
		var r = radius if i % 2 == 0 else radius * 0.4
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	draw_colored_polygon(points, color)
