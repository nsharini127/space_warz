extends CanvasLayer


# Scene tree nodes (must match hud.tscn)
@onready var score_label: Label = $MarginContainer/VBoxContainer/ScoreLabel
@onready var wave_label: Label = $MarginContainer/VBoxContainer/WaveLabel
@onready var hp_container: HBoxContainer = $MarginContainer/VBoxContainer/HPContainer

# Dynamically created HUD elements
var hi_score_label: Label
var counter_label: Label
var graze_label: Label
var bomb_label: Label
var power_label: Label
var boss_hp_bar: Control

# Weapon panel
var weapon_panel: HBoxContainer
var weapon_icons: Array = []

# Upgrade glow pulse tracking: weapon_id -> remaining_time (seconds)
var _recently_upgraded: Dictionary = {}

# Timer
var timer_label: Label

# Fever Mode
var fever_active: bool = false
var fever_timer: float = 0.0
var combo_count: int = 0
var fever_label: Label
var fever_glow_label: Label  # behind fever_label for glow effect
var fever_overlay: ColorRect  # subtle screen border glow

# Bomb icon texture for inline display
var bomb_icon_texture: Texture2D

var hi_score: int = 0

const VIEWPORT_W: int = 320
const VIEWPORT_H: int = 480
const MARGIN: int = 4


func _ready():
	# Preload bomb icon for stat display
	bomb_icon_texture = preload("res://assets/sprites/ui/space/powerup_bomb.png")

	_setup_score_label()
	_create_hi_score_label()
	_setup_wave_label()
	_create_right_stats()
	_setup_hp_container()
	_create_counter_label()
	_create_timer_label()
	_create_boss_hp_bar()
	_create_weapon_panel()
	_create_fever_indicator()


# ---------------------------------------------------------------------------
# Score label: top-left, large heading
# ---------------------------------------------------------------------------
func _setup_score_label():
	if !score_label:
		return
	score_label.text = "SCORE: 0"
	score_label.add_theme_font_size_override("font_size", UIColors.FONT_HEADING)
	score_label.add_theme_color_override("font_color", UIColors.HUD_SCORE)
	score_label.add_theme_constant_override("outline_size", 2)
	score_label.add_theme_color_override("font_outline_color", UIColors.OUTLINE_BLACK)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


# ---------------------------------------------------------------------------
# Hi-score label: directly below score, small gray
# ---------------------------------------------------------------------------
func _create_hi_score_label():
	hi_score_label = Label.new()
	hi_score_label.text = "HI: 0"
	hi_score_label.add_theme_font_size_override("font_size", UIColors.FONT_SMALL)
	hi_score_label.add_theme_color_override("font_color", UIColors.HUD_HISCORE)
	hi_score_label.add_theme_constant_override("outline_size", 2)
	hi_score_label.add_theme_color_override("font_outline_color", UIColors.OUTLINE_BLACK)
	hi_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	# Position below score label
	hi_score_label.position = Vector2(MARGIN, MARGIN + 14)
	add_child(hi_score_label)


# ---------------------------------------------------------------------------
# Wave label: top-right, cyan badge
# ---------------------------------------------------------------------------
func _setup_wave_label():
	if !wave_label:
		return
	wave_label.text = "WAVE 1"
	wave_label.add_theme_font_size_override("font_size", UIColors.FONT_BODY)
	wave_label.add_theme_color_override("font_color", UIColors.HUD_WAVE)
	wave_label.add_theme_constant_override("outline_size", 2)
	wave_label.add_theme_color_override("font_outline_color", UIColors.OUTLINE_BLACK)
	# Reparent out of VBox and position absolutely at top-right
	var parent = wave_label.get_parent()
	if parent:
		parent.remove_child(wave_label)
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	wave_label.anchor_left = 1.0
	wave_label.anchor_right = 1.0
	wave_label.anchor_top = 0.0
	wave_label.anchor_bottom = 0.0
	wave_label.offset_left = -100
	wave_label.offset_right = -MARGIN
	wave_label.offset_top = MARGIN
	wave_label.offset_bottom = MARGIN + 12
	add_child(wave_label)


