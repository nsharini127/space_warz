## Entity: Individual part of the mecha boss.
## Each part has its own HP, attack pattern, and visual representation.
## Uses a child HitboxArea (Area2D) so bullets can detect it via
## area.get_parent().take_damage() — matching the standard enemy pattern.
extends Node2D

class_name BossPart

## Emitted when this part's HP reaches zero.
signal part_destroyed(part_type: int, pos: Vector2)

## Emitted when this part fires bullets.
signal part_shoot(bullet_scene: PackedScene, pos: Vector2, dir: Vector2, dmg: int)

## Part type identifiers.
enum PartType { HEAD, ARM_L, ARM_R, TORSO, LEG_L, LEG_R }

## Maps PartType to configuration: { hp, damage, sprite, scale, has_attack, collision_size }
const PART_CONFIGS: Dictionary = {
	PartType.HEAD: {
		"hp": 8,
		"damage": 1,
		"sprite": "res://assets/sprites/enemies/space/enemy_base.png",
		"scale": Vector2(0.25, 0.25),
		"has_attack": true,
		"collision_size": Vector2(20, 18),
	},
	PartType.ARM_L: {
		"hp": 10,
		"damage": 1,
		"sprite": "res://assets/sprites/enemies/space/enemy_shooter.png",
		"scale": Vector2(0.30, 0.30),
		"has_attack": true,
		"collision_size": Vector2(22, 20),
	},
	PartType.ARM_R: {
		"hp": 10,
		"damage": 1,
		"sprite": "res://assets/sprites/enemies/space/enemy_shooter.png",
		"scale": Vector2(0.30, 0.30),
		"has_attack": true,
		"collision_size": Vector2(22, 20),
	},
	PartType.TORSO: {
		"hp": 15,
		"damage": 2,
		"sprite": "res://assets/sprites/enemies/space/enemy_boss.png",
		"scale": Vector2(0.40, 0.40),
		"has_attack": true,
		"collision_size": Vector2(36, 30),
	},
	PartType.LEG_L: {
		"hp": 6,
		"damage": 0,
		"sprite": "res://assets/sprites/enemies/space/enemy_runner.png",
		"scale": Vector2(0.25, 0.25),
		"has_attack": false,
		"collision_size": Vector2(18, 16),
	},
	PartType.LEG_R: {
		"hp": 6,
		"damage": 0,
		"sprite": "res://assets/sprites/enemies/space/enemy_runner.png",
		"scale": Vector2(0.25, 0.25),
		"has_attack": false,
		"collision_size": Vector2(18, 16),
	},
}

## The type of this part (set via setup()).
var part_type: int = PartType.HEAD
var max_hp: int = 8
var current_hp: int = 8
var damage: int = 1
var is_alive: bool = true
var has_attack: bool = true

## Reference to the player for aimed attacks.
var player_ref: CharacterBody2D = null

## Internal state.
var _flash_timer: float = 0.0
var _base_modulate: Color = Color.WHITE
var _time_alive: float = 0.0

var bullet_scene: PackedScene = preload("res://scenes/projectiles/bullet_enemy.tscn")

@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox_area: Area2D = $HitboxArea
@onready var collision_shape: CollisionShape2D = $HitboxArea/CollisionShape2D


## Initializes this part with a specific type and loads the corresponding config.
func setup(type: int, player: CharacterBody2D = null) -> void:
	part_type = type
	player_ref = player

	var config: Dictionary = PART_CONFIGS[type]
	max_hp = config.hp
	current_hp = max_hp
	damage = config.damage
	has_attack = config.has_attack

	# Mirror ARM_R and LEG_R sprites horizontally
	if type == PartType.ARM_R or type == PartType.LEG_R:
		if sprite:
			sprite.flip_h = true


func _ready() -> void:
	# The HitboxArea is the child Area2D that bullets collide with.
	# Bullets do area.get_parent().take_damage() — parent is this Node2D.
	if hitbox_area:
		hitbox_area.add_to_group("enemy_hitbox")
		hitbox_area.add_to_group("enemy_body")

	if sprite:
		_base_modulate = sprite.modulate


func _process(delta: float) -> void:
	if not is_alive:
		return

	_time_alive += delta

	# Flash effect on damage
	if _flash_timer > 0:
		_flash_timer -= delta
		if sprite:
			sprite.modulate = Color(1, 0.3, 0.3) if fmod(_flash_timer, 0.1) > 0.05 else _base_modulate
			if _flash_timer <= 0:
				sprite.modulate = _base_modulate


## Called by the controller when this part should fire.
func fire(player_pos: Vector2) -> void:
	if not is_alive or not has_attack:
		return

	var bullets: Array[Dictionary] = _get_attack_bullets(player_pos)
	for b in bullets:
		part_shoot.emit(bullet_scene, b.position, b.direction, b.damage)


## Returns bullet data for this part's attack pattern.
func _get_attack_bullets(player_pos: Vector2) -> Array[Dictionary]:
	match part_type:
		PartType.HEAD:
			return BossAttackPatterns.aimed_fan(
				global_position, player_pos, 2, 10.0, damage
			)
		PartType.ARM_L:
			return BossAttackPatterns.lateral_spray(
				global_position, Vector2(0.5, 1).normalized(), 3, 15.0, damage
			)
		PartType.ARM_R:
			return BossAttackPatterns.lateral_spray(
				global_position, Vector2(-0.5, 1).normalized(), 3, 15.0, damage
			)
		PartType.TORSO:
			return BossAttackPatterns.radial_burst(
				global_position, 6, damage, _time_alive * 0.5
			)
		_:
			return []


## Applies damage to this part. Called by bullets via area.get_parent().take_damage().
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
	part_destroyed.emit(part_type, global_position)
	queue_free()


## Returns the string name of a PartType enum value.
static func part_type_name(type: int) -> String:
	match type:
		PartType.HEAD: return "HEAD"
		PartType.ARM_L: return "ARM_L"
		PartType.ARM_R: return "ARM_R"
		PartType.TORSO: return "TORSO"
		PartType.LEG_L: return "LEG_L"
		PartType.LEG_R: return "LEG_R"
		_: return "UNKNOWN"
