extends CharacterBody2D


signal enemy_killed(points: int, pos: Vector2)
signal enemy_shoot(bullet_scene: PackedScene, pos: Vector2, dir: Vector2, dmg: int)
signal boss_died(pos: Vector2)

@export var max_hp: int = 30
@export var speed: float = 20.0
@export var points: int = 1000
@export var damage: int = 2
@export var shoot_interval: float = 2.0
@export var stop_y: float = 80.0

var current_hp: int = 30
var is_alive: bool = true
var flash_timer: float = 0.0
var base_modulate: Color = Color.WHITE
var shoot_timer: float = 2.0
var stopped: bool = false
var phase: int = 1
var move_dir: int = 1
var pattern_angle: float = 0.0
var time_alive: float = 0.0
var player_ref: CharacterBody2D = null
var phase_transition_done: Array = [false, false, false]

var bullet_scene: PackedScene = preload("res://scenes/projectiles/bullet_enemy.tscn")

const VIEWPORT_W = 320
const VIEWPORT_H = 480

@onready var sprite: Sprite2D = $Sprite2D
@onready var glow_sprite: Sprite2D = $GlowSprite
@onready var hitbox_area: Area2D = $HitboxArea


func _ready():
	current_hp = max_hp
	is_alive = true
	stop_y = 80.0
	if sprite:
		base_modulate = sprite.modulate
	if hitbox_area:
		hitbox_area.add_to_group("enemy_hitbox")
		hitbox_area.add_to_group("enemy_body")


func set_player(p: CharacterBody2D):
	player_ref = p


func _physics_process(delta: float):
	if !is_alive:
		return

	time_alive += delta
	move_enemy(delta)

	if position.y > VIEWPORT_H + 50:
		enemy_killed.emit(0, position)
		queue_free()

	# Shooting
	if stopped:
		shoot_timer -= delta
		if shoot_timer <= 0:
			shoot_timer = shoot_interval
			fire_pattern()

	# Flash effect
	if flash_timer > 0:
		flash_timer -= delta
		sprite.modulate = Color(1, 0.3, 0.3) if fmod(flash_timer, 0.1) > 0.05 else base_modulate
		if flash_timer <= 0:
			sprite.modulate = base_modulate

	# Subtle pulsing effect for boss (preserve scene scale)
	if sprite:
		var base_scale = 0.47
		var pulse = base_scale * (1.0 + sin(time_alive * 3.0) * 0.05)
		sprite.scale = Vector2(pulse, pulse)

	# Glow aura pulsing (larger, slower)
	if glow_sprite:
		var glow_base = 0.65
		var glow_pulse = glow_base * (1.0 + sin(time_alive * 2.0) * 0.1)
		glow_sprite.scale = Vector2(glow_pulse, glow_pulse)
		glow_sprite.modulate.a = 0.15 + sin(time_alive * 1.5) * 0.08

	# Phase transitions
	var hp_ratio = float(current_hp) / float(max_hp)
	if hp_ratio <= 0.3 and phase < 3:
		if !phase_transition_done[2]:
			phase_transition_done[2] = true
			_enter_phase_3()
	elif hp_ratio <= 0.6 and phase < 2:
		if !phase_transition_done[1]:
			phase_transition_done[1] = true
			_enter_phase_2()


func _enter_phase_2():
	phase = 2
	shoot_interval = 1.3
	speed = 28.0
	# Transition burst (reduced from 24 to 12)
	for i in range(12):
		var angle = (TAU / 12.0) * i
		var dir = Vector2(cos(angle), sin(angle))
		enemy_shoot.emit(bullet_scene, position + dir * 16, dir, damage)


func _enter_phase_3():
	phase = 3
	shoot_interval = 1.0
	speed = 35.0
	# Transition burst (reduced from 32 to 16)
	for i in range(16):
		var angle = (TAU / 16.0) * i
		var dir = Vector2(cos(angle), sin(angle))
		enemy_shoot.emit(bullet_scene, position + dir * 16, dir, damage)