# ---------------------------------------------------------------------------
# Right-side stats: power, bombs, graze (stacked below wave label on the right)
# ---------------------------------------------------------------------------
func _create_right_stats():
	var right_x: float = VIEWPORT_W - MARGIN
	var start_y: float = MARGIN + 16  # below wave label

	# Power label
	power_label = Label.new()
	power_label.text = "POWER: Lv.1"
	power_label.add_theme_font_size_override("font_size", UIColors.FONT_SMALL)
	power_label.add_theme_color_override("font_color", UIColors.HUD_POWER)
	power_label.add_theme_constant_override("outline_size", 2)
	power_label.add_theme_color_override("font_outline_color", UIColors.OUTLINE_BLACK)
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	power_label.position = Vector2(right_x - 120, start_y)
	power_label.size = Vector2(120, 10)
	add_child(power_label)

	# Bomb container (icon + label)
	var bomb_hbox = HBoxContainer.new()
	bomb_hbox.add_theme_constant_override("separation", 2)
	bomb_hbox.position = Vector2(right_x - 120, start_y + 12)
	bomb_hbox.size = Vector2(120, 12)
	bomb_hbox.alignment = BoxContainer.ALIGNMENT_END
	add_child(bomb_hbox)

	# Spacer to push content right
	var bomb_spacer = Control.new()
	bomb_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bomb_hbox.add_child(bomb_spacer)

	# Bomb icon
	var bomb_tex = TextureRect.new()
	bomb_tex.texture = bomb_icon_texture
	bomb_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bomb_tex.custom_minimum_size = Vector2(10, 10)
	bomb_hbox.add_child(bomb_tex)

	# Bomb label
	bomb_label = Label.new()
	bomb_label.text = "x3"
	bomb_label.add_theme_font_size_override("font_size", UIColors.FONT_SMALL)
	bomb_label.add_theme_color_override("font_color", UIColors.HUD_BOMBS)
	bomb_label.add_theme_constant_override("outline_size", 2)
	bomb_label.add_theme_color_override("font_outline_color", UIColors.OUTLINE_BLACK)
	bomb_hbox.add_child(bomb_label)

	# Graze label
	graze_label = Label.new()
	graze_label.text = "GRAZE: 0"
	graze_label.add_theme_font_size_override("font_size", UIColors.FONT_SMALL)
	graze_label.add_theme_color_override("font_color", UIColors.HUD_GRAZE)
	graze_label.add_theme_constant_override("outline_size", 2)
	graze_label.add_theme_color_override("font_outline_color", UIColors.OUTLINE_BLACK)
	graze_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	graze_label.position = Vector2(right_x - 120, start_y + 24)
	graze_label.size = Vector2(120, 10)
	add_child(graze_label)


# ---------------------------------------------------------------------------
# HP hearts: below score/hi-score on the left, 14px icons
# ---------------------------------------------------------------------------
func _setup_hp_container():
	if !hp_container:
		return
	# Reparent out of VBox to position freely
	var parent = hp_container.get_parent()
	if parent:
		parent.remove_child(hp_container)
	hp_container.position = Vector2(MARGIN, MARGIN + 26)
	hp_container.add_theme_constant_override("separation", 2)
	add_child(hp_container)


