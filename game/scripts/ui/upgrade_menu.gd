extends CanvasLayer


signal upgrade_selected(data: Dictionary)

@onready var container: VBoxContainer = $Panel/VBoxContainer
@onready var title_label: Label = $Panel/VBoxContainer/Title

var upgrade_buttons: Array = []
var weapon_manager: Node = null
var _is_animating: bool = false

# Utility upgrades (non-weapon)
const UTILITY_UPGRADES = [
	{
		"type": "heal",
		"name": "Heal",
		"description": "Restore all HP",
		"icon": "res://assets/sprites/ui/icon_heal.png",
		"max_level": 99,
		"category": "utility",
	},
	{
		"type": "speed",
		"name": "Speed Up",
		"description": "+15 movement speed",
		"icon": "res://assets/sprites/ui/icon_speed.png",
		"max_level": 5,
		"category": "utility",
	},
	{
		"type": "max_hp",
		"name": "Max HP Up",
		"description": "+1 maximum health",
		"icon": "res://assets/sprites/ui/icon_defense.png",
		"max_level": 5,
		"category": "utility",
	},
	{
		"type": "bomb_stock",
		"name": "Bomb Stock",
		"description": "+1 bomb capacity",
		"icon": "res://assets/sprites/ui/icon_multishot.png",
		"max_level": 3,
		"category": "utility",
	},
	{
		"type": "damage_boost",
		"name": "Damage Boost",
		"description": "+1 damage (all weapons)",
		"icon": "res://assets/sprites/ui/icon_fireball.png",
		"max_level": 5,
		"category": "utility",
	},
]

var upgrade_levels: Dictionary = {}

const VIEWPORT_W = 320


func _ready():
	hide()
	reset_levels()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_style_panel()


func _unhandled_input(event: InputEvent):
	if not visible or _is_animating:
		return
	# Keyboard/gamepad navigation between cards
	if event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up"):
		var focused = get_viewport().gui_get_focus_owner()
		if focused == null and upgrade_buttons.size() > 0:
			_get_card_button(upgrade_buttons[0]).grab_focus()
			get_viewport().set_input_as_handled()


func _style_panel():
	var panel = $Panel
	if panel:
		var style = StyleBoxFlat.new()
		style.bg_color = UIColors.PANEL_BG
		style.set_content_margin_all(20)
		panel.add_theme_stylebox_override("panel", style)
	if title_label:
		title_label.add_theme_font_size_override("font_size", UIColors.FONT_HERO)
		title_label.add_theme_color_override("font_color", UIColors.CYAN)
		title_label.add_theme_color_override("font_outline_color", Color(0.0, 0.1, 0.2))
		title_label.add_theme_constant_override("outline_size", 3)


func reset_levels():
	upgrade_levels.clear()
	for u in UTILITY_UPGRADES:
		upgrade_levels[u.type] = 0


