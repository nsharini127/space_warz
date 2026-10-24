extends Area2D

var direction: Vector2 = Vector2.UP
var speed: float = 150.0
var turn_speed: float = 4.0
var damage: int = 2
var pierce_count: int = 0
var is_player_bullet: bool = true
var hits: int = 0
var time_alive: float = 0.0
var max_lifetime: float = 4.0
var target: Node2D = null
var enemy_container: Node2D = null

const VIEWPORT_W = 320
const VIEWPORT_H = 480


func _ready():
	add_to_group("player_bullet")
	collision_layer = 4  # PlayerBullet
	collision_mask = 2   # Enemy
	area_entered.connect(_on_hit)

	# Create collision
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(4, 8)
	shape.shape = rect
	add_child(shape)


func _draw():
	# Missile body (orange-yellow, pointing up in local space)
	var body = PackedVector2Array([
		Vector2(-2, 4),   # bottom-left
		Vector2(-2, -2),  # mid-left
		Vector2(0, -6),   # nose tip
		Vector2(2, -2),   # mid-right
		Vector2(2, 4),    # bottom-right
	])
	draw_colored_polygon(body, Color(1.0, 0.7, 0.15))

	# Nose highlight
	var nose = PackedVector2Array([
		Vector2(-1, -2),
		Vector2(0, -6),
		Vector2(1, -2),
	])
	draw_colored_polygon(nose, Color(1.0, 0.9, 0.5))

	# Fins
	var fin_l = PackedVector2Array([Vector2(-2, 3), Vector2(-4, 5), Vector2(-2, 1)])
	var fin_r = PackedVector2Array([Vector2(2, 3), Vector2(4, 5), Vector2(2, 1)])
	draw_colored_polygon(fin_l, Color(1.0, 0.4, 0.1))
	draw_colored_polygon(fin_r, Color(1.0, 0.4, 0.1))

	# Exhaust flame (small flickering)
	var flame_len = randf_range(2.0, 4.0)
	var flame = PackedVector2Array([
		Vector2(-1, 4),
		Vector2(0, 4 + flame_len),
		Vector2(1, 4),
	])
	draw_colored_polygon(flame, Color(1.0, 0.3, 0.0))


func _physics_process(delta: float):
	time_alive += delta
	if time_alive > max_lifetime:
		queue_free()
		return

	# Find nearest enemy
	_acquire_target()

	# Steer toward target
	if target and is_instance_valid(target):
		var desired = (target.global_position - global_position).normalized()
		direction = direction.lerp(desired, turn_speed * delta).normalized()

	position += direction * speed * delta
	rotation = direction.angle() + PI / 2.0
	queue_redraw()

	# Off-screen removal
	if position.y < -30 or position.y > VIEWPORT_H + 30:
		queue_free()
	if position.x < -30 or position.x > VIEWPORT_W + 30:
		queue_free()


func _acquire_target():
	if target and is_instance_valid(target) and target.is_inside_tree():
		if "is_alive" in target and target.is_alive:
			return
	target = null

	if !enemy_container or !is_instance_valid(enemy_container):
		return

	var closest_dist = INF
	for enemy in enemy_container.get_children():
		if !is_instance_valid(enemy):
			continue
		if "is_alive" in enemy and !enemy.is_alive:
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist < closest_dist:
			closest_dist = dist
			target = enemy


func _on_hit(area: Area2D):
	if area.is_in_group("enemy_hitbox"):
		var enemy = area.get_parent()
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage)
		hits += 1
		if hits > pierce_count:
			queue_free()
