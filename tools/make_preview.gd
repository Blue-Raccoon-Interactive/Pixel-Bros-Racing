extends SceneTree

## Gera a imagem de referencia do sistema de rastros (docs/preview_drift.png).

const OUTPUT := "res://docs/preview_drift.png"

var _kart: Kart
var _marks: DriftMarks


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var background := ColorRect.new()
	background.color = Color(0.19, 0.19, 0.2)
	background.size = Vector2(4000, 4000)
	background.position = Vector2(-1000, -1000)
	world.add_child(background)

	_kart = (load("res://scenes/karts/kart_01.tscn") as PackedScene).instantiate() as Kart
	_kart.position = Vector2(600, 600)
	world.add_child(_kart)
	var controller: Node = _kart.get_node_or_null("PlayerController")
	if controller != null:
		controller.set_physics_process(false)
	await physics_frame
	await physics_frame
	for child in world.get_children():
		if child is DriftMarks:
			_marks = child
	if _marks == null:
		quit(1)
		return
	for i in range(300):
		_kart.set_controls(1.0 if i > 120 else 0.0, 1.0)
		await physics_frame
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://docs/preview_drift.png")
	print("preview: res://docs/preview_drift.png")

	# Segunda imagem: a marca acompanhando o caminho do pneu.
	_marks.orientation_mode = DriftMarks.OrientationMode.TRAVEL
	_marks.clear_marks()
	_kart.global_position = Vector2(600, 600)
	_kart.global_rotation = 0.0
	for i in range(300):
		_kart.set_controls(1.0 if i > 120 else 0.0, 1.0)
		await physics_frame
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://docs/preview_drift_travel.png")
	print("preview: res://docs/preview_drift_travel.png")
	quit()
