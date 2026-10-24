class_name BulletPattern
extends RefCounted


enum PatternType {
	RADIAL,
	SPIRAL,
	AIMED,
	AIMED_FAN,
	RING,
	CURTAIN,
	WAVE_SINE
}

var pattern_type: PatternType = PatternType.RADIAL
var bullet_count: int = 8
var bullet_speed: float = 80.0
var angle_offset: float = 0.0
var spread: float = TAU
var spin_speed: float = 0.0
var aim_at_player: bool = false
var wave_amplitude: float = 30.0
var wave_frequency: float = 3.0
var bullet_damage: int = 1


static func create_radial(count: int, spd: float, offset: float = 0.0) -> BulletPattern:
	var p = BulletPattern.new()
	p.pattern_type = PatternType.RADIAL
	p.bullet_count = count
	p.bullet_speed = spd
	p.angle_offset = offset
	return p


static func create_spiral(count: int, spd: float, spin: float) -> BulletPattern:
	var p = BulletPattern.new()
	p.pattern_type = PatternType.SPIRAL
	p.bullet_count = count
	p.bullet_speed = spd
	p.spin_speed = spin
	return p


static func create_aimed(spd: float) -> BulletPattern:
	var p = BulletPattern.new()
	p.pattern_type = PatternType.AIMED
	p.bullet_count = 1
	p.bullet_speed = spd
	p.aim_at_player = true
	return p


static func create_aimed_fan(count: int, spd: float, fan_spread: float) -> BulletPattern:
	var p = BulletPattern.new()
	p.pattern_type = PatternType.AIMED_FAN
	p.bullet_count = count
	p.bullet_speed = spd
	p.spread = fan_spread
	p.aim_at_player = true
	return p


static func create_ring(count: int, spd: float) -> BulletPattern:
	var p = BulletPattern.new()
	p.pattern_type = PatternType.RING
	p.bullet_count = count
	p.bullet_speed = spd
	return p


static func create_curtain(count: int, spd: float, curtain_spread: float) -> BulletPattern:
	var p = BulletPattern.new()
	p.pattern_type = PatternType.CURTAIN
	p.bullet_count = count
	p.bullet_speed = spd
	p.spread = curtain_spread
	return p


static func create_wave_sine(count: int, spd: float, amp: float, freq: float) -> BulletPattern:
	var p = BulletPattern.new()
	p.pattern_type = PatternType.WAVE_SINE
	p.bullet_count = count
	p.bullet_speed = spd
	p.wave_amplitude = amp
	p.wave_frequency = freq
	return p


func get_directions(source_pos: Vector2, player_pos: Vector2) -> Array:
	var directions: Array = []

	match pattern_type:
		PatternType.RADIAL:
			for i in range(bullet_count):
				var angle = angle_offset + (TAU / bullet_count) * i
				directions.append(Vector2(cos(angle), sin(angle)))

		PatternType.SPIRAL:
			for i in range(bullet_count):
				var angle = angle_offset + (TAU / bullet_count) * i
				directions.append(Vector2(cos(angle), sin(angle)))

		PatternType.AIMED:
			var dir = (player_pos - source_pos).normalized()
			directions.append(dir)

		PatternType.AIMED_FAN:
			var base_angle = (player_pos - source_pos).angle()
			var start = base_angle - spread / 2.0
			for i in range(bullet_count):
				var angle: float
				if bullet_count > 1:
					angle = start + (spread / (bullet_count - 1)) * i
				else:
					angle = base_angle
				directions.append(Vector2(cos(angle), sin(angle)))

		PatternType.RING:
			for i in range(bullet_count):
				var angle = angle_offset + (TAU / bullet_count) * i
				directions.append(Vector2(cos(angle), sin(angle)))

		PatternType.CURTAIN:
			var base_angle = PI / 2.0  # Down
			var start = base_angle - spread / 2.0
			for i in range(bullet_count):
				var angle: float
				if bullet_count > 1:
					angle = start + (spread / (bullet_count - 1)) * i
				else:
					angle = base_angle
				directions.append(Vector2(cos(angle), sin(angle)))

		PatternType.WAVE_SINE:
			for i in range(bullet_count):
				var angle = angle_offset + (spread / max(bullet_count - 1, 1)) * i
				directions.append(Vector2(cos(angle), sin(angle)))

	return directions
