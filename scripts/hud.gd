class_name Hud
extends CanvasLayer

## Gerenciador da corrida que este HUD acompanha.
@export var race_manager: RaceManager

@onready var lap_label: Label = $LapLabel
@onready var countdown_label: Label = $CountdownLabel


func _ready() -> void:
	if race_manager == null:
		push_error("Hud: race_manager não foi configurado!")
		return

	race_manager.countdown_changed.connect(_on_countdown_changed)
	race_manager.lap_changed.connect(_on_lap_changed)
	race_manager.race_finished.connect(_on_race_finished)


func _on_countdown_changed(text: String) -> void:
	countdown_label.text = text
	countdown_label.visible = text != ""


func _on_lap_changed(current_lap: int, total_laps: int) -> void:
	lap_label.text = "Volta %d/%d" % [current_lap, total_laps]


func _on_race_finished() -> void:
	lap_label.text += " (Finalizada!)"
	countdown_label.text = "FIM DE CORRIDA!"
	countdown_label.visible = true
