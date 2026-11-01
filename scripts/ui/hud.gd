class_name Hud
extends CanvasLayer
## Schwebende HUD-Karten: Finanzen, Stadtwerte, RCI/Steuer/Tempo, Werkzeugleiste, Infos.

signal save_requested(slot: String)
signal load_requested(slot: String)
signal new_city_requested
signal quit_requested(save_slot: String)   # "" = ohne Speichern
signal overlay_selected(mode: int)   # MapOverlay.Mode
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
	[ToolController.Tool.POWERLINE, ToolController.Tool.COAL, ToolController.Tool.WIND, ToolController.Tool.BIOMASS,
		ToolController.Tool.SOLAR, ToolController.Tool.BATTERY, ToolController.Tool.HYDRO, ToolController.Tool.PUMPED,
		ToolController.Tool.SALT],
	[],
	[ToolController.Tool.RES],
	[ToolController.Tool.COM],
	[ToolController.Tool.IND, ToolController.Tool.HIGHTECH],
	[],
	[ToolController.Tool.TREE, ToolController.Tool.PARK],
	[ToolController.Tool.RAISE, ToolController.Tool.LOWER],
	[],
	[ToolController.Tool.POLICE, ToolController.Tool.FIRE, ToolController.Tool.SCHOOL, ToolController.Tool.HOSPITAL],
	[ToolController.Tool.LIBRARY, ToolController.Tool.CINEMA, ToolController.Tool.TOWNHALL,
		ToolController.Tool.THEATER, ToolController.Tool.STADIUM],
	[ToolController.Tool.UNIVERSITY, ToolController.Tool.INSTITUTE],
	[ToolController.Tool.MINE, ToolController.Tool.QUARRY, ToolController.Tool.PIT, ToolController.Tool.LUMBER,
		ToolController.Tool.WAREHOUSE, ToolController.Tool.NURSERY, ToolController.Tool.PROSPECTOR,
		ToolController.Tool.RECYCLER],
	[ToolController.Tool.STEELWORKS, ToolController.Tool.SAWMILL, ToolController.Tool.BRICKWORKS,
		ToolController.Tool.GLASSWORKS, ToolController.Tool.CONCRETE],
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
var _popup_kind := ""
var _research_btn: Button
var _num_re := RegEx.create_from_string("[-+$]?\\d")    # erste Zahl in einer Info-Zeile
var _fit_pending := false
var _fit_frame := -1
var _fit_count := 0
var _power_dark := 0                  # Gebäude ohne Strom (letzte Berechnung)
var _power_night_shown := false       # Stromanzeige zeigt gerade die Nachtbilanz
var _quit_card: PanelContainer        # Abfrage "Spiel beenden?"
var _quit_speed := 1
var _current_slot_hint := ""          # vom Spiel: zuletzt benutzter Speicherplatz
var _research_open := {}
var _hall_btn: Button
var mayor: Mayor                     # Bürgermeister-Figur (verkündet Meldungen, Klick = Berater)
var _mayor_btn: Button
var _bubble: PanelContainer
var _bubble_label: Label              # Forschungsfenster: Bereich -> aufgeklappt
var _popup_btn: Button               # Knopf, unter dem das offene Popover hängt
var _popup_scroll: ScrollContainer   # Popover scrollt, wenn es höher als der Bildschirm wäre
var _breakthrough: PanelContainer     # Durchbruch-Karte (Forschung fertig)              # "view" / "happy" / "" = zu
var _trade_card: PanelContainer                 # Zukauf-Nachfrage des Bürgermeisters
var _hint_open := {}                            # aufgedeckte „Genauer?“-Tipps (Titel)
var _goal_last := ""                            # zuletzt angesagter Ziel-Hinweis
var _goal_month := -1
var _goal_wait := 0
var _menu: PanelContainer
var _slot_labels := {}
var _root: Control
var _scale_buttons: Array[Button] = []
var _fs_btn: Button
var _stock_card: PanelContainer
var _stock_labels := {}
var _confirm_row: HBoxContainer
var _confirm_label: Label
var _confirm_slot := ""
var _backup_col: VBoxContainer
var _speed_before_menu := 1
var _tax_labels := {}           # Zone -> Label
var _fare_btn: Button
var _tool_title: Label
var _tool_hint: Label
var _info_card: PanelContainer
var _info_col: VBoxContainer
var _info_sig := ""                 # Inhalt der aktuellen Info-Karte (Neuaufbau nur bei Änderung)
var info_text := ""                 # Klartext der Karte (Tests)
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
var _fps_buttons: Array[Button] = []
var _speed_buttons: Array[Button] = []
var _toast_time := 0.0
var _toast_target := Vector2i(-1, -1)  # Ort der Meldung (Klick/Tab springt hin)
var _right: VBoxContainer          # Spalte oben rechts: Steuer/Tempo, Brand-Anzeige, Warnungen
var _feed: VBoxContainer           # aktuelle Warnungen (max. FEED_MAX Streifen)
var _bell_btn: Button
var _log: Array = []               # Verlauf: {text, tile, date, count}
var _unread := 0
var _hud_parts: Array[Control] = []  # was H ausblendet
var _info_detail := false          # Info-Karte ausführlich (Taste I)
var _info_sections: Array = []     # [Abschnitt, Zeilen] der aktuellen Karte
const FEED_MAX := 2
const FEED_TIME := 7.0
const LOG_MAX := 20
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
	# Warnungen (mit Verlauf + Ton) vs. Infos (kurz, klein, ohne Verlauf)
	sim.message.connect(notify)
	sim.research_finished.connect(_on_research_finished)
	sim.trade_request.connect(_on_trade_request)
	sim.alert.connect(notify)
	fire_dept.alert.connect(notify)
	tools.message.connect(show_message)
	tools.hover_changed.connect(_on_hover)
	tools.preview_cost_changed.connect(_on_cost)
	_refresh()


# ---------------------------------------------------------------- Aufbau

func _build() -> void:
	var root := Control.new()
	_root = root
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
	_bell_btn = _text_button(tl_row, "", _toggle_popup.bind("log"), "Meldungen: Verlauf der letzten Warnungen (klicken)")
	_set_btn_icon(_bell_btn, "bell")
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
	_research_btn = _text_button(tc_row, "", _toggle_popup.bind("research"),
		"Forschung: Projekte, Budget, Fortschritt")
	_set_btn_icon(_research_btn, "institute")
	_hall_btn = _text_button(tc_row, "", _toggle_popup.bind("hall"), "Rathaus: Stufe, Ausbau, Freischaltungen")
	_set_btn_icon(_hall_btn, "cityhall")
	_mayor_btn = _text_button(tc_row, "", _toggle_popup.bind("mayor"), "Bürgermeister: was die Stadt gerade braucht")
	_set_btn_icon(_mayor_btn, "people")

	# Lager: je Rohstoff Icon + Menge (erst sichtbar, sobald es Abbau oder Vorrat gibt)
	_stock_card = _card(left)
	_stock_card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var st_col := VBoxContainer.new()
	st_col.add_theme_constant_override("separation", 2)
	_stock_card.add_child(st_col)
	var raw_row := _row(st_col, 8)
	var good_row := _row(st_col, 8)
	raw_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	good_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	for r: String in Config.RESOURCES:
		var st_row := good_row if Config.RESOURCES[r].get("good", false) else raw_row     # Rohstoffe / Baustoffe
		_icon(st_row, "res_" + r, 22, Config.RESOURCES[r]["name"])
		var l := _label(st_row, 16)
		l.add_theme_font_override("font", UiTheme.font(true))
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		_stock_labels[r] = l
	_stock_card.visible = false

	# Oben rechts: RCI, Steuer, Tempo
	_right = VBoxContainer.new()
	_right.add_theme_constant_override("separation", 8)
	_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_right)
	var tr := _card(_right)
	tr.size_flags_horizontal = Control.SIZE_SHRINK_END
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
	_popup_scroll = ScrollContainer.new()
	_popup_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Platz der Bildlaufleiste immer reservieren: sonst ändert ihr Ein-/Ausblenden die Breite -> Text bricht neu um
	# -> Höhe ändert sich -> Leiste verschwindet ... (Schaukeln bis zum Absturz "Message queue out of memory")
	_popup_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_RESERVE
	_popup.add_child(_popup_scroll)
	_popup_col = VBoxContainer.new()
	_popup_col.add_theme_constant_override("separation", 6)
	_popup_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_popup_scroll.add_child(_popup_col)
	_popup_col.minimum_size_changed.connect(_on_popup_content_changed)

	_flyout = _card(root, 10, 6)
	_flyout.visible = false
	_flyout_col = VBoxContainer.new()
	_flyout_col.add_theme_constant_override("separation", 4)
	_flyout.add_child(_flyout_col)

	# Unten links: Tile-Info
	_info_card = _card(left)
	_info_card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_info_col = VBoxContainer.new()
	_info_col.add_theme_constant_override("separation", 5)
	_info_col.custom_minimum_size.x = 380
	_info_card.add_child(_info_col)

	# Kosten am Cursor
	_cost_pill = _card(root, 8, 3)
	_cost = _label(_cost_pill, 16)

	# Infos (kurz, klein) über der Werkzeugleiste
	_toast_pill = _card(bottom, 10, 4)
	_toast_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_toast = _label(_toast_pill, 14, UiTheme.TEXT_DIM)
	_toast_pill.visible = false
	bottom.move_child(_toast_pill, 0)

	# Laufende Brände (rechts, unter Steuer/Tempo): Klick/Tab springt reihum hin
	_fire_pill = _card(_right, 10, 4)
	_fire_pill.size_flags_horizontal = Control.SIZE_SHRINK_END
	_fire_pill.add_theme_stylebox_override("panel", UiTheme.card(10, 4, UiTheme.TOAST))
	_fire_btn = _text_button(_fire_pill, "", jump_to_fire, "Zum nächsten Brand springen [Tab]")
	_set_btn_icon(_fire_btn, "fire")
	_fire_btn.add_theme_color_override("font_color", UiTheme.BAD)
	_fire_pill.visible = false
	# Warnungen: schmale Streifen rechts, Klick springt hin
	_feed = VBoxContainer.new()
	_feed.add_theme_constant_override("separation", 6)
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feed.size_flags_horizontal = Control.SIZE_SHRINK_END
	_right.add_child(_feed)

	_anchor(left, Control.PRESET_TOP_LEFT, Control.GROW_DIRECTION_END, Control.GROW_DIRECTION_END)
	_anchor(_right, Control.PRESET_TOP_RIGHT, Control.GROW_DIRECTION_BEGIN, Control.GROW_DIRECTION_END)
	_anchor(bottom, Control.PRESET_CENTER_BOTTOM, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BEGIN)
	_hud_parts = [left, _right]

	_build_menu(root)
	get_viewport().size_changed.connect(_apply_ui_scale)
	_apply_ui_scale()

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
		_text_button(row, "Speichern", _ask_save.bind(slot), "").custom_minimum_size.x = 120
		_text_button(row, "Laden", func(): load_requested.emit(slot); toggle_menu(), "").custom_minimum_size.x = 90
	# Bestätigung vor dem Überschreiben (ersetzt kurz die Slot-Liste nicht, steht darunter)
	_confirm_row = _row(col, 8)
	_confirm_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_confirm_label = _label(_confirm_row, 16, UiTheme.BAD)
	_confirm_label.custom_minimum_size.x = 540
	_confirm_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_button(_confirm_row, "Überschreiben", _confirm_save, "Alte Version wird als Sicherung behalten").custom_minimum_size.x = 160
	_text_button(_confirm_row, "Abbrechen", func(): _confirm_row.visible = false, "").custom_minimum_size.x = 120
	_confirm_row.visible = false
	# Sicherungen (ältere Versionen, automatisch vor jedem Überschreiben)
	var bk_title := _label(col, 16, UiTheme.TEXT_DIM)
	bk_title.text = "Sicherungen (vor jedem Überschreiben, je Platz die letzten %d):" % SaveManager.BACKUPS
	_backup_col = VBoxContainer.new()
	_backup_col.add_theme_constant_override("separation", 4)
	col.add_child(_backup_col)
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
	_fs_btn = _text_button(gfx_row, "Vollbild", toggle_fullscreen, "Vollbild an/aus [F11]")
	_fs_btn.toggle_mode = true
	_fs_btn.custom_minimum_size.x = 130
	_fs_btn.set_pressed_no_signal(GraphicsSettings.fullscreen)
	var vs := _text_button(gfx_row, "VSync", func(): _toggle_vsync(), "Bildsynchronisation (verhindert Tearing)")
	vs.toggle_mode = true
	vs.custom_minimum_size.x = 100
	vs.set_pressed_no_signal(GraphicsSettings.vsync)
	var dn := _text_button(gfx_row, "Tag/Nacht", func():
		GraphicsSettings.day_night = not GraphicsSettings.day_night
		GraphicsSettings.save(), "Sichtbarer Tag/Nacht-Zyklus (aus = immer Mittag). Strom rechnet Tag/Nacht trotzdem.")
	dn.toggle_mode = true
	dn.custom_minimum_size.x = 130
	dn.set_pressed_no_signal(GraphicsSettings.day_night)
	var fps_row := _row(col, 8)
	fps_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	var fps_label := _label(fps_row, 16)
	fps_label.text = "Bilder/s"
	fps_label.custom_minimum_size.x = 160
	_fps_buttons.clear()
	for v: int in GraphicsSettings.FPS_OPTIONS:
		var b := _text_button(fps_row, str(v) if v > 0 else "Unbegrenzt", _set_fps.bind(v),
			"Weniger Bilder pro Sekunde = weniger Stromverbrauch. 60 reicht für flüssiges Spiel.")
		b.toggle_mode = true
		b.custom_minimum_size.x = 110 if v > 0 else 150
		b.set_pressed_no_signal(v == GraphicsSettings.fps_limit)
		_fps_buttons.append(b)
	var sc_row := _row(col, 8)
	sc_row.alignment = BoxContainer.ALIGNMENT_BEGIN
	var sc_label := _label(sc_row, 16)
	sc_label.text = "Oberfläche"
	sc_label.custom_minimum_size.x = 160
	_scale_buttons.clear()
	for v: float in GraphicsSettings.UI_SCALES:
		var b := _text_button(sc_row, "%d%%" % roundi(v * 100.0), _set_ui_scale.bind(v), "Größe aller HUD-Elemente")
		b.toggle_mode = true
		b.custom_minimum_size.x = 110
		b.set_pressed_no_signal(is_equal_approx(v, GraphicsSettings.ui_scale))
		_scale_buttons.append(b)
	var fps_hint := _label(fps_row, 14, UiTheme.TEXT_DIM)
	fps_hint.text = "Hintergrund 10 · Pause 30"
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
	_text_button(bottom, "Neue Stadt", func(): new_city_requested.emit(); toggle_menu(),
		"Rathaus + Lager, erst Material sammeln, Freischaltungen über Rathaus-Stufen").custom_minimum_size.x = 230
	_text_button(bottom, "Weiter", toggle_menu, "").custom_minimum_size.x = 120
	_text_button(bottom, "Beenden", func(): ask_quit(_current_slot_hint), "Spiel beenden (fragt nach dem Speichern)").custom_minimum_size.x = 130
	_text_button(bottom, "Spielstand-Ordner öffnen", UserData.open_saves_folder,
		ProjectSettings.globalize_path("user://saves")).custom_minimum_size.x = 300
	var hint := _label(col, 16, UiTheme.TEXT_DIM)
	hint.text = "F5 Schnellspeichern  ·  F9 Schnellladen  ·  M Ton an/aus"
	_anchor(_menu, Control.PRESET_CENTER, Control.GROW_DIRECTION_BOTH, Control.GROW_DIRECTION_BOTH)
	_menu.visible = false


