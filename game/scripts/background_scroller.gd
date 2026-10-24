extends Node2D


const VIEWPORT_W = 320
const VIEWPORT_H = 480
const BASE_SCROLL_SPEED = 30.0
const MAX_DECORATIONS = 7
const DECO_SPACING_MIN = 80.0
const DECO_SPACING_MAX = 200.0

var is_active: bool = true
var scroll_speed_mult: float = 1.0

# Layer scroll offsets
var bg_offset: float = 0.0
var overlay_offset: float = 0.0
var stars_offset: float = 0.0

# Layer nodes (each pair tiles vertically)
var bg_a: Sprite2D
var bg_b: Sprite2D
var overlay_a: Sprite2D
var overlay_b: Sprite2D
var stars_a: Sprite2D
var stars_b: Sprite2D
var stars_fg_a: Sprite2D
var stars_fg_b: Sprite2D
var stars_fg_offset: float = 0.0

# Scroll speed multipliers per layer (parallax depth)
const BG_SPEED_MULT = 0.3
const OVERLAY_SPEED_MULT = 0.5
const STARS_SPEED_MULT = 0.7
const STARS_FG_SPEED_MULT = 1.0
const DECO_SPEED_MULT = 0.8

# Decorations (sprite-based)
var decorations: Array = []
var next_decoration_y: float = -100.0

# Cosmic dust particles
var dust_particles: GPUParticles2D

# Vignette overlay
var vignette: ColorRect

# Current environment config
var current_env: Dictionary = {}


func _ready():
	z_index = -20

	# Build default layers
	_build_bg_layer("res://assets/backgrounds/space/foozle/bg_void_01.png", Color.WHITE)
	_build_overlay_layer("res://assets/backgrounds/space/foozle/bg_shadows_01.png", Color(1, 1, 1, 0.5))
	_build_stars_layer("res://assets/backgrounds/space/foozle/bg_stars_01.png", Color(1, 1, 1, 0.7))
	_build_stars_fg_layer("res://assets/backgrounds/space/foozle/bg_stars_fg_01.png", Color(1, 1, 1, 0.9))
	_build_dust_particles(Color(0.6, 0.7, 1.0, 0.3))
	_build_vignette()
	_generate_initial_decorations()


# ---- Layer builders ----

func _build_bg_layer(tex_path: String, tint: Color):
	if bg_a:
		bg_a.queue_free()
		bg_a = null
	if bg_b:
		bg_b.queue_free()
		bg_b = null

	var tex = load(tex_path)
	if !tex:
		return

	var pair = _create_tiled_pair(tex, -20, tint)
	bg_a = pair[0]
	bg_b = pair[1]
	bg_offset = 0.0


func _build_overlay_layer(tex_path: String, tint: Color):
	if overlay_a:
		overlay_a.queue_free()
		overlay_a = null
	if overlay_b:
		overlay_b.queue_free()
		overlay_b = null

	var tex = load(tex_path)
	if !tex:
		return

	var pair = _create_tiled_pair(tex, -18, tint)
	overlay_a = pair[0]
	overlay_b = pair[1]
	overlay_offset = 0.0


func _build_stars_layer(tex_path: String, tint: Color):
	if stars_a:
		stars_a.queue_free()
		stars_a = null
	if stars_b:
		stars_b.queue_free()
		stars_b = null

	var tex = load(tex_path)
	if !tex:
		return

	var pair = _create_tiled_pair(tex, -16, tint)
	stars_a = pair[0]
	stars_b = pair[1]
	stars_offset = 0.0


func _build_stars_fg_layer(tex_path: String, tint: Color):
	if stars_fg_a:
		stars_fg_a.queue_free()
		stars_fg_a = null
	if stars_fg_b:
		stars_fg_b.queue_free()
		stars_fg_b = null

	var tex = load(tex_path)
	if !tex:
		return

	var pair = _create_tiled_pair(tex, -14, tint)
	stars_fg_a = pair[0]
	stars_fg_b = pair[1]
	stars_fg_offset = 0.0


