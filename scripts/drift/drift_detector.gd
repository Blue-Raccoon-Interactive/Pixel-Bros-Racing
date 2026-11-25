
class_name DriftDetector
extends Resource

## Detecta derrapagem lendo o movimento que o Kart ja calcula
## (velocidade, direcao do veiculo e direcao do movimento).
## Nao existe fisica nova aqui: e so leitura do estado atual do veiculo.
##
## Tres criterios, todos configuraveis:
##   1. angulo entre a direcao do veiculo e a direcao do movimento;
##   2. deslizamento lateral (componente da velocidade na transversal);
##   3. curva fechada (esterco forte em velocidade alta).
## O criterio 3 e o que dispara no modelo de movimento atual do jogo;
## os criterios 1 e 2 ja valem para quando existir derrapagem de verdade
## (botao de drift, raspagem na parede, etc).

## Velocidade minima (px/s) para o kart ser considerado em derrapagem.
@export_range(0.0, 1000.0, 5.0) var min_speed: float = 140.0
## Angulo minimo (graus) entre a direcao do veiculo e a direcao do movimento.
@export_range(0.0, 90.0, 1.0) var min_slip_angle_degrees: float = 18.0
## Deslizamento lateral minimo (px/s) para considerar derrapagem.
@export_range(0.0, 500.0, 5.0) var min_lateral_slip: float = 70.0
## Esterco minimo (0..1) para contar como "curva fechada".
@export_range(0.0, 1.0, 0.05) var min_hard_steer: float = 0.8
## Velocidade minima (px/s) para o criterio de curva fechada valer.
@export_range(0.0, 1000.0, 10.0) var min_hard_steer_speed: float = 240.0


## Estado do drift em um frame.
class State extends RefCounted:
	## O kart esta derrapando agora?
	var drifting: bool = false
	## Forca da derrapagem (0..1). Define a opacidade da marca.
	var intensity: float = 0.0
	## Velocidade atual do kart (px/s).
	var speed: float = 0.0
	## Angulo entre a direcao do veiculo e a direcao do movimento (graus).
	var slip_angle_degrees: float = 0.0
	## Componente lateral da velocidade (px/s).
	var lateral_slip: float = 0.0


## Avalia o movimento do kart e devolve o estado do drift.
## `forward` e `right` sao os vetores que a fisica do Kart ja usa.
func evaluate(velocity: Vector2, forward: Vector2, right: Vector2, steer_input: float) -> State:
	var state := State.new()
	state.speed = velocity.length()

	# Devagar demais ou de re nao e derrapagem.
	if state.speed < min_speed or velocity.dot(forward) <= 0.0:
		return state

	state.lateral_slip = absf(velocity.dot(right))
	state.slip_angle_degrees = rad_to_deg(absf(velocity.angle_to(forward)))

	var by_angle: bool = state.slip_angle_degrees >= min_slip_angle_degrees
	var by_slip: bool = state.lateral_slip >= min_lateral_slip
	var by_steer: bool = absf(steer_input) >= min_hard_steer and state.speed >= min_hard_steer_speed
	state.drifting = by_angle or by_slip or by_steer

	# Intensidade: o criterio mais forte manda, normalizado pelo seu limite.
	var angle_ratio: float = clampf(state.slip_angle_degrees / maxf(min_slip_angle_degrees, 0.001), 0.0, 1.0)
	var slip_ratio: float = clampf(state.lateral_slip / maxf(min_lateral_slip, 1.0), 0.0, 1.0)
	var steer_ratio: float = clampf(absf(steer_input) / maxf(min_hard_steer, 0.001), 0.0, 1.0)
	state.intensity = clampf(maxf(maxf(angle_ratio, slip_ratio), steer_ratio * 0.85), 0.0, 1.0)

	return state
