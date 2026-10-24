extends Node2D


signal wave_completed
signal game_over

@onready var player: CharacterBody2D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var wave_spawner: Node = $WaveSpawner
@onready var upgrade_menu: CanvasLayer = $UpgradeMenu
@onready var game_over_screen: CanvasLayer = $GameOverScreen
@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var bullet_container: Node2D = $BulletContainer
@onready var enemy_container: Node2D = $EnemyContainer
@onready var item_container: Node2D = $ItemContainer
@onready var bg_music: AudioStreamPlayer = $BGMusic
@onready var bg_music_alt: AudioStreamPlayer = $BGMusicAlt
@onready var sfx_shoot: AudioStreamPlayer = $SFXShoot
@onready var sfx_hit: AudioStreamPlayer = $SFXHit
@onready var sfx_enemy_die: AudioStreamPlayer = $SFXEnemyDie
@onready var sfx_powerup: AudioStreamPlayer = $SFXPowerup
@onready var sfx_game_over: AudioStreamPlayer = $SFXGameOver
@onready var sfx_level_up: AudioStreamPlayer = $SFXLevelUp
@onready var sfx_explosion: AudioStreamPlayer = $SFXExplosion
@onready var sfx_coin: AudioStreamPlayer = $SFXCoin
@onready var sfx_accept: AudioStreamPlayer = $SFXAccept
@onready var sfx_bomb: AudioStreamPlayer = $SFXBomb
@onready var bg_scroller: Node2D = $BackgroundScroller
@onready var screen_flash: ColorRect = $ScreenFlash

var score: int = 0
var current_wave: int = 0
var is_game_active: bool = false
var screen_shake_amount: float = 0.0
var camera: Camera2D

# Game stats tracking
var enemies_killed: int = 0
var bosses_defeated: int = 0
var max_combo: int = 0
var time_survived: float = 0.0

var hit_sounds: Array = []
var slash_sounds: Array = []

# Systems
var counter_system: Node
var rank_system: Node
var weapon_manager: Node
var environment_manager: Node
var fever_system: Node
var trophy_system: Node
var current_boss: CharacterBody2D = null
var current_mecha_boss: Node2D = null
var hitstop_timer: float = 0.0
var flash_timer: float = 0.0

# Boss wave tracking - prevents upgrade menu from killing boss
var boss_wave_active: bool = false
var pending_wave_complete: bool = false

# 5-minute game timer and difficulty
var game_timer: float = 300.0
var final_boss_spawned: bool = false
var game_won: bool = false

var mecha_boss_scene: PackedScene = preload("res://scenes/enemies/boss/mecha_boss.tscn")

# Music crossfade system
var _music_fade_timer: float = 0.0
var _music_fading: bool = false
var _fade_from: AudioStreamPlayer = null
var _fade_to: AudioStreamPlayer = null
const MUSIC_FADE_DURATION: float = 1.5

var music_fight: AudioStream = null
var music_adventure: AudioStream = null

const VIEWPORT_W = 320
const VIEWPORT_H = 480


func _ready():
	camera = Camera2D.new()
	camera.position = Vector2(VIEWPORT_W / 2, VIEWPORT_H / 2)
	add_child(camera)

	# Initialize systems
	_init_systems()

	# Load audio
	music_fight = load("res://assets/audio/music/theme_fight.ogg")
	music_adventure = load("res://assets/audio/music/theme_adventure.ogg")
	bg_music.stream = music_fight
	bg_music.volume_db = 0.0
	sfx_shoot.stream = load("res://assets/audio/sfx/whoosh.wav")
	sfx_hit.stream = load("res://assets/audio/sfx/hit1.wav")
	sfx_enemy_die.stream = load("res://assets/audio/sfx/impact.wav")
	sfx_powerup.stream = load("res://assets/audio/sfx/powerup.wav")
	sfx_game_over.stream = load("res://assets/audio/jingles/game_over.wav")
	sfx_level_up.stream = load("res://assets/audio/jingles/level_up.wav")
	sfx_explosion.stream = load("res://assets/audio/sfx/explosion.wav")
	sfx_coin.stream = load("res://assets/audio/sfx/coin.wav")
	sfx_coin.volume_db = -6.0
	sfx_accept.stream = load("res://assets/audio/sfx/accept.wav")
	sfx_bomb.stream = load("res://assets/audio/sfx/sword.wav")

	# Polyphony: allow overlapping sounds for rapid-fire contexts
	sfx_shoot.max_polyphony = 4
	sfx_enemy_die.max_polyphony = 3
	sfx_coin.max_polyphony = 4
	sfx_explosion.max_polyphony = 2
	sfx_hit.max_polyphony = 2

	hit_sounds = [
		load("res://assets/audio/sfx/hit1.wav"),
		load("res://assets/audio/sfx/hit2.wav"),
		load("res://assets/audio/sfx/hit3.wav"),
	]
	slash_sounds = [
		load("res://assets/audio/sfx/slash.wav"),
		load("res://assets/audio/sfx/slash2.wav"),
	]

	# Connect player signals
	player.player_hit.connect(_on_player_hit)
	player.player_died.connect(_on_player_died)
	player.bomb_activated.connect(_on_bomb_activated)
	player.gem_collected.connect(_on_gem_collected)
	player.power_item_collected.connect(_on_power_item_collected)
	player.bomb_item_collected.connect(_on_bomb_item_collected)
	player.buff_item_collected.connect(_on_buff_item_collected)

	wave_spawner.wave_completed.connect(_on_wave_completed)
	wave_spawner.spawn_enemy.connect(_on_spawn_enemy)
	wave_spawner.spawn_mecha_boss.connect(_on_spawn_mecha_boss)

	upgrade_menu.upgrade_selected.connect(_on_upgrade_selected)
	game_over_screen.restart_requested.connect(_on_restart)
	game_over_screen.quit_requested.connect(_on_quit)

	pause_menu.resume_requested.connect(_on_resume)
	pause_menu.quit_requested.connect(_on_quit)

	start_game()


