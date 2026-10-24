extends Node2D

# Persistent flame effect node, managed by weapon_manager
# Spawned per tick, self-destructs quickly

var damage: int = 1
var flame_range: float = 40.0
var cone_angle: float = deg_to_rad(45)
var evolved: bool = false
var lifetime: float = 0.12
var timer: float = 0.0
var player: CharacterBody2D = null
var damaged_enemies: Dictionary = {}

var hit_area: Area2D = null


func setup(p_player: CharacterBody2D, p_damage: int, p_range: float, p_angle: float, p_evolved: bool):
	player = p_player
	damage = p_damage
	flame_range = p_range
	cone_angle = p_angle
	evolved = p_evolved
	z_index = 6

	# Create hit area covering the cone
	hit_area = Area2D.new()
	hit_area.collision_layer = 4
	hit_area.collision_mask = 2
	hit_area.add_to_group("player_bullet")
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = flame_range
	shape.shape = circle
	hit_area.add_child(shape)
	hit_area.area_entered.connect(_on_area_hit)
	add_child(hit_area)


func _process(delta: float):
	timer += delta
	if timer >= lifetime:
		queue_free()
		return

	if player and player.is_alive:
		global_position = player.global_position + Vector2(0, -8)

	queue_redraw()


func _on_area_hit(area: Area2D):
	if area.is_in_group("enemy_hitbox"):
		var enemy = area.get_parent()
		# Check if enemy is in the cone
		var to_enemy = enemy.global_position - global_position
		var dist = to_enemy.length()
		if dist > flame_range:
			return
		# Check cone angle (upward)
		var angle_to = Vector2.UP.angle_to(to_enemy)
		if abs(angle_to) > cone_angle / 2.0:
			return

		var eid = enemy.get_instance_id()
		if damaged_enemies.has(eid):
			return
		damaged_enemies[eid] = true
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage)


func _draw():
	var alpha = 1.0 - (timer / lifetime)
	# Draw cone of flame particles
	var num_particles = 8
	for i in range(num_particles):
		var t = float(i) / num_particles
		var angle_offset = (t - 0.5) * cone_angle
		var dir = Vector2(sin(angle_offset), -cos(angle_offset))
		var dist = randf_range(5, flame_range) * (0.5 + timer / lifetime * 0.5)
		var pos = dir * dist
		var size = randf_range(2, 4) * alpha

		# Flame colors
		var col: Color
		if evolved:
			col = Color(1.0, 0.3, 0.1, alpha * 0.7)
		else:
			col = Color(1.0, 0.6, 0.2, alpha * 0.6)

		draw_circle(pos, size, col)

	# Core glow
	var core_col = Color(1.0, 0.9, 0.3, alpha * 0.3)
	draw_circle(Vector2(0, -5), 6.0, core_col)
