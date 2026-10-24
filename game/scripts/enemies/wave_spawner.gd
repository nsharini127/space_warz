extends Node


signal wave_completed
signal spawn_enemy(enemy_scene: PackedScene, pos: Vector2, is_boss: bool)
signal spawn_mecha_boss(pos: Vector2)

var enemy_base_scene: PackedScene = preload("res://scenes/enemies/enemy_base.tscn")
var enemy_runner_scene: PackedScene = preload("res://scenes/enemies/enemy_runner.tscn")
var enemy_shooter_scene: PackedScene = preload("res://scenes/enemies/enemy_shooter.tscn")
var enemy_charger_scene: PackedScene = preload("res://scenes/enemies/enemy_charger.tscn")
var enemy_boss_scene: PackedScene = preload("res://scenes/enemies/enemy_boss.tscn")
var enemy_midboss_scene: PackedScene = preload("res://scenes/enemies/enemy_midboss.tscn")
var enemy_tank_scene: PackedScene = preload("res://scenes/enemies/enemy_tank.tscn")
var enemy_bomber_scene: PackedScene = preload("res://scenes/enemies/enemy_bomber.tscn")
var enemy_laser_scene: PackedScene = preload("res://scenes/enemies/enemy_laser.tscn")
var meteor_scene: PackedScene = preload("res://scenes/enemies/meteor.tscn")

var current_wave: int = 0
var enemies_to_spawn: int = 0
var enemies_spawned: int = 0
var enemies_alive: int = 0
var spawn_timer: float = 0.0
var spawn_interval: float = 1.0
var wave_active: bool = false
var boss_spawned: bool = false
var midboss_spawned: bool = false
var mecha_boss_spawned: bool = false
var meteor_wave_spawned: bool = false

# Wave flavor system
enum WaveFlavor { NORMAL, RUSH, SWARM, ELITE }
var current_flavor: int = WaveFlavor.NORMAL

# Burst spawning system
var burst_size: int = 3
var burst_spawn_interval: float = 0.3
var burst_pause: float = 1.5
var enemies_in_current_burst: int = 0
var in_burst_pause: bool = false
var burst_pause_timer: float = 0.0
var formation_cooldown: int = 0

const VIEWPORT_W = 320
const SPAWN_Y = -20

# Formation definitions: array of relative offsets from center position
const FORMATIONS = {
	"v_shape": {
		"offsets": [Vector2(0, 0), Vector2(-25, 25), Vector2(25, 25), Vector2(-50, 50), Vector2(50, 50)],
		"enemy_type": "runner",
		"min_wave": 3,
	},
	"line": {
		"offsets": [Vector2(-45, 0), Vector2(-15, 0), Vector2(15, 0), Vector2(45, 0)],
		"enemy_type": "base",
		"min_wave": 2,
	},
	"escort": {
		"offsets": [Vector2(0, 0), Vector2(-30, 20), Vector2(30, 20)],
		"enemy_types": ["shooter", "runner", "runner"],
		"min_wave": 5,
	},
	"pincer": {
		"offsets": [Vector2(-60, 0), Vector2(-30, 15), Vector2(30, 15), Vector2(60, 0)],
		"enemy_type": "charger",
		"min_wave": 6,
	},
}


func _ready():
	pass


func _get_difficulty() -> float:
	var game_nodes = get_tree().get_nodes_in_group("game")
	if game_nodes.size() > 0 and game_nodes[0].has_method("get_difficulty_multiplier"):
		return game_nodes[0].get_difficulty_multiplier()
	return 1.0


