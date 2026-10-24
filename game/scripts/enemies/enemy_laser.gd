## Enemy Laser: Descends, stops, tracks player, fires a beam for 1.5s.
## Appears from wave 10+.
extends CharacterBody2D


signal enemy_killed(points: int, pos: Vector2)
signal enemy_shoot(bullet_scene: PackedScene, pos: Vector2, dir: Vector2, dmg: int)

@export var max_hp: int = 6
@export var speed: float = 30.0
@export var points: int = 180
@export var damage: int = 1

var current_hp: int = 6
var is_alive: bool = true
var flash_timer: float = 0.0
var base_modulate: Color = Color.WHITE
var stopped: bool = false
var player_ref: CharacterBody2D = null

# Laser state
var laser_state: String = "cooldown"  # "cooldown", "charging", "firing"
var laser_cooldown: float = 2.5
var laser_charge_time: float = 0.8
var laser_fire_time: float = 1.5
var state_timer: float = 2.0
var laser_target_angle: float = PI / 2.0  # default: aim down
var laser_line: Line2D = null
var damage_tick: float = 0.0

# Telegraph system
var is_telegraphing: bool = false
var telegraph_elapsed: float = 0.0

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

	# Create Line2D for laser beam
	laser_line = Line2D.new()
	laser_line.width = 3.0
	laser_line.default_color = Color(1.0, 0.2, 0.1, 0.8)
	laser_line.visible = false
	add_child(laser_line)


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

	# Descend to stop position
	if !stopped and position.y >= 70:
		stopped = true
	elif !stopped:
		velocity = Vector2(0, speed)
		move_and_slide()

	if position.y > VIEWPORT_H + 50:
		enemy_killed.emit(0, position)
		queue_free()

	# Laser state machine
	if stopped:
		state_timer -= delta
		match laser_state:
			"cooldown":
				laser_line.visible = false
				if is_telegraphing:
					is_telegraphing = false
					queue_redraw()
				if state_timer <= 0:
					laser_state = "charging"
					state_timer = laser_charge_time
					is_telegraphing = true
					telegraph_elapsed = 0.0
					_track_player()
			"charging":
				# Track player during telegraph phase
				_track_player()
				telegraph_elapsed += delta
				is_telegraphing = true
				queue_redraw()
				# Hide the Line2D during telegraph (we use _draw() instead)
				laser_line.visible = false
				if state_timer <= 0:
					laser_state = "firing"
					state_timer = laser_fire_time
					is_telegraphing = false
					queue_redraw()
			"firing":
				laser_line.visible = true
				laser_line.width = 4.0
				laser_line.default_color = Color(1.0, 0.15, 0.1, 0.9)
				_update_laser_visual()
				_damage_player_if_hit(delta)
				if state_timer <= 0:
					laser_state = "cooldown"
					state_timer = laser_cooldown

	# Flash
	if flash_timer > 0:
		flash_timer -= delta
		sprite.modulate = Color(1, 0.3, 0.3) if fmod(flash_timer, 0.1) > 0.05 else base_modulate
		if flash_timer <= 0:
			sprite.modulate = base_modulate


func _track_player():
	if player_ref and is_instance_valid(player_ref) and player_ref.is_alive:
		laser_target_angle = (player_ref.global_position - global_position).angle()
	else:
		laser_target_angle = PI / 2.0


func _update_laser_visual():
	var dir = Vector2(cos(laser_target_angle), sin(laser_target_angle))
	laser_line.clear_points()
	laser_line.add_point(Vector2.ZERO)
	laser_line.add_point(dir * 500)


func _damage_player_if_hit(delta: float):
	if !player_ref or !is_instance_valid(player_ref) or !player_ref.is_alive:
		return
	# Rate-limit damage ticks
	damage_tick -= delta
	if damage_tick > 0:
		return
	# Simple distance check from laser line to player
	var dir = Vector2(cos(laser_target_angle), sin(laser_target_angle))
	var to_player = player_ref.global_position - global_position
	# Project player position onto laser direction
	var dot = to_player.dot(dir)
	if dot < 0:
		return  # Player behind laser
	var closest = dir * dot
	var dist = (to_player - closest).length()
	if dist < 10.0:  # Hit radius
		damage_tick = 0.5  # Max 2 hits per second
		enemy_shoot.emit(preload("res://scenes/projectiles/bullet_enemy.tscn"),
			global_position + dir * 20.0, dir, damage)


func _draw():
	if !is_telegraphing:
		return
	# Draw dashed line from laser enemy toward player with pulsing alpha
	var dir = Vector2(cos(laser_target_angle), sin(laser_target_angle))
	var total_length: float = 500.0
	var dash_length: float = 8.0
	var gap_length: float = 6.0
	# Pulsing alpha via sin wave
	var alpha = 0.25 + 0.15 * sin(telegraph_elapsed * 8.0)
	var line_color = Color(1.0, 0.15, 0.1, alpha)
	var pos_along: float = 0.0
	var drawing_dash: bool = true
	while pos_along < total_length:
		if drawing_dash:
			var start = dir * pos_along
			var end_len = minf(pos_along + dash_length, total_length)
			var end = dir * end_len
			draw_line(start, end, line_color, 1.0)
			pos_along = end_len
		else:
			pos_along += gap_length
		drawing_dash = !drawing_dash


func take_damage(dmg: int):
	if !is_alive:
		return
	current_hp -= dmg
	flash_timer = 0.2
	if current_hp <= 0:
		die()


func die():
	is_alive = false
	if laser_line:
		laser_line.visible = false
	enemy_killed.emit(points, position)
	queue_free()
