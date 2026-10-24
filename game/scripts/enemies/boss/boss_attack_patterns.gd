## Service: Reusable boss attack patterns.
## Provides static methods that return arrays of bullet data dictionaries.
## Each dictionary contains: { position: Vector2, direction: Vector2, damage: int }
class_name BossAttackPatterns


## Fires bullets in a radial burst pattern with optional spin offset.
static func radial_burst(
	origin: Vector2,
	bullet_count: int,
	damage: int,
	spin_offset: float = 0.0,
	radius: float = 16.0
) -> Array[Dictionary]:
	var bullets: Array[Dictionary] = []
	for i in range(bullet_count):
		var angle: float = spin_offset + (TAU / float(bullet_count)) * i
		var dir := Vector2(cos(angle), sin(angle))
		bullets.append({
			"position": origin + dir * radius,
			"direction": dir,
			"damage": damage,
		})
	return bullets


## Fires an aimed fan of bullets toward a target position.
static func aimed_fan(
	origin: Vector2,
	target: Vector2,
	bullet_count: int,
	spread_angle_deg: float,
	damage: int
) -> Array[Dictionary]:
	var bullets: Array[Dictionary] = []
	var aim_angle: float = (target - origin).angle()
	var half: int = bullet_count / 2
	for i in range(bullet_count):
		var offset: float = (i - half) * deg_to_rad(spread_angle_deg)
		var dir := Vector2(cos(aim_angle + offset), sin(aim_angle + offset))
		bullets.append({
			"position": origin,
			"direction": dir,
			"damage": damage,
		})
	return bullets


## Fires a spiral pattern with multiple arms.
static func spiral(
	origin: Vector2,
	arm_count: int,
	bullets_per_arm: int,
	spin_offset: float,
	arm_spread_deg: float,
	damage: int,
	radius: float = 12.0
) -> Array[Dictionary]:
	var bullets: Array[Dictionary] = []
	for arm in range(arm_count):
		var base: float = spin_offset + arm * (TAU / float(arm_count))
		for i in range(bullets_per_arm):
			var angle: float = base + i * deg_to_rad(arm_spread_deg)
			var dir := Vector2(cos(angle), sin(angle))
			bullets.append({
				"position": origin + dir * radius,
				"direction": dir,
				"damage": damage,
			})
	return bullets


## Fires a lateral spray in a given direction (left or right).
static func lateral_spray(
	origin: Vector2,
	direction: Vector2,
	bullet_count: int,
	spread_angle_deg: float,
	damage: int
) -> Array[Dictionary]:
	var bullets: Array[Dictionary] = []
	var base_angle: float = direction.angle()
	var half: int = bullet_count / 2
	for i in range(bullet_count):
		var offset: float = (i - half) * deg_to_rad(spread_angle_deg)
		var dir := Vector2(cos(base_angle + offset), sin(base_angle + offset))
		bullets.append({
			"position": origin,
			"direction": dir,
			"damage": damage,
		})
	return bullets


## Combined pattern for the merged mecha boss form.
## Intensity 1.0 = full attacks, lower = fewer bullets.
static func combined_pattern(
	origin: Vector2,
	target: Vector2,
	intensity: float,
	damage: int,
	spin_offset: float = 0.0
) -> Array[Dictionary]:
	var bullets: Array[Dictionary] = []
	# Radial component
	var radial_count: int = int(6 * intensity)
	bullets.append_array(radial_burst(origin, max(radial_count, 3), damage, spin_offset))
	# Aimed component
	var aimed_count: int = int(4 * intensity)
	bullets.append_array(aimed_fan(origin, target, max(aimed_count, 2), 12.0, damage))
	return bullets
