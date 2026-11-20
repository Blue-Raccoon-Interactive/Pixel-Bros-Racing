extends Control

@onready var kart_left: TextureRect = $Control/Podium_left/TextureRect
@onready var kart_center: TextureRect = $Control/Podium_center/TextureRect
@onready var kart_right: TextureRect = $Control/Podium_right/TextureRect
@onready var name_label: Label = $Control/Podium_center/KartName
@onready var bar_speed: ProgressBar = $Control/Podium_center/VBoxContainer/Vel/BarVel
@onready var bar_accel: ProgressBar = $Control/Podium_center/VBoxContainer/Ace/BarAce
@onready var bar_handling: ProgressBar = $Control/Podium_center/VBoxContainer/Ctr/BarCtr
@onready var start_button: TextureButton = %StartButton
@onready var ui_sfx: AudioStreamPlayer = $AudioStreamPlayer

@onready var btn_left: TextureButton = $Left
@onready var btn_right: TextureButton = $Right


const SOUND_SELECT = preload("res://sound/sfx/menu/menu_select.wav")
const SOUND_BACK = preload("res://sound/sfx/menu/menu_back.wav")
const SOUND_RACE = preload("res://sound/sfx/menu/menu_startGame.wav")

var _karts: Array[Dictionary] = []
var _kart_index: int = 0
var _max: Dictionary = {}


func _ready() -> void:
	MenuMusic.play_menu_music() #<- Play da musica
	_read_kart_data()
	_kart_index = GameState.selected_kart
	_refresh()
	btn_left.pressed.connect(_move_kart.bind(-1))
	btn_right.pressed.connect(_move_kart.bind(1))

func play_ui_sound(sound: AudioStream) -> void:
	ui_sfx.stream = sound
	ui_sfx.play()
	
func _read_kart_data() -> void:
	for scene in GameState.KART_SCENES:
		print("Lendo: ", scene.resource_path)
		var k: Kart = scene.instantiate()
		_karts.append({
			"name": k.kart_name,
			"texture": k.kart_sprite_texture,
			"speed": k.max_speed,
			"accel": k.acceleration,
			"handling": k.rotation_speed,
		})
		k.free()

	for key in ["speed", "accel", "handling"]:
		_max[key] = _karts.map(func(d): return d[key]).max()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("steer_left"):
		_move_kart(-1)
	elif event.is_action_pressed("steer_right"):
		_move_kart(1)
	elif event.is_action_pressed("accelerate"):
		_move_track(-1)
	elif event.is_action_pressed("brake"):
		_move_track(1)
	elif event.is_action_pressed("ui_accept"):
		_confirm()
	elif event.is_action_pressed("ui_cancel"):
		play_ui_sound(SOUND_BACK)
		await get_tree().create_timer(0.38).timeout  #<- Atraso para produzir o áudio antes da mudança de cena
		get_tree().change_scene_to_file("res://scenes/main/main_menu.tscn")
		


func _move_kart(dir: int) -> void:
	play_ui_sound(SOUND_SELECT)
	_kart_index = wrapi(_kart_index + dir, 0, _karts.size())
	_refresh()
	


func _move_track(dir: int) -> void:
	GameState.selected_track = wrapi(
		GameState.selected_track + dir, 0, GameState.TRACKS.size()
	)
	# TODO: destacar o card da pista quando eles virarem nós separados.


func _confirm() -> void:
	play_ui_sound(SOUND_RACE)
	await get_tree().create_timer(0.38).timeout  #<- Atraso para produzir o áudio antes da mudança de cena
	start_button.modulate = Color(0.7, 0.7, 0.7)
	GameState.selected_kart = _kart_index
	GameState.has_selection = true
	get_tree().change_scene_to_file("res://scenes/race/race_test.tscn")


func _refresh() -> void:
	var n: int = _karts.size()
	kart_left.texture = _karts[wrapi(_kart_index - 1, 0, n)].texture
	kart_center.texture = _karts[_kart_index].texture
	kart_right.texture = _karts[wrapi(_kart_index + 1, 0, n)].texture

	var d: Dictionary = _karts[_kart_index]
	name_label.text = String(d.name).to_upper()
	bar_speed.value = d.speed / _max.speed * 100.0
	bar_accel.value = d.accel / _max.accel * 100.0
	bar_handling.value = d.handling / _max.handling * 100.0


func _on_start_button_pressed() -> void:
	_confirm()
