extends Node


signal environment_changed(env_index: int, env_id: String)

const VIEWPORT_W = 320
const VIEWPORT_H = 480

var current_index: int = 0

const ENVIRONMENTS = [
	{
		"id": "deep_space",
		"display_name": "Deep Space",
		# Layer images
		"bg_image": "res://assets/backgrounds/space/foozle/bg_void_01.png",
		"bg_tint": Color(1, 1, 1),
		"overlay_image": "res://assets/backgrounds/space/foozle/bg_shadows_01.png",
		"overlay_tint": Color(0.6, 0.6, 1.0, 0.4),
		"stars_image": "res://assets/backgrounds/space/foozle/bg_stars_01.png",
		"stars_tint": Color(0.7, 0.7, 1.0, 0.7),
		"stars_fg_image": "res://assets/backgrounds/space/foozle/bg_stars_fg_01.png",
		"stars_fg_tint": Color(1.0, 1.0, 1.0, 0.9),
		# Particles & effects
		"particle_color": Color(0.5, 0.5, 0.8, 0.25),
		"vignette_color": Color(0.0, 0.0, 0.08, 1.0),
		# Decorations
		"decoration_types": [
			"nebula_small", "nebula_large", "bigstar",
			"star_cluster", "dust_cloud",
		],
		"scroll_speed_mult": 1.0,
		"special": "",
	},
	{
		"id": "nebula_field",
		"display_name": "Nebula Field",
		"bg_image": "res://assets/backgrounds/space/foozle/bg_void_02.png",
		"bg_tint": Color(1, 1, 1),
		"overlay_image": "res://assets/backgrounds/space/foozle/bg_shadows_01.png",
		"overlay_tint": Color(1.0, 0.5, 0.8, 0.5),
		"stars_image": "res://assets/backgrounds/space/foozle/bg_stars_02.png",
		"stars_tint": Color(1.0, 0.7, 1.0, 0.7),
		"stars_fg_image": "res://assets/backgrounds/space/foozle/bg_stars_fg_01.png",
		"stars_fg_tint": Color(1.0, 0.8, 1.0, 0.9),
		"particle_color": Color(0.8, 0.3, 0.6, 0.3),
		"vignette_color": Color(0.05, 0.0, 0.08, 1.0),
		"decoration_types": [
			"nebula_large", "nebula_large", "bigstar",
			"star_cluster", "nebula_small",
		],
		"scroll_speed_mult": 1.0,
		"special": "dense_particles",
	},
	{
		"id": "asteroid_field",
		"display_name": "Asteroid Field",
		"bg_image": "res://assets/backgrounds/space/foozle/bg_solid_01.png",
		"bg_tint": Color(0.8, 0.8, 0.8),
		"overlay_image": "res://assets/backgrounds/space/foozle/bg_shadows2_01.png",
		"overlay_tint": Color(0.7, 0.6, 0.5, 0.4),
		"stars_image": "res://assets/backgrounds/space/foozle/bg_stars_01.png",
		"stars_tint": Color(0.8, 0.8, 0.8, 0.5),
		"stars_fg_image": "res://assets/backgrounds/space/foozle/bg_stars_fg_02.png",
		"stars_fg_tint": Color(1.0, 1.0, 1.0, 0.6),
		"particle_color": Color(0.6, 0.5, 0.4, 0.2),
		"vignette_color": Color(0.03, 0.02, 0.0, 1.0),
		"decoration_types": [
			"asteroid", "asteroid", "dust_cloud",
			"nebula_small",
		],
		"scroll_speed_mult": 1.1,
		"special": "asteroids",
	},
	{
		"id": "planet_orbit",
		"display_name": "Planet Orbit",
		"bg_image": "res://assets/backgrounds/space/foozle/bg_void_03.png",
		"bg_tint": Color(1.1, 1.05, 0.85),
		"overlay_image": "res://assets/backgrounds/space/foozle/bg_shadows_02.png",
		"overlay_tint": Color(0.8, 0.7, 0.5, 0.4),
		"stars_image": "res://assets/backgrounds/space/foozle/bg_stars_02.png",
		"stars_tint": Color(1.0, 1.0, 0.8, 0.6),
		"stars_fg_image": "res://assets/backgrounds/space/foozle/bg_stars_fg_02.png",
		"stars_fg_tint": Color(1.0, 1.0, 0.9, 0.8),
		"particle_color": Color(0.8, 0.7, 0.4, 0.2),
		"vignette_color": Color(0.04, 0.03, 0.0, 1.0),
		"decoration_types": [
			"planet", "nebula_small", "star_cluster",
			"bigstar",
		],
		"scroll_speed_mult": 0.9,
		"special": "planet_bg",
	},
	{
		"id": "wormhole",
		"display_name": "Wormhole",
		"bg_image": "res://assets/backgrounds/space/foozle/bg_void_02.png",
		"bg_tint": Color(0.7, 0.5, 1.0),
		"overlay_image": "res://assets/backgrounds/space/foozle/bg_shadows_01.png",
		"overlay_tint": Color(0.5, 0.3, 0.8, 0.5),
		"stars_image": "res://assets/backgrounds/space/foozle/bg_stars_01.png",
		"stars_tint": Color(0.6, 0.8, 1.0, 0.8),
		"stars_fg_image": "res://assets/backgrounds/space/foozle/bg_stars_fg_01.png",
		"stars_fg_tint": Color(0.7, 1.0, 1.0, 0.9),
		"particle_color": Color(0.4, 0.6, 1.0, 0.35),
		"vignette_color": Color(0.03, 0.0, 0.1, 1.0),
		"decoration_types": [
			"blackhole", "rotarystar", "star_cluster",
			"nebula_small", "rotarystar",
		],
		"scroll_speed_mult": 1.2,
		"special": "rotating_decorations",
	},
	{
		"id": "starforge",
		"display_name": "Starforge",
		"bg_image": "res://assets/backgrounds/space/foozle/bg_solid_01.png",
		"bg_tint": Color(1.2, 0.6, 0.3),
		"overlay_image": "res://assets/backgrounds/space/foozle/bg_shadows2_01.png",
		"overlay_tint": Color(1.0, 0.4, 0.2, 0.5),
		"stars_image": "res://assets/backgrounds/space/foozle/bg_stars_02.png",
		"stars_tint": Color(1.0, 0.6, 0.3, 0.7),
		"stars_fg_image": "res://assets/backgrounds/space/foozle/bg_stars_fg_02.png",
		"stars_fg_tint": Color(1.0, 0.8, 0.4, 0.9),
		"particle_color": Color(1.0, 0.5, 0.2, 0.3),
		"vignette_color": Color(0.08, 0.02, 0.0, 1.0),
		"decoration_types": [
			"bigstar", "rotarystar", "nebula_large",
			"star_cluster", "dust_cloud",
		],
		"scroll_speed_mult": 1.4,
		"special": "hot_colors",
	},
]


func reset():
	current_index = 0


func get_current_environment() -> Dictionary:
	return ENVIRONMENTS[current_index]


func advance_environment():
	current_index = (current_index + 1) % ENVIRONMENTS.size()
	var env = ENVIRONMENTS[current_index]
	environment_changed.emit(current_index, env.id)


func get_environment_index() -> int:
	return current_index
