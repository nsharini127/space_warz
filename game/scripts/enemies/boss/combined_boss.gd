## Entity: Combined form of the mecha boss.
## Created when surviving parts merge. Attacks are determined by which parts survived.
## Moves faster than the formation and has a larger visual scale.
extends CharacterBody2D


signal enemy_shoot(bullet_scene: PackedScene, pos: Vector2, dir: Vector2, dmg: int)
signal combined_boss_died(pos: Vector2)

var max_hp: int = 20
var current_hp: int = 20
var is_alive: bool = true
var damage: int = 2
var points: int = 0

## Which original part types survived into the combination.
var surviving_parts: Array[int] = []

## Player reference for aimed attacks.
var player_ref: CharacterBody2D = null

## Internal state.
var _time_alive: float = 0.0
var _shoot_timer: float = 1.5
var _flash_timer: float = 0.0
var _move_dir: int = 1
var _pattern_angle: float = 0.0
var _base_modulate: Color = Color.WHITE

var bullet_scene: PackedScene = preload("res://scenes/projectiles/bullet_enemy.tscn")

const VIEWPORT_W: float = 320.0
const SHOOT_INTERVAL: float = 1.5
const SPEED: float = 45.0
const STOP_Y: float = 90.0

var sprite: Sprite2D = null
var hitbox: Area2D = null


## Initializes the combined boss with surviving parts info and total HP.
func setup(surviving: Array[int], total_hp: int, player: CharacterBody2D) -> void:
	surviving_parts = surviving
	max_hp = max(total_hp, 10)
	current_hp = max_hp
	player_ref = player

	# Compute intensity based on surviving parts
	damage = 1 + surviving.size()


func _ready() -> void:
	_build_visuals()
	_build_hitbox()


## Creates the visual representation (boss sprite, scaled up with glow).
func _build_visuals() -> void:
	sprite = Sprite2D.new()
	sprite.texture = load("res://assets/sprites/enemies/space/enemy_boss.png")
	sprite.scale = Vector2(0.55, 0.55)
	sprite.modulate = Color(1.0, 0.6, 0.6, 1.0)
	add_child(sprite)
	_base_modulate = sprite.modulate

	# Glow layer
	var glow := Sprite2D.new()
	glow.texture = sprite.texture
	glow.scale = Vector2(0.85, 0.85)
	glow.modulate = Color(1.0, 0.3, 0.3, 0.2)
	glow.z_index = -1
	add_child(glow)


## Creates the collision hitbox.
func _build_hitbox() -> void:
	hitbox = Area2D.new()
	hitbox.collision_layer = 2
	hitbox.collision_mask = 4
	hitbox.add_to_group("enemy_hitbox")
	hitbox.add_to_group("enemy_body")

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(50, 42)
	shape.shape = rect
	hitbox.add_child(shape)
	add_child(hitbox)


func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	_time_alive += delta
	_move(delta)
	_shoot(delta)
	_update_flash(delta)
	_pulse_visual()


## Moves the combined boss with erratic horizontal + vertical bob.
func _move(delta: float) -> void:
	position.x += _move_dir * SPEED * delta
	position.x += sin(_time_alive * 2.5) * 0.8
	position.y = STOP_Y + sin(_time_alive * 1.5) * 10.0

	if position.x > VIEWPORT_W - 35:
		_move_dir = -1
	elif position.x < 35:
		_move_dir = 1


## Handles shooting based on which parts survived.
func _shoot(delta: float) -> void:
	_shoot_timer -= delta
	if _shoot_timer > 0:
		return
	_shoot_timer = SHOOT_INTERVAL

	var player_pos: Vector2 = _get_player_position()
	var bullets: Array[Dictionary] = []

	_pattern_angle += deg_to_rad(10)

	# Each surviving part type adds its attack pattern
	for pt in surviving_parts:
		match pt:
			BossPart.PartType.HEAD:
				bullets.append_array(
					BossAttackPatterns.aimed_fan(
						global_position, player_pos, 3, 12.0, damage
					)
				)
			BossPart.PartType.ARM_L, BossPart.PartType.ARM_R:
				bullets.append_array(
					BossAttackPatterns.lateral_spray(
						global_position,
						Vector2(0, 1),
						3, 20.0, damage
					)
				)
			BossPart.PartType.TORSO:
				bullets.append_array(
					BossAttackPatterns.radial_burst(
						global_position, 6, damage, _pattern_angle
					)
				)
			# Legs don't add attacks

	# If no surviving attack parts, use a fallback combined pattern
	if bullets.is_empty():
		bullets = BossAttackPatterns.combined_pattern(
			global_position, player_pos, 0.5, damage, _pattern_angle
		)

	for b in bullets:
		enemy_shoot.emit(bullet_scene, b.position, b.direction, b.damage)


## Updates the damage flash effect.
func _update_flash(delta: float) -> void:
	if _flash_timer > 0:
		_flash_timer -= delta
		if sprite:
			sprite.modulate = Color(1, 0.3, 0.3) if fmod(_flash_timer, 0.1) > 0.05 else _base_modulate
			if _flash_timer <= 0:
				sprite.modulate = _base_modulate


## Pulsing visual effect.
func _pulse_visual() -> void:
	if sprite:
		var pulse: float = 0.55 * (1.0 + sin(_time_alive * 3.0) * 0.06)
		sprite.scale = Vector2(pulse, pulse)


## Applies damage. Emits combined_boss_died when HP reaches zero.
func take_damage(dmg: int) -> void:
	if not is_alive:
		return

	current_hp -= dmg
	_flash_timer = 0.2

	if current_hp <= 0:
		current_hp = 0
		_die()


func _die() -> void:
	is_alive = false
	combined_boss_died.emit(global_position)
	queue_free()


## Returns the player's position or a default fallback.
func _get_player_position() -> Vector2:
	if player_ref and is_instance_valid(player_ref) and player_ref.is_alive:
		return player_ref.global_position
	return Vector2(VIEWPORT_W / 2.0, 384)
