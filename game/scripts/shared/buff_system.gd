## Service: Manages temporary buff effects on the player.
## Tracks active buffs with durations, applies and removes effects.
## Attach as a child node of the player.
extends Node

class_name BuffSystem

## Emitted when any buff starts or ends (for HUD updates).
signal buff_changed(buff_type: String, active: bool, remaining: float)

## Active buffs: { buff_name: { "remaining": float, "value": Variant } }
var _active_buffs: Dictionary = {}

## Reference to the player node.
var _player: CharacterBody2D = null


## Initializes the buff system with a player reference.
func setup(player: CharacterBody2D) -> void:
	_player = player


## Processes buff timers each frame. Call from player._physics_process().
func update(delta: float) -> void:
	var expired: Array[String] = []

	for buff_name in _active_buffs:
		_active_buffs[buff_name].remaining -= delta
		buff_changed.emit(buff_name, true, _active_buffs[buff_name].remaining)
		if _active_buffs[buff_name].remaining <= 0:
			expired.append(buff_name)

	for buff_name in expired:
		_remove_buff(buff_name)


## Applies an attack speed boost. Stacks duration, not intensity.
func apply_attack_speed_boost(duration: float = 5.0, multiplier: float = 1.5) -> void:
	if _active_buffs.has("attack_speed"):
		_active_buffs["attack_speed"].remaining += duration
	else:
		_active_buffs["attack_speed"] = { "remaining": duration, "value": multiplier }
	buff_changed.emit("attack_speed", true, _active_buffs["attack_speed"].remaining)


## Applies a shield (absorbs one hit, no duration limit but max 10s).
func apply_shield(duration: float = 10.0) -> void:
	_active_buffs["shield"] = { "remaining": duration, "value": 1 }
	if _player:
		_player.has_shield = true
	buff_changed.emit("shield", true, duration)


## Applies invincibility for a fixed duration.
func apply_invincibility(duration: float = 5.0) -> void:
	if _active_buffs.has("invincibility"):
		_active_buffs["invincibility"].remaining += duration
	else:
		_active_buffs["invincibility"] = { "remaining": duration, "value": true }
	if _player:
		_player.invincible = true
	buff_changed.emit("invincibility", true, _active_buffs["invincibility"].remaining)


## Called when the player is hit while shielded. Consumes the shield.
func consume_shield() -> void:
	if _active_buffs.has("shield"):
		_remove_buff("shield")


## Returns true if the given buff is currently active.
func is_active(buff_name: String) -> bool:
	return _active_buffs.has(buff_name)


## Returns the attack speed multiplier (1.0 if no buff).
func get_attack_speed_multiplier() -> float:
	if _active_buffs.has("attack_speed"):
		return _active_buffs["attack_speed"].value
	return 1.0


## Returns the remaining time for a buff (0.0 if inactive).
func get_remaining(buff_name: String) -> float:
	if _active_buffs.has(buff_name):
		return _active_buffs[buff_name].remaining
	return 0.0


## Removes a buff and reverts its effects on the player.
func _remove_buff(buff_name: String) -> void:
	if not _active_buffs.has(buff_name):
		return

	match buff_name:
		"shield":
			if _player:
				_player.has_shield = false
		"invincibility":
			if _player and not _player.bomb_active:
				_player.invincible = false
				_player.sprite.visible = true
				_player.sprite.modulate = Color.WHITE
		"attack_speed":
			pass  # No cleanup needed, multiplier just stops being applied

	_active_buffs.erase(buff_name)
	buff_changed.emit(buff_name, false, 0.0)


## Clears all active buffs (used on reset/death).
func clear_all() -> void:
	var buff_names: Array = _active_buffs.keys()
	for buff_name in buff_names:
		_remove_buff(buff_name)
	_active_buffs.clear()
