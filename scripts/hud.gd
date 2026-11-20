class_name Hud
extends CanvasLayer

## Gerenciador da corrida que este HUD acompanha.
@export var race_manager: RaceManager

## Caminho da cena do menu principal ao clicar em "Voltar".
@export_file("*.tscn") var main_menu_scene: String = ""

## Fonte pixelada do projeto (arraste o mesmo arquivo .ttf/.otf da tela de seleção).
@export var pixel_font: Font

# Paleta extraída da tela "Escolha seu Carro"
const COLOR_BG_DARK := Color("#161a33f2")
const COLOR_CARD_BG := Color("#2c3363")
const COLOR_CARD_BORDER := Color("#48528c")
const COLOR_GOLD := Color("#f7ce3e")
const COLOR_SILVER := Color("#d0d7e6")
const COLOR_BRONZE := Color("#d68947")
const COLOR_GOLD_SHADOW := Color("#c49a1d")
const COLOR_TEXT_DARK := Color("#14172b")
const COLOR_TEXT_LIGHT := Color("#ffffff")
const COLOR_TEXT_MUTED := Color("#b8c0e0")

@onready var lap_label: Label = $LapLabel
@onready var countdown_label: Label = $CountdownLabel
@onready var position_label: Label = $PositionLabel
@onready var results_panel: PanelContainer = $ResultsPanel
@onready var title_label: Label = $ResultsPanel/MarginContainer/MainVBox/TitleLabel
@onready var standings_list: VBoxContainer = $ResultsPanel/MarginContainer/MainVBox/StandingsList
@onready var retry_button: Button = $ResultsPanel/MarginContainer/MainVBox/ButtonsRow/RetrayButton
@onready var menu_button: Button = $ResultsPanel/MarginContainer/MainVBox/ButtonsRow/MenuButtom


func _ready() -> void:
	_apply_pixel_design()

	if results_panel != null:
		results_panel.visible = false

	if retry_button != null:
		retry_button.pressed.connect(_on_retry_pressed)

	if menu_button != null:
		menu_button.pressed.connect(_on_menu_pressed)

	if race_manager == null:
		push_error("Hud: race_manager não foi configurado!")
		return

	race_manager.countdown_changed.connect(_on_countdown_changed)
	race_manager.lap_changed.connect(_on_lap_changed)
	race_manager.placement_changed.connect(_on_placement_changed)
	race_manager.race_finished.connect(_on_race_finished)
	race_manager.finish_results_opened.connect(_on_finish_results_opened)
	race_manager.finish_results_updated.connect(_on_finish_results_updated)


func _apply_pixel_design() -> void:
	if standings_list != null:
		standings_list.size_flags_vertical = Control.SIZE_EXPAND_FILL

	if results_panel != null:
		var panel_style := StyleBoxFlat.new()
		panel_style.bg_color = COLOR_BG_DARK
		panel_style.set_border_width_all(2)
		panel_style.border_color = COLOR_CARD_BORDER
		panel_style.set_corner_radius_all(0)
		results_panel.add_theme_stylebox_override("panel", panel_style)

	if title_label != null:
		title_label.text = "CLASSIFICACAO"
		title_label.add_theme_color_override("font_color", COLOR_GOLD)
		title_label.add_theme_font_size_override("font_size", 24)
		if pixel_font != null:
			title_label.add_theme_font_override("font", pixel_font)

	if retry_button != null:
		retry_button.text = "JOGAR DE NOVO"
		_style_action_button(retry_button, true)

	if menu_button != null:
		menu_button.text = "VOLTAR"
		_style_action_button(menu_button, false)


func _style_action_button(btn: Button, is_primary: bool) -> void:
	btn.custom_minimum_size.y = 44
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.add_theme_font_size_override("font_size", 16)
	if pixel_font != null:
		btn.add_theme_font_override("font", pixel_font)

	var normal := StyleBoxFlat.new()
	normal.set_corner_radius_all(0)
	normal.content_margin_left = 14
	normal.content_margin_right = 14
	normal.content_margin_top = 8
	normal.content_margin_bottom = 10

	if is_primary:
		normal.bg_color = COLOR_GOLD
		normal.border_width_bottom = 4
		normal.border_color = COLOR_GOLD_SHADOW
		btn.add_theme_color_override("font_color", COLOR_TEXT_DARK)
		btn.add_theme_color_override("font_hover_color", COLOR_TEXT_DARK)
		btn.add_theme_color_override("font_pressed_color", COLOR_TEXT_DARK)
		btn.add_theme_color_override("font_focus_color", COLOR_TEXT_DARK)
	else:
		normal.bg_color = COLOR_CARD_BG
		normal.set_border_width_all(2)
		normal.border_color = COLOR_CARD_BORDER
		btn.add_theme_color_override("font_color", COLOR_TEXT_LIGHT)
		btn.add_theme_color_override("font_hover_color", COLOR_GOLD)
		btn.add_theme_color_override("font_pressed_color", COLOR_GOLD)
		btn.add_theme_color_override("font_focus_color", COLOR_GOLD)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = normal.bg_color.lightened(0.1)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = normal.bg_color.darkened(0.1)
	pressed.content_margin_top = 10
	pressed.content_margin_bottom = 8
	if is_primary:
		pressed.border_width_bottom = 2

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)


