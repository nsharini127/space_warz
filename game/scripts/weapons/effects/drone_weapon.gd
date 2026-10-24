extends Node2D


signal drone_shoot(bullet_scene: PackedScene, pos: Vector2, dir: Vector2, dmg: int, pierce: int)

var player: CharacterBody2D = null
var drone_index: int = 0
var drone_total: int = 1
var damage: int = 1
var fire_interval: float = 0.3
var fire_timer: float = 0.0
var orbit_angle: float = 0.0
var orbit_radius: float = 22.0
var orbit_speed: float = 2.0

var bullet_scene: PackedScene = preload("res://scenes/projectiles/bullet_player.tscn")


func setup(p_player: CharacterBody2D, p_index: int, p_total: int, p_dmg: int, p_interval: float):
	player = p_player
	drone_index = p_index
	drone_total = p_total
	damage = p_dmg
	fire_interval = p_interval
	orbit_angle = (TAU / max(p_total, 1)) * p_index
	z_index = 5


func update_config(p_index: int, p_total: int, p_dmg: int, p_interval: float):
	drone_index = p_index
	drone_total = p_total
	damage = p_dmg
	fire_interval = p_interval


func _process(delta: float):
	if !player or !player.is_alive:
		visible = false
		return

	visible = true
	orbit_angle += orbit_speed * delta
	var offset_angle = orbit_angle + (TAU / max(drone_total, 1)) * drone_index
	var offset = Vector2(cos(offset_angle), sin(offset_angle)) * orbit_radius
	global_position = player.global_position + offset

	fire_timer -= delta
	if fire_timer <= 0:
		fire_timer = fire_interval
		_shoot()

	queue_redraw()


func _shoot():
	if !player or !player.is_alive:
		return
	var p = player.pierce if "pierce" in player else 0
	drone_shoot.emit(bullet_scene, global_position + Vector2(0, -6), Vector2.UP, damage, p)


func _draw():
	# Draw drone body
	var body_col = Color(0.5, 0.7, 1.0, 0.9)
	var glow_col = Color(0.3, 0.6, 1.0, 0.4)
	draw_circle(Vector2.ZERO, 5, glow_col)
	var points = PackedVector2Array([Vector2(0, -4), Vector2(3, 0), Vector2(0, 3), Vector2(-3, 0)])
	var colors = PackedColorArray([body_col, body_col, body_col, body_col])
	draw_polygon(points, colors)
	draw_circle(Vector2(0, -1), 1.5, Color(0.6, 0.9, 1.0, 1.0))
	draw_rect(Rect2(-1, 2, 2, 2), Color(0.2, 0.5, 1.0, 0.6))
