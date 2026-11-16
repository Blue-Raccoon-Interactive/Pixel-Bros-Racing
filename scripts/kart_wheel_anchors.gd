
class_name KartWheelAnchors
extends Resource

## Posicao dos pneus traseiros de cada kart, no espaco local do kart.
## As medidas foram tiradas dos sprites de 32x32 (veja tools/apply_drift_setup.gd).
##
## O kart usa esta tabela quando a cena dele nao tem os marcadores
## "RearWheelLeft" e "RearWheelRight".

## Nome do kart -> posicao (x, y) do pneu traseiro esquerdo.
@export var left_wheels: Dictionary = {}
## Nome do kart -> posicao (x, y) do pneu traseiro direito.
@export var right_wheels: Dictionary = {}


## Devolve [esquerda, direita] do kart, ou um array vazio se ele nao estiver na tabela.
func get_anchors(kart_name: StringName) -> Array[Vector2]:
	var result: Array[Vector2] = []
	if not left_wheels.has(kart_name) or not right_wheels.has(kart_name):
		return result
	result.append(left_wheels[kart_name])
	result.append(right_wheels[kart_name])
	return result
