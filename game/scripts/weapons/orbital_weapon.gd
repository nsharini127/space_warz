extends Node2D

var player: CharacterBody2D = null
var orb_count: int = 2
var damage: int = 1
var orbit_radius: float = 28.0
var evolved: bool = false
var angle: float = 0.0
var rotation_speed: float = 3.0

var orb_areas: Array = []
var hit_cooldowns: Dictionary = {}  # enemy_id -> timer


func setup(p_player: CharacterBody2D, p_count: int, p_dmg: int, p_radius: float, p_evolved: bool):
	player = p_player
	orb_count = p_count
	damage = p_dmg
	orbit_radius = p_radius
	evolved = p_evolved
	z_index = 5
	_rebuild_orbs()


func update_config(p_count: int, p_dmg: int, p_evolved: bool):
	if p_count != orb_count or p_evolved != evolved:
		orb_count = p_count
		damage = p_dmg
		evolved = p_evolved
		_rebuild_orbs()
	else:
		damage = p_dmg


func _rebuild_orbs():
	for area in orb_areas:
		if is_instance_valid(area):
			area.queue_free()
	orb_areas.clear()

	for i in range(orb_count):
		var area = Area2D.new()
		area.collision_layer = 4  # PlayerBullet
		area.collision_mask = 2   # Enemy
		var shape = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		circle.radius = 5.0 if !evolved else 7.0
		shape.shape = circle
		area.add_child(shape)
		area.add_to_group("player_bullet")
		area.area_entered.connect(_on_orb_hit.bind(area))
		add_child(area)
		orb_areas.append(area)


func _process(delta: float):
	if !player or !player.is_alive:
		visible = false
		return

	visible = true
	global_position = player.global_position
	angle += rotation_speed * delta * (1.5 if evolved else 1.0)

	# Position orbs
	for i in range(orb_areas.size()):
		var orb_angle = angle + (TAU / orb_areas.size()) * i
		var offset = Vector2(cos(orb_angle), sin(orb_angle)) * orbit_radius
		orb_areas[i].position = offset

	# Update cooldowns
	var to_remove: Array = []
	for id in hit_cooldowns:
		hit_cooldowns[id] -= delta
		if hit_cooldowns[id] <= 0:
			to_remove.append(id)
	for id in to_remove:
		hit_cooldowns.erase(id)

	queue_redraw()


func _on_orb_hit(area: Area2D, _orb: Area2D):
	if area.is_in_group("enemy_hitbox"):
		var enemy = area.get_parent()
		var eid = enemy.get_instance_id()
		if hit_cooldowns.has(eid):
			return
		hit_cooldowns[eid] = 0.3
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage)


func _draw():
	for i in range(orb_areas.size()):
		if i < orb_areas.size() and is_instance_valid(orb_areas[i]):
			var pos = orb_areas[i].position
			var glow_col = Color(0.7, 0.3, 1.0, 0.3) if !evolved else Color(0.9, 0.3, 1.0, 0.5)
			var core_col = Color(0.8, 0.4, 1.0, 0.9) if !evolved else Color(1.0, 0.5, 1.0, 1.0)
			draw_circle(pos, 6.0 if !evolved else 8.0, glow_col)
			draw_circle(pos, 3.0 if !evolved else 4.0, core_col)