func _init_systems():
	# Counter system
	counter_system = Node.new()
	counter_system.set_script(preload("res://scripts/systems/counter_system.gd"))
	add_child(counter_system)
	counter_system.counter_updated.connect(_on_counter_updated)

	# Rank system
	rank_system = Node.new()
	rank_system.set_script(preload("res://scripts/systems/rank_system.gd"))
	add_child(rank_system)

	# Weapon manager
	weapon_manager = Node.new()
	weapon_manager.set_script(preload("res://scripts/weapons/weapon_manager.gd"))
	add_child(weapon_manager)
	weapon_manager.weapon_bullet_fired.connect(_on_player_bullet_fired)
	weapon_manager.weapon_effect_requested.connect(_on_weapon_effect_requested)
	weapon_manager.weapon_added.connect(_on_weapon_added)
	weapon_manager.weapon_leveled_up.connect(_on_weapon_leveled_up)

	# Environment manager
	environment_manager = Node.new()
	environment_manager.set_script(preload("res://scripts/systems/environment_manager.gd"))
	add_child(environment_manager)
	environment_manager.environment_changed.connect(_on_environment_changed)

	# Fever system
	fever_system = Node.new()
	fever_system.set_script(preload("res://scripts/systems/fever_system.gd"))
	add_child(fever_system)
	fever_system.fever_started.connect(_on_fever_started)
	fever_system.fever_ended.connect(_on_fever_ended)

	# Trophy system
	trophy_system = Node.new()
	trophy_system.set_script(preload("res://scripts/systems/trophy_system.gd"))
	add_child(trophy_system)
	trophy_system.trophy_unlocked.connect(_on_trophy_unlocked)


func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("pause") and is_game_active:
		pause_menu.show_pause()
		get_viewport().set_input_as_handled()


func get_difficulty_multiplier() -> float:
	var elapsed: float = 300.0 - game_timer
	var t: float = elapsed / 300.0
	return clampf(1.0 + t * t * 2.0, 1.0, 3.0)


func _crossfade_music(track: AudioStream) -> void:
	# Determine which player is currently active
	var current_player: AudioStreamPlayer
	var next_player: AudioStreamPlayer
	if bg_music.playing:
		current_player = bg_music
		next_player = bg_music_alt
	elif bg_music_alt.playing:
		current_player = bg_music_alt
		next_player = bg_music
	else:
		# Nothing playing, just start directly
		bg_music.stream = track
		bg_music.volume_db = 0.0
		bg_music.pitch_scale = 1.0
		bg_music.play()
		return

	# Don't crossfade if already playing this track
	if current_player.stream == track:
		return

	# Setup the new player
	next_player.stream = track
	next_player.volume_db = -40.0
	next_player.pitch_scale = 1.0
	next_player.play()

	# Begin fade
	_fade_from = current_player
	_fade_to = next_player
	_music_fade_timer = 0.0
	_music_fading = true


func _process_music_fade(delta: float) -> void:
	if not _music_fading:
		return
	_music_fade_timer += delta
	var t: float = clampf(_music_fade_timer / MUSIC_FADE_DURATION, 0.0, 1.0)
	# Fade from 0dB to -40dB (out) and -40dB to 0dB (in)
	_fade_from.volume_db = lerpf(0.0, -40.0, t)
	_fade_to.volume_db = lerpf(-40.0, 0.0, t)
	if t >= 1.0:
		_fade_from.stop()
		_fade_to.volume_db = 0.0
		_music_fading = false


func _set_music_pitch(pitch: float) -> void:
	bg_music.pitch_scale = pitch
	bg_music_alt.pitch_scale = pitch


