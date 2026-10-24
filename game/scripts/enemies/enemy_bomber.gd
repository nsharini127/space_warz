## Enemy Bomber: Crosses horizontally, drops mines that explode into bullet rings.
## Appears from wave 8+.
extends CharacterBody2D


signal enemy_killed(points: int, pos: Vector2)
signal enemy_shoot(bullet_scene: PackedScene, pos: Vector2, dir: Vector2, dmg: int)

@export var max_hp: int = 5
@export var speed: float = 60.0
@export var points: int = 150
@export var damage: int = 1

var current_hp: int = 5
var is_alive: bool = true
var flash_timer: float = 0.0
var base_modulate: Color = Color.WHITE
var move_dir: int = 1
var mine_timer: float = 1.5
var mine_interval: float = 2.0

# Telegraph system
var is_telegraphing: bool = false
var telegraph_timer: float = 0.0
const TELEGRAPH_DURATION: float = 0.3

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
	# Determine direction: spawn on left or right
	if position.x < VIEWPORT_W / 2.0:
		move_dir = 1
	else:
		move_dir = -1
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

	# Telegraph phase: slow down and blink before dropping mine
	if is_telegraphing:
		telegraph_timer -= delta
		# White blink effect
		if fmod(telegraph_timer, 0.1) > 0.05:
			sprite.modulate = Color(2, 2, 2)
		else:
			sprite.modulate = base_modulate
		queue_redraw()
		# Slow movement during telegraph
		position.x += move_dir * speed * 0.3 * delta
		position.y += 15.0 * 0.3 * delta
		if telegraph_timer <= 0:
			is_telegraphing = false
			sprite.modulate = base_modulate
			_drop_mine()
			queue_redraw()
	else:
		# Normal movement
		position.x += move_dir * speed * delta
		position.y += 15.0 * delta

		# Drop mines periodically
		mine_timer -= delta
		if mine_timer <= 0:
			mine_timer = mine_interval
			is_telegraphing = true
			telegraph_timer = TELEGRAPH_DURATION

	# Remove if off screen
	if position.x < -30 or position.x > VIEWPORT_W + 30 or position.y > VIEWPORT_H + 30:
		enemy_killed.emit(0, position)
		queue_free()

	# Flash
	if flash_timer > 0:
		flash_timer -= delta
		sprite.modulate = Color(1, 0.3, 0.3) if fmod(flash_timer, 0.1) > 0.05 else base_modulate
		if flash_timer <= 0:
			sprite.modulate = base_modulate


func _draw():
	if !is_telegraphing:
		return
	# Draw downward arrow indicator showing where mine will drop
	var arrow_color = Color(1.0, 0.4, 0.1, 0.7)
	var start_y: float = 12.0
	var end_y: float = 28.0
	# Vertical line
	draw_line(Vector2(0, start_y), Vector2(0, end_y), arrow_color, 2.0)
	# Arrowhead
	draw_polygon(
		[Vector2(0, end_y + 4), Vector2(-4, end_y), Vector2(4, end_y)],
		[arrow_color, arrow_color, arrow_color]
	)
	# Small circle at drop point for visibility
	draw_circle(Vector2(0, end_y + 8), 3.0, Color(1.0, 0.3, 0.0, 0.4))


func _drop_mine():
	# Spawn a mine at current position
	var mine_script = preload("res://scripts/enemies/mine.gd")
	var mine = Area2D.new()
	mine.set_script(mine_script)
	mine.global_position = global_position + Vector2(0, 10)
	mine.damage = damage
	get_parent().add_child(mine)


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
