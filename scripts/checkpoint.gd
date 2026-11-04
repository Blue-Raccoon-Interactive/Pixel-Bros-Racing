extends Area2D

signal passed(index: int)

@export var index: int = 0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if "surface_multiplier" in body or body is CharacterBody2D:
		passed.emit(index)
