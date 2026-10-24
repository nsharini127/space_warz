extends RefCounted
class_name WeaponRegistry

# All 10 weapon definitions (pure data)

const WEAPONS = {
	"front_laser": {
		"id": "front_laser",
		"display_name": "Front Laser",
		"description": "Straight shots forward. +streams per level.",
		"category": "weapon",
		"max_level": 5,
		"glow_color": Color(0, 0.8, 1.0),
		"icon": "res://assets/sprites/ui/icon_attack.png",
		"base_damage": [1, 2, 3, 4, 6],
		"fire_interval": [0.22, 0.19, 0.17, 0.15, 0.12],
		"projectile_count": [1, 2, 3, 4, 5],
		"bullet_speed": 280.0,
		"evolves_to": "mega_laser",
		"weapon_type": "projectile",
	},
	"spread_shot": {
		"id": "spread_shot",
		"display_name": "Spread Shot",
		"description": "Fan of bullets in an arc.",
		"category": "weapon",
		"max_level": 5,
		"glow_color": Color(1.0, 0.9, 0.2),
		"icon": "res://assets/sprites/ui/icon_multishot.png",
		"base_damage": [2, 2, 3, 3, 4],
		"fire_interval": [0.35, 0.32, 0.28, 0.25, 0.20],
		"projectile_count": [3, 4, 5, 6, 8],
		"bullet_speed": 230.0,
		"evolves_to": "bullet_storm",
		"weapon_type": "projectile",
	},
	"homing_missile": {
		"id": "homing_missile",
		"display_name": "Homing Missiles",
		"description": "Missiles that track enemies.",
		"category": "weapon",
		"max_level": 5,
		"glow_color": Color(1.0, 0.4, 0.1),
		"icon": "res://assets/sprites/ui/icon_fireball.png",
		"base_damage": [2, 3, 4, 5, 7],
		"fire_interval": [0.80, 0.70, 0.60, 0.50, 0.40],
		"projectile_count": [1, 1, 2, 2, 3],
		"bullet_speed": 150.0,
		"evolves_to": "swarm_rockets",
		"weapon_type": "projectile",
	},
	"orbital_shield": {
		"id": "orbital_shield",
		"display_name": "Orbital Shield",
		"description": "Orbs orbiting the player deal contact damage.",
		"category": "weapon",
		"max_level": 5,
		"glow_color": Color(0.7, 0.3, 1.0),
		"icon": "res://assets/sprites/ui/icon_defense.png",
		"base_damage": [1, 2, 2, 3, 4],
		"fire_interval": [0.0, 0.0, 0.0, 0.0, 0.0],
		"projectile_count": [2, 3, 4, 5, 6],
		"bullet_speed": 0.0,
		"evolves_to": "plasma_ring",
		"weapon_type": "effect",
	},
	"rear_cannon": {
		"id": "rear_cannon",
		"display_name": "Rear Cannon",
		"description": "Fires downward behind you.",
		"category": "weapon",
		"max_level": 5,
		"glow_color": Color(1.0, 0.2, 0.2),
		"icon": "res://assets/sprites/ui/icon_attack.png",
		"base_damage": [2, 3, 4, 5, 7],
		"fire_interval": [0.40, 0.35, 0.30, 0.25, 0.20],
		"projectile_count": [1, 1, 2, 2, 3],
		"bullet_speed": 220.0,
		"evolves_to": "dual_turret",
		"weapon_type": "projectile",
	},
	"lightning": {
		"id": "lightning",
		"display_name": "Lightning",
		"description": "Chain lightning between enemies.",
		"category": "weapon",
		"max_level": 5,
		"glow_color": Color(0.3, 0.6, 1.0),
		"icon": "res://assets/sprites/ui/icon_fireball.png",
		"base_damage": [1, 2, 2, 3, 4],
		"fire_interval": [0.60, 0.55, 0.48, 0.42, 0.35],
		"projectile_count": [2, 3, 4, 5, 6],
		"bullet_speed": 0.0,
		"evolves_to": "thunder_storm",
		"weapon_type": "effect",
	},
	"side_cannons": {
		"id": "side_cannons",
		"display_name": "Side Cannons",
		"description": "Fires left and right simultaneously.",
		"category": "weapon",
		"max_level": 5,
		"glow_color": Color(0.2, 1.0, 0.3),
		"icon": "res://assets/sprites/ui/icon_multishot.png",
		"base_damage": [1, 2, 2, 3, 4],
		"fire_interval": [0.35, 0.30, 0.27, 0.23, 0.18],
		"projectile_count": [2, 2, 4, 4, 6],
		"bullet_speed": 200.0,
		"evolves_to": "cross_fire",
		"weapon_type": "projectile",
	},
	"drone": {
		"id": "drone",
		"display_name": "Combat Drone",
		"description": "An orbiting drone that fires independently.",
		"category": "weapon",
		"max_level": 5,
		"glow_color": Color(0.5, 0.7, 1.0),
		"icon": "res://assets/sprites/ui/icon_multishot.png",
		"base_damage": [1, 1, 2, 2, 3],
		"fire_interval": [0.30, 0.27, 0.24, 0.20, 0.16],
		"projectile_count": [1, 1, 2, 2, 3],
		"bullet_speed": 260.0,
		"evolves_to": "drone_swarm",
		"weapon_type": "effect",
	},
	"shockwave": {
		"id": "shockwave",
		"display_name": "Shockwave",
		"description": "Expanding ring damages all nearby enemies.",
		"category": "weapon",
		"max_level": 5,
		"glow_color": Color(0.7, 0.8, 1.0),
		"icon": "res://assets/sprites/ui/icon_defense.png",
		"base_damage": [1, 2, 3, 4, 6],
		"fire_interval": [1.20, 1.05, 0.90, 0.75, 0.60],
		"projectile_count": [1, 1, 1, 1, 2],
		"bullet_speed": 0.0,
		"evolves_to": "nova_blast",
		"weapon_type": "effect",
	},
}

