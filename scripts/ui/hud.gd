class_name Hud
extends CanvasLayer
## Schwebende HUD-Karten: Finanzen, Stadtwerte, RCI/Steuer/Tempo, Werkzeugleiste, Infos.

signal save_requested(slot: String)
signal load_requested(slot: String)
signal new_city_requested
signal overlay_selected(mode: int)   # TrafficOverlay.Mode
signal graphics_changed
signal focus_requested(tile: Vector2i)

const MARGIN := 16.0
const SLOT_NAMES := {"quick": "Schnellspeicher", "1": "Slot 1", "2": "Slot 2", "3": "Slot 3"}
const SPEED_ICONS := ["pause", "play", "fast", "fastest"]
const SPEED_NAMES := ["Pause [P]", "Normal", "Schnell", "Sehr schnell"]

## Werkzeugleiste: je Eintrag ein Button; mehrere Werkzeuge = ausklappbare Gruppe, [] = Trenner
const TOOLBAR := [
	[ToolController.Tool.INSPECT],
	[],
	[ToolController.Tool.ROAD, ToolController.Tool.BUS_STOP],
	[ToolController.Tool.RAIL, ToolController.Tool.STATION],
	[ToolController.Tool.POWERLINE, ToolController.Tool.COAL, ToolController.Tool.WIND],
	[],
	[ToolController.Tool.RES],
	[ToolController.Tool.COM],
	[ToolController.Tool.IND],
	[],
	[ToolController.Tool.TREE, ToolController.Tool.PARK],
	[ToolController.Tool.RAISE, ToolController.Tool.LOWER],
	[],
	[ToolController.Tool.POLICE, ToolController.Tool.FIRE, ToolController.Tool.SCHOOL, ToolController.Tool.HOSPITAL],
	[ToolController.Tool.LIBRARY, ToolController.Tool.CINEMA, ToolController.Tool.TOWNHALL,
		ToolController.Tool.THEATER, ToolController.Tool.STADIUM],
	[],
	[ToolController.Tool.BULLDOZE],
]

var sim: Simulation
var tools: ToolController
var map: CityMap
var icons: IconFactory
var fire_dept: FireDept

var _money: Label
var _money_delta: Label
var _date: Label
var _pop: Label
var _jobs: Label
var _power: Label
var _happy_btn: Button
var _view_btn: Button
var _overlay_mode := 0
var _popup: PanelContainer         # Ausklapp-Liste unter Ansicht-/Zufriedenheits-Button
var _popup_col: VBoxContainer
var _popup_kind := ""              # "view" / "happy" / "" = zu
var _menu: PanelContainer
var _slot_labels := {}
var _speed_before_menu := 1
var _tax_labels := {}           # Zone -> Label
var _fare_btn: Button
var _tool_title: Label
var _tool_hint: Label
var _info_card: PanelContainer
var _info_title: Label
var _info_body: Label
var _cost_pill: PanelContainer
var _cost: Label
var _toast_pill: PanelContainer
var _toast: Label
var _rci: RciGraph
var _group_buttons := {}        # Gruppen-Index -> Button
var _group_current := {}        # Gruppen-Index -> zuletzt gewähltes Werkzeug
var _tool_group := {}           # Werkzeug -> Gruppen-Index
var _flyout: PanelContainer
var _flyout_col: VBoxContainer
var _flyout_group := -1
var _gfx_buttons: Array[Button] = []
var _speed_buttons: Array[Button] = []
var _toast_time := 0.0
var _toast_target := Vector2i(-1, -1)  # Ort der Meldung (Klick/Tab springt hin)
var _fire_pill: PanelContainer
var _fire_btn: Button
var _fire_next := 0


class RciGraph:
	extends Control
	var values := [0.0, 0.0, 0.0]
	const COLORS := [UiTheme.RES, UiTheme.COM, UiTheme.IND]
	const LABELS := ["W", "G", "I"]

	func _init() -> void:
		custom_minimum_size = Vector2(100, 64)
		tooltip_text = "Nachfrage: Wohnen / Gewerbe / Industrie"

	func _draw() -> void:
		var font := get_theme_default_font()
		var mid := (size.y - 18.0) * 0.5
		var bar_w := 20.0
		var gap := (size.x - bar_w * 3.0) / 4.0
		draw_rect(Rect2(0, 0, size.x, size.y - 18.0), Color(0.42, 0.27, 0.14, 0.08))
		for k in 3:
			var x := gap + k * (bar_w + gap)
			var v: float = values[k]
			var hgt := v * (mid - 2.0)
			var col: Color = COLORS[k]
			draw_rect(Rect2(x, mid - maxf(hgt, 0.0), bar_w, absf(hgt)), col)
			draw_string(font, Vector2(x + 5, size.y - 1), LABELS[k], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, col)
		draw_line(Vector2(0, mid), Vector2(size.x, mid), Color(UiTheme.PANEL_EDGE, 0.6), 2.0)


func setup(simulation: Simulation, tool_ctrl: ToolController, city_map: CityMap, icon_factory: IconFactory,
		fires: FireDept) -> void:
	icons = icon_factory
	fire_dept = fires
	sim = simulation
	tools = tool_ctrl
	map = city_map
	_build()
	sim.stats_changed.connect(_refresh)
	sim.message.connect(show_message)
	tools.message.connect(show_message)
	fire_dept.alert.connect(show_message)
	tools.hover_changed.connect(_on_hover)
	tools.preview_cost_changed.connect(_on_cost)
	_refresh()


