extends SceneTree

## Teste automatico do sistema de rastros de pneu (roda headless).
##
## Uso: godot --headless --path . --script res://tools/test_drift_marks.gd
##
## Cobre os cenarios: linha reta, curva normal, drift, parado, drift em alta
## velocidade, fim do drift, sumico das marcas e estabilidade no mundo.

const KART_SCENE := "res://scenes/karts/kart_01.tscn"
const FRAMES := 120

var _world: Node2D
var _kart: Kart
var _marks: DriftMarks
var _failures: int = 0
## Eixo trasseiro (as duas rodas) registrado a cada frame de fisica.
var _axles: Array[Dictionary] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_world = Node2D.new()
	root.add_child(_world)

	_kart = (load(KART_SCENE) as PackedScene).instantiate() as Kart
	_world.add_child(_kart)

	await physics_frame
	_marks = _find_marks()
	if _marks == null:
		print("FALHOU: o container DriftMarks nao foi criado.")
		quit(1)
		return

	print("Kart: ", _kart.kart_name, " | ancoras: ", _kart.get_node("RearWheelLeft").position, " / ", _kart.get_node("RearWheelRight").position)
	print("Detector: min_speed=", _kart._drift_detector.min_speed, " min_hard_steer=", _kart._drift_detector.min_hard_steer)
	print("")

	# 1. Linha reta: nao deve gerar marcas.
	await _drive(1.0, 0.0, FRAMES)
	_check("linha reta nao gera marcas", _marks.get_mark_count() == 0, "marcas: %d" % _marks.get_mark_count())

	# 2. Curva normal (esterco parcial): nao deve gerar marcas.
	await _drive(1.0, 0.35, FRAMES)
	_check("curva normal nao gera marcas", _marks.get_mark_count() == 0, "marcas: %d" % _marks.get_mark_count())

	# 2b. Curva normal em alta velocidade: ainda nao deve gerar marcas.
	await _drive(1.0, 0.0, 240)
	await _drive(1.0, 0.5, 90)
	_check("curva normal em alta velocidade nao gera marcas", _marks.get_mark_count() == 0, "marcas: %d" % _marks.get_mark_count())

	# 3. Drift: deve gerar dois rastros.
	_marks.clear_marks()
	_axles.clear()
	await _drive(1.0, 1.0, FRAMES)
	var count: int = _marks.get_mark_count()
	var separation: float = _trail_separation()
	_check("drift gera marcas", count > 20, "marcas: %d" % count)
	_check("drift gera dois rastros", separation >= 15.0, "separacao entre rastros: %.1f px" % separation)

	# 4. Espacamento constante entre as marcas do mesmo rastro.
	var spacing: float = _average_spacing()
	_check("espacamento constante", absf(spacing - _kart.drift_mark_spacing) < 1.5, "espacamento medio: %.2f px" % spacing)

	# 4b. As marcas ficam orientadas como o veiculo (a marca e o rastro do pneu).
	var angle_error: float = _heading_error()
	_check("marcas orientadas como o veiculo", angle_error < 15.0, "erro medio: %.1f graus" % angle_error)

	# 5. Fim do drift: parar de virar interrompe as marcas.
	await _drive(1.0, 0.0, 10)
	var before: int = _marks.get_mark_count()
	await _drive(1.0, 0.0, 30)
	_check("fim do drift para de gerar marcas", _marks.get_mark_count() == before, "antes: %d, depois: %d" % [before, _marks.get_mark_count()])

	# 6. Carro parado: nao gera marcas.
	_marks.clear_marks()
	await _drive(0.0, 0.0, 120)
	_check("carro parado nao gera marcas", _marks.get_mark_count() == 0, "marcas: %d" % _marks.get_mark_count())

	# 7. Drift em alta velocidade: os rastros acompanham os pneus.
	_marks.clear_marks()
	_axles.clear()
	await _drive(1.0, 0.0, 240)
	var fast_speed: float = _kart.velocity.length()
	await _drive(1.0, 1.0, 60)
	var speed: float = _kart.velocity.length()
	var high_count: int = _marks.get_mark_count()
	var offset_error: float = _axle_error()
	_check("drift em alta velocidade gera marcas", high_count > 20, "velocidade: %.0f px/s, marcas: %d" % [speed, high_count])
	_check("velocidade alta foi alcancada", fast_speed > 300.0, "velocidade: %.0f px/s" % fast_speed)
	_check("rastros ficam sob os pneus", offset_error < 2.0, "erro medio: %.2f px" % offset_error)

	# 8. Marcas ficam no mundo: nao acompanham o carro.
	var snapshot: Array[Vector2] = _marks.get_mark_positions()
	var kart_before: Vector2 = _kart.global_position
	await _drive(1.0, 0.0, 60)
	var moved: float = _kart.global_position.distance_to(kart_before)
	var drift_of_marks: float = 0.0
	var after: Array[Vector2] = _marks.get_mark_positions()
	for i in range(mini(snapshot.size(), after.size())):
		drift_of_marks = maxf(drift_of_marks, snapshot[i].distance_to(after[i]))
	_check("marcas ficam no lugar", drift_of_marks < 0.01 and moved > 10.0, "carro andou %.1f px, marcas andaram %.4f px" % [moved, drift_of_marks])

	# 9. Marcas antigas somem.
	_marks.mark_lifetime = 0.5
	_marks.fade_duration = 0.25
	await _drive(1.0, 1.0, 30)
	var with_marks: int = _marks.get_mark_count()
	await _drive(0.0, 0.0, 90)
	_check("marcas antigas somem", with_marks > 0 and _marks.get_mark_count() == 0, "antes: %d, depois: %d" % [with_marks, _marks.get_mark_count()])

	# 10. Limite de marcas respeitado.
	_marks.mark_lifetime = 0.0
	_marks.max_marks = 60
	_marks.clear_marks()
	await _drive(1.0, 1.0, 240)
	_check("limite de marcas respeitado", _marks.get_mark_count() <= 60, "marcas: %d" % _marks.get_mark_count())

	print("")
	if _failures == 0:
		print("TODOS OS TESTES PASSARAM")
	else:
		print("%d TESTE(S) FALHARAM" % _failures)
	quit(_failures)


