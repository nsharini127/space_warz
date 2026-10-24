## Pickup item that falls from defeated enemies.
## Collected on contact with the player. Supports multiple item types
## including power-ups, bombs, health, and temporary buffs.
extends Area2D


enum ItemType { POWER, BOMB, LIFE, ATTACK_SPEED, SHIELD, INVINCIBILITY }

var item_type: int = ItemType.POWER
var fall_speed: float = 35.0
var attract_speed: float = 150.0
var is_attracted: bool = false
var target: CharacterBody2D = null
var lifetime: float = 10.0
var timer: float = 0.0

const VIEWPORT_H: int = 480

## Visual configuration per item type: { color, label }
const ITEM_VISUALS: Dictionary = {
	ItemType.POWER:          { "color": Color(1, 0.3, 0.2),  "label": "P" },
	ItemType.BOMB:           { "color": Color(0.3, 0.5, 1.0), "label": "B" },
	ItemType.LIFE:           { "color": Color(0.2, 1.0, 0.4), "label": "1UP" },
	ItemType.ATTACK_SPEED:   { "color": Color(1.0, 0.9, 0.2), "label": "SPD" },
	ItemType.SHIELD:         { "color": Color(0.3, 1.0, 1.0), "label": "SH" },
	ItemType.INVINCIBILITY:  { "color": Color(1.0, 1.0, 1.0), "label": "INV" },
}


func _ready() -> void:
	collision_layer = 16  # Pickup layer
	collision_mask = 1    # Player layer
	add_to_group("pickup")
	area_entered.connect(_on_collected)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0
	shape.shape = circle
	add_child(shape)


func setup(type: int, player: CharacterBody2D) -> void:
	item_type = type
	target = player


func _physics_process(delta: float) -> void:
	timer += delta
	queue_redraw()

	if target and is_instance_valid(target) and target.is_alive:
		var dist: float = global_position.distance_to(target.global_position)
		if dist < 50.0 or is_attracted:
			is_attracted = true
			var dir: Vector2 = (target.global_position - global_position).normalized()
			position += dir * attract_speed * delta
			attract_speed += 300.0 * delta
			return

	position.y += fall_speed * delta

	if position.y > VIEWPORT_H + 20 or timer >= lifetime:
		queue_free()


func _on_collected(area: Area2D) -> void:
	if area.get_parent() is CharacterBody2D:
		queue_free()


func _draw() -> void:
	var visual: Dictionary = ITEM_VISUALS.get(item_type, ITEM_VISUALS[ItemType.POWER])
	var col: Color = visual.color

	var alpha: float = 1.0
	if timer > lifetime - 3.0:
		alpha = 0.5 + 0.5 * sin(timer * 8.0)

	# Background glow
	draw_circle(Vector2.ZERO, 8, Color(col.r, col.g, col.b, alpha * 0.25))

	match item_type:
		ItemType.POWER:
			_draw_lightning_bolt(col, alpha)
		ItemType.BOMB:
			_draw_bomb_icon(col, alpha)
		ItemType.LIFE:
			_draw_medical_cross(col, alpha)
		ItemType.ATTACK_SPEED:
			_draw_speed_arrows(col, alpha)
		ItemType.SHIELD:
			_draw_hexagon(col, alpha)
		ItemType.INVINCIBILITY:
			_draw_star(col, alpha)


func _draw_lightning_bolt(col: Color, alpha: float) -> void:
	var points = PackedVector2Array([
		Vector2(1, -6), Vector2(4, -6), Vector2(0, -1),
		Vector2(3, -1), Vector2(-2, 6), Vector2(0, 1), Vector2(-3, 1),
	])
	var colors = PackedColorArray()
	for _i in range(points.size()):
		colors.append(Color(col.r, col.g, col.b, alpha))
	draw_polygon(points, colors)
	# Orange highlight
	draw_line(Vector2(1, -5), Vector2(-1, 0), Color(1, 0.7, 0.2, alpha * 0.6), 1.0)


func _draw_bomb_icon(col: Color, alpha: float) -> void:
	draw_circle(Vector2(0, 1), 5, Color(col.r, col.g, col.b, alpha))
	# Fuse
	draw_line(Vector2(2, -4), Vector2(3, -6), Color(0.5, 0.3, 0.1, alpha), 1.5)
	# Spark
	var spark_alpha = 0.5 + 0.5 * sin(timer * 12.0)
	draw_circle(Vector2(3, -6), 1.5, Color(1, 0.9, 0.3, alpha * spark_alpha))
	# Highlight
	draw_circle(Vector2(-1.5, -0.5), 1.5, Color(1, 1, 1, alpha * 0.4))


func _draw_medical_cross(col: Color, alpha: float) -> void:
	var c = Color(col.r, col.g, col.b, alpha)
	# Vertical bar
	draw_rect(Rect2(-2, -5, 4, 10), c)
	# Horizontal bar
	draw_rect(Rect2(-5, -2, 10, 4), c)
	# White inner cross
	draw_rect(Rect2(-1, -3, 2, 6), Color(1, 1, 1, alpha * 0.5))
	draw_rect(Rect2(-3, -1, 6, 2), Color(1, 1, 1, alpha * 0.5))


func _draw_speed_arrows(col: Color, alpha: float) -> void:
	var c = Color(col.r, col.g, col.b, alpha)
	# Two upward arrows
	var arrow1 = PackedVector2Array([
		Vector2(-3, 2), Vector2(0, -4), Vector2(3, 2),
	])
	var arrow2 = PackedVector2Array([
		Vector2(-3, 6), Vector2(0, 0), Vector2(3, 6),
	])
	var cols = PackedColorArray([c, c, c])
	draw_polygon(arrow1, cols)
	draw_polygon(arrow2, cols)


func _draw_hexagon(col: Color, alpha: float) -> void:
	var c = Color(col.r, col.g, col.b, alpha)
	var r: float = 5.5
	var prev = Vector2(r, 0)
	for i in range(1, 7):
		var angle = TAU / 6.0 * i
		var next = Vector2(cos(angle) * r, sin(angle) * r)
		draw_line(prev, next, c, 1.5)
		prev = next
	# Inner dot
	draw_circle(Vector2.ZERO, 2, Color(col.r, col.g, col.b, alpha * 0.4))


func _draw_star(col: Color, alpha: float) -> void:
	var points = PackedVector2Array()
	var outer_r: float = 6.0
	var inner_r: float = 2.5
	for i in range(12):
		var angle = TAU / 12.0 * i - PI / 2.0
		var r = outer_r if i % 2 == 0 else inner_r
		points.append(Vector2(cos(angle) * r, sin(angle) * r))
	var colors = PackedColorArray()
	for _i in range(points.size()):
		colors.append(Color(col.r, col.g, col.b, alpha))
	draw_polygon(points, colors)
	# Bright center
	draw_circle(Vector2.ZERO, 2, Color(1, 1, 1, alpha * 0.8))
