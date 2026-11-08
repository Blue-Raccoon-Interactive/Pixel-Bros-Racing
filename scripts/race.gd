class_name Race
extends Node2D
## Cena de corrida. Carrega a pista escolhida e a entrega ao RaceManager,
## que cuida de checkpoints, voltas e largada.
##
## Estrutura esperada: Kart, RaceManager e Hud como filhos desta cena.

## Pista da corrida (uma cena herdada de track_base).
@export var track_scene: PackedScene

@onready var _race_manager: RaceManager = $RaceManager

## Pista instanciada (disponível depois do _ready).
var track: RaceTrack


func _ready() -> void:
	if track_scene == null:
		push_error("Race: nenhuma pista escolhida! Defina 'Track Scene' no inspetor.")
		return

	var node: Node = track_scene.instantiate()
	var new_track := node as RaceTrack
	if new_track == null:
		node.queue_free()
		push_error("Race: a cena escolhida não tem o script RaceTrack na raiz. Use uma cena herdada de track_base.")
		return

	track = new_track
	add_child(track)
	# Primeira posição na árvore = desenhada atrás do kart.
	move_child(track, 0)

	_race_manager.track = track
