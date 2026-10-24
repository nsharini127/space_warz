extends CharacterBody2D


signal player_hit
signal player_died
signal bomb_activated
signal gem_collected(gem_value: int)
signal power_item_collected
signal bomb_item_collected
signal buff_item_collected(buff_type: String)

const VIEWPORT_W = 320
const VIEWPORT_H = 480
const PLAYER_AREA_TOP = VIEWPORT_H * 0.15

@export var base_speed: float = 120.0
@export var base_damage: int = 1
@export var base_max_hp: int = 5
@export var invincibility_time: float = 1.0

var current_hp: int = 5
var max_hp: int = 5
var speed: float = 120.0
var damage: int = 1  # Global damage modifier for all weapons
var pierce: int = 0  # Global pierce modifier for all weapons
var invincible: bool = false
var invincible_timer: float = 0.0
var flash_timer: float = 0.0
var is_alive: bool = true
var has_shield: bool = false

## Buff system manages temporary effects (attack speed, shield, invincibility).
var buff_system: BuffSystem = null

# MHF mechanics
var is_focused: bool = false
var focus_speed_mult: float = 0.4
var bomb_count: int = 3
var max_bombs: int = 6
var power_level: int = 1  # 1-8
var bomb_active: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var hitbox: Area2D = $Hitbox
@onready var engine_sprite: AnimatedSprite2D = $EngineSprite

# Hitbox indicator (created in code)
var hitbox_indicator: Node2D = null
var shield_visual: Node2D = null

# Graze system
var graze_area: Area2D = null
var graze_count: int = 0
var graze_cooldowns: Dictionary = {}


func _ready():
	hitbox.area_entered.connect(_on_hitbox_area_entered)
	_create_hitbox_indicator()
	_create_graze_area()
	_setup_engine_animation()
	_create_buff_system()
	reset()


func _create_buff_system():
	buff_system = BuffSystem.new()
	buff_system.setup(self)
	add_child(buff_system)

	# Shield visual overlay
	shield_visual = Node2D.new()
	shield_visual.set_script(preload("res://scripts/player/shield_visual.gd"))
	shield_visual.setup(self)
	shield_visual.z_index = 5
	add_child(shield_visual)


func _create_hitbox_indicator():
	hitbox_indicator = Node2D.new()
	hitbox_indicator.z_index = 10
	hitbox_indicator.visible = false
	hitbox_indicator.set_script(preload("res://scripts/player/hitbox_indicator.gd"))
	add_child(hitbox_indicator)


func _create_graze_area():
	graze_area = Area2D.new()
	graze_area.collision_layer = 0
	graze_area.collision_mask = 8  # EnemyBullet
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 16.0
	shape.shape = circle
	graze_area.add_child(shape)
	graze_area.area_entered.connect(_on_graze_area_entered)
	add_child(graze_area)


func _setup_engine_animation():
	if !engine_sprite:
		return
	var sheet = load("res://assets/sprites/player/space/engine_base_sheet.png")
	if !sheet:
		return

	var frames = SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_speed("idle", 10)
	frames.set_animation_loop("idle", true)

	# Sheet is 192x96, 4 frames of 48x96
	var frame_w = 48
	var frame_h = 96
	for i in range(4):
		var atlas = AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(i * frame_w, 0, frame_w, frame_h)
		frames.add_frame("idle", atlas)

	engine_sprite.sprite_frames = frames
	engine_sprite.play("idle")


func reset():
	position = Vector2(VIEWPORT_W / 2, VIEWPORT_H * 0.8)
	current_hp = base_max_hp
	max_hp = base_max_hp
	speed = base_speed
	damage = base_damage
	pierce = 0
	power_level = 1
	bomb_count = 3
	bomb_active = false
	is_focused = false
	is_alive = true
	invincible = false
	visible = true
	has_shield = false
	graze_count = 0
	graze_cooldowns.clear()
	if buff_system:
		buff_system.clear_all()
	if sprite:
		sprite.modulate = Color.WHITE
	if hitbox_indicator:
		hitbox_indicator.visible = false


