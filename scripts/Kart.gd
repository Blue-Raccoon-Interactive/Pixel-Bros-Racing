class_name Kart
extends CharacterBody2D

const DEFAULT_WHEEL_ANCHORS_PATH := "res://assets/effects/drift/kart_wheel_anchors.tres"
const DEFAULT_DRIFT_MARKS_SCENE_PATH := "res://scenes/effects/drift_marks.tscn"

const SFX_COLISAO_KART: AudioStream = preload(
	"res://sound/sfx/impacts/colisao_karts.wav"
)
const SFX_COLISAO_BARREIRA: AudioStream = preload(
	"res://sound/sfx/impacts/colisao_barreira_pista.wav"
)

@export_group("Identidade")
@export var kart_name: String = "Kart"
@export var archetype: String = "Equilibrado"
@export var kart_sprite_texture: Texture2D

@export_group("Fisica e Dirigibilidade")
@export var max_speed: float = 400.0
@export var acceleration: float = 350.0
@export var brake_force: float = 400.0
@export var reverse_max_speed: float = 150.0
@export var rotation_speed: float = 3.5
@export var friction: float = 160.0
@export var grip: float = 800.0
@export var steer_full_speed: float = 120.0
@export var wall_speed_factor: float = 0.8

@export_group("Colisao entre Karts")
@export var kart_bump_impulse: float = 65.0
@export_range(0.0, 0.8, 0.02) var kart_restitution: float = 0.16
@export var kart_continuous_push: float = 220.0
@export var bump_damping: float = 1050.0
@export_range(0.05, 1.0, 0.05) var post_collision_grip_scale: float = 0.42
@export var post_collision_grip_duration: float = 0.10

@export_group("Rastros de pneu")
@export var drift_detector: DriftDetector
@export var wheel_anchors: KartWheelAnchors
@export var rear_wheel_left: Vector2 = Vector2(-11.0, 11.0)
@export var rear_wheel_right: Vector2 = Vector2(11.0, 11.0)
@export_range(1.0, 64.0, 0.5) var drift_mark_spacing: float = 8.0
@export var drift_default_surface: StringName = &"asphalt"
@export var drift_marks_scene: PackedScene

@export_group("Audio Tuning")
@export var idle_pitch: float = 0.80
@export var max_pitch: float = 2.0
@export var engine_brake_pitch: float = 0.75
@export var brake_threshold: float = 120.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var engine_audio: AudioStreamPlayer2D = $EngineAudio
@onready var brake_audio: AudioStreamPlayer2D = $BrakeAudio

var surface_multiplier: float = 1.0
var steer_input: float = 0.0
var throttle_input: float = 0.0

var _surface_zones: Array[GrassZone] = []
var _was_colliding: bool = false
var _bump_grip_timer: float = 0.0
var _external_velocity: Vector2 = Vector2.ZERO

var _drift_marks: DriftMarks
var _drift_detector: DriftDetector
var _rear_wheels: Array[Marker2D] = []
var _drift_last_positions: Dictionary = {}


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("race_kart")
	_setup_drift()

	if engine_audio and engine_audio.stream:
		engine_audio.play()


func _physics_process(delta: float) -> void:
	_step_physics(delta)

	var forward: Vector2 = Vector2.UP.rotated(rotation)
	var right: Vector2 = Vector2.RIGHT.rotated(rotation)
	_update_drift_marks(forward, right)
	_update_animation(forward)
	_update_audio(delta, forward, right)


# --- Controles e Superfícies ---

func set_controls(steering: float, throttle: float) -> void:
	steer_input = clampf(steering, -1.0, 1.0)
	throttle_input = clampf(throttle, -1.0, 1.0)


func enter_surface(zone: GrassZone) -> void:
	if not _surface_zones.has(zone):
		_surface_zones.append(zone)
	_update_surface_multiplier()


func exit_surface(zone: GrassZone) -> void:
	_surface_zones.erase(zone)
	_update_surface_multiplier()


func get_surface_name() -> StringName:
	var slowest: GrassZone = null
	for zone in _surface_zones:
		if not is_instance_valid(zone):
			continue
		if slowest == null or zone.multiplier < slowest.multiplier:
			slowest = zone
	return slowest.surface_name if slowest != null else drift_default_surface


func _update_surface_multiplier() -> void:
	var result: float = 1.0
	for zone in _surface_zones:
		if is_instance_valid(zone):
			result = minf(result, zone.multiplier)
	surface_multiplier = result


# --- Física e Colisões ---

func apply_external_impulse(impulse: Vector2, grip_reduction_time: float = -1.0) -> void:
	_external_velocity += impulse
	var duration: float = grip_reduction_time if grip_reduction_time >= 0.0 else post_collision_grip_duration
	_bump_grip_timer = maxf(_bump_grip_timer, duration)


