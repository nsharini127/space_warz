extends Node


signal counter_updated(stage_counter: int, total_counter: int, counter_color: String)

enum CounterColor { GREEN, BLUE }

var stage_counter: int = 0
var total_counter: int = 0
var counter_color: CounterColor = CounterColor.GREEN
var color_threshold: int = 500


func reset():
	stage_counter = 0
	total_counter = 0
	counter_color = CounterColor.GREEN
	_emit_update()


func reset_stage():
	stage_counter = 0
	_emit_update()


func add_gems(count: int):
	stage_counter = min(stage_counter + count, 9999)
	total_counter = min(total_counter + count, 99999)
	_update_color()
	_emit_update()


func on_player_death():
	stage_counter = stage_counter / 3
	total_counter = total_counter / 3
	_update_color()
	_emit_update()


func on_bomb_used():
	stage_counter = int(stage_counter * 0.67)
	_update_color()
	_emit_update()


func get_boss_kill_bonus() -> int:
	return 10000 + stage_counter * 100


func get_color_string() -> String:
	return "GREEN" if counter_color == CounterColor.GREEN else "BLUE"


func get_color() -> Color:
	if counter_color == CounterColor.GREEN:
		return Color(0.2, 1.0, 0.4)
	else:
		return Color(0.3, 0.5, 1.0)


func should_drop_more_gems(shot_focused: bool) -> bool:
	if counter_color == CounterColor.GREEN and !shot_focused:
		return true  # Rapid shot + green = more gems
	if counter_color == CounterColor.BLUE and shot_focused:
		return true  # Focus shot + blue = more gems
	return false


func _update_color():
	var cycle_pos = stage_counter % (color_threshold * 2)
	if cycle_pos < color_threshold:
		counter_color = CounterColor.GREEN
	else:
		counter_color = CounterColor.BLUE


func _emit_update():
	counter_updated.emit(stage_counter, total_counter, get_color_string())