func show_upgrades():
	if _is_animating:
		return
	_is_animating = true

	var choices: Array = []

	# Build weapon pool
	var weapon_options: Array = _build_weapon_options()
	# Build utility pool
	var utility_options: Array = _build_utility_options()

	# Mix: aim for ~2 weapon options, 1 utility (or fill as available)
	weapon_options.shuffle()
	utility_options.shuffle()

	# Try to pick 2 weapons and 1 utility
	var weapon_picks = weapon_options.slice(0, min(2, weapon_options.size()))
	var utility_picks = utility_options.slice(0, min(1, utility_options.size()))

	choices.append_array(weapon_picks)
	choices.append_array(utility_picks)

	# Fill remaining slots to reach 3 choices
	var remaining_weapons = weapon_options.slice(weapon_picks.size())
	var remaining_utilities = utility_options.slice(utility_picks.size())
	var remaining: Array = []
	remaining.append_array(remaining_weapons)
	remaining.append_array(remaining_utilities)
	remaining.shuffle()

	while choices.size() < 3 and remaining.size() > 0:
		choices.append(remaining.pop_front())

	# Fallback: if still less than 3 choices, add heal as guaranteed filler
	while choices.size() < 3:
		choices.append({
			"id": "heal",
			"type": "heal",
			"category": "utility",
			"card_type": "utility",
			"icon": "res://assets/sprites/ui/icon_heal.png",
			"display_name": "Heal",
			"description": "Restore all HP",
			"level_tag": "",
		})

	# Clear old cards
	for btn in upgrade_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	upgrade_buttons.clear()

	# Create styled cards
	for option in choices:
		var card = _create_upgrade_card(option)
		container.add_child(card)
		upgrade_buttons.append(card)
		card.modulate.a = 0.0

	# Set up keyboard focus chain between cards
	_setup_focus_chain()

	show()
	get_tree().paused = true

	# Animate title fade in
	if title_label:
		title_label.modulate.a = 0.0
		var title_tween = create_tween()
		title_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		title_tween.set_ease(Tween.EASE_OUT)
		title_tween.set_trans(Tween.TRANS_CUBIC)
		title_tween.tween_property(title_label, "modulate:a", 1.0, 0.3)

	# Animate cards with stagger (fade only)
	for i in range(upgrade_buttons.size()):
		var card = upgrade_buttons[i]
		var tween = create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_BACK)
		tween.tween_interval(i * 0.15)
		tween.tween_property(card, "modulate:a", 1.0, 0.25)
		# After last card animates in, unlock input and grab focus
		if i == upgrade_buttons.size() - 1:
			tween.tween_callback(func():
				_is_animating = false
				if upgrade_buttons.size() > 0 and is_instance_valid(upgrade_buttons[0]):
					var btn = _get_card_button(upgrade_buttons[0])
					if btn:
						btn.grab_focus()
			)


func _setup_focus_chain():
	for i in range(upgrade_buttons.size()):
		var btn = _get_card_button(upgrade_buttons[i])
		if not btn:
			continue
		# Previous neighbor
		var prev_idx = i - 1 if i > 0 else upgrade_buttons.size() - 1
		var prev_btn = _get_card_button(upgrade_buttons[prev_idx])
		# Next neighbor
		var next_idx = i + 1 if i < upgrade_buttons.size() - 1 else 0
		var next_btn = _get_card_button(upgrade_buttons[next_idx])

		if prev_btn:
			btn.focus_neighbor_top = prev_btn.get_path()
			btn.focus_neighbor_left = prev_btn.get_path()
		if next_btn:
			btn.focus_neighbor_bottom = next_btn.get_path()
			btn.focus_neighbor_right = next_btn.get_path()


func _get_card_button(card: PanelContainer) -> Button:
	if not is_instance_valid(card):
		return null
	for child in card.get_children():
		if child is Button:
			return child
	return null


