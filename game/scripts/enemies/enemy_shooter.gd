extends CharacterBody2D


signal enemy_killed(points: int, pos: Vector2)
signal enemy_shoot(bullet_scene: PackedScene, pos: Vector2, dir: Vector2, dmg: int)

@export var max_hp: int = 4
@export var speed: float = 30.0
@export var points: int = 200
@export var damage: int = 1
@export var shoot_interval: float = 2.0
@export var stop_y: float = 80.0

var current_hp: int = 4
var is_alive: bool = true
var flash_timer: float = 0.0
var base_modulate: Color = Color.WHITE
var shoot_timer: float = 1.0
var stopped: bool = false
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
	shoot_timer = randf_range(0.5, shoot_interval)
	stop_y = randf_range(40, 160)
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

	move_enemy(delta)

	if position.y > VIEWPORT_H + 30:
		enemy_killed.emit(0, position)
		queue_free()

	# Shooting: aimed fan 3-way
	if stopped:
		shoot_timer -= delta
		if shoot_timer <= 0:
			shoot_timer = shoot_interval
			fire_aimed_fan()

	if flash_timer > 0:
		flash_timer -= delta
		sprite.modulate = Color(1, 0.3, 0.3) if fmod(flash_timer, 0.1) > 0.05 else base_modulate
		if flash_timer <= 0:
			sprite.modulate = base_modulate

	# Sprite already faces down by default - no rotation needed


func move_enemy(delta: float):
	if !stopped and position.y >= stop_y:
		stopped = true
		velocity = Vector2.ZERO
	elif !stopped:
		velocity = Vector2(0, speed)

	if !stopped:
		move_and_slide()


func fire_aimed_fan():
	var player_pos: Vector2
	if player_ref and is_instance_valid(player_ref) and player_ref.is_alive:
		player_pos = player_ref.global_position
	else:
		player_pos = Vector2(160, 384)

	var aim_angle = (player_pos - position).angle()

	# 3-way aimed fan
	for i in range(3):
		var offset = (i - 1) * deg_to_rad(15)
		var dir = Vector2(cos(aim_angle + offset), sin(aim_angle + offset))
		enemy_shoot.emit(bullet_scene, position + Vector2(0, 10), dir, damage)


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
