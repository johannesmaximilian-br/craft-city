class_name PopUI
extends RefCounted
## Bausteine für Popover/Karten im HUD: Kopf, Abschnitte, zweispaltige Zeilen, Balken, Plaketten.
## Einheitlich statt Fließtext: Bezeichnung links gedämpft, Wert rechts fett/farbig.

const WIDTH := 440                  # Standardbreite eines Popovers (Text bricht um)
const ACCENT := Color("9a6a3a")     # Abschnittsüberschriften
const TRACK := Color("e6d6b4")      # Balken-Hintergrund


static func label(parent: Node, text: String, size := 16, color := UiTheme.TEXT, bold := false, wrap := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", UiTheme.font(true))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size.x = 120
	parent.add_child(l)
	return l


## Kopf: Icon, Titel (+ Unterzeile), rechts große Kennzahl.
static func header(parent: Node, icon: Texture2D, title: String, value := "", value_color := UiTheme.TEXT,
		sub := "") -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	parent.add_child(h)
	if icon != null:
		var r := TextureRect.new()
		r.texture = icon
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.custom_minimum_size = Vector2(40, 40)
		h.add_child(r)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(col)
	label(col, title, 20, UiTheme.TEXT, true)
	if sub != "":
		label(col, sub, 14, UiTheme.TEXT_DIM, false, true)
	if value != "":
		label(h, value, 22, value_color, true)
	return h


## Abschnitt: farbige Überschrift + Linie; Rückgabe = Container für die Zeilen.
static func section(parent: Node, title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	parent.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)
	label(head, title.to_upper(), 14, ACCENT, true)
	var line := ColorRect.new()
	line.color = Color(ACCENT, 0.35)
	line.custom_minimum_size = Vector2(0, 2)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(line)
	return box


## Zeile: Bezeichnung links (gedämpft), Wert rechts (fett, farbig); optional Hinweis klein darunter.
static func row(parent: Node, name: String, value: String, value_color := UiTheme.TEXT, hint := "") -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	parent.add_child(h)
	var n := label(h, name, 16, UiTheme.TEXT_DIM, false, true)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := label(h, value, 16, value_color, true)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if hint != "":
		note(parent, "-> " + hint)
	return h


## Kleiner, gedämpfter Text mit Umbruch.
static func note(parent: Node, text: String, color := UiTheme.TEXT_DIM) -> Label:
	return label(parent, text, 14, color, false, true)


## Fortschritts-/Anteilsbalken (0..1).
static func bar(parent: Node, frac: float, color: Color, height := 10) -> Control:
	var track := ColorRect.new()
	track.color = TRACK
	track.custom_minimum_size = Vector2(0, height)
	track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(track)
	var fill := ColorRect.new()
	fill.color = color
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.anchor_bottom = 1.0
	fill.anchor_right = clampf(frac, 0.0, 1.0)
	track.add_child(fill)
	return track


## Balken um eine Mitte: negativ rot nach links, positiv grün nach rechts (|v| / vmax).
static func diverging(parent: Node, v: float, vmax: float, height := 8) -> Control:
	var track := ColorRect.new()
	track.color = TRACK
	track.custom_minimum_size = Vector2(120, height)
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(track)
	var f := clampf(absf(v) / maxf(vmax, 0.001), 0.0, 1.0) * 0.5
	var fill := ColorRect.new()
	fill.color = UiTheme.GOOD if v >= 0.0 else UiTheme.BAD
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.anchor_bottom = 1.0
	fill.anchor_left = 0.5 if v >= 0.0 else 0.5 - f
	fill.anchor_right = 0.5 + f if v >= 0.0 else 0.5
	track.add_child(fill)
	var mid := ColorRect.new()
	mid.color = UiTheme.TEXT_DIM
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.anchor_left = 0.5
	mid.anchor_right = 0.5
	mid.anchor_bottom = 1.0
	mid.offset_left = -1
	mid.offset_right = 1
	track.add_child(mid)
	return track


## Plakette: farbig umrandetes Kästchen mit kurzem Text (Status).
static func chip(parent: Node, text: String, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(color, 0.15)
	s.border_color = color
	s.set_border_width_all(2)
	s.set_corner_radius_all(6)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(p)
	label(p, text, 13, color, true)
	return p


## Innere Karte (z.B. je Forschungsprojekt): heller Kasten mit dünnem Rand.
static func box(parent: Node, edge := UiTheme.BTN_EDGE, bg := Color("fffaf0")) -> VBoxContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(2)
	s.set_corner_radius_all(8)
	s.set_content_margin_all(8)
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	return v


## Roter Problemkasten (Liste von Texten).
static func problems(parent: Node, lines: PackedStringArray) -> void:
	if lines.is_empty():
		return
	var v := box(parent, UiTheme.BAD, Color("fdecea"))
	for t in lines:
		var l := label(v, t.trim_prefix("x ").trim_prefix("X "), 15, UiTheme.BAD, false, true)
		l.custom_minimum_size.x = 200


## Klickbarer Listeneintrag: Titel (fett) + Kennzahl rechts, Details klein darunter; aktiv = grün hinterlegt.
static func list_item(parent: Node, title: String, value: String, detail: String, active: bool, on_click: Callable) -> PanelContainer:
	var p := PanelContainer.new()
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(UiTheme.BTN_ON, 0.35) if active else Color(0, 0, 0, 0)
	normal.border_color = UiTheme.BTN_ON_EDGE if active else Color(0, 0, 0, 0)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(UiTheme.BTN_ON, 0.5) if active else UiTheme.BTN_HOVER
	hover.border_color = UiTheme.BTN_ON_EDGE if active else UiTheme.BTN_EDGE
	p.add_theme_stylebox_override("panel", normal)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	p.mouse_entered.connect(func() -> void: p.add_theme_stylebox_override("panel", hover))
	p.mouse_exited.connect(func() -> void: p.add_theme_stylebox_override("panel", normal))
	p.gui_input.connect(func(ev: InputEvent) -> void:
		var mb := ev as InputEventMouseButton
		if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			on_click.call())
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	var h := HBoxContainer.new()
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(h)
	var t := label(h, title, 16, UiTheme.TEXT, true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if value != "":
		label(h, value, 16, UiTheme.TEXT, true)
	if detail != "":
		note(v, detail)
	return p
