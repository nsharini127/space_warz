## Aggregate: Orchestrates the entire mecha boss fight.
## Manages state transitions, part coordination, attack timing,
## and the combination into a single boss form.
extends Node2D

## Emitted when all parts and the combined form are defeated.
signal boss_fully_defeated(pos: Vector2)

## Emitted when an individual part is destroyed.
signal part_destroyed_signal(part_type: int, pos: Vector2)

## Emitted when any part fires a bullet (relayed to game.gd).
signal enemy_shoot(bullet_scene: PackedScene, pos: Vector2, dir: Vector2, dmg: int)

## Emitted for score/kill tracking when fully defeated.
signal enemy_killed(points: int, pos: Vector2)

## Boss fight states.
enum State { ENTERING, FORMATION, DEGRADING, COMBINING, COMBINED }

## Current fight state.
var state: int = State.ENTERING

## Active parts indexed by PartType.
var parts: Dictionary = {}

## Reference to the combined boss (created during COMBINING phase).
var combined_boss_node: Node2D = null

## Player reference for aimed attacks.
var player_ref: CharacterBody2D = null

## Timing.
var _time_alive: float = 0.0
var _attack_timer: float = 2.5
var _combine_timer: float = 30.0
var _enter_speed: float = 80.0

## Points awarded on full defeat.
var points: int = 2000

## Scene for spawning individual parts.
var boss_part_scene: PackedScene = preload("res://scenes/enemies/boss/boss_part.tscn")

## Tracks whether all parts have reached formation.
var _parts_in_position: int = 0
var _total_parts: int = 6

## Group strafe offset for lateral movement.
var _strafe_offset: float = 0.0

const ATTACK_INTERVAL: float = 2.0
const COMBINE_TIMEOUT: float = 30.0
const COMBINE_THRESHOLD: int = 2
const VIEWPORT_W: float = 320.0


## Sets the player reference for aimed attacks.
func set_player(p: CharacterBody2D) -> void:
	player_ref = p


func _ready() -> void:
	_spawn_all_parts()


## Spawns all 6 parts at their entry positions.
func _spawn_all_parts() -> void:
	var part_types: Array = [
		BossPart.PartType.HEAD,
		BossPart.PartType.ARM_L,
		BossPart.PartType.ARM_R,
		BossPart.PartType.TORSO,
		BossPart.PartType.LEG_L,
		BossPart.PartType.LEG_R,
	]

	for pt in part_types:
		var part: BossPart = boss_part_scene.instantiate() as BossPart
		part.setup(pt, player_ref)
		part.position = MechaFormation.get_entry_position(pt)

		# Configure sprite based on part config
		var config: Dictionary = BossPart.PART_CONFIGS[pt]
		var part_sprite: Sprite2D = part.get_node("Sprite2D")
		if part_sprite:
			part_sprite.texture = load(config.sprite)
			part_sprite.scale = config.scale

		# Configure collision shape (inside HitboxArea child)
		var col_shape: CollisionShape2D = part.get_node("HitboxArea/CollisionShape2D")
		if col_shape:
			var shape := RectangleShape2D.new()
			shape.size = config.collision_size
			col_shape.shape = shape

		part.part_destroyed.connect(_on_part_destroyed)
		part.part_shoot.connect(_on_part_shoot)

		add_child(part)
		parts[pt] = part

	_total_parts = parts.size()


func _process(delta: float) -> void:
	_time_alive += delta

	match state:
		State.ENTERING:
			_process_entering(delta)
		State.FORMATION:
			_process_formation(delta)
		State.DEGRADING:
			_process_degrading(delta)
		State.COMBINING:
			_process_combining(delta)
		State.COMBINED:
			_process_combined(delta)


## ENTERING: Move parts from entry positions to robot formation.
func _process_entering(delta: float) -> void:
	_parts_in_position = 0
	for pt in parts:
		var part: BossPart = parts[pt]
		if not is_instance_valid(part):
			_parts_in_position += 1
			continue
		var target: Vector2 = MechaFormation.get_formation_position(pt)
		part.position = MechaFormation.move_toward_target(
			part.position, target, delta, _enter_speed
		)
		if MechaFormation.is_at_target(part.position, target):
			_parts_in_position += 1

	if _parts_in_position >= _total_parts:
		state = State.FORMATION
		_attack_timer = ATTACK_INTERVAL


## FORMATION: Parts are in robot shape, coordinated attacks.
func _process_formation(delta: float) -> void:
	_update_strafe(delta)
	_process_attacks(delta)

	# Transition to DEGRADING after first part is destroyed
	# (handled in _on_part_destroyed)


## DEGRADING: Some parts destroyed, remaining parts compensate slightly.
func _process_degrading(delta: float) -> void:
	_update_strafe(delta)
	_process_attacks(delta)

	# Check combination conditions
	_combine_timer -= delta
	var alive_count: int = _get_alive_part_count()

	if alive_count <= COMBINE_THRESHOLD or _combine_timer <= 0:
		_start_combining()


