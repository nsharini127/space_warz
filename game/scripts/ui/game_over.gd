extends CanvasLayer


signal restart_requested
signal quit_requested

@onready var panel: PanelContainer = $Panel
@onready var vbox: VBoxContainer = $Panel/VBoxContainer
@onready var game_over_label: Label = $Panel/VBoxContainer/GameOverLabel
@onready var score_label: Label = $Panel/VBoxContainer/ScoreLabel
@onready var wave_label: Label = $Panel/VBoxContainer/WaveLabel
@onready var separator: HSeparator = $Panel/VBoxContainer/HSeparator
@onready var restart_btn: Button = $Panel/VBoxContainer/RestartButton
@onready var quit_btn: Button = $Panel/VBoxContainer/QuitButton

var _stats_container: VBoxContainer = null

# Grade label (inserted between title and score)
var _grade_label: Label = null
# Contextual message label
var _message_label: Label = null
# Weapon build container
var _weapon_build_container: VBoxContainer = null

# Score counting animation
var animating_score: bool = false
var display_score: float = 0.0
var target_score: int = 0
var anim_delay: float = 0.0
var _score_value_label: Label = null
var _is_victory: bool = false
var _is_animating: bool = false


func _ready():
	hide()
	set_process(false)
	_style_panel()
	_style_game_over_label()
	_style_score_label()
	_style_wave_label()
	_style_separator()
	_style_restart_button()
	_style_quit_button()

	if restart_btn:
		restart_btn.pressed.connect(_on_restart)
	if quit_btn:
		quit_btn.pressed.connect(_on_quit)


func _process(delta: float):
	if not animating_score:
		set_process(false)
		return

	if anim_delay > 0.0:
		anim_delay -= delta
		return

	var increment: float = target_score / 60.0
	if increment < 1.0:
		increment = 1.0
	display_score += increment
	if display_score >= target_score:
		display_score = target_score
		animating_score = false
		set_process(false)

	if _score_value_label and is_instance_valid(_score_value_label):
		_score_value_label.text = str(int(display_score))


func show_game_over(score: int, wave: int, extra: Dictionary = {}):
	_is_victory = false
	_is_animating = false
	_cleanup_dynamic_groups()
	_style_panel()

	# -- Grade --
	var grade = _calculate_grade(score, wave)
	_show_grade(grade)

	# -- Contextual message --
	var msg = _get_contextual_message(wave, score)
	_show_contextual_message(msg)

	# -- Score section with animation --
	if score_label:
		score_label.text = ""
		_replace_with_stat_pair(score_label, "SCORE", "0", UIColors.FONT_SMALL, UIColors.FONT_HERO,
			UIColors.TEXT_GRAY, UIColors.TEXT_WHITE)
	_start_score_animation(score)

	# -- Wave section --
	if wave_label:
		wave_label.text = ""
		_replace_with_stat_pair(wave_label, "WAVE REACHED", str(wave), UIColors.FONT_SMALL, UIColors.FONT_HEADING,
			UIColors.TEXT_GRAY, UIColors.GOLD)

	# -- Extra stats --
	_clear_stats_container()
	if extra.size() > 0:
		_build_stats_grid(extra)

	show()

	# Keyboard focus
	if restart_btn:
		restart_btn.grab_focus()


# ---------------------------------------------------------------------------
# Score Grade System
# ---------------------------------------------------------------------------

func _calculate_grade(score: int, wave: int) -> String:
	if score >= 80000 or wave >= 15:
		return "S"
	elif score >= 50000 or wave >= 12:
		return "A"
	elif score >= 30000 or wave >= 9:
		return "B"
	elif score >= 15000 or wave >= 6:
		return "C"
	else:
		return "D"


func _get_grade_color(grade: String) -> Color:
	match grade:
		"S": return UIColors.GRADE_S
		"A": return UIColors.GRADE_A
		"B": return UIColors.GRADE_B
		"C": return UIColors.GRADE_C
		"D": return UIColors.GRADE_D
		_: return UIColors.GRADE_D


func _get_grade_size(grade: String) -> int:
	match grade:
		"S": return UIColors.FONT_TITLE + 8   # 24
		"A": return UIColors.FONT_TITLE + 6   # 22
		"B": return UIColors.FONT_TITLE + 4   # 20
		"C": return UIColors.FONT_TITLE + 2   # 18
		"D": return UIColors.FONT_TITLE + 2   # 18
		_: return UIColors.FONT_TITLE + 2