func start_game():
	GloveInput.send_event("game_start")
	score = 0
	current_wave = 0
	is_game_active = true
	current_boss = null
	boss_wave_active = false
	pending_wave_complete = false
	game_timer = 300.0
	final_boss_spawned = false
	game_won = false
	enemies_killed = 0
	bosses_defeated = 0
	max_combo = 0
	time_survived = 0.0
	add_to_group("game")
	player.reset()
	upgrade_menu.reset_levels()
	counter_system.reset()
	rank_system.reset()
	environment_manager.reset()
	fever_system.reset()
	trophy_system.reset()

	# Setup and reset weapon manager
	weapon_manager.setup(player, enemy_container)
	weapon_manager.reset()
	weapon_manager.set_process(true)

	# Setup upgrade menu with weapon_manager reference
	upgrade_menu.weapon_manager = weapon_manager

	hud.update_score(score)
	hud.update_wave(current_wave)
	hud.update_hp(player.current_hp, player.max_hp)
	hud.update_bombs(player.bomb_count)
	hud.update_power(player.power_level)
	hud.update_graze(0)
	hud.update_counter(0, 0, "GREEN")
	hud.hide_boss_hp()
	hud.hide_fever()
	hud.update_weapons(weapon_manager)

	# Reset environment
	if bg_scroller:
		bg_scroller.is_active = true
		bg_scroller.change_environment(environment_manager.get_current_environment())

	game_over_screen.hide()
	upgrade_menu.hide()
	pause_menu.hide()

	# Reset music system
	_music_fading = false
	_music_fade_timer = 0.0
	_fade_from = null
	_fade_to = null
	bg_music.stop()
	bg_music_alt.stop()
	bg_music.pitch_scale = 1.0
	bg_music_alt.pitch_scale = 1.0
	bg_music.volume_db = 0.0

	# Start fight music
	_crossfade_music(music_fight)

	start_next_wave()


func start_next_wave():
	current_wave += 1
	hud.update_wave(current_wave)
	counter_system.reset_stage()
	wave_spawner.start_wave(current_wave)

	# Wave announcement
	_show_wave_announce()


func _show_wave_announce():
	var announce = Node2D.new()
	announce.set_script(preload("res://scripts/ui/wave_announce.gd"))
	var is_boss_wave: bool = current_wave % 5 == 0
	var label: String = "WAVE " + str(current_wave)
	if current_wave % 10 == 0:
		label = "WAVE " + str(current_wave) + " - MECHA BOSS"
	else:
		var flavor_name: String = wave_spawner.get_current_flavor_name()
		if flavor_name != "":
			label = "WAVE " + str(current_wave) + " - " + flavor_name
	announce.setup(label, is_boss_wave)
	add_child(announce)

	# Dramatic screen shake and warning sound for boss waves
	if is_boss_wave:
		screen_shake_amount = 4.0
		# Deep warning boom using hit sound with low pitch
		if sfx_hit.stream:
			var old_pitch = sfx_hit.pitch_scale
			sfx_hit.pitch_scale = 0.6
			sfx_hit.play()
			sfx_hit.pitch_scale = old_pitch


func _on_wave_completed():
	trophy_system.on_wave_completed()
	# If boss is still alive, defer the upgrade menu until boss dies
	if boss_wave_active:
		pending_wave_complete = true
		return
	is_game_active = false
	# Stop weapons and clear player bullets so in-flight projectiles don't kill boss during menu
	weapon_manager.set_process(false)
	_clear_player_bullets()
	_clear_effect_weapons()
	if sfx_level_up.stream:
		sfx_level_up.play()
	upgrade_menu.show_upgrades()


func _on_upgrade_selected(upgrade_data: Dictionary):
	if upgrade_data.get("category", "") == "weapon":
		weapon_manager.add_weapon(upgrade_data.id)
		hud.update_weapons(weapon_manager)
	else:
		player.apply_upgrade(upgrade_data)
	hud.update_hp(player.current_hp, player.max_hp)
	hud.update_bombs(player.bomb_count)
	hud.update_power(player.power_level)
	upgrade_menu.hide()
	is_game_active = true
	weapon_manager.set_process(true)
	if sfx_accept.stream:
		sfx_accept.play()
	# Don't start next wave if boss is still alive
	if not boss_wave_active:
		start_next_wave()


func _on_player_bullet_fired(bullet_scene: PackedScene, pos: Vector2, dir: Vector2, dmg: int, pierce: int, glow_color: Color = Color(0, 0.8, 1.0), weapon_id: String = ""):
	var bullet = bullet_scene.instantiate()
	bullet.position = pos
	bullet.direction = dir
	bullet.damage = dmg
	bullet.pierce_count = pierce
	bullet.is_player_bullet = true
	bullet.bullet_color = glow_color
	bullet.weapon_id = weapon_id
	bullet_container.add_child(bullet)

	# Apply glow color to bullet shader (only when not using procedural draw)
	if weapon_id == "":
		var sprite = bullet.get_node_or_null("Sprite2D")
		if sprite and sprite.material and sprite.material is ShaderMaterial:
			sprite.material = sprite.material.duplicate()
			sprite.material.set_shader_parameter("glow_color", glow_color)

	# Spawn bullet trail
	var trail = Line2D.new()
	trail.set_script(preload("res://scripts/effects/bullet_trail.gd"))
	trail.setup(bullet, glow_color)
	add_child(trail)

	if sfx_shoot.stream:
		sfx_shoot.pitch_scale = randf_range(0.9, 1.1)
		sfx_shoot.play()


func _on_weapon_effect_requested(effect_type: String, data: Dictionary):
	match effect_type:
		"homing_missile":
			_spawn_homing_missile(data)
		"lightning":
			_spawn_lightning_effect(data)
		"shockwave":
			_spawn_shockwave_effect(data)