## COMBINING: Parts move to center to merge.
func _process_combining(delta: float) -> void:
	var center: Vector2 = MechaFormation.get_combination_position()
	var all_at_center: bool = true

	for pt in parts:
		var part: BossPart = parts[pt]
		if not is_instance_valid(part) or not part.is_alive:
			continue
		part.position = MechaFormation.move_toward_target(
			part.position, center, delta, 120.0
		)
		if not MechaFormation.is_at_target(part.position, center, 5.0):
			all_at_center = false

	if all_at_center:
		_finalize_combination()


## COMBINED: Delegates to the combined boss node.
func _process_combined(_delta: float) -> void:
	# Combined boss handles its own logic
	pass


## Updates lateral strafe for all alive parts.
func _update_strafe(delta: float) -> void:
	var new_offset: float = MechaFormation.get_strafe_offset(_time_alive)
	var strafe_delta: float = new_offset - _strafe_offset
	_strafe_offset = new_offset

	for pt in parts:
		var part: BossPart = parts[pt]
		if is_instance_valid(part) and part.is_alive:
			part.position.x += strafe_delta
			# Clamp within screen bounds
			part.position.x = clampf(part.position.x, 20.0, VIEWPORT_W - 20.0)


## Processes attack timing and tells each part to fire.
func _process_attacks(delta: float) -> void:
	_attack_timer -= delta
	if _attack_timer <= 0:
		# Adjust interval based on surviving parts (fewer parts = slightly faster)
		var alive: int = _get_alive_part_count()
		var speed_bonus: float = 1.0 - ((_total_parts - alive) * 0.05)
		_attack_timer = ATTACK_INTERVAL * max(speed_bonus, 0.7)

		var player_pos: Vector2 = _get_player_position()
		for pt in parts:
			var part: BossPart = parts[pt]
			if is_instance_valid(part) and part.is_alive:
				part.fire(player_pos)


## Handles a part being destroyed.
func _on_part_destroyed(part_type: int, pos: Vector2) -> void:
	part_destroyed_signal.emit(part_type, pos)

	# Remove from tracking
	if parts.has(part_type):
		parts.erase(part_type)

	# Transition from FORMATION to DEGRADING on first part loss
	if state == State.FORMATION:
		state = State.DEGRADING
		_combine_timer = COMBINE_TIMEOUT

	# Check if all parts are gone (shouldn't happen normally, but safety)
	if _get_alive_part_count() == 0 and state != State.COMBINED:
		_on_fully_defeated()


## Relays bullet signals from parts to the game.
func _on_part_shoot(bullet_scene: PackedScene, pos: Vector2, dir: Vector2, dmg: int) -> void:
	enemy_shoot.emit(bullet_scene, pos, dir, dmg)


## Initiates the combination phase.
func _start_combining() -> void:
	state = State.COMBINING


## Creates the combined boss from surviving parts.
func _finalize_combination() -> void:
	# Gather surviving part types and total remaining HP
	var surviving_types: Array[int] = []
	var total_remaining_hp: int = 0

	for pt in parts:
		var part: BossPart = parts[pt]
		if is_instance_valid(part) and part.is_alive:
			surviving_types.append(pt)
			total_remaining_hp += part.current_hp
			part.queue_free()

	parts.clear()

	# Create the combined boss
	var combined_script = preload("res://scripts/enemies/boss/combined_boss.gd")
	combined_boss_node = CharacterBody2D.new()
	combined_boss_node.set_script(combined_script)
	combined_boss_node.position = MechaFormation.get_combination_position()
	add_child(combined_boss_node)

	# Setup the combined boss
	combined_boss_node.setup(surviving_types, total_remaining_hp, player_ref)
	combined_boss_node.enemy_shoot.connect(_on_part_shoot)
	combined_boss_node.combined_boss_died.connect(_on_combined_boss_died)

	state = State.COMBINED


## Called when the combined boss form is defeated.
func _on_combined_boss_died(pos: Vector2) -> void:
	_on_fully_defeated()


## Final defeat - emit signals for game.gd integration.
func _on_fully_defeated() -> void:
	var pos: Vector2 = MechaFormation.get_combination_position()
	if combined_boss_node and is_instance_valid(combined_boss_node):
		pos = combined_boss_node.global_position
	enemy_killed.emit(points, pos)
	boss_fully_defeated.emit(pos)


## Returns the number of alive parts.
func _get_alive_part_count() -> int:
	var count: int = 0
	for pt in parts:
		var part: BossPart = parts[pt]
		if is_instance_valid(part) and part.is_alive:
			count += 1
	return count


## Returns the total HP across all alive parts and combined boss.
func get_total_hp() -> int:
	var total: int = 0
	for pt in parts:
		var part: BossPart = parts[pt]
		if is_instance_valid(part) and part.is_alive:
			total += part.current_hp
	if combined_boss_node and is_instance_valid(combined_boss_node) and combined_boss_node.is_alive:
		total += combined_boss_node.current_hp
	return total


## Returns the max total HP (sum of all part max HPs).
func get_total_max_hp() -> int:
	var total: int = 0
	for config in BossPart.PART_CONFIGS.values():
		total += config.hp
	return total


## Returns the player's position or a default fallback.
func _get_player_position() -> Vector2:
	if player_ref and is_instance_valid(player_ref) and player_ref.is_alive:
		return player_ref.global_position
	return Vector2(VIEWPORT_W / 2.0, 384)