func _set_graphics(p: int) -> void:
	GraphicsSettings.current = p as GraphicsSettings.Preset
	GraphicsSettings.save()
	for k in _gfx_buttons.size():
		_gfx_buttons[k].set_pressed_no_signal(k == p)
	graphics_changed.emit()


func toggle_fullscreen() -> void:
	GraphicsSettings.fullscreen = DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN
	GraphicsSettings.save()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if GraphicsSettings.fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED)
	_fs_btn.set_pressed_no_signal(GraphicsSettings.fullscreen)


func _set_ui_scale(v: float) -> void:
	GraphicsSettings.ui_scale = v
	GraphicsSettings.save()
	for k in _scale_buttons.size():
		_scale_buttons[k].set_pressed_no_signal(is_equal_approx(GraphicsSettings.UI_SCALES[k], v))
	_apply_ui_scale()


## HUD skalieren: CanvasLayer verkleinern, Wurzel-Control auf Fenstergröße / Faktor ziehen (Anker bleiben richtig).
func _apply_ui_scale() -> void:
	var f := GraphicsSettings.ui_scale
	scale = Vector2(f, f)
	_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_root.position = Vector2.ZERO
	_root.size = _ui_size()
	if _popup != null:
		_close_popup()


func _ui_size() -> Vector2:
	return get_viewport().get_visible_rect().size / GraphicsSettings.ui_scale


func _set_fps(v: int) -> void:
	GraphicsSettings.fps_limit = v
	GraphicsSettings.save()
	for k in _fps_buttons.size():
		_fps_buttons[k].set_pressed_no_signal(GraphicsSettings.FPS_OPTIONS[k] == v)


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


static func slot_name(slot: String) -> String:
	if SLOT_NAMES.has(slot):
		return SLOT_NAMES[slot]
	var p := slot.split(".bak")
	return "%s, Sicherung %s" % [SLOT_NAMES.get(p[0], p[0]), p[1] if p.size() > 1 else "?"]


## Abfrage beim Beenden (Menü-Knopf, Fenster schließen, Cmd+Q): Speichern und beenden / ohne Speichern / abbrechen.
func ask_quit(slot: String) -> void:
	_current_slot_hint = slot
	if _quit_card != null:
		return
	_quit_speed = sim.speed
	_set_speed(0)
	var target := slot if slot != "" else "quick"
	_quit_card = _card(_root, 16, 18)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	_quit_card.add_child(col)
	PopUI.label(col, "Spiel beenden?", 22, UiTheme.TEXT, true)
	PopUI.label(col, "Nicht gespeicherte Fortschritte gehen sonst verloren.", 16, UiTheme.TEXT_DIM)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	var sb := _text_button(row, "Speichern (%s) und beenden" % slot_name(target), func() -> void:
		quit_requested.emit(target), "Alte Version des Platzes wird als Sicherung behalten")
	sb.custom_minimum_size.x = 340
	_text_button(row, "Ohne Speichern beenden", func() -> void: quit_requested.emit(""), "").custom_minimum_size.x = 280
	_text_button(row, "Abbrechen", _close_quit, "").custom_minimum_size.x = 140
	_quit_card.modulate.a = 0.0
	await RenderingServer.frame_pre_draw
	if is_instance_valid(_quit_card):
		_quit_card.reset_size()
		_quit_card.position = (_ui_size() - _quit_card.size) * 0.5
		_quit_card.modulate.a = 1.0


func _close_quit() -> void:
	if _quit_card != null:
		_quit_card.queue_free()
		_quit_card = null
	_set_speed(_quit_speed if _quit_speed > 0 else 1)


## Speichern im Menü: belegter Platz -> erst nachfragen.
func _ask_save(slot: String) -> void:
	var m := SaveManager.meta(slot)
	if m.is_empty():
		save_requested.emit(slot)
		_refresh_slots()
		return
	_confirm_slot = slot
	_confirm_label.text = "%s überschreiben?  %s  ·  %s Einw.  ·  $%s" % [SLOT_NAMES[slot], m.get("date", "?"),
		_fmt(m.get("population", 0)), _fmt(m.get("money", 0))]
	_confirm_row.visible = true


func _confirm_save() -> void:
	_confirm_row.visible = false
	save_requested.emit(_confirm_slot)
	_refresh_slots()


func _refresh_slots() -> void:
	_confirm_row.visible = false
	for c in _backup_col.get_children():
		_backup_col.remove_child(c)
		c.queue_free()
	var list := SaveManager.backups()
	if list.is_empty():
		var l := _label(_backup_col, 14, UiTheme.TEXT_DIM)
		l.text = "  noch keine"
	for b: Dictionary in list:
		var m: Dictionary = b["meta"]
		var row := _row(_backup_col, 8)
		row.alignment = BoxContainer.ALIGNMENT_BEGIN
		var l := _label(row, 14)
		l.custom_minimum_size.x = 540
		l.text = "  %s:  %s  ·  %s Einw.  ·  gesichert %s" % [slot_name(b["slot"]), m.get("date", "?"),
			_fmt(m.get("population", 0)), str(m.get("saved_at", "?")).replace("T", " ").left(16)]
		var slot: String = b["slot"]
		_text_button(row, "Laden", func(): load_requested.emit(slot); toggle_menu(), "").custom_minimum_size.x = 90
	for slot: String in _slot_labels:
		var m := SaveManager.meta(slot)
		var text: String = SLOT_NAMES[slot] + ":  "
		if m.is_empty():
			text += "leer"
		else:
			text += "%s  ·  %s Einw.  ·  $%s" % [m.get("date", "?"), _fmt(m.get("population", 0)), _fmt(m.get("money", 0))]
		_slot_labels[slot].text = text


func _toggle_overlay() -> void:
	overlay_selected.emit((_overlay_mode + 1) % MapOverlay.MODE_NAMES.size())


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
	var btn: Button = {"view": _view_btn, "happy": _happy_btn, "log": _bell_btn, "research": _research_btn,
		"hall": _hall_btn, "mayor": _mayor_btn}[kind]
	if kind == "log":
		_unread = 0
		_update_bell()
	if _popup_kind == kind:
		_close_popup()
		return
	_popup_kind = kind
	_fill_popup()
	_popup.visible = true
	_popup_btn = btn
	_place_popup()
	_fit_popup()
	_place_popup()
	btn.set_pressed_no_signal(true)


## Forschungsfenster: kompakter Kopf (Labor, Budget), darunter Bereiche zum Aufklappen; je Bereich die Projekte in
## Abhängigkeitsreihenfolge (eingerückt = baut auf dem darüber auf), je Projekt eine Zeile; Beschreibung/Start nur bei
## verfügbaren oder laufenden Projekten. (Nutzer: vorher zu lang und überladen.)
func _fill_research() -> void:
	var inst := sim.institute_levels()
	PopUI.header(_popup_col, icons.get_icon("institute"), "Forschung",
		("%d P/Monat" % roundi(sim.research_points())) if inst > 0 else "", UiTheme.GOOD,
		"Ein Projekt gleichzeitig - Projekte bauen aufeinander auf")
	if inst == 0:
		var req := PopUI.section(_popup_col, "Voraussetzungen")
		var uni_def: Dictionary = Config.SPECIALS[Config.Special.UNIVERSITY]
		var need_pop: int = uni_def["unlock"]
		var need_cov: float = uni_def["need_coverage"][1]
		var cov := float(sim.city_coverage.get("education", 0.0))
		var check := func(ok: bool) -> Color: return UiTheme.GOOD if ok else UiTheme.BAD
		PopUI.row(req, "Einwohner (mind. %s)" % _fmt(need_pop), _fmt(sim.population), check.call(sim.population >= need_pop))
		PopUI.row(req, "Schulversorgung (mind. %d %%)" % roundi(need_cov * 100.0), "%d %%" % roundi(cov * 100.0),
			check.call(cov >= need_cov))
		var has_uni := not tools.locked_reason(ToolController.Tool.INSTITUTE).begins_with("Erst eine")
		PopUI.row(req, "Universität gebaut", "ja" if has_uni else "nein", check.call(has_uni))
		PopUI.row(req, "Forschungsinstitut mit Strom", "nein", UiTheme.BAD)
	else:
		var need := float(Config.ACADEMICS_PER_LEVEL * inst)
		var acad := sim.academics_count()
		PopUI.row(_popup_col, "Institute %d  ·  Akademiker %s / %s" % [inst, _fmt(int(acad)), _fmt(int(need))],
			"%d %% Leistung" % roundi(sim.academic_factor() * 100.0), UiTheme.GOOD if acad >= need else UiTheme.WARN)
	# Budget in einer Zeile
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 8)
	_popup_col.add_child(brow)
	var bt := PopUI.label(brow, "Budget", 16, UiTheme.TEXT_DIM)
	bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bt.tooltip_text = "Wird nur ausgegeben, solange ein Projekt läuft. Beim Start: Startpreis + Gold (fehlt es: Zukauf)."
	bt.mouse_filter = Control.MOUSE_FILTER_PASS
	_text_button(brow, "-", _research_budget.bind(-1), "Budget senken")
	var bl := PopUI.label(brow, "$%s / Monat" % _fmt(int(sim.research_budget)), 16, UiTheme.TEXT, true)
	bl.custom_minimum_size.x = 150
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_button(brow, "+", _research_budget.bind(1), "Budget erhöhen (mehr Geld = schneller, abnehmender Ertrag)")
	PopUI.label(brow, "Tempo x%.2f" % Simulation.budget_factor(sim.research_budget), 14, UiTheme.TEXT_DIM)
	# Bereiche
	var groups: Array[String] = []
	for id: String in Config.RESEARCH:
		var g: String = Config.RESEARCH[id].get("group", "Sonstiges")
		if not groups.has(g):
			groups.append(g)
	for g in groups:
		var ids := _research_ordered(g)
		var done := 0
		var running := false
		var ready := false
		for id in ids:
			var why := sim.research_blocker(id)
			done += 1 if why == "erforscht" else 0
			running = running or why == "läuft"
			ready = ready or why == ""
		if not _research_open.has(g):
			_research_open[g] = running or ready
		var open: bool = _research_open[g]
		var state := "%d/%d erforscht" % [done, ids.size()]
		if running:
			state += "  ·  1 läuft"
		elif ready:
			state += "  ·  bereit"
		PopUI.list_item(_popup_col, ("-  " if open else "+  ") + g, state, "", running, _toggle_research_group.bind(g))
		if not open:
			continue
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 6)
		_popup_col.add_child(list)
		for id in ids:
			_research_row(list, id)


## Projekte eines Bereichs in Abhängigkeitsreihenfolge (Vorgänger zuerst).
func _research_ordered(g: String) -> Array[String]:
	var out: Array[String] = []
	var left: Array[String] = []
	for id: String in Config.RESEARCH:
		if str(Config.RESEARCH[id].get("group", "Sonstiges")) == g:
			left.append(id)
	while not left.is_empty():
		var progress := false
		for id in left.duplicate():
			var ok := true
			for r: String in Config.RESEARCH[id]["requires"]:
				if left.has(r):
					ok = false
			if ok:
				out.append(id)
				left.erase(id)
				progress = true
		if not progress:
			out.append_array(left)
			break
	return out


