extends Control

@onready var main_buttons: VBoxContainer = $MainButtons
@onready var title: Label = $Label
@onready var options: OptionsMenu = $Options
@onready var ui_sfx: AudioStreamPlayer = $AudioStreamPlayer

const SOUND_SELECT = preload("res://sound/sfx/menu/menu_select.wav")
const SOUND_BACK = preload("res://sound/sfx/menu/menu_back.wav")
const SOUND_RACE = preload("res://sound/sfx/menu/menu_startGame.wav")

func _ready() -> void:
	_apply_palette()
	MenuMusic.play_menu_music()
	_show_main()
	options.closed.connect(_on_backoptions_pressed)

func _apply_palette() -> void:
	UIPalette.primary_button($MainButtons/StartButton)
	UIPalette.secondary_button($MainButtons/Options)
	UIPalette.secondary_button($MainButtons/Exit)

func _show_main() -> void:
	main_buttons.visible = true
	title.visible = true
	options.visible = false

func _show_options() -> void:
	main_buttons.visible = false
	title.visible = false
	options.visible = true

func play_ui_sound(sound: AudioStream) -> void:
	ui_sfx.stream = sound
	ui_sfx.play()

func _on_start_pressed() -> void:
	play_ui_sound(SOUND_RACE)
	await get_tree().create_timer(0.38).timeout
	get_tree().change_scene_to_file("res://scenes/ui/selection.tscn")

func _on_options_pressed() -> void:
	play_ui_sound(SOUND_SELECT)
	_show_options()

func _on_exit_pressed() -> void:
	play_ui_sound(SOUND_SELECT)
	await get_tree().create_timer(0.38).timeout
	get_tree().quit()

func _on_backoptions_pressed() -> void:
	play_ui_sound(SOUND_BACK)
	_show_main()