# ---------------------------------------------------------------- Aufbau

func _build() -> void:
	var root := Control.new()
	root.theme = UiTheme.build()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# Oben links: Geld + Datum
	# Linke Spalte: Finanzen, darunter Stadtwerte
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(left)
	var tl := _card(left)
	tl.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var tl_row := _row(tl, 12)
	_icon(tl_row, "money", 44, "Stadtkasse")
	var money_col := VBoxContainer.new()
	money_col.add_theme_constant_override("separation", -4)
	tl_row.add_child(money_col)
	_money = _label(money_col, 24)
	_money.add_theme_font_override("font", UiTheme.font(true))
	_money_delta = _label(money_col, 16, UiTheme.TEXT_DIM)
	tl_row.add_child(VSeparator.new())
	_date = _label(tl_row, 16)
	_date.add_theme_font_override("font", UiTheme.font(true))
	tl_row.add_child(VSeparator.new())
	_text_button(tl_row, "Menü", toggle_menu, "Speichern / Laden [Esc]").custom_minimum_size = Vector2(72, 36)

	# Oben Mitte: Einwohner, Jobs, Strom
	var tc := _card(left)
	tc.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var tc_row := _row(tc, 10)
	_icon(tc_row, "people", 40, "Einwohner")
	_pop = _label(tc_row, 16)
	_pop.add_theme_font_override("font", UiTheme.font(true))
	tc_row.add_child(VSeparator.new())
	_icon(tc_row, "jobs", 32, "Arbeitsplätze")
	_jobs = _label(tc_row, 16)
	_jobs.add_theme_font_override("font", UiTheme.font(true))
	tc_row.add_child(VSeparator.new())
	_icon(tc_row, "bolt", 32, "Strom: Verbrauch / Kapazität")
	_power = _label(tc_row, 16)
	_power.add_theme_font_override("font", UiTheme.font(true))
	tc_row.add_child(VSeparator.new())
	_happy_btn = _text_button(tc_row, "-", _toggle_popup.bind("happy"), "")
	_set_btn_icon(_happy_btn, "happy")
	_happy_btn.add_theme_font_override("font", UiTheme.font(true))
	tc_row.add_child(VSeparator.new())
	# Ansichten + weitere Kennzahlen als Ausklapp-Liste
	_view_btn = _text_button(tc_row, "", _toggle_popup.bind("view"),
		"Ansicht wählen [V]\nmit Stau, ÖPNV, Bodenwert, Kriminalität ...")
	_set_btn_icon(_view_btn, "stats")

	# Oben rechts: RCI, Steuer, Tempo
	var tr := _card(root)
	var tr_row := _row(tr, 10)
	_rci = RciGraph.new()
	tr_row.add_child(_rci)
	tr_row.add_child(VSeparator.new())
	var tax_col := VBoxContainer.new()
	tax_col.alignment = BoxContainer.ALIGNMENT_CENTER
	tax_col.add_theme_constant_override("separation", 0)
	tr_row.add_child(tax_col)
	var tax_head := _label(tax_col, 16, UiTheme.TEXT_DIM)
	tax_head.text = "STEUER"
	tax_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Je Zone ein Regler; Industrie verträgt mehr (dreckig), Wohnen ist empfindlich
	var tips := {Config.Zone.RES: "Wohnen: empfindlich - Zufriedenheit und Zuzug sinken",
		Config.Zone.COM: "Gewerbe: mittel - Gewerbe-Nachfrage sinkt",
		Config.Zone.IND: "Industrie: robust - verträgt höhere Sätze"}
	for zn: int in [Config.Zone.RES, Config.Zone.COM, Config.Zone.IND]:
		var tax_row := _row(tax_col, 2)
		var tag := _label(tax_row, 16, [UiTheme.TEXT, UiTheme.RES, UiTheme.COM, UiTheme.IND][zn])
		tag.text = ["", "W", "G", "I"][zn]
		tag.custom_minimum_size.x = 18
		var tip: String = tips[zn] + "\nneutral %d%%" % roundi(Config.TAX_NEUTRAL[zn] * 100.0)
		_text_button(tax_row, "-", _change_tax.bind(zn, -0.01), tip).custom_minimum_size = Vector2(28, 26)
		var l := _label(tax_row, 16)
		l.add_theme_font_override("font", UiTheme.font(true))
		l.custom_minimum_size.x = 44
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_tax_labels[zn] = l
		_text_button(tax_row, "+", _change_tax.bind(zn, 0.01), tip).custom_minimum_size = Vector2(28, 26)
	_fare_btn = _text_button(tax_col, "", _cycle_fare, "")
	_fare_btn.custom_minimum_size = Vector2(0, 26)
	tr_row.add_child(VSeparator.new())
	for s in 4:
		var b := _icon_button(tr_row, SPEED_ICONS[s], SPEED_NAMES[s], _set_speed.bind(s), 44)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_speed_buttons.append(b)

	# Unten Mitte: Werkzeugtitel + Werkzeugleiste
	var bottom := VBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_theme_constant_override("separation", 8)
	root.add_child(bottom)
	var title_pill := _card(bottom, 10, 4)
	title_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var title_col := VBoxContainer.new()
	title_col.add_theme_constant_override("separation", 0)
	title_pill.add_child(title_col)
	_tool_title = _label(title_col, 16)
	_tool_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tool_title.add_theme_font_override("font", UiTheme.font(true))
	_tool_hint = _label(title_col, 16, UiTheme.TEXT_DIM)
	_tool_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bar := _card(bottom, 16, 6)
	var bar_row := _row(bar, 4)
	for g in TOOLBAR.size():
		var entry: Array = TOOLBAR[g]
		if entry.is_empty():
			bar_row.add_child(VSeparator.new())
			continue
		var first: ToolController.Tool = entry[0]
		var b := _icon_button(bar_row, ToolController.TOOLS[first]["icon"], _tool_tip(first), _on_group_pressed.bind(g), 64)
		_group_buttons[g] = b
		_group_current[g] = first
		for t: ToolController.Tool in entry:
			_tool_group[t] = g
		if entry.size() > 1:
			# Ausklapp-Hinweis oben rechts
			var mark := _label(b, 16, UiTheme.TEXT_DIM)
			mark.text = "^"
			mark.position = Vector2(48, -2)
	_popup = _card(root, 10, 8)
	_popup.visible = false
	_popup_col = VBoxContainer.new()
	_popup_col.add_theme_constant_override("separation", 4)
	_popup.add_child(_popup_col)

	_flyout = _card(root, 10, 6)
	_flyout.visible = false
	_flyout_col = VBoxContainer.new()
	_flyout_col.add_theme_constant_override("separation", 4)
	_flyout.add_child(_flyout_col)

	# Unten links: Tile-Info
	_info_card = _card(left)
	_info_card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var info_col := VBoxContainer.new()
	info_col.add_theme_constant_override("separation", 2)
	_info_card.add_child(info_col)
	_info_title = _label(info_col, 16)
	_info_title.add_theme_font_override("font", UiTheme.font(true))
	_info_body = _label(info_col, 16, UiTheme.TEXT_DIM)

	# Kosten am Cursor
	_cost_pill = _card(root, 8, 3)
	_cost = _label(_cost_pill, 16)

	# Meldungen
	_toast_pill = _card(root, 10, 8)
	_toast_pill.add_theme_stylebox_override("panel", UiTheme.card(10, 8, UiTheme.TOAST))
	_toast = _label(_toast_pill, 16, UiTheme.WARN)
	_toast_pill.visible = false
	_toast_pill.gui_input.connect(_on_toast_input)

	# Laufende Brände: Klick/Tab springt reihum hin
	_fire_pill = _card(root, 10, 4)
	_fire_pill.add_theme_stylebox_override("panel", UiTheme.card(10, 4, UiTheme.TOAST))
	_fire_btn = _text_button(_fire_pill, "", jump_to_fire, "Zum nächsten Brand springen [Tab]")
	_set_btn_icon(_fire_btn, "fire")
	_fire_btn.add_theme_color_override("font_color", UiTheme.BAD)
	_fire_pill.visible = false

	_anchor(left, Control.PRESET_TOP_LEFT, Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_END)
	_anchor(tr, Control.PRESET_TOP_RIGHT, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_END)
	_anchor(bottom, Control.PRESET_CENTER_BOTTOM, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN)
	_anchor(_toast_pill, Control.PRESET_CENTER_TOP, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_END)
	_toast_pill.offset_top += 170
	_toast_pill.offset_bottom += 170
	_anchor(_fire_pill, Control.PRESET_CENTER_TOP, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_END)
	_fire_pill.offset_top += 110
	_fire_pill.offset_bottom += 110

	_build_menu(root)

	_select_tool(ToolController.Tool.INSPECT)
	_set_speed(1)


