
class_name DriftMarks
extends Node2D

## Container das marcas de pneu do mundo.
##
## Este no fica na cena (irmao do kart), e nao dentro do kart: assim as marcas
## ficam no chao e nao acompanham o veiculo nem a camera.
##
## Cada marca e um Sprite2D pequeno com a arte do Aseprite desenhada 1:1
## (sem escala, sem blur). Os nos sao reaproveitados: nada e criado ou
## destruido a cada frame.

## Conjuntos de arte por superficie (asfalto, grama, terra, neve...).
@export var mark_sets: Array[DriftMarkSet] = []
## Superficie usada quando o kart nao esta em nenhuma zona de piso.
@export var default_surface: StringName = &"asphalt"
## Arte usada quando a superficie atual nao tem conjunto proprio.
@export var default_texture: Texture2D
## Limite de marcas vivas ao mesmo tempo. As mais antigas sao recicladas.
@export_range(0, 2000, 1) var max_marks: int = 600
## Tempo (s) que a marca fica no chao antes de sumir. 0 = marca permanente.
@export_range(0.0, 60.0, 0.1) var mark_lifetime: float = 6.0
## Tempo (s) em que a marca vai ficando transparente no fim da vida.
@export_range(0.0, 20.0, 0.1) var fade_duration: float = 2.0
## Passos de rotacao da marca (0 = rotacao livre).
## 16 ou 32 deixa o visual mais pixelado, sem serrilhado.
@export_range(0, 64, 1) var rotation_steps: int = 0
## Como a marca e orientada.
enum OrientationMode {
	## A marca acompanha a orientacao do veiculo (o desenho do pneu).
	VEHICLE,
	## A marca acompanha o caminho do pneu: o rastro sai continuo.
	TRAVEL,
}
@export var orientation_mode: OrientationMode = OrientationMode.VEHICLE


## Uma marca viva no chao.
class Mark extends RefCounted:
	var sprite: Sprite2D
	var born: float = 0.0
	var peak_alpha: float = 1.0


## Marcas vivas, da mais antiga para a mais nova.
var _marks: Array[Mark] = []
## Sprites prontos para reuse.
var _free_sprites: Array[Sprite2D] = []
var _clock: float = 0.0


func _ready() -> void:
	add_to_group("drift_marks")
	# Nearest explicito: marca de pneu e pixel art e nao pode ficar borrada.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Coloca uma marca no chao. `world_position` e `angle` sao do mundo.
## `angle` e a orientacao do veiculo; `travel_direction` e o caminho do pneu.
## `intensity` (0..1) define a opacidade: derrapagem forte deixa a marca mais escura.
func place_mark(world_position: Vector2, angle: float, surface: StringName, intensity: float = 1.0, travel_direction: Vector2 = Vector2.ZERO) -> void:
	if max_marks <= 0:
		return

	var mark_set: DriftMarkSet = _set_for_surface(surface)
	var texture: Texture2D = default_texture if mark_set == null else mark_set.texture
	if texture == null:
		return
	var pixel_scale: float = 1.0 if mark_set == null else mark_set.pixel_scale
	var opacity: float = 0.85 if mark_set == null else mark_set.opacity

	var mark: Mark = _take_mark()
	_marks.append(mark)
	mark.sprite.texture = texture
	mark.sprite.scale = Vector2.ONE * pixel_scale
	mark.sprite.global_position = world_position
	mark.sprite.global_rotation = _quantize_angle(_mark_angle(angle, travel_direction))
	mark.sprite.visible = true
	mark.born = _clock
	mark.peak_alpha = clampf(opacity * lerpf(0.55, 1.0, intensity), 0.0, 1.0)
	mark.sprite.modulate = Color(1.0, 1.0, 1.0, mark.peak_alpha)


## Apaga todas as marcas (ex.: ao reiniciar a corrida).
func clear_marks() -> void:
	for mark in _marks:
		mark.sprite.visible = false
		_free_sprites.append(mark.sprite)
	_marks.clear()


## Quantas marcas estao vivas agora.
func get_mark_count() -> int:
	return _marks.size()


## Posicao (no mundo) de cada marca viva, da mais antiga para a mais nova.
func get_mark_positions() -> Array[Vector2]:
	var result: Array[Vector2] = []
	for mark in _marks:
		result.append(mark.sprite.global_position)
	return result


func _process(delta: float) -> void:
	_clock += delta
	if _marks.is_empty():
		return

	var fade_start: float = maxf(0.0, mark_lifetime - fade_duration)
	var index: int = _marks.size() - 1
	while index >= 0:
		var mark: Mark = _marks[index]
		var age: float = _clock - mark.born
		if mark_lifetime > 0.0 and age >= mark_lifetime:
			mark.sprite.visible = false
			_free_sprites.append(mark.sprite)
			_marks.remove_at(index)
			index -= 1
			continue
		if mark_lifetime > 0.0 and fade_duration > 0.0 and age > fade_start:
			var t: float = clampf((age - fade_start) / fade_duration, 0.0, 1.0)
			mark.sprite.modulate.a = mark.peak_alpha * (1.0 - t)
			index -= 1
			continue
		# Esta marca ainda não está desbotando. As mais antigas que vêm antes
		# também não estão: pode parar de percorrer a lista.
		break


## Pega um sprite para a marca: reaproveita um livre, cria um novo ou
## recicla a marca mais antiga quando o limite foi atingido.
## A marca devolvida ainda nao esta na lista de marcas vivas.
func _take_mark() -> Mark:
	# Limite de marcas: recicla a mais antiga em vez de criar mais.
	if not _marks.is_empty() and _marks.size() >= max_marks:
		var oldest: Mark = _marks.pop_front()
		return oldest

	if not _free_sprites.is_empty():
		var reused := Mark.new()
		reused.sprite = _free_sprites.pop_back()
		return reused

	var created := Mark.new()
	created.sprite = _create_sprite()
	return created


func _create_sprite() -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	return sprite


func _set_for_surface(surface: StringName) -> DriftMarkSet:
	for mark_set in mark_sets:
		if mark_set != null and mark_set.surface == surface:
			return mark_set
	return null


## Arredonda o angulo para um dos `rotation_steps` passos (0 = livre).
func _quantize_angle(angle: float) -> float:
	if rotation_steps <= 0:
		return angle
	var step: float = TAU / float(rotation_steps)
	return round(angle / step) * step


## Angulo final da marca, conforme o modo de orientacao escolhido.
## O eixo longo da arte e o Y do sprite: por isso o -90 graus no caminho.
func _mark_angle(vehicle_angle: float, travel_direction: Vector2) -> float:
	if orientation_mode == OrientationMode.TRAVEL and travel_direction != Vector2.ZERO:
		return travel_direction.angle() - PI * 0.5
	return vehicle_angle
