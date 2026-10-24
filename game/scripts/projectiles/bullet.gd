extends Area2D


var direction: Vector2 = Vector2.UP
var speed: float = 250.0
var damage: int = 1
var pierce_count: int = 0
@export var is_player_bullet: bool = true
var hits: int = 0
var anim_timer: float = 0.0
var anim_speed: float = 0.1

# Weapon-specific procedural drawing
var weapon_id: String = ""
var _draw_timer: float = 0.0

# MHF bullet properties
var bullet_color: Color = Color.WHITE
var is_wave_bullet: bool = false
var wave_amplitude: float = 30.0
var wave_frequency: float = 3.0
var time_alive: float = 0.0
var base_direction: Vector2 = Vector2.UP

const VIEWPORT_W = 320
const VIEWPORT_H = 480


func _ready():
	if is_player_bullet:
		add_to_group("player_bullet")
		collision_layer = 4  # PlayerBullet layer
		collision_mask = 2   # Enemy layer
		area_entered.connect(_on_hit_enemy)
	else:
		add_to_group("enemy_bullet")
		set_meta("damage", damage)
		collision_layer = 8  # EnemyBullet layer
		collision_mask = 1   # Player layer

	base_direction = direction

	# If weapon_id is set, hide sprite nodes and use procedural _draw() instead
	if weapon_id != "":
		var sprite = get_node_or_null("Sprite2D")
		if sprite:
			sprite.visible = false
		var glow_back = get_node_or_null("GlowBack")
		if glow_back:
			glow_back.visible = false
	else:
		# Apply color tint to shader if present
		var sprite = get_node_or_null("Sprite2D")
		if sprite and sprite.material and sprite.material is ShaderMaterial:
			if bullet_color != Color.WHITE and !is_player_bullet:
				sprite.material = sprite.material.duplicate()
				sprite.material.set_shader_parameter("glow_color", bullet_color)


func _physics_process(delta: float):
	time_alive += delta
	if weapon_id != "":
		_draw_timer += delta
		queue_redraw()

	if is_wave_bullet:
		# Sine wave movement perpendicular to base direction
		var perp = Vector2(-base_direction.y, base_direction.x)
		var wave_offset = sin(time_alive * wave_frequency) * wave_amplitude * delta
		position += direction * speed * delta + perp * wave_offset
	else:
		position += direction * speed * delta

	# Rotate to face direction
	rotation = direction.angle() + PI / 2.0

	# Remove if off screen
	if position.y < -20 or position.y > VIEWPORT_H + 20:
		queue_free()
	if position.x < -20 or position.x > VIEWPORT_W + 20:
		queue_free()


func _on_hit_enemy(area: Area2D):
	if area.is_in_group("enemy_hitbox"):
		var enemy = area.get_parent()
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage)
		hits += 1
		if hits > pierce_count:
			queue_free()


func _draw():
	if weapon_id == "":
		return

	# All drawing is in local space; bullet rotation is handled by the parent node
	# so we draw vertically (pointing UP) and let rotation orient it
	var pulse = 0.5 + 0.5 * sin(_draw_timer * 12.0)

	match weapon_id:
		"front_laser":
			_draw_front_laser(pulse)
		"spread_shot":
			_draw_spread_shot(pulse)
		"rear_cannon":
			_draw_rear_cannon(pulse)
		"side_cannons":
			_draw_side_cannons(pulse)
		"drone":
			_draw_drone_bullet(pulse)


func _draw_front_laser(pulse: float):
	# Elongated laser beam - thin 3px wide, 14px tall, bright center line + glow edges
	var half_w: float = 1.5
	var half_h: float = 7.0

	# Outer glow (soft cyan)
	var glow_color = Color(0.0, 0.7, 1.0, 0.2 + pulse * 0.1)
	draw_rect(Rect2(-half_w - 1.5, -half_h - 1, (half_w + 1.5) * 2, (half_h + 1) * 2), glow_color)

	# Main body (cyan)
	var body_color = Color(0.0, 0.8, 1.0, 0.85)
	draw_rect(Rect2(-half_w, -half_h, half_w * 2, half_h * 2), body_color)

	# Bright center line (white-cyan)
	var center_color = Color(0.7, 0.95, 1.0, 0.9 + pulse * 0.1)
	draw_rect(Rect2(-0.5, -half_h + 1, 1.0, half_h * 2 - 2), center_color)

	# Tip highlight
	draw_circle(Vector2(0, -half_h), 1.5, Color(0.8, 1.0, 1.0, 0.7 + pulse * 0.3))