## Projektkarte: Name + Plakette, Beschreibung, Kosten/Dauer, Starten bzw. Fortschritt. Gesperrte Karten ausgegraut mit
## Voraussetzung, erforschte kompakt. Reihenfolge = Abhängigkeit (Vorgänger zuerst), ohne Einrückung (Nutzerwunsch).
func _research_row(list: VBoxContainer, id: String) -> void:
	var def: Dictionary = Config.RESEARCH[id]
	var why := sim.research_blocker(id)
	var done := why == "erforscht"
	var running := why == "läuft"
	var ready := why == ""
	var card := PopUI.box(list, UiTheme.GOOD if done else (UiTheme.COM if running else (UiTheme.BTN_ON_EDGE if ready else UiTheme.BTN_EDGE)),
		Color("eef7e6") if done else Color("fffaf0"))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	card.add_child(top)
	var nm := PopUI.label(top, def["name"], 17, UiTheme.TEXT, true)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if done:
		PopUI.chip(top, "ERFORSCHT", UiTheme.GOOD)
		nm.tooltip_text = str(def["desc"])
		nm.mouse_filter = Control.MOUSE_FILTER_PASS
		return
	if running:
		PopUI.chip(top, "LÄUFT", UiTheme.COM)
	elif ready:
		PopUI.chip(top, "BEREIT", UiTheme.WARN)
	else:
		PopUI.chip(top, "GESPERRT", UiTheme.TEXT_DIM)
	PopUI.note(card, str(def["desc"]), UiTheme.TEXT)
	var eta := sim.research_eta(id, sim.research_budget)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	card.add_child(bottom)
	var info := PopUI.label(bottom, "Start $%s  ·  %s Punkte  ·  %d Gold%s" % [_fmt(int(Simulation.research_start_cost(id))),
		_fmt(int(def["points"])), int(def["gold"]),
		("  ·  ~%d Monate" % eta) if eta > 0 else ""], 14, UiTheme.TEXT_DIM)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if running:
		var frac := sim.research_progress / float(def["points"])
		PopUI.label(bottom, "%d %%" % roundi(frac * 100.0), 14, UiTheme.COM, true)
		PopUI.bar(card, frac, UiTheme.COM)
	elif ready:
		_text_button(bottom, "Projekt starten", _start_research.bind(id), "")
	else:
		var need := why
		if why.begins_with("braucht: "):
			need = "Voraussetzung: %s erforschen" % why.trim_prefix("braucht: ")
		elif why.begins_with("kein"):
			need = "Voraussetzung: Forschungsinstitut mit Strom"
		PopUI.note(card, need, UiTheme.BAD)
		card.get_parent().modulate = Color(1, 1, 1, 0.55)       # ausgegraut


func _toggle_research_group(g: String) -> void:
	_research_open[g] = not bool(_research_open.get(g, false))
	_fill_popup()


## Sprechblase des Bürgermeisters über seinem Kopf (3D-Position aufs HUD projiziert).
func _update_bubble() -> void:
	if _bubble == null:
		_bubble = _card(_root, 10, 8)
		_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_bubble_label = PopUI.label(_bubble, "", 15, UiTheme.TEXT, false, true)
		_bubble_label.custom_minimum_size.x = 260
		_bubble.visible = false
	var cam := get_viewport().get_camera_3d()
	if mayor == null or mayor.text == "" or cam == null or cam.is_position_behind(mayor.head()) or _hud_hidden() \
			or _popup.visible:      # Popover (z. B. Berater) nicht überdecken
		_bubble.visible = false
		return
	if _bubble_label.text != mayor.text:
		_bubble_label.text = mayor.text
		_bubble.reset_size()
	var p := cam.unproject_position(mayor.head()) / scale
	_bubble.position = p - Vector2(_bubble.size.x * 0.5, _bubble.size.y + 8.0)
	_bubble.visible = Rect2(Vector2.ZERO, _ui_size()).has_point(p)


## Klick auf die Figur öffnet den Berater (Bildschirm-Rechteck von Füßen bis Kopf).
func _input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT or mayor == null:
		return
	if DevTools.automated and not event.has_meta("synthetic"):
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam.is_position_behind(mayor.global_position):
		return
	var feet := cam.unproject_position(mayor.global_position)
	var top := cam.unproject_position(mayor.head())
	var r := Rect2(Vector2(minf(feet.x, top.x) - 18.0, top.y), Vector2(absf(feet.x - top.x) + 36.0, maxf(feet.y - top.y, 20.0)))
	if r.has_point(mb.position):
		_toggle_popup("mayor")
		get_viewport().set_input_as_handled()


## Berater: wichtigste Baustellen der Stadt (mit Tipp + Hinspringen), im Aufbau-Start zusätzlich die Aufgabenliste.
func _fill_mayor() -> void:
	PopUI.header(_popup_col, icons.get_icon("people"), "Bürgermeister", "", UiTheme.TEXT,
		"Frag mich jederzeit - ich gebe Hinweise, die Lösung findest du selbst")
	var goal := PopUI.section(_popup_col, "Nächstes Ziel")
	for g: Array in mayor_goals():
		_hint_item(goal, str(g[0]), str(g[1]), str(g[2]), UiTheme.TEXT, Vector2i(-1, -1))
	var items := _mayor_problems()
	var sec := PopUI.section(_popup_col, "Probleme")
	if items.is_empty():
		PopUI.note(sec, "Alles im Griff - weiter so!", UiTheme.GOOD)
	for it: Array in items.slice(0, 4):
		_hint_item(sec, str(it[0]), str(it[1]), str(it[2]), UiTheme.BAD, it[3])
	var stuck := _mayor_stuck()
	if not stuck.is_empty():
		var hk := PopUI.section(_popup_col, "Wo es hakt")
		for it: Array in stuck.slice(0, 3):
			_hint_item(hk, str(it[0]), str(it[1]), str(it[2]), UiTheme.TEXT, Vector2i(-1, -1))
	if sim.hall_level <= 2:
		var tasks := PopUI.section(_popup_col, "Aufgaben")
		for t: Array in _mayor_tasks():
			PopUI.row(tasks, str(t[0]), "erledigt" if bool(t[1]) else "offen", UiTheme.GOOD if bool(t[1]) else UiTheme.TEXT_DIM)


## Gestufter Tipp: Titel + Spielhinweis; der konkrete Schritt erst auf „Genauer?“ (Nutzer: nicht alles verraten).
## Aufgedeckte Tipps bleiben offen, solange der Titel gleich bleibt (Popover wird monatlich neu gebaut).
func _hint_item(parent: Control, title: String, hint: String, detail: String, col: Color, tile: Vector2i) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	parent.add_child(h)
	PopUI.label(h, title, 16, col, true, true).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if tile.x >= 0:
		_text_button(h, ">", _jump_log.bind(tile), "Hinspringen")
	if hint != "":
		PopUI.note(parent, hint)
	if detail == "":
		return
	var d := PopUI.note(parent, "-> " + detail, UiTheme.GOOD)
	d.visible = _hint_open.has(title)
	if not d.visible:
		var b := _text_button(h, "Genauer?", func() -> void:
			_hint_open[title] = true
			d.visible = true, "Konkreten Schritt zeigen")
		b.pressed.connect(b.queue_free)


## Wo es in der Stadt hakt: häufigste Wachstums-Blocker als [Titel, Hinweis, konkreter Schritt].
func _mayor_stuck() -> Array:
	var count := {}
	for i in map.size * map.size:
		if map.zone[i] == Config.Zone.NONE:
			continue
		for b: String in sim.growth_blockers(i):
			for key: String in STUCK_HINTS:
				if b.begins_with(key):
					count[key] = int(count.get(key, 0)) + 1
	var keys := count.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return int(count[a]) > int(count[b]))
	var out := []
	for k: String in keys:
		if int(count[k]) < 5:
			continue
		var e: Array = STUCK_HINTS[k]
		out.append(["%s (%d Gebäude/Flächen)" % [e[0], int(count[k])], e[1], e[2]])
	return out


const STUCK_HINTS := {
	"Baustoffe fehlen": ["Häuser warten auf Baustoffe", "Woher kommt das Material, das Häuser zum Wachsen brauchen?",
		"Eigene Werke bauen bzw. ausbauen (Ziegelei, Glashütte, Stahlwerk) oder Zukauf freigeben"],
	"Kein Strom": ["Gebäude ohne Strom", "Ein Teil der Stadt bleibt dunkel.", "Leitung zum Netz ziehen oder Kraftwerk bauen (Ansicht Strom, V)"],
	"Arbeitsweg zu lang": ["Lange Arbeitswege", "Die Leute brauchen zu lange zur Arbeit.",
		"Jobs näher ans Wohnen, Hauptstraße (zwei parallele Straßen), Bus oder Bahn (Ansicht Verkehr)"],
	"Unzufrieden": ["Unzufriedene Bürger", "Manche Viertel fühlen sich vergessen.", "Zufriedenheit oben anklicken: dort steht, was am meisten fehlt"],
	"Bodenwert zu niedrig": ["Viertel nicht attraktiv genug", "Für größere Häuser muss die Gegend schöner werden.",
		"Parks, Dienste in Reichweite, weniger Verschmutzung und Stau (Ansicht Bodenwert)"],
	"Keine Jobs erreichbar": ["Keine Arbeit in Reichweite", "Manche Bewohner kommen nicht zu einem Arbeitsplatz.",
		"Gewerbe/Industrie ins selbe Straßennetz bauen"],
	"Keine Einwohner erreichbar": ["Firmen ohne Mitarbeiter", "Manche Firmen erreicht niemand.", "Wohngebiet per Straße anbinden"],
	"Keine Straße": ["Flächen ohne Straße", "Nicht jede Fläche ist erschlossen.", "Straße bis höchstens 3 Felder heranführen"],
	"Kein Lager": ["Weit weg vom Lager", "Am Stadtrand dauert alles länger.", "Lagerhaus in die Nähe bauen"],
}


## Monatlich: neuer, konkreter Schritt zum nächsten Ziel -> Bürgermeister sagt ihn an (höchstens alle 6 Monate).
func _goal_hint() -> void:
	if mayor == null or sim.month == _goal_month:
		return
	_goal_month = sim.month
	_goal_wait -= 1
	var gs := mayor_goals()
	if gs.is_empty():
		return
	var g: Array = gs[mini(1, gs.size() - 1)]          # erster konkreter Schritt (Eintrag 0 ist das Ziel selbst)
	var txt := "%s - %s" % [g[0], g[1]]               # nur Hinweis, kein Lösungsweg
	if txt != _goal_last and _goal_wait <= 0:
		_goal_last = txt
		_goal_wait = 6
		mayor.say(txt, Vector2i(-1, -1), true)


## Spielleiter: nächstes Ziel (Rathaus-Stufe) mit konkreten Schritten [Text, Tipp] – was fehlt und woher es kommt.
func mayor_goals() -> Array:
	var out := []
	var nx := sim.hall_next()
	if nx.is_empty():
		if sim.institute_levels() > 0:
			out.append(["Forschung vorantreiben", "Wissen kostet Geld und Gold.", "Forschungsfenster: Projekte starten, eigene Goldmine spart Zukauf"])
		else:
			out.append(["Höchste Rathaus-Stufe erreicht", "Jetzt lockt die Wissenschaft.", "Universität + Forschungsinstitut bauen"])
		return out
	if bool(nx["ok"]):
		out.append(["Rathaus kann ausgebaut werden: %s" % nx["name"], "Alles beisammen!", "Rathaus-Fenster oben: \"Rathaus ausbauen\""])
		return out
	out.append(["Ziel: Rathaus Stufe %d (%s)" % [int(nx["level"]), nx["name"]], "Das Rathaus-Fenster zeigt, was noch fehlt.",
		"es fehlen " + ", ".join(nx["missing"])])
	if sim.population < int(nx["pop"]):
		out.append(["Mehr Einwohner (%s fehlen)" % _fmt(int(nx["pop"]) - sim.population), "Die Stadt muss wachsen.",
			"Wohngebiet nah an Gewerbe ausweisen, für Jobs sorgen; Info-Karte zeigt, was Häuser bremst"])
	var mats: Dictionary = nx["mats"]
	var growth_eats := false
	for r: String in mats:
		var have := float(sim.stock.get(r, 0.0))
		if have >= float(mats[r]):
			continue
		var src: int = Config.MATERIAL_SOURCE.get(r, Config.Special.NONE)
		var sname: String = Config.SPECIALS[src]["name"] if src != Config.Special.NONE else "Zukauf"
		var count := 0
		var low := 3
		for a in map.size * map.size:
			if map.anchor[a] == a and map.special[a] == src:
				count += 1
				low = mini(low, map.special_level(a))
		var mname: String = Config.RESOURCES[r]["name"]
		if count == 0:
			var t := ToolController.TOOLS.keys().filter(func(k: int) -> bool: return ToolController.special_for(k) == src)
			var lock := tools.locked_reason(t[0]) if not t.is_empty() else ""
			out.append(["%s fehlt (%d / %d)" % [mname, int(have), int(mats[r])], "%s entsteht nicht von allein - wer stellt es her?" % mname,
				lock if lock != "" else "%s bauen und per Straße anschließen" % sname])
		else:
			out.append(["Mehr %s (%d / %d)" % [mname, int(have), int(mats[r])], "%s kommt zu langsam nach." % mname,
				"%s ausbauen oder einen weiteren bauen" % sname if low < 3 else "weiteren %s bauen" % sname])
		if sim.population >= int(nx["pop"]) * 0.8 and not sim.hall_reserve:
			growth_eats = true
	if growth_eats:
		out.append(["Das Lager füllt sich nicht", "Wer verbraucht das Material eigentlich?", "Rathaus-Fenster: \"Material zurücklegen\" einschalten"])
	return out


