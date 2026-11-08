extends Area2D

## Emitido quando um kart atravessa o checkpoint.
## A ordem NÃO é definida aqui: vem da posição do checkpoint na pista
## (nó "Checkpoints"), calculada pelo RaceManager.
signal checkpoint_passed(checkpoint: Area2D, kart: Node2D)


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("race_kart"):
		return

	checkpoint_passed.emit(self, body)