func _show_grade(grade: String):
	if _grade_label and is_instance_valid(_grade_label):
		_grade_label.get_parent().remove_child(_grade_label)
		_grade_label.queue_free()
		_grade_label = null

	if not vbox or not game_over_label:
		return

	var grade_color := _get_grade_color(grade)

	_grade_label = Label.new()
	_grade_label.name = "GradeLabelGroup"
	_grade_label.text = grade
	_grade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_grade_label.add_theme_font_size_override("font_size", _get_grade_size(grade))
	_grade_label.add_theme_color_override("font_color", grade_color)
	_grade_label.add_theme_constant_override("outline_size", 3)
	_grade_label.add_theme_color_override("font_outline_color", Color(grade_color.r * 0.3, grade_color.g * 0.3, grade_color.b * 0.3))
	_grade_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Insert right after the game over label
	var title_idx = game_over_label.get_index()
	vbox.add_child(_grade_label)
	vbox.move_child(_grade_label, title_idx + 1)

	# Grade entrance animation: scale bounce + fade
	_grade_label.pivot_offset = _grade_label.size * 0.5
	_grade_label.scale = Vector2(2.5, 2.5)
	_grade_label.modulate.a = 0.0
	var tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(_grade_label, "scale", Vector2(1.0, 1.0), 0.4)
	tween.parallel().tween_property(_grade_label, "modulate:a", 1.0, 0.25)


# ---------------------------------------------------------------------------
# Contextual Messages
# ---------------------------------------------------------------------------

func _get_contextual_message(wave: int, _score: int) -> String:
	if _is_victory:
		return "The galaxy is safe... for now."
	if wave <= 2:
		return "The void is unforgiving..."
	elif wave <= 5:
		return "A promising start. Keep fighting!"
	elif wave <= 8:
		return "You're getting stronger, pilot."
	elif wave <= 11:
		return "So close! The final boss awaits..."
	else:
		return "An impressive run, Commander!"


func _show_contextual_message(msg: String):
	if _message_label and is_instance_valid(_message_label):
		_message_label.get_parent().remove_child(_message_label)
		_message_label.queue_free()
		_message_label = null

	if not vbox:
		return

	_message_label = Label.new()
	_message_label.name = "MessageLabelGroup"
	_message_label.text = msg
	_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message_label.add_theme_font_size_override("font_size", UIColors.FONT_SMALL)
	_message_label.add_theme_color_override("font_color", Color(UIColors.TEXT_GRAY.r, UIColors.TEXT_GRAY.g, UIColors.TEXT_GRAY.b, 0.8))
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var insert_idx = game_over_label.get_index() + 1
	if _grade_label and is_instance_valid(_grade_label):
		insert_idx = _grade_label.get_index() + 1
	vbox.add_child(_message_label)
	vbox.move_child(_message_label, insert_idx)


# ---------------------------------------------------------------------------
# Score Counting Animation
# ---------------------------------------------------------------------------

func _start_score_animation(score: int):
	target_score = score
	display_score = 0.0
	anim_delay = 0.3
	animating_score = true
	set_process(true)

	_score_value_label = null
	if vbox:
		for child in vbox.get_children():
			if child.name == "ScoreLabelGroup" and child is VBoxContainer:
				if child.get_child_count() >= 2:
					_score_value_label = child.get_child(1)
				break


# ---------------------------------------------------------------------------
# Weapon Build Showcase
# ---------------------------------------------------------------------------

