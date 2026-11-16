
class_name Kart
extends CharacterBody2D

## Caminho da tabela de âncoras usada quando a cena do kart não define os pneus traseiros.
const DEFAULT_WHEEL_ANCHORS_PATH := "res://assets/effects/drift/kart_wheel_anchors.tres"
## Caminho da cena padrão do container das marcas.
const DEFAULT_DRIFT_MARKS_SCENE_PATH := "res://scenes/effects/drift_marks.tscn"

## Nome identificador do kart.
@export var kart_name: String = "Kart"
## Arquétipo ou categoria de estilo de pilotagem.
@export var archetype: String = "Equilibrado"
## Caminho do sprite ou textura representativa do kart no menu.
@export var kart_sprite_texture: Texture2D

## Velocidade máxima para frente em pixels por segundo.
@export var max_speed: float = 400.0
## Aceleração gradual para frente.
@export var acceleration: float = 350.0
## Força de frenagem / desaceleração ativa ao segurar freio.
@export var brake_force: float = 400.0
## Velocidade máxima em marcha ré.
@export var reverse_max_speed: float = 150.0
## Velocidade de rotação em torno do próprio eixo.
@export var rotation_speed: float = 3.5
## Desaceleração por atrito quando nenhum comando é pressionado.
@export var friction: float = 160.0
## Aderência lateral.
@export var grip: float = 800.0
## Velocidade a partir da qual a direção responde por completo.
@export var steer_full_speed: float = 120.0
## Fator de velocidade após bater numa parede.
@export var wall_speed_factor: float = 0.8

@export_group("Rastros de pneu")
## Detector de derrapagem. Vazio = usa os valores padrão do código.
@export var drift_detector: DriftDetector
## Tabela com a posição dos pneus traseiros de cada kart.
@export var wheel_anchors: KartWheelAnchors
## Pneu traseiro esquerdo (x, y) no espaço do kart.
## Usado quando o kart não está na tabela de âncoras.
@export var rear_wheel_left: Vector2 = Vector2(-11.0, 11.0)
## Pneu traseiro direito (x, y) no espaço do kart.
@export var rear_wheel_right: Vector2 = Vector2(11.0, 11.0)
## Distância (px) entre uma marca e a seguinte de cada pneu.
@export_range(1.0, 64.0, 0.5) var drift_mark_spacing: float = 8.0
## Superfície usada quando o kart não está em nenhuma zona de piso.
@export var drift_default_surface: StringName = &"asphalt"
## Cena do container das marcas. Se a cena da corrida já tiver um, ele é reutilizado.
@export var drift_marks_scene: PackedScene

## Multiplicador da velocidade máxima conforme o piso.
var surface_multiplier: float = 1.0

## Zonas de piso (grama etc.) em que o kart está agora.
var _surface_zones: Array[GrassZone] = []

## Comandos recebidos do controlador.
var steer_input: float = 0.0
var throttle_input: float = 0.0

var _was_colliding: bool = false

## Container das marcas de pneu (irmão do kart na cena, fica no mundo).
var _drift_marks: DriftMarks
## Detector usado na hora de evaluar a derrapagem.
var _drift_detector: DriftDetector
## Pneus traseiros deste kart (marcadores na cena ou criados em tempo de execução).
var _rear_wheels: Array[Marker2D] = []
## Última marca de cada pneu, para manter o espaçamento constante.
var _drift_last_positions: Dictionary = {}

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D;


## Recebe os comandos do jogador ou da IA.
func set_controls(steering: float, throttle: float) -> void:
	steer_input = clampf(steering, -1.0, 1.0)
	throttle_input = clampf(throttle, -1.0, 1.0)
	
	## Chamado pelas zonas de piso quando o kart entra.
func enter_surface(zone: GrassZone) -> void:
	if not _surface_zones.has(zone):
		_surface_zones.append(zone)
	_update_surface_multiplier()


## Chamado pelas zonas de piso quando o kart sai.
func exit_surface(zone: GrassZone) -> void:
	_surface_zones.erase(zone)
	_update_surface_multiplier()


# Vale a zona mais lenta; sem zona nenhuma, velocidade normal.
func _update_surface_multiplier() -> void:
	var result: float = 1.0
	for zone in _surface_zones:
		if is_instance_valid(zone):
			result = minf(result, zone.multiplier)
	surface_multiplier = result


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("race_kart")
	_setup_drift()

