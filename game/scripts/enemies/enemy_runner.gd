extends CharacterBody2D


signal enemy_killed(points: int, pos: Vector2)
signal enemy_shoot(bullet_scene: PackedScene, pos: Vector2, dir: Vector2, dmg: int)

@export var max_hp: int = 2
@export var speed: float = 80.0
@export var points: int = 150
@export var damage: int = 1
@export var zigzag_amplitude: float = 40.0
@export var zigzag_frequency: float = 3.0

var current_hp: int = 2
var is_alive: bool = true
var flash_timer: float = 0.0
var base_modulate: Color = Color.WHITE
var time_alive: float = 0.0
var start_x: float = 0.0

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
	start_x = position.x
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


func _physics_process(delta: float):
	if !is_alive:
		return

	time_alive += delta
	move_enemy(delta)

	if position.y > VIEWPORT_H + 30:
		enemy_killed.emit(0, position)
		queue_free()

	if flash_timer > 0:
		flash_timer -= delta
		sprite.modulate = Color(1, 0.3, 0.3) if fmod(flash_timer, 0.1) > 0.05 else base_modulate
		if flash_timer <= 0:
			sprite.modulate = base_modulate

	# Tilt sprite toward movement direction (sprite faces down by default)
	if sprite and velocity.length() > 0:
		sprite.rotation = velocity.angle() + PI / 2.0


func move_enemy(delta: float):
	var target_x = start_x + sin(time_alive * zigzag_frequency) * zigzag_amplitude
	var x_vel = (target_x - position.x) * 5.0
	velocity = Vector2(x_vel, speed)
	move_and_slide()


func take_damage(dmg: int):
	if !is_alive:
		return
	current_hp -= dmg
	flash_timer = 0.2
	if current_hp <= 0:
		die()


func die():
	is_alive = false
	# Drop ring of bullets on death
	for i in range(8):
		var angle = (TAU / 8.0) * i
		var dir = Vector2(cos(angle), sin(angle))
		enemy_shoot.emit(bullet_scene, position, dir, damage)
	enemy_killed.emit(points, position)
	queue_free()
