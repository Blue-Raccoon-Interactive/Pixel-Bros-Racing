extends SceneTree

## Ferramenta de montagem do sistema de rastros de pneu.
##
## Roda em headless e cria (ou recria) os recursos e a cena do sistema:
##   assets/effects/drift/mark_set_<superficie>.tres  (arte por superficie)
##   assets/effects/drift/kart_wheel_anchors.tres      (pneus traseiros por kart)
##   scenes/effects/drift_marks.tscn                   (container das marcas)
##
## Uso: godot --headless --path . --script res://tools/apply_drift_setup.gd
##
## As posicoes dos pneus traseiros foram medidas pixel a pixel nos sprites de
## 32x32 (coluna do kart dentro de assets/sprites/carros/kart_car_2camadas_*.png).
## Se a arte dos karts mudar, meca de novo e atualize a tabela abaixo.

const DRIFT_DIR := "res://assets/effects/drift"
const MARKS_SCENE_PATH := "res://scenes/effects/drift_marks.tscn"

## Medidas no sprite: coluna no sheet -> [x esquerda, x direita, y do eixo].
## O sprite fica em (0, 0) dentro de 32x32 e o AnimatedSprite2D do kart esta
## deslocado em (-0.5, 3): o pixel (px, py) do sprite fica em
## (px, py) - (16, 12.5) dentro do kart.
const WHEEL_MEASURES := {
	&"Fuguete": [3.0, 28.0, 24.5],
	&"Tanque": [4.0, 27.0, 25.5],
	&"Sapo Cururu": [5.5, 25.5, 25.5],
	&"Tronco": [4.0, 27.0, 22.0],
	&"Nave Rosa": [5.5, 25.5, 20.0],
	&"Morcego Roxo": [8.0, 23.0, 21.0],
	&"OVNI": [4.0, 27.0, 21.5],
	&"Esportivo F1": [8.5, 22.5, 23.0],
}

## Deslocamento do sprite dentro do kart: (15.5, 15.5) - (-0.5, 3).
const SPRITE_ORIGIN_OFFSET := Vector2(16.0, 12.5)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DRIFT_DIR)
	DirAccess.make_dir_recursive_absolute("res://scenes/effects")

	var mark_sets: Array[Resource] = _create_mark_sets()
	_create_wheel_anchors()
	_create_marks_scene(mark_sets)
	print("apply_drift_setup: sistema de rastros de pneu pronto.")
	quit()


## Cria um .tres de arte por superficie.
func _create_mark_sets() -> Array[Resource]:
	var mark_set_script: Script = load("res://scripts/drift_mark_set.gd")
	var result: Array[Resource] = []

	var surfaces := [
		{"name": &"asphalt", "path": "%s/asphalt/skid_mark.png", "opacity": 0.85},
		{"name": &"dirt", "path": "%s/dirt/skid_mark.png", "opacity": 0.85},
		{"name": &"grass", "path": "%s/grass/skid_mark.png", "opacity": 0.8},
		{"name": &"snow", "path": "%s/snow/skid_mark.png", "opacity": 0.75},
	]

	for surface in surfaces:
		var mark_set: Resource = mark_set_script.new()
		mark_set.set("surface", surface["name"])
		mark_set.set("texture", load(surface["path"] % DRIFT_DIR))
		mark_set.set("pixel_scale", 1.0)
		mark_set.set("opacity", surface["opacity"])
		var path: String = "%s/mark_set_%s.tres" % [DRIFT_DIR, surface["name"]]
		ResourceSaver.save(mark_set, path)
		print("  ", path)
		# Recarrega para a cena guardar a referencia do .tres (e nao uma copia).
		result.append(load(path))

	return result


## Cria a tabela com a posicao dos pneus traseiros de cada kart.
func _create_wheel_anchors() -> void:
	var anchors_script: Script = load("res://scripts/kart_wheel_anchors.gd")
	var anchors: Resource = anchors_script.new()
	var left: Dictionary = {}
	var right: Dictionary = {}

	for kart_name in WHEEL_MEASURES:
		var measure: Array = WHEEL_MEASURES[kart_name]
		var axis_y: float = measure[2]
		left[kart_name] = Vector2(measure[0], axis_y) - SPRITE_ORIGIN_OFFSET
		right[kart_name] = Vector2(measure[1], axis_y) - SPRITE_ORIGIN_OFFSET

	anchors.set("left_wheels", left)
	anchors.set("right_wheels", right)
	var path: String = "%s/kart_wheel_anchors.tres" % DRIFT_DIR
	ResourceSaver.save(anchors, path)
	print("  ", path)


## Cria a cena do container das marcas.
func _create_marks_scene(mark_sets: Array[Resource]) -> void:
	var marks_script: Script = load("res://scripts/drift_marks.gd")
	var root := Node2D.new()
	root.name = "DriftMarks"
	root.set_script(marks_script)

	# O array e tipado no script: pega a referencia e preenche por cima.
	var sets: Array = root.get("mark_sets")
	for mark_set in mark_sets:
		sets.append(mark_set)

	root.set("default_surface", &"asphalt")
	root.set("default_texture", load("%s/asphalt/skid_mark.png" % DRIFT_DIR))
	root.set("max_marks", 240)
	root.set("mark_lifetime", 6.0)
	root.set("fade_duration", 2.0)
	root.set("rotation_steps", 0)

	var scene := PackedScene.new()
	var err: int = scene.pack(root)
	if err != OK:
		push_error("apply_drift_setup: falha ao montar a cena (%d)." % err)
		return
	ResourceSaver.save(scene, MARKS_SCENE_PATH)
	print("  ", MARKS_SCENE_PATH)