func show_weapon_build(weapon_manager: Node):
	if _weapon_build_container and is_instance_valid(_weapon_build_container):
		_weapon_build_container.get_parent().remove_child(_weapon_build_container)
		_weapon_build_container.queue_free()
		_weapon_build_container = null

	if not weapon_manager or not vbox:
		return

	var ids = weapon_manager.get_active_weapon_ids()
	if ids.size() == 0:
		return

	_weapon_build_container = VBoxContainer.new()
	_weapon_build_container.name = "WeaponBuildGroup"
	_weapon_build_container.add_theme_constant_override("separation", 4)
	_weapon_build_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var build_header = Label.new()
	build_header.text = "YOUR BUILD"
	build_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	build_header.add_theme_font_size_override("font_size", UIColors.FONT_TINY)
	build_header.add_theme_color_override("font_color", UIColors.TEXT_DIM)
	_weapon_build_container.add_child(build_header)

	var icon_row = HBoxContainer.new()
	icon_row.add_theme_constant_override("separation", 3)
	icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	icon_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_weapon_build_container.add_child(icon_row)

	for id in ids:
		var level = weapon_manager.get_weapon_level(id)
		var evolved = weapon_manager.is_weapon_evolved(id)
		var data = WeaponRegistry.get_weapon(id)
		var icon = _create_weapon_icon(data, level, evolved)
		icon_row.add_child(icon)

	var restart_idx = restart_btn.get_index() if restart_btn else vbox.get_child_count()
	vbox.add_child(_weapon_build_container)
	vbox.move_child(_weapon_build_container, restart_idx)


func _create_weapon_icon(data: Dictionary, level: int, evolved: bool) -> Control:
	var container = PanelContainer.new()
	container.custom_minimum_size = Vector2(40, 30)

	var glow: Color = data.get("glow_color", Color.WHITE)

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
	container.add_theme_stylebox_override("panel", style)

	var icon_vbox = VBoxContainer.new()
	icon_vbox.add_theme_constant_override("separation", 0)
	icon_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(icon_vbox)

	var icon_draw = Control.new()
	icon_draw.set_script(preload("res://scripts/ui/weapon_icon_draw.gd"))
	icon_draw.setup(data.get("id", ""), glow, evolved)
	icon_vbox.add_child(icon_draw)

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
	icon_vbox.add_child(lv_label)

	return container


# ---------------------------------------------------------------------------
# Styling helpers
# ---------------------------------------------------------------------------

func _style_panel():
	if not panel:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = UIColors.PANEL_BG
	sb.border_color = UIColors.PANEL_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", sb)


func _style_game_over_label():
	if not game_over_label:
		return
	game_over_label.add_theme_font_size_override("font_size", UIColors.FONT_TITLE + 2)
	game_over_label.add_theme_color_override("font_color", UIColors.RED)
	game_over_label.add_theme_color_override("font_outline_color", Color(0.3, 0.0, 0.0))
	game_over_label.add_theme_constant_override("outline_size", 3)
	game_over_label.text = "GAME OVER"


func _style_score_label():
	if not score_label:
		return
	score_label.add_theme_font_size_override("font_size", UIColors.FONT_HERO)
	score_label.add_theme_color_override("font_color", UIColors.TEXT_WHITE)


func _style_wave_label():
	if not wave_label:
		return
	wave_label.add_theme_font_size_override("font_size", UIColors.FONT_HEADING)
	wave_label.add_theme_color_override("font_color", UIColors.GOLD)


func _style_separator():
	if not separator:
		return
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.15)
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	sb.content_margin_left = 40
	sb.content_margin_right = 40
	separator.add_theme_stylebox_override("separator", sb)


func _style_restart_button():
	if not restart_btn:
		return
	restart_btn.add_theme_font_size_override("font_size", UIColors.FONT_BODY)
	restart_btn.add_theme_color_override("font_color", UIColors.TEXT_WHITE)
	restart_btn.custom_minimum_size.x = 200
	restart_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = UIColors.BTN_NORMAL_BG
	sb_normal.border_color = UIColors.BTN_NORMAL_BORDER
	sb_normal.set_border_width_all(1)
	sb_normal.set_corner_radius_all(3)
	sb_normal.set_content_margin_all(6)
	restart_btn.add_theme_stylebox_override("normal", sb_normal)

	var sb_hover := sb_normal.duplicate()
	sb_hover.bg_color = UIColors.BTN_HOVER_BG
	sb_hover.border_color = UIColors.BTN_HOVER_BORDER
	restart_btn.add_theme_stylebox_override("hover", sb_hover)

	var sb_pressed := sb_normal.duplicate()
	sb_pressed.bg_color = UIColors.BTN_PRESSED_BG
	restart_btn.add_theme_stylebox_override("pressed", sb_pressed)

	var sb_focus := sb_hover.duplicate()
	restart_btn.add_theme_stylebox_override("focus", sb_focus)