## [Text, Hinweis, konkreter Schritt, Ort] nach Dringlichkeit.
func _mayor_problems() -> Array:
	var out := []
	for net: Dictionary in sim.power_nets:
		if int(net["unserved"]) > 0:
			var d: int = net["dark"]
			out.append(["Strom fehlt: %d Gebäude ohne Strom" % int(net["unserved"]), "Ein Teil der Stadt ist dunkel.",
				"Kraftwerk bauen oder Leitung zum Netz ziehen" if int(net["plants"]) == 0 else "mehr Leistung (Kraftwerk/Speicher)",
				Vector2i(d % map.size, d / map.size) if d >= 0 else Vector2i(-1, -1)])
			break
	if sim.money < 0.0:
		out.append(["Kasse im Minus ($%s)" % _fmt(int(sim.money)), "Schulden kosten Zinsen.",
			"Steuern prüfen, teure Bauten und Zukauf meiden", Vector2i(-1, -1)])
	if sim.population > 0 and sim.city_happiness < 0.5:
		var rep := sim.happiness_report()
		if not rep.is_empty() and float(rep[0][1]) < 0.0:
			out.append(["Unzufriedenheit: %d %%" % roundi(sim.city_happiness * 100.0), "Die Stimmung kippt - woran liegt es am meisten?",
				"%s: %s" % [rep[0][0], str(rep[0][2]) if str(rep[0][2]) != "" else "Dienste, Parks, Steuern prüfen"], Vector2i(-1, -1)])
	if sim.vacant_count() >= 5:
		out.append(["Leerstand: %d Gebäude" % sim.vacant_count(), "Häuser stehen leer.",
			"Info-Karte eines leeren Hauses nennt den Grund", Vector2i(-1, -1)])
	if sim.maint_short > 0.0:
		out.append(["Instandhaltung unbezahlt", "Gebäude verfallen langsam.",
			"Material fehlt: eigene Werke bauen oder Zukauf freigeben", Vector2i(-1, -1)])
	if sim.unemployment > 0.1 and not sim.founding():        # Gründung: Arbeit am Rathaus/im Abbau zählt nicht als Job
		out.append(["Arbeitslosigkeit %d %%" % roundi(sim.unemployment * 100.0), "Viele suchen Arbeit.", "Gewerbe/Industrie ausweisen",
			Vector2i(-1, -1)])
	if sim.institute_levels() > 0 and sim.research_current == "":
		out.append(["Forschungsinstitut ohne Projekt", "Das Institut wartet auf Arbeit.", "Forschungsfenster oben: Projekt starten",
			Vector2i(-1, -1)])
	return out


## Aufgabenliste für den Aufbau-Start: [Text, erledigt].
func _mayor_tasks() -> Array:
	var has := func(sp: int) -> bool: return tools._special_present(sp)
	var houses := 0
	for i in map.size * map.size:
		if map.zone[i] == Config.Zone.RES and map.level[i] > 0:
			houses += 1
	var delivering := false
	for a: int in sim.producer_info:
		if sim.delivers(a):
			delivering = true
	return [
		["Holzfäller am Wald bauen", has.call(Config.Special.LUMBER)],
		["Steinbruch am Fels bauen", has.call(Config.Special.QUARRY)],
		["Abbau per Straße mit dem Rathaus verbinden", delivering],
		["Wohngebiet ausweisen (10 Häuser)", houses >= 10],
		["200 Einwohner", sim.population >= 200],
		["Rathaus auf Stufe 2 ausbauen (Steuern + Handel)", sim.hall_level >= 2],
		["Sägewerk und Ziegelei bauen", has.call(Config.Special.SAWMILL) and has.call(Config.Special.BRICKWORKS)],
	]


## Rathaus-Fenster: aktuelle Stufe, Bedingungen der nächsten (Einwohner + Material mit Häkchen), Ausbauen, Freischaltungen.
func _fill_hall() -> void:
	var cur: Dictionary = Config.HALL_LEVELS[sim.hall_level]
	PopUI.header(_popup_col, icons.get_icon("cityhall"), "Rathaus  ·  %s" % cur["name"], "Stufe %d" % sim.hall_level,
		UiTheme.GOOD, "Steuern und Zukauf ab Stufe 2" if sim.hall_level < 2 else "Lager im Rathaus-Hof")
	var nxt := sim.hall_next()
	if nxt.is_empty():
		PopUI.note(_popup_col, "Höchste Stufe erreicht.")
	else:
		var sec := PopUI.section(_popup_col, "Nächste Stufe: %s" % nxt["name"])
		var need_pop: int = nxt["pop"]
		PopUI.row(sec, "Einwohner", "%s / %s" % [_fmt(sim.population), _fmt(need_pop)],
			UiTheme.GOOD if sim.population >= need_pop else UiTheme.BAD)
		var mats: Dictionary = nxt["mats"]
		for r: String in mats:
			var have := int(sim.stock.get(r, 0.0))
			PopUI.row(sec, Config.RESOURCES[r]["name"], "%s / %s" % [_fmt(have), _fmt(int(mats[r]))],
				UiTheme.GOOD if have >= int(mats[r]) else UiTheme.BAD)
		if bool(nxt["ok"]):
			var b := _text_button(sec, "Rathaus ausbauen", _upgrade_hall, "Material wird aus dem Lager genommen")
			b.size_flags_horizontal = Control.SIZE_SHRINK_END
		else:
			PopUI.note(sec, "Es fehlen: " + ", ".join(nxt["missing"]), UiTheme.BAD)
		# Rathaus-Reserve: Material der nächsten Stufe nicht fürs Wachsen/Bauen verbrauchen
		var res := PopUI.section(_popup_col, "Material zurücklegen")
		PopUI.note(res, "AN: Häuser, Instandhaltung, Werke und Bauen nehmen das Material für die nächste Stufe nicht aus dem Lager (Fehlendes wird zugekauft oder das Wachstum wartet). So sammelt sich der Vorrat fürs Rathaus.")
		var tb := _text_button(res, "Zurücklegen: AN" if sim.hall_reserve else "Zurücklegen: AUS", _toggle_hall_reserve,
			"Rathaus-Reserve umschalten")
		tb.size_flags_horizontal = Control.SIZE_SHRINK_END
		var unl := PopUI.section(_popup_col, "Neu mit Stufe %d" % int(nxt["level"]))
		PopUI.note(unl, _hall_unlocks(int(nxt["level"])), UiTheme.TEXT)
	# Zukauf-Freigaben (der Bürgermeister fragt bei Bedarf; hier abschaltbar)
	var fr := PopUI.section(_popup_col, "Zukauf-Freigaben")
	var any := false
	for r: String in Config.RESOURCES:
		if bool(sim.trade_allow.get(r, false)):
			any = true
			var h := HBoxContainer.new()
			fr.add_child(h)
			PopUI.label(h, Config.RESOURCES[r]["name"] + ": wird bei Bedarf zugekauft", 15, UiTheme.TEXT, false, true) \
				.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_text_button(h, "Aus", func() -> void:
				sim.trade_allow.erase(r)
				_fill_popup(), "Freigabe zurücknehmen")
	if not any:
		PopUI.note(fr, "Keine - der Bürgermeister fragt, wenn etwas fehlt." if sim.can_trade() else "Zukauf erst ab Stufe 2 (Dorf).")
	var now := PopUI.section(_popup_col, "Freigeschaltet")
	var parts := PackedStringArray()
	for lv in range(1, sim.hall_level + 1):
		parts.append(_hall_unlocks(lv))
	PopUI.note(now, "  ·  ".join(parts))


func _hall_unlocks(lv: int) -> String:
	var names := PackedStringArray()
	if lv == 1:
		names.append("Straßen, Wohnen, Strom, Abbau, Lager")
	if lv == 2:
		names.append("Steuern, Zukauf + Verkauf von Überschuss")
	if int(Config.HALL_LEVELS[lv].get("grant", 0)) > 0:
		names.append("Zuschuss %s $" % _fmt(int(Config.HALL_LEVELS[lv]["grant"])))
	for t: int in ToolController.HALL_LEVEL:
		if int(ToolController.HALL_LEVEL[t]) == lv:
			names.append(str(ToolController.TOOLS[t]["name"]))
	return ", ".join(names)


func _toggle_hall_reserve() -> void:
	sim.hall_reserve = not sim.hall_reserve
	show_message("Material fürs Rathaus wird zurückgelegt" if sim.hall_reserve else "Rathaus-Reserve aus")
	_fill_popup()


func _upgrade_hall() -> void:
	var err := sim.upgrade_hall()
	if err != "":
		show_message(err)
	_fill_popup()


## Große Karte in der Bildmitte, wenn ein Forschungsprojekt fertig ist: Wirkung in Zahlen + Hinspringen.
func _on_research_finished(id: String) -> void:
	if _breakthrough != null:
		_breakthrough.queue_free()
	var def: Dictionary = Config.RESEARCH[id]
	var impact := sim.tech_impact(id)
	_breakthrough = _card(_root, 16, 16)
	_breakthrough.custom_minimum_size.x = PopUI.WIDTH + 40
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	_breakthrough.add_child(col)
	PopUI.label(col, "DURCHBRUCH!", 14, PopUI.ACCENT, true)
	PopUI.header(col, icons.get_icon("institute"), def["name"], "", UiTheme.TEXT, def["desc"])
	var sec := PopUI.section(col, "In deiner Stadt")
	for line: String in impact["lines"]:
		PopUI.label(sec, "+ " + line, 16, UiTheme.GOOD, false, true)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_END
	btns.add_theme_constant_override("separation", 8)
	col.add_child(btns)
	var tile: Vector2i = impact["tile"]
	if tile.x >= 0:
		_text_button(btns, "Hinspringen", func() -> void:
			focus_requested.emit(tile)
			_close_breakthrough(), "")
	_text_button(btns, "Weiter", _close_breakthrough, "")
	_breakthrough.modulate.a = 0.0           # erst zeigen, wenn Größe/Position fertig sind (kein Springen)
	await RenderingServer.frame_pre_draw
	if is_instance_valid(_breakthrough):
		_breakthrough.reset_size()
		_breakthrough.position = (_ui_size() - _breakthrough.size) * 0.5
		_breakthrough.modulate.a = 1.0


## Bürgermeister fragt nach Zukauf (Nutzer 1.11.: Zukauf ist eine bewusste Entscheidung). Karte über der Werkzeugleiste,
## je Rohstoff Menge, wofür, Preis und Knöpfe Diesmal / Immer / Nein. Ohne Antwort fragt er in 6 Monaten wieder.
func _on_trade_request(req: Dictionary) -> void:
	if _trade_card != null:
		_trade_card.queue_free()
	_trade_card = _card(_root, 14, 12)
	_trade_card.custom_minimum_size.x = PopUI.WIDTH + 80
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_trade_card.add_child(col)
	PopUI.label(col, "DER BÜRGERMEISTER FRAGT", 14, PopUI.ACCENT, true)
	PopUI.header(col, icons.get_icon("people"), "Zukauf freigeben?", "", UiTheme.TEXT,
		"Ohne Zukauf warten Häuser, Werke stehen, Kraftwerke liefern weniger. Zukauf kostet 3x Grundpreis.")
	var total := 0
	var names := PackedStringArray()
	var open_rows := [req.size()]          # Array: Lambdas fangen Zahlen als Kopie
	for r: String in req:
		var e: Dictionary = req[r]
		total += int(e["cost"])
		names.append("%d %s" % [int(e["amount"]), Config.RESOURCES[r]["name"]])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		col.add_child(row)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		PopUI.label(info, "%d %s  ·  $%s" % [int(e["amount"]), Config.RESOURCES[r]["name"], _fmt(int(e["cost"]))], 16,
			UiTheme.TEXT, true)
		PopUI.label(info, "für " + str(e["uses"]), 13, UiTheme.TEXT_DIM, false, true)
		for ch: Array in [["Diesmal", "once", "Nur diesen Monat zukaufen"], ["Immer", "always",
				"Dauerhaft zukaufen, wenn es fehlt (im Rathaus-Fenster abschaltbar)"], ["Nein", "no", "Nicht zukaufen, 12 Monate nicht fragen"]]:
			_text_button(row, str(ch[0]), func() -> void:
				sim.answer_trade(r, str(ch[1]))
				row.queue_free()
				open_rows[0] -= 1
				if open_rows[0] <= 0:
					_close_trade_card(), str(ch[2]))
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(btns)
	_text_button(btns, "Später", _close_trade_card, "Ohne Entscheidung schließen (fragt in 6 Monaten wieder)")
	if mayor != null:
		mayor.say("Uns fehlt Material: %s - zukaufen für $%s?" % [", ".join(names), _fmt(total)])
	_trade_card.modulate.a = 0.0
	await RenderingServer.frame_pre_draw
	if is_instance_valid(_trade_card):
		_trade_card.reset_size()
		var ui := _ui_size()
		_trade_card.position = Vector2((ui.x - _trade_card.size.x) * 0.5, ui.y - _trade_card.size.y - 160.0)
		_trade_card.modulate.a = 1.0