func _step_physics(delta: float) -> void:
	if _bump_grip_timer > 0.0:
		_bump_grip_timer = maxf(_bump_grip_timer - delta, 0.0)

	_external_velocity = _external_velocity.move_toward(Vector2.ZERO, bump_damping * delta)

	var forward: Vector2 = Vector2.UP.rotated(rotation)
	var current_forward_speed: float = velocity.dot(forward)
	var steer_factor: float = clampf(current_forward_speed / steer_full_speed, -1.0, 1.0)
	rotation += steer_input * rotation_speed * steer_factor * delta

	forward = Vector2.UP.rotated(rotation)
	var right: Vector2 = Vector2.RIGHT.rotated(rotation)

	var forward_speed: float = _compute_forward_speed(velocity.dot(forward), delta)
	var effective_grip: float = grip * (post_collision_grip_scale if _bump_grip_timer > 0.0 else 1.0)
	var lateral_speed: float = move_toward(velocity.dot(right), 0.0, effective_grip * delta)

	velocity = forward * forward_speed + right * lateral_speed + _external_velocity
	move_and_slide()
	_handle_collisions(delta)


func _compute_forward_speed(current_speed: float, delta: float) -> float:
	var speed: float = current_speed

	if throttle_input > 0.0:
		speed = move_toward(speed, max_speed, acceleration * throttle_input * delta)
	elif throttle_input < 0.0:
		speed = move_toward(speed, -reverse_max_speed, brake_force * absf(throttle_input) * delta)
	else:
		speed = move_toward(speed, 0.0, friction * delta)

	return clampf(speed, -reverse_max_speed, max_speed * surface_multiplier)


func _handle_collisions(delta: float) -> void:
	var collision_count: int = get_slide_collision_count()
	var colliding: bool = collision_count > 0
	var is_new_collision: bool = colliding and not _was_colliding

	var hit_wall: bool = false
	var played_sound: bool = false

	for i in collision_count:
		var collision: KinematicCollision2D = get_slide_collision(i)
		var collider := collision.get_collider() as Node

		if is_new_collision and not played_sound and _play_collision_sound(collision):
			played_sound = true

		if collider is Kart:
			_resolve_kart_collision(collision, is_new_collision, delta)
		elif collider != null and collider.is_in_group("colisao_barreira"):
			hit_wall = true

	if is_new_collision and hit_wall:
		velocity *= wall_speed_factor

	_was_colliding = colliding


func _resolve_kart_collision(collision: KinematicCollision2D, is_initial_hit: bool, delta: float) -> void:
	var other_kart := collision.get_collider() as Kart
	if other_kart == null or not is_instance_valid(other_kart):
		return

	if get_instance_id() > other_kart.get_instance_id():
		return

	var to_other: Vector2 = other_kart.global_position - global_position
	var normal: Vector2 = to_other.normalized() if to_other.length_squared() > 0.0001 else collision.get_normal().normalized()
	if normal == Vector2.ZERO:
		normal = Vector2.RIGHT

	var relative_velocity: Vector2 = velocity - other_kart.velocity
	var closing_speed: float = maxf(relative_velocity.dot(normal), 0.0)

	var my_push_speed: float = maxf(velocity.dot(normal), 0.0)
	var other_push_speed: float = maxf(-other_kart.velocity.dot(normal), 0.0)
	var total_push: float = my_push_speed + other_push_speed
	var other_share: float = 0.70 if total_push <= 0.01 else clampf(my_push_speed / total_push, 0.25, 0.80)
	var my_share: float = 1.0 - other_share

	if is_initial_hit:
		var impulse_magnitude: float = closing_speed * kart_restitution + kart_bump_impulse
		var impulse: Vector2 = normal * impulse_magnitude
		apply_external_impulse(-impulse * my_share)
		other_kart.apply_external_impulse(impulse * other_share)
	elif closing_speed > 5.0:
		var push_step: Vector2 = normal * (kart_continuous_push * delta)
		apply_external_impulse(-push_step * my_share, 0.06)
		other_kart.apply_external_impulse(push_step * other_share, 0.06)


# --- Rastros de Pneu ---

func _setup_drift() -> void:
	_drift_detector = drift_detector if drift_detector != null else DriftDetector.new()
	_rear_wheels = _resolve_rear_wheels()
	_create_drift_marks_container.call_deferred()


func _resolve_rear_wheels() -> Array[Marker2D]:
	var markers: Array[Marker2D] = []
	for child in get_children():
		if child is Marker2D and (child.name == "RearWheelLeft" or child.name == "RearWheelRight"):
			markers.append(child)
	if markers.size() >= 2:
		markers.sort_custom(func(a: Marker2D, b: Marker2D) -> bool: return a.name < b.name)
		return markers

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


