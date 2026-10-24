extends Node


signal weapon_bullet_fired(bullet_scene: PackedScene, pos: Vector2, dir: Vector2, dmg: int, pierce: int, glow_color: Color, weapon_id: String)
signal weapon_effect_requested(effect_type: String, data: Dictionary)
signal weapon_added(weapon_id: String, level: int)
signal weapon_leveled_up(weapon_id: String, level: int)

const MAX_WEAPONS = 6
const VIEWPORT_W = 320
const VIEWPORT_H = 480

var active_weapons: Dictionary = {}  # id -> {data, level, timer, evolved, extra_state}
var player: CharacterBody2D = null
var enemy_container: Node2D = null
var bullet_scene: PackedScene = preload("res://scenes/projectiles/bullet_player.tscn")

# Effect nodes managed here
var _effect_nodes: Dictionary = {}  # id -> Node

# Current weapon glow color and ID (set before firing)
var _current_glow: Color = Color(0, 0.8, 1.0)
var _current_weapon_id: String = ""


func setup(p_player: CharacterBody2D, p_enemy_container: Node2D):
	player = p_player
	enemy_container = p_enemy_container


func reset():
	# Remove all effect nodes
	for id in _effect_nodes:
		if is_instance_valid(_effect_nodes[id]):
			_effect_nodes[id].queue_free()
	_effect_nodes.clear()

	# Clean up drone nodes stored in extra_state
	for wid in active_weapons:
		var w = active_weapons[wid]
		if w.extra_state.has("drone_nodes"):
			for d in w.extra_state["drone_nodes"]:
				if is_instance_valid(d):
					d.queue_free()

	active_weapons.clear()
	# Always start with front_laser level 1
	add_weapon("front_laser")


func add_weapon(id: String) -> bool:
	if active_weapons.has(id):
		return level_up_weapon(id)

	if active_weapons.size() >= MAX_WEAPONS:
		return false

	var data = WeaponRegistry.get_weapon(id)
	if data.is_empty():
		return false

	active_weapons[id] = {
		"data": data,
		"level": 1,
		"timer": 0.0,
		"evolved": false,
		"extra_state": {},
	}

	_on_weapon_added(id)
	weapon_added.emit(id, 1)
	return true


func level_up_weapon(id: String) -> bool:
	if !active_weapons.has(id):
		return false

	var w = active_weapons[id]
	var max_lvl = w.data.max_level
	if w.level >= max_lvl:
		return _try_evolve(id)

	w.level += 1
	_on_weapon_leveled(id)
	weapon_leveled_up.emit(id, w.level)
	return true


func _try_evolve(id: String) -> bool:
	var w = active_weapons[id]
	var evolves_to = w.data.get("evolves_to", "")
	if evolves_to == "" or w.evolved:
		return false

	w.evolved = true
	w.level = w.data.max_level
	weapon_leveled_up.emit(id, w.level)
	return true


func get_weapon_level(id: String) -> int:
	if active_weapons.has(id):
		return active_weapons[id].level
	return 0


func get_weapon_count() -> int:
	return active_weapons.size()


func get_active_weapon_ids() -> Array:
	return active_weapons.keys()


func has_weapon(id: String) -> bool:
	return active_weapons.has(id)


func is_weapon_max_level(id: String) -> bool:
	if !active_weapons.has(id):
		return false
	var w = active_weapons[id]
	return w.level >= w.data.max_level


func is_weapon_evolved(id: String) -> bool:
	if !active_weapons.has(id):
		return false
	return active_weapons[id].evolved


## Power level gives a fire rate bonus (3% per level, up to ~24% at max).
## Also applies temporary attack speed buff from BuffSystem.
func _get_power_fire_rate_mult() -> float:
	if !player:
		return 1.0
	var power: int = player.power_level if "power_level" in player else 1
	var base_mult: float = 1.0 - (power - 1) * 0.03
	# Apply attack speed buff (lower multiplier = faster firing)
	var buff_mult: float = player.get_attack_speed_multiplier() if player.has_method("get_attack_speed_multiplier") else 1.0
	return base_mult / buff_mult