func _spawn_homing_missile(data: Dictionary):
	var missile_script = preload("res://scripts/weapons/bullets/homing_bullet.gd")
	var missile = Area2D.new()
	missile.set_script(missile_script)
	missile.position = data.pos
	missile.damage = data.dmg
	missile.pierce_count = data.pierce
	missile.speed = data.speed
	missile.turn_speed = data.turn_speed
	missile.enemy_container = enemy_container
	bullet_container.add_child(missile)

	# Spawn missile trail
	var trail = Line2D.new()
	trail.set_script(preload("res://scripts/effects/bullet_trail.gd"))
	trail.setup(missile, Color(1.0, 0.6, 0.1))
	add_child(trail)

	if sfx_shoot.stream:
		sfx_shoot.play()


func _spawn_lightning_effect(data: Dictionary):
	if !enemy_container:
		return

	var pos = data.pos
	var chains = data.chains
	var dmg = data.dmg

	# Find chain targets
	var chain_positions: Array = [pos]
	var hit_enemies: Array = []
	var current_pos = pos

	for _i in range(chains):
		var nearest = _find_nearest_enemy(current_pos, hit_enemies)
		if !nearest:
			break
		hit_enemies.append(nearest)
		chain_positions.append(nearest.global_position)
		current_pos = nearest.global_position
		if nearest.has_method("take_damage"):
			nearest.take_damage(dmg)

	# Spawn visual effect
	if chain_positions.size() >= 2:
		var effect_script = preload("res://scripts/weapons/effects/lightning_effect.gd")
		var effect = Node2D.new()
		effect.set_script(effect_script)
		effect.global_position = Vector2.ZERO
		effect.setup(chain_positions)
		add_child(effect)


func _find_nearest_enemy(from: Vector2, exclude: Array) -> Node:
	var closest: Node = null
	var closest_dist = INF
	for enemy in enemy_container.get_children():
		if !is_instance_valid(enemy):
			continue
		if exclude.has(enemy):
			continue
		if "is_alive" in enemy and !enemy.is_alive:
			continue
		var dist = from.distance_to(enemy.global_position)
		if dist < closest_dist and dist < 200.0:
			closest_dist = dist
			closest = enemy
	return closest


func _spawn_shockwave_effect(data: Dictionary):
	var effect_script = preload("res://scripts/weapons/effects/shockwave_effect.gd")
	var effect = Node2D.new()
	effect.set_script(effect_script)
	effect.global_position = data.pos
	effect.setup(data.dmg, data.radius, data.get("evolved", false))
	add_child(effect)

	for _i in range(data.get("count", 1) - 1):
		# Extra rings with slight delay
		var extra = Node2D.new()
		extra.set_script(effect_script)
		extra.global_position = data.pos
		extra.setup(data.dmg, data.radius * 0.8, data.get("evolved", false))
		add_child(extra)


func _on_weapon_added(weapon_id: String, _level: int):
	hud.update_weapons(weapon_manager)
	hud.notify_weapon_upgrade(weapon_id)
	trophy_system.on_weapon_count_changed(weapon_manager.get_weapon_count())


func _on_weapon_leveled_up(weapon_id: String, _level: int):
	hud.update_weapons(weapon_manager)
	hud.notify_weapon_upgrade(weapon_id)


func _on_spawn_enemy(enemy_scene: PackedScene, pos: Vector2, is_boss: bool):
	var enemy = enemy_scene.instantiate()
	enemy.position = pos
	enemy.enemy_killed.connect(_on_enemy_killed)
	enemy.enemy_shoot.connect(_on_enemy_shoot)

	# Give enemies that need it a reference to the player
	if enemy.has_method("set_player"):
		enemy.set_player(player)

	# Scale boss/midboss HP using centralized formulas
	if is_boss:
		enemy.max_hp = int(GameConstants.get_boss_hp(current_wave) * get_difficulty_multiplier())
		enemy.current_hp = enemy.max_hp
		enemy.points = GameConstants.get_boss_points(current_wave)
		current_boss = enemy
		boss_wave_active = true
		hud.show_boss_hp(enemy.current_hp, enemy.max_hp)

		# Connect boss_died signal if available
		if enemy.has_signal("boss_died"):
			enemy.boss_died.connect(_on_boss_died)

		# Increase music intensity for boss fight
		_set_music_pitch(1.1)

	# Scale midboss HP (apply difficulty multiplier same as boss)
	if enemy.has_signal("midboss_died"):
		enemy.max_hp = int(GameConstants.get_midboss_hp(current_wave) * get_difficulty_multiplier())
		enemy.current_hp = enemy.max_hp
		enemy.points = GameConstants.get_midboss_points(current_wave)

	enemy_container.add_child(enemy)


func _on_enemy_shoot(bullet_scene: PackedScene, pos: Vector2, dir: Vector2, dmg: int):
	var bullet = bullet_scene.instantiate()
	bullet.position = pos
	bullet.direction = dir
	bullet.damage = dmg
	bullet.is_player_bullet = false

	# Apply rank speed multiplier
	bullet.speed = bullet.speed * rank_system.get_bullet_speed_mult()

	bullet_container.add_child(bullet)