func _create_upgrade_card(option: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	var max_w = VIEWPORT_W - 40  # 20px padding each side
	card.custom_minimum_size = Vector2(max_w, 0)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Determine card style
	var card_type = option.get("card_type", "utility")
	var border_color: Color
	var bg_color: Color
	var tag_text: String = ""
	var tag_color: Color = Color.WHITE

	match card_type:
		"new_weapon":
			border_color = option.get("glow_color", UIColors.CYAN)
			bg_color = Color(border_color.r * 0.15, border_color.g * 0.15, border_color.b * 0.15, 0.95)
			tag_text = "NEW"
			tag_color = UIColors.CARD_TAG_NEW
		"level_up":
			border_color = option.get("glow_color", UIColors.CYAN)
			bg_color = Color(border_color.r * 0.12, border_color.g * 0.12, border_color.b * 0.12, 0.95)
			tag_text = option.get("level_tag", "")
			tag_color = UIColors.GOLD
		"evolution":
			border_color = UIColors.CARD_BORDER_EVOLUTION
			bg_color = Color(0.12, 0.1, 0.04, 0.95)
			tag_text = "EVOLVE"
			tag_color = UIColors.CARD_TAG_EVOLVE
		_:  # utility
			border_color = UIColors.CARD_BORDER_UTILITY
			bg_color = UIColors.CARD_BG_UTILITY
			tag_text = option.get("level_tag", "")
			tag_color = UIColors.CARD_TAG_LEVEL

	# Normal StyleBox
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	var bw = 3 if card_type == "evolution" else 2
	style.set_border_width_all(bw)
	style.border_color = border_color
	style.set_corner_radius_all(4)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", style)

	# Content: HBox with icon + VBox(name, description)
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	card.add_child(hbox)

	# Icon
	if option.has("icon") and option.icon != "":
		var icon_tex = load(option.icon)
		if icon_tex:
			var icon_rect = TextureRect.new()
			icon_rect.texture = icon_tex
			icon_rect.custom_minimum_size = Vector2(24, 24)
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			hbox.add_child(icon_rect)

	# Text column
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	# Top row: name + tag
	var top_row = HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 4)
	vbox.add_child(top_row)

	var name_label = Label.new()
	name_label.text = option.get("display_name", "???")
	name_label.add_theme_font_size_override("font_size", UIColors.FONT_BODY)
	var name_color = border_color if card_type != "utility" else UIColors.TEXT_WHITE
	name_label.add_theme_color_override("font_color", name_color)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	top_row.add_child(name_label)

	if tag_text != "":
		var tag_container = PanelContainer.new()
		var tag_style = StyleBoxFlat.new()

		match card_type:
			"new_weapon":
				tag_style.bg_color = Color(0.05, 0.25, 0.05, 0.95)
				tag_style.border_color = Color(UIColors.GREEN.r, UIColors.GREEN.g, UIColors.GREEN.b, 0.8)
			"evolution":
				tag_style.bg_color = Color(0.25, 0.18, 0.0, 0.95)
				tag_style.border_color = Color(UIColors.CARD_BORDER_EVOLUTION.r, UIColors.CARD_BORDER_EVOLUTION.g, UIColors.CARD_BORDER_EVOLUTION.b, 0.8)
				tag_text = "★ " + tag_text
			_:
				tag_style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
				tag_style.border_color = Color(UIColors.CARD_BORDER_UTILITY.r, UIColors.CARD_BORDER_UTILITY.g, UIColors.CARD_BORDER_UTILITY.b, 0.5)

		tag_style.set_border_width_all(1)
		tag_style.set_corner_radius_all(3)
		tag_style.content_margin_left = 4
		tag_style.content_margin_right = 4
		tag_style.content_margin_top = 1
		tag_style.content_margin_bottom = 1
		tag_container.add_theme_stylebox_override("panel", tag_style)

		var tag_label = Label.new()
		tag_label.text = tag_text
		var tag_font_size = UIColors.FONT_BODY if card_type == "evolution" else UIColors.FONT_SMALL
		tag_label.add_theme_font_size_override("font_size", tag_font_size)
		tag_label.add_theme_color_override("font_color", tag_color)
		tag_label.add_theme_constant_override("outline_size", 1)
		tag_label.add_theme_color_override("font_outline_color", UIColors.OUTLINE_BLACK)
		tag_container.add_child(tag_label)

		tag_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top_row.add_child(tag_container)

	# Description
	var desc_label = Label.new()
	desc_label.text = option.get("description", "")
	desc_label.add_theme_font_size_override("font_size", UIColors.FONT_SMALL)
	desc_label.add_theme_color_override("font_color", UIColors.CARD_DESC)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_label.clip_text = true
	desc_label.custom_minimum_size.x = max_w - 60
	vbox.add_child(desc_label)

	# Click button (invisible overlay, also handles keyboard focus)
	var click_btn = Button.new()
	click_btn.flat = true
	click_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	click_btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	click_btn.mouse_filter = Control.MOUSE_FILTER_PASS
	click_btn.focus_mode = Control.FOCUS_ALL
	click_btn.pressed.connect(_on_upgrade_chosen.bind(option))

	# Focus style for keyboard navigation visibility
	var focus_style = StyleBoxFlat.new()
	focus_style.bg_color = Color(0, 0, 0, 0)
	focus_style.border_color = UIColors.CYAN
	focus_style.set_border_width_all(2)
	focus_style.set_corner_radius_all(4)
	click_btn.add_theme_stylebox_override("focus", focus_style)
	# Keep normal/hover/pressed transparent
	var empty_style = StyleBoxEmpty.new()
	click_btn.add_theme_stylebox_override("normal", empty_style)
	click_btn.add_theme_stylebox_override("hover", empty_style)
	click_btn.add_theme_stylebox_override("pressed", empty_style)

	card.add_child(click_btn)

	# Hover effects (color only, no scale in managed layout)
	var original_bg = bg_color
	var hover_bg = Color(bg_color.r + 0.06, bg_color.g + 0.06, bg_color.b + 0.08, bg_color.a)

	# Also highlight on keyboard focus
	var _apply_highlight = func():
		style.border_color = border_color.lightened(0.4)
		style.bg_color = hover_bg
		card.add_theme_stylebox_override("panel", style)

	var _remove_highlight = func():
		style.border_color = border_color
		style.bg_color = original_bg
		card.add_theme_stylebox_override("panel", style)

	card.mouse_entered.connect(_apply_highlight)
	card.mouse_exited.connect(_remove_highlight)
	click_btn.focus_entered.connect(_apply_highlight)
	click_btn.focus_exited.connect(_remove_highlight)

	return card