func _build_menu(root: Control) -> void:
	_menu = _card(root, 12, 16)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	_menu.add_child(col)
	var title := _label(col, 24)
	title.text = "Spielstand"
	title.add_theme_font_override("font", UiTheme.font(true))
	for slot: String in SaveManager.SLOTS:
		var row := _row(col, 8)
		row.alignment = BoxContainer.ALIGNMENT_BEGIN
		var info := _label(row, 16)
		info.custom_minimum_size.x = 540
		_slot_labels[slot] = info
		_text_button(row, "Speichern", func(): save_requested.emit(slot); _refresh_slots(), "").custom_minimum_size.x = 120
		_text_button(row, "Laden", func(): load_requested.emit(slot); toggle_menu(), "").custom_minimum_size.x = 90
	col.add_child(HSeparator.new())
	var gfx_row := _row(col, 8)
	gfx_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	var gfx_label := _label(gfx_row, 16)
	gfx_label.text = "Grafik"
	gfx_label.custom_minimum_size.x = 160
	_gfx_buttons.clear()
	for p in GraphicsSettings.NAMES.size():
		var b := _text_button(gfx_row, GraphicsSettings.NAMES[p], _set_graphics.bind(p), "")
		b.toggle_mode = true
		b.custom_minimum_size.x = 110
		b.set_pressed_no_signal(p == GraphicsSettings.current)
		_gfx_buttons.append(b)
	var vs := _text_button(gfx_row, "VSync", func(): _toggle_vsync(), "Bildsynchronisation (verhindert Tearing)")
	vs.toggle_mode = true
	vs.custom_minimum_size.x = 100
	vs.set_pressed_no_signal(GraphicsSettings.vsync)
	for bus: String in ["Music", "SFX", "Ambient"]:
		var row := _row(col, 12)
		row.alignment = BoxContainer.ALIGNMENT_BEGIN
		var l := _label(row, 16)
		l.text = {"Music": "Musik", "SFX": "Effekte", "Ambient": "Umgebung"}[bus]
		l.custom_minimum_size.x = 160
		var slider := HSlider.new()
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = Audio.volumes[bus]
		slider.custom_minimum_size = Vector2(320, 28)
		slider.focus_mode = Control.FOCUS_NONE
		slider.value_changed.connect(func(v): Audio.set_volume(bus, v))
		row.add_child(slider)
	col.add_child(HSeparator.new())
	var bottom := _row(col, 8)
	_text_button(bottom, "Neue Stadt", func(): new_city_requested.emit(); toggle_menu(), "Neue Karte, Startkapital").custom_minimum_size.x = 160
	_text_button(bottom, "Weiter", toggle_menu, "").custom_minimum_size.x = 120
	var hint := _label(col, 16, UiTheme.TEXT_DIM)
	hint.text = "F5 Schnellspeichern  ·  F9 Schnellladen  ·  M Musik an/aus"
	_anchor(_menu, Control.PRESET_CENTER, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BOTH)
	_menu.visible = false