func _close_trade_card() -> void:
	if _trade_card != null:
		_trade_card.queue_free()
		_trade_card = null


func _close_breakthrough() -> void:
	if _breakthrough != null:
		_breakthrough.queue_free()
		_breakthrough = null


func _research_budget(dir: int) -> void:
	var steps: Array = Config.RESEARCH_BUDGET_STEPS
	var k := 0
	for j in steps.size():
		if float(steps[j]) <= sim.research_budget + 0.5:
			k = j
	k = clampi(k + dir, 0, steps.size() - 1)
	sim.research_budget = float(steps[k])
	_fill_popup()


func _start_research(id: String) -> void:
	var err := sim.start_research(id)
	if err != "":
		show_message(err)
	else:
		show_message("Forschung gestartet: %s" % Config.RESEARCH[id]["name"])
	_fill_popup()


## Popover unter seinen Knopf setzen (innerhalb des Bildschirms).
func _place_popup() -> void:
	if _popup_btn == null:
		return
	var r := _popup_btn.get_global_rect()
	var vw := _ui_size().x
	_popup.position = Vector2(clampf(r.position.x, MARGIN, maxf(vw - _popup.size.x - MARGIN, MARGIN)), r.end.y + 8)


## Größe des Popovers: Breite fest für neue Karten (Umbruch), Höhe bis zum Bildschirmrand, darüber scrollen.
## Größe des Popovers: feste Breite (Umbruch), Höhe = Inhalt bis über die Werkzeugleiste, darüber scrollen.
## Kein Messen mit Verzögerung: das Popover folgt dem Signal minimum_size_changed seines Inhalts. Godot ordnet Container
## und umbrochene Texte innerhalb desselben Frames fertig an, bevor gezeichnet wird -> im Bild nur die Endgröße
## (früher: Messen vor dem Layout + Korrektur einen Frame später = sichtbares Zucken).
func _popup_width() -> float:
	return 620.0 if _popup_kind == "research" else float(PopUI.WIDTH)


func _fit_popup() -> void:
	_popup_col.custom_minimum_size.x = _popup_width()
	_fit_pending = false
	_apply_fit()


func _on_popup_content_changed() -> void:
	if _popup_kind == "" or _fit_pending:
		return
	_fit_pending = true
	_apply_fit.call_deferred()     # gebündelt, läuft noch im selben Frame vor dem Zeichnen


func _apply_fit() -> void:
	_fit_pending = false
	if _popup_kind == "":
		return
	var frame := Engine.get_process_frames()
	if frame != _fit_frame:
		_fit_frame = frame
		_fit_count = 0
	_fit_count += 1
	if _fit_count > 6:
		return                     # Notbremse gegen Schaukeln
	var want := _popup_col.get_combined_minimum_size().y
	var room := maxf(_ui_size().y - maxf(_popup.position.y, 100.0) - 130.0, 200.0)   # bis über die Werkzeugleiste
	var h := minf(want, room)
	var w := _popup_width()
	if absf(h - _popup_scroll.custom_minimum_size.y) < 0.5 and _popup_scroll.custom_minimum_size.x == w:
		return
	_popup_col.custom_minimum_size.x = w
	_popup_scroll.custom_minimum_size = Vector2(w, h)
	_popup.reset_size()
	_place_popup()


func _close_popup() -> void:
	_popup.visible = false
	_popup_kind = ""
	_happy_btn.set_pressed_no_signal(false)
	_bell_btn.set_pressed_no_signal(false)
	_research_btn.set_pressed_no_signal(false)
	_hall_btn.set_pressed_no_signal(false)
	_mayor_btn.set_pressed_no_signal(false)
	_view_btn.set_pressed_no_signal(_overlay_mode != 0)


func _fill_popup() -> void:
	for c in _popup_col.get_children():
		_popup_col.remove_child(c)      # sofort entfernen, sonst zählt reset_size() die alten Einträge mit
		c.queue_free()
	match _popup_kind:
		"research":
			_fill_research()
		"hall":
			_fill_hall()
		"mayor":
			_fill_mayor()
		"log":
			_fill_log()
		"view":
			_fill_view()
		_:
			_fill_happy()
	_fit_popup()


## Meldungsverlauf: Datum | Text (umbrochen) | Hinspringen.
func _fill_log() -> void:
	PopUI.header(_popup_col, icons.get_icon("bell"), "Meldungen", str(_log.size()) if not _log.is_empty() else "",
		UiTheme.TEXT, "Neueste zuerst  ·  Pfeil springt zum Ort")
	if _log.is_empty():
		PopUI.note(_popup_col, "Keine Meldungen.")
		return
	var list := PopUI.section(_popup_col, "Verlauf")
	for entry: Dictionary in _log:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		list.add_child(h)
		var d := PopUI.label(h, str(entry["date"]), 14, UiTheme.TEXT_DIM)
		d.custom_minimum_size.x = 90
		var c: int = entry["count"]
		var txt: String = entry["text"]
		var problem := txt.begins_with("Feuer") or txt.contains("Kein Strom") or txt.contains("sinkt") or txt.contains("Engpass")
		PopUI.label(h, txt + ((" (x%d)" % c) if c > 1 else ""), 15, UiTheme.BAD if problem else UiTheme.TEXT, false, true)
		var tile: Vector2i = entry["tile"]
		if tile.x >= 0:
			_text_button(h, ">", _jump_log.bind(tile), "Hinspringen")


## Ansichten: Listeneinträge (ganze Zeile klickbar): Name + Hauptkennzahl, Details klein darunter.
func _fill_view() -> void:
	PopUI.header(_popup_col, icons.get_icon("stats"), "Ansicht", "", UiTheme.TEXT, "Taste V schaltet durch")
	var avg := _city_averages()
	var rows := [
		["", "Karte ohne Einfärbung"],
		["Stau Ø %d %%" % roundi(sim.avg_congestion * 100.0), "ÖPNV-Anteil %d %%" % roundi(sim.transit_share * 100.0)],
		["Ø %.1f" % avg[0], "bei Wohnhäusern"],
		["Ø %d %%" % roundi(avg[1] * 100.0), "bei Wohnhäusern"],
		["Ø %d %%" % roundi(avg[2] * 100.0), "Arbeitslos %d %%" % roundi(sim.unemployment * 100.0)],
		["%d %%" % roundi(sim.city_happiness * 100.0), "ganze Stadt"],
		["%d %%" % roundi(sim.transit_share * 100.0), "Bus %d  ·  Bahn %d  ·  Wohnungen mit Anschluss %d %%" % [
			int(sim.bus_riders), int(sim.rail_riders), roundi(avg[3] * 100.0)]],
		["%d / %d MW" % [sim.power_demand, sim.power_supply], "%d Netze  ·  %d Gebäude ohne Strom" % [_power_net_count(),
			_dark_buildings()]],
		["", _deposit_summary()],
	]
	for m in MapOverlay.MODE_NAMES.size():
		var r: Array = rows[m]
		PopUI.list_item(_popup_col, MapOverlay.MODE_NAMES[m] if m > 0 else "Aus", r[0], r[1], m == _overlay_mode,
			_pick_view.bind(m))


## Zufriedenheit: Kopf mit Wert, Abschnitte "Senkt"/"Hebt" mit Balken, Tipps klein darunter, Nullposten gesammelt.
func _fill_happy() -> void:
	var hv := roundi(sim.city_happiness * 100.0)
	PopUI.header(_popup_col, icons.get_icon("happy"), "Zufriedenheit", "%d %%" % hv,
		UiTheme.BAD if hv < 40 else (UiTheme.GOOD if hv > 65 else UiTheme.TEXT),
		"Grundwert %d  ·  unter %d %% ziehen Leute weg" % [roundi(Config.HAPPY_BASE * 100.0), roundi(Config.HAPPY_LEAVE * 100.0)])
	var rep := sim.happiness_report()
	var vmax := 0.01
	for part: Array in rep:
		vmax = maxf(vmax, absf(float(part[1])))
	var neutral := PackedStringArray()
	var neg: VBoxContainer = null
	var pos: VBoxContainer = null
	for part: Array in rep:
		var pts := roundi(float(part[1]) * 100.0)
		if pts == 0:
			neutral.append(part[0])
			continue
		var box: VBoxContainer
		if pts < 0:
			if neg == null:
				neg = PopUI.section(_popup_col, "Senkt")
			box = neg
		else:
			if pos == null:
				pos = PopUI.section(_popup_col, "Hebt")
			box = pos
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		box.add_child(h)
		var n := PopUI.label(h, part[0], 16, UiTheme.TEXT, false, true)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		PopUI.diverging(h, float(part[1]), vmax)
		var v := PopUI.label(h, "%s%d" % ["+" if pts > 0 else "", pts], 16, UiTheme.GOOD if pts > 0 else UiTheme.BAD, true)
		v.custom_minimum_size.x = 40
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		if str(part[2]) != "":
			PopUI.note(box, "-> " + str(part[2]))
	if not neutral.is_empty():
		PopUI.note(_popup_col, "Ohne Einfluss: " + ", ".join(neutral))
	PopUI.note(_popup_col, "Ansicht Zufriedenheit (V) zeigt, wo es hakt.")

func _jump_log(tile: Vector2i) -> void:
	focus_requested.emit(tile)
	_close_popup()


func _pick_view(m: int) -> void:
	overlay_selected.emit(m)
	_close_popup()


## Restmengen aller Vorkommen + Waldfläche (Ansicht-Liste).
func _refresh_stock() -> void:
	var cap := sim.stock_capacity()
	var any := false
	for r: String in _stock_labels:
		var v := float(sim.stock.get(r, 0.0))
		var prod := float(sim.production.get(r, 0.0))
		var exp := float(sim.exported.get(r, 0.0))
		var imp := float(sim.imported.get(r, 0.0))
		var built := float(sim.last_materials.get(r, 0.0))
		any = any or v > 0.0 or prod > 0.0
		var l: Label = _stock_labels[r]
		l.text = _fmt(int(v))
		l.add_theme_color_override("font_color", UiTheme.WARN if v >= cap else UiTheme.TEXT)
		var verb := "Herstellung" if Config.RESOURCES[r].get("good", false) else "Förderung"
		l.tooltip_text = "%s: %d / %d (Lager)\n%s +%d/Monat%s%s%s" % [Config.RESOURCES[r]["name"], int(v), cap, verb, int(prod),
			("\nVerbaut beim Wachsen: %d" % int(built)) if built > 0.0 else ""
				+ (("\nKraftwerke: %d aus dem Lager (Werke haben Vorrang)" % int(sim.coal_burned)) if r == "coal" and sim.coal_burned > 0.0 else ""),
			("\nZugekauft: %d (-$%d)" % [int(imp), roundi(imp * float(Config.RESOURCES[r]["price"]) * Config.IMPORT_FACTOR)]) if imp > 0.0 else "",
			("\nVerkauft: %d (+$%d)" % [int(exp), roundi(exp * float(Config.RESOURCES[r]["price"]) * Config.EXPORT_FACTOR)]) if exp > 0.0 else ""]
	_stock_card.visible = any and not _hud_hidden()


func _deposit_summary() -> String:
	var left := {}
	var trees := 0
	for i in map.size * map.size:
		if map.ore_amt[i] > 0:
			var r: String = Config.ORE_RESOURCE[map.ore[i]]
			left[r] = int(left.get(r, 0)) + map.ore_amt[i] * Config.ORE_UNIT
		if map.feature[i] == Config.Feature.TREE:
			trees += 1
	var parts := PackedStringArray()
	for r: String in ["stone", "coal", "iron", "gold", "sand", "clay"]:
		parts.append("%s %s" % [Config.RESOURCES[r]["name"], _fmt(int(left.get(r, 0)))])
	parts.append("Bäume %d" % trees)
	return "  ·  ".join(parts)


func _power_net_count() -> int:
	var c := 0
	for net: Dictionary in sim.power_nets:
		if int(net["demand"]) > 0 or int(net["plants"]) > 0:
			c += 1
	return c


func _dark_buildings() -> int:
	var c := 0
	for net: Dictionary in sim.power_nets:
		c += int(net["unserved"])
	return c


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
				pop += map.residents(i)
				if sim.has_transit(i):
					pop_transit += map.residents(i)
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
	_update_bubble()
	if (GraphicsSettings.day_night and DayNight.daylight < 0.45) != _power_night_shown and _power != null:
		_update_power_label()
	if not _cost_pill.has_meta("pin"):       # Testlauf (--hover): Blase bleibt in der Bildmitte
		var mp := _cost_pill.get_viewport().get_mouse_position() / scale
		_cost_pill.position = mp + Vector2(20, 14)
	else:
		_cost_pill.position = _ui_size() * 0.5 + Vector2(20, 14)
	_cost_pill.visible = _cost.text != ""
	if _toast_time > 0.0:
		_toast_time -= delta
		_toast_pill.modulate.a = clampf(_toast_time * 2.0, 0.0, 1.0)
		if _toast_time <= 0.0:
			_toast_pill.visible = false
	for strip: Control in _feed.get_children():
		var left_t: float = float(strip.get_meta("time")) - delta
		strip.set_meta("time", left_t)
		strip.modulate.a = clampf(left_t, 0.0, 1.0)
		if left_t <= 0.0:
			strip.queue_free()
	var n := fire_dept.fires.size()
	_fire_pill.visible = n > 0
	if n > 0:
		var txt := "%d %s  [Tab]" % [n, "Brand" if n == 1 else "Brände"]
		if _fire_btn.text != txt:
			_fire_btn.text = txt
			_fire_pill.reset_size()


