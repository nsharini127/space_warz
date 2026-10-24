extends Node
## Space Warz glove input for Godot 4.x.
##
## Add this script as an Autoload named "GloveInput"
## (Project > Project Settings > Globals/Autoload).
##
## It listens for glove data from the bridge and turns it into normal Godot input
## actions (move_left, bomb, ui_accept, ...). The game keeps using Input.get_axis /
## is_action_pressed as usual, and the keyboard still works alongside the glove.
##
## To make the glove react to the game, call from anywhere:
##     GloveInput.send_event("hit")       # what each event does is set in the bridge's config.json
##     GloveInput.pulse(0, 200)           # or drive an output channel directly

## Which glove this game instance listens to (players are numbered from 1).
@export var player := 1
@export var listen_port := 5005
@export var bridge_host := "127.0.0.1"
@export var bridge_port := 5006
## Also turn tilt into ui_up/down/left/right presses so menus can be used with the glove.
@export var menu_nav_from_tilt := true

## Tilt -> movement actions: [negative direction, positive direction].
## Change these names to match your game's Input Map.
const AXIS_X := ["move_left", "move_right"]
const AXIS_Y := ["move_up", "move_down"]
## Glove buttons (names from config.json "controls.buttons") -> actions they press.
const BUTTONS := {
	"a": ["bomb", "ui_accept"],
	"b": ["focus"],
	"c": ["pause"],
}
const MENU_THRESHOLD := 0.6   # how far to tilt before a menu move happens
const MENU_REPEAT := 0.35     # seconds between repeats while held
const STALE_AFTER := 0.5      # no data for this long -> release everything

signal glove_connected
signal glove_disconnected

var connected := false
var x := 0.0
var y := 0.0
var buttons := {}
var raw := {}

var _udp := PacketPeerUDP.new()
var _last_state := -1000.0
var _held := {}               # actions currently held by us
var _menu_dir := Vector2i.ZERO
var _menu_timer := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keep working in pause menus
	# Several game windows on one PC: start each with e.g.
	#   game.exe -- --glove-player=2 --glove-port=5015
	# and set "player_ports": {"2": 5015} in the bridge's config.json
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--glove-player="):
			player = int(arg.get_slice("=", 1))
		elif arg.begins_with("--glove-port="):
			listen_port = int(arg.get_slice("=", 1))
	var err := _udp.bind(listen_port, "127.0.0.1")
	if err != OK:
		push_warning("GloveInput: could not listen on UDP port %d (error %d)" % [listen_port, err])
	_udp.set_dest_address(bridge_host, bridge_port)


func _exit_tree() -> void:
	_release_all()
	_udp.close()


func _process(delta: float) -> void:
	while _udp.get_available_packet_count() > 0:
		var msg = JSON.parse_string(_udp.get_packet().get_string_from_utf8())
		if typeof(msg) != TYPE_DICTIONARY or int(msg.get("player", 0)) != player:
			continue
		match str(msg.get("t", "")):
			"state":
				_last_state = _now()
				if not connected:
					connected = true
					glove_connected.emit()
				x = float(msg.get("x", 0.0))
				y = float(msg.get("y", 0.0))
				raw = msg.get("raw", {})
				_apply_buttons(msg.get("buttons", {}))
			"disconnected":
				_release_all()
	if connected and _now() - _last_state > STALE_AFTER:
		_release_all()
	_set_axis(AXIS_X, x)
	_set_axis(AXIS_Y, y)
	if menu_nav_from_tilt:
		_menu_nav(delta)


# ---------------------------------------------------------------- game -> glove

func send_event(event_name: String) -> void:
	_send({"t": "event", "name": event_name, "player": player})


func pulse(channel: int, ms: int) -> void:
	_send({"t": "pulse", "player": player, "ch": channel, "ms": ms})


func set_output(channel: int, on: bool) -> void:
	_send({"t": "out", "player": player, "ch": channel, "value": 1 if on else 0})


func _send(msg: Dictionary) -> void:
	_udp.put_packet(JSON.stringify(msg).to_utf8_buffer())


# ---------------------------------------------------------------- glove -> input actions

func _set_axis(pair: Array, v: float) -> void:
	if v < 0.0:
		_hold(pair[0], -v)
		_unhold(pair[1])
	elif v > 0.0:
		_hold(pair[1], v)
		_unhold(pair[0])
	else:
		_unhold(pair[0])
		_unhold(pair[1])


func _hold(action: String, strength: float) -> void:
	if InputMap.has_action(action):
		Input.action_press(action, clampf(strength, 0.0, 1.0))
		_held[action] = true


func _unhold(action: String) -> void:
	if _held.has(action):
		Input.action_release(action)
		_held.erase(action)


func _apply_buttons(b: Dictionary) -> void:
	for btn in BUTTONS:
		var now_pressed := bool(b.get(btn, false))
		if now_pressed != bool(buttons.get(btn, false)):
			for action in BUTTONS[btn]:
				_emit_action(action, now_pressed)
	buttons = b.duplicate()


## Sends a real input event, so both polling (is_action_pressed) and
## event handlers (_input / _unhandled_input / UI focus) see it.
func _emit_action(action: String, pressed: bool) -> void:
	if not InputMap.has_action(action):
		return
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	ev.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(ev)


func _menu_nav(delta: float) -> void:
	var dir := Vector2i.ZERO
	if absf(x) >= MENU_THRESHOLD or absf(y) >= MENU_THRESHOLD:
		if absf(x) > absf(y):
			dir.x = 1 if x > 0.0 else -1
		else:
			dir.y = 1 if y > 0.0 else -1
	if dir == Vector2i.ZERO:
		_menu_dir = dir
		return
	_menu_timer -= delta
	if dir != _menu_dir or _menu_timer <= 0.0:
		_menu_dir = dir
		_menu_timer = MENU_REPEAT
		var action := "ui_right" if dir.x > 0 else "ui_left" if dir.x < 0 else "ui_down" if dir.y > 0 else "ui_up"
		_emit_action(action, true)
		_emit_action(action, false)


func _release_all() -> void:
	for action in _held.keys():
		Input.action_release(action)
	_held.clear()
	for btn in BUTTONS:
		if bool(buttons.get(btn, false)):
			for action in BUTTONS[btn]:
				_emit_action(action, false)
	buttons = {}
	x = 0.0
	y = 0.0
	if connected:
		connected = false
		glove_disconnected.emit()


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