func _draw_spread_shot(pulse: float):
	# Small round pellet - 3px radius circle with bright center and outer glow
	var radius: float = 3.0

	# Outer glow
	var glow_color = Color(1.0, 0.9, 0.2, 0.15 + pulse * 0.1)
	draw_circle(Vector2.ZERO, radius + 2.0, glow_color)

	# Main body (yellow)
	var body_color = Color(1.0, 0.9, 0.3, 0.9)
	draw_circle(Vector2.ZERO, radius, body_color)

	# Bright center dot (white-yellow)
	var center_color = Color(1.0, 1.0, 0.8, 0.9 + pulse * 0.1)
	draw_circle(Vector2.ZERO, 1.2, center_color)


func _draw_rear_cannon(pulse: float):
	# Thick energy bolt - 5px wide, 10px tall, bright core + darker red edges
	var half_w: float = 2.5
	var half_h: float = 5.0

	# Outer dark-red glow
	var glow_color = Color(0.8, 0.1, 0.1, 0.2 + pulse * 0.1)
	draw_rect(Rect2(-half_w - 1.5, -half_h - 1, (half_w + 1.5) * 2, (half_h + 1) * 2), glow_color)

	# Darker red edges
	var edge_color = Color(0.7, 0.1, 0.1, 0.85)
	draw_rect(Rect2(-half_w, -half_h, half_w * 2, half_h * 2), edge_color)

	# Bright red-orange core
	var core_color = Color(1.0, 0.35, 0.2, 0.9 + pulse * 0.1)
	draw_rect(Rect2(-half_w + 1, -half_h + 1, (half_w - 1) * 2, (half_h - 1) * 2), core_color)

	# Hot white center line
	var center_color = Color(1.0, 0.7, 0.5, 0.7 + pulse * 0.2)
	draw_rect(Rect2(-0.5, -half_h + 2, 1.0, half_h * 2 - 4), center_color)


func _draw_side_cannons(pulse: float):
	# Thin laser dash - 2px wide, 10px tall, sharp bright center
	var half_w: float = 1.0
	var half_h: float = 5.0

	# Soft green glow
	var glow_color = Color(0.2, 1.0, 0.3, 0.15 + pulse * 0.1)
	draw_rect(Rect2(-half_w - 1.5, -half_h - 0.5, (half_w + 1.5) * 2, (half_h + 0.5) * 2), glow_color)

	# Main body (green)
	var body_color = Color(0.2, 1.0, 0.3, 0.85)
	draw_rect(Rect2(-half_w, -half_h, half_w * 2, half_h * 2), body_color)

	# Sharp bright center (white-green)
	var center_color = Color(0.7, 1.0, 0.8, 0.9 + pulse * 0.1)
	draw_rect(Rect2(-0.3, -half_h + 0.5, 0.6, half_h * 2 - 1), center_color)

	# Tip point
	draw_circle(Vector2(0, -half_h), 1.0, Color(0.5, 1.0, 0.6, 0.7 + pulse * 0.3))


func _draw_drone_bullet(pulse: float):
	# Small blue-white bolt for drone bullets
	var half_w: float = 1.0
	var half_h: float = 4.0

	# Glow
	var glow_color = Color(0.4, 0.6, 1.0, 0.2 + pulse * 0.1)
	draw_circle(Vector2.ZERO, 3.5, glow_color)

	# Body
	var body_color = Color(0.5, 0.7, 1.0, 0.9)
	draw_rect(Rect2(-half_w, -half_h, half_w * 2, half_h * 2), body_color)

	# Center
	var center_color = Color(0.8, 0.9, 1.0, 0.9 + pulse * 0.1)
	draw_rect(Rect2(-0.3, -half_h + 1, 0.6, half_h * 2 - 2), center_color)