func _set_graphics(p: int) -> void:
	GraphicsSettings.current = p as GraphicsSettings.Preset
	GraphicsSettings.save()
	for k in _gfx_buttons.size():
		_gfx_buttons[k].set_pressed_no_signal(k == p)
	graphics_changed.emit()


func _toggle_vsync() -> void:
	GraphicsSettings.vsync = not GraphicsSettings.vsync
	GraphicsSettings.save()
	graphics_changed.emit()


func toggle_menu() -> void:
	_menu.visible = not _menu.visible
	if _menu.visible:
		_speed_before_menu = sim.speed
		_set_speed(0)
		_refresh_slots()
	else:
		_set_speed(_speed_before_menu if _speed_before_menu > 0 else 1)


func _refresh_slots() -> void:
	for slot: String in _slot_labels:
		var m := SaveManager.meta(slot)
		var text: String = SLOT_NAMES[slot] + ":  "
		if m.is_empty():
			text += "leer"
		else:
			text += "%s  ·  %s Einw.  ·  $%s" % [m.get("date", "?"), _fmt(m.get("population", 0)), _fmt(m.get("money", 0))]
		_slot_labels[slot].text = text


func _toggle_overlay() -> void:
	overlay_selected.emit((_overlay_mode + 1) % TrafficOverlay.MODE_NAMES.size())


## Vom Spiel nach dem Umschalten aufgerufen ("" = aus).
func set_overlay_mode(mode: int, mode_name: String, quiet := false) -> void:
	_overlay_mode = mode
	_view_btn.text = "Ansicht: %s  v" % (mode_name if mode_name != "" else "aus")
	_view_btn.set_pressed_no_signal(mode != 0)
	if not quiet:
		show_message("Ansicht: " + mode_name if mode_name != "" else "Ansicht aus")
	if _popup_kind == "view":
		_fill_popup()


func _toggle_popup(kind: String) -> void:
	var btn := _view_btn if kind == "view" else _happy_btn
	if _popup_kind == kind:
		_close_popup()
		return
	_popup_kind = kind
	_fill_popup()
	_popup.visible = true
	_popup.reset_size()
	var r := btn.get_global_rect()
	_popup.position = Vector2(r.position.x, r.end.y + 8)
	btn.set_pressed_no_signal(true)


func _close_popup() -> void:
	_popup.visible = false
	_popup_kind = ""
	_happy_btn.set_pressed_no_signal(false)
	_view_btn.set_pressed_no_signal(_overlay_mode != 0)


func _fill_popup() -> void:
	for c in _popup_col.get_children():
		c.queue_free()
	if _popup_kind == "view":
		var avg := _city_averages()
		var stats := ["Karte ohne Einfärbung",
			"Stau Ø %d%%  ·  ÖPNV %d%%" % [roundi(sim.avg_congestion * 100.0), roundi(sim.transit_share * 100.0)],
			"Ø %.1f bei Wohnhäusern" % avg[0],
			"Ø %d%% bei Wohnhäusern" % roundi(avg[1] * 100.0),
			"Ø %d%%  ·  Arbeitslos %d%%" % [roundi(avg[2] * 100.0), roundi(sim.unemployment * 100.0)],
			"Stadt %d%%" % roundi(sim.city_happiness * 100.0),
			"Anteil %d%%  ·  Bus %d  ·  Bahn %d  ·  Wohnungen mit Anschluss %d%%" % [roundi(sim.transit_share * 100.0),
				int(sim.bus_riders), int(sim.rail_riders), roundi(avg[3] * 100.0)]]
		for m in TrafficOverlay.MODE_NAMES.size():
			var label: String = TrafficOverlay.MODE_NAMES[m] if m > 0 else "Aus"
			var b := _text_button(_popup_col, "%s:  %s" % [label, stats[m]], _pick_view.bind(m), "")
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.toggle_mode = true
			b.set_pressed_no_signal(m == _overlay_mode)
	else:
		var title := _label(_popup_col, 16)
		title.add_theme_font_override("font", UiTheme.font(true))
		title.text = "Zufriedenheit %d%%  (Grundwert %d)" % [roundi(sim.city_happiness * 100.0), roundi(Config.HAPPY_BASE * 100.0)]
		for part: Array in sim.happiness_report():
			var v: float = part[1]
			var pts := roundi(v * 100.0)
			var l := _label(_popup_col, 16, UiTheme.BAD if pts < 0 else (UiTheme.GOOD if pts > 0 else UiTheme.TEXT_DIM))
			l.text = "%s%d  %s%s" % ["+" if pts >= 0 else "", pts, part[0], ("  -> " + part[2]) if part[2] != "" else ""]
		var foot := _label(_popup_col, 16, UiTheme.TEXT_DIM)
		foot.text = "Unter %d%% ziehen Leute weg. Ansicht: V / Zufriedenheit" % roundi(Config.HAPPY_LEAVE * 100.0)
	_popup.reset_size()


