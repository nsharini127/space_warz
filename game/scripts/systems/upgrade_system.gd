extends Node

# Upgrade definitions
const UPGRADES = [
	{
		"type": "attack_speed",
		"name": "Attack Speed",
		"description": "Increase fire rate",
		"icon": "res://assets/sprites/ui/icon_attack.png",
		"max_level": 8,
	},
	{
		"type": "damage",
		"name": "Damage Up",
		"description": "+1 projectile damage",
		"icon": "res://assets/sprites/ui/icon_fireball.png",
		"max_level": 5,
	},
	{
		"type": "bomb_stock",
		"name": "Bomb Stock",
		"description": "+1 bomb capacity",
		"icon": "res://assets/sprites/ui/icon_multishot.png",
		"max_level": 3,
	},
	{
		"type": "speed",
		"name": "Speed Up",
		"description": "Move faster",
		"icon": "res://assets/sprites/ui/icon_speed.png",
		"max_level": 5,
	},
	{
		"type": "max_hp",
		"name": "Max HP Up",
		"description": "+1 maximum health",
		"icon": "res://assets/sprites/ui/icon_defense.png",
		"max_level": 5,
	},
	{
		"type": "heal",
		"name": "Heal",
		"description": "Restore all HP",
		"icon": "res://assets/sprites/ui/icon_heal.png",
		"max_level": 99,
	},
	{
		"type": "pierce",
		"name": "Pierce",
		"description": "Projectiles pass through enemies",
		"icon": "res://assets/sprites/ui/icon_pierce.png",
		"max_level": 3,
	},
	{
		"type": "gem_attract",
		"name": "Gem Magnet",
		"description": "Wider gem attraction radius",
		"icon": "res://assets/sprites/ui/icon_heal.png",
		"max_level": 3,
	},
]

var upgrade_levels: Dictionary = {}


func _ready():
	reset()


func reset():
	upgrade_levels.clear()
	for u in UPGRADES:
		upgrade_levels[u.type] = 0


func get_random_upgrades(count: int = 3) -> Array:
	var available: Array = []
	for u in UPGRADES:
		if upgrade_levels[u.type] < u.max_level:
			available.append(u.duplicate())

	available.shuffle()
	return available.slice(0, min(count, available.size()))


func apply_upgrade(upgrade_type: String):
	upgrade_levels[upgrade_type] = upgrade_levels.get(upgrade_type, 0) + 1
