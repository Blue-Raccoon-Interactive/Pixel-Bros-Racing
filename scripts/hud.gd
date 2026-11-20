class_name Hud
extends CanvasLayer

## Gerenciador da corrida que este HUD acompanha.
@export var race_manager: RaceManager

@onready var lap_label: Label = $LapLabel
@onready var countdown_label: Label = $CountdownLabel
@onready var position_label: Label = $PositionLabel
@onready var results_panel: Control = $ResultsPanel
@onready var results_label: Label = $ResultsPanel/ResultsLabel


func _ready() -> void:
	if results_panel != null:
		results_panel.visible = false

	if race_manager == null:
		push_error("Hud: race_manager não foi configurado!")
		return

	race_manager.countdown_changed.connect(_on_countdown_changed)
	race_manager.lap_changed.connect(_on_lap_changed)
	race_manager.placement_changed.connect(_on_placement_changed)
	race_manager.race_finished.connect(_on_race_finished)
	race_manager.finish_results_opened.connect(_on_finish_results_opened)
	race_manager.finish_results_updated.connect(_on_finish_results_updated)


func _on_countdown_changed(text: String) -> void:
	countdown_label.text = text
	countdown_label.visible = text != ""


func _on_lap_changed(current_lap: int, total_laps: int) -> void:
	lap_label.text = "%d/%d" % [current_lap, total_laps]


func _on_placement_changed(rank: int, total_racers: int) -> void:
	position_label.text = "%dº/%d" % [rank, total_racers]


func _on_race_finished() -> void:
	lap_label.text = "Volta %d/%d (Finalizada!)" % [race_manager.total_laps, race_manager.total_laps]
	countdown_label.text = ""
	countdown_label.visible = false


func _on_finish_results_opened(finished_karts: Array[Kart]) -> void:
	_render_finished_list(finished_karts)
	if results_panel != null:
		results_panel.visible = true


func _on_finish_results_updated(finished_karts: Array[Kart]) -> void:
	_render_finished_list(finished_karts)


func _render_finished_list(finished_karts: Array[Kart]) -> void:
	if results_label == null:
		return

	var lines: PackedStringArray = ["CLASSIFICAÇÃO"]
	for i in finished_karts.size():
		var racer: Kart = finished_karts[i]
		lines.append("%dº - %s" % [i + 1, _get_kart_display_name(racer)])

	results_label.text = "\n".join(lines)


func _get_kart_display_name(racer: Kart) -> String:
	if racer == null:
		return "Kart"

	var raw_name: Variant = racer.get("kart_name")
	var custom_name: String = str(raw_name).strip_edges() if raw_name != null else ""

	if not custom_name.is_empty():
		return "%s (Você)" % custom_name if racer == race_manager.kart else custom_name

	return "Você" if racer == race_manager.kart else racer.name