func _on_countdown_changed(text: String) -> void:
	countdown_label.text = text
	countdown_label.visible = text != ""


func _on_lap_changed(current_lap: int, total_laps: int) -> void:
	lap_label.text = "%d/%d" % [current_lap, total_laps]


func _on_placement_changed(rank: int, total_racers: int) -> void:
	position_label.text = "%d th" % [rank]


func _on_race_finished() -> void:
	if lap_label != null:
		lap_label.visible = false
	if position_label != null:
		position_label.visible = false
	if countdown_label != null:
		countdown_label.text = ""
		countdown_label.visible = false


func _on_finish_results_opened(finished_karts: Array[Kart]) -> void:
	_render_finished_list(finished_karts)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if results_panel != null:
		results_panel.visible = true
		results_panel.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_property(results_panel, "modulate:a", 1.0, 0.2)


func _on_finish_results_updated(finished_karts: Array[Kart]) -> void:
	_render_finished_list(finished_karts)


func _on_retry_pressed() -> void:
	get_tree().paused = false
	var err := get_tree().reload_current_scene()
	if err != OK:
		push_error("Hud: falha ao recarregar a cena. Código de erro: %s" % err)


func _on_menu_pressed() -> void:
	get_tree().paused = false
	if main_menu_scene.is_empty():
		push_warning("Hud: main_menu_scene não foi definido no Inspector.")
		return
	var err := get_tree().change_scene_to_file(main_menu_scene)
	if err != OK:
		push_error("Hud: falha ao carregar '%s'. Código de erro: %s" % [main_menu_scene, err])


func _render_finished_list(finished_karts: Array[Kart]) -> void:
	if standings_list == null:
		return

	for child in standings_list.get_children():
		child.queue_free()

	for i in finished_karts.size():
		var racer: Kart = finished_karts[i]
		var rank: int = i + 1
		var is_player: bool = (racer == race_manager.kart)

		var row := _create_standing_row(rank, _get_kart_display_name(racer), is_player)
		standings_list.add_child(row)


func _create_standing_row(rank: int, kart_display_name: String, is_player: bool) -> PanelContainer:
	var row_panel := PanelContainer.new()
	var row_style := StyleBoxFlat.new()
	row_style.set_corner_radius_all(0)
	row_style.bg_color = COLOR_CARD_BG
	row_style.content_margin_left = 14
	row_style.content_margin_right = 14
	row_style.content_margin_top = 10
	row_style.content_margin_bottom = 10

	if is_player:
		# Mesma borda amarela do cartão selecionado na tela "Escolha seu Carro"
		row_style.set_border_width_all(2)
		row_style.border_color = COLOR_GOLD
	else:
		# Detalhe superior mais claro como nos blocos do pódio/seleção
		row_style.border_width_top = 3
		row_style.border_color = COLOR_CARD_BORDER

	row_panel.add_theme_stylebox_override("panel", row_style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 14)
	row_panel.add_child(hbox)

	var rank_label := Label.new()
	rank_label.text = "%d th" % rank
	rank_label.custom_minimum_size.x = 64
	rank_label.add_theme_font_size_override("font_size", 16)
	rank_label.add_theme_color_override("font_color", _get_podium_rank_color(rank))
	if pixel_font != null:
		rank_label.add_theme_font_override("font", pixel_font)
	hbox.add_child(rank_label)

	var name_label := Label.new()
	name_label.text = kart_display_name.to_upper()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", COLOR_TEXT_LIGHT)
	if pixel_font != null:
		name_label.add_theme_font_override("font", pixel_font)
	hbox.add_child(name_label)

	return row_panel


func _get_podium_rank_color(rank: int) -> Color:
	match rank:
		1:
			return COLOR_GOLD
		2:
			return COLOR_SILVER
		3:
			return COLOR_BRONZE
		_:
			return COLOR_TEXT_MUTED


func _get_kart_display_name(racer: Kart) -> String:
	if racer == null:
		return "Kart"

	var raw_name: Variant = racer.get("kart_name")
	var custom_name: String = str(raw_name).strip_edges() if raw_name != null else ""

	if not custom_name.is_empty():
		return "%s (VOCE)" % custom_name if racer == race_manager.kart else custom_name

	return "VOCE" if racer == race_manager.kart else racer.name