func _physics_process(delta: float):
	if !is_alive:
		return

	# Focus mode
	is_focused = Input.is_action_pressed("focus")
	if hitbox_indicator:
		hitbox_indicator.visible = is_focused

	# Movement
	var input_dir = Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_up", "move_down")

	if input_dir.length() > 0:
		input_dir = input_dir.normalized()

	var current_speed = speed * (focus_speed_mult if is_focused else 1.0)
	velocity = input_dir * current_speed
	move_and_slide()

	# Clamp to play area
	position.x = clamp(position.x, 8, VIEWPORT_W - 8)
	position.y = clamp(position.y, PLAYER_AREA_TOP, VIEWPORT_H - 8)

	# Sprite tilt based on horizontal movement
	if sprite:
		if input_dir.x < -0.1:
			sprite.rotation = deg_to_rad(-10)
		elif input_dir.x > 0.1:
			sprite.rotation = deg_to_rad(10)
		else:
			sprite.rotation = 0

	# Bomb input
	if Input.is_action_just_pressed("bomb") and bomb_count > 0 and !bomb_active:
		activate_bomb()

	# Invincibility
	if invincible:
		invincible_timer -= delta
		flash_timer -= delta
		if flash_timer <= 0:
			flash_timer = 0.08
			sprite.visible = !sprite.visible
		if invincible_timer <= 0:
			invincible = false
			sprite.visible = true
			sprite.modulate = Color.WHITE

	# Update buff system
	if buff_system:
		buff_system.update(delta)

	# Clean graze cooldowns
	var to_remove: Array = []
	for id in graze_cooldowns:
		if !is_instance_id_valid(id):
			to_remove.append(id)
	for id in to_remove:
		graze_cooldowns.erase(id)


func activate_bomb():
	bomb_count -= 1
	bomb_active = true
	invincible = true
	invincible_timer = 1.5
	bomb_activated.emit()

	# Bomb effect node
	var bomb_node = Node2D.new()
	bomb_node.set_script(preload("res://scripts/player/bomb.gd"))
	bomb_node.global_position = global_position
	get_tree().current_scene.add_child(bomb_node)
	bomb_node.activate()
	bomb_node.bomb_finished.connect(_on_bomb_finished)


func _on_bomb_finished():
	bomb_active = false
	if invincible_timer <= 0:
		invincible = false
		sprite.visible = true
		sprite.modulate = Color.WHITE


func take_damage(dmg: int = 1):
	if invincible or !is_alive or bomb_active:
		return

	# Shield absorbs the hit without losing HP
	if has_shield and buff_system:
		buff_system.consume_shield()
		invincible = true
		invincible_timer = 0.5
		return

	current_hp -= dmg
	player_hit.emit()

	if current_hp <= 0:
		current_hp = 0
		die()
	else:
		invincible = true
		invincible_timer = invincibility_time
		sprite.modulate = Color(1, 0.3, 0.3)


func die():
	is_alive = false
	visible = false
	player_died.emit()


func _on_hitbox_area_entered(area: Area2D):
	if area.is_in_group("enemy_bullet"):
		var dmg = area.get_meta("damage") if area.has_meta("damage") else 1
		take_damage(dmg)
		area.queue_free()
	elif area.is_in_group("enemy_body"):
		take_damage(1)
	elif area.is_in_group("gem"):
		var gem_val = area.gem_value if "gem_value" in area else 1
		gem_collected.emit(gem_val)
		area.queue_free()
	elif area.is_in_group("pickup"):
		var item = area
		match item.item_type:
			0:  # POWER
				power_item_collected.emit()
			1:  # BOMB
				bomb_item_collected.emit()
			2:  # LIFE
				current_hp = min(current_hp + 1, max_hp)
			3:  # ATTACK_SPEED
				if buff_system:
					buff_system.apply_attack_speed_boost(5.0, 1.5)
				buff_item_collected.emit("attack_speed")
			4:  # SHIELD
				if buff_system:
					buff_system.apply_shield(10.0)
				buff_item_collected.emit("shield")
			5:  # INVINCIBILITY
				if buff_system:
					buff_system.apply_invincibility(4.0)
				buff_item_collected.emit("invincibility")
		item.queue_free()


func _on_graze_area_entered(area: Area2D):
	if !area.is_in_group("enemy_bullet"):
		return
	var id = area.get_instance_id()
	if graze_cooldowns.has(id):
		return
	graze_cooldowns[id] = true
	graze_count += 1
	# Spawn small spark
	var spark = Node2D.new()
	spark.set_script(preload("res://scripts/effects/graze_spark.gd"))
	spark.global_position = area.global_position
	get_tree().current_scene.add_child(spark)


## Returns the current attack speed multiplier from buffs (1.0 = normal).
func get_attack_speed_multiplier() -> float:
	if buff_system:
		return buff_system.get_attack_speed_multiplier()
	return 1.0


func add_power():
	if power_level >= 8:
		# Overflow: converte em heal se HP nao esta cheio
		if current_hp < max_hp:
			current_hp = min(current_hp + 1, max_hp)
		# Se HP ja cheio, power overflow nao faz nada extra (score ja foi dado)
		return
	power_level = min(power_level + 1, 8)


func add_bomb():
	bomb_count = min(bomb_count + 1, max_bombs)


func apply_upgrade(data: Dictionary):
	# Only utility upgrades now - weapons handled by weapon_manager
	match data.type:
		"speed":
			speed += 15
		"max_hp":
			max_hp += 1
			current_hp += 1
		"heal":
			current_hp = max_hp
		"bomb_stock":
			add_bomb()
		"damage_boost":
			damage += 1
