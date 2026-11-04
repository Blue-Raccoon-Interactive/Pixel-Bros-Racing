extends Node

signal lap_completed(lap: int)
signal race_finished

@export var total_laps: int = 3
@export var kart: CharacterBody2D
@export var lap_label: Label
@export var countdown_label: Label

var current_lap: int = 1
var is_finished: bool = false
var _next_checkpoint: int = 0
var _has_started: bool = false
var _total_checkpoints: int = 4


func _ready() -> void:
	_resolve_nodes()
	_update_lap_label()
	_start_countdown()


func _resolve_nodes() -> void:
	if not kart:
		kart = get_parent().find_child("Kart", true, false) as CharacterBody2D
	if not lap_label:
		lap_label = get_parent().find_child("LapLabel", true, false) as Label
	if not countdown_label:
		countdown_label = get_parent().find_child("CountdownLabel", true, false) as Label

	var areas := get_parent().find_children("*", "Area2D", true, false)
	for area in areas:
		if area.has_signal("passed"):
			area.passed.connect(_on_checkpoint_passed)


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


func _on_checkpoint_passed(checkpoint_index: int) -> void:
	if is_finished:
		return

	if checkpoint_index == _next_checkpoint:
		if checkpoint_index == 0:
			if _has_started:
				lap_completed.emit(current_lap)
				if current_lap >= total_laps:
					is_finished = true
					race_finished.emit()
					_on_race_finished()
					return
				current_lap += 1
				_update_lap_label()
			else:
				_has_started = true
			_next_checkpoint = 1
		else:
			_next_checkpoint = (checkpoint_index + 1) % _total_checkpoints


func _on_race_finished() -> void:
	_update_lap_label()
	if countdown_label:
		countdown_label.text = "FIM DE CORRIDA!"
		countdown_label.visible = true
