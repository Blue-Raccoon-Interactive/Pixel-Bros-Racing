@tool
class_name TrackWaypoints
extends Node2D
## Anexe ao nó 'Waypoints' da pista. No editor, desenha uma linha ligando os
## Marker2D na ordem, com setas indicando o sentido (o último liga ao primeiro).
## Não desenha nada durante o jogo.


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return

	var markers: Array[Marker2D] = []
	for child in get_children():
		if child is Marker2D:
			markers.append(child)

	if markers.size() < 2:
		return

	for i in markers.size():
		var from: Vector2 = to_local(markers[i].global_position)
		var to: Vector2 = to_local(markers[(i + 1) % markers.size()].global_position)
		draw_line(from, to, Color.YELLOW, 4.0)
		draw_circle(from, 14.0, Color.ORANGE)

		# Seta no meio do trecho, apontando o sentido.
		var dir: Vector2 = (to - from).normalized()
		var mid: Vector2 = (from + to) * 0.5
		draw_line(mid, mid - dir.rotated(0.5) * 36.0, Color.YELLOW, 4.0)
		draw_line(mid, mid - dir.rotated(-0.5) * 36.0, Color.YELLOW, 4.0)