func start_wave(wave_number: int):
	current_wave = wave_number
	wave_active = true
	enemies_spawned = 0
	enemies_alive = 0
	boss_spawned = false
	midboss_spawned = false
	mecha_boss_spawned = false
	meteor_wave_spawned = false
	enemies_in_current_burst = 0
	in_burst_pause = false
	burst_pause_timer = 0.0
	formation_cooldown = 0

	# Spawn meteor wave before boss waves (wave 4+, one wave before boss)
	var next_wave = wave_number + 1
	var is_pre_boss: bool = (next_wave % 5 == 0) and wave_number >= 4
	if is_pre_boss:
		_spawn_meteor_wave()

	# Gentler early game progression
	var base_enemies: int
	if wave_number <= 3:
		base_enemies = 3 + wave_number  # Wave 1: 4, Wave 2: 5, Wave 3: 6
	else:
		base_enemies = 3 + wave_number * 2  # Wave 4: 11, Wave 5: 13...

	var is_mecha_boss_wave: bool = wave_number % 10 == 0
	var is_boss_wave: bool = wave_number % 5 == 0 and not is_mecha_boss_wave
	var is_midboss_wave = wave_number >= 4 and wave_number % 3 == 0 and !is_boss_wave and !is_mecha_boss_wave

	if is_boss_wave or is_midboss_wave or is_mecha_boss_wave:
		enemies_to_spawn = base_enemies + 1
	else:
		enemies_to_spawn = base_enemies

	# Slower spawn rate early, ramps up gradually
	# Apply difficulty multiplier from game timer
	var diff: float = _get_difficulty()
	enemies_to_spawn = int(enemies_to_spawn * diff)
	spawn_interval = max(0.2, (1.5 - wave_number * 0.06) / diff)

	# Select wave flavor
	current_flavor = _select_wave_flavor(wave_number, is_boss_wave, is_mecha_boss_wave)

	# Burst spawning: scale burst size and pause based on wave progression (NORMAL defaults)
	burst_size = clampi(2 + current_wave / 4, 2, 5)
	burst_pause = maxf(0.8, 2.0 - current_wave * 0.08)

	# Apply flavor overrides to enemy count and burst parameters
	match current_flavor:
		WaveFlavor.RUSH:
			burst_size = clampi(3 + current_wave / 3, 3, 6)
			burst_pause = 0.4
		WaveFlavor.SWARM:
			enemies_to_spawn = int(enemies_to_spawn * 1.5)
			burst_size = 2
			burst_pause = 1.2
		WaveFlavor.ELITE:
			enemies_to_spawn = maxi(4, int(enemies_to_spawn * 0.6))
			burst_size = 2
			burst_pause = 2.0

	# Boss waves get a dramatic pause before enemies start spawning (warning plays)
	if is_boss_wave or is_mecha_boss_wave:
		spawn_timer = 2.5
	else:
		spawn_timer = 0.8


func _select_wave_flavor(wave_number: int, is_boss_wave: bool, is_mecha_boss_wave: bool) -> int:
	# Waves 1-2: Always NORMAL (tutorial)
	if wave_number <= 2:
		return WaveFlavor.NORMAL
	# Boss waves: Always NORMAL (don't mess with boss pacing)
	if is_boss_wave or is_mecha_boss_wave:
		return WaveFlavor.NORMAL
	# Waves 3+: Weighted random selection
	# NORMAL 40%, RUSH 25%, SWARM 20%, ELITE 15%
	var roll: float = randf()
	if roll < 0.40:
		return WaveFlavor.NORMAL
	elif roll < 0.65:
		return WaveFlavor.RUSH
	elif roll < 0.85:
		return WaveFlavor.SWARM
	else:
		return WaveFlavor.ELITE


func get_current_flavor_name() -> String:
	match current_flavor:
		WaveFlavor.RUSH:
			return "RUSH"
		WaveFlavor.SWARM:
			return "SWARM"
		WaveFlavor.ELITE:
			return "ELITE"
		_:
			return ""


func _process(delta: float):
	if !wave_active:
		return

	# Burst pause: wait between bursts before spawning more enemies
	if in_burst_pause:
		burst_pause_timer -= delta
		if burst_pause_timer <= 0:
			in_burst_pause = false
		else:
			# Still check for wave completion during pause
			if enemies_spawned >= enemies_to_spawn and enemies_alive <= 0:
				wave_active = false
				wave_completed.emit()
			return

	spawn_timer -= delta

	if spawn_timer <= 0 and enemies_spawned < enemies_to_spawn:
		spawn_timer = burst_spawn_interval  # Fast spawn within burst
		spawn_next_enemy()
		enemies_in_current_burst += 1
		if enemies_in_current_burst >= burst_size:
			# Burst complete, start pause
			enemies_in_current_burst = 0
			in_burst_pause = true
			burst_pause_timer = burst_pause

	if enemies_spawned >= enemies_to_spawn and enemies_alive <= 0:
		wave_active = false
		# Let game.gd decide whether to show upgrade menu (boss may still be alive)
		wave_completed.emit()


