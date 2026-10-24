extends Area2D


enum GemType { SMALL, LARGE }

var gem_type: GemType = GemType.SMALL
var fall_speed: float = 30.0
var attract_speed: float = 200.0
var attract_radius: float = 40.0
var focus_attract_radius: float = 120.0
var is_attracted: bool = false
var target: CharacterBody2D = null
var gem_value: int = 1
var lifetime: float = 8.0
var timer: float = 0.0
var color: Color = Color(0.2, 1.0, 0.4)  # Green default

const VIEWPORT_W = 320
const VIEWPORT_H = 480


func _ready():
	collision_layer = 16  # Layer 5 Pickup
	collision_mask = 1    # Player layer
	add_to_group("gem")

	area_entered.connect(_on_collected)

	# Set up collision shape
	var shape_node = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 6.0
	shape_node.shape = circle
	add_child(shape_node)

	match gem_type:
		GemType.SMALL:
			gem_value = 1
		GemType.LARGE:
			gem_value = 2


func setup(type: GemType, col: Color, player: CharacterBody2D):
	gem_type = type
	color = col
	target = player
	match type:
		GemType.SMALL:
			gem_value = 1
		GemType.LARGE:
			gem_value = 2


func _physics_process(delta: float):
	timer += delta
	queue_redraw()

	if target and is_instance_valid(target) and target.is_alive:
		var dist = global_position.distance_to(target.global_position)
		var radius = focus_attract_radius if target.is_focused else attract_radius

		if dist < radius or is_attracted:
			is_attracted = true
			var dir = (target.global_position - global_position).normalized()
			position += dir * attract_speed * delta
			attract_speed += 400.0 * delta  # Accelerate toward player
			return

	# Fall downward
	position.y += fall_speed * delta

	# Remove if off screen or expired
	if position.y > VIEWPORT_H + 20 or timer >= lifetime:
		queue_free()


func _on_collected(area: Area2D):
	if area.get_parent() is CharacterBody2D:
		queue_free()


func _draw():
	var size = 8.0 if gem_type == GemType.SMALL else 12.0
	var alpha = 1.0
	if timer > lifetime - 2.0:
		alpha = 0.5 + 0.5 * sin(timer * 10.0)

	# Pulsating glow effect
	var glow_pulse = 1.0 + sin(timer * 4.0) * 0.2
	var glow_size = size * 1.4 * glow_pulse

	# Gem colors: SMALL = bright green, LARGE = gold
	var gem_color: Color
	if gem_type == GemType.LARGE:
		gem_color = Color(1.0, 0.85, 0.2)
	else:
		gem_color = Color(0.2, 1.0, 0.4)

	# Outer glow
	draw_circle(Vector2.ZERO, glow_size, Color(gem_color.r, gem_color.g, gem_color.b, alpha * 0.2))

	# Rotation angle for crystal spin
	var rot = timer * 2.0

	# Hexagonal crystal shape
	var hex_points = PackedVector2Array()
	for i in range(6):
		var angle = TAU / 6.0 * i + rot
		hex_points.append(Vector2(cos(angle) * size * 0.6, sin(angle) * size * 0.6))

	var hex_colors = PackedColorArray()
	for _i in range(6):
		hex_colors.append(Color(gem_color.r, gem_color.g, gem_color.b, alpha))
	draw_polygon(hex_points, hex_colors)

	# Inner facets for 3D effect - smaller hexagon rotated opposite
	var inner_points = PackedVector2Array()
	for i in range(6):
		var angle = TAU / 6.0 * i - rot * 0.5
		inner_points.append(Vector2(cos(angle) * size * 0.3, sin(angle) * size * 0.3))

	var inner_colors = PackedColorArray()
	for _i in range(6):
		inner_colors.append(Color(1, 1, 1, alpha * 0.35))
	draw_polygon(inner_points, inner_colors)

	# Bright center highlight
	draw_circle(Vector2.ZERO, size * 0.15, Color(1, 1, 1, alpha * 0.9))