func _create_tiled_pair(tex: Texture2D, z: int, tint: Color) -> Array:
	# Create a viewport-sized texture from the source by tiling
	var tile_img = tex.get_image()
	var floor_img = Image.create(VIEWPORT_W, VIEWPORT_H, false, Image.FORMAT_RGBA8)

	var tile_w = tile_img.get_width()
	var tile_h = tile_img.get_height()
	var cols = int(ceil(float(VIEWPORT_W) / tile_w)) + 1
	var rows = int(ceil(float(VIEWPORT_H) / tile_h)) + 1

	for row in range(rows):
		for col in range(cols):
			var dst = Vector2i(col * tile_w, row * tile_h)
			var src_w = min(tile_w, VIEWPORT_W - dst.x)
			var src_h = min(tile_h, VIEWPORT_H - dst.y)
			if src_w > 0 and src_h > 0:
				floor_img.blit_rect(tile_img, Rect2i(0, 0, src_w, src_h), dst)

	var floor_texture = ImageTexture.create_from_image(floor_img)

	var sprite_a = Sprite2D.new()
	sprite_a.texture = floor_texture
	sprite_a.centered = false
	sprite_a.z_index = z
	sprite_a.modulate = tint
	add_child(sprite_a)

	var sprite_b = Sprite2D.new()
	sprite_b.texture = floor_texture
	sprite_b.centered = false
	sprite_b.position.y = -VIEWPORT_H
	sprite_b.z_index = z
	sprite_b.modulate = tint
	add_child(sprite_b)

	return [sprite_a, sprite_b]


func _build_dust_particles(color: Color):
	if dust_particles:
		dust_particles.queue_free()
		dust_particles = null

	dust_particles = GPUParticles2D.new()
	dust_particles.z_index = -12
	dust_particles.amount = 20
	dust_particles.lifetime = 6.0
	dust_particles.speed_scale = 0.5
	dust_particles.visibility_rect = Rect2(0, 0, VIEWPORT_W, VIEWPORT_H)
	dust_particles.position = Vector2(VIEWPORT_W / 2.0, 0)

	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(VIEWPORT_W / 2.0, 10, 0)
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 15.0
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 20.0
	mat.gravity = Vector3(0, 2, 0)
	mat.scale_min = 0.5
	mat.scale_max = 1.5
	mat.color = color

	dust_particles.process_material = mat
	add_child(dust_particles)


func _build_vignette():
	if vignette:
		vignette.queue_free()
		vignette = null

	vignette = ColorRect.new()
	vignette.size = Vector2(VIEWPORT_W, VIEWPORT_H)
	vignette.z_index = -10
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader = load("res://shaders/vignette.gdshader")
	if shader:
		var shader_mat = ShaderMaterial.new()
		shader_mat.shader = shader
		shader_mat.set_shader_parameter("vignette_intensity", 0.4)
		shader_mat.set_shader_parameter("vignette_opacity", 0.5)
		shader_mat.set_shader_parameter("vignette_color", Color(0.0, 0.0, 0.05, 1.0))
		vignette.material = shader_mat
	else:
		# Fallback: simple dark border
		vignette.color = Color(0, 0, 0, 0)
		vignette.visible = false

	add_child(vignette)


# ---- Decorations ----

func _generate_initial_decorations():
	var y = randf_range(-150, 50)
	for i in range(5):
		_spawn_decoration(y)
		y += randf_range(DECO_SPACING_MIN, DECO_SPACING_MAX)


func _clear_decorations():
	for deco in decorations:
		if is_instance_valid(deco):
			deco.queue_free()
	decorations.clear()
	next_decoration_y = -100.0