func _unhandled_key_input(event: InputEvent) -> void:
	if DevTools.automated and not event.has_meta("synthetic"):
		return      # echte Tasten des Nutzers ignorieren (siehe DevTools.automated)
	var k := event as InputEventKey
	if not k.pressed or k.echo:
		return
	# Geld-Cheat: Strg/Cmd + Shift + G (vor den Werkzeug-Tasten, G = Terrain)
	if k.keycode == KEY_G and k.shift_pressed and (k.ctrl_pressed or k.meta_pressed):
		cheat_money()
		return
	if k.keycode == KEY_F and k.ctrl_pressed and k.meta_pressed:     # macOS-üblich: Ctrl+Cmd+F
		toggle_fullscreen()
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
		KEY_I:
			toggle_info_detail()
		KEY_F11:
			toggle_fullscreen()
		KEY_H:
			toggle_hud()
		KEY_M:
			Audio.toggle_mute()
			show_message("Ton aus [M]" if Audio.muted else "Ton an")
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
	var tip: String = def["name"] if def["key"] == KEY_NONE else "%s   [%s]" % [def["name"], OS.get_keycode_string(def["key"])]
	if def.has("cost"):
		tip += "\n$%d" % def["cost"]
		var mats := _tool_materials(t)
		if not mats.is_empty():
			var parts := PackedStringArray()
			for r: String in mats:
				parts.append("%d %s" % [int(mats[r]), Config.RESOURCES[r]["name"]])
			tip += " + " + ", ".join(parts)
	return tip


func _tool_materials(t: ToolController.Tool) -> Dictionary:
	match t:
		ToolController.Tool.ROAD: return Config.BUILD_MATERIALS["road"]
		ToolController.Tool.RAIL: return Config.BUILD_MATERIALS["rail"]
		ToolController.Tool.POWERLINE: return Config.BUILD_MATERIALS["powerline"]
		ToolController.Tool.BUS_STOP: return Config.BUILD_MATERIALS["bus_stop"]
		ToolController.Tool.STATION: return Config.BUILD_MATERIALS["station"]
		ToolController.Tool.PARK: return Config.BUILD_MATERIALS["park"]
	var m: Dictionary = Config.SPECIAL_MATERIALS.get(tools.special_for(t), {})
	return m if sim.build_factor() == 1.0 else Simulation.scale_materials(m, sim.build_factor())


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


## Info (kurz, klein, über der Werkzeugleiste, ohne Verlauf): Ansicht gewechselt, gespeichert, Bau-Fehler ...
func show_message(text: String, _tile := Vector2i(-1, -1)) -> void:
	_toast.text = text
	_toast_pill.visible = true
	_toast_pill.modulate.a = 1.0
	_toast_time = 2.5


## Warnung (Problem): Streifen rechts + Verlauf (Glocke). Gleiche Warnung direkt hintereinander wird gezählt statt gestapelt.
func notify(text: String, tile := Vector2i(-1, -1)) -> void:
	if mayor != null:
		var good := text.begins_with("Forschung abgeschlossen") or text.begins_with("Rathaus ausgebaut") \
			or text.begins_with("Prospektor")
		mayor.say(text, tile, good)
	if tile.x >= 0:
		_toast_target = tile
	var entry: Dictionary
	if not _log.is_empty() and _log[0]["text"] == text:
		entry = _log[0]
		entry["count"] = int(entry["count"]) + 1
		entry["tile"] = tile
		entry["date"] = sim.date_string()
	else:
		entry = {"text": text, "tile": tile, "date": sim.date_string(), "count": 1}
		_log.push_front(entry)
		if _log.size() > LOG_MAX:
			_log.pop_back()
	_unread += 1
	_update_bell()
	if _popup_kind == "log":
		_fill_popup()
	# Streifen: vorhandenen gleichen Text auffrischen, sonst neuen oben einfügen
	for strip: Control in _feed.get_children():
		if strip.get_meta("text") == text:
			strip.set_meta("time", FEED_TIME)
			var lbl: Label = strip.get_child(0)
			lbl.text = _feed_text(entry)
			return
	var strip := _card(_feed, 8, 4)
	strip.add_theme_stylebox_override("panel", UiTheme.card(8, 4, UiTheme.TOAST))
	strip.size_flags_horizontal = Control.SIZE_SHRINK_END
	strip.set_meta("text", text)
	strip.set_meta("time", FEED_TIME)
	var lbl := _label(strip, 14, UiTheme.WARN)
	lbl.text = _feed_text(entry)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.custom_minimum_size.x = 420
	if tile.x >= 0:
		strip.tooltip_text = "Klicken: hinspringen"
		strip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		strip.gui_input.connect(_on_strip_input.bind(tile))
	_feed.move_child(strip, 0)
	while _feed.get_child_count() > FEED_MAX:
		var old := _feed.get_child(_feed.get_child_count() - 1)
		_feed.remove_child(old)
		old.queue_free()


func _feed_text(entry: Dictionary) -> String:
	var c: int = entry["count"]
	return "%s%s%s" % [entry["text"], (" (x%d)" % c) if c > 1 else "", "  >" if (entry["tile"] as Vector2i).x >= 0 else ""]


func _on_strip_input(event: InputEvent, tile: Vector2i) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		focus_requested.emit(tile)


func _update_bell() -> void:
	_bell_btn.text = str(_unread) if _unread > 0 else ""
	for st: String in ["font_color", "font_hover_color", "font_pressed_color"]:
		_bell_btn.add_theme_color_override(st, UiTheme.BAD if _unread > 0 else UiTheme.TEXT)


## Reihum zu laufenden Bränden springen; ohne Brand zum Ort der letzten Meldung.
func jump_to_fire() -> void:
	var tiles := fire_dept.burning_tiles()
	if tiles.is_empty():
		if _toast_target.x >= 0:      # Ort der letzten Warnung
			focus_requested.emit(_toast_target)
		return
	_fire_next = (_fire_next + 1) % tiles.size()
	focus_requested.emit(tiles[_fire_next])


func _refresh() -> void:
	var tp := Perf.begin()
	_refresh_inner()
	Perf.end("hud.aktualisieren", tp)


## Stromanzeige oben: tagsüber Tagesbilanz, während der sichtbaren Nacht die Nachtbilanz (Bedarf 75 %, Solar 0,
## Speicher) – so fällt ein nächtlicher Engpass dann auf, wenn es dunkel ist.
func _update_power_label() -> void:
	var night := GraphicsSettings.day_night and DayNight.daylight < 0.45
	_power_night_shown = night
	if not night:
		_power.text = "%d / %d MW" % [sim.power_demand, sim.power_supply]
		_power.add_theme_color_override("font_color", UiTheme.BAD if _power_dark > 0 else UiTheme.TEXT)
		return
	var need := 0.0
	var have := 0
	var short := false
	for net: Dictionary in sim.power_nets:
		need += int(net["demand"]) * Config.NIGHT_DEMAND
		have += int(net.get("night", net["capacity"]))
		if bool(net.get("night_limited", false)) and int(net["unserved"]) > 0:
			short = true
	_power.text = "Nacht %d / %d MW" % [roundi(need), have]
	_power.add_theme_color_override("font_color", UiTheme.BAD if short or _power_dark > 0 else UiTheme.COM)


func _refresh_inner() -> void:
	_goal_hint()
	_money.text = "$ %s" % _fmt(int(sim.money))
	_money.add_theme_color_override("font_color", UiTheme.BAD if sim.money < 0 else UiTheme.TEXT)
	var delta := sim.last_income - sim.last_expense
	_money_delta.text = "%s%s / Monat" % ["+" if delta >= 0 else "-", _fmt(absi(int(delta)))]
	_money_delta.add_theme_color_override("font_color", UiTheme.GOOD if delta >= 0 else UiTheme.BAD)
	_date.text = sim.date_string()
	_pop.text = _fmt(sim.population)
	_jobs.text = _fmt(sim.jobs_com + sim.jobs_ind)
	# Bedarf aller Gebäude / Leistung aller Kraftwerke; rot, sobald irgendwo ein Gebäude ohne Strom ist
	var dark := 0
	var tip := PackedStringArray(["Strom: Bedarf / Leistung (alle Netze)", "Geliefert: %d MW" % sim.power_served])
	var nets := sim.power_nets.duplicate()
	nets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["unserved"]) > int(b["unserved"]))
	var shown := 0
	for net: Dictionary in nets:
		dark += int(net["unserved"])
		if (int(net["demand"]) > 0 or int(net["plants"]) > 0) and shown < 8:
			shown += 1
			var k: int = net["key"]
			var state := "ok"
			if int(net["plants"]) == 0 and int(net["unserved"]) > 0:
				state = "KEIN KRAFTWERK"
			elif int(net["unserved"]) > 0:
				state = "Engpass, %d ohne Strom" % int(net["unserved"])
			tip.append("Netz bei %d,%d: %d / %d MW, %d Kraftwerk(e) - %s" % [k % map.size, k / map.size,
				int(net["demand"]), int(net["capacity"]), int(net["plants"]), state])
			if int(net.get("day", 0)) != int(net.get("night", 0)):
				tip.append("   Tag %d MW / Nacht %d MW (Speicher %d)%s" % [int(net["day"]), int(net["night"]),
					int(net["store_used"]), "  -> nachts zu knapp!" if bool(net["night_limited"]) and int(net["unserved"]) > 0 else ""])
	if dark > 0:
		tip.append("%d Gebäude ohne Strom - Ansicht Strom (V) zeigt wo" % dark)
	_power_dark = dark
	_update_power_label()
	_power.tooltip_text = "\n".join(tip)
	_power.mouse_filter = Control.MOUSE_FILTER_PASS
	_refresh_stock()
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
	if sim.research_spent > 0.0:
		inc.append("  davon Forschung  $%d" % roundi(sim.research_spent))
	if sim.interest_cost > 0.0:
		inc.append("  davon Schuldzinsen  $%d  (1 %% je Monat auf das Minus)" % roundi(sim.interest_cost))
	if not sim.last_maint.is_empty():
		var mt := 0.0
		for r: String in sim.last_maint:
			mt += float(sim.last_maint[r])
		inc.append("  Instandhaltung: %d Material/Monat (Recycling %d)%s" % [roundi(mt), roundi(sim.maint_recycled),
			"  - Geld fehlt, Gebäude verfallen!" if sim.maint_short > 0.0 else ""])
	if sim.admin_cost > 0.0:
		inc.append("  davon Verwaltung  $%d  (ab %s Einw., steigt mit der Größe)" % [roundi(sim.admin_cost), _fmt(Config.ADMIN_FROM)])
	if sim.import_cost > 0.0:
		inc.append("  davon Zukauf (Kohle, Baustoffe)  $%d" % roundi(sim.import_cost))
	_money_delta.tooltip_text = "\n".join(inc)
	_money_delta.mouse_filter = Control.MOUSE_FILTER_PASS
	_rci.values = [sim.demand_res, sim.demand_com, sim.demand_ind]
	_rci.queue_redraw()
	_on_hover(tools.hover)


