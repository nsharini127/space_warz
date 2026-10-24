## Enemy Tank: High HP, slow, strafes and fires ring of 6 bullets.
## Appears from wave 7+.
extends CharacterBody2D


signal enemy_killed(points: int, pos: Vector2)
signal enemy_shoot(bullet_scene: PackedScene, pos: Vector2, dir: Vector2, dmg: int)

@export var max_hp: int = 8
@export var speed: float = 20.0
@export var points: int = 200
@export var damage: int = 1
@export var shoot_interval: float = 3.0

var current_hp: int = 8
var is_alive: bool = true
var flash_timer: float = 0.0
var base_modulate: Color = Color.WHITE
var shoot_timer: float = 2.0
var stopped: bool = false
var move_dir: int = 1

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


func set_player(_p: CharacterBody2D):
	pass


func _physics_process(delta: float):
	if !is_alive:
		return

	# Descend to stop position
	if !stopped and position.y >= 80:
		stopped = true
	elif !stopped:
		velocity = Vector2(0, speed)
		move_and_slide()

	# Slow strafe when stopped
	if stopped:
		position.x += move_dir * speed * 0.5 * delta
		if position.x > VIEWPORT_W - 30:
			move_dir = -1
		elif position.x < 30:
			move_dir = 1

	if position.y > VIEWPORT_H + 50:
		enemy_killed.emit(0, position)
		queue_free()

	# Shooting: ring of 6 bullets
	if stopped:
		shoot_timer -= delta
		if shoot_timer <= 0:
			shoot_timer = shoot_interval
			_fire_ring()

	# Flash
	if flash_timer > 0:
		flash_timer -= delta
		sprite.modulate = Color(1, 0.3, 0.3) if fmod(flash_timer, 0.1) > 0.05 else base_modulate
		if flash_timer <= 0:
			sprite.modulate = base_modulate


func _fire_ring():
	for i in range(6):
		var angle = (TAU / 6.0) * i
		var dir = Vector2(cos(angle), sin(angle))
		enemy_shoot.emit(bullet_scene, position + dir * 14, dir, damage)


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
