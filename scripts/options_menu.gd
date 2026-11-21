class_name OptionsMenu
extends Panel

signal closed

@onready var back_button: Button = $Exit

func _ready() -> void:
	UIPalette.secondary_button(back_button)
	UIPalette.style_panel(self)
	for l in find_children("*", "Label", true, false):
		UIPalette.style_label(l, UIPalette.TEXT_LIGHT)
	back_button.pressed.connect(_on_back_pressed)

func _on_back_pressed() -> void:
	closed.emit()
