extends HSlider

@export var audio_bus_name: String
var audio_bus_id: int = -1


func _ready() -> void:
	audio_bus_id = AudioServer.get_bus_index(audio_bus_name)
	if audio_bus_id == -1:
		push_warning("SoundController: bus '%s' não existe." % audio_bus_name)
		return
	# Lê o volume real do bus, sem disparar value_changed.
	set_value_no_signal(db_to_linear(AudioServer.get_bus_volume_db(audio_bus_id)))


func _on_value_changed(value: float) -> void:
	if audio_bus_id == -1:
		return
	AudioServer.set_bus_volume_db(audio_bus_id, linear_to_db(value))
