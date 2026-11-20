class_name AiController
extends Node
## Controlador de IA: dirige o kart seguindo os waypoints da pista.
## Usa a mesma interface do PlayerController: kart.set_controls(direção, aceleração).

@export var kart: Kart

## Waypoints na ordem do percurso (a cena da corrida preenche).
var waypoints: Array[Marker2D] = []

@export_group("Ajustes")
## Distância (px) para considerar o waypoint alcançado.
@export var reach_radius: float = 160.0
## Reação da direção ao ângulo até o alvo (maior = vira mais forte).
@export var steer_gain: float = 2.0
## Ângulo (rad) a partir do qual é curva fechada (0.9 ≈ 50°).
@export var sharp_turn_angle: float = 0.9
## Em curva fechada, solta o acelerador acima dessa velocidade (px/s).
@export var corner_speed: float = 250.0
## Tempo (s) quase parado até tentar dar ré.
@export var stuck_time_limit: float = 1.2
## Duração (s) da ré ao destravar.
@export var reverse_duration: float = 0.8
## Variação lateral aleatória (px): cada IA escolhe uma "faixa" diferente.
## Mantenha menor que a metade da largura da pista. 0 = todas na linha central.
@export var lane_range: float = 40.0

var _index: int = 0
var _stuck_time: float = 0.0
var _reverse_time: float = 0.0
var _lane_offset: float = 0.0


func _ready() -> void:
	_lane_offset = randf_range(-lane_range, lane_range)


## Escolhe como alvo o waypoint mais próximo que esteja à frente do kart.
## A corrida chama isso na largada.
func pick_start_target() -> void:
	if kart == null or waypoints.is_empty():
		return

	var forward: Vector2 = Vector2.UP.rotated(kart.global_rotation)
	var best: int = -1
	var best_dist: float = INF

	for i in waypoints.size():
		var offset: Vector2 = waypoints[i].global_position - kart.global_position
		if offset.dot(forward) <= 0.0:
			continue
		var dist: float = offset.length()
		if dist < best_dist:
			best_dist = dist
			best = i

	_index = maxi(best, 0)


# Posição do waypoint atual, deslocada para o lado (a "faixa" desta IA).
func _target_position() -> Vector2:
	var current: Vector2 = waypoints[_index].global_position
	var next: Vector2 = waypoints[(_index + 1) % waypoints.size()].global_position
	var side: Vector2 = (next - current).normalized().rotated(PI / 2.0)
	return current + side * _lane_offset


func _physics_process(delta: float) -> void:
	if kart == null or waypoints.is_empty():
		return

	# Kart congelado pela contagem não conta como travado.
	if not kart.is_physics_processing():
		_stuck_time = 0.0
		return

	var target: Vector2 = _target_position()
	if kart.global_position.distance_to(target) < reach_radius:
		_index = (_index + 1) % waypoints.size()
		target = _target_position()

	# Ângulo entre para onde o kart olha e a direção do alvo.
	# Positivo = alvo à direita (mesmo sinal do steering do kart).
	var forward: Vector2 = Vector2.UP.rotated(kart.global_rotation)
	var to_target: Vector2 = kart.global_position.direction_to(target)
	var angle: float = forward.angle_to(to_target)
	var steer: float = clampf(angle * steer_gain, -1.0, 1.0)
	var speed: float = kart.velocity.dot(forward)

	# Destravando: ré com a direção invertida (de ré, o giro é ao contrário).
	if _reverse_time > 0.0:
		_reverse_time -= delta
		kart.set_controls(-steer, -1.0)
		return

	# Kart preso (quase parado, mesmo acelerando).
	if kart.velocity.length() < 25.0:
		_stuck_time += delta
		if _stuck_time >= stuck_time_limit:
			_stuck_time = 0.0
			_reverse_time = reverse_duration
	else:
		_stuck_time = 0.0

	# Curva fechada em alta velocidade: solta o acelerador.
	var throttle: float = 1.0
	if absf(angle) > sharp_turn_angle and speed > corner_speed:
		throttle = 0.0

	kart.set_controls(steer, throttle)