func _spawn_decoration(y_pos: float):
	var deco_types = current_env.get("decoration_types", [
		"bigstar", "planet", "blackhole", "rotarystar", "asteroid"
	])
	var deco_type = deco_types[randi() % deco_types.size()]

	var deco = Node2D.new()
	deco.z_index = -13
	deco.position = Vector2(randf_range(30, VIEWPORT_W - 30), y_pos)
	deco.set_meta("deco_type", deco_type)

	match deco_type:
		"bigstar":
			var idx = randi_range(1, 4)
			_add_sprite_to_deco(
				deco,
				"res://assets/backgrounds/space/foozle/bigstar_hd_%d.png" % idx,
				randf_range(0.5, 1.0)
			)
			# Add glow duplicate behind
			_add_glow_sprite(deco,
				"res://assets/backgrounds/space/foozle/bigstar_hd_%d.png" % idx,
				randf_range(0.8, 1.5), 0.2
			)
		"asteroid":
			_add_sprite_to_deco(
				deco,
				"res://assets/backgrounds/space/asteroid_base_hd.png",
				randf_range(0.15, 0.35)
			)
			deco.set_meta("rotation_speed", randf_range(-0.5, 0.5))
		"planet":
			deco.position.x = VIEWPORT_W / 2 + randf_range(-60, 60)
			_add_sprite_to_deco(
				deco,
				"res://assets/backgrounds/space/planet_earth_hd.png",
				randf_range(0.5, 0.8)
			)
			deco.set_meta("rotation_speed", randf_range(-0.02, 0.02))
		"blackhole":
			var idx = randi_range(1, 4)
			_add_sprite_to_deco(
				deco,
				"res://assets/backgrounds/space/foozle/blackhole_hd_%d.png" % idx,
				randf_range(0.5, 0.8)
			)
			deco.set_meta("rotation_speed", 0.3)
			# Glow aura
			_add_glow_sprite(deco,
				"res://assets/backgrounds/space/foozle/blackhole_hd_%d.png" % idx,
				randf_range(0.9, 1.3), 0.15
			)
		"rotarystar":
			var idx = randi_range(1, 4)
			_add_sprite_to_deco(
				deco,
				"res://assets/backgrounds/space/foozle/rotarystar_hd_%d.png" % idx,
				randf_range(0.7, 1.2)
			)
			deco.set_meta("rotation_speed", randf_range(0.5, 1.5))
		"nebula_small":
			# Fallback to old procedural nebula if no sprite available
			deco.set_meta("render_mode", "procedural")
			deco.set_meta("deco_size", randf_range(5, 10))
			deco.set_meta("deco_color", _random_nebula_color())
			deco.set_meta("layers", randi_range(3, 4))
		"nebula_large":
			deco.set_meta("render_mode", "procedural")
			deco.set_meta("deco_size", randf_range(12, 22))
			deco.set_meta("deco_color", _random_nebula_color())
			deco.set_meta("layers", randi_range(4, 6))
		"star_cluster":
			deco.set_meta("render_mode", "procedural")
			var points: Array = []
			var cluster_colors: Array = []
			for _i in range(randi_range(8, 14)):
				points.append(Vector2(randf_range(-12, 12), randf_range(-12, 12)))
				cluster_colors.append(Color(
					randf_range(0.7, 1.0), randf_range(0.7, 1.0),
					randf_range(0.8, 1.0), randf_range(0.4, 0.9)
				))
			deco.set_meta("cluster_points", points)
			deco.set_meta("cluster_colors", cluster_colors)
		"dust_cloud":
			deco.set_meta("render_mode", "procedural")
			deco.set_meta("cloud_width", randf_range(60, 160))
			deco.set_meta("cloud_height", randf_range(8, 20))
			deco.set_meta("cloud_color", Color(
				randf_range(0.3, 0.6), randf_range(0.3, 0.5),
				randf_range(0.4, 0.7), randf_range(0.06, 0.12)
			))
			deco.position.x = VIEWPORT_W / 2.0

	add_child(deco)
	decorations.append(deco)
	next_decoration_y = y_pos - randf_range(DECO_SPACING_MIN, DECO_SPACING_MAX)


func _add_sprite_to_deco(deco: Node2D, path: String, scale_f: float):
	var tex = load(path)
	if tex:
		var sprite = Sprite2D.new()
		sprite.texture = tex
		sprite.scale = Vector2(scale_f, scale_f)
		sprite.modulate.a = 0.8
		deco.add_child(sprite)