func _pick_view(m: int) -> void:
	overlay_selected.emit(m)
	_close_popup()


## Ø Verschmutzung, Bodenwert, Kriminalität über bebaute Wohn-Tiles.
func _city_averages() -> Array:
	var sum := [0.0, 0.0, 0.0]
	var cnt := 0
	var pop := 0.0
	var pop_transit := 0.0
	if sim.land_value.size() == map.size * map.size:
		for i in map.size * map.size:
			if map.zone[i] == Config.Zone.RES and map.level[i] > 0:
				sum[0] += sim.pollution[i]
				sum[1] += sim.land_value[i]
				sum[2] += sim.crime[i]
				cnt += 1
				pop += map.res_capacity(i)
				if sim.has_transit(i):
					pop_transit += map.res_capacity(i)
	return [sum[0] / maxi(cnt, 1), sum[1] / maxi(cnt, 1), sum[2] / maxi(cnt, 1), pop_transit / maxf(pop, 1.0)]


## Tooltip der Zufriedenheit: die drei größten Minuspunkte.
func _happy_tip() -> String:
	var lines := PackedStringArray(["Zufriedenheit - klicken für Details"])
	for part: Array in sim.happiness_report().slice(0, 3):
		if float(part[1]) < -0.005:
			lines.append("%d  %s%s" % [roundi(float(part[1]) * 100.0), part[0], ("  -> " + part[2]) if part[2] != "" else ""])
	return "\n".join(lines)


## Ecke/Kante verankern; Karte wächst bei Inhaltsänderung vom Rand weg.
func _anchor(c: Control, preset: Control.LayoutPreset, gh: Control.GrowDirection, gv: Control.GrowDirection) -> void:
	c.grow_horizontal = gh
	c.grow_vertical = gv
	c.set_anchors_and_offsets_preset(preset, Control.PRESET_MODE_MINSIZE, int(MARGIN))


func _card(parent: Node, radius := 14, pad := 10) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.card(radius, pad))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(p)
	return p


func _row(parent: Node, sep: int) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", sep)
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(r)
	return r


func _label(parent: Node, font_size: int, color := UiTheme.TEXT) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _icon(parent: Node, icon_name: String, px: int, tip := "") -> TextureRect:
	var r := TextureRect.new()
	r.texture = icons.get_icon(icon_name)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = Vector2(px, px)
	r.tooltip_text = tip
	r.mouse_filter = Control.MOUSE_FILTER_PASS if tip != "" else Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


func _icon_button(parent: Node, icon_name: String, tip: String, cb: Callable, px: int) -> Button:
	var b := Button.new()
	b.icon = icons.get_icon(icon_name)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(px, px)
	b.toggle_mode = true
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	b.pressed.connect(cb)
	b.pressed.connect(func(): Audio.sfx("click", 0.05, -4.0))
	parent.add_child(b)
	return b


## Icon links neben Text (expand_icon würde es neben Text auf 0 schrumpfen).
func _set_btn_icon(b: Button, icon_name: String) -> void:
	b.icon = icons.get_icon(icon_name)
	b.add_theme_constant_override("icon_max_width", 28)


