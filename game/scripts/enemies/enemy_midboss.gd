extends CharacterBody2D


signal enemy_killed(points: int, pos: Vector2)
signal enemy_shoot(bullet_scene: PackedScene, pos: Vector2, dir: Vector2, dmg: int)
signal midboss_died(pos: Vector2)

@export var max_hp: int = 15
@export var speed: float = 25.0
@export var points: int = 500
@export var damage: int = 1
@export var shoot_interval: float = 1.2

var current_hp: int = 15
var is_alive: bool = true
var flash_timer: float = 0.0
var base_modulate: Color = Color.WHITE
var shoot_timer: float = 1.5
var stopped: bool = false
var move_dir: int = 1
var pattern_angle: float = 0.0
var player_ref: CharacterBody2D = null

var bullet_scene: PackedScene = preload("res://scenes/projectiles/bullet_enemy.tscn")

const VIEWPORT_W = 320
const VIEWPORT_H = 480

@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox_area: Area2D = $HitboxArea


func _ready():
	var diff := _get_difficulty()
	max_hp = int(max_hp * diff)
	speed = speed * sqrt(diff)
	current_hp = max_hp
	is_alive = true
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

	# Move to stop position
	if !stopped and position.y >= 80:
		stopped = true
	elif !stopped:
		velocity = Vector2(0, speed)
		move_and_slide()

	# Strafe when stopped
	if stopped:
		position.x += move_dir * speed * delta
		if position.x > VIEWPORT_W - 40:
			move_dir = -1
		elif position.x < 40:
			move_dir = 1

	# Remove if off screen
	if position.y > VIEWPORT_H + 50:
		enemy_killed.emit(0, position)
		queue_free()

	# Shooting
	if stopped:
		shoot_timer -= delta
		if shoot_timer <= 0:
			shoot_timer = shoot_interval
			fire_pattern()

	# Flash
	if flash_timer > 0:
		flash_timer -= delta
		sprite.modulate = Color(1, 0.3, 0.3) if fmod(flash_timer, 0.1) > 0.05 else base_modulate
		if flash_timer <= 0:
			sprite.modulate = base_modulate

	# Sprite already faces down by default


func fire_pattern():
	pattern_angle += deg_to_rad(15)

	# Radial burst with spin
	for i in range(12):
		var angle = pattern_angle + (TAU / 12.0) * i
		var dir = Vector2(cos(angle), sin(angle))
		enemy_shoot.emit(bullet_scene, position + dir * 16, dir, damage)

	# Aimed shot at player
	if player_ref and is_instance_valid(player_ref) and player_ref.is_alive:
		var aim_dir = (player_ref.global_position - position).normalized()
		enemy_shoot.emit(bullet_scene, position, aim_dir, damage)


func take_damage(dmg: int):
	if !is_alive:
		return
	current_hp -= dmg
	flash_timer = 0.2
	if current_hp <= 0:
		die()


func die():
	is_alive = false
	midboss_died.emit(position)
	enemy_killed.emit(points, position)
	queue_free()