func spawn_next_enemy():
	var scene: PackedScene
	var pos = Vector2(randf_range(20, VIEWPORT_W - 20), SPAWN_Y)
	var is_boss = false
	var is_midboss = false

	# Mecha boss wave (every 10): spawn mecha boss as last enemy
	if current_wave % 10 == 0 and enemies_spawned == enemies_to_spawn - 1 and !mecha_boss_spawned:
		mecha_boss_spawned = true
		enemies_spawned += 1
		enemies_alive += 1
		spawn_mecha_boss.emit(Vector2(VIEWPORT_W / 2.0, SPAWN_Y))
		return
	# Regular boss wave (every 5, not mecha): spawn boss as last enemy
	elif current_wave % 5 == 0 and current_wave % 10 != 0 and enemies_spawned == enemies_to_spawn - 1 and !boss_spawned:
		scene = enemy_boss_scene
		pos.x = VIEWPORT_W / 2.0
		boss_spawned = true
		is_boss = true
	# Midboss wave (every 3rd from wave 4+, non-boss): spawn halfway
	elif current_wave >= 4 and current_wave % 3 == 0 and current_wave % 5 != 0 and enemies_spawned == enemies_to_spawn / 2 and !midboss_spawned:
		scene = enemy_midboss_scene
		pos.x = VIEWPORT_W / 2.0
		midboss_spawned = true
		is_midboss = true
	else:
		# Check for formation spawn (only for regular enemies, not bosses/midbosses)
		if formation_cooldown <= 0 and _should_spawn_formation():
			_spawn_formation()
			return
		scene = _pick_enemy_type()
		formation_cooldown -= 1
		# Bombers spawn from the sides
		if scene == enemy_bomber_scene:
			if randf() < 0.5:
				pos = Vector2(-20, randf_range(40, 120))
			else:
				pos = Vector2(VIEWPORT_W + 20, randf_range(40, 120))

	enemies_spawned += 1
	enemies_alive += 1

	if is_midboss:
		spawn_enemy.emit(scene, pos, false)
	else:
		spawn_enemy.emit(scene, pos, is_boss)


func _pick_enemy_type() -> PackedScene:
	# Apply flavor bias for SWARM and ELITE
	if current_flavor == WaveFlavor.SWARM:
		return _pick_enemy_type_swarm()
	if current_flavor == WaveFlavor.ELITE:
		return _pick_enemy_type_elite()

	# Wave 1: only basic enemies
	if current_wave <= 1:
		return enemy_base_scene

	# Wave 2-3: basics + occasional runners
	if current_wave <= 3:
		if randf() < 0.25:
			return enemy_runner_scene
		return enemy_base_scene

	# Wave 4: basics + runners + rare shooters
	if current_wave == 4:
		var roll = randf()
		if roll < 0.15:
			return enemy_shooter_scene
		elif roll < 0.40:
			return enemy_runner_scene
		return enemy_base_scene

	# Wave 5+: all enemy types with new enemies introduced progressively
	var roll = randf()

	# Laser enemy: 7% chance from wave 10+
	if current_wave >= 10 and roll < 0.07:
		return enemy_laser_scene

	# Bomber enemy: 8% chance from wave 8+
	if current_wave >= 8 and roll < 0.15:
		return enemy_bomber_scene

	# Tank enemy: 10% chance from wave 7+
	if current_wave >= 7 and roll < 0.25:
		return enemy_tank_scene

	# Original enemy types
	if roll < 0.15:
		return enemy_charger_scene
	elif roll < 0.35:
		return enemy_shooter_scene
	elif roll < 0.55:
		return enemy_runner_scene
	return enemy_base_scene