# ---------------------------------------------------------------------------
# Counter label: top-center, standalone
# ---------------------------------------------------------------------------
func _create_counter_label():
	counter_label = Label.new()
	counter_label.text = ""
	counter_label.add_theme_font_size_override("font_size", UIColors.FONT_BODY)
	counter_label.add_theme_color_override("font_color", UIColors.CYAN)
	counter_label.add_theme_constant_override("outline_size", 2)
	counter_label.add_theme_color_override("font_outline_color", UIColors.OUTLINE_BLACK)
	counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Center horizontally at top
	counter_label.anchor_left = 0.5
	counter_label.anchor_right = 0.5
	counter_label.anchor_top = 0.0
	counter_label.anchor_bottom = 0.0
	counter_label.offset_left = -40
	counter_label.offset_right = 40
	counter_label.offset_top = MARGIN
	counter_label.offset_bottom = MARGIN + 12
	add_child(counter_label)


# ---------------------------------------------------------------------------
# Timer label: top-center below counter, MM:SS format
# ---------------------------------------------------------------------------
func _create_timer_label():
	timer_label = Label.new()
	timer_label.text = "5:00"
	timer_label.add_theme_font_size_override("font_size", UIColors.FONT_HEADING)
	timer_label.add_theme_color_override("font_color", UIColors.HUD_TIMER_SAFE)
	timer_label.add_theme_constant_override("outline_size", 2)
	timer_label.add_theme_color_override("font_outline_color", UIColors.OUTLINE_BLACK)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.anchor_left = 0.5
	timer_label.anchor_right = 0.5
	timer_label.anchor_top = 0.0
	timer_label.anchor_bottom = 0.0
	timer_label.offset_left = -30
	timer_label.offset_right = 30
	timer_label.offset_top = MARGIN + 14
	timer_label.offset_bottom = MARGIN + 28
	add_child(timer_label)


# ---------------------------------------------------------------------------
# Boss HP bar: centered at y=14
# ---------------------------------------------------------------------------
func _create_boss_hp_bar():
	boss_hp_bar = Control.new()
	boss_hp_bar.set_script(preload("res://scripts/ui/boss_hp_bar.gd"))
	boss_hp_bar.visible = false
	boss_hp_bar.position = Vector2(0, 14)
	boss_hp_bar.size = Vector2(VIEWPORT_W, 30)
	add_child(boss_hp_bar)


# ---------------------------------------------------------------------------
# Weapon panel: bottom-center, horizontal row of weapon icons
# ---------------------------------------------------------------------------
func _create_weapon_panel():
	weapon_panel = HBoxContainer.new()
	weapon_panel.add_theme_constant_override("separation", 3)
	# Anchor to bottom-center
	weapon_panel.anchor_left = 0.5
	weapon_panel.anchor_right = 0.5
	weapon_panel.anchor_top = 1.0
	weapon_panel.anchor_bottom = 1.0
	weapon_panel.offset_top = -42
	weapon_panel.offset_bottom = -MARGIN
	weapon_panel.offset_left = -100
	weapon_panel.offset_right = 100
	weapon_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(weapon_panel)