# Evolution definitions
const EVOLUTIONS = {
	"mega_laser": {
		"id": "mega_laser",
		"display_name": "Mega Laser",
		"description": "Continuous beam of destruction.",
		"base_from": "front_laser",
	},
	"bullet_storm": {
		"id": "bullet_storm",
		"display_name": "Bullet Storm",
		"description": "360-degree bullet rain.",
		"base_from": "spread_shot",
	},
	"swarm_rockets": {
		"id": "swarm_rockets",
		"display_name": "Swarm Rockets",
		"description": "A swarm of homing rockets.",
		"base_from": "homing_missile",
	},
	"plasma_ring": {
		"id": "plasma_ring",
		"display_name": "Plasma Ring",
		"description": "Deadly plasma ring surrounds you.",
		"base_from": "orbital_shield",
	},
	"dual_turret": {
		"id": "dual_turret",
		"display_name": "Dual Turret",
		"description": "Fires in all directions.",
		"base_from": "rear_cannon",
	},
	"thunder_storm": {
		"id": "thunder_storm",
		"display_name": "Thunder Storm",
		"description": "Lightning strikes everywhere.",
		"base_from": "lightning",
	},
	"cross_fire": {
		"id": "cross_fire",
		"display_name": "Cross Fire",
		"description": "Fires in all 4 directions.",
		"base_from": "side_cannons",
	},
	"drone_swarm": {
		"id": "drone_swarm",
		"display_name": "Drone Swarm",
		"description": "Multiple drones surround you.",
		"base_from": "drone",
	},
	"nova_blast": {
		"id": "nova_blast",
		"display_name": "Nova Blast",
		"description": "Devastating expanding nova.",
		"base_from": "shockwave",
	},
}


static func get_weapon(id: String) -> Dictionary:
	if WEAPONS.has(id):
		return WEAPONS[id].duplicate(true)
	return {}


static func get_all_weapon_ids() -> Array:
	return WEAPONS.keys()


static func get_damage_at_level(weapon_data: Dictionary, level: int) -> int:
	var idx = clampi(level - 1, 0, weapon_data.base_damage.size() - 1)
	return weapon_data.base_damage[idx]


static func get_fire_interval_at_level(weapon_data: Dictionary, level: int) -> float:
	var idx = clampi(level - 1, 0, weapon_data.fire_interval.size() - 1)
	return weapon_data.fire_interval[idx]


static func get_projectile_count_at_level(weapon_data: Dictionary, level: int) -> int:
	var idx = clampi(level - 1, 0, weapon_data.projectile_count.size() - 1)
	return weapon_data.projectile_count[idx]
