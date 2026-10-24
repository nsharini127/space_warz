extends Node2D


signal option_shoot(bullet_scene: PackedScene, pos: Vector2, dir: Vector2, dmg: int, pierce: int)

var player: CharacterBody2D
var side: int = 1  # 1 = right, -1 = left
var target_offset: Vector2 = Vector2.ZERO
var current_offset: Vector2 = Vector2.ZERO

var bullet_scene: PackedScene = preload("res://scenes/projectiles/bullet_player.tscn")
var fire_timer: float = 0.0
var fire_rate: float = 0.3


func _ready():
	z_index = 5


func setup(p: CharacterBody2D, s: int):
	player = p
	side = s
	current_offset = get_formation_offset(false)
	target_offset = current_offset


func get_formation_offset(focused: bool) -> Vector2:
	if focused:
		return Vector2(side * 6, 10)
	else:
		return Vector2(side * 18, -4)


func _process(delta: float):
	if !player or !player.is_alive:
		visible = false
		return

	visible = true
	var focused = player.is_focused
	target_offset = get_formation_offset(focused)
	current_offset = current_offset.lerp(target_offset, 8.0 * delta)
	global_position = player.global_position + current_offset

	fire_timer -= delta
	if fire_timer <= 0:
		fire_timer = fire_rate
		shoot(focused)

	# Gentle bob animation
	rotation = sin(Engine.get_frames_drawn() * 0.05 + side) * 0.15


func shoot(focused: bool):
	if !player.is_alive:
		return

	var dmg = player.damage
	var pierce = player.pierce

	if focused:
		option_shoot.emit(bullet_scene, global_position + Vector2(0, -8), Vector2.UP, dmg, pierce)
	else:
		var angle = side * deg_to_rad(15)
		var dir = Vector2(sin(angle), -cos(angle))
		option_shoot.emit(bullet_scene, global_position + Vector2(0, -8), dir, dmg, pierce)


func _draw():
	# Draw a small drone/satellite shape
	var body_col = Color(0.5, 0.7, 1.0, 0.9)
	var glow_col = Color(0.3, 0.6, 1.0, 0.4)
	# Glow
	draw_circle(Vector2.ZERO, 5, glow_col)
	# Body (diamond shape)
	var points = [Vector2(0, -4), Vector2(3, 0), Vector2(0, 3), Vector2(-3, 0)]
	draw_polygon(points, [body_col, body_col, body_col, body_col])
	# Core light
	draw_circle(Vector2(0, -1), 1.5, Color(0.6, 0.9, 1.0, 1.0))
	# Thruster
	draw_rect(Rect2(-1, 2, 2, 2), Color(0.2, 0.5, 1.0, 0.6))
