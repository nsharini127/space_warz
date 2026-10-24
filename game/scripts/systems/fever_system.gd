## Fever Mode: rapid kills within a time window trigger a power fantasy state.
## During fever, gems drop at 2x rate and kills extend the duration.
extends Node

signal fever_started
signal fever_ended

var kill_timestamps: Array[float] = []  # timestamps das ultimas kills
var is_fever_active: bool = false
var fever_timer: float = 0.0

const KILL_WINDOW: float = 2.0       # janela de tempo para contar combo
const KILLS_TO_FEVER: int = 12        # kills necessarias na janela
const FEVER_DURATION: float = 5.0     # duracao do fever
const FEVER_EXTEND: float = 1.0       # segundos ganhos por kill durante fever

var current_combo: int = 0


func register_kill() -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	kill_timestamps.append(now)

	# Limpa timestamps fora da janela
	_clean_old_timestamps(now)

	current_combo = kill_timestamps.size()

	if is_fever_active:
		# Estender fever por cada kill durante o modo
		fever_timer = minf(fever_timer + FEVER_EXTEND, FEVER_DURATION + 3.0)
	else:
		# Verificar se atingiu threshold para ativar fever
		if current_combo >= KILLS_TO_FEVER:
			_activate_fever()


func _process(delta: float) -> void:
	if is_fever_active:
		fever_timer -= delta
		if fever_timer <= 0.0:
			_deactivate_fever()

	# Atualizar combo mesmo fora do fever (para HUD futura)
	var now: float = Time.get_ticks_msec() / 1000.0
	_clean_old_timestamps(now)
	current_combo = kill_timestamps.size()


func _activate_fever() -> void:
	is_fever_active = true
	fever_timer = FEVER_DURATION
	kill_timestamps.clear()  # Resetar combo ao ativar
	current_combo = 0
	fever_started.emit()


func _deactivate_fever() -> void:
	is_fever_active = false
	fever_timer = 0.0
	fever_ended.emit()


func reset() -> void:
	kill_timestamps.clear()
	is_fever_active = false
	fever_timer = 0.0
	current_combo = 0


func get_combo() -> int:
	return current_combo


func get_gem_multiplier() -> float:
	return 2.0 if is_fever_active else 1.0


func _clean_old_timestamps(now: float) -> void:
	while kill_timestamps.size() > 0 and (now - kill_timestamps[0]) > KILL_WINDOW:
		kill_timestamps.pop_front()
