extends Area2D

@export var multiplier: float = 0.6


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if "surface_multiplier" in body:
		body.surface_multiplier = multiplier


func _on_body_exited(body: Node2D) -> void:
	if "surface_multiplier" in body:
		body.surface_multiplier = 1.0
