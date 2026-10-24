extends Control

## Procedural weapon icon drawn via _draw().
## Each weapon ID gets a unique shape in a 16x16 viewport.

var weapon_id: String = ""
var icon_color: Color = Color.WHITE
var evolved: bool = false


func setup(id: String, color: Color, is_evolved: bool):
	weapon_id = id
	icon_color = color
	evolved = is_evolved
	custom_minimum_size = Vector2(16, 16)
	size = Vector2(16, 16)
	queue_redraw()


func _draw():
	if weapon_id == "":
		return

	var c: Color = icon_color
	if evolved:
		c = Color(1.0, 0.85, 0.2)

	match weapon_id:
		"front_laser":
			_draw_front_laser(c)
		"spread_shot":
			_draw_spread_shot(c)
		"homing_missile":
			_draw_homing_missile(c)
		"rear_cannon":
			_draw_rear_cannon(c)
		"side_cannons":
			_draw_side_cannons(c)
		"lightning":
			_draw_lightning(c)
		"orbital_shield":
			_draw_orbital_shield(c)
		"drone":
			_draw_drone(c)
		"shockwave":
			_draw_shockwave(c)
		_:
			# Fallback: simple square
			draw_rect(Rect2(4, 4, 8, 8), c, true)


# ---------------------------------------------------------------------------
# 1. Front Laser: 3 parallel vertical lines, center brightest
# ---------------------------------------------------------------------------
func _draw_front_laser(c: Color):
	var bright = c
	var dim = Color(c.r, c.g, c.b, 0.5)
	# Left line
	draw_line(Vector2(5, 2), Vector2(5, 14), dim, 1.5)
	# Center line (brightest, thicker)
	draw_line(Vector2(8, 1), Vector2(8, 15), bright, 2.0)
	# Right line
	draw_line(Vector2(11, 2), Vector2(11, 14), dim, 1.5)


# ---------------------------------------------------------------------------
# 2. Spread Shot: fan pattern, 5 lines from bottom center
# ---------------------------------------------------------------------------
func _draw_spread_shot(c: Color):
	var origin = Vector2(8, 14)
	var angles = [-60.0, -30.0, 0.0, 30.0, 60.0]
	var length = 11.0
	for i in range(angles.size()):
		var a = deg_to_rad(angles[i] - 90.0)  # -90 to point upward
		var end_pt = origin + Vector2(cos(a), sin(a)) * length
		var alpha = 1.0 if i == 2 else 0.6
		var col = Color(c.r, c.g, c.b, alpha)
		var w = 1.5 if i == 2 else 1.0
		draw_line(origin, end_pt, col, w)


# ---------------------------------------------------------------------------
# 3. Homing Missile: rocket shape (triangle + tail fins)
# ---------------------------------------------------------------------------
func _draw_homing_missile(c: Color):
	# Rocket body (triangle pointing up)
	var body = PackedVector2Array([
		Vector2(8, 2),   # nose
		Vector2(11, 10),
		Vector2(5, 10),
	])
	draw_colored_polygon(body, c)

	# Tail/exhaust section
	draw_rect(Rect2(6, 10, 4, 2), Color(c.r * 0.7, c.g * 0.7, c.b * 0.7), true)

	# Fins
	var left_fin = PackedVector2Array([
		Vector2(5, 9),
		Vector2(3, 13),
		Vector2(5, 12),
	])
	var right_fin = PackedVector2Array([
		Vector2(11, 9),
		Vector2(13, 13),
		Vector2(11, 12),
	])
	var fin_color = Color(c.r * 0.8, c.g * 0.8, c.b * 0.8)
	draw_colored_polygon(left_fin, fin_color)
	draw_colored_polygon(right_fin, fin_color)

	# Exhaust flame
	var flame = PackedVector2Array([
		Vector2(7, 12),
		Vector2(8, 15),
		Vector2(9, 12),
	])
	draw_colored_polygon(flame, Color(1.0, 0.5, 0.1))


