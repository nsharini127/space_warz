## Mine: Dropped by bomber. Floats down, explodes after 2 seconds into a 6-bullet ring.
extends Area2D


var damage: int = 1
var fuse_timer: float = 2.0
var fall_speed: float = 20.0
var exploded: bool = false

var bullet_scene: PackedScene = preload("res://scenes/projectiles/bullet_enemy.tscn")

const VIEWPORT_H = 480


func _ready():
	collision_layer = 2  # Enemy layer
	collision_mask = 4   # Player bullet layer
	add_to_group("enemy_hitbox")
	add_to_group("enemy_body")

	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	add_child(shape)


func _physics_process(delta: float):
	if exploded:
		return

	position.y += fall_speed * delta
	fuse_timer -= delta
	queue_redraw()

	if fuse_timer <= 0:
		_explode()

	if position.y > VIEWPORT_H + 20:
		queue_free()


func _explode():
	exploded = true
	# Spawn 6-bullet ring
	for i in range(6):
		var angle = (TAU / 6.0) * i
		var dir = Vector2(cos(angle), sin(angle))
		# Create bullet directly since we can't easily use the signal
		var bullet = bullet_scene.instantiate()
		bullet.position = global_position + dir * 8
		bullet.direction = dir
		bullet.damage = damage
		bullet.is_player_bullet = false
		var parent = get_parent()
		if parent:
			# Find bullet container (sibling named BulletContainer)
			var game_node = parent.get_parent()
			if game_node:
				var bc = game_node.get_node_or_null("BulletContainer")
				if bc:
					bc.add_child(bullet)
				else:
					parent.add_child(bullet)
			else:
				parent.add_child(bullet)
	queue_free()


func take_damage(dmg: int):
	# Mines can be shot to destroy them early
	_explode()


func _draw():
	var pulse = 0.5 + 0.5 * sin(fuse_timer * 8.0)
	# Mine body
	draw_circle(Vector2.ZERO, 5, Color(0.6, 0.2, 0.2, 0.9))
	# Blinking light
	draw_circle(Vector2(0, -3), 2, Color(1.0, 0.3, 0.1, pulse))
	# Outer ring
	var r: float = 6.0
	var prev = Vector2(r, 0)
	for i in range(1, 9):
		var angle = TAU / 8.0 * i
		var next = Vector2(cos(angle) * r, sin(angle) * r)
		draw_line(prev, next, Color(0.8, 0.3, 0.1, 0.6), 1.0)
		prev = next
