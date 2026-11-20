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
## O kart do jogador terminou a corrida.
signal race_finished

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


## Registra um kart extra (IA): ele larga junto e conta checkpoints e voltas.
func register_kart(extra: Kart) -> void:
	if extra != null and not _extra_karts.has(extra):
		_extra_karts.append(extra)


# Kart do jogador primeiro, depois os extras.
func _all_karts() -> Array[Kart]:
	var result: Array[Kart] = []
	if kart:
		result.append(kart)
	result.append_array(_extra_karts)
	return result


func _ready() -> void:
	_start_audio = AudioStreamPlayer.new()
	_start_audio.bus = "SFX"
	add_child(_start_audio)

	# Adiado para depois do _ready de todos os nós: o HUD já está conectado
	# aos sinais e a cena (ex.: Race) já pôde definir a pista.
	_initialize_race.call_deferred()


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
			_play_start_sound(GO_BEEP) #<-Som do "Go" 
			_set_kart_active(true)
			race_started.emit()
		else:
			_play_start_sound(COUNTDOWN_BEEP) #<- Som do "Beep"
		await get_tree().create_timer(1.0).timeout


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
	# Por enquanto a corrida acaba quando o kart do jogador termina.
	if is_finished or passed_kart == null:
		return

	# Ordem do checkpoint = posição dele na lista, começando em 1.
	var checkpoint_order: int = checkpoints.find(checkpoint) + 1
	if checkpoint_order == 0:
		return

	var kart_id: int = passed_kart.get_instance_id()
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
		lap_completed.emit(passed_kart, laps_done)

	if passed_kart != kart:
		return

	lap_changed.emit(mini(laps_done + 1, total_laps), total_laps)

	if laps_done >= total_laps:
		is_finished = true
		race_finished.emit()