func _style_quit_button():
	if not quit_btn:
		return
	quit_btn.add_theme_font_size_override("font_size", UIColors.FONT_BODY)
	quit_btn.add_theme_color_override("font_color", UIColors.TEXT_WHITE)
	quit_btn.custom_minimum_size.x = 160
	quit_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = UIColors.BTN_DANGER_BG
	sb_normal.border_color = UIColors.BTN_DANGER_BORDER
	sb_normal.set_border_width_all(1)
	sb_normal.set_corner_radius_all(3)
	sb_normal.set_content_margin_all(5)
	quit_btn.add_theme_stylebox_override("normal", sb_normal)

	var sb_hover := sb_normal.duplicate()
	sb_hover.bg_color = Color(UIColors.BTN_DANGER_BG.r * 1.4, UIColors.BTN_DANGER_BG.g * 1.3, UIColors.BTN_DANGER_BG.b * 1.25, 0.95)
	sb_hover.border_color = Color(UIColors.BTN_DANGER_BORDER.r * 1.2, UIColors.BTN_DANGER_BORDER.g * 1.3, UIColors.BTN_DANGER_BORDER.b * 1.3, 0.8)
	quit_btn.add_theme_stylebox_override("hover", sb_hover)

	var sb_pressed := sb_normal.duplicate()
	sb_pressed.bg_color = Color(UIColors.BTN_DANGER_BG.r * 0.67, UIColors.BTN_DANGER_BG.g * 0.67, UIColors.BTN_DANGER_BG.b * 0.63, 1.0)
	quit_btn.add_theme_stylebox_override("pressed", sb_pressed)

	var sb_focus := sb_hover.duplicate()
	quit_btn.add_theme_stylebox_override("focus", sb_focus)


# ---------------------------------------------------------------------------
# Dynamic content builders
# ---------------------------------------------------------------------------

func _cleanup_dynamic_groups():
	animating_score = false
	set_process(false)
	_score_value_label = null

	if vbox:
		var to_remove: Array = []
		for child in vbox.get_children():
			if child.name.ends_with("Group"):
				to_remove.append(child)
		for child in to_remove:
			child.get_parent().remove_child(child)
			child.queue_free()

	if _grade_label and is_instance_valid(_grade_label):
		if _grade_label.get_parent():
			_grade_label.get_parent().remove_child(_grade_label)
		_grade_label.queue_free()
		_grade_label = null

	if _message_label and is_instance_valid(_message_label):
		if _message_label.get_parent():
			_message_label.get_parent().remove_child(_message_label)
		_message_label.queue_free()
		_message_label = null

	if _weapon_build_container and is_instance_valid(_weapon_build_container):
		if _weapon_build_container.get_parent():
			_weapon_build_container.get_parent().remove_child(_weapon_build_container)
		_weapon_build_container.queue_free()
		_weapon_build_container = null

	if score_label:
		score_label.visible = true
	if wave_label:
		wave_label.visible = true


func _replace_with_stat_pair(
	placeholder: Label,
	header_text: String,
	value_text: String,
	header_size: int,
	value_size: int,
	header_color: Color,
	value_color: Color
):
	var parent := placeholder.get_parent()
	var idx := placeholder.get_index()
	placeholder.visible = false

	var container := VBoxContainer.new()
	container.name = placeholder.name + "Group"
	container.add_theme_constant_override("separation", 1)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var lbl_header := Label.new()
	lbl_header.text = header_text
	lbl_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_header.add_theme_font_size_override("font_size", header_size)
	lbl_header.add_theme_color_override("font_color", header_color)
	container.add_child(lbl_header)

	var lbl_value := Label.new()
	lbl_value.text = value_text
	lbl_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_value.add_theme_font_size_override("font_size", value_size)
	lbl_value.add_theme_color_override("font_color", value_color)
	container.add_child(lbl_value)

	parent.add_child(container)
	parent.move_child(container, idx + 1)


func _clear_stats_container():
	if _stats_container and is_instance_valid(_stats_container):
		if _stats_container.get_parent():
			_stats_container.get_parent().remove_child(_stats_container)
		_stats_container.queue_free()
		_stats_container = null


