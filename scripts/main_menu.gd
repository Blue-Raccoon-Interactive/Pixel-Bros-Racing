extends Control

@onready var main_buttons: VBoxContainer = $MainButtons
@onready var options: Panel = $Options

@onready var ui_sfx: AudioStreamPlayer = $AudioStreamPlayer

const SOUND_SELECT = preload("res://sound/sfx/menu/menu_select.wav")
const SOUND_BACK = preload("res://sound/sfx/menu/menu_back.wav")
const SOUND_RACE = preload("res://sound/sfx/menu/menu_startGame.wav")

func _apply_palette() -> void:
	UIPalette.primary_button($MainButtons/StartButton)
	UIPalette.secondary_button($MainButtons/Options)
	UIPalette.secondary_button($MainButtons/Exit)
	UIPalette.secondary_button($Options/Exit) # botão Back
	UIPalette.style_panel($Options)
	for l in $Options.find_children("*", "Label", true, false):
		UIPalette.style_label(l, UIPalette.TEXT_LIGHT)

func play_ui_sound(sound: AudioStream) -> void:
	ui_sfx.stream = sound
	ui_sfx.play()
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_apply_palette()
	MenuMusic.play_menu_music() #<- Play ma trilha sonora
	main_buttons.visible = true
	options.visible = false
	 # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_start_pressed() -> void:
	play_ui_sound(SOUND_RACE)
	await get_tree().create_timer(0.38).timeout  #<- Atraso para produzir o áudio antes da mudança de cena
	get_tree().change_scene_to_file("res://scenes/ui/selection.tscn")


func _on_options_pressed() -> void:
	play_ui_sound(SOUND_SELECT)
	print("Options pressed")
	main_buttons.visible = false
	options.visible = true


func _on_exit_pressed() -> void:
	play_ui_sound(SOUND_SELECT)
	await get_tree().create_timer(0.38).timeout #<- Atraso para produzir o áudio antes da mudança de cena
	print("Exit pressed")
	get_tree().quit()


func _on_backoptions_pressed() -> void:
	play_ui_sound(SOUND_BACK)
	_ready()
