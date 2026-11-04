extends CharacterBody2D

## Velocidade máxima para frente em pixels por segundo.
@export var max_speed: float = 400.0
## Aceleração gradual para frente.
@export var acceleration: float = 350.0
## Força de frenagem / desaceleração ativa ao segurar freio.
@export var brake_force: float = 400.0
## Velocidade máxima em marcha ré.
@export var reverse_max_speed: float = 150.0
## Velocidade de rotação em torno do próprio eixo (radianos por segundo).
@export var rotation_speed: float = 3.5
## Desaceleração por atrito quando nenhum comando é pressionado.
@export var friction: float = 160.0
## Aderência lateral: quanto maior, menos o kart escorrega nas curvas.
@export var grip: float = 800.0
## Velocidade a partir da qual a direção responde por completo.
@export var steer_full_speed: float = 120.0
## Fator de velocidade após bater numa parede (0.8 = perde 20%).
@export var wall_speed_factor: float = 0.8

## Multiplicador da velocidade máxima conforme o piso (1.0 = asfalto, 0.6 = grama).
## A pista altera este valor.
var surface_multiplier: float = 1.0

var _was_colliding: bool = false


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING


func _physics_process(delta: float) -> void:
	# Direita/frente atuais, antes de girar
	var forward: Vector2 = Vector2.UP.rotated(rotation)
	var current_forward_speed: float = velocity.dot(forward)

	# Direção só responde com o kart em movimento (e inverte na ré)
	var steer_input: float = Input.get_axis("steer_left", "steer_right")
	var steer_factor: float = clampf(current_forward_speed / steer_full_speed, -1.0, 1.0)
	rotation += steer_input * rotation_speed * steer_factor * delta

	# Separa a velocidade em componente frontal e lateral
	forward = Vector2.UP.rotated(rotation)
	var right: Vector2 = Vector2.RIGHT.rotated(rotation)
	var forward_speed: float = velocity.dot(forward)
	var lateral_speed: float = velocity.dot(right)

	if Input.is_action_pressed("accelerate"):
		forward_speed = move_toward(forward_speed, max_speed, acceleration * delta)
	elif Input.is_action_pressed("brake"):
		forward_speed = move_toward(forward_speed, -reverse_max_speed, brake_force * delta)
	else:
		forward_speed = move_toward(forward_speed, 0.0, friction * delta)

	# Limite de velocidade conforme o piso (grama reduz o máximo)
	forward_speed = clampf(forward_speed, -reverse_max_speed, max_speed * surface_multiplier)

	# Aderência: o componente lateral vai sumindo (derrapagem)
	lateral_speed = move_toward(lateral_speed, 0.0, grip * delta)

	velocity = forward * forward_speed + right * lateral_speed
	move_and_slide()

	# Perde velocidade uma vez por impacto, não a cada frame encostado
	var colliding: bool = get_slide_collision_count() > 0
	if colliding and not _was_colliding:
		velocity *= wall_speed_factor
	_was_colliding = colliding
