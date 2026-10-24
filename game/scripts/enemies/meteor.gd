## Meteor: Destructible obstacle that falls straight down, rotates, no attack.
## Spawned in waves before boss waves. Uses procedural drawing for a rock look.
extends CharacterBody2D


signal enemy_killed(points: int, pos: Vector2)
signal enemy_shoot(bullet_scene: PackedScene, pos: Vector2, dir: Vector2, dmg: int)

@export var max_hp: int = 3
@export var speed: float = 80.0
@export var points: int = 50

var current_hp: int = 3
var is_alive: bool = true
var flash_timer: float = 0.0
var rotation_angle: float = 0.0
var rotation_speed: float = 2.0
var meteor_radius: float = 10.0
var _vertices: PackedVector2Array = PackedVector2Array()

const VIEWPORT_W = 320
const VIEWPORT_H = 480

@onready var hitbox_area: Area2D = $HitboxArea


func _ready():
	# Randomize stats
	max_hp = randi_range(2, 5)
	speed = randf_range(60, 120)
	rotation_speed = randf_range(1.5, 4.0) * (1.0 if randf() > 0.5 else -1.0)
	meteor_radius = randf_range(8.0, 16.0)

	# Apply difficulty scaling
	var diff := _get_difficulty()
	max_hp = int(max_hp * diff)
	current_hp = max_hp
	is_alive = true

	# Generate irregular rock vertices once
	_generate_rock_shape()

	if hitbox_area:
		hitbox_area.add_to_group("enemy_hitbox")
		hitbox_area.add_to_group("enemy_body")
		# Update collision to match radius
		var col_shape = hitbox_area.get_node_or_null("CollisionShape2D")
		if col_shape and col_shape.shape is CircleShape2D:
			col_shape.shape.radius = meteor_radius


func _get_difficulty() -> float:
	var game_nodes = get_tree().get_nodes_in_group("game")
	if game_nodes.size() > 0 and game_nodes[0].has_method("get_difficulty_multiplier"):
		return game_nodes[0].get_difficulty_multiplier()
	return 1.0


func _generate_rock_shape():
	_vertices.clear()
	var num_points: int = randi_range(7, 10)
	for i in range(num_points):
		var angle = TAU / num_points * i
		var r = meteor_radius * randf_range(0.7, 1.0)
		_vertices.append(Vector2(cos(angle) * r, sin(angle) * r))


func _physics_process(delta: float):
	if !is_alive:
		return

	velocity = Vector2(0, speed)
	move_and_slide()

	rotation_angle += rotation_speed * delta
	queue_redraw()

	if position.y > VIEWPORT_H + 40:
		enemy_killed.emit(0, position)
		queue_free()

	if flash_timer > 0:
		flash_timer -= delta
		if flash_timer <= 0:
			flash_timer = 0.0


func _draw():
	if _vertices.size() < 3:
		return

	# Rotate all vertices
	var rotated = PackedVector2Array()
	for v in _vertices:
		rotated.append(v.rotated(rotation_angle))

	# Rock body - dark brown/gray
	var body_color: Color
	if flash_timer > 0 and fmod(flash_timer, 0.1) > 0.05:
		body_color = Color(1.0, 0.4, 0.3)
	else:
		body_color = Color(0.45, 0.35, 0.28)

	var colors = PackedColorArray()
	for _i in range(rotated.size()):
		colors.append(body_color)
	draw_polygon(rotated, colors)

	# Outline
	for i in range(rotated.size()):
		var next_i = (i + 1) % rotated.size()
		draw_line(rotated[i], rotated[next_i], Color(0.3, 0.22, 0.15), 1.0)

	# Crater details
	var crater_col = Color(0.35, 0.25, 0.18)
	draw_circle(Vector2(meteor_radius * 0.2, -meteor_radius * 0.1).rotated(rotation_angle),
		meteor_radius * 0.2, crater_col)
	draw_circle(Vector2(-meteor_radius * 0.3, meteor_radius * 0.25).rotated(rotation_angle),
		meteor_radius * 0.15, crater_col)


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
