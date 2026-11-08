@tool
class_name RaceTrack
extends Node2D
## Raiz de toda pista. Esperado na estrutura:
##   Checkpoints     (Node2D com instancias de checkpoint.tscn, na ordem da corrida)
##   StartPositions  (Node2D com Marker2D; o primeiro é a posição do jogador)

## Nome da pista (para menus futuros).
@export var track_name: String = "Pista"
## Quantidade de voltas desta pista.
@export var laps: int = 3


func _ready() -> void:
	if not Engine.is_editor_hint():
		return

	# Atualiza os avisos do editor quando o designer adiciona/remove filhos.
	for node_name in ["Checkpoints", "StartPositions"]:
		var container: Node = get_node_or_null(node_name)
		if container and not container.child_order_changed.is_connected(update_configuration_warnings):
			container.child_order_changed.connect(update_configuration_warnings)

	update_configuration_warnings()


## Checkpoints da pista, na ordem em que aparecem na árvore.
func get_checkpoints() -> Array[Area2D]:
	var result: Array[Area2D] = []
	var container: Node = get_node_or_null("Checkpoints")
	if container == null:
		return result

	for child in container.get_children():
		if child is Area2D:
			result.append(child)
	return result


## Marcadores de largada, na ordem da árvore.
## Use global_position e global_rotation de cada um para posicionar o kart.
func get_start_positions() -> Array[Marker2D]:
	var result: Array[Marker2D] = []
	var container: Node = get_node_or_null("StartPositions")
	if container == null:
		return result

	for child in container.get_children():
		if child is Marker2D:
			result.append(child)
	return result


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()

	if get_node_or_null("Checkpoints") == null:
		warnings.append("Falta o nó 'Checkpoints' (Node2D) na raiz da pista.")
	elif get_checkpoints().is_empty():
		warnings.append("Adicione pelo menos um checkpoint dentro de 'Checkpoints'. O primeiro é a linha de largada.")

	if get_node_or_null("StartPositions") == null:
		warnings.append("Falta o nó 'StartPositions' (Node2D) na raiz da pista.")
	elif get_start_positions().is_empty():
		warnings.append("Adicione pelo menos um Marker2D dentro de 'StartPositions'.")

	return warnings