func _text_button(parent: Node, text: String, cb: Callable, tip: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(36, 36)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tip
	b.pressed.connect(cb)
	b.pressed.connect(func(): Audio.sfx("click", 0.05, -4.0))
	parent.add_child(b)
	return b


# ---------------------------------------------------------------- Laufzeit

func _process(delta: float) -> void:
	var mp := _cost_pill.get_viewport().get_mouse_position()
	_cost_pill.position = mp + Vector2(20, 14)
	_cost_pill.visible = _cost.text != ""
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast_pill.modulate.a = clampf(_toast_time * 2.0, 0.0, 1.0)
		if _toast_time <= 0.0:
			_toast_pill.visible = false
	# Meldung nicht über eine offene Ausklapp-Liste legen
	var toast_y := 170.0 + MARGIN
	if _popup.visible:
		toast_y = maxf(toast_y, _popup.position.y + _popup.size.y + 10.0)
	_toast_pill.offset_bottom += toast_y - _toast_pill.offset_top
	_toast_pill.offset_top = toast_y
	var n := fire_dept.fires.size()
	_fire_pill.visible = n > 0
	if n > 0:
		var txt := "%d %s  [Tab]" % [n, "Brand" if n == 1 else "Brände"]
		if _fire_btn.text != txt:
			_fire_btn.text = txt
			_fire_pill.reset_size()


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if not k.pressed or k.echo:
		return
	# Geld-Cheat: Strg/Cmd + Shift + G (vor den Werkzeug-Tasten, G = Terrain)
	if k.keycode == KEY_G and k.shift_pressed and (k.ctrl_pressed or k.meta_pressed):
		cheat_money()
		return
	for t in ToolController.TOOLS:
		if ToolController.TOOLS[t]["key"] == k.keycode:
			_select_tool(t)
			return
	match k.keycode:
		KEY_P: _set_speed(0 if sim.speed != 0 else 1)
		KEY_V:
			_toggle_overlay()
		KEY_TAB:
			jump_to_fire()
		KEY_M:
			Audio.toggle_music_mute()
			show_message("Musik aus" if Audio.music_muted else "Musik an")
		KEY_F5: save_requested.emit("quick")
		KEY_F9: load_requested.emit("quick")
		KEY_ESCAPE:
			# Beim Ziehen bricht Esc nur die Aktion ab (ToolController), offene Auswahl zuerst schließen
			if _popup.visible:
				_close_popup()
			elif _flyout.visible:
				_close_flyout()
			elif not tools._dragging:
				toggle_menu()


func cheat_money() -> void:
	sim.money += Config.CHEAT_MONEY
	sim.stats_changed.emit()
	show_message("Cheat: +$%s" % _fmt(int(Config.CHEAT_MONEY)))


func _tool_tip(t: ToolController.Tool) -> String:
	var def: Dictionary = ToolController.TOOLS[t]
	var tip := "%s   [%s]" % [def["name"], OS.get_keycode_string(def["key"])]
	if def.has("cost"):
		tip += "\n$%d" % def["cost"]
	return tip


## Gruppen-Button: wählt das zuletzt genutzte Werkzeug der Gruppe; bei mehreren
## Werkzeugen klappt darüber eine Auswahl auf (nochmal klicken = zuklappen).
func _on_group_pressed(g: int) -> void:
	var entry: Array = TOOLBAR[g]
	var was_open := _flyout.visible and _flyout_group == g
	_close_flyout()
	_select_tool(_group_current[g])
	if entry.size() > 1 and not was_open:
		_open_flyout(g)


func _open_flyout(g: int) -> void:
	for c in _flyout_col.get_children():
		c.queue_free()
	for t: ToolController.Tool in TOOLBAR[g]:
		var lock := tools.locked_reason(t)
		var b := _icon_button(_flyout_col, ToolController.TOOLS[t]["icon"], _tool_tip(t) + ("\n" + lock if lock != "" else ""),
			_on_flyout_pick.bind(g, t), 56)
		b.disabled = lock != ""
		b.modulate.a = 0.45 if lock != "" else 1.0
		b.set_pressed_no_signal(t == tools.tool)
	_flyout_group = g
	_flyout.visible = true
	_flyout.reset_size()
	var btn: Button = _group_buttons[g]
	var r := btn.get_global_rect()
	var size := _flyout.get_combined_minimum_size()
	# Über der Werkzeug-Hinweiszeile, damit sie lesbar bleibt
	var pill: Control = _tool_title.get_parent().get_parent()
	var pill_top := pill.get_global_rect().position.y
	_flyout.position = Vector2(r.get_center().x - size.x * 0.5, minf(r.position.y, pill_top) - size.y - 10)


func _on_flyout_pick(g: int, t: ToolController.Tool) -> void:
	_select_tool(t)
	_close_flyout()


func _close_flyout() -> void:
	_flyout.visible = false
	_flyout_group = -1


func _select_tool(t: ToolController.Tool) -> void:
	tools.set_tool(t)
	var g: int = _tool_group.get(t, -1)
	if g >= 0:
		_group_current[g] = t
		_group_buttons[g].icon = icons.get_icon(ToolController.TOOLS[t]["icon"])
		_group_buttons[g].tooltip_text = _tool_tip(t)
	for key in _group_buttons:
		_group_buttons[key].set_pressed_no_signal(key == g)
	_tool_title.text = ToolController.TOOLS[t]["name"]
	_tool_hint.text = ToolController.TOOLS[t].get("hint", "")
	_tool_hint.visible = _tool_hint.text != ""


func _set_speed(s: int) -> void:
	sim.speed = s
	for k in _speed_buttons.size():
		_speed_buttons[k].set_pressed_no_signal(k == s)


func _change_tax(zn: int, d: float) -> void:
	sim.tax[zn] = clampf(snappedf(float(sim.tax[zn]) + d, 0.01), 0.0, Config.TAX_MAX)
	sim._update_demand()
	_refresh()


## ÖPNV-Tarif durchschalten: kostenlos -> normal -> teuer. Wirkt sofort auf Routen und Zufriedenheit.
func _cycle_fare() -> void:
	sim.fare = (sim.fare + 1) % Config.FARE_NAMES.size()
	sim.refresh()
	show_message("ÖPNV-Tarif: %s" % Config.FARE_NAMES[sim.fare])


## tile >= 0: Meldung hat einen Ort -> länger sichtbar, Klick springt hin.
func show_message(text: String, tile := Vector2i(-1, -1)) -> void:
	_toast.text = text + ("  >" if tile.x >= 0 else "")
	_toast_target = tile
	_toast_pill.visible = true
	_toast_pill.modulate.a = 1.0
	_toast_time = 6.0 if tile.x >= 0 else 3.5
	_toast_pill.tooltip_text = "Klicken: hinspringen" if tile.x >= 0 else ""
	_toast_pill.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if tile.x >= 0 else Control.CURSOR_ARROW


func _on_toast_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _toast_target.x >= 0:
		focus_requested.emit(_toast_target)


## Reihum zu laufenden Bränden springen; ohne Brand zum Ort der letzten Meldung.
func jump_to_fire() -> void:
	var tiles := fire_dept.burning_tiles()
	if tiles.is_empty():
		if _toast_target.x >= 0:
			focus_requested.emit(_toast_target)
		return
	_fire_next = (_fire_next + 1) % tiles.size()
	focus_requested.emit(tiles[_fire_next])


func _refresh() -> void:
	_money.text = "$ %s" % _fmt(int(sim.money))
	_money.add_theme_color_override("font_color", UiTheme.BAD if sim.money < 0 else UiTheme.TEXT)
	var delta := sim.last_income - sim.last_expense
	_money_delta.text = "%s%s / Monat" % ["+" if delta >= 0 else "-", _fmt(absi(int(delta)))]
	_money_delta.add_theme_color_override("font_color", UiTheme.GOOD if delta >= 0 else UiTheme.BAD)
	_date.text = sim.date_string()
	_pop.text = _fmt(sim.population)
	_jobs.text = _fmt(sim.jobs_com + sim.jobs_ind)
	_power.text = "%d / %d MW" % [sim.power_demand, sim.power_supply]
	_power.add_theme_color_override("font_color", UiTheme.BAD if sim.power_demand > sim.power_supply else UiTheme.TEXT)
	_happy_btn.text = "%d%%" % roundi(sim.city_happiness * 100.0) if sim.population > 0 else "-"
	var hc := UiTheme.BAD if sim.city_happiness < 0.4 and sim.population > 0 \
		else (UiTheme.GOOD if sim.city_happiness > 0.65 else UiTheme.TEXT)
	for st: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		_happy_btn.add_theme_color_override(st, hc)
	_happy_btn.tooltip_text = _happy_tip()
	if _popup_kind != "":
		_fill_popup()
	for zn: int in _tax_labels:
		var t := float(sim.tax[zn])
		var lbl: Label = _tax_labels[zn]
		lbl.text = "%d%%" % roundi(t * 100.0)
		lbl.add_theme_color_override("font_color", UiTheme.BAD if t > Config.TAX_NEUTRAL[zn] + 0.025
			else (UiTheme.GOOD if t < Config.TAX_NEUTRAL[zn] - 0.005 else UiTheme.TEXT))
	_fare_btn.text = "ÖPNV: %s" % Config.FARE_NAMES[sim.fare]
	_fare_btn.tooltip_text = "ÖPNV-Tarif (klicken zum Wechseln)\nkostenlos: mehr Fahrgäste, +5 Zufriedenheit mit Anschluss\nnormal: $0,10 je Fahrgast\nteuer: $0,20, weniger Fahrgäste, -3 Zufriedenheit\nFahrgäste: %d/Monat -> $%d" % [
		int(sim.bus_riders + sim.rail_riders), int(sim.income_parts.get("ÖPNV", 0.0))]
	var inc := PackedStringArray(["Einnahmen / Monat:"])
	for k: String in sim.income_parts:
		inc.append("  %s  $%d" % [k, roundi(float(sim.income_parts[k]))])
	inc.append("Ausgaben  $%d" % roundi(sim.last_expense))
	_money_delta.tooltip_text = "\n".join(inc)
	_money_delta.mouse_filter = Control.MOUSE_FILTER_PASS
	_rci.values = [sim.demand_res, sim.demand_com, sim.demand_ind]
	_rci.queue_redraw()
	_on_hover(tools.hover)


func _on_hover(t: Vector2i) -> void:
	if t.x < 0:
		_info_card.visible = false
		return
	_info_card.visible = true
	var i := map.idx(t.x, t.y)
	var lines := PackedStringArray()
	var title := "Gelände"
	if map.is_water(t.x, t.y):
		title = "Wasser"
	elif map.special[i] != Config.Special.NONE:
		var def: Dictionary = Config.SPECIALS[map.special[i]]
		title = def["name"]
		if def.has("service"):
			var a := map.anchor[i]
			var lv := map.special_level(i)
			title = "%s  ·  Stufe %d" % [def["name"], lv]
			lines.append("Reichweite %d Tiles  ·  Kapazität %s %s" % [Config.SERVICE_RADIUS[lv], _fmt(Config.SERVICE_CAPACITY[lv]),
				"Einw. + Jobs" if def["service"] == "fire" else "Einw."])
			var load: float = sim.service_load.get(a, 0.0)
			lines.append("Auslastung %d%%%s" % [roundi(load * 100.0), "  - überlastet!" if load > 1.0 else ""])
			lines.append("Unterhalt $%d/Monat" % int(def["upkeep"] * Config.UPKEEP_LEVEL[lv]))
			if def["service"] == "venue":
				var every: int = def["event_every"]
				var now := float(sim.venue_event.get(a, 0.0)) > 0.0
				lines.append("%d Besucher je %s  ·  %s" % [int(sim.venue_visitors(a)),
					"Vorstellung" if every == 1 else "Spieltag", "heute!" if now else "alle %d Monate" % every])
				lines.append("Straßen rundum: Auslastung %d%%" % roundi(float(sim.venue_jam.get(a, 0.0)) * 100.0))
			if lv < 3:
				lines.append("Ausbau: gleiches Werkzeug, $%d" % (int(def["upgrade"]) * lv))
		else:
			lines.append("Leistung %d MW  ·  Unterhalt $%d/Monat" % [def["power"], int(def["upkeep"])])
	elif map.zone[i] != Config.Zone.NONE:
		title = "%s  ·  Stufe %d" % [Config.ZONE_NAMES[map.zone[i]], map.level[i]]
		if map.villa[i] == 1 and map.level[i] == 3:
			title = "Villa  ·  %d Einw.  ·  Bodenabgabe $%d" % [Config.VILLA_POP, int(Config.VILLA_LEVY)]
		var src := sim._src(i)
		if map.zone[i] == Config.Zone.RES and src >= 0 and sim.tile_commute(i) > 0.0:
			lines.append("Arbeitsweg %d" % roundi(sim.tile_commute(i)))
		var use := sim.tile_power_use(i)
		if use > 0:
			lines.append("Verbrauch %d MW" % use)
		if sim.happiness.size() > i and map.zone[i] == Config.Zone.RES and map.level[i] > 0:
			lines.append("Zufriedenheit %d%%  ·  Kriminalität %d%%" % [roundi(sim.happiness[i] * 100.0), roundi(sim.crime[i] * 100.0)])
			var miss := sim.missing_services(i)
			if not miss.is_empty():
				lines.append("Fehlt: " + ", ".join(miss))
		elif sim.crime.size() > i and map.level[i] > 0:
			lines.append("Kriminalität %d%%" % roundi(sim.crime[i] * 100.0))
		if map.level[i] > 0 and sim.population >= Config.FIRE_GRACE_POP and sim.coverage.has("fire"):
			var cov := minf((sim.coverage["fire"] as PackedFloat32Array)[i], 1.0)
			var note := fire_dept.protection_note(i)
			lines.append("Brandschutz %d%%%s" % [roundi(cov * 100.0), ("  - " + note) if note != "" else ""])
		if map.burning[i] > 0:
			lines.append("BRAND %d%%  ·  %s" % [map.burning[i], fire_dept.status_text(i)])
		if sim.land_mix.size() > i:
			match map.zone[i]:
				Config.Zone.RES:
					var mix := sim.land_mix[i]
					if mix > 0.0:
						lines.append("Nahversorgung: Läden in %d Tiles (+%d%% Bodenwert)" % [Config.RES_SHOP_RANGE, roundi(mix * 100)])
					elif mix < 0.0:
						lines.append("Eintönig: kein Laden/Park/Wasser in %d Tiles (%d%%)" % [Config.RES_DULL_RANGE, roundi(mix * 100)])
					if sim.villa_site(i) and map.villa[i] == 0:
						lines.append("Villenlage: Stufe 3 wird eine Villa (Bodenwert >= %d%%, Kleinsiedlung)" % roundi(Config.VILLA_LAND * 100))
				Config.Zone.COM:
					lines.append("Ladenzeile: %d. Reihe, %d Tiles zur Kreuzung -> max. Stufe %d" % [
						sim.road_dist[i], sim.corner_dist(i), sim._max_level(i)])
				Config.Zone.IND:
					lines.append("Ballung: %d Industrie-Tiles ringsum -> Wachstum x%.1f, max. Stufe %d" % [
						int(sim.ind_cluster[i]), sim._cluster_factor(i), sim._max_level(i)])
		var blockers := sim.growth_blockers(i)
		if blockers.is_empty():
			lines.append("+ Kann wachsen" if map.level[i] < 3 else "Voll ausgebaut")
		else:
			for b in blockers:
				lines.append("x " + b)
	elif map.transit[i] == Config.Transit.STATION:
		title = "Bahnhof"
		var use := float(sim.station_use.get(i, 0.0))
		lines.append("%d Ein-/Aussteiger/Monat  ·  Kapazität %d (%d%%)%s" % [int(use), int(Config.STATION_CAPACITY),
			roundi(use / Config.STATION_CAPACITY * 100.0), "  - überfüllt!" if use > Config.STATION_CAPACITY else ""])
		lines.append("Bahn gesamt: %d Fahrgäste" % int(sim.rail_riders))
	elif map.road[i] != 0:
		var wide := map.wide_partner(t.x, t.y) != Vector2i.ZERO
		title = "Hauptstraße (4 Spuren)" if wide else "Straße"
		if map.rail[i] != 0:
			title = "Bahnübergang"
		if map.transit[i] == Config.Transit.BUS_STOP:
			title = "Bushaltestelle"
			lines.append("Bus gesamt: %d Fahrgäste/Monat" % int(sim.bus_riders))
		if sim.traffic.size() > i:
			lines.append("%d Pendler/Monat" % int(sim.traffic[i]))
			lines.append("Auslastung %d%%" % roundi(sim.congestion[i] * 100.0))
	elif map.rail[i] != 0:
		title = "Gleis"
		if sim.rail_traffic.size() > i:
			lines.append("%d Fahrgäste/Monat" % int(sim.rail_traffic[i]))
	elif map.feature[i] == Config.Feature.PARK:
		title = "Park"
	elif map.feature[i] == Config.Feature.TREE:
		title = "Wald"
	if map.power_line[i] == 1:
		lines.append("Stromleitung")
	if sim.land_value.size() > i and not map.is_water(t.x, t.y):
		var gf := sim.green_filter[i] if sim.green_filter.size() > i else 0.0
		lines.append("Bodenwert %d%%  ·  Verschmutzung %.1f%s" % [roundi(sim.land_value[i] * 100.0), sim.pollution[i],
			("  (Grün filtert %d%%)" % roundi(gf * 100.0)) if gf > 0.0 else ""])
		if map.zone[i] == Config.Zone.COM:
			lines.append("Kundschaft im Umkreis: %d" % int(sim.customers[i]))
	lines.append("Tile %d, %d  ·  Höhe %d" % [t.x, t.y, map.height[i]])
	_info_title.text = title
	_info_body.text = "\n".join(lines)


func _on_cost(cost: int, valid: bool) -> void:
	_cost.text = ("$ %s" % _fmt(cost)) if cost > 0 else ""
	_cost.add_theme_color_override("font_color", UiTheme.TEXT if valid else UiTheme.BAD)


func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