func _make_wheel_marker(marker_name: String, marker_position: Vector2) -> Marker2D:
	var marker := Marker2D.new()
	marker.name = marker_name
	marker.position = marker_position
	add_child(marker)
	return marker


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

	var scene: PackedScene = drift_marks_scene if drift_marks_scene != null else load(DEFAULT_DRIFT_MARKS_SCENE_PATH) as PackedScene
	if scene == null:
		return

	var marks := scene.instantiate() as DriftMarks
	if marks == null:
		push_warning("Kart: a cena de rastros de pneu não tem o script DriftMarks.")
		return

	parent.add_child(marks)
	parent.move_child(marks, get_index())
	_drift_marks = marks


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

	var direction: Vector2 = offset / distance
	var mark_position: Vector2 = last + direction * drift_mark_spacing
	_drift_marks.place_mark(mark_position, wheel.global_rotation, surface, intensity, direction)
	_drift_last_positions[key] = mark_position


# --- Animação ---

func _update_animation(forward: Vector2) -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return

	var current_speed: float = velocity.dot(forward)
	var target_animation: String
	var is_idle: bool = false

	if steer_input < -0.2:
		target_animation = "steering_left"
	elif steer_input > 0.2:
		target_animation = "steering_right"
	elif throttle_input > 0.0:
		target_animation = "accelerating"
	elif throttle_input < 0.0:
		target_animation = "braking"
	elif absf(current_speed) > 10.0 and is_zero_approx(throttle_input):
		target_animation = "stopping"
	elif current_speed < -5.0:
		target_animation = "reverse"
	else:
		target_animation = "reverse"
		is_idle = true

	if not animated_sprite.sprite_frames.has_animation(target_animation):
		return

	if is_idle:
		if animated_sprite.animation != target_animation:
			animated_sprite.play(target_animation)
		animated_sprite.stop()
		animated_sprite.frame = maxi(animated_sprite.sprite_frames.get_frame_count(target_animation) - 1, 0)
		return

	if animated_sprite.animation != target_animation:
		animated_sprite.play(target_animation)
	elif not animated_sprite.is_playing():
		animated_sprite.play()


# --- Áudio ---

func _play_collision_sound(collision: KinematicCollision2D) -> bool:
	var collider := collision.get_collider() as Node
	if collider == null:
		return false

	var sound: AudioStream
	if collider.is_in_group("race_kart"):
		if get_instance_id() > collider.get_instance_id():
			return false
		sound = SFX_COLISAO_KART
	elif collider.is_in_group("colisao_barreira"):
		sound = SFX_COLISAO_BARREIRA
	else:
		return false

	var player := AudioStreamPlayer2D.new()
	player.stream = sound
	player.bus = "SFX"
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
	return true


func _update_audio(delta: float, forward: Vector2, right: Vector2) -> void:
	var forward_speed: float = velocity.dot(forward)
	var abs_speed: float = absf(forward_speed)
	var lateral_speed: float = absf(velocity.dot(right))
	var speed_ratio: float = clampf(abs_speed / max_speed, 0.0, 1.0)
	var is_braking: bool = throttle_input < 0.0 and forward_speed > 40.0

	_update_brake_audio(delta, is_braking, lateral_speed)
	_update_engine_audio(delta, forward_speed, abs_speed, speed_ratio, is_braking)


func _update_brake_audio(delta: float, is_braking: bool, _lateral_speed: float) -> void:
	if brake_audio == null or brake_audio.stream == null:
		return

	if is_braking:
		if not brake_audio.playing:
			brake_audio.volume_db = -2.0
			brake_audio.play()
		brake_audio.volume_db = move_toward(brake_audio.volume_db, 0.0, 80.0 * delta)
	else:
		brake_audio.volume_db = move_toward(brake_audio.volume_db, -40.0, 100.0 * delta)
		if brake_audio.volume_db <= -38.0 and brake_audio.playing:
			brake_audio.stop()


func _update_engine_audio(
	delta: float,
	forward_speed: float,
	abs_speed: float,
	speed_ratio: float,
	is_braking: bool
) -> void:
	if engine_audio == null:
		return

	var target_pitch: float = idle_pitch
	var target_volume: float = -18.0

	if throttle_input > 0.0:
		target_pitch = lerpf(idle_pitch, max_pitch, speed_ratio)
		target_volume = 0.0
	elif is_braking:
		target_pitch = engine_brake_pitch
		target_volume = -16.0
	elif throttle_input < 0.0 and forward_speed <= 10.0:
		target_pitch = 0.6
		target_volume = -12.0
	elif is_zero_approx(throttle_input) and abs_speed > 80.0:
		target_pitch = engine_brake_pitch
		target_volume = -12.0

	engine_audio.pitch_scale = clampf(move_toward(engine_audio.pitch_scale, target_pitch, 6.0 * delta), 0.1, 4.0)
	engine_audio.volume_db = move_toward(engine_audio.volume_db, target_volume, 15.0 * delta)
