extends Node2D

# Spawned per shockwave pulse, self-destructs

var max_radius: float = 50.0
var current_radius: float = 0.0
var expand_speed: float = 200.0
var damage: int = 1
var lifetime: float = 0.3
var timer: float = 0.0
var evolved: bool = false
var damaged_enemies: Dictionary = {}

var hit_area: Area2D = null
var hit_shape: CollisionShape2D = null
var circle_shape: CircleShape2D = null


func setup(p_damage: int, p_radius: float, p_evolved: bool):
	damage = p_damage
	max_radius = p_radius
	evolved = p_evolved
	expand_speed = max_radius / lifetime
	z_index = 6

	# Create collision area
	hit_area = Area2D.new()
	hit_area.collision_layer = 4  # PlayerBullet
	hit_area.collision_mask = 2   # Enemy
	hit_area.add_to_group("player_bullet")
	circle_shape = CircleShape2D.new()
	circle_shape.radius = 1.0
	hit_shape = CollisionShape2D.new()
	hit_shape.shape = circle_shape
	hit_area.add_child(hit_shape)
	hit_area.area_entered.connect(_on_area_hit)
	add_child(hit_area)


func _process(delta: float):
	timer += delta
	if timer >= lifetime:
		queue_free()
		return

	current_radius = expand_speed * timer
	if circle_shape:
		circle_shape.radius = current_radius

	queue_redraw()


func _on_area_hit(area: Area2D):
	if area.is_in_group("enemy_hitbox"):
		var enemy = area.get_parent()
		var eid = enemy.get_instance_id()
		if damaged_enemies.has(eid):
			return
		damaged_enemies[eid] = true
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage)


func _draw():
	var alpha = 1.0 - (timer / lifetime)
	var col = Color(0.7, 0.8, 1.0, alpha * 0.6) if !evolved else Color(1.0, 0.8, 0.4, alpha * 0.7)
	var core_col = Color(1.0, 1.0, 1.0, alpha * 0.3)

	# Outer ring
	draw_arc(Vector2.ZERO, current_radius, 0, TAU, 32, col, 2.0)
	# Inner glow
	draw_arc(Vector2.ZERO, current_radius * 0.8, 0, TAU, 24, core_col, 1.0)