# ---------------------------------------------------------------------------
# Fever Mode indicator: center-top, below timer
# ---------------------------------------------------------------------------
func _create_fever_indicator():
	# Glow label (behind main text for glow/shadow effect)
	fever_glow_label = Label.new()
	fever_glow_label.text = ""
	fever_glow_label.add_theme_font_size_override("font_size", UIColors.FONT_HERO)
	fever_glow_label.add_theme_color_override("font_color", Color(UIColors.FEVER_GLOW.r, UIColors.FEVER_GLOW.g, UIColors.FEVER_GLOW.b, 0.6))
	fever_glow_label.add_theme_constant_override("outline_size", 6)
	fever_glow_label.add_theme_color_override("font_outline_color", Color(UIColors.FEVER_GLOW.r, UIColors.FEVER_GLOW.g - 0.1, UIColors.FEVER_GLOW.b, 0.4))
	fever_glow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fever_glow_label.anchor_left = 0.5
	fever_glow_label.anchor_right = 0.5
	fever_glow_label.anchor_top = 0.0
	fever_glow_label.anchor_bottom = 0.0
	fever_glow_label.offset_left = -60
	fever_glow_label.offset_right = 60
	fever_glow_label.offset_top = MARGIN + 28
	fever_glow_label.offset_bottom = MARGIN + 46
	fever_glow_label.visible = false
	add_child(fever_glow_label)

	# Main fever/combo label
	fever_label = Label.new()
	fever_label.text = ""
	fever_label.add_theme_font_size_override("font_size", UIColors.FONT_SMALL)
	fever_label.add_theme_color_override("font_color", UIColors.FEVER_COMBO)
	fever_label.add_theme_constant_override("outline_size", 2)
	fever_label.add_theme_color_override("font_outline_color", UIColors.OUTLINE_BLACK)
	fever_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fever_label.anchor_left = 0.5
	fever_label.anchor_right = 0.5
	fever_label.anchor_top = 0.0
	fever_label.anchor_bottom = 0.0
	fever_label.offset_left = -60
	fever_label.offset_right = 60
	fever_label.offset_top = MARGIN + 28
	fever_label.offset_bottom = MARGIN + 46
	fever_label.visible = false
	add_child(fever_label)

	# Screen border glow overlay (subtle red edges during fever)
	fever_overlay = ColorRect.new()
	fever_overlay.color = Color(UIColors.FEVER_OVERLAY.r, UIColors.FEVER_OVERLAY.g, UIColors.FEVER_OVERLAY.b, 0.0)
	fever_overlay.anchor_left = 0.0
	fever_overlay.anchor_right = 1.0
	fever_overlay.anchor_top = 0.0
	fever_overlay.anchor_bottom = 1.0
	fever_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fever_overlay.visible = false
	add_child(fever_overlay)


# ---------------------------------------------------------------------------
# Fever Mode: _process for animation
# ---------------------------------------------------------------------------
func _process(delta: float):
	fever_timer += delta

	# Tick down weapon upgrade glow timers and apply pulse modulate
	var expired_keys: Array = []
	for wid in _recently_upgraded:
		_recently_upgraded[wid] -= delta
		if _recently_upgraded[wid] <= 0.0:
			expired_keys.append(wid)
	for wid in expired_keys:
		_recently_upgraded.erase(wid)
		# Reset modulate on expired icon
		for icon in weapon_icons:
			if is_instance_valid(icon) and icon.has_meta("weapon_id") and icon.get_meta("weapon_id") == wid:
				icon.modulate = Color.WHITE

	# Apply pulsing glow to recently upgraded weapons
	for wid in _recently_upgraded:
		var t: float = _recently_upgraded[wid]  # remaining time (2.0 -> 0.0)
		var pulse: float = t / 2.0  # normalized 1.0 -> 0.0
		for icon in weapon_icons:
			if is_instance_valid(icon) and icon.has_meta("weapon_id") and icon.get_meta("weapon_id") == wid:
				icon.modulate = Color(1.0 + pulse * 0.5, 1.0 + pulse * 0.3, 1.0 + pulse * 0.3)

	if fever_active:
		# Pulsating FEVER! text
		var pulse: float = sin(fever_timer * 6.0)
		var scale_factor: float = 1.0 + pulse * 0.15
		var alpha: float = 0.8 + pulse * 0.2

		if fever_label:
			fever_label.visible = true
			fever_label.text = "FEVER!"
			fever_label.add_theme_font_size_override("font_size", UIColors.FONT_HERO)
			fever_label.add_theme_color_override("font_color", Color(UIColors.FEVER_ACTIVE.r, UIColors.FEVER_ACTIVE.g, UIColors.FEVER_ACTIVE.b, alpha))
			fever_label.scale = Vector2(scale_factor, scale_factor)
			fever_label.pivot_offset = fever_label.size * 0.5

		if fever_glow_label:
			fever_glow_label.visible = true
			fever_glow_label.text = "FEVER!"
			var glow_alpha: float = 0.3 + pulse * 0.2
			fever_glow_label.add_theme_color_override("font_color", Color(UIColors.FEVER_GLOW.r, UIColors.FEVER_GLOW.g, UIColors.FEVER_GLOW.b, glow_alpha))
			fever_glow_label.add_theme_color_override("font_outline_color", Color(UIColors.FEVER_GLOW.r, UIColors.FEVER_GLOW.g - 0.05, UIColors.FEVER_GLOW.b, glow_alpha * 0.7))
			fever_glow_label.scale = Vector2(scale_factor, scale_factor)
			fever_glow_label.pivot_offset = fever_glow_label.size * 0.5

		# Subtle red border glow
		if fever_overlay:
			fever_overlay.visible = true
			var border_alpha: float = 0.03 + abs(pulse) * 0.03
			fever_overlay.color = Color(UIColors.FEVER_OVERLAY.r, UIColors.FEVER_OVERLAY.g, UIColors.FEVER_OVERLAY.b, border_alpha)

	elif combo_count > 0:
		# Show combo counter with opacity proportional to combo/12
		var opacity: float = clampf(float(combo_count) / 12.0, 0.15, 1.0)

		if fever_label:
			fever_label.visible = true
			fever_label.text = "COMBO x" + str(combo_count)
			fever_label.add_theme_font_size_override("font_size", UIColors.FONT_SMALL)
			fever_label.add_theme_color_override("font_color", Color(UIColors.FEVER_COMBO.r, UIColors.FEVER_COMBO.g, UIColors.FEVER_COMBO.b, opacity))
			fever_label.scale = Vector2.ONE
			fever_label.pivot_offset = Vector2.ZERO

		if fever_glow_label:
			fever_glow_label.visible = false

		if fever_overlay:
			fever_overlay.visible = false

	else:
		# Nothing active, hide everything
		if fever_label:
			fever_label.visible = false
		if fever_glow_label:
			fever_glow_label.visible = false
		if fever_overlay:
			fever_overlay.visible = false


