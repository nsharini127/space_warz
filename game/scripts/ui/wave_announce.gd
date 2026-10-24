## Animated wave announcement overlay with cyberpunk neon styling.
extends Node2D


var text: String = "WAVE 1"
var timer: float = 0.0
var lifetime: float = 2.0
var is_boss_wave: bool = false
var flash_timer: float = 0.0

const VIEWPORT_W: float = 320.0


func setup(wave_text: String, boss: bool = false):
	text = wave_text
	is_boss_wave = boss
	if boss:
		text = "WARNING"
		lifetime = 3.0
	z_index = 50


func _process(delta: float):
	timer += delta
	flash_timer += delta
	queue_redraw()

	if timer >= lifetime:
		queue_free()


func _draw():
	var t = timer / lifetime

	if is_boss_wave:
		_draw_boss_warning(t)
	else:
		_draw_wave_label(t)


func _draw_wave_label(t: float):
	# Slide in from right, hold, slide out left
	var x_offset: float
	if t < 0.2:
		x_offset = lerp(340.0, 160.0, t / 0.2)
	elif t < 0.8:
		x_offset = 160.0
	else:
		x_offset = lerp(160.0, -20.0, (t - 0.8) / 0.2)

	var font = ThemeDB.fallback_font
	if !font:
		return

	var font_size: int = UIColors.FONT_HEADING
	var alpha = 1.0
	if t > 0.7:
		alpha = 1.0 - ((t - 0.7) / 0.3)
	var text_color = Color(UIColors.CYAN.r, UIColors.CYAN.g, UIColors.CYAN.b, alpha)
	var glow_color = Color(UIColors.CYAN.r * 0.5, UIColors.CYAN.g * 0.6, UIColors.CYAN.b, alpha * 0.3)

	var text_width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
	var draw_x = x_offset - text_width * 0.5
	var draw_y: float = 200.0

	# Glow behind text
	draw_string(font, Vector2(draw_x, draw_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size + 2, glow_color)

	# Black outline
	for offset in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		draw_string(font, Vector2(draw_x + offset.x, draw_y + offset.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(UIColors.OUTLINE_BLACK.r, UIColors.OUTLINE_BLACK.g, UIColors.OUTLINE_BLACK.b, text_color.a * 0.8))

	# Main text
	draw_string(font, Vector2(draw_x, draw_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

	# Horizontal accent lines
	if t >= 0.15 and t <= 0.85:
		var line_alpha = text_color.a * 0.4
		var line_y = draw_y + 4
		var line_color = Color(UIColors.CYAN.r, UIColors.CYAN.g * 0.88, UIColors.CYAN.b, line_alpha)
		draw_line(Vector2(20, line_y), Vector2(draw_x - 8, line_y), line_color, 1.0)
		draw_line(Vector2(draw_x + text_width + 8, line_y), Vector2(VIEWPORT_W - 20, line_y), line_color, 1.0)


func _draw_boss_warning(t: float):
	var font = ThemeDB.fallback_font
	if !font:
		return

	# Phase 1 (0-0.4): WARNING flashes in, screen darkens
	# Phase 2 (0.4-0.7): Text holds, pulsing red
	# Phase 3 (0.7-1.0): Fade out

	var alpha: float
	var font_size: int = UIColors.FONT_TITLE

	if t < 0.1:
		# Rapid flash in
		alpha = t / 0.1
	elif t < 0.7:
		# Pulsing
		alpha = 0.6 + 0.4 * sin(flash_timer * 10.0)
	else:
		# Fade out
		alpha = 1.0 - ((t - 0.7) / 0.3)

	# Dark overlay behind warning (creates dramatic moment)
	var overlay_alpha: float = 0.0
	if t < 0.1:
		overlay_alpha = t / 0.1 * 0.35
	elif t < 0.7:
		overlay_alpha = 0.35
	else:
		overlay_alpha = 0.35 * (1.0 - (t - 0.7) / 0.3)
	draw_rect(Rect2(-10, -250, VIEWPORT_W + 20, 500), Color(0, 0, 0, overlay_alpha))

	# Red scan lines (horizontal bars sweeping)
	if t > 0.05 and t < 0.7:
		var scan_alpha = alpha * 0.15
		var scan_color_base = UIColors.RED
		for i in range(12):
			var y_pos = fmod(float(i) * 40.0 + flash_timer * 80.0, 500.0) - 250.0
			draw_rect(Rect2(-10, y_pos, VIEWPORT_W + 20, 2), Color(scan_color_base.r, 0.0, 0.0, scan_alpha))

	# WARNING text
	var text_color = Color(UIColors.BOSS_WARNING.r, UIColors.BOSS_WARNING.g, UIColors.BOSS_WARNING.b, alpha)
	var glow_color = Color(UIColors.RED.r, 0.0, 0.0, alpha * 0.5)

	var text_width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
	var draw_x = VIEWPORT_W * 0.5 - text_width * 0.5
	var draw_y: float = 200.0

	# Red glow (large)
	draw_string(font, Vector2(draw_x, draw_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size + 4, glow_color)

	# Black outline (thicker)
	for offset in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1),
					Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
		draw_string(font, Vector2(draw_x + offset.x, draw_y + offset.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, alpha * 0.9))

	# Main text
	draw_string(font, Vector2(draw_x, draw_y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

	# Red horizontal danger lines
	if t > 0.05 and t < 0.8:
		var line_alpha = alpha * 0.6
		var line_y = draw_y + 6
		var danger_line = Color(UIColors.RED.r, 0.0, 0.0, line_alpha)
		draw_line(Vector2(10, line_y), Vector2(draw_x - 10, line_y), danger_line, 2.0)
		draw_line(Vector2(draw_x + text_width + 10, line_y), Vector2(VIEWPORT_W - 10, line_y), danger_line, 2.0)

		# Second set above text
		var line_y2 = draw_y - font_size - 4
		var danger_line_dim = Color(UIColors.RED.r, 0.0, 0.0, line_alpha * 0.5)
		draw_line(Vector2(10, line_y2), Vector2(draw_x - 10, line_y2), danger_line_dim, 1.0)
		draw_line(Vector2(draw_x + text_width + 10, line_y2), Vector2(VIEWPORT_W - 10, line_y2), danger_line_dim, 1.0)