# Helper to emit bullet with current glow color and weapon_id
func _emit_bullet(pos: Vector2, dir: Vector2, dmg: int, pierce: int):
	weapon_bullet_fired.emit(bullet_scene, pos, dir, dmg, pierce, _current_glow, _current_weapon_id)


func _process(delta: float):
	if !player or !player.is_alive:
		return

	for id in active_weapons:
		var w = active_weapons[id]
		var wtype = w.data.get("weapon_type", "projectile")

		if wtype == "effect":
			_process_effect_weapon(id, w, delta)
		else:
			w.timer -= delta
			if w.timer <= 0:
				var interval = WeaponRegistry.get_fire_interval_at_level(w.data, w.level)
				w.timer = interval * _get_power_fire_rate_mult()
				_fire_weapon(id, w)


func _fire_weapon(id: String, w: Dictionary):
	var dmg = WeaponRegistry.get_damage_at_level(w.data, w.level) + player.damage - 1
	var count = WeaponRegistry.get_projectile_count_at_level(w.data, w.level)
	var pierce = player.pierce
	var pos = player.global_position + Vector2(0, -10)
	var evolved = w.evolved
	_current_glow = w.data.get("glow_color", Color(0, 0.8, 1.0))
	_current_weapon_id = id

	match id:
		"front_laser":
			_fire_front_laser(pos, dmg, count, pierce, evolved)
		"spread_shot":
			_fire_spread_shot(pos, dmg, count, pierce, evolved)
		"rear_cannon":
			_fire_rear_cannon(pos, dmg, count, pierce, evolved)
		"side_cannons":
			_fire_side_cannons(pos, dmg, count, pierce, evolved)
		"homing_missile":
			_fire_homing_missile(pos, dmg, count, pierce, evolved)


func _process_effect_weapon(id: String, w: Dictionary, delta: float):
	var power_mult = _get_power_fire_rate_mult()
	match id:
		"lightning":
			w.timer -= delta
			if w.timer <= 0:
				var interval = WeaponRegistry.get_fire_interval_at_level(w.data, w.level)
				w.timer = interval * power_mult
				_fire_lightning(w)
		"shockwave":
			w.timer -= delta
			if w.timer <= 0:
				var interval = WeaponRegistry.get_fire_interval_at_level(w.data, w.level)
				w.timer = interval * power_mult
				_fire_shockwave(w)
		"orbital_shield":
			_process_orbital(w, delta)
		"drone":
			_process_drone(w, delta)


# ==================== PROJECTILE WEAPONS ====================

func _fire_front_laser(pos: Vector2, dmg: int, count: int, pierce: int, evolved: bool):
	if player.is_focused:
		var focus_dmg = int(dmg * 1.5)
		_emit_bullet(pos, Vector2.UP, focus_dmg, pierce)
		if count >= 2:
			_emit_bullet(pos + Vector2(-3, 0), Vector2.UP, focus_dmg, pierce)
			_emit_bullet(pos + Vector2(3, 0), Vector2.UP, focus_dmg, pierce)
		if count >= 4:
			_emit_bullet(pos + Vector2(-6, 2), Vector2.UP, focus_dmg, pierce)
			_emit_bullet(pos + Vector2(6, 2), Vector2.UP, focus_dmg, pierce)
		if evolved:
			_emit_bullet(pos + Vector2(-9, 4), Vector2.UP, focus_dmg, pierce)
			_emit_bullet(pos + Vector2(9, 4), Vector2.UP, focus_dmg, pierce)
	else:
		if count == 1:
			_emit_bullet(pos, Vector2.UP, dmg, pierce)
		else:
			var arc = deg_to_rad(6 + count * 3)
			for i in range(count):
				var t = float(i) / max(count - 1, 1) - 0.5
				var angle = t * arc
				var dir = Vector2(sin(angle), -cos(angle))
				var offset = Vector2(t * 6, 0)
				_emit_bullet(pos + offset, dir, dmg, pierce)
			if evolved:
				_emit_bullet(pos + Vector2(-12, 0), Vector2(-0.15, -1).normalized(), dmg, pierce)
				_emit_bullet(pos + Vector2(12, 0), Vector2(0.15, -1).normalized(), dmg, pierce)


