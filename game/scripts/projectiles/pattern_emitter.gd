class_name PatternEmitter
extends Node


signal emit_bullet(bullet_scene: PackedScene, pos: Vector2, dir: Vector2, dmg: int, spd: float, color: Color, is_wave: bool, wave_amp: float, wave_freq: float)

var bullet_scene: PackedScene = preload("res://scenes/projectiles/bullet_enemy.tscn")
var patterns: Array = []  # Array of {pattern: BulletPattern, interval: float, timer: float}
var player_ref: CharacterBody2D = null
var spin_accumulator: float = 0.0
var active: bool = true


func add_pattern(pattern: BulletPattern, interval: float):
	patterns.append({
		"pattern": pattern,
		"interval": interval,
		"timer": interval * 0.5,  # Start halfway to stagger
	})


func clear_patterns():
	patterns.clear()
	spin_accumulator = 0.0


func set_player(p: CharacterBody2D):
	player_ref = p


func _process(delta: float):
	if !active:
		return

	for p_data in patterns:
		p_data.timer -= delta
		if p_data.timer <= 0:
			p_data.timer = p_data.interval
			fire_pattern(p_data.pattern)

	# Accumulate spin for spiral patterns
	for p_data in patterns:
		var pattern: BulletPattern = p_data.pattern
		if pattern.pattern_type == BulletPattern.PatternType.SPIRAL:
			pattern.angle_offset += pattern.spin_speed * delta


func fire_pattern(pattern: BulletPattern):
	var source_pos = get_parent().global_position if get_parent() else Vector2.ZERO
	var player_pos = player_ref.global_position if player_ref and is_instance_valid(player_ref) else Vector2(160, 384)

	var directions = pattern.get_directions(source_pos, player_pos)
	var is_wave = pattern.pattern_type == BulletPattern.PatternType.WAVE_SINE

	for dir in directions:
		emit_bullet.emit(
			bullet_scene,
			source_pos,
			dir,
			pattern.bullet_damage,
			pattern.bullet_speed,
			Color.WHITE,
			is_wave,
			pattern.wave_amplitude,
			pattern.wave_frequency
		)