func move_enemy(delta: float):
	if !stopped and position.y >= stop_y:
		stopped = true
		velocity = Vector2.ZERO
	elif !stopped:
		velocity = Vector2(0, speed)
		move_and_slide()
		return

	if stopped:
		match phase:
			1:
				# Gentle sinusoidal horizontal
				position.x += move_dir * speed * delta
				position.x += sin(time_alive * 1.5) * 0.5
			2:
				# Faster horizontal
				position.x += move_dir * speed * 1.3 * delta
			3:
				# Erratic: sinusoidal + occasional dash
				position.x += move_dir * speed * 1.2 * delta
				position.x += sin(time_alive * 3.0) * 1.0
				# Occasional vertical bob
				position.y = stop_y + sin(time_alive * 2.0) * 15.0

		if position.x > VIEWPORT_W - 30:
			move_dir = -1
		elif position.x < 30:
			move_dir = 1


func fire_pattern():
	var player_pos = player_ref.global_position if player_ref and is_instance_valid(player_ref) and player_ref.is_alive else Vector2(160, 384)

	match phase:
		1:
			_fire_phase_1(player_pos)
		2:
			_fire_phase_2(player_pos)
		3:
			_fire_phase_3(player_pos)


func _fire_phase_1(player_pos: Vector2):
	# Radial burst: 8 bullets with slow spin (reduced from 16)
	pattern_angle += deg_to_rad(5)
	for i in range(8):
		var angle = pattern_angle + (TAU / 8.0) * i
		var dir = Vector2(cos(angle), sin(angle))
		enemy_shoot.emit(bullet_scene, position + dir * 16, dir, damage)

	# Aimed fan 3-way every other shot
	if int(time_alive / shoot_interval) % 2 == 0:
		var aim_angle = (player_pos - position).angle()
		for i in range(3):
			var offset = (i - 1) * deg_to_rad(15)
			var dir = Vector2(cos(aim_angle + offset), sin(aim_angle + offset))
			enemy_shoot.emit(bullet_scene, position, dir, damage)


func _fire_phase_2(player_pos: Vector2):
	# Double spiral: 2 arms x 2 bullets each (reduced from 3)
	pattern_angle += deg_to_rad(12)
	for arm in range(2):
		var base = pattern_angle + arm * PI
		for i in range(2):
			var angle = base + i * deg_to_rad(8)
			var dir = Vector2(cos(angle), sin(angle))
			enemy_shoot.emit(bullet_scene, position + dir * 12, dir, damage)

	# Aimed fan: 3-way (reduced from 5-way)
	if int(time_alive * 2) % 3 == 0:
		var aim_angle = (player_pos - position).angle()
		for i in range(3):
			var offset = (i - 1) * deg_to_rad(12)
			var dir = Vector2(cos(aim_angle + offset), sin(aim_angle + offset))
			enemy_shoot.emit(bullet_scene, position, dir, damage)


func _fire_phase_3(player_pos: Vector2):
	# Triple spiral: 3 arms x 2 bullets (reduced from 4)
	pattern_angle += deg_to_rad(15)
	for arm in range(3):
		var base = pattern_angle + arm * (TAU / 3.0)
		for i in range(2):
			var angle = base + i * deg_to_rad(6)
			var dir = Vector2(cos(angle), sin(angle))
			enemy_shoot.emit(bullet_scene, position + dir * 10, dir, damage)

	# Aimed curtain: 5-way (reduced from 7-way)
	var aim_angle = (player_pos - position).angle()
	for i in range(5):
		var offset = (i - 2) * deg_to_rad(8)
		var dir = Vector2(cos(aim_angle + offset), sin(aim_angle + offset))
		enemy_shoot.emit(bullet_scene, position, dir, damage)


func take_damage(dmg: int):
	if !is_alive:
		return
	current_hp -= dmg
	flash_timer = 0.2
	if current_hp <= 0:
		die()


func die():
	is_alive = false
	boss_died.emit(position)
	enemy_killed.emit(points, position)
	queue_free()