func _fire_spread_shot(pos: Vector2, dmg: int, count: int, pierce: int, evolved: bool):
	var total = count
	if evolved:
		total = 12
	var arc = deg_to_rad(60) if !evolved else TAU
	var start_angle = -arc / 2.0 if !evolved else 0.0

	for i in range(total):
		var t: float
		if evolved:
			t = float(i) / total
		else:
			t = float(i) / max(total - 1, 1)
		var angle = start_angle + t * arc
		var dir = Vector2(sin(angle), -cos(angle))
		_emit_bullet(pos, dir, dmg, pierce)


func _fire_rear_cannon(pos: Vector2, dmg: int, count: int, pierce: int, evolved: bool):
	var rear_pos = player.global_position + Vector2(0, 10)
	_emit_bullet(rear_pos, Vector2.DOWN, dmg, pierce)
	if count >= 2:
		_emit_bullet(rear_pos + Vector2(-5, 0), Vector2(-0.1, 1).normalized(), dmg, pierce)
	if count >= 3:
		_emit_bullet(rear_pos + Vector2(5, 0), Vector2(0.1, 1).normalized(), dmg, pierce)
	if evolved:
		_emit_bullet(pos, Vector2.UP, dmg, pierce)
		_emit_bullet(pos + Vector2(-5, 0), Vector2(-0.1, -1).normalized(), dmg, pierce)
		_emit_bullet(pos + Vector2(5, 0), Vector2(0.1, -1).normalized(), dmg, pierce)


func _fire_side_cannons(pos: Vector2, dmg: int, count: int, pierce: int, evolved: bool):
	var left_dir = Vector2(-0.95, -0.3).normalized()
	var right_dir = Vector2(0.95, -0.3).normalized()
	_emit_bullet(pos + Vector2(-8, 0), left_dir, dmg, pierce)
	_emit_bullet(pos + Vector2(8, 0), right_dir, dmg, pierce)
	if count >= 4:
		var left_dir2 = Vector2(-0.8, -0.6).normalized()
		var right_dir2 = Vector2(0.8, -0.6).normalized()
		_emit_bullet(pos + Vector2(-6, -4), left_dir2, dmg, pierce)
		_emit_bullet(pos + Vector2(6, -4), right_dir2, dmg, pierce)
	if count >= 6 or evolved:
		_emit_bullet(pos, Vector2.UP, dmg, pierce)
		_emit_bullet(pos, Vector2.DOWN, dmg, pierce)


func _fire_homing_missile(pos: Vector2, dmg: int, count: int, pierce: int, evolved: bool):
	var total = count
	if evolved:
		total = count + 2
	for i in range(total):
		var offset = Vector2(randf_range(-8, 8), randf_range(-4, 4))
		var data = {
			"pos": pos + offset,
			"dmg": dmg,
			"pierce": pierce,
			"speed": 150.0 if !evolved else 200.0,
			"turn_speed": 4.0 if !evolved else 6.0,
		}
		weapon_effect_requested.emit("homing_missile", data)


# ==================== EFFECT WEAPONS ====================

func _fire_lightning(w: Dictionary):
	var dmg = WeaponRegistry.get_damage_at_level(w.data, w.level) + player.damage - 1
	var chains = WeaponRegistry.get_projectile_count_at_level(w.data, w.level)
	if w.evolved:
		chains += 3
		dmg = int(dmg * 1.5)
	weapon_effect_requested.emit("lightning", {
		"pos": player.global_position,
		"dmg": dmg,
		"chains": chains,
		"evolved": w.evolved,
	})


