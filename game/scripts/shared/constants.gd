## Shared constants used across the entire project.
## Centralizes magic numbers so changes propagate everywhere.
class_name GameConstants

## Viewport dimensions.
const VIEWPORT_W: int = 320
const VIEWPORT_H: int = 480

## Collision layers (bit values).
const LAYER_PLAYER: int = 1
const LAYER_ENEMY: int = 2
const LAYER_PLAYER_BULLET: int = 4
const LAYER_ENEMY_BULLET: int = 8
const LAYER_PICKUP: int = 16

## Spawn positions.
const SPAWN_Y: float = -20.0
const PLAYER_START: Vector2 = Vector2(VIEWPORT_W / 2, VIEWPORT_H * 0.8)

## Boss HP scaling formulas (base values, game.gd applies difficulty multiplier).
## Boss: 25 + wave * 5  (wave 5 = 50 HP base)
## Midboss: 15 + wave * 3  (wave 6 = 33 HP base)
static func get_boss_hp(wave: int) -> int:
	return 25 + wave * 5

static func get_midboss_hp(wave: int) -> int:
	return 15 + wave * 3

## Boss score scaling.
static func get_boss_points(wave: int) -> int:
	return 1000 + wave * 200

static func get_midboss_points(wave: int) -> int:
	return 500 + wave * 100
