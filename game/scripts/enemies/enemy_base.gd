extends CharacterBody2D


signal enemy_killed(points: int, pos: Vector2)
signal enemy_shoot(bullet_scene: PackedScene, pos: Vector2, dir: Vector2, dmg: int)

@export var max_hp: int = 3
@export var speed: float = 40.0
@export var points: int = 100
@export var damage: int = 1

var current_hp: int = 3
var is_alive: bool = true
var flash_timer: float = 0.0
var is_flashing: bool = false
var base_modulate: Color = Color.WHITE

const VIEWPORT_W = 320
const VIEWPORT_H = 480

@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox_area: Area2D = $HitboxArea


func _ready():
	# Apply difficulty scaling
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


func _physics_process(delta: float):
	if !is_alive:
		return

	move_enemy(delta)

	# Remove if off screen (below)
	if position.y > VIEWPORT_H + 30:
		enemy_killed.emit(0, position)
		queue_free()

	# Hit flash effect (overbright white then restore)
	if is_flashing:
		flash_timer -= delta
		if flash_timer <= 0:
			is_flashing = false
			if sprite:
				sprite.modulate = base_modulate

	# Rotate sprite to face movement direction (sprite faces down by default)
	if sprite and velocity.length() > 0:
		sprite.rotation = velocity.angle() + PI / 2.0


func move_enemy(delta: float):
	velocity = Vector2(0, speed)
	move_and_slide()


func take_damage(dmg: int):
	if !is_alive:
		return

	current_hp -= dmg

	# Overbright white flash on hit
	is_flashing = true
	flash_timer = 0.05
	if sprite:
		sprite.modulate = Color(3, 3, 3)

	if current_hp <= 0:
		die()


func die():
	is_alive = false
	enemy_killed.emit(points, position)
	queue_free()