## Segura os comandos por N frames de fisica e registra o eixo trasseiro.
func _drive(throttle: float, steer: float, frames: int) -> void:
	for _i in range(frames):
		_kart.set_controls(steer, throttle)
		await physics_frame
		_axles.append({
			"left": _kart.get_node("RearWheelLeft").global_position,
			"right": _kart.get_node("RearWheelRight").global_position,
		})


func _find_marks() -> DriftMarks:
	for child in _world.get_children():
		if child is DriftMarks:
			return child
	return null


## Separa as marcas em dois rastros e devolve a distancia lateral entre eles.
func _trail_clusters() -> Array:
	var positions: Array[Vector2] = _marks.get_mark_positions()
	var clusters: Array = [[], []]
	if positions.size() < 4:
		return clusters
	var recent: Array[Vector2] = positions.slice(positions.size() - 12)
	var direction: Vector2 = (recent[recent.size() - 1] - recent[0]).normalized()
	var normal: Vector2 = Vector2(-direction.y, direction.x)
	var offsets: Array[float] = []
	for position in recent:
		offsets.append((position - recent[0]).dot(normal))
	var sorted: Array[float] = offsets.duplicate()
	sorted.sort()
	var middle: float = sorted[sorted.size() / 2]
	for i in range(recent.size()):
		if offsets[i] < middle:
			clusters[0].append(recent[i])
		else:
			clusters[1].append(recent[i])
	return clusters


## Distancia lateral entre os dois rastros, medida nas marcas mais recentes.
func _trail_separation() -> float:
	var clusters: Array = _trail_clusters()
	if clusters[0].is_empty() or clusters[1].is_empty():
		return 0.0
	var center_a: Vector2 = Vector2.ZERO
	for position in clusters[0]:
		center_a += position
	center_a /= float(clusters[0].size())
	var center_b: Vector2 = Vector2.ZERO
	for position in clusters[1]:
		center_b += position
	center_b /= float(clusters[1].size())
	return center_a.distance_to(center_b)


## Espacamento medio entre marcas consecutivas de um mesmo rastro.
func _average_spacing() -> float:
	var clusters: Array = _trail_clusters()
	var total: float = 0.0
	var samples: int = 0
	for cluster in clusters:
		for i in range(1, cluster.size()):
			total += cluster[i].distance_to(cluster[i - 1])
			samples += 1
	return 0.0 if samples == 0 else total / float(samples)


## Erro medio (graus) entre a orientacao das ultimas marcas e a direcao do veiculo.
## A marca e o rastro do pneu: ela acompanha a orientacao do kart.
func _heading_error() -> float:
	var positions: Array[Vector2] = _marks.get_mark_positions()
	if positions.is_empty():
		return 999.0
	var total: float = 0.0
	var samples: int = 0
	var count: int = mini(4, positions.size())
	for i in range(positions.size() - count, positions.size()):
		var difference: float = absf(wrapf(_rotation_of(positions[i]) - _kart.global_rotation, -PI, PI))
		total += rad_to_deg(difference)
		samples += 1
	return 0.0 if samples == 0 else total / float(samples)


## Rotacao da marca que está em uma posicao (as marcas sao filhas do container).
func _rotation_of(position: Vector2) -> float:
	for child in _marks.get_children():
		if child is Sprite2D and (child as Sprite2D).visible:
			if (child as Sprite2D).global_position.distance_to(position) < 0.01:
				return (child as Sprite2D).global_rotation
	return 0.0


## Distancia media das marcas ate o eixo trasseiro do kart no frame mais proximo.
func _axle_error() -> float:
	var positions: Array[Vector2] = _marks.get_mark_positions()
	if positions.is_empty() or _axles.is_empty():
		return 999.0
	var total: float = 0.0
	for position in positions:
		var best: float = INF
		for axle in _axles:
			var left: Vector2 = axle["left"]
			var right: Vector2 = axle["right"]
			var axis: Vector2 = right - left
			var length: float = axis.length()
			if length < 0.001:
				continue
			var normal: Vector2 = Vector2(-axis.y, axis.x) / length
			best = minf(best, absf((position - left).dot(normal)))
		if best < INF:
			total += best
	return total / float(positions.size())


func _check(label: String, ok: bool, details: String) -> void:
	if ok:
		print("  OK   %s (%s)" % [label, details])
	else:
		_failures += 1
		print("  FALHA %s (%s)" % [label, details])