## Prepara o sistema de rastros: detector, âncoras dos pneus e container de marcas.
func _setup_drift() -> void:
	_drift_detector = drift_detector if drift_detector != null else DriftDetector.new()
	_rear_wheels = _resolve_rear_wheels()
	# O container das marcas é criado depois que a cena termina de montar:
	# durante o _ready o pai ainda está colocando os filhos e não aceita add_child.
	_create_drift_marks_container.call_deferred()

## Descobre onde ficam os pneus traseiros deste kart.
## Prioridade: marcadores na cena > tabela de âncoras > valores do inspetor.
func _resolve_rear_wheels() -> Array[Marker2D]:
	var markers: Array[Marker2D] = []
	for child in get_children():
		if child is Marker2D and (child.name == "RearWheelLeft" or child.name == "RearWheelRight"):
			markers.append(child)
	if markers.size() >= 2:
		markers.sort_custom(func(a: Marker2D, b: Marker2D) -> bool: return a.name < b.name)
		return markers

	# Sem marcadores na cena: procura o kart pelo nome na tabela de âncoras.
	var anchors: KartWheelAnchors = wheel_anchors
	if anchors == null:
		anchors = load(DEFAULT_WHEEL_ANCHORS_PATH) as KartWheelAnchors
	var table: Array[Vector2] = [] if anchors == null else anchors.get_anchors(StringName(kart_name))
	var left: Vector2 = table[0] if table.size() == 2 else rear_wheel_left
	var right: Vector2 = table[1] if table.size() == 2 else rear_wheel_right
	return [
		_make_wheel_marker("RearWheelLeft", left),
		_make_wheel_marker("RearWheelRight", right),
	]

## Cria um marcador de pneu em tempo de execução.
func _make_wheel_marker(marker_name: String, marker_position: Vector2) -> Marker2D:
	var marker := Marker2D.new()
	marker.name = marker_name
	marker.position = marker_position
	add_child(marker)
	return marker

## Cria (ou reaproveita) o container das marcas. Ele precisa ser irmão do kart
## na cena: assim as marcas ficam no chão e não acompanham o veículo nem a câmera.
func _create_drift_marks_container() -> void:
	if not is_inside_tree():
		return
	var parent: Node = get_parent()
	if parent == null:
		return

	for child in parent.get_children():
		if child is DriftMarks:
			_drift_marks = child
			return

	var scene: PackedScene = drift_marks_scene
	if scene == null:
		scene = load(DEFAULT_DRIFT_MARKS_SCENE_PATH) as PackedScene
	if scene == null:
		return
	var marks: DriftMarks = scene.instantiate() as DriftMarks
	if marks == null:
		push_warning("Kart: a cena de rastros de pneu não tem o script DriftMarks.")
		return
	parent.add_child(marks)
	# Antes do kart: as marcas ficam entre a pista e o veículo.
	parent.move_child(marks, get_index())
	_drift_marks = marks

## Superfície atual do kart (vale a mais lenta em que ele está).
func get_surface_name() -> StringName:
	var slowest: GrassZone = null
	for zone in _surface_zones:
		if not is_instance_valid(zone):
			continue
		if slowest == null or zone.multiplier < slowest.multiplier:
			slowest = zone
	if slowest != null:
		return slowest.surface_name
	return drift_default_surface

## Lê o estado do drift e coloca as marcas dos pneus traseiros.
func _update_drift_marks(forward: Vector2, right: Vector2) -> void:
	if _drift_marks == null or _drift_detector == null:
		return

	var state: DriftDetector.State = _drift_detector.evaluate(velocity, forward, right, steer_input)
	if not state.drifting:
		_drift_last_positions.clear()
		return

	var surface: StringName = get_surface_name()
	for wheel in _rear_wheels:
		_place_mark(wheel, surface, state.intensity)

