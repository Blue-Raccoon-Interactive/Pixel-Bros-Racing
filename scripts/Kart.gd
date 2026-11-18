
class_name Kart
extends CharacterBody2D

@onready var engine_audio: AudioStreamPlayer2D = $EngineAudio
@onready var brake_audio: AudioStreamPlayer2D = $BrakeAudio

@export_group("Audio Tuning")
@export var idle_pitch: float = 0.80           # Tom do motor em marcha lenta (parado)
@export var max_pitch: float = 2.0             # Tom do motor na velocidade máxima
@export var engine_brake_pitch: float = 0.75   # Tom grave simulando o freio-motor
@export var brake_threshold: float = 120.0     # Velocidade lateral mínima para chiar nas curvas

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

## Multiplicador da velocidade máxima conforme o piso.
var surface_multiplier: float = 1.0

## Zonas de piso (grama etc.) em que o kart está agora.
var _surface_zones: Array[GrassZone] = []

## Comandos recebidos do controlador.
var steer_input: float = 0.0
var throttle_input: float = 0.0

var _was_colliding: bool = false

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
	
	if engine_audio.stream:
		engine_audio.play()

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
	
	update_animation()
	update_audio(delta)
	
func update_audio(delta: float) -> void:
	var forward: Vector2 = Vector2.UP.rotated(rotation)
	var right: Vector2 = Vector2.RIGHT.rotated(rotation)
	
	var forward_speed: float = velocity.dot(forward)
	var abs_speed: float = abs(forward_speed)
	var lateral_speed: float = abs(velocity.dot(right))
	var speed_ratio: float = clamp(abs_speed / max_speed, 0.0, 1.0)
	
	# --- 1. LÓGICA DO FREIO (BrakeAudio) ---
	var is_braking: bool = throttle_input < 0.0 and forward_speed > 40.0
	
	if brake_audio and brake_audio.stream:
		if is_braking:
			if not brake_audio.playing:
				# Inicia direto com um volume bom e audível (sem nascer abafado)
				brake_audio.volume_db = -2.0 
				brake_audio.play()
			
			# Mantém em um nível forte e presente (0 dB)
			brake_audio.volume_db = move_toward(brake_audio.volume_db, 0.0, 80.0 * delta)
		else:
			# Ao soltar, abaixa rápido e desliga
			brake_audio.volume_db = move_toward(brake_audio.volume_db, -40.0, 100.0 * delta)
			if brake_audio.volume_db <= -38.0 and brake_audio.playing:
				brake_audio.stop()

	# --- 2. LÓGICA DO MOTOR (EngineAudio) ---
	var target_pitch: float = idle_pitch
	var target_volume: float = -18.0
	
	if throttle_input > 0.0:
		# ACELERANDO PARA FRENTE
		target_pitch = lerp(idle_pitch, max_pitch, speed_ratio)
		target_volume = 0.0
		
	elif is_braking:
		# FREANDO: Motor vai para o freio-motor e dá uma abafada suave (-16.0 dB) para destacar o freio
		target_pitch = engine_brake_pitch
		target_volume = -16.0  
		
	elif throttle_input < 0.0 and forward_speed <= 10.0:
		# MARCHA RÉ
		target_pitch = 0.6
		target_volume = -12.0
		
	elif throttle_input == 0.0 and abs_speed > 80.0:
		# FREIO-MOTOR (soltou o acelerador)
		target_pitch = engine_brake_pitch
		target_volume = -12.0
		
	else:
		# PARADO
		target_pitch = idle_pitch
		target_volume = -18.0

	engine_audio.pitch_scale = clamp(move_toward(engine_audio.pitch_scale, target_pitch, 6.0 * delta), 0.1, 4.0)
	engine_audio.volume_db = move_toward(engine_audio.volume_db, target_volume, 15.0 * delta)