func _add_glow_sprite(deco: Node2D, path: String, scale_f: float, alpha: float):
	var tex = load(path)
	if tex:
		var glow = Sprite2D.new()
		glow.texture = tex
		glow.scale = Vector2(scale_f, scale_f)
		glow.modulate = Color(1, 1, 1, alpha)
		glow.z_index = -1
		deco.add_child(glow)


func _random_nebula_color() -> Color:
	var colors = [
		Color(0.25, 0.1, 0.45, 0.2),
		Color(0.1, 0.25, 0.45, 0.18),
		Color(0.35, 0.1, 0.25, 0.16),
		Color(0.1, 0.35, 0.25, 0.18),
		Color(0.3, 0.2, 0.5, 0.2),
		Color(0.15, 0.3, 0.4, 0.15),
	]
	return colors[randi() % colors.size()]


# ---- Environment change ----

func change_environment(env_config: Dictionary):
	current_env = env_config

	scroll_speed_mult = env_config.get("scroll_speed_mult", 1.0)

	# Rebuild background layer
	var bg_path = env_config.get("bg_image",
		"res://assets/backgrounds/space/foozle/bg_void_01.png")
	var bg_tint = env_config.get("bg_tint", Color.WHITE)
	_build_bg_layer(bg_path, bg_tint)

	# Rebuild overlay layer
	var overlay_path = env_config.get("overlay_image",
		"res://assets/backgrounds/space/foozle/bg_shadows_01.png")
	var overlay_tint = env_config.get("overlay_tint", Color(1, 1, 1, 0.5))
	_build_overlay_layer(overlay_path, overlay_tint)

	# Rebuild stars layer
	var stars_path = env_config.get("stars_image",
		"res://assets/backgrounds/space/foozle/bg_stars_01.png")
	var stars_tint = env_config.get("stars_tint", Color(1, 1, 1, 0.7))
	_build_stars_layer(stars_path, stars_tint)

	# Rebuild foreground stars
	var stars_fg_path = env_config.get("stars_fg_image",
		"res://assets/backgrounds/space/foozle/bg_stars_fg_01.png")
	var stars_fg_tint = env_config.get("stars_fg_tint", Color(1, 1, 1, 0.9))
	_build_stars_fg_layer(stars_fg_path, stars_fg_tint)

	# Update dust particles
	var particle_color = env_config.get("particle_color", Color(0.6, 0.7, 1.0, 0.3))
	_build_dust_particles(particle_color)

	# Update vignette
	if vignette and vignette.material is ShaderMaterial:
		var v_color = env_config.get("vignette_color", Color(0.0, 0.0, 0.05, 1.0))
		vignette.material.set_shader_parameter("vignette_color", v_color)

	# Clear and regenerate decorations
	_clear_decorations()
	_generate_initial_decorations()


# ---- Process ----

func _process(delta: float):
	if !is_active:
		return

	var speed = BASE_SCROLL_SPEED * scroll_speed_mult * delta

	# Scroll background (slowest)
	bg_offset += speed * BG_SPEED_MULT
	if bg_offset >= VIEWPORT_H:
		bg_offset -= VIEWPORT_H
	if bg_a:
		bg_a.position.y = bg_offset
	if bg_b:
		bg_b.position.y = bg_offset - VIEWPORT_H

	# Scroll overlay
	overlay_offset += speed * OVERLAY_SPEED_MULT
	if overlay_offset >= VIEWPORT_H:
		overlay_offset -= VIEWPORT_H
	if overlay_a:
		overlay_a.position.y = overlay_offset
	if overlay_b:
		overlay_b.position.y = overlay_offset - VIEWPORT_H

	# Scroll stars
	stars_offset += speed * STARS_SPEED_MULT
	if stars_offset >= VIEWPORT_H:
		stars_offset -= VIEWPORT_H
	if stars_a:
		stars_a.position.y = stars_offset
	if stars_b:
		stars_b.position.y = stars_offset - VIEWPORT_H

	# Scroll foreground stars (fastest)
	stars_fg_offset += speed * STARS_FG_SPEED_MULT
	if stars_fg_offset >= VIEWPORT_H:
		stars_fg_offset -= VIEWPORT_H
	if stars_fg_a:
		stars_fg_a.position.y = stars_fg_offset
	if stars_fg_b:
		stars_fg_b.position.y = stars_fg_offset - VIEWPORT_H

	# Move and rotate decorations
	for deco in decorations:
		deco.position.y += speed * DECO_SPEED_MULT
		if deco.has_meta("rotation_speed"):
			var rot_speed: float = deco.get_meta("rotation_speed")
			deco.rotation += rot_speed * delta

	# Recycle off-screen decorations
	var to_remove: Array = []
	for deco in decorations:
		if deco.position.y > VIEWPORT_H + 60:
			to_remove.append(deco)
	for deco in to_remove:
		decorations.erase(deco)
		deco.queue_free()

	# Spawn new decorations to maintain density
	if decorations.size() < MAX_DECORATIONS:
		_spawn_decoration(randf_range(-80, -10))

	queue_redraw()