func _build_weapon_options() -> Array:
	var options: Array = []
	if !weapon_manager:
		return options

	var all_ids = WeaponRegistry.get_all_weapon_ids()
	var active_ids = weapon_manager.get_active_weapon_ids()
	var can_add_new = weapon_manager.get_weapon_count() < weapon_manager.MAX_WEAPONS

	# Offer level-ups for existing weapons
	for id in active_ids:
		if weapon_manager.is_weapon_evolved(id):
			continue
		var data = WeaponRegistry.get_weapon(id)
		var level = weapon_manager.get_weapon_level(id)
		if weapon_manager.is_weapon_max_level(id):
			# Offer evolution
			var evo_id = data.get("evolves_to", "")
			if evo_id != "" and WeaponRegistry.EVOLUTIONS.has(evo_id):
				var evo = WeaponRegistry.EVOLUTIONS[evo_id]
				options.append({
					"id": id,
					"type": id,
					"category": "weapon",
					"card_type": "evolution",
					"icon": data.get("icon", ""),
					"display_name": evo.display_name,
					"description": evo.description,
					"glow_color": data.get("glow_color", Color.WHITE),
				})
		else:
			options.append({
				"id": id,
				"type": id,
				"category": "weapon",
				"card_type": "level_up",
				"icon": data.get("icon", ""),
				"display_name": data.display_name,
				"description": data.description,
				"level_tag": "Lv." + str(level) + "→" + str(level + 1),
				"glow_color": data.get("glow_color", Color.WHITE),
			})

	# Offer new weapons
	if can_add_new:
		for id in all_ids:
			if weapon_manager.has_weapon(id):
				continue
			var data = WeaponRegistry.get_weapon(id)
			options.append({
				"id": id,
				"type": id,
				"category": "weapon",
				"card_type": "new_weapon",
				"icon": data.get("icon", ""),
				"display_name": data.display_name,
				"description": data.description,
				"glow_color": data.get("glow_color", Color.WHITE),
			})

	return options


func _build_utility_options() -> Array:
	var options: Array = []
	for u in UTILITY_UPGRADES:
		var level = upgrade_levels.get(u.type, 0)
		if level < u.max_level:
			options.append({
				"id": u.type,
				"type": u.type,
				"category": "utility",
				"card_type": "utility",
				"icon": u.icon,
				"display_name": u.name,
				"description": u.description,
				"level_tag": "Lv." + str(level + 1),
			})
	return options


func _on_upgrade_chosen(data: Dictionary):
	if _is_animating:
		return
	_is_animating = true

	if data.category == "utility":
		upgrade_levels[data.type] = upgrade_levels.get(data.type, 0) + 1

	# Fade-out animation before closing
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_ease(Tween.EASE_IN)
	tween.set_trans(Tween.TRANS_CUBIC)

	# Fade out all cards
	for i in range(upgrade_buttons.size()):
		var card = upgrade_buttons[i]
		if is_instance_valid(card):
			tween.parallel().tween_property(card, "modulate:a", 0.0, 0.15)
	if title_label:
		tween.parallel().tween_property(title_label, "modulate:a", 0.0, 0.15)

	tween.tween_callback(func():
		_is_animating = false
		get_tree().paused = false
		hide()
		upgrade_selected.emit(data)
	)