## Info-Karte: kompakt = Titel + Kernzeile + nur Probleme; Taste I = alle Abschnitte.
func _on_hover(t: Vector2i) -> void:
	if t.x < 0:
		_info_card.visible = false
		return
	_info_card.visible = not _hud_hidden()
	var i := map.idx(t.x, t.y)
	var title := "Gelände"
	var summary := ""
	var problems := PackedStringArray()
	var sec := {}           # Abschnitt -> PackedStringArray (Reihenfolge über ORDER)
	var add := func(section: String, text: String) -> void:
		var arr: PackedStringArray = sec.get(section, PackedStringArray())
		arr.append(text)        # Packed-Array aus Dictionary ist eine Kopie -> zurückschreiben
		sec[section] = arr
	if map.is_water(t.x, t.y):
		title = "Wasser"
	elif map.special[i] != Config.Special.NONE:
		var def: Dictionary = Config.SPECIALS[map.special[i]]
		title = def["name"]
		if def.has("service"):
			var a := map.anchor[i]
			var lv := map.special_level(i)
			title = "%s  ·  Stufe %d" % [def["name"], lv]
			var load: float = sim.service_load.get(a, 0.0)
			summary = "Auslastung %d%%  ·  Reichweite %d" % [roundi(load * 100.0), sim.service_radius(a)]
			if not sim.special_powered(i):
				problems.append("x Kein Strom - arbeitet nicht")
			elif load > 1.0:
				problems.append("x Überlastet - ausbauen oder weiteres Gebäude")
			add.call("Dienst", "Reichweite %d Tiles  ·  Kapazität %s %s" % [sim.service_radius(a),
				_fmt(int(sim.service_capacity(a))), "Einw. + Jobs" if def["service"] == "fire" else "Einw."])
			if def["service"] == "university":
				add.call("Dienst", "Akademiker: %s (je Institutsstufe %s für volle Leistung)" % [_fmt(int(sim.academics_count())),
					_fmt(Config.ACADEMICS_PER_LEVEL)])
			add.call("Dienst", "Unterhalt $%d/Monat  ·  Strom %d MW" % [int(def["upkeep"] * Config.UPKEEP_LEVEL[lv]),
				sim.tile_power_use(a)])
			if def["service"] == "venue":
				var every: int = def["event_every"]
				var now := float(sim.venue_event.get(a, 0.0)) > 0.0
				add.call("Dienst", "%d Besucher je %s  ·  %s" % [int(sim.venue_visitors(a)),
					"Vorstellung" if every == 1 else "Spieltag", "heute!" if now else "alle %d Monate" % every])
				add.call("Dienst", "Straßen rundum: Auslastung %d%%" % roundi(float(sim.venue_jam.get(a, 0.0)) * 100.0))
			if lv < 3:
				add.call("Dienst", "Ausbau: gleiches Werkzeug, $%d" % (int(def["upgrade"]) * lv))
		elif def.has("process"):
			var a := map.anchor[i]
			var lv := map.special_level(a)
			title = "%s  ·  Stufe %d" % [def["name"], lv]
			var info: Dictionary = sim.producer_info.get(a, {})
			var proc: Dictionary = def["process"]
			var ins := PackedStringArray()
			var outs := PackedStringArray()
			for r: String in proc["in"]:
				ins.append("%d %s" % [int(proc["in"][r]) * lv, Config.RESOURCES[r]["name"]])
			for r: String in proc["out"]:
				outs.append("%d %s" % [int(float((info.get("out", {}) as Dictionary).get(r, 0.0))), Config.RESOURCES[r]["name"]])
			summary = "Herstellung: %s /Monat" % ", ".join(outs)
			add.call("Dienst", "Bedarf: %s /Monat" % ", ".join(ins))
			if str(info.get("issue", "")) != "":
				problems.append("x " + str(info["issue"]))
			add.call("Dienst", "Unterhalt $%d/Monat  ·  Strom %d MW" % [int(def["upkeep"] * Config.UPKEEP_LEVEL[lv]),
				sim.tile_power_use(a)])
			if lv < 3:
				add.call("Dienst", "Ausbau (mehr Leistung): gleiches Werkzeug, $%d" % (int(def["upgrade"]) * lv))
		elif def.has("research"):
			var a := map.anchor[i]
			var lv := map.special_level(a)
			title = "%s  ·  Stufe %d" % [def["name"], lv]
			summary = "%d Punkte/Monat (Stadt gesamt %d)" % [roundi(Config.RESEARCH_POINTS * lv * sim.academic_factor()
				* Simulation.budget_factor(sim.research_budget)), roundi(sim.research_points())]
			if sim.academic_factor() < 1.0 and sim.special_powered(i):
				problems.append("x Zu wenig Akademiker (%d %% Leistung) - Universität ausbauen/weitere bauen" %
					roundi(sim.academic_factor() * 100.0))
			if not sim.special_powered(i):
				problems.append("x Kein Strom - forscht nicht")
			if sim.research_current == "":
				problems.append("x Kein Projekt gewählt - Forschungsfenster oben")
			else:
				add.call("Dienst", "Projekt: %s (%d %%)" % [Config.RESEARCH[sim.research_current]["name"],
					roundi(100.0 * sim.research_progress / float(Config.RESEARCH[sim.research_current]["points"]))])
			add.call("Dienst", "Akademiker %s  ·  Budget $%d/Monat" % [_fmt(int(sim.academics_count())), int(sim.research_budget)])
			add.call("Dienst", "Unterhalt $%d/Monat  ·  Strom %d MW" % [int(def["upkeep"] * Config.UPKEEP_LEVEL[lv]),
				sim.tile_power_use(a)])
			if lv < 3:
				add.call("Dienst", "Ausbau (mehr Punkte): gleiches Werkzeug, $%d" % (int(def["upgrade"]) * lv))
		elif def.has("renew"):
			var a := map.anchor[i]
			var lv := map.special_level(a)
			title = "%s  ·  Stufe %d" % [def["name"], lv]
			if not def.has("upgrade"):
				title = def["name"]
			match str(def["renew"]):
				"trees":
					summary = "Pflanzt %d Bäume/Monat im Umkreis von %d Tiles (bis %d%% Wald)" % [Config.NURSERY_TREES * lv,
						Config.NURSERY_RANGE, roundi(Config.NURSERY_MAX_SHARE * 100.0)]
					var got := int(sim.planted_at.get(a, -2))
					if got >= 0:
						add.call("Dienst", "Letzter Monat gepflanzt: %d Bäume" % got)
					elif got == -1:
						add.call("Dienst", "Pause: Umkreis zu %d%% bewaldet (pflanzt wieder, wenn gefällt wird)" %
							roundi(Config.NURSERY_MAX_SHARE * 100.0))
					if got == 0:
						problems.append("x Kein freies Gras im Umkreis - pflanzt nichts")
				"prospect":
					summary = "Sucht neue Adern im Umkreis von %d Tiles (%d%%/Monat)" % [Config.PROSPECT_RANGE,
						roundi(Config.PROSPECT_CHANCE * lv * 100.0)]
					add.call("Dienst", "Zuletzt gefunden: %s" % str(sim.last_found.get(a, "noch nichts")))
					add.call("Dienst", "Nur auf freien Hügeln (2+ über Wasser): Kohle, höher Eisen/Gold")
				"recycle":
					summary = "Einzugskreis %d Tiles: Abriss gibt %d%% statt %d%% zurück" % [sim.service_radius(a),
						roundi(Config.RECYCLE_SHARE_YARD * 100.0), roundi(Config.RECYCLE_SHARE * 100.0)]
					add.call("Dienst", "Instandhaltung im Kreis: %d %% zurück, höchstens %d je Monat (Stufe %d)" % [
						roundi(Config.RECYCLE_MAINT * 100.0), int(Config.RECYCLE_CAP[lv]), lv])
					add.call("Dienst", "Stadtweit zurückgeholt letzter Monat: %d" % roundi(sim.maint_recycled))
			if not sim.special_powered(i):
				problems.append("x Kein Strom - arbeitet nicht")
			add.call("Dienst", "Unterhalt $%d/Monat  ·  Strom %d MW" % [int(def["upkeep"] * Config.UPKEEP_LEVEL[lv]),
				sim.tile_power_use(a)])
			if lv < 3 and def.has("upgrade"):
				add.call("Dienst", "Ausbau (mehr Leistung): gleiches Werkzeug, $%d" % (int(def["upgrade"]) * lv))
		elif def.has("produce") or def.has("storage"):
			var a := map.anchor[i]
			var lv := map.special_level(a)
			title = "%s  ·  Stufe %d" % [def["name"], lv]
			if def.has("hall"):
				title = "Rathaus  ·  Stufe %d (%s)" % [sim.hall_level, Config.HALL_LEVELS[maxi(sim.hall_level, 1)]["name"]]
				summary = "Sitz des Bürgermeisters + Lagerhof  ·  Lager je Rohstoff: %s" % _fmt(sim.stock_capacity())
				var nx := sim.hall_next()
				if not nx.is_empty():
					add.call("Dienst", "Nächste Stufe %s: %s" % [nx["name"], "bereit - Rathaus-Fenster oben" if bool(nx["ok"])
						else "es fehlen " + ", ".join(nx["missing"])])
			elif def.has("storage"):
				summary = "Lager je Rohstoff: %s" % _fmt(sim.stock_capacity())
			else:
				var info: Dictionary = sim.producer_info.get(a, {})
				var out: Dictionary = info.get("out", {})
				var parts := PackedStringArray()
				for r: String in out:
					parts.append("+%d %s" % [int(out[r]), Config.RESOURCES[r]["name"]])
				summary = "Förderung: " + (", ".join(parts) if not parts.is_empty() else "keine") + " /Monat"
				if str(info.get("issue", "")) != "":
					problems.append("x " + str(info["issue"]))
			if not sim.special_powered(i):
				problems.append("x Kein Strom - steht still")
			add.call("Dienst", "Unterhalt $%d/Monat  ·  Strom %d MW" % [int(def["upkeep"] * Config.UPKEEP_LEVEL[lv]),
				sim.tile_power_use(a)])
			if lv < 3:
				add.call("Dienst", "Ausbau (mehr Förderung/Lager): gleiches Werkzeug, $%d" % (int(def["upgrade"]) * lv))
		else:
			summary = "Leistung %d MW  ·  Unterhalt $%d/Monat" % [def["power"], int(def["upkeep"])]
			if map.special[i] == Config.Special.COAL:
				var info: Dictionary = sim.producer_info.get(map.anchor[i], {})
				add.call("Dienst", "Verbraucht %d Kohle/Monat aus dem Lager" % Config.COAL_PLANT_USE)
				if str(info.get("issue", "")) != "":
					problems.append("x " + str(info["issue"]))
			var pnet := sim.power_net[i] if sim.power_net.size() > i else -1
			var nd: Dictionary = sim.power_nets[pnet] if pnet >= 0 and pnet < sim.power_nets.size() else {}
			match map.special[i]:
				Config.Special.BIOMASS:
					var info: Dictionary = sim.producer_info.get(map.anchor[i], {})
					add.call("Dienst", "Verbraucht %d Holz/Monat aus dem Lager (Tag und Nacht)" % Config.BIOMASS_WOOD_USE)
					add.call("Dienst", "Abgas: Verschmutzung im Umkreis")
					if str(info.get("issue", "")) != "":
						problems.append("x " + str(info["issue"]))
				Config.Special.SOLAR:
					summary = "Leistung tagsüber %d MW, nachts 0  ·  Unterhalt $%d/Monat" % [def["power"], int(def["upkeep"])]
				Config.Special.BATTERY, Config.Special.PUMPED, Config.Special.SALT:
					summary = "Speicher: liefert nachts bis %d MW  ·  Unterhalt $%d/Monat" % [int(def["storage_mw"]),
						int(def["upkeep"])]
					if not nd.is_empty():
						add.call("Dienst", "Im Netz: Speicher %d MW, nachts genutzt %d MW" % [int(nd["storage"]),
							int(nd["store_used"])])
						if int(nd["store_used"]) < int(nd["storage"]):
							add.call("Dienst", "Tagesüberschuss reicht nicht zum vollen Laden (mehr Solar/Wind)")
			if not nd.is_empty() and int(nd["day"]) != int(nd["night"]):
				add.call("Versorgung", "Netz: Tag %d MW  ·  Nacht %d MW  ·  Bedarf nachts %d MW" % [int(nd["day"]),
					int(nd["night"]), roundi(int(nd["demand"]) * Config.NIGHT_DEMAND)])
	elif map.zone[i] != Config.Zone.NONE:
		var zn := map.zone[i]
		var lv := map.level[i]
		title = "%s  ·  Stufe %d" % [Config.ZONE_NAMES[zn], lv]
		if zn == Config.Zone.IND and map.hightech[i] == 1:
			title = "Hightech-Industrie  ·  Stufe %d" % lv
		elif lv == 4:
			title = "%s  ·  Stufe 4" % ("Hochhaus" if zn == Config.Zone.RES else "Büroturm")
		if map.villa[i] == 1 and lv == 3:
			title = "Villa  ·  Bodenabgabe $%d" % int(Config.VILLA_LEVY)
		match zn:
			Config.Zone.RES:
				summary = "%d Einwohner" % roundi(map.residents(i))
				if sim.happiness.size() > i and lv > 0:
					summary += "  ·  Zufriedenheit %d%%" % roundi(sim.happiness[i] * 100.0)
			Config.Zone.COM:
				summary = "%d Jobs  ·  Kundschaft %d" % [roundi(map.jobs_at(i)), int(sim.customers[i]) if sim.customers.size() > i else 0]
			Config.Zone.IND:
				summary = "%d Jobs" % roundi(map.jobs_at(i))
		if lv > 0:
			var occ := map.occupancy(i)
			if map.is_vacant(i):
				title = "%s  ·  LEERSTAND" % Config.ZONE_NAMES[zn]
				var why := sim.decay_reason(i)
				problems.append("x Aufgegeben seit %d Monaten - Abriss in %d Monaten%s" % [map.vacant[i],
					maxi(Config.VACANT_MONTHS - map.vacant[i], 0), (": " + why) if why != "" else ""])
				problems.append("x Drückt die Zufriedenheit im Umkreis von %d Tiles" % Config.VACANT_RANGE)
			elif occ < 100:
				var trend := "sinkt" if map.worn[i] == 1 else "steigt"
				add.call("Gebäude", "Belegung: %d %% (%s)" % [occ, trend])
				if map.worn[i] == 1:
					problems.append("x Leute ziehen aus: Belegung %d %%" % occ)
			else:
				add.call("Gebäude", "Belegung: 100 %")
		# Gebäude
		var src := sim._src(i)
		if zn == Config.Zone.RES and src >= 0 and sim.tile_commute(i) > 0.0:
			add.call("Gebäude", "Arbeitsweg %d" % roundi(sim.tile_commute(i)))
		if sim.happiness.size() > i and zn == Config.Zone.RES and lv > 0:
			add.call("Gebäude", "Zufriedenheit %d%%  ·  Kriminalität %d%%" % [roundi(sim.happiness[i] * 100.0), roundi(sim.crime[i] * 100.0)])
		elif sim.crime.size() > i and lv > 0:
			add.call("Gebäude", "Kriminalität %d%%" % roundi(sim.crime[i] * 100.0))
		# Versorgung
		var use := sim.tile_power_use(i)
		if use > 0:
			add.call("Versorgung", "Verbrauch %d MW%s" % [use, "  - KEIN STROM" if sim.powered.size() > i and sim.powered[i] == 0 else ""])
		if zn == Config.Zone.RES and lv > 0:
			var miss := sim.missing_services(i)
			if not miss.is_empty():
				add.call("Versorgung", "Fehlt: " + ", ".join(miss))
		if lv > 0 and sim.population >= Config.FIRE_GRACE_POP and sim.coverage.has("fire"):
			var cov := minf((sim.coverage["fire"] as PackedFloat32Array)[i], 1.0)
			var note := fire_dept.protection_note(i)
			add.call("Versorgung", "Brandschutz %d%%%s" % [roundi(cov * 100.0), ("  - " + note) if note != "" else ""])
		if sim.has_transit(i):
			add.call("Versorgung", "Bus-/Bahnanschluss")
		# Lage
		if sim.land_mix.size() > i:
			match zn:
				Config.Zone.RES:
					var mix := sim.land_mix[i]
					if mix > 0.0:
						add.call("Lage", "Nahversorgung: Läden in %d Tiles (+%d%% Bodenwert)" % [Config.RES_SHOP_RANGE, roundi(mix * 100)])
					elif mix < 0.0:
						add.call("Lage", "Eintönig: kein Laden/Park/Wasser in %d Tiles (%d%%)" % [Config.RES_DULL_RANGE, roundi(mix * 100)])
					if sim.villa_site(i) and map.villa[i] == 0:
						add.call("Lage", "Villenlage: Stufe 3 wird eine Villa")
				Config.Zone.COM:
					add.call("Lage", "Ladenzeile: %d. Reihe, %d Tiles zur Kreuzung -> max. Stufe %d" % [
						sim.road_dist[i], sim.corner_dist(i), sim._max_level(i)])
				Config.Zone.IND:
					add.call("Lage", "Ballung: %d Industrie-Tiles ringsum -> Wachstum x%.1f, max. Stufe %d" % [
						int(sim.ind_cluster[i]), sim._cluster_factor(i), sim._max_level(i)])
		# Probleme und Wachstum
		if map.burning[i] > 0:
			problems.append("x BRAND %d%%  ·  %s" % [map.burning[i], fire_dept.status_text(i)])
		var blockers := sim.growth_blockers(i)
		if map.worn[i] == 1:
			problems.append("x Verfällt: %s" % sim.decay_reason(i))   # enthält schon den Hauptgrund
		else:
			for b in blockers:
				if b != "Keine Nachfrage":
					problems.append("x " + b)
		if lv >= 1 and lv < 3 and sim.population >= Config.MATERIAL_FROM_POP:
			var cost: Dictionary = Config.MATERIAL_COST[zn][lv + 1]
			var parts := PackedStringArray()
			for r: String in cost:
				parts.append("%d %s" % [int(cost[r]), Config.RESOURCES[r]["name"]])
			var need := sim.material_need(zn, lv + 1)
			add.call("Wachstum", "Stufe %d braucht: %s%s" % [lv + 1, ", ".join(parts),
				("  (fehlt, Zukauf $%d)" % int(need[1])) if float(need[1]) > 0.0 else "  (im Lager)"])
		if blockers.is_empty():
			add.call("Wachstum", "+ Kann wachsen" if lv < 3 else "Voll ausgebaut")
		else:
			for b in blockers:
				add.call("Wachstum", "x " + b)
	elif map.transit[i] == Config.Transit.STATION:
		title = "Bahnhof"
		var use := float(sim.station_use.get(i, 0.0))
		summary = "%d Ein-/Aussteiger (%d%%)" % [int(use), roundi(use / Config.STATION_CAPACITY * 100.0)]
		if use > Config.STATION_CAPACITY:
			problems.append("x Überfüllt - weiteren Bahnhof bauen")
		add.call("Verkehr", "Kapazität %d/Monat  ·  Bahn gesamt %d Fahrgäste" % [int(Config.STATION_CAPACITY), int(sim.rail_riders)])
	elif map.road[i] != 0:
		var wide := map.wide_partner(t.x, t.y) != Vector2i.ZERO
		title = "Hauptstraße (4 Spuren)" if wide else "Straße"
		if map.rail[i] != 0:
			title = "Bahnübergang"
		if map.transit[i] == Config.Transit.BUS_STOP:
			title = "Bushaltestelle"
			add.call("Verkehr", "Bus gesamt: %d Fahrgäste/Monat" % int(sim.bus_riders))
		if sim.traffic.size() > i:
			summary = "%d Pendler  ·  Auslastung %d%%" % [int(sim.traffic[i]), roundi(sim.congestion[i] * 100.0)]
			if sim.congestion[i] > 1.0:
				problems.append("x Stau")
	elif map.rail[i] != 0:
		title = "Gleis"
		if sim.rail_traffic.size() > i:
			summary = "%d Fahrgäste/Monat" % int(sim.rail_traffic[i])
	elif map.feature[i] == Config.Feature.PARK:
		title = "Park"
	elif map.feature[i] == Config.Feature.TREE:
		title = "Wald"
	# Bodenvorkommen
	if map.ore[i] != Config.Ore.NONE:
		var res: String = Config.ORE_RESOURCE[map.ore[i]]
		var line := "Vorkommen: %s %s" % [Config.RESOURCES[res]["name"], _fmt(map.ore_amt[i] * Config.ORE_UNIT)] if map.ore_amt[i] > 0 \
			else "Vorkommen: %s erschöpft" % Config.RESOURCES[res]["name"]
		if summary == "":
			summary = line
		else:
			add.call("Lage", line)
	# Netz, Umwelt, Ort (nur in den Details)
	if map.power_line[i] == 1:
		add.call("Versorgung", "Stromleitung")
	var pn := sim.power_net_text(i)
	if pn != "":
		add.call("Versorgung", pn)
		if "kein Kraftwerk" in pn or "Engpass" in pn:
			var short := "x Stromnetz: " + ("kein Kraftwerk" if "kein Kraftwerk" in pn else "Engpass")
			if not short in problems and not "x Kein Strom" in problems:
				problems.append(short)
	if sim.land_value.size() > i and not map.is_water(t.x, t.y):
		var gf := sim.green_filter[i] if sim.green_filter.size() > i else 0.0
		add.call("Lage", "Bodenwert %d%%  ·  Verschmutzung %.1f%s" % [roundi(sim.land_value[i] * 100.0), sim.pollution[i],
			("  (Grün filtert %d%%)" % roundi(gf * 100.0)) if gf > 0.0 else ""])
	add.call("Lage", "Tile %d, %d  ·  Höhe %d" % [t.x, t.y, map.height[i]])
	# Baustelle / Lager-Netz (Aufbau-Start)
	var ci := map.anchor[i] if map.special[i] != Config.Special.NONE and map.anchor[i] >= 0 else i
	var outside := sim.store_cover.size() > i and sim.store_cover[i] == 0
	if map.construct[ci] > 0:
		summary = "Baustelle: fertig in ~%d Monat(en)%s" % [ceili(map.construct[ci] * 0.5 * (Config.STORE_SLOW if outside else 1)),
			"" if not outside else " (langsam)"]
	if outside and (map.zone[i] != Config.Zone.NONE or map.special[i] != Config.Special.NONE):
		problems.append("x Kein Lager in Reichweite - Bauen dauert %dx so lange, Instandhaltung kommt schlecht an" % Config.STORE_SLOW)
	if map.anchor[i] >= 0 and map.special[i] != Config.Special.NONE:
		var sdef: Dictionary = Config.SPECIALS[map.special[i]]
		if sim.tech("deep_mining") and sdef.has("produce") and str(sdef["produce"]) != "wood":
			add.call("Forschung", "Tiefbau: +50 % Förderung")
		if sim.tech("plant_filter") and map.special[i] == Config.Special.COAL:
			add.call("Forschung", "Kraftwerksfilter: -50 % Verschmutzung")
		if sim.tech("blast_furnace") and sdef.has("process") and (sdef["process"]["in"] as Dictionary).has("coal"):
			add.call("Forschung", "Moderne Hochöfen: -50 % Kohle, -40 % Verschmutzung")
	_info_sections = []
	for name: String in ["Gebäude", "Dienst", "Forschung", "Verkehr", "Versorgung", "Lage", "Wachstum"]:
		if sec.has(name):
			_info_sections.append([name, sec[name]])
	_show_info(title, summary, problems)