# ---------------------------------------------------------------------------
# 4. Rear Cannon: downward pointing bolt/arrow
# ---------------------------------------------------------------------------
func _draw_rear_cannon(c: Color):
	# Thick vertical shaft
	draw_rect(Rect2(6, 2, 4, 8), c, true)
	# Downward arrowhead
	var arrow = PackedVector2Array([
		Vector2(3, 9),
		Vector2(8, 15),
		Vector2(13, 9),
	])
	draw_colored_polygon(arrow, c)


# ---------------------------------------------------------------------------
# 5. Side Cannons: two horizontal arrows pointing left + right
# ---------------------------------------------------------------------------
func _draw_side_cannons(c: Color):
	# Left arrow
	draw_line(Vector2(2, 5), Vector2(8, 5), c, 1.5)
	var left_head = PackedVector2Array([
		Vector2(2, 5),
		Vector2(5, 3),
		Vector2(5, 7),
	])
	draw_colored_polygon(left_head, c)

	# Right arrow
	draw_line(Vector2(8, 11), Vector2(14, 11), c, 1.5)
	var right_head = PackedVector2Array([
		Vector2(14, 11),
		Vector2(11, 9),
		Vector2(11, 13),
	])
	draw_colored_polygon(right_head, c)


# ---------------------------------------------------------------------------
# 6. Lightning: zigzag bolt
# ---------------------------------------------------------------------------
func _draw_lightning(c: Color):
	var points = PackedVector2Array([
		Vector2(10, 1),
		Vector2(6, 6),
		Vector2(9, 6),
		Vector2(5, 11),
		Vector2(8, 11),
		Vector2(4, 16),
	])
	# Glow behind (thicker, dimmer)
	var glow = Color(c.r, c.g, c.b, 0.3)
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], glow, 3.0)
	# Main bolt
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], c, 1.5)


# ---------------------------------------------------------------------------
# 7. Orbital Shield: circle ring with orbiting dots
# ---------------------------------------------------------------------------
func _draw_orbital_shield(c: Color):
	var center = Vector2(8, 8)
	var radius = 5.0

	# Ring (arc approximation)
	draw_arc(center, radius, 0, TAU, 24, c, 1.5)

	# Inner dot (the "core")
	draw_circle(center, 1.5, Color(c.r, c.g, c.b, 0.6))

	# Orbiting dots (3 dots at 120-degree intervals)
	for i in range(3):
		var angle = TAU * i / 3.0
		var dot_pos = center + Vector2(cos(angle), sin(angle)) * radius
		draw_circle(dot_pos, 1.5, c)


# ---------------------------------------------------------------------------
# 8. Drone: diamond shape with propeller lines
# ---------------------------------------------------------------------------
func _draw_drone(c: Color):
	# Diamond body
	var diamond = PackedVector2Array([
		Vector2(8, 3),   # top
		Vector2(12, 8),  # right
		Vector2(8, 13),  # bottom
		Vector2(4, 8),   # left
	])
	draw_colored_polygon(diamond, c)

	# Inner darker diamond
	var inner = PackedVector2Array([
		Vector2(8, 5),
		Vector2(10, 8),
		Vector2(8, 11),
		Vector2(6, 8),
	])
	draw_colored_polygon(inner, Color(c.r * 0.5, c.g * 0.5, c.b * 0.5))

	# Propeller lines (top)
	var prop_color = Color(c.r, c.g, c.b, 0.6)
	draw_line(Vector2(5, 2), Vector2(11, 2), prop_color, 1.0)
	draw_line(Vector2(6, 1), Vector2(10, 1), prop_color, 1.0)


# ---------------------------------------------------------------------------
# 9. Shockwave: concentric expanding arcs
# ---------------------------------------------------------------------------
func _draw_shockwave(c: Color):
	var center = Vector2(8, 8)

	# Inner ring (brightest)
	draw_arc(center, 2.5, 0, TAU, 16, c, 1.5)

	# Middle ring
	var mid = Color(c.r, c.g, c.b, 0.65)
	draw_arc(center, 4.5, 0, TAU, 20, mid, 1.0)

	# Outer ring (dimmest)
	var outer = Color(c.r, c.g, c.b, 0.35)
	draw_arc(center, 6.5, 0, TAU, 24, outer, 1.0)
