class_name UIPalette

const BG_DARK := Color("#161a33f2")
const CARD_BG := Color("#2c3363")
const CARD_BORDER := Color("#48528c")
const GOLD := Color("#f7ce3e")
const SILVER := Color("#d0d7e6")
const BRONZE := Color("#d68947")
const GOLD_SHADOW := Color("#c49a1d")
const TEXT_DARK := Color("#14172b")
const TEXT_LIGHT := Color("#ffffff")
const TEXT_MUTED := Color("#b8c0e0")


static func box(bg: Color, border: Color, border_w: int, bottom_w: int = -1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	if bottom_w >= 0:
		sb.border_width_bottom = bottom_w
	sb.set_content_margin_all(10)
	return sb


static func style_panel(c: Control) -> void:
	c.add_theme_stylebox_override("panel", box(BG_DARK, CARD_BORDER, 3))


static func style_label(l: Label, color: Color = TEXT_LIGHT, outline: bool = false) -> void:
	l.add_theme_color_override("font_color", color)
	if outline:
		l.add_theme_color_override("font_outline_color", TEXT_DARK)
		l.add_theme_constant_override("outline_size", 6)


static func _button(btn: Button, bg: Color, border: Color, border_w: int, bottom_w: int, text: Color) -> void:
	btn.add_theme_stylebox_override("normal", box(bg, border, border_w, bottom_w))
	btn.add_theme_stylebox_override("hover", box(bg.lightened(0.12), border, border_w, bottom_w))
	btn.add_theme_stylebox_override("pressed", box(bg.darkened(0.12), border, border_w, bottom_w))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		btn.add_theme_color_override(c, text)


# Amarelo com a faixa escura embaixo, igual ao "INICIAR CORRIDA"
static func primary_button(btn: Button) -> void:
	_button(btn, GOLD, GOLD_SHADOW, 0, 4, TEXT_DARK)


# Azul escuro com borda, pra ações secundárias (Voltar, Menu)
static func secondary_button(btn: Button) -> void:
	_button(btn, CARD_BG, CARD_BORDER, 2, -1, TEXT_LIGHT)


static func place_color(place: int) -> Color:
	match place:
		1: return GOLD
		2: return SILVER
		3: return BRONZE
		_: return TEXT_MUTED
