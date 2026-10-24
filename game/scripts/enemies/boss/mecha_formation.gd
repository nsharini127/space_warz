## Value Object: Defines positional layouts for the mecha boss parts.
## Calculates entry positions (V formation), robot formation, and combination target.
class_name MechaFormation

const VIEWPORT_W: float = 320.0
const VIEWPORT_H: float = 480.0
const CENTER_X: float = VIEWPORT_W / 2.0

## Vertical offset from top of screen where the robot formation stops.
const FORMATION_Y: float = 90.0

## Robot formation offsets relative to TORSO center position.
## Layout:
##       [HEAD]
##   [ARM_L] [ARM_R]
##       [TORSO]  (center, offset 0,0)
##   [LEG_L] [LEG_R]
const ROBOT_OFFSETS: Dictionary = {
	BossPart.PartType.HEAD:  Vector2(0, -50),
	BossPart.PartType.ARM_L: Vector2(-40, -25),
	BossPart.PartType.ARM_R: Vector2(40, -25),
	BossPart.PartType.TORSO: Vector2(0, 0),
	BossPart.PartType.LEG_L: Vector2(-30, 30),
	BossPart.PartType.LEG_R: Vector2(30, 30),
}

## V-formation entry positions (off-screen, moving down).
## Parts enter in a V shape centered at the top.
const ENTRY_OFFSETS: Dictionary = {
	BossPart.PartType.HEAD:  Vector2(0, -30),
	BossPart.PartType.ARM_L: Vector2(-35, -15),
	BossPart.PartType.ARM_R: Vector2(35, -15),
	BossPart.PartType.TORSO: Vector2(0, 0),
	BossPart.PartType.LEG_L: Vector2(-25, 15),
	BossPart.PartType.LEG_R: Vector2(25, 15),
}


## Returns the entry position for a given part type (off-screen top).
static func get_entry_position(part_type: int) -> Vector2:
	var offset: Vector2 = ENTRY_OFFSETS.get(part_type, Vector2.ZERO)
	return Vector2(CENTER_X + offset.x, -60 + offset.y)


## Returns the robot formation position for a given part type.
static func get_formation_position(part_type: int) -> Vector2:
	var offset: Vector2 = ROBOT_OFFSETS.get(part_type, Vector2.ZERO)
	return Vector2(CENTER_X + offset.x, FORMATION_Y + offset.y)


## Returns the combination target position (all parts merge to center).
static func get_combination_position() -> Vector2:
	return Vector2(CENTER_X, FORMATION_Y)


## Calculates the strafing offset for group movement.
## The entire formation moves left/right as a unit.
static func get_strafe_offset(time: float, amplitude: float = 40.0) -> float:
	return sin(time * 0.8) * amplitude


## Lerps a part toward its target position at the given speed.
static func move_toward_target(
	current_pos: Vector2,
	target_pos: Vector2,
	delta: float,
	speed: float = 80.0
) -> Vector2:
	return current_pos.move_toward(target_pos, speed * delta)


## Returns true when a part is close enough to its target position.
static func is_at_target(current_pos: Vector2, target_pos: Vector2, threshold: float = 2.0) -> bool:
	return current_pos.distance_to(target_pos) < threshold
