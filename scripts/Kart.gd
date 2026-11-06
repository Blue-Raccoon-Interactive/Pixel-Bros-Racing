
class_name Kart
extends CharacterBody2D

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

## Multiplicador da velocidade máxima conforme o piso.
var surface_multiplier: float = 1.0

## Comandos recebidos do controlador.
var steer_input: float = 0.0
var throttle_input: float = 0.0

var _was_colliding: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D;


## Recebe os comandos do jogador ou da IA.
func set_controls(steering: float, throttle: float) -> void:
	steer_input = clampf(steering, -1.0, 1.0)
	throttle_input = clampf(throttle, -1.0, 1.0)


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("race_kart")

# Definir animacoes durante acelerar, feiar e re.

func update_animation() -> void:
	var forward: Vector2 = Vector2.UP.rotated(rotation)
	var current_speed: float = velocity.dot(forward)

	var target_animation: String
	var is_idle: bool = false

	if throttle_input > 0.0:
		target_animation = "accelerating"

	elif current_speed < -5.0:
		target_animation = "reverse"

	elif throttle_input < 0.0 or current_speed > 5.0:
		target_animation = "braking"

	else:
		target_animation = "reverse"
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
	
	update_animation()