func _on_enemy_killed(points: int, pos: Vector2):
	score += points
	if points > 0:
		enemies_killed += 1
	hud.update_score(score)
	wave_spawner.on_enemy_died()
	fever_system.register_kill()
	hud.update_combo(fever_system.get_combo())
	max_combo = max(max_combo, fever_system.get_combo())

	# Trophy tracking
	trophy_system.on_enemy_killed(enemies_killed)
	trophy_system.on_combo_update(fever_system.get_combo())

	# Sound based on enemy value: explosion for tough/boss, slash for regular
	if points >= 200:
		sfx_explosion.pitch_scale = randf_range(0.85, 1.15)
		if sfx_explosion.stream:
			sfx_explosion.play()
	elif slash_sounds.size() > 0:
		sfx_enemy_die.stream = slash_sounds[randi() % slash_sounds.size()]
		sfx_enemy_die.pitch_scale = randf_range(0.85, 1.15)
		sfx_enemy_die.play()
	elif sfx_enemy_die.stream:
		sfx_enemy_die.pitch_scale = randf_range(0.85, 1.15)
		sfx_enemy_die.play()

	if points > 0:
		# Spawn explosion with color based on enemy value
		var explosion_color: Color
		if points >= 1000:
			explosion_color = Color(1.0, 0.3, 0.1)  # Red-orange for bosses
		elif points >= 200:
			explosion_color = Color(1.0, 0.4, 0.2)  # Deep orange for tough enemies
		elif points >= 100:
			explosion_color = Color(1.0, 0.6, 0.1)  # Standard orange
		else:
			explosion_color = Color(1.0, 0.7, 0.3)  # Light orange for weak enemies
		var is_boss_enemy = points >= 1000
		_spawn_explosion(pos, explosion_color, is_boss_enemy)

		_spawn_score_popup(pos, points)
		_drop_items(pos, points)
		_drop_gems(pos, points)

		# Subtle screen shake on regular kills (doesn't override larger shakes)
		if is_boss_enemy:
			screen_shake_amount = maxf(screen_shake_amount, 4.0)
		else:
			screen_shake_amount = maxf(screen_shake_amount, 0.5)

	# Update boss HP bar
	if current_boss and is_instance_valid(current_boss):
		hud.update_boss_hp(current_boss.current_hp)


func _on_boss_died(pos: Vector2):
	GloveInput.send_event("boss_killed")
	bosses_defeated += 1
	trophy_system.on_boss_defeated()
	# Bullet cancel: convert all enemy bullets to gems
	_bullet_cancel(pos)

	# Boss explosion
	var boss_exp = Node2D.new()
	boss_exp.set_script(preload("res://scripts/effects/boss_explosion.gd"))
	boss_exp.global_position = pos
	add_child(boss_exp)

	# Screen effects
	screen_shake_amount = 10.0
	_trigger_screen_flash(0.3)

	# Boss kill bonus
	var bonus = counter_system.get_boss_kill_bonus()
	score += bonus
	hud.update_score(score)
	_spawn_score_popup(pos, bonus)

	current_boss = null
	boss_wave_active = false
	hud.hide_boss_hp()

	# Reset boss pitch
	_set_music_pitch(1.0)

	# Check if this was the final boss
	if final_boss_spawned:
		game_won = true
		is_game_active = false
		_crossfade_music(music_adventure)
		var extra = _build_extra_stats()
		game_over_screen.show_victory(score, current_wave, extra)
		game_over_screen.show_weapon_build(weapon_manager)
		return

	# Advance environment on boss kill
	environment_manager.advance_environment()

	# If wave completed while boss was alive, show upgrade menu now
	if pending_wave_complete:
		pending_wave_complete = false
		_on_wave_completed()


func _on_spawn_mecha_boss(pos: Vector2) -> void:
	var mecha: Node2D = mecha_boss_scene.instantiate()
	mecha.position = Vector2.ZERO
	mecha.set_player(player)
	mecha.enemy_shoot.connect(_on_enemy_shoot)
	mecha.enemy_killed.connect(_on_enemy_killed)
	mecha.part_destroyed_signal.connect(_on_mecha_part_destroyed)
	mecha.boss_fully_defeated.connect(_on_mecha_boss_defeated)
	enemy_container.add_child(mecha)
	current_mecha_boss = mecha
	boss_wave_active = true

	# Increase music intensity for boss fight
	_set_music_pitch(1.1)

	# Show boss HP bar with total mecha HP
	hud.show_boss_hp(mecha.get_total_hp(), mecha.get_total_max_hp())


func _on_mecha_part_destroyed(_part_type: int, pos: Vector2) -> void:
	spawn_death_effect(pos)
	screen_shake_amount = 5.0
	_trigger_screen_flash(0.15)

	# Update boss HP bar
	if current_mecha_boss and is_instance_valid(current_mecha_boss):
		hud.update_boss_hp(current_mecha_boss.get_total_hp())


