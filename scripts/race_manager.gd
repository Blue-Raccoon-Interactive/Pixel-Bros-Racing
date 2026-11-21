class_name RaceManager
extends Node

const COUNTDOWN_BEEP: AudioStream = preload("res://sound/sfx/race/largada_beep_contagem.wav")
const GO_BEEP: AudioStream = preload("res://sound/sfx/race/largada_go.wav")

var _start_audio: AudioStreamPlayer

## Contagem regressiva mudou. Texto vazio = esconder.
signal countdown_changed(text: String)
## Largada liberada (kart pode andar).
signal race_started
## Volta atual do kart do jogador mudou.
signal lap_changed(current_lap: int, total_laps: int)
## Qualquer kart fechou uma volta.
signal lap_completed(kart: Node2D, lap: int)
## Colocação atual do jogador mudou (1 = 1º lugar).
signal placement_changed(rank: int, total_racers: int)
## O kart do jogador terminou a corrida.
signal race_finished
## Abre a tela de classificação final assim que o jogador cruza a linha na última volta.
signal finish_results_opened(finished_karts: Array[Kart])
## Atualiza a tela de classificação conforme outros karts vão cruzando a linha final.
signal finish_results_updated(finished_karts: Array[Kart])

## Voltas da corrida. Se houver uma pista, o valor vem dela.
@export var total_laps: int = 3

@export_group("Referências")
## Kart do jogador (o HUD acompanha este).
@export var kart: Kart
## Pista da corrida. Se definida, checkpoints, largada e voltas vêm dela.
@export var track: RaceTrack
## Usado só quando NÃO há pista: checkpoints na ordem da corrida.
@export var checkpoints: Array[Area2D] = []

var is_finished: bool = false

# Quantos checkpoints cada kart já passou, na ordem correta.
# Chave: ID da instância do kart.
# O checkpoint 1 é a linha de largada: passar por ele de novo fecha uma volta.
var _progress_by_kart: Dictionary = {}

# Karts extras (IA), registrados pela cena da corrida.
var _extra_karts: Array[Kart] = []

var _last_player_rank: int = -1

# Ordem de chegada dos karts que já completaram todas as voltas.
var _finished_karts: Array[Kart] = []


## Registra um kart extra (IA): ele larga junto e conta checkpoints e voltas.
func register_kart(extra: Kart) -> void:
	if extra != null and not _extra_karts.has(extra):
		_extra_karts.append(extra)


# Kart do jogador primeiro, depois os extras.
func _all_karts() -> Array[Kart]:
	var result: Array[Kart] = []
	if kart != null:
		result.append(kart)
	result.append_array(_extra_karts)
	return result


func get_finished_karts() -> Array[Kart]:
	return _finished_karts.duplicate()


func _ready() -> void:
	_start_audio = AudioStreamPlayer.new()
	_start_audio.bus = "SFX"
	add_child(_start_audio)

	# Adiado para depois do _ready de todos os nós: o HUD já está conectado
	# aos sinais e a cena (ex.: Race) já pôde definir a pista.
	_initialize_race.call_deferred()


func _process(_delta: float) -> void:
	if kart == null or checkpoints.is_empty():
		return

	var racers: Array[Kart] = _all_karts()
	if racers.is_empty():
		return

	var current_rank: int = get_kart_placement(kart, racers)
	if current_rank != _last_player_rank:
		_last_player_rank = current_rank
		placement_changed.emit(current_rank, racers.size())


## Retorna a colocação de um kart (1 = 1º, 2 = 2º...).
func get_kart_placement(target: Kart, racers: Array[Kart] = []) -> int:
	if target == null:
		return 1
	var list: Array[Kart] = racers if not racers.is_empty() else _all_karts()
	var standings: Array[Kart] = get_standings(list)
	var idx: int = standings.find(target)
	return idx + 1 if idx != -1 else list.size()


## Retorna a lista de karts ordenada do 1º para o último lugar.
func get_standings(racers: Array[Kart] = []) -> Array[Kart]:
	var base: Array[Kart] = racers if not racers.is_empty() else _all_karts()
	var sorted: Array[Kart] = base.duplicate()
	sorted.sort_custom(_compare_racers)
	return sorted


func _compare_racers(a: Kart, b: Kart) -> bool:
	var fin_a: int = _finished_karts.find(a)
	var fin_b: int = _finished_karts.find(b)

	# Quem já terminou a corrida vem sempre antes de quem ainda está correndo,
	# respeitando a ordem exata de chegada.
	if fin_a != -1 or fin_b != -1:
		if fin_a == -1:
			return false
		if fin_b == -1:
			return true
		return fin_a < fin_b

	var prog_a: int = _progress_by_kart.get(a.get_instance_id(), 0)
	var prog_b: int = _progress_by_kart.get(b.get_instance_id(), 0)

	if prog_a != prog_b:
		return prog_a > prog_b

	var next_cp_a: Area2D = checkpoints[prog_a % checkpoints.size()]
	var next_cp_b: Area2D = checkpoints[prog_b % checkpoints.size()]

	if next_cp_a == null or next_cp_b == null:
		return false

	var dist_a: float = a.global_position.distance_to(next_cp_a.global_position)
	var dist_b: float = b.global_position.distance_to(next_cp_b.global_position)

	return dist_a < dist_b


