
extends Area2D

# Número que identifica a ordem deste checkpoint na pista.
@export_range(1, 100) var checkpoint_order: int = 1

# Emitido quando um kart atravessa o checkpoint.
signal checkpoint_passed(checkpoint_order: int, kart: Node2D)


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("race_kart"):
		return

	checkpoint_passed.emit(checkpoint_order, body)