func _on_mecha_boss_defeated(pos: Vector2) -> void:
	GloveInput.send_event("boss_killed")
	bosses_defeated += 1
	trophy_system.on_boss_defeated()
	_bullet_cancel(pos)

	# Boss explosion
	var boss_exp := Node2D.new()
	boss_exp.set_script(preload("res://scripts/effects/boss_explosion.gd"))
	boss_exp.global_position = pos
	add_child(boss_exp)

	screen_shake_amount = 12.0
	_trigger_screen_flash(0.4)

	var bonus: int = counter_system.get_boss_kill_bonus()
	score += bonus
	hud.update_score(score)
	_spawn_score_popup(pos, bonus)

	current_mecha_boss = null
	boss_wave_active = false
	hud.hide_boss_hp()
	wave_spawner.on_enemy_died()
	environment_manager.advance_environment()

	# Reset boss pitch
	_set_music_pitch(1.0)

	# If wave completed while mecha boss was alive, show upgrade menu now
	if pending_wave_complete:
		pending_wave_complete = false
		_on_wave_completed()


func _on_environment_changed(_env_index: int, _env_id: String):
	# Screen flash for transition
	_trigger_screen_flash(0.4)

	# Apply new environment to background
	if bg_scroller:
		bg_scroller.change_environment(environment_manager.get_current_environment())

	# Toggle obstacle asteroids based on environment
	var env = environment_manager.get_current_environment()
	if env.special == "asteroids":
		_start_asteroid_spawning()
	else:
		_stop_asteroid_spawning()


var _asteroid_spawn_active: bool = false

func _start_asteroid_spawning():
	_asteroid_spawn_active = true


func _stop_asteroid_spawning():
	_asteroid_spawn_active = false


func _spawn_asteroid():
	var asteroid_script = preload("res://scripts/environment/obstacle_asteroid.gd")
	var asteroid = Area2D.new()
	asteroid.set_script(asteroid_script)
	asteroid.position = Vector2(randf_range(20, VIEWPORT_W - 20), -30)
	asteroid.asteroid_killed.connect(_on_asteroid_killed)
	enemy_container.add_child(asteroid)


func _on_asteroid_killed(pts: int, pos: Vector2):
	score += pts
	hud.update_score(score)
	spawn_death_effect(pos)
	_spawn_score_popup(pos, pts)


func _clear_player_bullets():
	for bullet in bullet_container.get_children():
		if is_instance_valid(bullet) and bullet.is_in_group("player_bullet"):
			bullet.queue_free()


func _clear_effect_weapons():
	# Remove active effect weapon nodes (lightning, shockwave, orbital, drone, flamethrower)
	for child in get_children():
		if !is_instance_valid(child):
			continue
		var script = child.get_script()
		if script == preload("res://scripts/weapons/effects/lightning_effect.gd"):
			child.queue_free()
		elif script == preload("res://scripts/weapons/effects/shockwave_effect.gd"):
			child.queue_free()
		elif script == preload("res://scripts/weapons/effects/flamethrower_effect.gd"):
			child.queue_free()


func _bullet_cancel(center_pos: Vector2):
	for bullet in bullet_container.get_children():
		if is_instance_valid(bullet) and bullet.is_in_group("enemy_bullet"):
			# Convert bullet to gem
			_spawn_gem(bullet.global_position, 0)  # SMALL gem
			bullet.queue_free()


func _on_player_hit():
	GloveInput.send_event("hit")
	hud.update_hp(player.current_hp, player.max_hp)
	screen_shake_amount = 6.0
	counter_system.on_player_death()
	rank_system.on_player_death()
	trophy_system.on_player_hit()

	# Hitstop
	hitstop_timer = 0.08
	Engine.time_scale = 0.05

	# Screen flash red
	_trigger_screen_flash(0.15, Color(1, 0.2, 0.2, 0.3))

	if hit_sounds.size() > 0:
		sfx_hit.stream = hit_sounds[randi() % hit_sounds.size()]
		sfx_hit.play()
	elif sfx_hit.stream:
		sfx_hit.play()


func _build_extra_stats() -> Dictionary:
	time_survived = 300.0 - game_timer
	var graze: int = 0
	if is_instance_valid(player) and "graze_count" in player:
		graze = player.graze_count
	return {
		"enemies_killed": enemies_killed,
		"graze_count": graze,
		"max_combo": max_combo,
		"time_survived": time_survived,
		"bosses_defeated": bosses_defeated,
		"trophies": trophy_system.get_unlocked_count(),
	}


func _on_player_died():
	GloveInput.send_event("death")
	is_game_active = false
	if bg_scroller:
		bg_scroller.is_active = false
	_set_music_pitch(1.0)
	_crossfade_music(music_adventure)
	if sfx_game_over.stream:
		sfx_game_over.play()
	# Delay before showing game over screen for dramatic effect
	var delay_tween = create_tween()
	delay_tween.tween_interval(1.2)
	delay_tween.tween_callback(func():
		var extra = _build_extra_stats()
		game_over_screen.show_game_over(score, current_wave, extra)
		game_over_screen.show_weapon_build(weapon_manager)
	)


func _on_bomb_activated():
	GloveInput.send_event("bomb")
	# Convert all enemy bullets to gems
	_bullet_cancel(player.global_position)
	counter_system.on_bomb_used()
	rank_system.on_bomb_used()
	hud.update_bombs(player.bomb_count)

	# Screen flash white
	_trigger_screen_flash(0.2)
	screen_shake_amount = 8.0

	# Bomb activation sound
	if sfx_bomb.stream:
		sfx_bomb.play()