func _initialize_race() -> void:
	_setup_from_track()
	_connect_checkpoints()
	await _begin_race()


func _setup_from_track() -> void:
	if track == null:
		return

	total_laps = track.laps
	checkpoints = track.get_checkpoints()

	_place_karts_at_start()


# Cada kart vai para um marcador de largada, na ordem. Se houver mais karts
# do que marcadores, os que sobram ficam em fila atrás do último marcador.
func _place_karts_at_start() -> void:
	var starts: Array[Marker2D] = track.get_start_positions()
	var karts: Array[Kart] = _all_karts()
	if karts.is_empty() or starts.is_empty():
		push_warning("RaceManager: a pista não tem posição de largada ou faltam karts.")
		return

	for i in karts.size():
		var marker: Marker2D = starts[mini(i, starts.size() - 1)]
		var rows_behind: int = maxi(0, i - (starts.size() - 1))
		var behind: Vector2 = Vector2.DOWN.rotated(marker.global_rotation) * 160.0 * rows_behind
		karts[i].global_position = marker.global_position + behind
		karts[i].global_rotation = marker.global_rotation
		karts[i].velocity = Vector2.ZERO


func _begin_race() -> void:
	lap_changed.emit(1, total_laps)
	_set_kart_active(false)

	var steps: Array[String] = ["3", "2", "1", "VAI!"]
	for step in steps:
		countdown_changed.emit(step)
		if step == "VAI!":
			_play_start_sound(GO_BEEP)
			_set_kart_active(true)
			race_started.emit()
		else:
			_play_start_sound(COUNTDOWN_BEEP)
		await get_tree().create_timer(1.0, false).timeout

	countdown_changed.emit("")


func _play_start_sound(sound: AudioStream) -> void:
	_start_audio.stream = sound
	_start_audio.play()


func _set_kart_active(active: bool) -> void:
	for racer in _all_karts():
		racer.set_physics_process(active)


func _connect_checkpoints() -> void:
	if checkpoints.is_empty():
		push_error("RaceManager: nenhum checkpoint foi configurado!")
		return

	# A ordem da corrida é a ordem da lista (na pista: a ordem na árvore).
	for checkpoint in checkpoints:
		if checkpoint == null:
			push_error("RaceManager: existe uma referência de checkpoint vazia!")
			return

		if not checkpoint.has_signal("checkpoint_passed"):
			push_error("RaceManager: um checkpoint não possui o sinal checkpoint_passed!")
			return

	# Conecta só depois de validar todos.
	for checkpoint in checkpoints:
		if not checkpoint.is_connected("checkpoint_passed", _on_checkpoint_passed):
			checkpoint.connect("checkpoint_passed", _on_checkpoint_passed)

	print("RaceManager: %d checkpoints conectados!" % checkpoints.size())


func _on_checkpoint_passed(checkpoint: Area2D, passed_kart: Node2D) -> void:
	if passed_kart == null or not (passed_kart is Kart):
		return

	var racer: Kart = passed_kart as Kart

	# Ordem do checkpoint = posição dele na lista, começando em 1.
	var checkpoint_order: int = checkpoints.find(checkpoint) + 1
	if checkpoint_order == 0:
		return

	var kart_id: int = racer.get_instance_id()
	var progress: int = _progress_by_kart.get(kart_id, 0)
	var expected: int = progress % checkpoints.size() + 1

	# Ignora checkpoints atravessados fora da sequência.
	if checkpoint_order != expected:
		return

	progress += 1
	_progress_by_kart[kart_id] = progress

	# Voltas fechadas = quantas vezes a sequência completa já foi cruzada
	# e a linha de largada (checkpoint 1) foi atravessada de novo.
	var laps_done: int = floori(float(progress - 1) / checkpoints.size())

	if checkpoint_order == 1 and laps_done > 0:
		lap_completed.emit(racer, laps_done)

	var completed_race: bool = checkpoint_order == 1 and laps_done >= total_laps
	if completed_race and not _finished_karts.has(racer):
		_finished_karts.append(racer)

		if racer == kart and not is_finished:
			is_finished = true
			lap_changed.emit(total_laps, total_laps)
			race_finished.emit()
			finish_results_opened.emit(get_finished_karts())
		elif is_finished:
			finish_results_updated.emit(get_finished_karts())
		return

	if racer != kart or is_finished:
		return

	lap_changed.emit(mini(laps_done + 1, total_laps), total_laps)