func _build_stats_grid(extra: Dictionary):
	var parent := separator.get_parent()
	var sep_idx := separator.get_index()

	_stats_container = VBoxContainer.new()
	_stats_container.name = "StatsContainer"
	_stats_container.add_theme_constant_override("separation", 4)
	_stats_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var stat_labels := {
		"enemies_killed": "ENEMIES KILLED",
		"graze_count": "GRAZES",
		"accuracy": "ACCURACY",
		"time_survived": "TIME SURVIVED",
		"powerups_collected": "POWER-UPS",
		"max_combo": "MAX COMBO",
		"bosses_defeated": "BOSSES DEFEATED",
		"damage_dealt": "DAMAGE DEALT",
		"shots_fired": "SHOTS FIRED",
	}

	var row_index: int = 0
	for key in extra:
		var display_name: String = stat_labels.get(key, key.to_upper().replace("_", " "))
		var value = extra[key]
		var value_str: String

		if value is float:
			if key == "accuracy":
				value_str = "%.1f%%" % (value * 100.0) if value <= 1.0 else "%.1f%%" % value
			elif key == "time_survived":
				var mins := int(value) / 60
				var secs := int(value) % 60
				value_str = "%d:%02d" % [mins, secs]
			else:
				value_str = "%.1f" % value
		else:
			value_str = str(value)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.alignment = BoxContainer.ALIGNMENT_CENTER

		var lbl_name := Label.new()
		lbl_name.text = display_name
		lbl_name.add_theme_font_size_override("font_size", UIColors.FONT_TINY)
		lbl_name.add_theme_color_override("font_color", UIColors.TEXT_DIM)
		lbl_name.custom_minimum_size.x = 100
		lbl_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(lbl_name)

		var lbl_val := Label.new()
		lbl_val.text = value_str
		lbl_val.add_theme_font_size_override("font_size", UIColors.FONT_SMALL)
		lbl_val.add_theme_color_override("font_color", UIColors.TEXT_WHITE)
		lbl_val.custom_minimum_size.x = 60
		lbl_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(lbl_val)

		# Stats cascade animation
		row.modulate.a = 0.0
		var tween = create_tween()
		tween.tween_interval(row_index * 0.1)
		tween.tween_property(row, "modulate:a", 1.0, 0.2)

		_stats_container.add_child(row)
		row_index += 1

	parent.add_child(_stats_container)
	parent.move_child(_stats_container, sep_idx + 1)


func show_victory(score: int, wave: int, extra: Dictionary = {}):
	_is_victory = true
	_is_animating = false
	_cleanup_dynamic_groups()

	if game_over_label:
		game_over_label.text = "VICTORY!"
		game_over_label.add_theme_color_override("font_color", UIColors.GOLD)
		game_over_label.add_theme_color_override("font_outline_color", Color(0.4, 0.3, 0.0))

	var grade = _calculate_grade(score, wave)
	_show_grade(grade)

	var msg = _get_contextual_message(wave, score)
	_show_contextual_message(msg)

	if score_label:
		score_label.text = ""
		_replace_with_stat_pair(score_label, "FINAL SCORE", "0", UIColors.FONT_SMALL, UIColors.FONT_HERO,
			UIColors.TEXT_GRAY, UIColors.TEXT_WHITE)
	_start_score_animation(score)

	if wave_label:
		wave_label.text = ""
		_replace_with_stat_pair(wave_label, "WAVES SURVIVED", str(wave), UIColors.FONT_SMALL, UIColors.FONT_HEADING,
			UIColors.TEXT_GRAY, UIColors.GOLD)

	_clear_stats_container()
	if extra.size() > 0:
		_build_stats_grid(extra)

	# Gold panel for victory
	if panel:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.04, 0.04, 0.02, 0.94)
		sb.border_color = UIColors.PANEL_BORDER_GOLD
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(4)
		panel.add_theme_stylebox_override("panel", sb)

	show()

	if restart_btn:
		restart_btn.grab_focus()


# ---------------------------------------------------------------------------
# Button callbacks
# ---------------------------------------------------------------------------

func _on_restart():
	if _is_animating:
		return
	_is_animating = true
	hide()
	animating_score = false
	set_process(false)
	if game_over_label:
		game_over_label.text = "GAME OVER"
		game_over_label.add_theme_color_override("font_color", UIColors.RED)
		game_over_label.add_theme_color_override("font_outline_color", Color(0.3, 0.0, 0.0))
	_style_panel()
	_is_animating = false
	restart_requested.emit()


func _on_quit():
	if _is_animating:
		return
	_is_animating = true
	hide()
	animating_score = false
	set_process(false)
	_is_animating = false
	quit_requested.emit()