func _on_gem_collected(gem_value: int):
	counter_system.add_gems(gem_value)
	score += gem_value * 10
	hud.update_score(score)
	if sfx_coin.stream:
		sfx_coin.pitch_scale = randf_range(0.95, 1.05)
		sfx_coin.play()


func _on_power_item_collected():
	player.add_power()
	hud.update_power(player.power_level)
	hud.update_hp(player.current_hp, player.max_hp)
	if sfx_powerup.stream:
		sfx_powerup.play()


func _on_bomb_item_collected():
	player.add_bomb()
	hud.update_bombs(player.bomb_count)
	if sfx_powerup.stream:
		sfx_powerup.play()


func _on_buff_item_collected(buff_type: String):
	if sfx_powerup.stream:
		sfx_powerup.play()
	hud.update_hp(player.current_hp, player.max_hp)


func _on_counter_updated(stage: int, total: int, color_str: String):
	hud.update_counter(stage, total, color_str)


func _on_resume():
	is_game_active = true


func _on_restart():
	Engine.time_scale = 1.0
	for child in bullet_container.get_children():
		child.queue_free()
	for child in enemy_container.get_children():
		child.queue_free()
	for child in item_container.get_children():
		child.queue_free()
	# Clean up bullet trails, trophy popups, and other transient effects added to game node
	for child in get_children():
		if child is Line2D and child.has_method("setup"):
			child.queue_free()
		elif child.get_script() == preload("res://scripts/ui/trophy_popup.gd"):
			child.queue_free()
		elif child.get_script() == preload("res://scripts/effects/explosion.gd"):
			child.queue_free()
		elif child.get_script() == preload("res://scripts/effects/score_popup.gd"):
			child.queue_free()
		elif child.get_script() == preload("res://scripts/effects/boss_explosion.gd"):
			child.queue_free()
		elif child.get_script() == preload("res://scripts/ui/wave_announce.gd"):
			child.queue_free()
	current_boss = null
	current_mecha_boss = null
	boss_wave_active = false
	pending_wave_complete = false
	_asteroid_spawn_active = false
	_asteroid_timer = 0.0
	start_game()


func _on_quit():
	Engine.time_scale = 1.0
	# Fade to black before returning to title
	var fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.z_index = 200
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fade_rect)
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(fade_rect, "color:a", 1.0, 0.3)
	tween.tween_callback(func():
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	)


func spawn_death_effect(pos: Vector2):
	_spawn_explosion(pos)


func _spawn_explosion(pos: Vector2, color: Color = Color(1.0, 0.6, 0.1), is_boss: bool = false):
	var explosion = Node2D.new()
	explosion.set_script(preload("res://scripts/effects/explosion.gd"))
	explosion.global_position = pos
	var size_mult = 2.5 if is_boss else 1.0
	explosion.setup(color, size_mult)
	add_child(explosion)


func _spawn_score_popup(pos: Vector2, points: int):
	var popup = Node2D.new()
	popup.set_script(preload("res://scripts/effects/score_popup.gd"))
	popup.global_position = pos
	var big = points >= 500
	var col = Color.YELLOW if big else Color.WHITE
	popup.setup(str(points), col, big)
	add_child(popup)


func _drop_gems(pos: Vector2, points: int):
	var gem_count = 1
	if points >= 200:
		gem_count = 3
	elif points >= 100:
		gem_count = 2

	# Counter color bonus
	if counter_system.should_drop_more_gems(player.is_focused):
		gem_count += 2

	# Fever mode: double gems
	gem_count = int(gem_count * fever_system.get_gem_multiplier())

	for i in range(gem_count):
		var offset = Vector2(randf_range(-12, 12), randf_range(-12, 12))
		var gem_type = 1 if points >= 500 else 0  # LARGE for high value, SMALL otherwise
		_spawn_gem(pos + offset, gem_type)


func _spawn_gem(pos: Vector2, gem_type: int):
	var gem = Area2D.new()
	gem.set_script(preload("res://scripts/items/gem.gd"))
	gem.global_position = pos
	gem.setup(gem_type, counter_system.get_color(), player)
	item_container.add_child(gem)


func _drop_items(pos: Vector2, points: int):
	# Boss kills always drop guaranteed items
	if points >= 1000:
		var boss_drops: Array[int] = DropTable.roll_boss_drops()
		for i in range(boss_drops.size()):
			var offset := Vector2(i * 10 - 10, 0)
			_spawn_item(pos + offset, _drop_type_to_item_type(boss_drops[i]))
		return

	# Regular enemies: 25% chance to drop an item (via DropTable)
	var drop: int = DropTable.roll_enemy_drop()
	if drop != DropTable.DropType.NONE:
		_spawn_item(pos, _drop_type_to_item_type(drop))


## Converts a DropTable.DropType to a power_item.gd ItemType integer.
func _drop_type_to_item_type(drop_type: int) -> int:
	match drop_type:
		DropTable.DropType.POWER: return 0
		DropTable.DropType.BOMB: return 1
		DropTable.DropType.HEALTH: return 2
		DropTable.DropType.ATTACK_SPEED_BOOST: return 3
		DropTable.DropType.SHIELD: return 4
		DropTable.DropType.INVINCIBILITY: return 5
		_: return 0


