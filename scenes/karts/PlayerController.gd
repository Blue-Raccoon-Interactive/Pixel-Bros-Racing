
extends Node

@export var kart: Kart


func _physics_process(_delta: float) -> void:
	if kart == null:
		return

	var steering: float = Input.get_axis(
		"steer_left", "steer_right"
	)

	var throttle: float = 0.0

	if Input.is_action_pressed("accelerate"):
		throttle = 1.0
	elif Input.is_action_pressed("brake"):
		throttle = -1.0

	kart.set_controls(steering, throttle)