func _pick_enemy_type_swarm() -> PackedScene:
	# SWARM: 60% runners, 25% base, 15% other
	var roll = randf()
	if roll < 0.60:
		return enemy_runner_scene
	elif roll < 0.85:
		return enemy_base_scene
	else:
		# Small chance for shooters to add some variety
		return enemy_shooter_scene


func _pick_enemy_type_elite() -> PackedScene:
	# ELITE: No runners. Pick from shooters, chargers, tanks (and bomber/laser if unlocked)
	var pool: Array[PackedScene] = [enemy_shooter_scene, enemy_charger_scene]
	if current_wave >= 7:
		pool.append(enemy_tank_scene)
	if current_wave >= 8:
		pool.append(enemy_bomber_scene)
	if current_wave >= 10:
		pool.append(enemy_laser_scene)
	return pool[randi() % pool.size()]


func _spawn_meteor_wave():
	meteor_wave_spawned = true
	var count = randi_range(5, 10)
	# Tiered escalation: first 40% slow, next 40% fast, last 20% rapid
	var slow_count: int = int(count * 0.4)
	var fast_count: int = int(count * 0.4)
	# remaining is rapid
	var cumulative_delay: float = 0.0
	for i in range(count):
		var pos = Vector2(randf_range(20, VIEWPORT_W - 20), SPAWN_Y - i * 30)
		enemies_to_spawn += 1
		var interval: float
		if i < slow_count:
			interval = 0.5
		elif i < slow_count + fast_count:
			interval = 0.25
		else:
			interval = 0.15
		if i > 0:
			cumulative_delay += interval
		var timer = get_tree().create_timer(cumulative_delay)
		timer.timeout.connect(func(): _spawn_single_meteor(pos))


func _spawn_single_meteor(pos: Vector2):
	enemies_alive += 1
	enemies_spawned += 1
	spawn_enemy.emit(meteor_scene, pos, false)


func should_complete_wave() -> bool:
	return enemies_spawned >= enemies_to_spawn and enemies_alive <= 0


func on_enemy_died():
	enemies_alive -= 1


func _should_spawn_formation() -> bool:
	# Don't spawn formations in the last few enemies (leave room for boss)
	if enemies_to_spawn - enemies_spawned < 5:
		return false
	# Chance increases with wave: 10% base, +1.5% per wave
	var chance = 0.10 + current_wave * 0.015
	return randf() < chance


func _spawn_formation():
	# Pick a valid formation for current wave
	var valid_formations: Array = []
	for name in FORMATIONS:
		var f = FORMATIONS[name]
		if current_wave >= f.min_wave:
			valid_formations.append(name)

	if valid_formations.is_empty():
		return

	var formation_name = valid_formations[randi() % valid_formations.size()]
	var formation = FORMATIONS[formation_name]
	var offsets: Array = formation.offsets

	# Check we have enough enemies left to spawn the formation
	var remaining = enemies_to_spawn - enemies_spawned
	if remaining < offsets.size():
		return

	# Center position
	var center_x = randf_range(70, VIEWPORT_W - 70)
	var center = Vector2(center_x, SPAWN_Y)

	# Spawn each enemy in formation with slight delays
	for i in range(offsets.size()):
		var pos = center + offsets[i]
		pos.x = clampf(pos.x, 20, VIEWPORT_W - 20)

		var scene: PackedScene
		if formation.has("enemy_types"):
			scene = _get_scene_for_type(formation.enemy_types[i])
		else:
			scene = _get_scene_for_type(formation.enemy_type)

		enemies_spawned += 1
		enemies_alive += 1
		spawn_enemy.emit(scene, pos, false)

	# Cooldown: don't spawn another formation for 3-5 enemies
	formation_cooldown = randi_range(3, 5)


func _get_scene_for_type(type_name: String) -> PackedScene:
	match type_name:
		"runner": return enemy_runner_scene
		"shooter": return enemy_shooter_scene
		"charger": return enemy_charger_scene
		"tank": return enemy_tank_scene
		"bomber": return enemy_bomber_scene
		"laser": return enemy_laser_scene
		_: return enemy_base_scene