# ===========================================================================
# Public update methods
# ===========================================================================

func update_score(score: int):
	if score_label:
		score_label.text = "SCORE: " + str(score)
	if score > hi_score:
		hi_score = score
	if hi_score_label:
		hi_score_label.text = "HI: " + str(hi_score)


func update_wave(wave: int):
	if wave_label:
		wave_label.text = "WAVE " + str(wave)


func update_hp(current: int, max_hp: int):
	if !hp_container:
		return
	# Clear existing hearts
	for child in hp_container.get_children():
		child.queue_free()
	# Create heart icons at 14px
	for i in range(max_hp):
		var heart = TextureRect.new()
		heart.texture = preload("res://assets/sprites/ui/space/life_icon.png")
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.custom_minimum_size = Vector2(14, 14)
		if i >= current:
			heart.modulate = UIColors.HUD_HEART_EMPTY
		hp_container.add_child(heart)


func update_counter(stage: int, total: int, color_str: String):
	if !counter_label:
		return
	counter_label.text = str(stage)
	if color_str == "GREEN":
		counter_label.add_theme_color_override("font_color", UIColors.CYAN)
	else:
		counter_label.add_theme_color_override("font_color", UIColors.HUD_BOMBS)


func update_graze(count: int):
	if graze_label:
		graze_label.text = "GRAZE: " + str(count)


func update_power(level: int):
	if power_label:
		power_label.text = "POWER: Lv." + str(level)


func update_bombs(count: int):
	if bomb_label:
		bomb_label.text = "x" + str(count)


func update_timer(time_remaining: float):
	if !timer_label:
		return
	var mins: int = int(time_remaining) / 60
	var secs: int = int(time_remaining) % 60
	timer_label.text = "%d:%02d" % [mins, secs]
	# Color changes: yellow > 120s, orange 60-120s, red < 60s
	if time_remaining > 120.0:
		timer_label.add_theme_color_override("font_color", UIColors.HUD_TIMER_SAFE)
	elif time_remaining > 60.0:
		timer_label.add_theme_color_override("font_color", UIColors.HUD_TIMER_WARN)
	else:
		# Pulsing red for urgency
		var pulse = 0.7 + 0.3 * abs(sin(time_remaining * 3.0))
		timer_label.add_theme_color_override("font_color", Color(UIColors.HUD_TIMER_DANGER.r, UIColors.HUD_TIMER_DANGER.g, UIColors.HUD_TIMER_DANGER.b, pulse))


