extends Node

signal lap_completed(lap: int)
signal race_finished

@export var total_laps: int = 3

@export_group("Referências")
@export var kart: CharacterBody2D
@export var lap_label: Label
@export var countdown_label: Label
@export var checkpoints: Array[Area2D] = []

var current_lap: int = 1
var is_finished: bool = false

# Guarda o próximo checkpoint esperado para cada kart.
# A chave é o ID da instância do kart.
var _next_checkpoint_by_kart: Dictionary = {}

# Voltas já completadas por kart (ID da instância -> quantidade).
var _laps_by_kart: Dictionary = {}

# Karts que já terminaram a corrida (ID da instância -> true).
var _finished_karts: Dictionary = {}

# Karts que passaram por todos os checkpoints e só falta recruzar o 1.
var _sequence_done_by_kart: Dictionary = {}


func _ready() -> void:
	_connect_checkpoints()
	_update_lap_label()
	_start_countdown()


func _connect_checkpoints() -> void:
	if checkpoints.is_empty():
		push_error("RaceManager: nenhum checkpoint foi configurado!")
		return

	var found_orders: Dictionary = {}

	# Primeiro, verifica se todos os checkpoints estão configurados.
	for checkpoint in checkpoints:
		if checkpoint == null:
			push_error("RaceManager: existe uma referência de checkpoint vazia!")
			return

		if not checkpoint.has_signal("checkpoint_passed"):
			push_error("RaceManager: um checkpoint não possui o sinal checkpoint_passed!")
			return

		var order: int = checkpoint.get("checkpoint_order")

		if order < 1 or order > checkpoints.size():
			push_error("RaceManager: ordem de checkpoint inválida: %d" % order)
			return

		if found_orders.has(order):
			push_error("RaceManager: ordem de checkpoint duplicada: %d" % order)
			return

		found_orders[order] = true

	# Garante que a sequência seja 1, 2, 3... N.
	for order in range(1, checkpoints.size() + 1):
		if not found_orders.has(order):
			push_error("RaceManager: está faltando o checkpoint %d!" % order)
			return

	# Conecta os sinais depois de validar todos.
	for checkpoint in checkpoints:
		var callback := Callable(self, "_on_checkpoint_passed")

		if not checkpoint.is_connected("checkpoint_passed", callback):
			checkpoint.connect("checkpoint_passed", callback)

	print("RaceManager: %d checkpoints conectados!" % checkpoints.size())


func _update_lap_label() -> void:
	if lap_label:
		if is_finished:
			lap_label.text = "Volta %d/%d (Finalizada!)" % [total_laps, total_laps]
		else:
			lap_label.text = "Volta %d/%d" % [min(current_lap, total_laps), total_laps]


func _start_countdown() -> void:
	if kart:
		kart.set_physics_process(false)

	if countdown_label:
		countdown_label.visible = true

	var steps := ["3", "2", "1", "VAI!"]

	for i in range(steps.size()):
		if countdown_label:
			countdown_label.text = steps[i]

		if i == steps.size() - 1:
			if kart:
				kart.set_physics_process(true)

		await get_tree().create_timer(1.0).timeout

	if countdown_label:
		countdown_label.visible = false


func _on_checkpoint_passed(checkpoint_order: int, passed_kart: Node2D) -> void:
	if passed_kart == null:
		return

	var kart_id: int = passed_kart.get_instance_id()

	# Kart que já terminou a corrida não conta mais nada.
	if _finished_karts.has(kart_id):
		return

	# Cada kart começa esperando o checkpoint 1.
	if not _next_checkpoint_by_kart.has(kart_id):
		_next_checkpoint_by_kart[kart_id] = 1

	var expected_checkpoint: int = _next_checkpoint_by_kart[kart_id]

	# Ignora checkpoints atravessados fora da sequência.
	if checkpoint_order != expected_checkpoint:
		return

	# Avança para o próximo checkpoint.
	var next_order: int = checkpoint_order + 1

	# Passou pelo último: a sequência está completa, falta cruzar a linha (checkpoint 1).
	if next_order > checkpoints.size():
		next_order = 1
		_sequence_done_by_kart[kart_id] = true

	# Cruzou o checkpoint 1 com a sequência completa: fecha a volta.
	if checkpoint_order == 1 and _sequence_done_by_kart.get(kart_id, false):
		_sequence_done_by_kart[kart_id] = false
		_complete_lap(passed_kart, kart_id)

	_next_checkpoint_by_kart[kart_id] = next_order


func _complete_lap(passed_kart: Node2D, kart_id: int) -> void:
	var laps_done: int = int(_laps_by_kart.get(kart_id, 0)) + 1
	_laps_by_kart[kart_id] = laps_done

	var is_player: bool = passed_kart == kart

	if is_player:
		current_lap = laps_done + 1
		_update_lap_label()

	lap_completed.emit(laps_done)

	if laps_done >= total_laps:
		_finished_karts[kart_id] = true

		if is_player:
			is_finished = true
			race_finished.emit()
			_on_race_finished()


func _on_race_finished() -> void:
	_update_lap_label()

	if countdown_label:
		countdown_label.text = "FIM DE CORRIDA!"
		countdown_label.visible = true