## Info-Karte aufbauen: Titel, Kernzeile, roter Problemkasten; mit Details (Taste I) Abschnitte als Zeilen
## Bezeichnung | Wert (aus den Texten zerlegt, siehe _info_rows).
func _show_info(title: String, summary: String, problems: PackedStringArray) -> void:
	var uniq := PackedStringArray()
	for pr in problems:
		if not uniq.has(pr):
			uniq.append(pr)
	problems = uniq
	var sig := "%s|%s|%s|%s|%s" % [title, summary, problems, _info_sections, _info_detail]
	if sig == _info_sig:
		return
	_info_sig = sig
	info_text = " | ".join(PackedStringArray([title, summary]) + problems)
	for c in _info_col.get_children():
		_info_col.remove_child(c)
		c.queue_free()
	PopUI.label(_info_col, title, 18, UiTheme.TEXT, true, true)
	if summary != "":
		PopUI.label(_info_col, summary, 16, UiTheme.TEXT, false, true)
	PopUI.problems(_info_col, problems)
	if _info_detail:
		for sct: Array in _info_sections:
			var box := PopUI.section(_info_col, sct[0])
			for line: String in sct[1]:
				info_text += " | " + line
				_info_rows(box, line)
	if not _info_sections.is_empty():
		PopUI.note(_info_col, "[I] weniger" if _info_detail else "[I] Details")
	_info_card.reset_size()


## Eine Info-Zeile zerlegen: "A 5  ·  B: x" -> Zeilen (A | 5), (B | x); ohne Wert als Text.
func _info_rows(box: VBoxContainer, line: String) -> void:
	for part: String in line.split("  ·  "):
		part = part.strip_edges()
		var name := ""
		var value := ""
		var colon := part.find(": ")
		if colon > 0:
			name = part.substr(0, colon)
			value = part.substr(colon + 2)
		else:
			var m := _num_re.search(part)
			if m != null and m.get_start() > 0:
				name = part.substr(0, m.get_start()).strip_edges()
				value = part.substr(m.get_start()).strip_edges()
		if name == "" or value == "":
			PopUI.label(box, part, 15, UiTheme.TEXT, false, true)
		else:
			var col := UiTheme.TEXT
			if value.begins_with("-") or value.contains("überlastet") or value.begins_with("x "):
				col = UiTheme.BAD
			PopUI.row(box, name, value, col)


func toggle_info_detail() -> void:
	_info_detail = not _info_detail
	_on_hover(tools.hover)


func _hud_hidden() -> bool:
	return not _hud_parts.is_empty() and not _hud_parts[0].visible


## H: HUD aus-/einblenden (Werkzeugleiste bleibt).
func toggle_hud() -> void:
	var show := _hud_hidden()
	for c in _hud_parts:
		c.visible = show
	_close_popup()
	_info_card.visible = show and tools.hover.x >= 0
	show_message("HUD eingeblendet" if show else "HUD ausgeblendet [H]")


func _on_cost(cost: int, valid: bool) -> void:
	_cost.text = ("$ %s" % _fmt(cost)) if cost > 0 else ""
	if tools.preview_site != "":
		_cost.text = tools.preview_site          # Standortregel nicht erfüllt -> Grund statt Preis
		_cost.add_theme_color_override("font_color", UiTheme.BAD)
		return
	if tools.preview_convert:
		_cost.text += "\nUmrüsten: Kohlekraftwerk -> Salzspeicher\nAchtung: %d MW Kohlestrom fallen weg (Speicher erzeugt nichts)" % int(
			Config.SPECIALS[Config.Special.COAL]["power"])
	var mats: Dictionary = tools.preview_materials
	if cost > 0 and not mats.is_empty():
		var parts := PackedStringArray()
		for r: String in mats:
			var short := float(tools.preview_missing.get(r, 0.0))
			parts.append("%d %s%s" % [ceili(float(mats[r])), Config.RESOURCES[r]["name"],
				" (%d fehlt)" % ceili(short) if short > 0.0 else ""])
		_cost.text += "\n" + ", ".join(parts)
		if tools.preview_import > 0.0:
			_cost.text += "\ndavon Zukauf $%s" % _fmt(int(tools.preview_import))
		if sim.build_factor() < 1.0:
			_cost.text += "\n-%d %% Material (Effiziente Bauweise)" % roundi((1.0 - sim.build_factor()) * 100.0)
	_cost.add_theme_color_override("font_color", UiTheme.TEXT if valid else UiTheme.BAD)


func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
