## Title screen with cyberpunk-style animated background and player ship preview.
extends Control


const VIEWPORT_W: int = 320
const VIEWPORT_H: int = 480
const STAR_COUNT: int = 60
const STAR_SPEED_MIN: float = 15.0
const STAR_SPEED_MAX: float = 80.0

var blink_timer: float = 0.0
var floor_sprite: Sprite2D
var ship_sprite: Sprite2D
var ship_bob_time: float = 0.0
var _transitioning: bool = false

## Parallax star data: Array of {pos: Vector2, speed: float, size: float, color: Color}
var stars: Array[Dictionary] = []

## Scanline overlay for CRT effect
var scanline_time: float = 0.0

@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var subtitle: Label = $VBoxContainer/SubtitleLabel
@onready var credits_label: Label = $VBoxContainer/CreditsLabel
@onready var bg_music: AudioStreamPlayer = $BGMusic


func _ready():
	_build_tiled_background()
	_init_stars()
	_build_ship_preview()
	_style_labels()

	if bg_music:
		bg_music.stream = load("res://assets/audio/music/theme_adventure.ogg")
		bg_music.play()


func _build_tiled_background():
	var bg_tex = preload("res://assets/backgrounds/space/kenney_darkpurple.png")
	var tile_img = bg_tex.get_image()

	var bg_img = Image.create(VIEWPORT_W, VIEWPORT_H, false, Image.FORMAT_RGBA8)

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
				bg_img.blit_rect(tile_img, Rect2i(0, 0, src_w, src_h), dst)

	# Darken for title readability
	for y in range(VIEWPORT_H):
		for x in range(VIEWPORT_W):
			var c = bg_img.get_pixel(x, y)
			bg_img.set_pixel(x, y, Color(c.r * 0.4, c.g * 0.4, c.b * 0.5, 1.0))

	var bg_texture = ImageTexture.create_from_image(bg_img)
	var color_rect = $ColorRect
	if color_rect:
		color_rect.visible = false

	floor_sprite = Sprite2D.new()
	floor_sprite.texture = bg_texture
	floor_sprite.centered = false
	floor_sprite.z_index = -10
	add_child(floor_sprite)
	move_child(floor_sprite, 0)


func _init_stars():
	for i in range(STAR_COUNT):
		var star_speed = randf_range(STAR_SPEED_MIN, STAR_SPEED_MAX)
		var brightness = remap(star_speed, STAR_SPEED_MIN, STAR_SPEED_MAX, 0.3, 1.0)
		var star_size = remap(star_speed, STAR_SPEED_MIN, STAR_SPEED_MAX, 0.5, 2.0)
		stars.append({
			"pos": Vector2(randf_range(0, VIEWPORT_W), randf_range(0, VIEWPORT_H)),
			"speed": star_speed,
			"size": star_size,
			"color": Color(0.6 * brightness, 0.7 * brightness, brightness, brightness),
		})


func _build_ship_preview():
	ship_sprite = Sprite2D.new()
	ship_sprite.texture = preload("res://assets/sprites/player/space/player_ship.png")
	ship_sprite.scale = Vector2(0.5, 0.5)
	ship_sprite.position = Vector2(VIEWPORT_W / 2.0, VIEWPORT_H * 0.72)
	ship_sprite.z_index = 5
	add_child(ship_sprite)


func _style_labels():
	if title_label:
		title_label.add_theme_font_size_override("font_size", 22)
		title_label.add_theme_color_override("font_color", UIColors.CYAN)
		title_label.add_theme_constant_override("outline_size", 4)
		title_label.add_theme_color_override("font_outline_color", Color(0.0, 0.1, 0.3))

	if subtitle:
		subtitle.add_theme_font_size_override("font_size", UIColors.FONT_SMALL)
		subtitle.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))

	if credits_label:
		credits_label.add_theme_font_size_override("font_size", UIColors.FONT_TINY)
		credits_label.add_theme_color_override("font_color", UIColors.TEXT_DIM)


func _process(delta: float):
	blink_timer += delta
	ship_bob_time += delta
	scanline_time += delta

	# Subtitle blink
	if subtitle:
		subtitle.modulate.a = 0.5 + 0.5 * sin(blink_timer * 3.0)

	# Ship bobbing
	if ship_sprite:
		ship_sprite.position.y = VIEWPORT_H * 0.72 + sin(ship_bob_time * 1.5) * 4.0
		ship_sprite.rotation = sin(ship_bob_time * 0.8) * 0.03

	# Update stars
	for star in stars:
		star.pos.y += star.speed * delta
		if star.pos.y > VIEWPORT_H + 5:
			star.pos.y = -5
			star.pos.x = randf_range(0, VIEWPORT_W)

	queue_redraw()


func _draw():
	# Draw stars
	for star in stars:
		var s: float = star.size
		var col: Color = star.color
		# Twinkle effect
		col.a *= 0.7 + 0.3 * sin(blink_timer * 5.0 + star.pos.x * 0.1)
		draw_rect(Rect2(star.pos.x - s * 0.5, star.pos.y - s * 0.5, s, s), col)

	# Draw subtle scanlines for CRT effect
	for y in range(0, VIEWPORT_H, 3):
		draw_line(
			Vector2(0, y),
			Vector2(VIEWPORT_W, y),
			Color(0, 0, 0, 0.08),
			1.0
		)

	# Draw neon glow line under title area
	var line_y: float = VIEWPORT_H * 0.42
	var line_alpha: float = 0.3 + 0.15 * sin(blink_timer * 2.0)
	draw_line(
		Vector2(40, line_y),
		Vector2(VIEWPORT_W - 40, line_y),
		Color(0.2, 0.7, 1.0, line_alpha),
		1.5
	)
	# Glow spread
	draw_line(
		Vector2(50, line_y),
		Vector2(VIEWPORT_W - 50, line_y),
		Color(0.2, 0.7, 1.0, line_alpha * 0.3),
		4.0
	)

	# Ship engine glow
	if ship_sprite:
		var engine_pos = ship_sprite.position + Vector2(0, 16)
		var glow_alpha = 0.4 + 0.2 * sin(blink_timer * 6.0)
		draw_circle(engine_pos, 6.0, Color(0.3, 0.5, 1.0, glow_alpha * 0.3))
		draw_circle(engine_pos, 3.0, Color(0.5, 0.7, 1.0, glow_alpha))


func _input(event: InputEvent):
	if event.is_action_pressed("ui_accept") and not _transitioning:
		_transitioning = true
		# Fade out music and screen before transitioning
		var fade_rect = ColorRect.new()
		fade_rect.color = Color(0, 0, 0, 0)
		fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		fade_rect.z_index = 100
		fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(fade_rect)

		var tween = create_tween()
		tween.set_ease(Tween.EASE_IN)
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(fade_rect, "color:a", 1.0, 0.4)
		if bg_music and bg_music.playing:
			tween.parallel().tween_property(bg_music, "volume_db", -40.0, 0.4)
		tween.tween_callback(func():
			if bg_music and bg_music.playing:
				bg_music.stop()
			get_tree().change_scene_to_file("res://scenes/game.tscn")
		)