func _spawn_item(pos: Vector2, item_type: int):
	var item = Area2D.new()
	item.set_script(preload("res://scripts/items/power_item.gd"))
	item.global_position = pos
	item.setup(item_type, player)
	item_container.add_child(item)


func _trigger_screen_flash(duration: float, col: Color = Color(1, 1, 1, 0.5)):
	if screen_flash:
		screen_flash.color = col
		flash_timer = duration


var _asteroid_timer: float = 0.0

func _process(delta: float):
	# Music crossfade
	_process_music_fade(delta)

	# Hitstop recovery
	if hitstop_timer > 0:
		hitstop_timer -= delta / max(Engine.time_scale, 0.01)
		if hitstop_timer <= 0:
			Engine.time_scale = 1.0

	# Screen shake
	if screen_shake_amount > 0:
		camera.offset = Vector2(
			randf_range(-screen_shake_amount, screen_shake_amount),
			randf_range(-screen_shake_amount, screen_shake_amount)
		)
		screen_shake_amount = lerp(screen_shake_amount, 0.0, 10.0 * delta)
		if screen_shake_amount < 0.1:
			screen_shake_amount = 0.0
			camera.offset = Vector2.ZERO

	# Screen flash fade
	if flash_timer > 0:
		flash_timer -= delta
		if screen_flash:
			screen_flash.color.a = max(0, flash_timer * 3.0)
		if flash_timer <= 0 and screen_flash:
			screen_flash.color.a = 0

	# Update HUD graze count
	if player and player.is_alive:
		hud.update_graze(player.graze_count)
		trophy_system.on_graze_update(player.graze_count)

	# Trophy system update
	if is_game_active:
		trophy_system.update(delta)

	# Game timer countdown
	if is_game_active and game_timer > 0 and not final_boss_spawned:
		game_timer -= delta
		hud.update_timer(game_timer)
		if game_timer <= 0:
			game_timer = 0.0
			_spawn_final_boss()

	# Asteroid spawning
	if _asteroid_spawn_active and is_game_active:
		_asteroid_timer += delta
		if _asteroid_timer >= 2.0:
			_asteroid_timer = 0.0
			_spawn_asteroid()


func _spawn_final_boss():
	final_boss_spawned = true
	# Clear all existing enemies
	for child in enemy_container.get_children():
		if is_instance_valid(child) and child != current_boss:
			child.queue_free()
	_bullet_cancel(Vector2(VIEWPORT_W / 2.0, VIEWPORT_H / 2.0))

	# Wave announce
	var announce = Node2D.new()
	announce.set_script(preload("res://scripts/ui/wave_announce.gd"))
	announce.setup("FINAL BOSS", true)
	add_child(announce)

	# Spawn the final boss using enemy_boss scene with scaled HP
	var boss_scene: PackedScene = preload("res://scenes/enemies/enemy_boss.tscn")
	var boss = boss_scene.instantiate()
	boss.position = Vector2(VIEWPORT_W / 2.0, -20)
	var final_hp: int = int(150 * get_difficulty_multiplier())
	boss.max_hp = final_hp
	boss.current_hp = final_hp
	boss.points = 5000
	boss.enemy_killed.connect(_on_enemy_killed)
	boss.enemy_shoot.connect(_on_enemy_shoot)
	if boss.has_method("set_player"):
		boss.set_player(player)
	if boss.has_signal("boss_died"):
		boss.boss_died.connect(_on_boss_died)
	current_boss = boss
	boss_wave_active = true
	enemy_container.add_child(boss)
	hud.show_boss_hp(final_hp, final_hp)

	# Increase music intensity for final boss
	_set_music_pitch(1.1)

	screen_shake_amount = 8.0
	_trigger_screen_flash(0.4)


func _on_fever_started():
	trophy_system.on_fever_started()
	_trigger_screen_flash(0.25, Color(1, 0.8, 0, 0.4))
	screen_shake_amount = 3.0
	hud.show_fever()


func _on_fever_ended():
	_trigger_screen_flash(0.15, Color(0.5, 0.5, 1.0, 0.3))
	hud.hide_fever()


func _on_trophy_unlocked(trophy_id: String, trophy_name: String, bonus_text: String):
	# Apply bonus
	var trophy = trophy_system.TROPHIES[trophy_id]
	match trophy.bonus:
		"score":
			score += trophy.bonus_value
			hud.update_score(score)
		"heal":
			if is_instance_valid(player):
				player.current_hp = min(player.current_hp + trophy.bonus_value, player.max_hp)
				hud.update_hp(player.current_hp, player.max_hp)
		"damage":
			if is_instance_valid(player) and "damage" in player:
				player.damage += trophy.bonus_value

	# Show popup
	var popup = Node2D.new()
	popup.set_script(preload("res://scripts/ui/trophy_popup.gd"))
	popup.global_position = Vector2(160, 60)  # Top center
	popup.setup(trophy_name, bonus_text)
	add_child(popup)
