extends CanvasLayer


signal resume_requested
signal quit_requested

@onready var panel: PanelContainer = $Panel
@onready var vbox: VBoxContainer = $Panel/VBoxContainer
@onready var pause_label: Label = $Panel/VBoxContainer/PauseLabel
@onready var resume_btn: Button = $Panel/VBoxContainer/ResumeButton
@onready var quit_btn: Button = $Panel/VBoxContainer/QuitButton

var _is_animating: bool = false


func _ready():
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS

	_style_panel()
	_style_pause_label()
	_style_resume_button()
	_style_quit_button()
	_add_hint_label()

	if resume_btn:
		resume_btn.pressed.connect(_on_resume)
	if quit_btn:
		quit_btn.pressed.connect(_on_quit)


func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("pause") and visible and not _is_animating:
		_on_resume()
		get_viewport().set_input_as_handled()


func show_pause():
	_is_animating = true
	panel.modulate.a = 0.0
	show()
	get_tree().paused = true

	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(panel, "modulate:a", 1.0, 0.2)
	tween.tween_callback(func():
		_is_animating = false
		if resume_btn:
			resume_btn.grab_focus()
	)


func _on_resume():
	if _is_animating:
		return
	_is_animating = true
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(panel, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func():
		_is_animating = false
		hide()
		get_tree().paused = false
		resume_requested.emit()
	)


func _on_quit():
	if _is_animating:
		return
	_is_animating = true
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(panel, "modulate:a", 0.0, 0.15)
	tween.tween_callback(func():
		_is_animating = false
		hide()
		get_tree().paused = false
		quit_requested.emit()
	)


# ---------------------------------------------------------------------------
# Styling
# ---------------------------------------------------------------------------

func _style_panel():
	var bg := StyleBoxFlat.new()
	bg.bg_color = UIColors.PANEL_BG
	bg.border_color = UIColors.PANEL_BORDER
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", bg)


func _style_pause_label():
	pause_label.add_theme_font_size_override("font_size", UIColors.FONT_TITLE)
	pause_label.add_theme_color_override("font_color", UIColors.CYAN)
	pause_label.add_theme_color_override("font_outline_color", Color(0.0, 0.1, 0.3))
	pause_label.add_theme_constant_override("outline_size", 3)


func _style_resume_button():
	var normal := _make_button_style(UIColors.BTN_NORMAL_BG, UIColors.BTN_NORMAL_BORDER)
	var hover := _make_button_style(UIColors.BTN_HOVER_BG, UIColors.BTN_HOVER_BORDER)
	var pressed := _make_button_style(UIColors.BTN_PRESSED_BG, UIColors.BTN_NORMAL_BORDER)

	resume_btn.add_theme_stylebox_override("normal", normal)
	resume_btn.add_theme_stylebox_override("hover", hover)
	resume_btn.add_theme_stylebox_override("pressed", pressed)
	resume_btn.add_theme_stylebox_override("focus", hover.duplicate())

	resume_btn.add_theme_font_size_override("font_size", UIColors.FONT_BODY)
	resume_btn.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	resume_btn.add_theme_color_override("font_hover_color", Color(0.85, 0.95, 1.0))
	resume_btn.add_theme_color_override("font_pressed_color", Color(0.5, 0.7, 0.9))
	resume_btn.add_theme_color_override("font_focus_color", Color(0.85, 0.95, 1.0))

	resume_btn.custom_minimum_size.x = 180
	resume_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _style_quit_button():
	var normal := _make_button_style(UIColors.BTN_DANGER_BG, UIColors.BTN_DANGER_BORDER)
	var hover := _make_button_style(
		Color(0.22, 0.1, 0.1, 0.95),
		Color(0.8, 0.45, 0.45)
	)
	var pressed := _make_button_style(
		Color(0.12, 0.06, 0.06, 0.95),
		UIColors.BTN_DANGER_BORDER
	)

	quit_btn.add_theme_stylebox_override("normal", normal)
	quit_btn.add_theme_stylebox_override("hover", hover)
	quit_btn.add_theme_stylebox_override("pressed", pressed)
	quit_btn.add_theme_stylebox_override("focus", hover.duplicate())

	quit_btn.add_theme_font_size_override("font_size", UIColors.FONT_BODY)
	quit_btn.add_theme_color_override("font_color", Color(0.85, 0.6, 0.6))
	quit_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.75, 0.75))
	quit_btn.add_theme_color_override("font_pressed_color", Color(0.6, 0.4, 0.4))
	quit_btn.add_theme_color_override("font_focus_color", Color(1.0, 0.75, 0.75))

	quit_btn.custom_minimum_size.x = 140
	quit_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func _make_button_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	style.content_margin_left = 12
	style.content_margin_right = 12
	return style


func _add_hint_label():
	var hint := Label.new()
	hint.text = "Press ESC to resume"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", UIColors.FONT_SMALL)
	hint.add_theme_color_override("font_color", UIColors.TEXT_DIM)
	vbox.add_child(hint)
