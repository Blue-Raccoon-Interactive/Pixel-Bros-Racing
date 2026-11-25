class_name Race
extends Node2D
## Cena de corrida. Carrega a pista escolhida e a entrega ao RaceManager,
## que cuida de checkpoints, voltas e largada.
##
## Estrutura esperada: Kart, RaceManager e Hud como filhos desta cena.

## Pista da corrida (uma cena herdada de track_base).
@export var track_scene: PackedScene
## Quantidade de karts de IA, sorteados entre os karts do jogo. 0 = sem IA.
@export var ai_count: int = 3
## Opcional (para testes): se preenchido, usa estes karts em vez de sortear.
@export var ai_kart_scenes: Array[PackedScene] = []

@onready var _race_manager: RaceManager = $RaceManager

## Pista instanciada (disponível depois do _ready).
var track: RaceTrack


func _ready() -> void:
	if track_scene == null:
		push_error("Race: nenhuma pista escolhida! Defina 'Track Scene' no inspetor.")
		return
		
	if GameState.has_selection:
		track_scene = load(GameState.TRACKS[GameState.selected_track].path)
		_spawn_selected_kart()

	var node: Node = track_scene.instantiate()
	if node == null:
		push_error("Race: 'Track Scene' está vazio ou inválido. Escolha um arquivo .tscn de pista.")
		return

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
	_spawn_ai_karts()


func _spawn_ai_karts() -> void:
	var scenes: Array[PackedScene] = _choose_ai_scenes()
	if scenes.is_empty():
		return

	var waypoints: Array[Marker2D] = track.get_waypoints()
	if waypoints.size() < 3:
		push_warning("Race: a pista tem %d waypoints (mínimo 3); karts de IA não criados." % waypoints.size())
		return

	for scene in scenes:
		if scene == null:
			continue

		var ai_kart := scene.instantiate() as Kart
		if ai_kart == null:
			push_error("Race: uma cena de IA não tem o script Kart na raiz.")
			continue

		# O kart_base traz PlayerController e câmera; a IA não usa nenhum dos dois.
		for node_name in ["PlayerController", "Camera2D"]:
			var unwanted: Node = ai_kart.get_node_or_null(node_name)
			if unwanted:
				unwanted.free()

		var ai := AiController.new()
		ai.kart = ai_kart
		ai.waypoints = waypoints
		ai_kart.add_child(ai)

		add_child(ai_kart)
		_race_manager.register_kart(ai_kart)
		# Na largada, cada IA escolhe o primeiro waypoint à sua frente.
		_race_manager.race_started.connect(ai.pick_start_target)


# Sorteia karts diferentes entre si e diferentes do kart do jogador.
func _choose_ai_scenes() -> Array[PackedScene]:
	if not ai_kart_scenes.is_empty():
		return ai_kart_scenes

	var player_path: String = ""
	if _race_manager.kart:
		player_path = _race_manager.kart.scene_file_path

	var pool: Array[PackedScene] = []
	for scene in GameState.KART_SCENES:
		if scene.resource_path != player_path:
			pool.append(scene)

	pool.shuffle()

	var result: Array[PackedScene] = []
	for i in mini(ai_count, pool.size()):
		result.append(pool[i])
	return result


func _spawn_selected_kart() -> void:
	var old: Kart = $Kart
	var new_kart: Kart = GameState.KART_SCENES[GameState.selected_kart].instantiate()
	remove_child(old)
	old.queue_free()
	new_kart.name = "Kart"
	add_child(new_kart)
	_race_manager.kart = new_kart