func update_weapons(weapon_manager: Node):
	if !weapon_panel:
		return

	# Clear old icons
	for icon in weapon_icons:
		if is_instance_valid(icon):
			icon.queue_free()
	weapon_icons.clear()

	# Clear upgrade glow timers (prevents stale entries across restarts)
	_recently_upgraded.clear()

	if !weapon_manager:
		return

	var ids = weapon_manager.get_active_weapon_ids()
	for id in ids:
		var level = weapon_manager.get_weapon_level(id)
		var evolved = weapon_manager.is_weapon_evolved(id)
		var data = WeaponRegistry.get_weapon(id)

		var icon_container = _create_weapon_icon(data, level, evolved, id)
		weapon_panel.add_child(icon_container)
		weapon_icons.append(icon_container)


func _create_weapon_icon(data: Dictionary, level: int, evolved: bool, weapon_id: String = "") -> Control:
	var container_node = PanelContainer.new()
	container_node.custom_minimum_size = Vector2(44, 34)
	if weapon_id != "":
		container_node.set_meta("weapon_id", weapon_id)

	# Determine glow color from weapon data
	var glow: Color = data.get("glow_color", Color.WHITE)

	# Style the panel: gradient-like background with colored border
	var style = StyleBoxFlat.new()
	style.bg_color = Color(glow.r * 0.2, glow.g * 0.2, glow.b * 0.2, 0.9)
	if evolved:
		style.border_color = UIColors.GOLD
		style.set_border_width_all(2)
	else:
		style.border_color = glow
		style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = 2
	style.content_margin_right = 2
	style.content_margin_top = 1
	style.content_margin_bottom = 1
	container_node.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	container_node.add_child(vbox)

	# Procedural weapon icon via _draw()
	var icon_draw = Control.new()
	icon_draw.set_script(preload("res://scripts/ui/weapon_icon_draw.gd"))
	icon_draw.setup(data.get("id", ""), glow, evolved)
	vbox.add_child(icon_draw)

	# Level indicator as dots (●●●○○)
	var lv_label = Label.new()
	if evolved:
		lv_label.text = "\u2605MAX"
		lv_label.add_theme_color_override("font_color", UIColors.GOLD)
	else:
		var max_level: int = data.get("max_level", 5)
		var dots: String = ""
		for i in range(max_level):
			dots += "\u25cf" if i < level else "\u25cb"
		lv_label.text = dots
		lv_label.add_theme_color_override("font_color", glow)
	lv_label.add_theme_font_size_override("font_size", UIColors.FONT_TINY)
	lv_label.add_theme_constant_override("outline_size", 1)
	lv_label.add_theme_color_override("font_outline_color", UIColors.OUTLINE_BLACK)
	lv_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(lv_label)

	return container_node


func notify_weapon_upgrade(weapon_id: String):
	_recently_upgraded[weapon_id] = 2.0


func show_boss_hp(hp: float, max_val: float):
	if boss_hp_bar:
		boss_hp_bar.show_bar(hp, max_val)


func update_boss_hp(hp: float):
	if boss_hp_bar:
		boss_hp_bar.update_hp(hp)


func hide_boss_hp():
	if boss_hp_bar:
		boss_hp_bar.hide_bar()


# ===========================================================================
# Fever Mode public methods
# ===========================================================================

func show_fever():
	fever_active = true
	fever_timer = 0.0


func hide_fever():
	fever_active = false
	combo_count = 0


func update_combo(count: int):
	combo_count = count
