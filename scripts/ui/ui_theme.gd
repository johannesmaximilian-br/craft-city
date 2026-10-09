class_name UiTheme
extends RefCounted
## Zentrales Styling im Look des Cube World Kits: helle, blockige Karten mit
## Holzrand und "Tiefe" an der Unterkante, Buttons wie drückbare Blöcke.

const PANEL := Color("fbf3e2")
const PANEL_EDGE := Color("6b4423")
const BTN := Color("efe1c2")
const BTN_HOVER := Color("f8eed6")
const BTN_EDGE := Color("c6ad80")
const BTN_ON := Color("a5d65f")
const BTN_ON_EDGE := Color("5f8f2d")
const TEXT := Color("3b2a1e")
const TEXT_DIM := Color("8a6f58")
const GOOD := Color("3f8f2a")
const BAD := Color("c0392b")
const WARN := Color("8a4b00")
const TOAST := Color("ffe9a8")
const RES := Color("4caf50")
const COM := Color("3d7fd9")
const IND := Color("e0a21a")

const FONT_REGULAR := preload("res://assets/fonts/Silkscreen-Regular.ttf")
const FONT_BOLD := preload("res://assets/fonts/Silkscreen-Bold.ttf")


static func font(bold := false) -> Font:
	var f: FontFile = (FONT_BOLD if bold else FONT_REGULAR).duplicate()
	f.hinting = TextServer.HINTING_NONE
	f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	return f


## Karte: Holzrand, unten dicker (Blocktiefe), weicher Schatten.
static func card(radius := 10, pad := 10, bg := PANEL, edge := PANEL_EDGE) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	s.content_margin_left = pad + 4
	s.content_margin_right = pad + 4
	s.content_margin_bottom = pad + 3
	s.border_color = edge
	s.set_border_width_all(3)
	s.border_width_bottom = 6
	s.shadow_color = Color(0.15, 0.1, 0.05, 0.25)
	s.shadow_size = 8
	s.shadow_offset = Vector2(0, 5)
	s.anti_aliasing = true
	return s


static func _btn(bg: Color, edge: Color, pressed: bool) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(8)
	s.set_content_margin_all(5)
	s.border_color = edge
	s.set_border_width_all(2)
	# Gedrückt: weniger Unterkante, Inhalt rutscht nach unten
	s.border_width_bottom = 2 if pressed else 5
	s.content_margin_top = 8 if pressed else 5
	s.content_margin_bottom = 2 if pressed else 5
	return s


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = 16

	t.set_stylebox("panel", "PanelContainer", card())
	t.set_color("font_color", "Label", TEXT)

	t.set_stylebox("normal", "Button", _btn(BTN, BTN_EDGE, false))
	t.set_stylebox("hover", "Button", _btn(BTN_HOVER, BTN_EDGE, false))
	t.set_stylebox("pressed", "Button", _btn(BTN_ON, BTN_ON_EDGE, true))
	t.set_stylebox("hover_pressed", "Button", _btn(BTN_ON.lightened(0.1), BTN_ON_EDGE, true))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("disabled", "Button", _btn(BTN, BTN_EDGE, false))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", TEXT)
	t.set_font_size("font_size", "Button", 16)

	var tip := card(6, 6)
	tip.shadow_size = 4
	tip.set_border_width_all(2)
	tip.border_width_bottom = 4
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 16)

	var track := StyleBoxFlat.new()
	track.bg_color = BTN_EDGE
	track.set_corner_radius_all(4)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = BTN_ON
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)

	var sep := StyleBoxLine.new()
	sep.color = Color(PANEL_EDGE, 0.25)
	sep.vertical = true
	sep.thickness = 3
	sep.grow_begin = -6
	sep.grow_end = -6
	t.set_stylebox("separator", "VSeparator", sep)
	t.set_constant("separation", "VSeparator", 14)
	return t
