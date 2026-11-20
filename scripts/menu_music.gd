extends Node

const MENU_TRACK: AudioStream = preload(
	"res://sound/music/Menu-music.ogg"
)

var player: AudioStreamPlayer


func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.name = "MenuMusicPlayer"
	player.stream = MENU_TRACK
	player.bus = "Music"
	add_child(player)


func play_menu_music() -> void:
	if not player.playing:
		player.play()


func stop_menu_music() -> void:
	if player.playing:
		player.stop()