# ---- Procedural drawing (for nebula/cluster/dust fallback) ----

func _draw():
	var time = Engine.get_frames_drawn() * 0.02

	for deco in decorations:
		if !is_instance_valid(deco):
			continue
		var render = deco.get_meta("render_mode") if deco.has_meta("render_mode") else ""
		if render != "procedural":
			continue

		var dtype = deco.get_meta("deco_type") if deco.has_meta("deco_type") else ""
		match dtype:
			"nebula_small", "nebula_large":
				_draw_nebula(deco, time)
			"star_cluster":
				_draw_star_cluster(deco, time)
			"dust_cloud":
				_draw_dust_cloud(deco)


func _draw_nebula(deco: Node2D, time: float):
	var col: Color = deco.get_meta("deco_color")
	var sz: float = deco.get_meta("deco_size")
	var layers: int = deco.get_meta("layers") if deco.has_meta("layers") else 3
	var pos = deco.position

	for i in range(layers):
		var offset = Vector2(
			sin(time * 0.3 + i * 1.5) * sz * 0.3,
			cos(time * 0.25 + i * 2.0) * sz * 0.2
		)
		var layer_sz = sz * (1.2 - i * 0.15)
		var layer_alpha = col.a * (1.0 - i * 0.12)
		var layer_col = Color(
			col.r + i * 0.03, col.g + i * 0.02,
			col.b + i * 0.04, layer_alpha
		)
		draw_circle(pos + offset, layer_sz * 3.5, layer_col)

	var core_alpha = col.a * 1.3
	var core_col = Color(
		col.r * 1.5, col.g * 1.5, col.b * 1.5,
		min(core_alpha, 0.3)
	)
	draw_circle(pos, sz * 1.2, core_col)


func _draw_star_cluster(deco: Node2D, time: float):
	if !deco.has_meta("cluster_points"):
		return
	var points: Array = deco.get_meta("cluster_points")
	var cols: Array = deco.get_meta("cluster_colors")
	var pos = deco.position

	for i in range(points.size()):
		var pt: Vector2 = points[i]
		var col: Color = cols[i]
		var twinkle = 0.5 + 0.5 * sin(time * 1.5 + i * 0.7)
		var dc = Color(col.r, col.g, col.b, col.a * twinkle)
		var sz = 1 if randf() > 0.3 else 2
		draw_rect(Rect2(pos + pt, Vector2(sz, sz)), dc)

	draw_circle(pos, 6.0, Color(0.6, 0.7, 1.0, 0.04))


func _draw_dust_cloud(deco: Node2D):
	if !deco.has_meta("cloud_width"):
		return
	var w: float = deco.get_meta("cloud_width")
	var h: float = deco.get_meta("cloud_height")
	var col: Color = deco.get_meta("cloud_color")
	var pos = deco.position

	var segments = 5
	for i in range(segments):
		var t = float(i) / (segments - 1)
		var x = pos.x - w / 2.0 + t * w
		var seg_h = h * (0.6 + 0.4 * sin(t * PI))
		var seg_w = w / segments * 1.4
		var alpha = col.a * (0.5 + 0.5 * sin(t * PI))
		draw_rect(
			Rect2(x - seg_w / 2, pos.y - seg_h / 2, seg_w, seg_h),
			Color(col.r, col.g, col.b, alpha)
		)