## Coloca uma marca do pneu a `drift_mark_spacing` da anterior, no caminho do pneu.
func _place_mark(wheel: Marker2D, surface: StringName, intensity: float) -> void:
	var key: int = wheel.get_instance_id()
	var current: Vector2 = wheel.global_position
	if not _drift_last_positions.has(key):
		_drift_last_positions[key] = current
		return

	var last: Vector2 = _drift_last_positions[key]
	var offset: Vector2 = current - last
	var distance: float = offset.length()
	if distance < drift_mark_spacing:
		return

	# A marca fica exatamente um espaçamento atrás da anterior: o rastro fica
	# uniforme e nunca há sobreposição, mesmo em alta velocidade.
	var direction: Vector2 = offset / distance
	var position: Vector2 = last + direction * drift_mark_spacing
	_drift_marks.place_mark(position, wheel.global_rotation, surface, intensity, direction)
	_drift_last_positions[key] = position

# Definir animacoes durante acelerar, feiar e re.

func update_animation() -> void:
	var forward: Vector2 = Vector2.UP.rotated(rotation)
	var current_speed: float = velocity.dot(forward)

	var target_animation: String
	var is_idle: bool = false

	# 1. Prioridade para o volante/pneu esterçando (se você estiver usando essa lógica)
	if steer_input < -0.2:
		target_animation = "steering_left"
	elif steer_input > 0.2:
		target_animation = "steering_right"
		
	# 2. Acelerando ativamente
	elif throttle_input > 0.0:
		target_animation = "accelerating"
		
	# 3. Frenagem ativa (jogador apertou para trás / freio)
	elif throttle_input < 0.0:
		target_animation = "braking"
		
	# 4. Soltou o acelerador, mas o carro ainda está embalado (Desacelerando por atrito)
	elif abs(current_speed) > 10.0 and throttle_input == 0.0:
		target_animation = "stopping"
		
	# 5. Marcha ré (se estiver andando para trás)
	elif current_speed < -5.0:
		target_animation = "reverse"
		
	# 6. Totalmente parado
	else:
		target_animation = "reverse" # Ou uma animação "idle" se tiver criado
		is_idle = true

	# Kart parado: congela no último frame da frenagem.
	if is_idle:
		if animated_sprite.animation != target_animation:
			animated_sprite.play(target_animation)

		animated_sprite.stop()
		animated_sprite.frame = (
			animated_sprite.sprite_frames.get_frame_count(target_animation) - 1
		)
		return

	# Só inicia novamente quando a animação realmente mudar
	# ou quando estiver parada.
	if animated_sprite.animation != target_animation:
		animated_sprite.play(target_animation)
	elif not animated_sprite.is_playing():
		animated_sprite.play()


func _physics_process(delta: float) -> void:
	# Direção atual do kart.
	var forward: Vector2 = Vector2.UP.rotated(rotation)
	var current_forward_speed: float = velocity.dot(forward)

	# Rotação conforme o comando recebido.
	var steer_factor: float = clampf(
		current_forward_speed / steer_full_speed, -1.0, 1.0
	)
	rotation += steer_input * rotation_speed * steer_factor * delta

	# Separa a velocidade em componente frontal e lateral.
	forward = Vector2.UP.rotated(rotation)
	var right: Vector2 = Vector2.RIGHT.rotated(rotation)
	var forward_speed: float = velocity.dot(forward)
	var lateral_speed: float = velocity.dot(right)

	# Aceleração e frenagem.
	if throttle_input > 0.0:
		forward_speed = move_toward(
			forward_speed,
			max_speed,
			acceleration * throttle_input * delta
		)
	elif throttle_input < 0.0:
		forward_speed = move_toward(
			forward_speed,
			-reverse_max_speed,
			brake_force * absf(throttle_input) * delta
		)
	else:
		forward_speed = move_toward(
			forward_speed, 0.0, friction * delta
		)

	# Limite de velocidade conforme o piso.
	forward_speed = clampf(
		forward_speed,
		-reverse_max_speed,
		max_speed * surface_multiplier
	)

	# Aderência lateral.
	lateral_speed = move_toward(
		lateral_speed, 0.0, grip * delta
	)

	velocity = forward * forward_speed + right * lateral_speed
	move_and_slide()

	# Perde velocidade uma vez por impacto.
	var colliding: bool = get_slide_collision_count() > 0
	if colliding and not _was_colliding:
		velocity *= wall_speed_factor

	_was_colliding = colliding
	
	_update_drift_marks(forward, right)
	
	update_animation()