func _fire_shockwave(w: Dictionary):
	var dmg = WeaponRegistry.get_damage_at_level(w.data, w.level) + player.damage - 1
	var count = WeaponRegistry.get_projectile_count_at_level(w.data, w.level)
	if w.evolved:
		dmg = int(dmg * 1.5)
	weapon_effect_requested.emit("shockwave", {
		"pos": player.global_position,
		"dmg": dmg,
		"radius": 40.0 + w.level * 10.0 + (20.0 if w.evolved else 0.0),
		"count": count,
		"evolved": w.evolved,
	})


func _process_orbital(w: Dictionary, _delta: float):
	var id = "orbital_shield"
	var orb_count = WeaponRegistry.get_projectile_count_at_level(w.data, w.level)
	if w.evolved:
		orb_count += 2
	var dmg = WeaponRegistry.get_damage_at_level(w.data, w.level) + player.damage - 1
	if w.evolved:
		dmg = int(dmg * 1.5)

	if !_effect_nodes.has(id) or !is_instance_valid(_effect_nodes[id]):
		_create_orbital_node(id, orb_count, dmg, w.evolved)
	else:
		var orbital = _effect_nodes[id]
		orbital.update_config(orb_count, dmg, w.evolved)


func _create_orbital_node(id: String, orb_count: int, dmg: int, evolved: bool):
	var orbital_script = preload("res://scripts/weapons/orbital_weapon.gd")
	var orbital = Node2D.new()
	orbital.set_script(orbital_script)
	orbital.setup(player, orb_count, dmg, 28.0, evolved)
	player.get_parent().add_child(orbital)
	_effect_nodes[id] = orbital


func _process_drone(w: Dictionary, _delta: float):
	var drone_count = WeaponRegistry.get_projectile_count_at_level(w.data, w.level)
	if w.evolved:
		drone_count += 2
	var dmg = WeaponRegistry.get_damage_at_level(w.data, w.level) + player.damage - 1
	var fire_interval = WeaponRegistry.get_fire_interval_at_level(w.data, w.level)

	var state_key = "drone_nodes"
	if !w.extra_state.has(state_key):
		w.extra_state[state_key] = []

	var drone_nodes: Array = w.extra_state[state_key]

	# Clean invalid
	var valid: Array = []
	for d in drone_nodes:
		if is_instance_valid(d):
			valid.append(d)
	drone_nodes = valid
	w.extra_state[state_key] = drone_nodes

	# Add/remove drones as needed
	while drone_nodes.size() < drone_count:
		var drone_node = _create_drone_node(drone_nodes.size(), drone_count, dmg, fire_interval)
		drone_nodes.append(drone_node)

	while drone_nodes.size() > drone_count:
		var excess = drone_nodes.pop_back()
		if is_instance_valid(excess):
			excess.queue_free()

	# Update existing drones
	for i in range(drone_nodes.size()):
		if is_instance_valid(drone_nodes[i]):
			drone_nodes[i].update_config(i, drone_nodes.size(), dmg, fire_interval)


func _create_drone_node(index: int, total: int, dmg: int, fire_interval: float) -> Node2D:
	var drone_script = preload("res://scripts/weapons/effects/drone_weapon.gd")
	var drone_node = Node2D.new()
	drone_node.set_script(drone_script)
	drone_node.setup(player, index, total, dmg, fire_interval)
	drone_node.drone_shoot.connect(_on_drone_shoot)
	player.get_parent().add_child(drone_node)
	return drone_node


func _on_drone_shoot(scene: PackedScene, pos: Vector2, dir: Vector2, dmg: int, pierce: int):
	weapon_bullet_fired.emit(scene, pos, dir, dmg, pierce, Color(0.5, 0.7, 1.0), "drone")


func _on_weapon_added(_id: String):
	pass


func _on_weapon_leveled(_id: String):
	pass
