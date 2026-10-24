extends CharacterBody2D


signal enemy_killed(points: int, pos: Vector2)
signal enemy_shoot(bullet_scene: PackedScene, pos: Vector2, dir: Vector2, dmg: int)

@export var max_hp: int = 3
@export var speed: float = 50.0
@export var charge_speed: float = 180.0
@export var points: int = 50
@export var damage: int = 1

var current_hp: int = 3
var is_alive: bool = true
var flash_timer: float = 0.0
var base_modulate: Color = Color.WHITE
var state: String = "descend"
var pause_timer: float = 0.0
var charge_dir: Vector2 = Vector2.DOWN
var player_ref: CharacterBody2D = null
var target_y: float = 120.0
var shoot_timer: float = 0.0

# Telegraph system
var is_telegraphing: bool = false
var telegraph_timer: float = 0.0
const TELEGRAPH_DURATION: float = 0.5
var telegraph_dir: Vector2 = Vector2.DOWN

var bullet_scene: PackedScene = preload("res://scenes/projectiles/bullet_enemy.tscn")

const VIEWPORT_W = 320
const VIEWPORT_H = 480

@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox_area: Area2D = $HitboxArea


func _ready():
	var diff := _get_difficulty()
	max_hp = int(max_hp * diff)
	speed = speed * sqrt(diff)
	charge_speed = charge_speed * sqrt(diff)
	current_hp = max_hp
	is_alive = true
	target_y = randf_range(80.0, 180.0)
	if sprite:
		base_modulate = sprite.modulate
	if hitbox_area:
		hitbox_area.add_to_group("enemy_hitbox")
		hitbox_area.add_to_group("enemy_body")


func _get_difficulty() -> float:
	var game_nodes = get_tree().get_nodes_in_group("game")
	if game_nodes.size() > 0 and game_nodes[0].has_method("get_difficulty_multiplier"):
		return game_nodes[0].get_difficulty_multiplier()
	return 1.0


func set_player(p: CharacterBody2D):
	player_ref = p


func _physics_process(delta: float):
	if !is_alive:
		return

	match state:
		"descend":
			velocity = Vector2(0, speed)
			move_and_slide()
			if position.y >= target_y:
				state = "telegraph"
				is_telegraphing = true
				telegraph_timer = TELEGRAPH_DURATION
				velocity = Vector2.ZERO
				# Calculate telegraph direction toward player
				if player_ref and is_instance_valid(player_ref) and player_ref.is_alive:
					telegraph_dir = (player_ref.position - position).normalized()
				else:
					telegraph_dir = Vector2.DOWN
		"telegraph":
			telegraph_timer -= delta
			# Flash red modulate during telegraph
			sprite.modulate = Color(2, 0.3, 0.3) if fmod(telegraph_timer, 0.15) > 0.075 else base_modulate
			# Update telegraph direction to track player
			if player_ref and is_instance_valid(player_ref) and player_ref.is_alive:
				telegraph_dir = (player_ref.position - position).normalized()
			queue_redraw()
			if telegraph_timer <= 0:
				state = "charge"
				is_telegraphing = false
				sprite.modulate = Color(1, 0.2, 0.2)
				charge_dir = telegraph_dir
				queue_redraw()
		"charge":
			velocity = charge_dir * charge_speed
			move_and_slide()
			# Aimed stream during charge
			shoot_timer -= delta
			if shoot_timer <= 0:
				shoot_timer = 0.3
				if player_ref and is_instance_valid(player_ref) and player_ref.is_alive:
					var aim_dir = (player_ref.global_position - position).normalized()
					enemy_shoot.emit(bullet_scene, position, aim_dir, damage)

	# Remove if off screen
	if position.y > VIEWPORT_H + 30 or position.y < -50 or position.x < -30 or position.x > VIEWPORT_W + 30:
		enemy_killed.emit(0, position)
		queue_free()

	# Flash from damage
	if flash_timer > 0:
		flash_timer -= delta
		sprite.modulate = Color(1, 0.3, 0.3) if fmod(flash_timer, 0.1) > 0.05 else base_modulate
		if flash_timer <= 0:
			sprite.modulate = base_modulate

	# Rotate sprite to face movement/charge direction
	# Sprite default faces down, so offset by +PI/2 instead of -PI/2
	if sprite:
		if state == "charge":
			sprite.rotation = charge_dir.angle() + PI / 2.0
		else:
			sprite.rotation = 0  # Already faces downward


func _draw():
	if !is_telegraphing:
		return
	# Draw red arrow pointing toward the player direction
	var arrow_color = Color(1.0, 0.1, 0.1, 0.8)
	var arrow_length: float = 30.0
	var arrow_tip = telegraph_dir * arrow_length
	var arrow_width: float = 2.0
	# Main line
	draw_line(Vector2.ZERO, arrow_tip, arrow_color, arrow_width)
	# Arrowhead
	var head_size: float = 6.0
	var perp = Vector2(-telegraph_dir.y, telegraph_dir.x)
	var head_base = telegraph_dir * (arrow_length - head_size)
	draw_polygon(
		[arrow_tip, head_base + perp * head_size * 0.5, head_base - perp * head_size * 0.5],
		[arrow_color, arrow_color, arrow_color]
	)


func take_damage(dmg: int):
	if !is_alive:
		return
	current_hp -= dmg
	flash_timer = 0.2
	if current_hp <= 0:
		die()


func die():
	is_alive = false
	enemy_killed.emit(points, position)
	queue_free()
