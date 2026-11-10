class_name GrassZone
extends Area2D
## Zona de piso lento (grama, areia...). Ao entrar, o kart registra a zona;
## ao sair, remove. Com várias zonas ao mesmo tempo, vale a mais lenta.

## Multiplicador da velocidade máxima dentro da zona (1.0 = normal).
@export_range(0.1, 1.0, 0.05) var multiplier: float = 0.6


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("enter_surface"):
		body.enter_surface(self)


func _on_body_exited(body: Node2D) -> void:
	if body.has_method("exit_surface"):
		body.exit_surface(self)
