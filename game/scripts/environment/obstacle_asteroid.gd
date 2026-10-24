extends Area2D

var speed: float = 35.0
var hp: int = 3
var max_hp: int = 3
var points: int = 50
var rotation_speed: float = 0.0

const VIEWPORT_W = 320
const VIEWPORT_H = 480

signal asteroid_killed(points: int, pos: Vector2)


func _ready():
	collision_layer = 2  # Enemy layer
	collision_mask = 5   # Player + PlayerBullet
	add_to_group("enemy_hitbox")
	add_to_group("enemy_body")

	speed = randf_range(25, 50)
	rotation_speed = randf_range(-1.5, 1.5)

	# Visual
	var sprite = Sprite2D.new()
	sprite.texture = preload("res://assets/backgrounds/space/asteroid_base.png")
	var scale_f = randf_range(0.4, 0.8)
	sprite.scale = Vector2(scale_f, scale_f)
	add_child(sprite)

	# Collision
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 8.0 * scale_f
	shape.shape = circle
	add_child(shape)

	area_entered.connect(_on_area_entered)


func _process(delta: float):
	position.y += speed * delta
	rotation += rotation_speed * delta

	if position.y > VIEWPORT_H + 40:
		queue_free()


func _on_area_entered(area: Area2D):
	if area.is_in_group("player_bullet"):
		take_damage(1)


func take_damage(dmg: int):
	hp -= dmg
	if hp <= 0:
		asteroid_killed.emit(points, global_position)
		queue_free()
