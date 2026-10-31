class_name Simulation
extends Node
## Monatliche Stadtsimulation: Strom, Nachfrage (RCI), Wachstum, Budget.

signal stats_changed
signal power_changed
signal traffic_changed
signal message(text: String)
signal alert(text: String, tile: Vector2i)   # Meldung mit Ort (Klick/Tab springt hin)
signal research_finished(id: String)          # Projekt abgeschlossen -> HUD zeigt Durchbruch-Karte

const SECONDS_PER_MONTH := [0.0, 8.0, 4.0, 1.5]    # vorher 3/1,5/0,5: 40 Spieljahre waren 24 bzw. 4 Minuten
const MONTH_NAMES := ["Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"]

var map: CityMap
var money: float = Config.START_MONEY
var month := 0
var year := Config.START_YEAR
var tax := [0.0, 0.09, 0.09, 0.12]   # Steuersatz je Zone (Index = Config.Zone), Startwerte = neutral
var fare := 1                       # ÖPNV-Tarif (Config.FARE_*)
var income_parts := {}              # Einnahmen je Quelle (Wohnen, Gewerbe, Industrie, ÖPNV)
var speed := 1

var population := 0
var jobs_com := 0
var jobs_ind := 0
var road_count := 0
var park_count := 0
var line_count := 0
var rail_count := 0
var bus_stop_count := 0
var station_count := 0
var special_upkeep := 0.0
var power_supply := 0
var power_demand := 0              # Bedarf aller Gebäude, auch nicht angeschlossener
var power_served := 0              # davon tatsächlich geliefert
var power_net: PackedInt32Array    # Netz-Nummer je Tile (-1 = leitet nicht)
var power_nets: Array = []         # je Netz: capacity, demand, plants, unserved, dark (Tile ohne Strom), key
var demand_res := 0.0
var demand_com := 0.0
var demand_ind := 0.0
var last_income := 0.0
var last_expense := 0.0

var road_dist: PackedInt32Array     # Abstand zur nächsten Straße (Tiles), 99 = keine
var road_src: PackedInt32Array      # Index des nächsten Straßen-Tiles, -1 = keins
var powered: PackedByteArray        # 1 = Tile hat Strom

# Pendelverkehr
const WORK_SHARE := 0.55            # Anteil Einwohner, die pendeln
const MAX_HOPS := 80                # max. Weglänge in Tiles (Stau verlängert nicht die Reichweite)
const LONG_COMMUTE := 40.0          # Fahrzeit, ab der Wohnwachstum stoppt
const ASSIGN_ROUNDS := 3            # Pendler in Etappen verteilen (incremental assignment)
const CONGESTION_COST := 2.0        # Wegkosten-Faktor: 1 + k * Auslastung^2
var traffic: PackedFloat32Array     # Pendler pro Straßen-Tile
var congestion: PackedFloat32Array  # Auslastung, 1.0 = Kapazität
var commute_cost: PackedFloat32Array  # Ø Wegkosten der Pendler je Quell-Straßen-Tile
var road_comp: PackedInt32Array     # Netz-Komponente je Straßen-Tile
var comp_has_res := {}
var comp_has_job := {}
var avg_congestion := 0.0

# Dienste, Zufriedenheit, Kriminalität
var coverage := {}                  # Kategorie -> PackedFloat32Array (0..1 Versorgung je Tile)
var crime: PackedFloat32Array       # 0..1
var happiness: PackedFloat32Array   # 0..1 (nur bebaute Wohn-Tiles)
var city_happiness := 0.6           # einwohnergewichteter Durchschnitt
var city_coverage := {}             # Kategorie -> Anteil versorgter Einwohner
var service_load := {}              # Anker-Tile -> Auslastung (Einwohner / Kapazität)
var unemployment := 0.0
var fires_total := 0               # Brandausbrüche (Statistik/Tests)
var _needs_announced := {}
var venue_event := {}               # Anker Theater/Stadion -> Besucher der Veranstaltung diesen Monat (0 = keine)
var venue_jam := {}                 # Anker -> Ø Auslastung der Straßen rundum (nach Pendlern)
var _jam_warned := 0                # Monate bis zur nächsten Stau-Meldung am Stadion
var stock := {}                     # Rohstoff -> Menge im Lager
var production := {}                # Rohstoff -> Förderung im letzten Monat
var exported := {}                  # Rohstoff -> exportierte Menge im letzten Monat (Lager voll)
var export_income := 0.0
var last_materials := {}            # beim Wachsen verbaut (letzter Monat)
var producer_info := {}
var _ore_used := {}
var _delivery_warned := {}
# Forschung
var research_done: Array[String] = []
var research_current := ""          # laufendes Projekt (Config.RESEARCH-Schlüssel) oder ""
var research_progress := 0.0        # gesammelte Punkte des laufenden Projekts
var research_budget := 0.0          # eingestelltes Budget $/Monat (Config.RESEARCH_BUDGET_STEPS)
var research_rate := 0.0            # Punkte im letzten Monat
var _inst_levels := 0
var research_spent := 0.0           # Forschungsausgaben im letzten Monat
var traffic_control := false        # Forschung Verkehrsleitsystem (Kopie für den Pendler-Worker, s. COMMUTE_IN)
var jobs_hightech := 0              # davon Hightech-Jobs (höhere Steuer)
var last_maint := {}                # Instandhaltung: Bedarf je Material im letzten Monat
var maint_recycled := 0.0           # davon von Recyclinghöfen zurückgeholt (Einheiten)
var maint_short := 0.0              # Anteil Instandhaltung, der mangels Geld ausblieb (0..1) -> Verfall
var store_cover := PackedByteArray()   # Lager-Netz: 1 = Tile im Einzugskreis eines Lagers (Aufbau-Start)
var game_mode := "classic"          # "classic" (Startkapital, alles nach Einwohnern) | "build" (Aufbau-Start, Rathaus-Stufen)
var hall_level := 0                 # Rathaus-Stufe (nur Aufbau-Start; 0 = klassisch)
var interest_cost := 0.0            # Schuldzinsen im letzten Monat
var admin_cost := 0.0               # Verwaltungskosten im letzten Monat
var build_imports := 0.0           # Sofort-Zukauf von Baumaterial beim Bauen (Summe seit Spielstart, nicht gespeichert)
var planted := 0                    # Bäume, die Baumschulen im letzten Monat gepflanzt haben
var planted_at := {}                # Baumschul-Anker -> gepflanzte Bäume im letzten Monat (nicht gespeichert)
var last_found := {}                # Prospektor-Anker -> zuletzt gefundene Ader (Text)
var local_buffer := {}              # Anker -> {Rohstoff: Menge}: Vorrat von Abbau ohne Straße zum Lager
var _road_net := PackedInt32Array() # Straßen-Tile -> Netz-Nummer (für Lieferwege)
var _store_nets := {}               # Netz-Nummern mit Lager (bzw. Hauptnetz der Stadt)
var coal_burned := 0.0             # Kraftwerkskohle aus dem eigenen Lager (letzter Monat)
var imported := {}                  # Rohstoff -> zugekaufte Menge (Kraftwerkskohle, Baustoffe)
var materials_used := {}            # Rohstoff -> beim Wachsen verbaut (laufender Monat)
var import_cost := 0.0              # Zukauf im letzten Monat ($)
var _import_pending := 0.0          # Zukauf im laufenden Monat, wird im Budget abgebucht                 # Tile -> schon entnommene Einheiten unter einem Vorkommen-Punkt             # Anker -> {"out": {Rohstoff: Menge}, "issue": Text}
var happy_parts := {}               # Anteil an der Zufriedenheit (Punkte 0..1, einwohnergewichtet): Name -> Wert
var _happy_hist: Array = []         # letzte Monate: [city_happiness, happy_parts]
var _happy_alert_cool := 0          # Monate bis zur nächsten Zufriedenheits-Warnung
var _ipop := PackedFloat32Array()   # Integralbild Einwohner (aus _compute_environment)
var _ijobs := PackedFloat32Array()  # Integralbild Arbeitsplätze (Feuerwehr-Auslastung)

# Öffentlicher Verkehr
var bus_served: PackedByteArray     # 1 = Straßen-Tile im Einzugsbereich einer Haltestelle
var rail_traffic: PackedFloat32Array  # Fahrgäste je Gleis-Tile
var station_use := {}               # Bahnhof-Tile -> Ein-/Aussteiger
var bus_riders := 0.0
var rail_riders := 0.0
var transit_share := 0.0            # Anteil Pendler mit Bus/Bahn
var car_trips := 0.0                # Pendler, die Auto fahren (für die sichtbaren Autos)
var _transit_trips := 0.0           # Pendler mit Bus und/oder Bahn (je Pendler einmal)
var _station_links := {}            # Gleis-Tile -> [[Straßen-Tile, Kosten], ...]
var _road_station_links := {}       # Straßen-Tile -> [[Gleis-Knoten n+i, Kosten], ...]
var _dist := PackedFloat32Array()
var _visit := PackedInt32Array()     # Lauf-Nummer je Knoten (statt Neu-Initialisierung)
var _parent := PackedInt32Array()
var _hops := PackedInt32Array()
var _via_rail := PackedByteArray()
var avg_commute := 0.0
var unreachable_workers := 0

# Umwelt / Standort
var pollution: PackedFloat32Array   # 0.. (Punkte)
var land_value: PackedFloat32Array  # 0..1
var customers: PackedFloat32Array   # Einwohner im Umkreis (für Gewerbe)
var res_nearby: PackedFloat32Array  # Einwohner im Umkreis 4 (Industrie-Abstand)
var parks_near: PackedFloat32Array  # Parks im Umkreis 3 (Zufriedenheit)
var res_cluster: PackedFloat32Array # Wohn-Zonen im 5x5 ringsum (ohne eigenes) -> Kleinsiedlung/Villa
var junction_dist: PackedInt32Array # Straßen-Tile: Weg entlang der Straße zur nächsten Kreuzung/Ecke/Ende
var villa_count := 0
var ind_cluster: PackedFloat32Array # Industrie-Tiles im 5x5 ringsum (ohne eigenes) -> Ballung
var land_mix: PackedFloat32Array    # Bodenwert-Anteil aus Nachbarschaft: + Nahversorgung / - eintönig
var green_filter: PackedFloat32Array  # Anteil der Verschmutzung, den Grün im Umkreis wegfiltert (0..GREEN_FILTER_MAX)
var _acc := 0.0
var _ticking := false               # Monat läuft gerade (über mehrere Frames)

# Pendler im Hintergrund: zweite Simulation rechnet auf einer Kartenkopie, Ergebnis wird übernommen
var async_commute := false          # im laufenden Spiel true (main.gd); Tests rechnen synchron
var _worker: Simulation = null
var _commute_task := -1
var _commute_again := false         # während der Berechnung geändert -> danach nochmal
var _commute_discard := false       # Karte ersetzt (Laden/Neu) -> laufendes Ergebnis verwerfen
const COMMUTE_IN := ["congestion", "road_dist", "road_src", "fare", "month", "year", "station_use", "powered", "traffic_control"]
const COMMUTE_OUT := ["traffic", "congestion", "commute_cost", "road_comp", "comp_has_res", "comp_has_job",
	"bus_served", "_station_links", "_road_station_links", "rail_traffic", "station_use", "bus_riders",
	"rail_riders", "_transit_trips", "avg_commute", "transit_share", "unreachable_workers", "avg_congestion",
	"venue_event", "venue_jam", "car_trips"]
var _rng := RandomNumberGenerator.new()
var _power_warned := {}            # Netz-Probleme, die schon gemeldet wurden

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


func setup(city_map: CityMap) -> void:
	map = city_map
	_rng.randomize()
	refresh()


func _process(delta: float) -> void:
	_poll_commute()
	if speed == 0:
		return
	if _ticking:
		return
	_acc += delta
	if _acc >= SECONDS_PER_MONTH[speed]:
		_acc = 0.0
		_tick_spread()


func to_dict() -> Dictionary:
	var buffers := {}
	for a: int in local_buffer:
		buffers[str(a)] = local_buffer[a]
	return {"money": money, "month": month, "year": year, "tax": tax, "fare": fare, "congestion": congestion,
		"stock": stock, "buffers": buffers, "game_mode": game_mode, "hall_level": hall_level,
		"research": {"done": research_done, "current": research_current, "progress": research_progress,
			"budget": research_budget}}


func from_dict(d: Dictionary) -> void:
	money = d.get("money", Config.START_MONEY)
	month = d.get("month", 0)
	year = d.get("year", Config.START_YEAR)
	tax = (Config.TAX_NEUTRAL as Array).duplicate()
	if d.has("tax"):
		tax = (d["tax"] as Array).duplicate()
	elif d.has("tax_rate"):
		# Alte Spielstände: ein Satz für alle -> Wohnen/Gewerbe übernehmen, Industrie neutral
		tax[Config.Zone.RES] = d["tax_rate"]
		tax[Config.Zone.COM] = d["tax_rate"]
	fare = d.get("fare", 1)
	game_mode = str(d.get("game_mode", "classic"))
	hall_level = int(d.get("hall_level", 0))
	var rs: Dictionary = d.get("research", {})
	research_done.clear()
	for id: String in (rs.get("done", []) as Array):
		if Config.RESEARCH.has(id):
			research_done.append(id)
	research_current = str(rs.get("current", ""))
	if not Config.RESEARCH.has(research_current):
		research_current = ""
	research_progress = float(rs.get("progress", 0.0))
	research_budget = float(rs.get("budget", 0.0))
	research_rate = 0.0
	research_spent = 0.0
	local_buffer = {}
	for k: String in (d.get("buffers", {}) as Dictionary):
		local_buffer[int(k)] = d["buffers"][k]
	stock = {}
	for r: String in Config.RESOURCES:
		stock[r] = float((d.get("stock", {}) as Dictionary).get(r, 0.0))
	congestion = d.get("congestion", PackedFloat32Array())
	if congestion.size() != map.size * map.size:
		congestion = PackedFloat32Array()     # z.B. alter kleinerer Spielstand, in größere Karte eingebettet
	last_income = 0.0
	last_expense = 0.0
	_acc = 0.0
	if _commute_task != -1:
		_commute_discard = true     # Ergebnis gehört zur alten Karte
	_happy_hist.clear()
	refresh()


func reset() -> void:
	from_dict({})


func date_string() -> String:
	return "%s %d" % [MONTH_NAMES[month], year]


func can_afford(cost: float) -> bool:
	return money >= cost


func spend(cost: float) -> void:
	money -= cost
	stats_changed.emit()


## Abgeleitete Daten sofort neu berechnen (z.B. nach Bauaktionen).
## staged = true (Bau-Klick im Spiel): Netz/Strom sofort, Umwelt und Dienste in den nächsten Frames.
func refresh(staged := false) -> void:
	var t := Perf.begin()
	_compute_road_distance()
	_compute_junctions()
	_compute_power()
	if game_mode == "build":
		_compute_store_cover()
	Perf.end("sim.strassen+strom", t)
	t = Perf.begin()
	_request_commute()
	Perf.end("sim.pendler", t)
	if staged and is_inside_tree():
		_recount()
		_update_demand()
		stats_changed.emit()
		_refresh_rest()
		return
	t = Perf.begin()
	_compute_environment()
	_recount()
	_compute_services()
	_update_demand()
	Perf.end("sim.umwelt+dienste", t)
	t = Perf.begin()
	stats_changed.emit()
	Perf.end("sim.signal_stats", t)


var _refresh_token := 0


## Rest einer gestaffelten Neuberechnung; nur der jeweils letzte Aufruf läuft zu Ende.
func _refresh_rest() -> void:
	_refresh_token += 1
	var token := _refresh_token
	await get_tree().process_frame
	if token != _refresh_token:
		return
	var t := Perf.begin()
	_env_begin()
	_env_rows(0, map.size / 2)
	Perf.end("sim.umwelt", t)
	await get_tree().process_frame
	if token != _refresh_token:
		return
	t = Perf.begin()
	_env_rows(map.size / 2, map.size)
	_env_end()
	_recount()
	Perf.end("sim.umwelt2", t)
	await get_tree().process_frame
	if token != _refresh_token:
		return
	t = Perf.begin()
	_compute_services()
	_update_demand()
	stats_changed.emit()
	Perf.end("sim.dienste", t)


## Ein Monat in einem Rutsch (Tests, Demo-Aufbau).
func tick_month() -> void:
	for stage in TICK_STAGES:
		_tick_stage(stage)


## Ein Monat verteilt auf mehrere Frames, damit kein einzelner Frame ruckelt.
func _tick_spread() -> void:
	_ticking = true
	for stage in TICK_STAGES:
		_tick_stage(stage)
		if stage != TICK_STAGES[-1]:
			await get_tree().process_frame
	_ticking = false


## Etappen eines Monats, je Frame eine (im Spiel); teure Teile (Umwelt, Wachstum) zeilenweise halbiert.
## Pendler laufen im Hintergrund-Thread. Nach dem Wachstum: Strom, Zählung, Nachfrage, Budget.
const TICK_STAGES := ["netz", "strom", "pendler", "umwelt", "umwelt2", "zaehlen", "dienste", "wachsen", "wachsen2",
	"strom2", "abschluss"]


func _tick_stage(stage: String) -> void:
	var t := Perf.begin()
	var half := map.size / 2
	match stage:
		"netz":
			_timed("sim.n.strassenabstand", _compute_road_distance)
			_timed("sim.n.kreuzungen", _compute_junctions)
		"strom":
			_compute_power()
		"pendler":
			_request_commute()
		"umwelt":
			_env_begin()
			_env_rows(0, half)
		"umwelt2":
			_env_rows(half, map.size)
			_env_end()
		"zaehlen":
			_recount()
		"dienste":
			_compute_services()
			_update_demand()
			_check_happiness()
		"wachsen":
			_fires()
			_grow_rows(0, half)
		"wachsen2":
			_grow_rows(half, map.size)
			_grow_finish()
		"strom2":
			_compute_power()
		"abschluss":
			_advance_construction()
			_recount()
			_update_demand()
			_renew()
			_produce()
			_process_goods()
			_maintenance()
			_export_surplus()
			_research()
			_budget()
			month += 1
			if month >= 12:
				month = 0
				year += 1
			stats_changed.emit()
	Perf.end("sim." + stage, t)


func _timed(label: String, f: Callable) -> void:
	var t := Perf.begin()
	f.call()
	Perf.end(label, t)


func _compute_road_distance() -> void:
	# Multi-Source-BFS von allen Straßen-Tiles (lokale Packed-Arrays: in GDScript deutlich schneller)
	var size := map.size
	var n := size * size
	var road := map.road
	var dist := PackedInt32Array()
	dist.resize(n)
	dist.fill(99)
	var src := PackedInt32Array()
	src.resize(n)
	src.fill(-1)
	var queue := PackedInt32Array()
	for i in n:
		if road[i] != 0:
			dist[i] = 0
			src[i] = i
			queue.append(i)
	var limit := Config.ROAD_ACCESS_RANGE
	var head := 0
	while head < queue.size():
		var u := queue[head]
		head += 1
		var d := dist[u]
		if d >= limit:
			continue
		var x := u % size
		var z := u / size
		# Reihenfolge wie DIRS: +x, -x, +z, -z
		if x + 1 < size and dist[u + 1] > d + 1:
			dist[u + 1] = d + 1
			src[u + 1] = src[u]
			queue.append(u + 1)
		if x > 0 and dist[u - 1] > d + 1:
			dist[u - 1] = d + 1
			src[u - 1] = src[u]
			queue.append(u - 1)
		if z + 1 < size and dist[u + size] > d + 1:
			dist[u + size] = d + 1
			src[u + size] = src[u]
			queue.append(u + size)
		if z > 0 and dist[u - size] > d + 1:
			dist[u - size] = d + 1
			src[u - size] = src[u]
			queue.append(u - size)
	road_dist = dist
	road_src = src


## Pendler berechnen: synchron (Tests) oder im Hintergrund-Thread (Spiel). Die Berechnung ist bei großen
## Städten der mit Abstand teuerste Teil (Sekunden) und würde sonst bei jedem Bau-Klick/Monat einfrieren.
func _request_commute() -> void:
	if not async_commute:
		_compute_commute()
		return
	if _commute_task != -1:
		_commute_again = true
		return
	if _worker == null:
		_worker = Simulation.new()
		_worker.map = CityMap.new(map.size)
	for f: String in CityMap.SAVE_FIELDS:
		_worker.map.set(f, (map.get(f) as Variant).duplicate())
	_worker.map._wide_dirty = true
	for f: String in COMMUTE_IN:
		var v: Variant = get(f)
		_worker.set(f, v.duplicate() if v is PackedFloat32Array or v is PackedInt32Array else v)
	_commute_task = WorkerThreadPool.add_task(_worker._compute_commute, true, "Pendler")


## Fertiges Hintergrund-Ergebnis übernehmen (Hauptthread).
func _poll_commute() -> void:
	if _commute_task == -1 or not WorkerThreadPool.is_task_completed(_commute_task):
		return
	var t := Perf.begin()
	WorkerThreadPool.wait_for_task_completion(_commute_task)
	_commute_task = -1
	if _commute_discard:
		_commute_discard = false
	else:
		for f: String in COMMUTE_OUT:
			var v: Variant = _worker.get(f)
			set(f, v.duplicate() if v is Dictionary or v is PackedFloat32Array or v is PackedInt32Array
				or v is PackedByteArray else v)
		Perf.end("sim.pendler_uebernehmen", t)
		t = Perf.begin()
		traffic_changed.emit()
		Perf.end("signal.verkehr_geaendert", t)
		t = Perf.begin()
		stats_changed.emit()
		Perf.end("signal.werte_geaendert", t)
	if _commute_again:
		_commute_again = false
		_request_commute()


func _exit_tree() -> void:
	if _commute_task != -1:
		WorkerThreadPool.wait_for_task_completion(_commute_task)
	if _worker != null:
		_worker.free()


## Weg entlang der Straße zur nächsten Kreuzung, Ecke oder zum Straßenende (BFS über Straßen).
## Hauptstraßen-Partner zählt nicht als Abzweig.
func _compute_junctions() -> void:
	var size := map.size
	var n := size * size
	var road := map.road
	var height := map.height
	if map._wide_dirty:
		map._compute_wide()
	var wide := map._wide
	# Nachbarn je Straßen-Tile als Bitmaske (1 +x, 2 -x, 4 +z, 8 -z), verbunden = Straße + max. 1 Block Höhe
	var mask := PackedByteArray()
	mask.resize(n)
	for i in n:
		if road[i] == 0:
			continue
		var x := i % size
		var z := i / size
		var h := height[i]
		var m := 0
		if x + 1 < size and road[i + 1] != 0 and absi(height[i + 1] - h) <= 1: m |= 1
		if x > 0 and road[i - 1] != 0 and absi(height[i - 1] - h) <= 1: m |= 2
		if z + 1 < size and road[i + size] != 0 and absi(height[i + size] - h) <= 1: m |= 4
		if z > 0 and road[i - size] != 0 and absi(height[i - size] - h) <= 1: m |= 8
		mask[i] = m
	var jd := PackedInt32Array()
	jd.resize(n)
	jd.fill(99)
	var queue := PackedInt32Array()
	const PARTNER_BIT := [0, 1, 2, 4, 8]     # _wide-Code (WIDE_DIRS) -> Bit des Partner-Nachbarn
	for i in n:
		if road[i] == 0:
			continue
		var m: int = mask[i] & ~int(PARTNER_BIT[wide[i]])
		# gerade Strecke = genau zwei gegenüberliegende Nachbarn
		if m != 3 and m != 12:
			jd[i] = 0
			queue.append(i)
	var head := 0
	while head < queue.size():
		var u := queue[head]
		head += 1
		var m := mask[u]
		var d := jd[u] + 1
		if m & 1 and jd[u + 1] > d:
			jd[u + 1] = d
			queue.append(u + 1)
		if m & 2 and jd[u - 1] > d:
			jd[u - 1] = d
			queue.append(u - 1)
		if m & 4 and jd[u + size] > d:
			jd[u + size] = d
			queue.append(u + size)
		if m & 8 and jd[u - size] > d:
			jd[u - size] = d
			queue.append(u - size)
	junction_dist = jd


## Pendler: Arbeitskräfte je Straßen-Anschluss werden in ASSIGN_ROUNDS Etappen
## per Dijkstra zum nächsten freien Job geschickt. Jede Etappe sieht den Verkehr der
## vorherigen -> Parallelrouten und Hauptstraßen werden genutzt, sobald es sich lohnt.
func _compute_commute() -> void:
	var n := map.size * map.size
	traffic.resize(n)
	traffic.fill(0.0)
	var prev := congestion.duplicate()
	if prev.size() != n:
		prev.resize(n)
		prev.fill(0.0)
	congestion.resize(n)
	commute_cost.resize(n)
	commute_cost.fill(0.0)

	# Netz-Komponenten
	road_comp.resize(n)
	road_comp.fill(-1)
	var comps := 0
	for i in n:
		if map.road[i] == 0 or road_comp[i] != -1:
			continue
		var stack: Array[int] = [i]
		road_comp[i] = comps
		while not stack.is_empty():
			var u: int = stack.pop_back()
			for v in _road_neighbors(u):
				if road_comp[v] == -1:
					road_comp[v] = comps
					stack.append(v)
		comps += 1

	_build_transit_links(comps)

	# Kapazität und Tempo je Straßen-Tile
	var cap := PackedFloat32Array()
	cap.resize(n)
	var inv_speed := PackedFloat32Array()
	inv_speed.resize(n)
	for i in n:
		if map.road[i] != 0:
			var wide := map.wide_partner(i % map.size, i / map.size) != Vector2i.ZERO
			cap[i] = (Config.WIDE_CAPACITY if wide else Config.STREET_CAPACITY) / (Config.TRAFFIC_CONTROL if traffic_control else 1.0)
			inv_speed[i] = 1.0 / (Config.WIDE_SPEED if wide else Config.STREET_SPEED)

	# Arbeitskräfte und Jobs je Straßen-Anschluss sammeln
	comp_has_res = {}
	comp_has_job = {}
	var workers := {}
	var jobs_left := PackedFloat32Array()
	jobs_left.resize(n)
	for i in n:
		var zn := map.zone[i]
		if zn == Config.Zone.NONE or road_dist[i] > Config.ROAD_ACCESS_RANGE:
			continue
		# Grundstück nutzt alle Straßen in Reichweite, nähere stärker gewichtet
		var acc := _access(i)
		var lv := map.level[i]
		var amount := 0.0
		if zn == Config.Zone.RES:
			amount = map.residents(i) * WORK_SHARE
		else:
			amount = map.jobs_at(i)
		for k in range(0, acc.size(), 2):
			var r := int(acc[k])
			var share := acc[k + 1]
			if zn == Config.Zone.RES:
				comp_has_res[road_comp[r]] = true
				if amount > 0.0:
					workers[r] = workers.get(r, 0.0) + amount * share
			else:
				comp_has_job[road_comp[r]] = true
				jobs_left[r] += amount * share

	# Knoten: 0..n-1 Straßen-Tiles, n..2n-1 Gleis-Tiles
	_dist.resize(2 * n)
	_visit.resize(2 * n)
	_visit.fill(0)
	_parent.resize(2 * n)
	_hops.resize(2 * n)
	_via_rail.resize(2 * n)
	rail_traffic.resize(n)
	rail_traffic.fill(0.0)
	var prev_station := station_use     # Vormonat: Überfüllung wirkt schon in der ersten Etappe
	station_use = {}
	bus_riders = 0.0
	_transit_trips = 0.0
	rail_riders = 0.0
	var sources: Array = workers.keys()
	var src_cost := {}
	var src_assigned := {}
	var run := 0
	var unreachable := 0.0
	# Nachbarn einmal vorberechnen (4 Plätze je Knoten, -1 = leer): keine Allokation in der Suche
	var adj := PackedInt32Array()
	adj.resize(8 * n)
	adj.fill(-1)
	for i in n:
		var x := i % map.size
		var z := i / map.size
		var k := 0
		var kr := 0
		for d: Vector2i in DIRS:
			if map.roads_connected(x, z, x + d.x, z + d.y):
				adj[i * 4 + k] = map.idx(x + d.x, z + d.y)
				k += 1
			if map.rails_connected(x, z, x + d.x, z + d.y):
				adj[(n + i) * 4 + kr] = n + map.idx(x + d.x, z + d.y)
				kr += 1
	var jobs_total := 0.0
	for i in n:
		jobs_total += jobs_left[i]
	# Dijkstra mit Heap direkt in Packed-Arrays (lazy deletion), lokale Referenzen für Tempo
	var dist := _dist
	var visit := _visit
	var hops := _hops
	# _parent/_via_rail als Member: _record_trip liest sie (lokaler Alias würde beim Schreiben kopieren)
	var hp := PackedFloat32Array()
	var hv := PackedInt32Array()
	hp.resize(16 * n)
	hv.resize(16 * n)
	var cv := PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	var cd := PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	var ch := PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
	for round_i in ASSIGN_ROUNDS:
		sources.shuffle()
		for s: int in sources:
			var w: float = workers[s] / ASSIGN_ROUNDS
			if jobs_total <= 0.001:
				unreachable += w        # nirgends mehr freie Jobs -> Suche sparen
				continue
			run += 1
			dist[s] = 0.0
			visit[s] = run
			_parent[s] = -1
			hops[s] = 0
			_via_rail[s] = 0
			var hn := 1
			hp[0] = 0.0
			hv[0] = s
			while hn > 0 and w > 0.001:
				var d := hp[0]
				var u := hv[0]
				# pop
				hn -= 1
				hp[0] = hp[hn]
				hv[0] = hv[hn]
				var pi := 0
				while true:
					var l := pi * 2 + 1
					if l >= hn:
						break
					var m := l
					if l + 1 < hn and hp[l + 1] < hp[l]:
						m = l + 1
					if hp[m] >= hp[pi]:
						break
					var tp := hp[pi]
					hp[pi] = hp[m]
					hp[m] = tp
					var tv := hv[pi]
					hv[pi] = hv[m]
					hv[m] = tv
					pi = m
				if d > dist[u]:
					continue
				if u < n and jobs_left[u] > 0.0:
					var take := minf(w, jobs_left[u])
					jobs_left[u] -= take
					jobs_total -= take
					w -= take
					src_assigned[s] = src_assigned.get(s, 0.0) + take
					src_cost[s] = src_cost.get(s, 0.0) + take * d
					_record_trip(u, s, take)
				if hops[u] >= MAX_HOPS:
					continue
				# Kandidaten sammeln: [Knoten, Kosten, Hop-Zuwachs]
				var cn := 0
				if u < n:
					for k in 4:
						var v := adj[u * 4 + k]
						if v < 0:
							break
						# Auslastung: aktueller Verkehr + etwas Erinnerung an den Vormonat
						var ratio := minf(traffic[v] / cap[v] + prev[v] * 0.3, 4.0)
						cv[cn] = v
						cd[cn] = d + inv_speed[v] * (1.0 + CONGESTION_COST * ratio * ratio)
						ch[cn] = 1
						cn += 1
					if _road_station_links.has(u):
						for lk: Array in _road_station_links[u]:
							var cc := _crowd_cost(int(lk[0]) - n, prev_station)
							if cc == INF:
								continue
							if cn >= cv.size():
								cv.resize(cn * 2)
								cd.resize(cn * 2)
								ch.resize(cn * 2)
							cv[cn] = lk[0]
							cd[cn] = d + float(lk[1]) + cc
							ch[cn] = 0
							cn += 1
				else:
					for k in 4:
						var v := adj[u * 4 + k]
						if v < 0:
							break
						var r := rail_traffic[v - n] / Config.RAIL_CAPACITY
						cv[cn] = v
						cd[cn] = d + Config.RAIL_COST * (1.0 + r * r)
						ch[cn] = 0
						cn += 1
					var t := u - n
					if _station_links.has(t):
						var crowd := _crowd_cost(t, prev_station)
						for lk: Array in (_station_links[t] if crowd != INF else []):
							if cn >= cv.size():
								cv.resize(cn * 2)
								cd.resize(cn * 2)
								ch.resize(cn * 2)
							cv[cn] = lk[0]
							cd[cn] = d + float(lk[1]) + crowd
							ch[cn] = 0
							cn += 1
				# relax + push
				for c in cn:
					var v := cv[c]
					var nd := cd[c]
					if visit[v] == run and nd >= dist[v]:
						continue
					visit[v] = run
					dist[v] = nd
					_parent[v] = u
					hops[v] = hops[u] + ch[c]
					_via_rail[v] = 1 if _via_rail[u] == 1 or v >= n else 0
					if hn >= hp.size():
						hp.resize(hp.size() * 2)
						hv.resize(hv.size() * 2)
					var ci := hn
					hp[ci] = nd
					hv[ci] = v
					hn += 1
					while ci > 0:
						var up := (ci - 1) / 2
						if hp[up] <= hp[ci]:
							break
						var tp := hp[up]
						hp[up] = hp[ci]
						hp[ci] = tp
						var tv := hv[up]
						hv[up] = hv[ci]
						hv[ci] = tv
						ci = up
			unreachable += w
	var total_cost := 0.0
	var total_assigned := 0.0
	for s: int in src_assigned:
		commute_cost[s] = src_cost[s] / src_assigned[s]
		total_cost += src_cost[s]
		total_assigned += src_assigned[s]
	unreachable_workers = int(unreachable)
	avg_commute = total_cost / total_assigned if total_assigned > 0.0 else 0.0
	transit_share = _transit_trips / total_assigned if total_assigned > 0.0 else 0.0
	car_trips = maxf(total_assigned - _transit_trips, 0.0)

	_add_venue_traffic()
	# Auslastung; Anzeige = Stau, den Pendler im Schnitt erleben (verkehrsgewichtet)
	var w_sum := 0.0
	var c_sum := 0.0
	for i in n:
		if map.road[i] == 0:
			congestion[i] = 0.0
			continue
		congestion[i] = lerpf(prev[i], traffic[i] / cap[i], 0.75)
		w_sum += traffic[i]
		c_sum += traffic[i] * congestion[i]
	avg_congestion = c_sum / w_sum if w_sum > 0.0 else 0.0
	for a: int in venue_event:
		var roads := _venue_roads(a)
		var sum := 0.0
		for r in roads:
			sum += congestion[r]
		venue_jam[a] = sum / maxf(roads.size(), 1.0)


## Theater/Stadion (Anker-Tiles).
func venues() -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in map.size * map.size:
		if map.anchor[i] == i and Config.SPECIALS[map.special[i]].get("service", "") == "venue":
			out.append(i)
	return out


func venue_visitors(a: int) -> float:
	return float(Config.SPECIALS[map.special[a]]["visitors"]) * map.special_level(a)


## Veranstaltung diesen Monat? Versetzt je Gebäude, damit nicht alle gleichzeitig spielen.
func venue_has_event(a: int) -> bool:
	var every: int = Config.SPECIALS[map.special[a]]["event_every"]
	return (year * 12 + month + a) % every == 0


func _venue_roads(a: int) -> PackedInt32Array:
	var s: int = Config.SPECIALS[map.special[a]]["size"]
	var r := Config.VENUE_TRAFFIC_RANGE
	var ax := a % map.size
	var az := a / map.size
	var out := PackedInt32Array()
	for z in range(maxi(az - r, 0), mini(az + s + r, map.size)):
		for x in range(maxi(ax - r, 0), mini(ax + s + r, map.size)):
			if map.road[z * map.size + x] != 0:
				out.append(z * map.size + x)
	return out


## Besucher an Veranstaltungstagen belasten die Straßen rund um Theater/Stadion;
## Bus/Bahn in der Nähe nimmt einen Teil auf.
func _add_venue_traffic() -> void:
	venue_event = {}
	venue_jam = {}
	for a in venues():
		if not venue_has_event(a) or powered.size() <= a or powered[a] == 0:
			venue_event[a] = 0.0
			continue
		var visitors := venue_visitors(a)
		venue_event[a] = visitors
		var roads := _venue_roads(a)
		if roads.is_empty():
			continue
		var cut := 1.0
		var ax := a % map.size
		var az := a / map.size
		for z in range(maxi(az - 4, 0), mini(az + 7, map.size)):
			for x in range(maxi(ax - 4, 0), mini(ax + 7, map.size)):
				if map.transit[z * map.size + x] != Config.Transit.NONE:
					cut = 1.0 - Config.VENUE_TRANSIT_CUT
		var per_road := visitors * Config.VENUE_TRAFFIC * cut / roads.size()
		for r in roads:
			traffic[r] += per_road


## Pfad vom Ziel u zurück zur Quelle s verbuchen: Bahnfahrt -> Gleis-Last + Bahnhofs-Nutzung,
## sonst Straßenlast (mit Busanteil, wenn Start und Ziel an Haltestellen liegen).
func _record_trip(u: int, s: int, take: float) -> void:
	var n := map.size * map.size
	if _via_rail[u] == 1:
		rail_riders += take
		_transit_trips += take
		# Zubringer: Start oder Ziel im Busnetz -> diese Pendler fahren auch Bus
		if bus_served[s] == 1 or bus_served[u] == 1:
			bus_riders += take
		var v := u
		var prev_node := -1
		while v != -1:
			if v >= n:
				rail_traffic[v - n] += take
				# Ein-/Ausstieg: Übergang Gleis <-> Straße
				if prev_node != -1 and prev_node < n:
					station_use[v - n] = station_use.get(v - n, 0.0) + take
				var p := _parent[v]
				if p != -1 and p < n:
					station_use[v - n] = station_use.get(v - n, 0.0) + take
			prev_node = v
			v = _parent[v]
		return
	var car := take
	if bus_served[s] == 1 and bus_served[u] == 1:
		var bus := take * float(Config.FARE_BUS_SHARE[fare])
		bus_riders += bus
		_transit_trips += bus
		car = take - bus + bus * Config.BUS_TRAFFIC
	var v := u
	while v != -1:
		traffic[v] += car
		v = _parent[v]


## Überfüllter Bahnhof: Wegkosten-Aufschlag aus Ein-/Aussteigern (laufender Monat + Rest vom Vormonat).
func _crowd_cost(station: int, prev: Dictionary) -> float:
	var now := float(station_use.get(station, 0.0))
	if now >= Config.STATION_CAPACITY * Config.STATION_HARD_LIMIT:
		return INF       # dicht
	var load := (now + float(prev.get(station, 0.0)) * 0.3) / Config.STATION_CAPACITY
	load = minf(load, 4.0)
	return Config.STATION_CROWD_COST * load * load


## Bahn als zweites Netz: Knoten n+i = Gleis-Tile i. Bahnhöfe verbinden Gleis und Straßen
## im Fußweg-Umkreis. Straßen-Komponenten, die per Bahn verbunden sind, gelten als ein Netz.
## Haltestellen markieren Straßen-Tiles mit Busanschluss (bus_served).
func _build_transit_links(road_comps: int) -> void:
	var n := map.size * map.size
	# Tarif wirkt auf die Routenwahl: kostenlos = Einstieg "billiger", teuer = teurer
	var transfer := maxf(Config.STATION_TRANSFER + float(Config.FARE_PATH_COST[fare]), 0.5)
	_station_links = {}
	_road_station_links = {}
	bus_served.resize(n)
	bus_served.fill(0)
	var uf := range(road_comps)   # Union-Find über Straßen-Komponenten
	var stops: Array[int] = []
	for i in n:
		if map.transit[i] != Config.Transit.BUS_STOP:
			continue
		stops.append(i)
		var x := i % map.size
		var z := i / map.size
		var r := Config.BUS_RANGE
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) + absi(dz) <= r and map.is_road(x + dx, z + dz):
					bus_served[map.idx(x + dx, z + dz)] = 1

	for i in n:
		if map.transit[i] != Config.Transit.STATION or map.rail[i] == 0:
			continue
		var x := i % map.size
		var z := i / map.size
		var best := {}    # Straßen-Tile -> günstigste Zugangskosten
		# Fußweg
		var w := Config.STATION_WALK
		for dz in range(-w, w + 1):
			for dx in range(-w, w + 1):
				var d := absi(dx) + absi(dz)
				if d <= w and map.is_road(x + dx, z + dz):
					best[map.idx(x + dx, z + dz)] = d * Config.WALK_COST + transfer
		# Zubringerbus: Haltestelle am Bahnhof bindet das ganze Haltestellen-Netz
		# (alle Straßen mit Busanschluss im selben Straßennetz) an
		var fed_comps := {}
		for st in stops:
			if absi(st % map.size - x) + absi(st / map.size - z) <= w:
				fed_comps[road_comp[st]] = true
		if not fed_comps.is_empty():
			for r in n:
				if bus_served[r] == 0 or not fed_comps.has(road_comp[r]):
					continue
				var d := absi(r % map.size - x) + absi(r / map.size - z)
				var cost := transfer + Config.BUS_WAIT + d * Config.BUS_FEEDER_COST
				if cost < best.get(r, INF):
					best[r] = cost
		var links: Array = []
		for r: int in best:
			links.append([r, best[r]])
			if not _road_station_links.has(r):
				_road_station_links[r] = []
			_road_station_links[r].append([n + i, best[r]])
		_station_links[i] = links

	# Bahn-Komponenten -> verbundene Straßen-Komponenten vereinigen
	var rail_comp := PackedInt32Array()
	rail_comp.resize(n)
	rail_comp.fill(-1)
	var rc := 0
	for i in n:
		if map.rail[i] == 0 or rail_comp[i] != -1:
			continue
		var stack: Array[int] = [i]
		rail_comp[i] = rc
		var touched: Array[int] = []
		while not stack.is_empty():
			var u: int = stack.pop_back()
			if _station_links.has(u):
				for l: Array in _station_links[u]:
					touched.append(road_comp[l[0]])
			for v in _rail_neighbors(u):
				if rail_comp[v] == -1:
					rail_comp[v] = rc
					stack.append(v)
		for k in range(1, touched.size()):
			_uf_union(uf, touched[0], touched[k])
		rc += 1
	for i in n:
		if road_comp[i] >= 0:
			road_comp[i] = _uf_find(uf, road_comp[i])


func _uf_find(uf: Array, a: int) -> int:
	while uf[a] != a:
		uf[a] = uf[uf[a]]
		a = uf[a]
	return a


func _uf_union(uf: Array, a: int, b: int) -> void:
	uf[_uf_find(uf, a)] = _uf_find(uf, b)


func _rail_neighbors(i: int) -> Array[int]:
	var out: Array[int] = []
	var x := i % map.size
	var z := i / map.size
	for d: Vector2i in DIRS:
		if map.rails_connected(x, z, x + d.x, z + d.y):
			out.append(map.idx(x + d.x, z + d.y))
	return out


## Straßen in Reichweite eines Tiles: [road_idx, Anteil, road_idx, Anteil, ...], Anteile summieren auf 1.
func _access(i: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var x := i % map.size
	var z := i / map.size
	var r := Config.ROAD_ACCESS_RANGE
	var total := 0.0
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var d := absi(dx) + absi(dz)
			if d > r or not map.is_road(x + dx, z + dz):
				continue
			var w := 1.0 / (1.0 + d * d)
			out.append(map.idx(x + dx, z + dz))
			out.append(w)
			total += w
	for k in range(1, out.size(), 2):
		out[k] /= total
	return out


## Ø Arbeitsweg der Pendler eines Wohn-Tiles (über alle genutzten Straßen).
func tile_commute(i: int) -> float:
	var acc := _access(i)
	var c := 0.0
	for k in range(0, acc.size(), 2):
		c += commute_cost[int(acc[k])] * acc[k + 1]
	return c


## Irgendeine erreichbare Straßen-Komponente mit Jobs (Wohnen) bzw. Einwohnern (Gewerbe/Industrie)?
func _reaches(i: int, need_jobs: bool) -> bool:
	var acc := _access(i)
	for k in range(0, acc.size(), 2):
		var c := road_comp[int(acc[k])]
		if (need_jobs and comp_has_job.has(c)) or (not need_jobs and comp_has_res.has(c)):
			return true
	return false


## Verschmutzung, Bodenwert, Kundschaft. Nachbarschafts-Summen per Integralbild (O(n)).
## Umwelt in Teilen, damit sie im Spiel über mehrere Frames laufen kann:
## _env_begin (Verschmutzung + Integralbilder), _env_rows (Bodenwert usw. je Zeilenbereich), _env_end.
func _compute_environment() -> void:
	_env_begin()
	_env_rows(0, map.size)
	_env_end()


var _env_int: Array = []      # Integralbilder aus _env_begin: [iw, it, ip, ipop, icom, iind, ires]


func _env_begin() -> void:
	var size := map.size
	var n := size * size
	# Lokale Referenzen: spart in GDScript den Member-/Map-Zugriff je Iteration
	var zone := map.zone
	var level := map.level
	var road := map.road
	var height := map.height
	var feature := map.feature
	var anchor := map.anchor
	var special := map.special

	pollution.resize(n)
	pollution.fill(0.0)
	var coal_f := Config.TECH_FILTER if tech("plant_filter") else 1.0
	var works_f := Config.TECH_FURNACE_POLLUTION if tech("blast_furnace") else 1.0
	for i in n:
		if zone[i] == Config.Zone.IND and level[i] > 0:
			_stamp(i, Config.POLLUTION_IND_PER_LEVEL[level[i]] * (Config.HIGHTECH_POLLUTION if map.hightech[i] == 1 else 1.0),
				Config.POLLUTION_IND_RANGE)
		elif anchor[i] == i and special[i] == Config.Special.COAL:
			_stamp(i, Config.POLLUTION_COAL * coal_f, Config.POLLUTION_COAL_RANGE)
		elif anchor[i] == i and special[i] != Config.Special.NONE and Config.SPECIALS[special[i]].has("pollution"):
			var pol: Array = Config.SPECIALS[special[i]]["pollution"]
			_stamp(i, float(pol[0]) * map.special_level(i) * (works_f if Config.SPECIALS[special[i]].has("process") else 1.0),
				int(pol[1]))
		elif road[i] != 0 and congestion[i] > 0.3:
			_stamp(i, Config.POLLUTION_TRAFFIC * minf(congestion[i], 2.0), Config.POLLUTION_TRAFFIC_RANGE)

	# Integralbilder (Präfixsummen) für Wasser, Bäume, Parks, Einwohner in einem Durchlauf
	var s := size + 1
	var iw := PackedFloat32Array()
	var it := PackedFloat32Array()
	var ip := PackedFloat32Array()
	var ipop := PackedFloat32Array()
	var ijobs := PackedFloat32Array()
	var icom := PackedFloat32Array()   # Gewerbe mit Gebäude (Läden)
	var iind := PackedFloat32Array()   # Industrie-Zonen
	var ires := PackedFloat32Array()   # Wohn-Zonen
	for a: PackedFloat32Array in [iw, it, ip, ipop, ijobs, icom, iind, ires]:
		a.resize(s * s)
	for z in size:
		var rw := 0.0
		var rt := 0.0
		var rp := 0.0
		var rpop := 0.0
		var rjobs := 0.0
		var rcom := 0.0
		var rind := 0.0
		var rres := 0.0
		for x in size:
			var i := z * size + x
			if height[i] < Config.WATER_LEVEL: rw += 1.0
			var f := feature[i]
			if f == Config.Feature.TREE: rt += 1.0
			elif f == Config.Feature.PARK: rp += 1.0
			if zone[i] == Config.Zone.RES:
				rpop += map.residents(i)
				rres += 1.0
			elif zone[i] == Config.Zone.COM:
				rjobs += map.jobs_at(i)
				if level[i] > 0: rcom += 1.0
			elif zone[i] == Config.Zone.IND:
				rjobs += map.jobs_at(i)
				rind += 1.0
			var o := (z + 1) * s + x + 1
			var up := z * s + x + 1
			iw[o] = iw[up] + rw
			it[o] = it[up] + rt
			ip[o] = ip[up] + rp
			ipop[o] = ipop[up] + rpop
			ijobs[o] = ijobs[up] + rjobs
			icom[o] = icom[up] + rcom
			iind[o] = iind[up] + rind
			ires[o] = ires[up] + rres
	_ipop = ipop
	_ijobs = ijobs
	_env_int = [iw, it, ip, ipop, icom, iind, ires]

	land_value.resize(n)
	customers.resize(n)
	res_nearby.resize(n)
	parks_near.resize(n)
	green_filter.resize(n)
	ind_cluster.resize(n)
	res_cluster.resize(n)
	land_mix.resize(n)


func _env_rows(z_from: int, z_to: int) -> void:
	var size := map.size
	var s := size + 1
	var zone := map.zone
	var level := map.level
	var road := map.road
	var height := map.height
	var feature := map.feature
	var iw: PackedFloat32Array = _env_int[0]
	var it: PackedFloat32Array = _env_int[1]
	var ip: PackedFloat32Array = _env_int[2]
	var ipop: PackedFloat32Array = _env_int[3]
	var icom: PackedFloat32Array = _env_int[4]
	var iind: PackedFloat32Array = _env_int[5]
	var ires: PackedFloat32Array = _env_int[6]
	var gr := Config.GREEN_FILTER_RANGE
	var kr := Config.IND_CLUSTER_RANGE
	var sr := Config.RES_SHOP_RANGE
	var dr := Config.RES_DULL_RANGE
	var cr := Config.COM_CUSTOMER_RANGE
	var range_ok := Config.ROAD_ACCESS_RANGE
	for z in range(z_from, z_to):
		var z0 := maxi(z - 3, 0) * s
		var z1 := mini(z + 4, size) * s
		var cz0 := maxi(z - cr, 0) * s
		var cz1 := mini(z + cr + 1, size) * s
		var rz0 := maxi(z - 4, 0) * s
		var rz1 := mini(z + 5, size) * s
		for x in size:
			var i := z * size + x
			var x0 := maxi(x - 3, 0)
			var x1 := mini(x + 4, size)
			# Bäume/Parks im Umkreis filtern Verschmutzung (Grüngürtel zwischen Industrie und Wohnen)
			var gz0 := maxi(z - gr, 0) * s
			var gz1 := mini(z + gr + 1, size) * s
			var gx0 := maxi(x - gr, 0)
			var gx1 := mini(x + gr + 1, size)
			var gf := minf((it[gz1 + gx1] - it[gz0 + gx1] - it[gz1 + gx0] + it[gz0 + gx0]) * Config.GREEN_FILTER_TREE
				+ (ip[gz1 + gx1] - ip[gz0 + gx1] - ip[gz1 + gx0] + ip[gz0 + gx0]) * Config.GREEN_FILTER_PARK, Config.GREEN_FILTER_MAX)
			green_filter[i] = gf
			pollution[i] *= 1.0 - gf
			var v := Config.LAND_BASE
			if iw[z1 + x1] - iw[z0 + x1] - iw[z1 + x0] + iw[z0 + x0] > 0.0:
				v += Config.LAND_WATER
			var parks := ip[z1 + x1] - ip[z0 + x1] - ip[z1 + x0] + ip[z0 + x0]
			parks_near[i] = parks
			v += minf(parks * Config.LAND_PARK, 0.24)
			# Nachbarschaft: Läden in der Nähe (+), weit und breit nur Häuser (-)
			var sz0 := maxi(z - sr, 0) * s
			var sz1 := mini(z + sr + 1, size) * s
			var sx0 := maxi(x - sr, 0)
			var sx1 := mini(x + sr + 1, size)
			var mix := 0.0
			if icom[sz1 + sx1] - icom[sz0 + sx1] - icom[sz1 + sx0] + icom[sz0 + sx0] > 0.0:
				mix = Config.RES_SHOP_BONUS
			else:
				var dz0 := maxi(z - dr, 0) * s
				var dz1 := mini(z + dr + 1, size) * s
				var dx0 := maxi(x - dr, 0)
				var dx1 := mini(x + dr + 1, size)
				var variety := icom[dz1 + dx1] - icom[dz0 + dx1] - icom[dz1 + dx0] + icom[dz0 + dx0] \
					+ ip[dz1 + dx1] - ip[dz0 + dx1] - ip[dz1 + dx0] + ip[dz0 + dx0] \
					+ iw[dz1 + dx1] - iw[dz0 + dx1] - iw[dz1 + dx0] + iw[dz0 + dx0]
				if variety <= 0.0:
					mix = -Config.RES_DULL_MALUS
			land_mix[i] = mix
			v += mix
			# Ballung: Industrie-Zonen im 5x5 ringsum
			var kz0 := maxi(z - kr, 0) * s
			var kz1 := mini(z + kr + 1, size) * s
			var kx0 := maxi(x - kr, 0)
			var kx1 := mini(x + kr + 1, size)
			ind_cluster[i] = iind[kz1 + kx1] - iind[kz0 + kx1] - iind[kz1 + kx0] + iind[kz0 + kx0] \
				- (1.0 if zone[i] == Config.Zone.IND else 0.0)
			res_cluster[i] = ires[kz1 + kx1] - ires[kz0 + kx1] - ires[kz1 + kx0] + ires[kz0 + kx0] \
				- (1.0 if zone[i] == Config.Zone.RES else 0.0)
			v += minf(maxf(0.0, height[i] - Config.WATER_LEVEL) * Config.LAND_HEIGHT, 0.1)
			v -= pollution[i] * Config.LAND_POLLUTION
			if road_dist[i] <= range_ok:
				var src := road_src[i]
				v -= minf(congestion[src], 2.0) * Config.LAND_CONGESTION
				if bus_served[src] == 1 or _road_station_links.has(src):
					v += Config.LAND_TRANSIT
			land_value[i] = clampf(v, 0.0, 1.0)
			var cx0 := maxi(x - cr, 0)
			var cx1 := mini(x + cr + 1, size)
			customers[i] = ipop[cz1 + cx1] - ipop[cz0 + cx1] - ipop[cz1 + cx0] + ipop[cz0 + cx0]
			var rx0 := maxi(x - 4, 0)
			var rx1 := mini(x + 5, size)
			res_nearby[i] = ipop[rz1 + rx1] - ipop[rz0 + rx1] - ipop[rz1 + rx0] + ipop[rz0 + rx0]


func _env_end() -> void:
	var size := map.size
	# Besucher von Theater/Stadion kaufen im Umkreis ein
	for a in venues():
		var bonus := venue_visitors(a) * Config.VENUE_SHOP_SHARE
		var vs: int = Config.SPECIALS[map.special[a]]["size"]
		var vr := Config.VENUE_SHOP_RANGE
		for z in range(maxi(a / size - vr, 0), mini(a / size + vs + vr, size)):
			for x in range(maxi(a % size - vr, 0), mini(a % size + vs + vr, size)):
				customers[z * size + x] += bonus
	traffic_changed.emit()


## Linear abfallender Kegel um Tile i. Kegel-Gewichte je Radius vorberechnet.
var _kernels := {}

func _stamp(i: int, strength: float, radius: int) -> void:
	if not _kernels.has(radius):
		var k := PackedFloat32Array()
		for dz in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var d := sqrt(float(dx * dx + dz * dz))
				k.append(1.0 - d / (radius + 1.0) if d <= radius else 0.0)
		_kernels[radius] = k
	var w: PackedFloat32Array = _kernels[radius]
	var size := map.size
	var x := i % size
	var z := i / size
	var k := 0
	for dz in range(-radius, radius + 1):
		var nz := z + dz
		if nz < 0 or nz >= size:
			k += radius * 2 + 1
			continue
		for dx in range(-radius, radius + 1):
			var nx := x + dx
			if nx >= 0 and nx < size and w[k] > 0.0:
				pollution[nz * size + nx] += strength * w[k]
			k += 1




## Eignung eines Tiles für eine Zone, 0..1 (für Bau-Vorschau und Info).
func suitability(i: int, zn: int) -> float:
	if land_value.size() <= i:
		return 0.5
	var road_factor := 1.0 if _src(i) >= 0 else 0.35
	match zn:
		Config.Zone.RES:
			return clampf(land_value[i] * 1.4 - 0.2, 0.0, 1.0) * road_factor
		Config.Zone.COM:
			var depth: float = [1.0, 1.0, 0.7, 0.45][clampi(road_dist[i], 0, 3)]   # Ladenzeile
			return clampf(0.35 + customers[i] / Config.COM_CUSTOMERS_FULL * 0.65, 0.0, 1.0) * road_factor * depth
		Config.Zone.IND:
			# gut: weg von Wohnen (Industrie verschmutzt Nachbarn), neben anderer Industrie (Ballung)
			var cl := 0.6 + 0.4 * minf((ind_cluster[i] if ind_cluster.size() > i else 0.0) / Config.IND_CLUSTER_LEVEL[2], 1.0)
			return clampf(1.0 - res_nearby[i] / 250.0, 0.25, 1.0) * road_factor * cl
	return 0.0


func _road_neighbors(i: int) -> Array[int]:
	var out: Array[int] = []
	var x := i % map.size
	var z := i / map.size
	for d: Vector2i in DIRS:
		if map.roads_connected(x, z, x + d.x, z + d.y):
			out.append(map.idx(x + d.x, z + d.y))
	return out


func tile_power_use(i: int) -> int:
	var zn := map.zone[i]
	if zn == Config.Zone.NONE:
		# Dienst-/Kulturbau: Verbrauch am Ursprungs-Tile, je Ausbaustufe
		if map.anchor[i] == i and map.special[i] != Config.Special.NONE:
			return ceili(float(Config.SPECIALS[map.special[i]].get("use", 0)) * Config.SERVICE_POWER_LEVEL[map.special_level(i)])
		return 0
	return Config.POWER_USE[zn][map.level[i]]


## Sonderbau (beliebiges Tile davon) hat Strom? Kraftwerke immer.
func special_powered(i: int) -> bool:
	var a := map.anchor[i]
	return a >= 0 and powered.size() > a and powered[a] == 1 and map.construct[a] == 0   # Baustelle arbeitet nicht


## Stromnetze: zusammenhängende leitende Tiles (Leitungen, Zonen, Sonderbauten; Straßen leiten nicht).
## Je Netz: BFS ab den Kraftwerken, versorgt bis die Leistung erschöpft ist (Leitungsende fällt zuerst aus).
## Auch Netze ohne Kraftwerk werden erfasst (Bedarf zählt, Gebäude bleiben dunkel).
func _compute_power() -> void:
	var n := map.size * map.size
	powered.resize(n)
	powered.fill(0)
	power_net.resize(n)
	power_net.fill(-1)
	power_supply = 0
	power_demand = 0
	power_served = 0
	power_nets = []
	# Vorberechnet je Tile (statt Funktionsaufrufen in den Schleifen): leitet? Verbrauch? Kraftwerks-Leistung?
	var size := map.size
	var cond := PackedByteArray()
	cond.resize(n)
	var use := PackedInt32Array()
	use.resize(n)
	var anchor := map.anchor
	var special := map.special
	var zone := map.zone
	var line := map.power_line
	var special_use := PackedByteArray()      # 1 = Sonderbau mit eigenem Verbrauch (Dienst)
	special_use.resize(n)
	for i in n:
		cond[i] = 1 if line[i] == 1 or zone[i] != Config.Zone.NONE or special[i] != Config.Special.NONE else 0
		use[i] = tile_power_use(i) if zone[i] != Config.Zone.NONE or anchor[i] == i else 0
		if special[i] != Config.Special.NONE and int(Config.SPECIALS[special[i]].get("use", 0)) > 0:
			special_use[i] = 1
	var net := power_net
	var pw := powered
	var visit := PackedInt32Array()           # Lauf-Nummer (Netz + 1) statt Dictionary je Netz
	visit.resize(n)
	var comp := PackedInt32Array()
	var q := PackedInt32Array()
	for start in n:
		if net[start] != -1 or cond[start] == 0:
			continue
		# 1) Netz-Komponente sammeln
		var id := power_nets.size()
		comp.resize(0)
		comp.append(start)
		net[start] = id
		var head := 0
		var plants: Array[int] = []
		var capacity := 0
		var night := 0           # Leistung nachts (ohne Solar)
		var storage := 0         # Speicher-Leistung (Batterien), lädt tagsüber aus dem Überschuss
		var demand := 0
		while head < comp.size():
			var i := comp[head]
			head += 1
			if anchor[i] == i:
				var pdef: Dictionary = Config.SPECIALS[special[i]]
				var p: int = pdef["power"] if map.construct[i] == 0 else 0     # Kraftwerk im Bau liefert nichts
				capacity += p
				if not pdef.has("solar"):
					night += p
				storage += int(pdef.get("storage_mw", 0))
				if p > 0:
					plants.append(i)
			demand += use[i]
			var x := i % size
			var z := i / size
			if x + 1 < size and net[i + 1] == -1 and cond[i + 1] == 1:
				net[i + 1] = id
				comp.append(i + 1)
			if x > 0 and net[i - 1] == -1 and cond[i - 1] == 1:
				net[i - 1] = id
				comp.append(i - 1)
			if z + 1 < size and net[i + size] == -1 and cond[i + size] == 1:
				net[i + size] = id
				comp.append(i + size)
			if z > 0 and net[i - size] == -1 and cond[i - size] == 1:
				net[i - size] = id
				comp.append(i - size)
		# Tag/Nacht: versorgt wird nach der knapperen Tageshälfte. Nachts 75 % Bedarf, Speicher geben den Tagesüberschuss
		# ab (höchstens ihre Leistung). Ohne Solar ist das Ergebnis = Tagesleistung (wie früher).
		var day_cap := capacity
		var store_used := mini(storage, maxi(day_cap - demand, 0))
		var night_cap := night + store_used
		var night_limited := float(night_cap) / Config.NIGHT_DEMAND < float(day_cap)
		capacity = mini(day_cap, int(float(night_cap) / Config.NIGHT_DEMAND))
		# 2) Versorgen in BFS-Reihenfolge ab den Kraftwerken
		var left := capacity
		var unserved := 0
		var dark := -1          # ein Gebäude ohne Strom (für Meldung/Kamera)
		if not plants.is_empty():
			var stamp := id + 1
			# Dienste (Polizei, Krankenhaus ...) zuerst versorgen, Wohnen/Gewerbe/Industrie bekommen den Rest
			var reserved := {}
			for i in comp:
				if zone[i] == Config.Zone.NONE and anchor[i] == i:
					var su := use[i]
					if su > 0 and su <= left:
						left -= su
						pw[i] = 1
						reserved[i] = true
			# Startpunkte: alle Tiles der Kraftwerke (1x1 oder 2x2), je Kraftwerk in Komponenten-Reihenfolge
			var plant_set := {}
			for p in plants:
				plant_set[p] = []
			for k in comp:
				if anchor[k] >= 0 and plant_set.has(anchor[k]):
					(plant_set[anchor[k]] as Array).append(k)
			q.resize(0)
			for p in plants:
				for k: int in plant_set[p]:
					if visit[k] != stamp:
						visit[k] = stamp
						q.append(k)
			head = 0
			while head < q.size():
				var i := q[head]
				head += 1
				var u := 0 if reserved.has(i) else use[i]
				if u > left:
					continue
				left -= u
				pw[i] = 1
				var x := i % size
				var z := i / size
				if x + 1 < size and visit[i + 1] != stamp and cond[i + 1] == 1:
					visit[i + 1] = stamp
					q.append(i + 1)
				if x > 0 and visit[i - 1] != stamp and cond[i - 1] == 1:
					visit[i - 1] = stamp
					q.append(i - 1)
				if z + 1 < size and visit[i + size] != stamp and cond[i + size] == 1:
					visit[i + size] = stamp
					q.append(i + size)
				if z > 0 and visit[i - size] != stamp and cond[i - size] == 1:
					visit[i - size] = stamp
					q.append(i - size)
		for i in comp:
			if use[i] > 0 and pw[i] == 0:
				unserved += 1
				if dark < 0:
					dark = i
		# Sonderbauten ohne eigenen Verbrauch (Kraftwerke) gelten als versorgt, wenn ihr Netz ein Kraftwerk hat;
		# Dienste nur, wenn ihr Ursprungs-Tile oben Strom bekommen hat
		if not plants.is_empty():
			for i in comp:
				if special[i] != Config.Special.NONE and special_use[i] == 0:
					pw[i] = 1
		power_supply += capacity
		power_demand += demand
		power_served += capacity - left
		power_nets.append({"capacity": capacity, "demand": demand, "plants": plants.size(),
			"unserved": unserved, "dark": dark, "key": start, "day": day_cap, "night": night_cap,
			"storage": storage, "store_used": store_used, "night_limited": night_limited})
	power_net = net
	powered = pw
	# Restliche Tiles eines Dienstbaus übernehmen den Zustand ihres Ursprungs-Tiles
	for i in n:
		var a := map.anchor[i]
		if a >= 0 and a != i and int(Config.SPECIALS[map.special[i]].get("use", 0)) > 0:
			powered[i] = powered[a]
	_power_alerts()
	power_changed.emit()


## Stromnetz eines Tiles als Text für Info-Karte/Tooltip ("" = kein Netz oder ohne Bedarf und Kraftwerk).
func power_net_text(i: int) -> String:
	if power_net.size() <= i or power_net[i] < 0:
		return ""
	var net: Dictionary = power_nets[power_net[i]]
	if int(net["demand"]) == 0 and int(net["plants"]) == 0:
		return ""
	var state := ""
	if int(net["plants"]) == 0:
		state = "  - kein Kraftwerk angeschlossen!"
	elif int(net["unserved"]) > 0:
		state = "  - Engpass (%d Gebäude ohne Strom)" % int(net["unserved"])
	return "Stromnetz: %d MW Leistung / %d MW Bedarf (%d Kraftwerk%s)%s" % [int(net["capacity"]), int(net["demand"]),
		int(net["plants"]), "" if int(net["plants"]) == 1 else "e", state]


## Meldungen bei neuen Strom-Problemen (mit Ort); pro Netz nur einmal, solange das Problem besteht.
func _power_alerts() -> void:
	var now := {}
	var fresh: Array = []
	for net: Dictionary in power_nets:
		if int(net["unserved"]) == 0:
			continue
		var kind := "noplant" if int(net["plants"]) == 0 else "short"
		var key := "%s:%d" % [kind, int(net["key"])]
		now[key] = true
		if not _power_warned.has(key):
			fresh.append(net)
	_power_warned = now
	if fresh.is_empty():
		return
	var net: Dictionary = fresh[0]
	var t := Vector2i(int(net["dark"]) % map.size, int(net["dark"]) / map.size)
	var text := ""
	if int(net["plants"]) == 0:
		text = "Kein Strom: Gebäude bei %d,%d ohne Kraftwerk im Netz - Stromleitung ziehen" % [t.x, t.y]
	else:
		text = "Stromengpass im Netz bei %d,%d: Bedarf %d MW > Leistung %d MW" % [t.x, t.y,
			int(net["demand"]), int(net["capacity"])]
		if bool(net.get("night_limited", false)):
			text += " - nachts (Solar liefert nur tagsüber: Speicher oder Grundlast bauen)"
	if fresh.size() > 1:
		text += " (+%d weitere Netze)" % (fresh.size() - 1)
	alert.emit(text, t)


func _recount() -> void:
	population = 0
	villa_count = 0
	jobs_com = 0
	jobs_ind = 0
	road_count = 0
	park_count = 0
	line_count = 0
	rail_count = 0
	bus_stop_count = 0
	station_count = 0
	special_upkeep = 0.0
	_inst_levels = 0
	var zone := map.zone
	var level := map.level
	var villa := map.villa
	var road := map.road
	var line := map.power_line
	var rail := map.rail
	var transit := map.transit
	var feature := map.feature
	var anchor := map.anchor
	var res_cap: Array = Config.RES_CAPACITY
	var com_cap: Array = Config.COM_CAPACITY
	var ind_cap: Array = Config.IND_CAPACITY
	var empty := map.empty
	var pop_f := 0.0
	var ht_f := 0.0
	var com_f := 0.0
	var ind_f := 0.0
	for i in map.size * map.size:
		var lv := level[i]
		var zn := zone[i]
		var occ := (100 - empty[i]) * 0.01 if map.construct[i] == 0 else 0.0
		if zn == Config.Zone.RES:
			if villa[i] == 1 and lv == 3:
				pop_f += Config.VILLA_POP * occ
				if occ > 0.0:
					villa_count += 1
			else:
				pop_f += res_cap[lv] * occ
		elif zn == Config.Zone.COM:
			com_f += com_cap[lv] * occ
		elif zn == Config.Zone.IND:
			ind_f += ind_cap[lv] * occ
			if map.hightech[i] == 1:
				ht_f += ind_cap[lv] * occ
		if road[i] != 0: road_count += 1
		line_count += line[i]
		if rail[i] != 0: rail_count += 1
		var tr := transit[i]
		if tr == Config.Transit.BUS_STOP: bus_stop_count += 1
		elif tr == Config.Transit.STATION: station_count += 1
		if feature[i] == Config.Feature.PARK:
			park_count += 1
		if anchor[i] == i:
			var sdef: Dictionary = Config.SPECIALS[map.special[i]]
			var lvl := map.special_level(i) if sdef.has("service") or sdef.has("research") else 1
			if map.special[i] == Config.Special.INSTITUTE and special_powered(i):
				_inst_levels += lvl
			var early := Config.SERVICE_UPKEEP_EARLY if sdef.has("service") and lvl == 1 else 1.0
			special_upkeep += Config.SPECIALS[map.special[i]]["upkeep"] * Config.UPKEEP_LEVEL[lvl] * early
	population = roundi(pop_f)
	jobs_com = roundi(com_f)
	jobs_ind = roundi(ind_f)
	jobs_hightech = roundi(ht_f)
	traffic_control = tech("traffic")


func _update_demand() -> void:
	var pop := float(population)
	var workforce := pop * 0.55
	var jobs := float(jobs_com + jobs_ind) + founding_jobs()
	# Wohnen: Zuzug, wenn Jobs frei sind (+ Grundattraktivität)
	demand_res = (jobs - workforce + 60.0) / maxf(60.0, workforce * 0.4 + 40.0)
	# Industrie: Exportmarkt + wächst mit Bevölkerung
	var ind_target := 40.0 + pop * 0.30
	demand_ind = (ind_target - jobs_ind) / maxf(40.0, ind_target * 0.4)
	# Gewerbe: braucht Kundschaft (Einwohner) und etwas Industrie-Zulieferung
	var com_target := 15.0 + pop * 0.22 + jobs_ind * 0.1
	for a in venues():
		com_target += venue_visitors(a) * 0.05       # Gastronomie/Läden für Besucher
	demand_com = (com_target - jobs_com) / maxf(30.0, com_target * 0.4)
	# Arbeitskräftemangel bremst Jobs
	if jobs > workforce + 80.0:
		demand_ind -= 0.3
		demand_com -= 0.3
	# Ruf der Stadt: zufriedene Bürger locken Zuzug an, unzufriedene schrecken ab
	if population > 0:
		demand_res += (city_happiness - 0.5) * 0.8
	# Steuern über Neutralwert dämpfen, darunter fördern
	demand_res = clampf(demand_res - tax_effect(Config.Zone.RES), -1.0, 1.0)
	demand_com = clampf(demand_com - tax_effect(Config.Zone.COM), -1.0, 1.0)
	demand_ind = clampf(demand_ind - tax_effect(Config.Zone.IND), -1.0, 1.0)


## Nachfrage-Abzug durch Steuern über dem neutralen Satz (negativ = Förderung).
func tax_effect(zn: int) -> float:
	return (float(tax[zn]) - Config.TAX_NEUTRAL[zn]) * Config.TAX_DEMAND[zn]


func demand_for(z: int) -> float:
	match z:
		Config.Zone.RES: return demand_res
		Config.Zone.COM: return demand_com
		Config.Zone.IND: return demand_ind
	return 0.0


## Liste der Gründe, warum ein Zonen-Tile nicht wächst (leer = alles ok).
func growth_blockers(i: int) -> PackedStringArray:
	var out := PackedStringArray()
	if map.ruin[i] > 0:
		out.append("Brandruine - Neubau in %d Monaten" % map.ruin[i])
	if road_dist.size() > i and road_dist[i] > Config.ROAD_ACCESS_RANGE:
		out.append("Keine Straße in Reichweite")
	if powered.size() > i and powered[i] == 0:
		out.append("Kein Strom")
	if _src(i) >= 0:
		if map.zone[i] == Config.Zone.RES and game_mode == "build" and hall_level < 2:
			pass                        # Gründung: Siedler arbeiten am Rathaus/im Abbau
		elif map.zone[i] == Config.Zone.RES:
			if not _reaches(i, true):
				out.append("Keine Jobs erreichbar")
			elif tile_commute(i) > LONG_COMMUTE:
				out.append("Arbeitsweg zu lang (Stau)")
		elif not _reaches(i, false):
			out.append("Keine Einwohner erreichbar")
	var lv := map.level[i]
	if map.zone[i] == Config.Zone.RES and lv < 3 and land_value.size() > i \
			and land_value[i] < Config.RES_MIN_LAND[lv + 1]:
		out.append("Bodenwert zu niedrig für Stufe %d" % (lv + 1))
	if map.zone[i] == Config.Zone.COM and lv < 3 and lv >= _max_level(i):
		if _corner_level(i) <= lv:
			out.append("%d Tiles bis zur nächsten Kreuzung - Querstraße bauen" % corner_dist(i))
		else:
			out.append("Ladenzeile: Stufe %d nur näher an der Straße" % (lv + 1))
	if map.zone[i] == Config.Zone.IND and map.hightech[i] == 1 and _uni_cover(i) < Config.HIGHTECH_ACADEMICS:
		out.append("Hightech braucht Akademiker: Universität in Reichweite (Hochschule %d %%)" % roundi(_uni_cover(i) * 100.0))
	elif map.zone[i] == Config.Zone.IND and lv < 3 and lv >= _max_level(i):
		out.append("Zu wenig Industrie ringsum (%d) - Ballung ab %d für Stufe %d" % [
			int(ind_cluster[i]), Config.IND_CLUSTER_LEVEL[lv], lv + 1])
	if map.zone[i] == Config.Zone.RES and lv == 3 and tech("highrise") and map.villa[i] == 0 and land_value.size() > i \
			and land_value[i] < Config.RES_MIN_LAND[4]:
		out.append("Hochhaus erst ab %d %% Bodenwert (hier %d %%)" % [roundi(Config.RES_MIN_LAND[4] * 100.0),
			roundi(land_value[i] * 100.0)])
	if map.zone[i] == Config.Zone.COM and lv == 3 and tech("offices") and _max_level(i) < 4:
		out.append("Büroturm: direkt an der Straße nahe einer Kreuzung und ab %d %% Bodenwert" % roundi(Config.COM_TOWER_LAND * 100.0))
	if map.zone[i] == Config.Zone.RES and happiness.size() > i and lv > 0 and happiness[i] < Config.HAPPY_LEAVE:
		out.append("Unzufrieden - Leute ziehen weg")
	if demand_for(map.zone[i]) <= 0.0:
		out.append("Keine Nachfrage")
	if lv < _max_level(i) and lv >= 1:
		var need := material_need(map.zone[i], lv + 1)
		if float(need[1]) > 0.0 and money < float(need[1]):
			var names := PackedStringArray()
			for r: String in need[0]:
				names.append(Config.RESOURCES[r]["name"])
			out.append("Baustoffe fehlen (%s), Zukauf $%d zu teuer" % [", ".join(names), int(need[1])])
	return out


## Straßenanschluss eines Tiles (-1 = keiner in Reichweite).
func _src(i: int) -> int:
	if road_src.size() <= i or road_dist[i] > Config.ROAD_ACCESS_RANGE:
		return -1
	return road_src[i]


## Wachstumsbedingungen außer Nachfrage erfüllt?
func _can_grow(i: int) -> bool:
	if _src(i) < 0 or powered[i] == 0:
		return false
	if map.zone[i] == Config.Zone.RES:
		if game_mode == "build" and hall_level < 2:
			return true             # Gründung: Siedler arbeiten am Rathaus/im Abbau, kein Pendelweg nötig
		return _reaches(i, true) and tile_commute(i) <= LONG_COMMUTE
	return _reaches(i, false)


func _grow() -> void:
	_grow_rows(0, map.size)
	_grow_finish()


var _grow_changed := Rect2i()
var _vacant_new: Array[int] = []      # in diesem Monat neu aufgegebene Gebäude (Meldung)
var _grow_any := false


## Wachstum für einen Zeilenbereich (im Spiel auf 2 Frames verteilt); _grow_finish meldet die Änderungen.
func _grow_rows(z_from: int, z_to: int) -> void:
	var changed := _grow_changed
	var any := _grow_any
	for z in range(z_from, z_to):
		for x in map.size:
			var i := map.idx(x, z)
			var zn := map.zone[i]
			if zn == Config.Zone.NONE or map.burning[i] > 0 or map.ruin[i] > 0:
				if map.worn[i] != 0:
					map.worn[i] = 0
					var rw := Rect2i(x, z, 1, 1)
					changed = rw if not any else changed.merge(rw)
					any = true
				continue
			var lv := map.level[i]
			var demand := demand_for(zn)
			var ok := _can_grow(i)
			var new_lv := lv
			var was_vacant := lv > 0 and map.empty[i] >= 100
			if was_vacant:
				pass                  # Leerstand: keine Stufenwechsel, nur Belegung/Abriss (unten)
			elif zn == Config.Zone.RES and lv == 3 and map.villa[i] == 1 and villa_lost(i):
				if _rng.randf() < Config.VILLA_DECAY:
					new_lv = 2        # Villenlage verloren -> Einfamilienhaus
			elif zn == Config.Zone.RES and lv > 0 and happiness[i] < Config.HAPPY_LEAVE:
				pass                  # Unzufriedenheit -> Auszug über die Belegung (unten), kein Stufen-Abstieg
			elif not ok:
				pass                  # ohne Straße/Strom/Erreichbarkeit: Auszug über die Belegung
			elif demand > 0.0 and lv < _max_level(i):
				var chance := 0.3 * demand / (1.0 + lv) * _growth_factor(i, zn)
				if lv == 0:
					chance *= 1.5
				if _rng.randf() < chance:
					new_lv = lv + 1
					if new_lv >= 1 and not _use_materials(zn, new_lv):
						new_lv = lv       # Baustoffe fehlen und kein Geld für den Zukauf
			elif lv > _max_level(i) and _rng.randf() < 0.05:
				new_lv = lv - 1       # Bodenwert/Lage reicht nur für kleineres Gebäude -> Abstieg
			# keine Nachfrage (demand < -0.25): Auszug über die Belegung
			if new_lv != lv:
				map.level[i] = new_lv
				# Wohnen Stufe 3: in Villenlage eine Villa statt Wohnblock
				map.villa[i] = 1 if zn == Config.Zone.RES and new_lv == 3 and villa_site(i) else 0
			# Verfall sichtbar machen, bevor das Gebäude absinkt (gleiche Bedingungen wie decay_reason)
			var worn := 0
			var hard := false         # echter Mangel -> schneller Auszug; nur "keine Nachfrage" -> sanft (gleicht sich aus)
			if new_lv > 0:
				var mx := _max_level(i)
				# hart: unzufrieden, kein Strom/Straße/Erreichbarkeit -> Leerstand möglich
				# sanft: zu groß für die Lage / Villenlage weg (Abstieg auf kleinere Stufe) und keine Nachfrage
				hard = (zn == Config.Zone.RES and happiness[i] < Config.HAPPY_LEAVE) or not ok
				var unmaintained := new_lv >= 2 and maint_short > 0.0 and _rng.randf() < maint_short * 0.5
				if game_mode == "build" and new_lv >= 2 and population >= Config.MATERIAL_FROM_POP \
						and store_cover.size() > i and store_cover[i] == 0 and _rng.randf() < 0.1:
					unmaintained = true     # außerhalb jedes Lager-Kreises kommt die Instandhaltung schlecht an
				if hard or demand < -0.25 or new_lv > mx or unmaintained \
						or (zn == Config.Zone.RES and new_lv == 3 and map.villa[i] == 1 and villa_lost(i)):
					worn = 1
			# Belegung: bei Verfall Auszug, sonst Zuzug; 0 % = Leerstand, nach VACANT_MONTHS Abriss
			var occ := 100 - int(map.empty[i])
			if new_lv > lv:
				occ = 100
				if game_mode == "build":
					map.construct[i] = Config.BUILD_MONTHS_ZONE[new_lv] * 2       # halbe Monate
			elif new_lv > 0:
				if worn == 1 and not hard:
					occ = maxi(mini(occ, maxi(occ - Config.OCC_DROP_DEMAND, Config.OCC_SOFT_FLOOR)), 0)
				elif worn == 1:
					occ = maxi(occ - (Config.OCC_DROP if not ok else Config.OCC_DROP_UNHAPPY), 0)
				else:
					occ = mini(occ + Config.OCC_RISE, 100)
			if new_lv > 0 and occ == 0:
				if not was_vacant:
					_vacant_new.append(i)
				map.vacant[i] = mini(int(map.vacant[i]) + 1, 255)
				if map.vacant[i] >= Config.VACANT_MONTHS:
					new_lv = 0              # lange leer -> abgerissen, Zone bleibt
					map.level[i] = 0
					map.villa[i] = 0
					map.vacant[i] = 0
					worn = 0
			else:
				map.vacant[i] = 0
			map.empty[i] = 100 - occ if new_lv > 0 else 0
			var vacant_now := new_lv > 0 and occ == 0
			if new_lv != lv or worn != map.worn[i] or vacant_now != was_vacant:
				map.worn[i] = worn
				var r := Rect2i(x, z, 1, 1)
				changed = r if not any else changed.merge(r)
				any = true
	_grow_changed = changed
	_grow_any = any


func _grow_finish() -> void:
	if _grow_any:
		map.notify_changed(_grow_changed, false)    # nur Gebäudestufen
	_grow_any = false
	_grow_changed = Rect2i()
	if not _vacant_new.is_empty():
		var i: int = _vacant_new[0]
		var why := decay_reason(i)
		var what: String = Config.ZONE_NAMES[map.zone[i]]
		alert.emit("Leerstand: %s bei %d,%d aufgegeben%s%s" % [what, i % map.size, i / map.size,
			(" (" + why + ")") if why != "" else "",
			(" - und %d weitere" % (_vacant_new.size() - 1)) if _vacant_new.size() > 1 else ""],
			Vector2i(i % map.size, i / map.size))
		_vacant_new.clear()


## Höchste erreichbare Stufe (Wohnen: begrenzt durch Bodenwert).
func _max_level(i: int) -> int:
	match map.zone[i]:
		Config.Zone.COM:
			# Ladenzeile: je weiter von der Straße, desto niedriger
			var by_depth: int = Config.COM_MAX_LEVEL_BY_DEPTH[clampi(road_dist[i], 0, 3)]
			var corner := _corner_level(i)
			# Büroturm (Stufe 4): Forschung, direkt an der Straße nahe der Kreuzung, hoher Bodenwert
			if corner == 3 and by_depth == 4 and tech("offices") and land_value.size() > i \
					and land_value[i] >= Config.COM_TOWER_LAND:
				corner = 4
			return mini(by_depth, corner)
		Config.Zone.IND:
			if map.hightech[i] == 1 and _uni_cover(i) < Config.HIGHTECH_ACADEMICS:
				return 0                # Hightech ohne Akademiker in Reichweite: wächst nicht / verfällt
			var lv_i := 1
			for k in range(1, 3):
				if ind_cluster.size() > i and ind_cluster[i] >= Config.IND_CLUSTER_LEVEL[k]:
					lv_i = k + 1
			return lv_i
		Config.Zone.NONE:
			return 3
	var lv := 1
	var top := 4 if tech("highrise") and map.villa[i] == 0 else 3     # Hochhaus nur mit Forschung, Villen bleiben Villen
	for k in range(2, top + 1):
		if land_value[i] >= Config.RES_MIN_LAND[k]:
			lv = k
	return lv


func _uni_cover(i: int) -> float:
	var cov: PackedFloat32Array = coverage.get("university", PackedFloat32Array())
	return cov[i] if cov.size() > i else 0.0


## Gewerbe: Laufkundschaft kommt von Kreuzungen -> Stufe nach Weg zur nächsten Kreuzung/Ecke.
func corner_dist(i: int) -> int:
	var src := _src(i)
	return junction_dist[src] if src >= 0 and junction_dist.size() > src else 99


func _corner_level(i: int) -> int:
	var d := corner_dist(i)
	if d <= Config.COM_CORNER_LEVEL[0]:
		return 3
	return 2 if d <= Config.COM_CORNER_LEVEL[1] else 1


## Villa hat ihre Lage verloren (mit Puffer unter VILLA_LAND, damit sie nicht hin- und herspringt).
func villa_lost(i: int) -> bool:
	return land_value.size() > i and (land_value[i] < Config.VILLA_KEEP_LAND
		or res_cluster[i] > Config.VILLA_MAX_NEIGHBORS)


## Warum ein Gebäude verfällt (leer = stabil). Gleiche Bedingungen wie die Abstiege in _grow().
func decay_reason(i: int) -> String:
	var lv := map.level[i]
	var zn := map.zone[i]
	if lv == 0 or zn == Config.Zone.NONE or land_value.size() <= i:
		return ""
	if zn == Config.Zone.RES and lv == 3 and map.villa[i] == 1 and villa_lost(i):
		return "Villenlage verloren (Bodenwert %d%% < %d%% oder zu dicht bebaut)" % [
			roundi(land_value[i] * 100.0), roundi(Config.VILLA_KEEP_LAND * 100.0)]
	if zn == Config.Zone.RES and happiness.size() > i and happiness[i] < Config.HAPPY_LEAVE:
		return "Unzufrieden - Leute ziehen weg"
	if not _can_grow(i):
		if _src(i) < 0:
			return "Keine Straße in Reichweite"
		if powered.size() > i and powered[i] == 0:
			return "Kein Strom"
		return "Keine Jobs erreichbar / Weg zu lang" if zn == Config.Zone.RES else "Keine Einwohner erreichbar"
	var mx := _max_level(i)
	if lv > mx:
		match zn:
			Config.Zone.RES:
				return "Bodenwert %d%% zu niedrig für Stufe %d" % [roundi(land_value[i] * 100.0), lv]
			Config.Zone.COM:
				return "Lage reicht nur für Stufe %d (Abstand Straße/Kreuzung)" % mx
			_:
				if map.hightech[i] == 1 and mx == 0:
					return "Hightech braucht Akademiker: Universität in Reichweite"
				return "Zu wenig Industrie ringsum für Stufe %d" % lv
	if demand_for(zn) < -0.25:
		return "Keine Nachfrage"
	return ""


## Villenlage: Top-Bodenwert in einer Kleinsiedlung.
func villa_site(i: int) -> bool:
	return land_value.size() > i and land_value[i] >= Config.VILLA_LAND \
		and res_cluster.size() > i and res_cluster[i] <= Config.VILLA_MAX_NEIGHBORS


## Bus- oder Bahnanschluss (Haltestelle in 3 Tiles bzw. Bahnhof zu Fuß/per Zubringer) am Straßenanschluss.
func has_transit(i: int) -> bool:
	var src := _src(i)
	return src >= 0 and bus_served.size() > src and (bus_served[src] == 1 or _road_station_links.has(src))


## Belebte Lage für Läden: Hauptstraße, Bushaltestelle oder Bahnhof in der Nähe.
func _busy_front(src: int) -> bool:
	return map.wide_partner(src % map.size, src / map.size) != Vector2i.ZERO or bus_served[src] == 1 \
		or _road_station_links.has(src)


## Industrie-Ballung: Zulieferer ringsum beschleunigen (einzelne Tiles kümmern).
func _cluster_factor(i: int) -> float:
	var c := ind_cluster[i] if ind_cluster.size() > i else 0.0
	return minf(0.6 + c * Config.IND_CLUSTER_GROWTH, 1.6)


## Wachstums-Multiplikator je Zone.
func _growth_factor(i: int, zn: int) -> float:
	var src := _src(i)
	match zn:
		Config.Zone.RES:
			var f := 0.4 + 1.2 * land_value[i]
			if src >= 0:
				f -= maxf(0.0, tile_commute(i) - 10.0) * 0.015   # lange Wege
			f *= clampf(happiness[i] * 1.6 - 0.1, 0.1, 1.3)       # Zufriedenheit
			return maxf(f, 0.05)
		Config.Zone.COM:
			var f := 0.3 + 0.9 * minf(customers[i] / Config.COM_CUSTOMERS_FULL, 1.0)
			f *= 1.0 - crime[i] * 0.5                                # Kriminalität schreckt Kunden ab
			f *= Config.COM_DEPTH_GROWTH[clampi(road_dist[i], 0, 3)]  # hintere Reihen langsamer
			if src >= 0 and _busy_front(src):
				f *= Config.COM_FRONT_BONUS                          # Hauptstraße/Haltestelle: Laufkundschaft
			return f * _workforce_education()
		Config.Zone.IND:
			return _cluster_factor(i) * _workforce_education()
	return 1.0


## Versorgung je Dienst-Kategorie, Kriminalität, Zufriedenheit; Bürgerwünsche melden.
func _compute_services() -> void:
	var size := map.size
	var n := size * size
	for cat: String in Config.SERVICES:
		var f := PackedFloat32Array()
		f.resize(n)
		coverage[cat] = f
	service_load = {}
	var has_cat := {}
	# Dienstgebäude sammeln; je Kategorie zählen, wie viele Gebäude ein Tile abdecken. Mehrere Gebäude
	# teilen sich die Einwohner eines Tiles (sonst wäre jede Wache in dichten Vierteln einzeln überlastet).
	var stations := []      # [Anker, Kategorie, Stufe]
	var cover_count := {}   # Kategorie -> PackedInt32Array
	for i in n:
		if map.anchor[i] != i:
			continue
		var def: Dictionary = Config.SPECIALS[map.special[i]]
		if not def.has("service"):
			continue
		var cat: String = def["service"]
		has_cat[cat] = true
		if powered.size() > i and powered[i] == 0:
			service_load[i] = 0.0        # ohne Strom: arbeitet nicht, versorgt niemanden
			continue
		stations.append([i, cat, map.special_level(i)])
		if not cover_count.has(cat):
			var cc := PackedInt32Array()
			cc.resize(n)
			cover_count[cat] = cc
		var cnt: PackedInt32Array = cover_count[cat]
		for j in _service_tiles(i):
			cnt[j] += 1
		cover_count[cat] = cnt
	# Einwohner (Feuerwehr: + halbe Arbeitsplätze) je Tile
	var people := PackedFloat32Array()
	people.resize(n)
	var work := PackedFloat32Array()
	work.resize(n)
	for i in n:
		match map.zone[i]:
			Config.Zone.RES: people[i] = map.residents(i)
			Config.Zone.COM: work[i] = map.jobs_at(i)
			Config.Zone.IND: work[i] = map.jobs_at(i)
	for st: Array in stations:
		var i: int = st[0]
		var cat: String = st[1]
		var lv: int = st[2]
		var cnt: PackedInt32Array = cover_count[cat]
		var tiles := _service_tiles(i)
		var served := 0.0
		for j in tiles:
			var w := people[j] + (Config.FIRE_JOB_WEIGHT * work[j] if cat == "fire" else 0.0)
			served += w / maxi(cnt[j], 1)
		# Auslastung; Überlast schwächt die Wirkung
		var load := served / service_capacity(i)
		service_load[i] = load
		var strength := 1.0 if load <= 1.0 else 1.0 / load
		var field: PackedFloat32Array = coverage[cat]
		var r: int = service_radius(i)
		var half := (int(Config.SPECIALS[map.special[i]]["size"]) - 1) * 0.5
		var cx := i % size
		var cz := i / size
		for j in tiles:
			var d := Vector2(j % size - cx - half, j / size - cz - half).length()
			var v := strength * (1.0 - 0.4 * d / r)
			if v > field[j]:
				field[j] = v
		coverage[cat] = field

	# Kriminalität und Zufriedenheit
	var workforce := population * WORK_SHARE
	var jobs := float(jobs_com + jobs_ind)
	unemployment = clampf((workforce - jobs) / maxf(workforce, 1.0), 0.0, 1.0)
	var size_factor := clampf(population / 1500.0, 0.2, 1.0)    # Dörfer sind friedlich
	crime.resize(n)
	happiness.resize(n)
	var police: PackedFloat32Array = coverage["police"]
	var sum_h := 0.0
	var sum_w := 0.0
	var cov_sum := {}
	var part_land := 0.0
	var part_park := 0.0
	var part_fare := 0.0
	var part_blight := 0.0
	var blight := _blight_field()
	var tax_happy := tax_happiness()
	var fare_happy: float = Config.FARE_HAPPY[fare]
	var part_crime := 0.0
	var part_svc := {}
	for cat: String in Config.SERVICES:
		cov_sum[cat] = 0.0
		part_svc[cat] = 0.0
	for i in n:
		var zn := map.zone[i]
		var lv := map.level[i]
		if zn == Config.Zone.NONE or lv == 0:
			crime[i] = 0.0
			happiness[i] = 0.0
			continue
		var c := (0.1 + lv * 0.12 + (1.0 - land_value[i]) * 0.3 + unemployment * 0.4) * size_factor
		crime[i] = clampf(c * (1.0 - 0.85 * police[i]), 0.0, 1.0)
		if zn != Config.Zone.RES:
			happiness[i] = 0.0
			continue
		var p: float = map.residents(i)
		var land := (land_value[i] - 0.45) * 0.5
		var h := Config.HAPPY_BASE + land
		part_land += land * p
		if blight[i] > 0.0:
			var bl := minf(blight[i] * Config.VACANT_HAPPY, Config.VACANT_HAPPY_MAX)
			h -= bl
			part_blight -= bl * p
		for cat: String in Config.SERVICES:
			var spec: Array = Config.SERVICES[cat]
			var cov: float = (coverage[cat] as PackedFloat32Array)[i]
			var sv := float(spec[2]) * (2.0 * cov - 1.0) if population >= int(spec[1]) \
				else float(spec[2]) * cov * 0.5            # versorgt +, unversorgt -; vorher kleiner Bonus
			h += sv
			part_svc[cat] += sv * p
		var pk := minf(parks_near[i] * Config.HAPPY_PARK, Config.HAPPY_PARK_MAX)
		h += pk
		part_park += pk * p
		h -= crime[i] * 0.3
		part_crime -= crime[i] * 0.3 * p
		h -= tax_happy
		if fare_happy != 0.0 and road_dist[i] <= Config.ROAD_ACCESS_RANGE:
			var src := road_src[i]
			if bus_served[src] == 1 or _road_station_links.has(src):
				h += fare_happy
				part_fare += fare_happy * p
		happiness[i] = clampf(h, 0.0, 1.0)
		sum_h += happiness[i] * p
		sum_w += p
		for cat: String in Config.SERVICES:
			cov_sum[cat] += minf((coverage[cat] as PackedFloat32Array)[i], 1.0) * p
	city_happiness = sum_h / sum_w if sum_w > 0.0 else 0.6
	for cat: String in Config.SERVICES:
		city_coverage[cat] = cov_sum[cat] / sum_w if sum_w > 0.0 else 0.0
	# Aufschlüsselung für HUD und Warnungen (Summe ~ city_happiness, ohne Kappung auf 0..1)
	happy_parts = {}
	if sum_w > 0.0:
		happy_parts["Bodenwert"] = part_land / sum_w
		happy_parts["Parks"] = part_park / sum_w
		for cat: String in Config.SERVICES:
			happy_parts[Config.SERVICES[cat][0]] = part_svc[cat] / sum_w
		happy_parts["Kriminalität"] = part_crime / sum_w
		happy_parts["Steuern"] = -tax_happy
		happy_parts["ÖPNV-Tarif"] = part_fare / sum_w
		happy_parts["Leerstand"] = part_blight / sum_w

	# Bürgerwünsche: einmalige Meldung, wenn die Stadt eine Größe erreicht und der Dienst fehlt
	for cat: String in Config.SERVICES:
		var spec: Array = Config.SERVICES[cat]
		if population >= int(spec[1]) and not has_cat.has(cat) and not _needs_announced.has(cat):
			_needs_announced[cat] = true
			message.emit("Die Bürger verlangen nach: %s" % spec[0])


## Lagerkapazität je Rohstoff (Grundmenge + Lagerhäuser je Ausbaustufe, nur mit Strom).
func stock_capacity() -> int:
	var cap := Config.STOCK_BASE
	for a in _producers(true):
		cap += Config.STOCK_WAREHOUSE * map.special_level(a)
	return cap


## Anker aller Abbau-Gebäude (bzw. Lagerhäuser bei storage = true).
func _producers(storage := false) -> PackedInt32Array:
	var out := PackedInt32Array()
	var anchor := map.anchor
	var special := map.special
	for i in map.size * map.size:
		if anchor[i] == i and special[i] != Config.Special.NONE:
			var def: Dictionary = Config.SPECIALS[special[i]]
			if ((storage and def.has("storage")) or (not storage and def.has("produce"))) and map.construct[i] == 0:
				out.append(i)
	return out


## Tiles im quadratischen Umkreis r um einen Sonderbau (Grundfläche + r), nächste zuerst.
func _area_tiles(a: int, r: int) -> PackedInt32Array:
	var size := map.size
	var s: int = Config.SPECIALS[map.special[a]]["size"]
	var ax := a % size
	var az := a / size
	var cx := ax + (s - 1) * 0.5
	var cz := az + (s - 1) * 0.5
	var tiles := []
	for z in range(maxi(az - r, 0), mini(az + s + r, size)):
		for x in range(maxi(ax - r, 0), mini(ax + s + r, size)):
			tiles.append([absf(x - cx) + absf(z - cz), z * size + x])
	tiles.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
	var out := PackedInt32Array()
	for t: Array in tiles:
		out.append(int(t[1]))
	return out


## Monatlicher Abbau: Holzfäller fällt Bäume, Steinbruch liefert Stein, Grube/Mine entnehmen Vorkommen.
## Überschuss über der Lagerkapazität wird exportiert (Einnahme).
func _produce() -> void:
	production = {}
	exported = {}
	for r: String in Config.RESOURCES:
		production[r] = 0.0
		exported[r] = 0.0
		if not stock.has(r):
			stock[r] = 0.0
	producer_info = {}
	_compute_delivery()
	var changed := Rect2i()
	var any := false
	var size := map.size
	for a in _producers():
		var def: Dictionary = Config.SPECIALS[map.special[a]]
		var lv := map.special_level(a)
		var out := {}
		var issue := ""
		if not special_powered(a):
			producer_info[a] = {"out": out, "issue": "Kein Strom - steht still"}
			continue
		var linked := delivers(a)
		var buf: Dictionary = local_buffer.get(a, {})
		var buf_cap := Config.LOCAL_BUFFER * lv
		if not linked and _buffer_sum(buf) >= buf_cap:
			producer_info[a] = {"out": out, "issue": "Keine Straße zum Lager - eigener Vorrat voll (%d/%d), steht still" % [
				int(_buffer_sum(buf)), buf_cap]}
			continue
		match def["produce"]:
			"wood":
				var left := Config.LUMBER_TREES * lv
				for j in _area_tiles(a, Config.LUMBER_RANGE):
					if left <= 0:
						break
					if map.feature[j] == Config.Feature.TREE and map.zone[j] == Config.Zone.NONE:
						map.feature[j] = Config.Feature.NONE
						out["wood"] = float(out.get("wood", 0.0)) + Config.WOOD_PER_TREE
						left -= 1
						var r := Rect2i(j % size, j / size, 1, 1)
						changed = r if not any else changed.merge(r)
						any = true
				if out.is_empty():
					issue = "Kein Wald mehr in Reichweite (%d Tiles)" % Config.LUMBER_RANGE
			"stone", "pit", "mine":
				var kind: String = def["produce"]
				var rng_r: int = {"stone": Config.QUARRY_RANGE, "pit": Config.PIT_RANGE, "mine": Config.MINE_RANGE}[kind]
				var kinds: Array = {"stone": ["stone"], "pit": ["sand", "clay"], "mine": ["coal", "iron", "gold"]}[kind]
				var budget := {}
				for k: String in kinds:
					var rate := Config.QUARRY_STONE if kind == "stone" else (Config.PIT_RATE if kind == "pit" else int(Config.MINE_RATE[k]))
					budget[k] = rate * lv * (Config.TECH_MINING if tech("deep_mining") else 1.0)
				for j in _area_tiles(a, rng_r):
					var amt := map.ore_amt[j]
					if amt == 0:
						continue
					var res: String = Config.ORE_RESOURCE[map.ore[j]]
					if not budget.has(res) or int(budget[res]) <= 0:
						continue
					# Ein Punkt Vorkommen = ORE_UNIT Einheiten; Bruchteile pro Tile merken
					var avail := amt * Config.ORE_UNIT - int(_ore_used.get(j, 0))
					var take := mini(avail, int(budget[res]))
					var used := int(_ore_used.get(j, 0)) + take
					map.ore_amt[j] = amt - used / Config.ORE_UNIT
					_ore_used[j] = used % Config.ORE_UNIT
					budget[res] = int(budget[res]) - take
					out[res] = float(out.get(res, 0.0)) + take
					if map.ore_amt[j] == 0:
						var r := Rect2i(j % size, j / size, 1, 1)
						changed = r if not any else changed.merge(r)
						any = true
				if out.is_empty():
					issue = "Kein Vorkommen mehr in Reichweite (%d Tiles) - Ansicht Rohstoffe" % rng_r
		if linked:
			# Anschluss da: eigener Vorrat (falls vorhanden) wird mitgeliefert
			for res: String in buf:
				stock[res] = float(stock.get(res, 0.0)) + float(buf[res])
			local_buffer.erase(a)
			for res: String in out:
				production[res] = float(production[res]) + float(out[res])
				stock[res] = float(stock[res]) + float(out[res])
		else:
			for res: String in out:
				var room := float(buf_cap) - _buffer_sum(buf)
				buf[res] = float(buf.get(res, 0.0)) + minf(float(out[res]), maxf(room, 0.0))
			local_buffer[a] = buf
			issue = "Keine Straße zum Lager - fördert in eigenen Vorrat (%d/%d)" % [int(_buffer_sum(buf)), buf_cap]
		producer_info[a] = {"out": out, "issue": issue}
	# Warnung, wenn ein Abbau-Gebäude neu ohne Lieferweg dasteht (einmal je Gebäude)
	var unlinked := {}
	var fresh: Array[int] = []
	for a in _producers():
		if special_powered(a) and not delivers(a):
			unlinked[a] = true
			if not _delivery_warned.has(a):
				fresh.append(a)
	_delivery_warned = unlinked
	if not fresh.is_empty():
		var f := fresh[0]
		var text := "%s bei %d,%d: keine Straße zum Lager - fördert nur in eigenen Vorrat" % [
			Config.SPECIALS[map.special[f]]["name"], f % size, f / size]
		if fresh.size() > 1:
			text = "%d Abbau-Gebäude ohne Straße zum Lager (z.B. %s bei %d,%d) - Ansicht Rohstoffe zeigt sie rot" % [
				fresh.size(), Config.SPECIALS[map.special[f]]["name"], f % size, f / size]
		alert.emit(text, Vector2i(f % size, f / size))
	if any:
		map.notify_changed(changed, false)


## Verarbeitung (Sägewerk, Ziegelei, Glashütte, Stahlwerk) und Kohleverbrauch der Kraftwerke.
## Knappe Rohstoffe -> anteilige Verarbeitung. Fehlende Kraftwerkskohle wird zugekauft.
## Erneuerung (monatlich): Wald breitet sich aus, Baumschulen pflanzen, Adern regenerieren langsam,
## Prospektoren finden neue Adern.
func _renew() -> void:
	var size := map.size
	var n := size * size
	var feature := map.feature
	var zone := map.zone
	var road := map.road
	var rail := map.rail
	var special := map.special
	var height := map.height
	var ore := map.ore
	var ore_amt := map.ore_amt
	var wl := Config.WATER_LEVEL
	var changed := PackedInt32Array()      # einzeln melden: ein Sammel-Rechteck über die Karte baut alle Chunks neu
	# Freies Gras: keine Bebauung, kein Wasser, kein Sand (Strand)
	var free := func(i: int) -> bool:
		return feature[i] == Config.Feature.NONE and zone[i] == Config.Zone.NONE and road[i] == 0 and rail[i] == 0 \
			and special[i] == Config.Special.NONE and height[i] >= wl and map.power_line[i] == 0 \
			and not (ore[i] == Config.Ore.SAND and ore_amt[i] > 0)
	# 1) Natürliche Ausbreitung: Stichprobe von n·FOREST_SPREAD Tiles (gleicher Erwartungswert wie Wurf je Tile, viel
	#    billiger); nur Lücken mit FOREST_GAP+ Baum-Nachbarn inkl. Diagonalen wachsen zu (gerodete Stellen erholen
	#    sich, Waldränder wandern nicht), und nur solange weniger als FOREST_MAX_SHARE des Landes Wald ist.
	#    Früher reichten 2 Nachbarn -> nach Jahrhunderten war die ganze Karte zugewachsen.
	var trees := 0
	var land := 0
	for i in n:
		if feature[i] == Config.Feature.TREE:
			trees += 1
		if height[i] >= wl:
			land += 1
	var spread := roundi(n * Config.FOREST_SPREAD) if trees < land * Config.FOREST_MAX_SHARE else 0
	for k in spread:
		var i := _rng.randi() % n
		if feature[i] != Config.Feature.NONE:
			continue
		var x := i % size
		var z := i / size
		var t := 0
		for dz in range(maxi(z - 1, 0), mini(z + 2, size)):
			for dx in range(maxi(x - 1, 0), mini(x + 2, size)):
				if feature[dz * size + dx] == Config.Feature.TREE:
					t += 1
		if t >= Config.FOREST_GAP and free.call(i):
			feature[i] = Config.Feature.TREE
			changed.append(i)
	# Sonderbauten der Erneuerung einsammeln
	var nurseries := PackedInt32Array()
	var prospectors := PackedInt32Array()
	for a in n:
		if special[a] == Config.Special.NURSERY or special[a] == Config.Special.PROSPECTOR:
			if map.anchor[a] == a and special_powered(a):
				if special[a] == Config.Special.NURSERY:
					nurseries.append(a)
				else:
					prospectors.append(a)
	# 2) Baumschulen pflanzen im Umkreis (nächste freie Tiles zuerst)
	planted = 0
	planted_at.clear()
	for a in nurseries:
		var left := Config.NURSERY_TREES * map.special_level(a)
		var area := _area_tiles(a, Config.NURSERY_RANGE)
		var wood := 0
		for j in area:
			if feature[j] == Config.Feature.TREE:
				wood += 1
		if wood >= area.size() * Config.NURSERY_MAX_SHARE:
			planted_at[a] = -1         # Umkreis ist Wald genug (Holzfäller schafft wieder Platz)
			continue
		for j in area:
			if left <= 0:
				break
			if free.call(j):
				feature[j] = Config.Feature.TREE
				changed.append(j)
				left -= 1
				planted += 1
		planted_at[a] = Config.NURSERY_TREES * map.special_level(a) - left
	# 3) Adern regenerieren sehr langsam bis zur Startmenge (Fels/Erz/Ton, nicht Sand); Stichprobe n·ORE_REGROW
	for k in roundi(n * Config.ORE_REGROW):
		var i := _rng.randi() % n
		if ore[i] != Config.Ore.NONE and ore[i] != Config.Ore.SAND and ore_amt[i] < Config.ORE_MIN:
			if ore_amt[i] == 0:
				changed.append(i)
			ore_amt[i] += 1
	# 4) Prospektoren
	for a in prospectors:
		if _rng.randf() >= Config.PROSPECT_CHANCE * map.special_level(a):
			continue
		var found := _prospect(a, free)
		if not found.is_empty():
			var c: int = found[0]
			var kind: String = Config.RESOURCES[Config.ORE_RESOURCE[ore[c]]]["name"]
			last_found[a] = "%s-Ader bei %d,%d" % [kind, c % size, c / size]
			alert.emit("Prospektor: neue %s-Ader gefunden bei %d,%d (%d Tiles)" % [kind, c % size, c / size, found.size()],
				Vector2i(c % size, c / size))
			changed.append_array(found)
	for i in changed:
		map.notify_changed(Rect2i(i % size, i / size, 1, 1), false)


## Neue Ader im Umkreis: zufälliges freies Hügel-Tile, Erzart nach Höhe (Gold hoch/selten, Eisen, Kohle), 3-6 Tiles.
func _prospect(a: int, free: Callable) -> Array[int]:
	var size := map.size
	var wl := Config.WATER_LEVEL
	var out: Array[int] = []
	var cands := PackedInt32Array()
	for j in _area_tiles(a, Config.PROSPECT_RANGE):
		if map.ore[j] == Config.Ore.NONE and map.height[j] >= wl + 2 and free.call(j):
			cands.append(j)
	if cands.is_empty():
		return out
	var start := cands[_rng.randi() % cands.size()]
	var h := map.height[start]
	var kind := Config.Ore.COAL
	if h >= wl + 5 and _rng.randf() < 0.25:
		kind = Config.Ore.GOLD
	elif h >= wl + 4 and _rng.randf() < 0.5:
		kind = Config.Ore.IRON
	var want := _rng.randi_range(3, 6)
	var frontier: Array[int] = [start]
	while not frontier.is_empty() and out.size() < want:
		var j: int = frontier.pop_front()
		if out.has(j) or map.ore[j] != Config.Ore.NONE or map.height[j] < wl + 1 or not free.call(j):
			continue
		map.ore[j] = kind
		map.ore_amt[j] = _rng.randi_range(Config.PROSPECT_MIN, Config.ORE_MIN)
		out.append(j)
		var x := j % size
		var z := j / size
		for d: Vector2i in DIRS:
			if map.in_bounds(x + d.x, z + d.y):
				frontier.append(map.idx(x + d.x, z + d.y))
	return out


## Abriss eines Gebäudes der Stufe lv: Anteil der verbauten Baustoffe zurück ins Lager (tile: im Einzugskreis eines
## Recyclinghofs mehr). Rückgabe: zurückgewonnene Mengen.
func recycle(zn: int, lv: int, tile := -1) -> Dictionary:
	var mats := {}
	if not Config.MATERIAL_COST.has(zn):
		return mats
	for k in range(2, lv + 1):
		var cost: Dictionary = Config.MATERIAL_COST[zn][k]
		for r: String in cost:
			mats[r] = float(mats.get(r, 0.0)) + float(cost[r])
	return recycle_materials(mats, tile)


## Abriss eines Sonderbaus: Anteil des Baumaterials (inkl. Ausbaustufen) zurück ins Lager.
func recycle_special(sp: int, lv: int, tile := -1) -> Dictionary:
	var base: Dictionary = Config.SPECIAL_MATERIALS.get(sp, {})
	var f := 1.0
	for k in range(1, lv):
		f += Config.UPGRADE_MATERIALS * k
	return recycle_materials(scale_materials(base, f), tile)


func recycle_materials(mats: Dictionary, tile := -1) -> Dictionary:
	var back := {}
	if mats.is_empty():
		return back
	var share := Config.RECYCLE_SHARE_YARD if (recycler_covers(tile) if tile >= 0 else has_recycler()) else Config.RECYCLE_SHARE
	for r: String in mats:
		back[r] = float(mats[r]) * share
		stock[r] = float(stock.get(r, 0.0)) + float(back[r])
	return back


static func scale_materials(mats: Dictionary, f: float) -> Dictionary:
	var out := {}
	for r: String in mats:
		out[r] = float(mats[r]) * f
	return out


# ---------------------------------------------------------------- Forschung

func tech(id: String) -> bool:
	return research_done.has(id)


## Akademikerquote = Anteil der Einwohner im Einzugsbereich einer Universität (Anzeige).
func academics() -> float:
	return float(city_coverage.get("university", 0.0))


## Akademiker = von Universitäten versorgte Einwohner, je Uni höchstens ihre Kapazität.
func academics_count() -> float:
	var sum := 0.0
	for a: int in service_load:
		if map.anchor[a] == a and map.special[a] == Config.Special.UNIVERSITY and special_powered(a):
			var cap := service_capacity(a)
			sum += minf(float(service_load[a]) * cap, cap)
	return sum


## Anteil der Institutsleistung, den die Akademiker tragen (0.1 .. 1).
func academic_factor() -> float:
	if _inst_levels == 0:
		return 0.0
	return clampf(academics_count() / (Config.ACADEMICS_PER_LEVEL * _inst_levels), Config.RESEARCH_MIN_ACADEMICS, 1.0)


## Summe der Ausbaustufen aller Institute mit Strom (gezählt in _recount).
func institute_levels() -> int:
	return _inst_levels


static func budget_factor(budget: float) -> float:
	return 0.25 + 0.75 * sqrt(maxf(budget, 0.0) / Config.RESEARCH_BUDGET_REF)


## Forschungspunkte je Monat beim eingestellten Budget (0 ohne Institut).
func research_points() -> float:
	return Config.RESEARCH_POINTS * institute_levels() * academic_factor() * budget_factor(research_budget)


## Geschätzte Dauer in Monaten bei Budget b (-1 = ohne Institut nicht möglich).
func research_eta(id: String, b: float) -> int:
	var rate := Config.RESEARCH_POINTS * institute_levels() * academic_factor() * budget_factor(b)
	if rate <= 0.0:
		return -1
	var left := float(Config.RESEARCH[id]["points"]) - (research_progress if research_current == id else 0.0)
	return ceili(left / rate)


## Was ein abgeschlossenes Projekt in dieser Stadt bewirkt: {"lines": [...], "tile": Vector2i (-1 = keins)}.
func tech_impact(id: String) -> Dictionary:
	var lines := PackedStringArray()
	var tile := Vector2i(-1, -1)
	var anchors: Array[int] = []
	var count := 0
	var before := 0.0
	for a in map.size * map.size:
		if map.anchor[a] != a or map.special[a] == Config.Special.NONE:
			continue
		var def: Dictionary = Config.SPECIALS[map.special[a]]
		var hit := false
		match id:
			"deep_mining":
				hit = def.has("produce") and str(def["produce"]) != "wood"
				if hit:
					for r: String in ((producer_info.get(a, {}) as Dictionary).get("out", {}) as Dictionary):
						before += float(producer_info[a]["out"][r])
			"plant_filter":
				hit = map.special[a] == Config.Special.COAL
			"blast_furnace":
				hit = def.has("process") and (def["process"]["in"] as Dictionary).has("coal")
				if hit:
					before += float(((producer_info.get(a, {}) as Dictionary).get("in", {}) as Dictionary).get("coal", 0.0))
		if hit:
			count += 1
			anchors.append(a)
			if tile.x < 0:
				tile = Vector2i(a % map.size, a / map.size)
	match id:
		"deep_mining":
			lines.append(("%d Abbau-Betriebe fördern ab sofort 50 %% mehr" % count) if count > 0
				else "Jede Mine, jeder Steinbruch und jede Grube fördert 50 % mehr")
			if before > 0.0:
				lines.append("Förderung: ~%d statt %d Einheiten je Monat" % [roundi(before * Config.TECH_MINING), roundi(before)])
			lines.append("Sichtbar: Fördertürme an Minen und Steinbrüchen")
		"efficient_build":
			lines.append("Polizeiwache: %d statt %d Ziegel" % [roundi(20 * Config.TECH_BUILD), 20])
			lines.append("Wohnhaus Stufe 3: %d statt %d Ziegel" % [roundi(8 * Config.TECH_BUILD), 8])
			lines.append("Gilt für Bauen, Ausbau und Wachsen - Kostenblase zeigt den Rabatt")
		"plant_filter":
			lines.append("%s: Verschmutzung %d -> %d" % [("%d Kohlekraftwerk(e)" % count) if count > 0 else "Jedes Kohlekraftwerk",
				roundi(Config.POLLUTION_COAL), roundi(Config.POLLUTION_COAL * Config.TECH_FILTER)])
			lines.append("Sichtbar: Filter auf den Schornsteinen, weißer dünner Rauch")
		"solar":
			lines.append("Solarfeld in der Strom-Gruppe: 50 MW tagsüber, sauber")
			lines.append("Nachts liefert es nichts - Grundlast (Kohle, Biomasse, Wind) oder Speicher behalten")
			lines.append("Nächstes Projekt: Batteriespeicher")
		"concrete":
			lines.append("Betonwerk in der Verarbeitung: 10 Stein + 10 Sand + 1 Kohle -> 12 Beton")
			lines.append("Beton braucht man für Hochhäuser und Bürotürme (sonst Zukauf)")
		"highrise":
			lines.append("Wohnhäuser ab 75 % Bodenwert wachsen zum Hochhaus: 200 statt 80 Einwohner")
			lines.append("Braucht Beton, Glas und Stahl - Bodenwert heben: Parks, Dienste, weg von Industrie")
		"offices":
			lines.append("Gewerbe direkt an der Straße nahe Kreuzungen (ab 60 % Bodenwert) wächst zum Büroturm: 120 Jobs")
		"hightech":
			lines.append("Neues Zonen-Werkzeug Hightech-Industrie (Industrie-Gruppe)")
			lines.append("85 % weniger Verschmutzung, 60 % mehr Steuer - wächst nur im Einzugsbereich einer Universität")
		"traffic":
			lines.append("Ampeln und Leitsystem: Straßen vertragen 25 % mehr Verkehr, Stau sinkt")
		"hydro":
			lines.append("Wasserkraftwerk in der Strom-Gruppe: 120 MW Tag und Nacht, ohne Abgas")
			lines.append("Nur direkt am Wasser baubar (Fluss oder See)")
		"pumped":
			lines.append("Pumpspeicher in der Strom-Gruppe: speichert 150 MW Tagesüberschuss")
			lines.append("Braucht einen Hang: mindestens 3 Blöcke über dem Wasser, Wasser in der Nähe")
		"salt":
			lines.append("Salzspeicher in der Strom-Gruppe: 300 MW für die Nacht, überall baubar")
			lines.append("Klick auf ein Kohlekraftwerk rüstet es zum halben Preis zum Salzspeicher um")
		"battery":
			lines.append("Batteriespeicher in der Strom-Gruppe: lädt tagsüber, liefert nachts bis 40 MW")
			lines.append("Mit Solar + Speicher kann Kohle Schritt für Schritt ersetzt werden")
		"blast_furnace":
			lines.append("%s halb so viel Kohle und verschmutzen 40 %% weniger" % [("%d Werk(e) brauchen" % count) if count > 0
				else "Ziegelei, Glashütte und Stahlwerk brauchen"])
			if before > 0.0:
				lines.append("Kohle für Werke: ~%d statt %d je Monat" % [roundi(before * Config.TECH_FURNACE_COAL), roundi(before)])
	return {"lines": lines, "tile": tile, "anchors": anchors}


## Warum ein Projekt nicht gestartet werden kann ("" = möglich).
func research_blocker(id: String) -> String:
	if tech(id):
		return "erforscht"
	if research_current == id:
		return "läuft"
	if research_current != "":
		return "erst laufendes Projekt beenden"
	for req: String in Config.RESEARCH[id]["requires"]:
		if not tech(req):
			return "braucht: %s" % Config.RESEARCH[req]["name"]
	if institute_levels() == 0:
		return "kein Forschungsinstitut (mit Strom)"
	return ""


static func research_start_cost(id: String) -> float:
	return float(Config.RESEARCH[id]["points"]) * Config.RESEARCH_START_PER_POINT


## Projekt starten: Gold aus dem Lager, Rest sofort zukaufen. Rückgabe: Fehlertext oder "".
func start_research(id: String) -> String:
	var why := research_blocker(id)
	if why != "":
		return why
	var mats := {"gold": float(Config.RESEARCH[id]["gold"])}
	var price: float = build_need(mats)[1]
	var start := research_start_cost(id)
	if not can_afford(price + start):
		return "Nicht genug Geld: Start $%d + Gold-Zukauf $%d" % [int(start), int(price)]
	spend(start)
	use_build_materials(mats)
	research_current = id
	research_progress = 0.0
	stats_changed.emit()
	return ""


## Monatlich: Budget ausgeben (nur wenn geforscht wird), Punkte sammeln, Abschluss melden.
func _research() -> void:
	research_rate = 0.0
	research_spent = 0.0
	if research_current == "" or institute_levels() == 0:
		return
	research_spent = research_budget
	research_rate = research_points()
	research_progress += research_rate
	var def: Dictionary = Config.RESEARCH[research_current]
	if research_progress >= float(def["points"]):
		research_done.append(research_current)
		var done_id := research_current
		message.emit("Forschung abgeschlossen: %s - %s" % [def["name"], def["desc"]])
		research_current = ""
		StructureGenerator.techs = research_done      # Modelle (Förderturm, Filter ...) vor dem Neuaufbau kennen
		for a: int in tech_impact(done_id)["anchors"]:
			var sz: int = Config.SPECIALS[map.special[a]]["size"]
			map.notify_changed(Rect2i(a % map.size, a / map.size, sz, sz), false)   # einzeln, nie Sammel-Rechteck
		research_finished.emit(done_id)
		research_progress = 0.0


## Leerstand im Umkreis (VACANT_RANGE, Quadrat): Anzahl leerer Gebäude je Tile -> Verfall des Viertels.
func _blight_field() -> PackedFloat32Array:
	var n := map.size * map.size
	var f := PackedFloat32Array()
	f.resize(n)
	var r := Config.VACANT_RANGE
	for i in n:
		if not map.is_vacant(i):
			continue
		var cx := i % map.size
		var cz := i / map.size
		for z in range(maxi(cz - r, 0), mini(cz + r + 1, map.size)):
			for x in range(maxi(cx - r, 0), mini(cx + r + 1, map.size)):
				if x != cx or z != cz:
					f[z * map.size + x] += 1.0
	return f


func vacant_count() -> int:
	var c := 0
	for i in map.size * map.size:
		if map.is_vacant(i):
			c += 1
	return c


# ---------------------------------------------------------------- Aufbau-Start / Rathaus

## Baustoffe beim Wachsen: im Aufbau-Start immer (auch Stufe 1: etwas Holz), klassisch erst ab MATERIAL_FROM_POP.
func materials_on() -> bool:
	return game_mode == "build" or population >= Config.MATERIAL_FROM_POP


## Zukauf (Handel) möglich? Im Aufbau-Start erst ab Rathaus-Stufe 2 – vorher nur selbst gesammeltes Material.
func can_trade() -> bool:
	return game_mode != "build" or hall_level >= 2


## Lager-Netz: Einzugskreise von Rathaus-Hof und Lagerhäusern (fertig gebaut, mit Strom) -> store_cover je Tile.
func _compute_store_cover() -> void:
	var n := map.size * map.size
	store_cover.resize(n)
	store_cover.fill(0)
	for a in n:
		if map.anchor[a] != a or map.special[a] == Config.Special.NONE:
			continue
		if not Config.SPECIALS[map.special[a]].has("storage") or map.construct[a] > 0:
			continue
		var r := Config.HALL_STORE_RADIUS if map.special[a] == Config.Special.CITYHALL else \
			int(Config.STORE_RADIUS[map.special_level(a)])
		var s: int = Config.SPECIALS[map.special[a]]["size"]
		var cx := a % map.size + (s - 1) * 0.5
		var cz := a / map.size + (s - 1) * 0.5
		for z in range(maxi(int(cz) - r, 0), mini(int(cz) + r + 2, map.size)):
			for x in range(maxi(int(cx) - r, 0), mini(int(cx) + r + 2, map.size)):
				if Vector2(x - cx, z - cz).length() <= r:
					store_cover[z * map.size + x] = 1


## Baustellen (nur Aufbau-Start) einen Monat weiterbauen: im Lager-Kreis 2 halbe Monate, sonst 1 (STORE_SLOW).
func _advance_construction() -> void:
	if game_mode != "build":
		return
	_compute_store_cover()
	var n := map.size * map.size
	var con := map.construct
	for i in n:
		if con[i] == 0:
			continue
		var step := 2 if store_cover[i] == 1 else 2 / Config.STORE_SLOW
		con[i] = maxi(int(con[i]) - step, 0)
		if con[i] == 0:
			var s := 1
			if map.special[i] != Config.Special.NONE and map.anchor[i] == i:
				s = Config.SPECIALS[map.special[i]]["size"]
			map.notify_changed(Rect2i(i % map.size, i / map.size, s, s), map.special[i] != Config.Special.NONE)


## Gründung (Aufbau-Start, Stufe 1): Arbeitsplätze am Rathaus und in Abbau-Betrieben mit Strom (es gibt noch kein
## Gewerbe/keine Industrie). Sonst 0.
func founding_jobs() -> float:
	if game_mode != "build" or hall_level >= 2:
		return 0.0
	var jobs := 0.0
	for a in map.size * map.size:
		if map.anchor[a] != a or map.special[a] == Config.Special.NONE:
			continue
		if map.special[a] == Config.Special.CITYHALL:
			jobs += Config.FOUNDING_JOBS_HALL
		elif Config.SPECIALS[map.special[a]].has("produce") and special_powered(a):
			jobs += Config.FOUNDING_JOBS_PRODUCER
	return jobs


## Was fehlt für die nächste Rathaus-Stufe: {"level", "name", "pop", "mats", "missing": [Texte], "ok": bool}.
func hall_next() -> Dictionary:
	var nxt := hall_level + 1
	if game_mode != "build" or nxt >= Config.HALL_LEVELS.size():
		return {}
	var def: Dictionary = Config.HALL_LEVELS[nxt]
	var missing := PackedStringArray()
	if population < int(def.get("pop", 0)):
		missing.append("%d Einwohner" % (int(def["pop"]) - population))
	var mats: Dictionary = def.get("mats", {})
	for r: String in mats:
		var short := float(mats[r]) - float(stock.get(r, 0.0))
		if short > 0.0:
			missing.append("%d %s" % [ceili(short), Config.RESOURCES[r]["name"]])
	return {"level": nxt, "name": def["name"], "pop": int(def.get("pop", 0)), "mats": mats, "missing": missing,
		"ok": missing.is_empty()}


## Rathaus ausbauen: Material aus dem Lager. Rückgabe: Fehlertext oder "".
func upgrade_hall() -> String:
	var nxt := hall_next()
	if nxt.is_empty():
		return "Keine weitere Stufe"
	if not bool(nxt["ok"]):
		return "Es fehlen noch: " + ", ".join(nxt["missing"])
	for r: String in (nxt["mats"] as Dictionary):
		stock[r] = float(stock.get(r, 0.0)) - float(nxt["mats"][r])
	hall_level = int(nxt["level"])
	for a in map.size * map.size:
		if map.anchor[a] == a and map.special[a] == Config.Special.CITYHALL:
			map.slevel[a] = mini(hall_level, 3)
			map.notify_changed(Rect2i(a % map.size, a / map.size, 3, 3), false)
	message.emit("Rathaus ausgebaut: Stufe %d (%s)" % [hall_level, nxt["name"]])
	stats_changed.emit()
	return ""


## Zufriedenheits-Abzug durch die Wohnsteuer (negativ = Bonus bei Steuer unter neutral).
func tax_happiness() -> float:
	var d := float(tax[Config.Zone.RES]) - Config.TAX_NEUTRAL[Config.Zone.RES]
	if d <= 0.0:
		return d * Config.TAX_HAPPY
	var q := maxf(d - Config.TAX_HAPPY_SQ_FROM, 0.0)
	return d * Config.TAX_HAPPY_UP + q * q * Config.TAX_HAPPY_SQ


static func admin_for(pop: int) -> float:
	var over := maxf(float(pop - Config.ADMIN_FROM), 0.0)
	return Config.ADMIN_RATE * over * over / Config.ADMIN_SCALE


## Baumaterial für eine Bauaktion: [fehlende Mengen, sofortiger Zukaufpreis] gemessen am Lager.
func build_need(mats: Dictionary) -> Array:
	var missing := {}
	var price := 0.0
	for r: String in mats:
		var short := float(mats[r]) - float(stock.get(r, 0.0))
		if short > 0.0:
			missing[r] = short
			price += short * float(Config.RESOURCES[r]["price"]) * Config.IMPORT_FACTOR
	return [missing, ceilf(price)]


## Baumaterial verbrauchen: aus dem Lager, Rest sofort zukaufen (Geld wird direkt abgebucht). Rückgabe: Zukaufpreis.
func use_build_materials(mats: Dictionary) -> float:
	var need := build_need(mats)
	var missing: Dictionary = need[0]
	for r: String in mats:
		var take := minf(float(mats[r]), float(stock.get(r, 0.0)))
		stock[r] = float(stock.get(r, 0.0)) - take
		materials_used[r] = float(materials_used.get(r, 0.0)) + float(mats[r])
	for r: String in missing:
		imported[r] = float(imported.get(r, 0.0)) + float(missing[r])
	var price: float = need[1]
	if price > 0.0:
		build_imports += price
		spend(price)
	return price


## Liegt Tile i im Einzugskreis eines Recyclinghofs mit Strom?
func recycler_covers(i: int) -> bool:
	var x := i % map.size
	var z := i / map.size
	for a in _recyclers():
		var r := service_radius(a) + 1
		if Vector2(x - a % map.size - 0.5, z - a / map.size - 0.5).length() <= r:
			return true
	return false


func _recyclers() -> PackedInt32Array:
	var out := PackedInt32Array()
	for a in map.size * map.size:
		if map.special[a] == Config.Special.RECYCLER and map.anchor[a] == a and special_powered(a):
			out.append(a)
	return out


## Instandhaltung (monatlich, Etappe "abschluss" nach den Werken): Gebäude ab Stufe 2 verbrauchen MAINT_RATE ihres
## Baumaterials. Recyclinghöfe holen im Einzugskreis RECYCLE_MAINT davon zurück (Kapazität je Stufe). Fehlendes wird
## zugekauft; reicht auch das Geld nicht (MATERIAL_DEBT), steigt maint_short -> Gebäude verfallen langsam (_grow_rows).
func _maintenance() -> void:
	last_maint = {}
	maint_recycled = 0.0
	maint_short = 0.0
	if population < Config.MATERIAL_FROM_POP:
		return
	var n := map.size * map.size
	var recs := _recyclers()
	var covered := PackedByteArray()
	covered.resize(n)
	var cap := 0.0
	for a in recs:
		cap += Config.RECYCLE_CAP[map.special_level(a)]
		var r := service_radius(a) + 1
		var ax := a % map.size
		var az := a / map.size
		for z in range(maxi(az - r, 0), mini(az + r + 2, map.size)):
			for x in range(maxi(ax - r, 0), mini(ax + r + 2, map.size)):
				if Vector2(x - ax - 0.5, z - az - 0.5).length() <= r:
					covered[z * map.size + x] = 1
	var need := {}
	var in_reach := 0.0
	var zone := map.zone
	var level := map.level
	var bf := build_factor()
	for i in n:
		var lv := level[i]
		if lv < 2 or zone[i] == Config.Zone.NONE or map.empty[i] >= 100:
			continue
		var cost: Dictionary = Config.MATERIAL_COST[zone[i]][lv]
		for r: String in cost:
			var q := float(cost[r]) * Config.MAINT_RATE * bf
			need[r] = float(need.get(r, 0.0)) + q
			if covered[i] == 1:
				in_reach += q * Config.RECYCLE_MAINT
	# Recycling deckt einen Teil (gleichmäßig über alle Materialien)
	var total := 0.0
	for r: String in need:
		total += float(need[r])
	maint_recycled = minf(in_reach, cap)
	var cover := maint_recycled / total if total > 0.0 else 0.0
	var unpaid_val := 0.0
	var total_val := 0.0
	for r: String in need:
		var q := float(need[r]) * (1.0 - cover)
		var take := minf(q, float(stock.get(r, 0.0)))
		stock[r] = float(stock.get(r, 0.0)) - take
		var miss := q - take
		var price := miss * float(Config.RESOURCES[r]["price"]) * Config.IMPORT_FACTOR
		total_val += q * float(Config.RESOURCES[r]["price"])
		if miss > 0.0:
			if money - _import_pending - price >= -Config.MATERIAL_DEBT:
				_buy(r, miss)
			else:
				unpaid_val += miss * float(Config.RESOURCES[r]["price"])
		last_maint[r] = float(need[r])
		materials_used[r] = float(materials_used.get(r, 0.0)) + q
	maint_short = clampf(unpaid_val / total_val, 0.0, 1.0) if total_val > 0.0 else 0.0


func has_recycler() -> bool:
	for a in map.size * map.size:
		if map.anchor[a] == a and map.special[a] == Config.Special.RECYCLER and special_powered(a):
			return true
	return false


func _buffer_sum(buf: Dictionary) -> float:
	var t := 0.0
	for r: String in buf:
		t += float(buf[r])
	return t


## Lieferwege: Straßennetze (zusammenhängende Straßen) bestimmen; "Lager-Netze" = Netze mit Lagerhaus,
## ohne Lagerhaus das Netz mit den meisten Einwohnern (Hauptnetz der Stadt).
func _compute_delivery() -> void:
	var size := map.size
	var n := size * size
	var road := map.road
	var h := map.height
	var net := PackedInt32Array()
	net.resize(n)
	net.fill(-1)
	var queue := PackedInt32Array()
	var id := 0
	for s in n:
		if road[s] == 0 or net[s] != -1:
			continue
		net[s] = id
		queue.resize(0)
		queue.append(s)
		var head := 0
		while head < queue.size():
			var u := queue[head]
			head += 1
			var x := u % size
			var z := u / size
			for v: int in [u + 1 if x + 1 < size else -1, u - 1 if x > 0 else -1, u + size if z + 1 < size else -1,
					u - size if z > 0 else -1]:
				if v >= 0 and road[v] != 0 and net[v] == -1 and absi(h[v] - h[u]) <= 1:
					net[v] = id
					queue.append(v)
		id += 1
	_road_net = net
	_store_nets = {}
	for a in _producers(true):
		for r in _access_roads(a):
			_store_nets[net[r]] = true
	if _store_nets.is_empty() and road_src.size() == n:
		var pop := {}
		for i in n:
			if map.zone[i] == Config.Zone.RES and map.level[i] > 0 and road_dist[i] <= Config.ROAD_ACCESS_RANGE:
				var c := net[road_src[i]]
				pop[c] = int(pop.get(c, 0)) + roundi(map.residents(i))
		var best := -1
		for c: int in pop:
			if best < 0 or int(pop[c]) > int(pop[best]):
				best = c
		if best >= 0:
			_store_nets[best] = true


## Straßen-Tiles direkt neben der Grundfläche eines Sonderbaus.
func _access_roads(a: int) -> PackedInt32Array:
	var size := map.size
	var s: int = Config.SPECIALS[map.special[a]]["size"]
	var ax := a % size
	var az := a / size
	var out := PackedInt32Array()
	for z in range(az - 1, az + s + 1):
		for x in range(ax - 1, ax + s + 1):
			var edge := (x == ax - 1 or x == ax + s) != (z == az - 1 or z == az + s)
			if edge and map.is_road(x, z):
				out.append(map.idx(x, z))
	return out


## Liefert dieser Sonderbau ins Lager (Straße daneben, gleiches Netz wie ein Lager)?
func delivers(a: int) -> bool:
	if _road_net.size() != map.size * map.size:
		return true
	for r in _access_roads(a):
		if _store_nets.has(_road_net[r]):
			return true
	return false


## Für die Bau-Vorschau: Lage x,z (Größe s) hätte Straße daneben / Anschluss ans Lager?
func delivery_at(t: Vector2i, s: int) -> int:
	if _road_net.size() != map.size * map.size:
		return 2
	var any_road := false
	for z in range(t.y - 1, t.y + s + 1):
		for x in range(t.x - 1, t.x + s + 1):
			var edge := (x == t.x - 1 or x == t.x + s) != (z == t.y - 1 or z == t.y + s)
			if edge and map.is_road(x, z):
				any_road = true
				if _store_nets.has(_road_net[map.idx(x, z)]):
					return 2       # angeschlossen
	return 1 if any_road else 0    # 1 = Straße, aber anderes Netz; 0 = keine Straße


func _process_goods() -> void:
	var furnace := Config.TECH_FURNACE_COAL if tech("blast_furnace") else 1.0
	coal_burned = 0.0
	imported = {}
	for r: String in Config.RESOURCES:
		imported[r] = 0.0
	var anchor := map.anchor
	var special := map.special
	# Erst die Werke (sie können nichts zukaufen), dann die Kohlekraftwerke mit dem Rest (+ Zukauf)
	var plants := PackedInt32Array()
	var bio := PackedInt32Array()
	for a in map.size * map.size:
		if anchor[a] != a or special[a] == Config.Special.NONE:
			continue
		var def: Dictionary = Config.SPECIALS[special[a]]
		if special[a] == Config.Special.COAL:
			plants.append(a)
			continue
		if special[a] == Config.Special.BIOMASS:
			bio.append(a)
			continue
		if not def.has("process"):
			continue
		var proc: Dictionary = def["process"]
		var lv := map.special_level(a)
		if not special_powered(a):
			producer_info[a] = {"out": {}, "in": {}, "issue": "Kein Strom - steht still"}
			continue
		if not delivers(a):
			producer_info[a] = {"out": {}, "in": {}, "issue": "Keine Straße zum Lager - bekommt keine Rohstoffe"}
			continue
		# Anteil, der mit den vorhandenen Rohstoffen möglich ist
		var share := 1.0
		var lacking := PackedStringArray()
		for r: String in proc["in"]:
			var need := float(proc["in"][r]) * lv * (furnace if r == "coal" else 1.0)
			var f := float(stock.get(r, 0.0)) / need
			if f < 1.0:
				lacking.append(Config.RESOURCES[r]["name"])
			share = minf(share, f)
		share = clampf(share, 0.0, 1.0)
		var used := {}
		var made := {}
		for r: String in proc["in"]:
			used[r] = float(proc["in"][r]) * lv * share * (furnace if r == "coal" else 1.0)
			stock[r] = float(stock.get(r, 0.0)) - float(used[r])
		for r: String in proc["out"]:
			made[r] = float(proc["out"][r]) * lv * share
			stock[r] = float(stock.get(r, 0.0)) + float(made[r])
			production[r] = float(production.get(r, 0.0)) + float(made[r])
		producer_info[a] = {"out": made, "in": used, "issue": "" if lacking.is_empty() else
			"Zu wenig %s (%d%% Auslastung)" % [", ".join(lacking), roundi(share * 100.0)]}
	for a in plants:
		var need := float(Config.COAL_PLANT_USE)
		var have := minf(float(stock.get("coal", 0.0)), need)
		stock["coal"] = float(stock.get("coal", 0.0)) - have
		coal_burned += have
		if need - have > 0.0:
			_buy("coal", need - have)
		producer_info[a] = {"out": {}, "in": {"coal": need}, "issue": "" if have >= need else
			"Kohle zugekauft: %d (eigene Mine spart Geld)" % int(need - have)}
	# Biomasse verbrennt Holz (nach den Werken, also nach dem Sägewerk); fehlt es: Zukauf
	for a in bio:
		var need := float(Config.BIOMASS_WOOD_USE)
		var have := minf(float(stock.get("wood", 0.0)), need)
		stock["wood"] = float(stock.get("wood", 0.0)) - have
		if need - have > 0.0:
			_buy("wood", need - have)
		producer_info[a] = {"out": {}, "in": {"wood": need}, "issue": "" if have >= need else
			"Holz zugekauft: %d (Holzfäller + Baumschule sparen Geld)" % int(need - have)}


## Lager voll -> Überschuss exportieren.
func _export_surplus() -> void:
	var cap := float(stock_capacity())
	export_income = 0.0
	for res: String in stock:
		var over := float(stock[res]) - cap
		if over > 0.0:
			exported[res] = over
			export_income += over * float(Config.RESOURCES[res]["price"])
			stock[res] = cap


## Zukauf (Ausgabe am Monatsende im Budget).
func _buy(res: String, amount: float) -> void:
	imported[res] = float(imported.get(res, 0.0)) + amount
	_import_pending += amount * float(Config.RESOURCES[res]["price"]) * Config.IMPORT_FACTOR


## Baustoffe für das Wachsen von Zone zn auf Stufe lv: [fehlende Mengen, Zukaufpreis]. Leer, wenn nichts nötig.
func material_need(zn: int, lv: int) -> Array:
	if not materials_on() or not Config.MATERIAL_COST.has(zn):
		return [{}, 0.0]
	var cost := growth_materials(zn, lv)
	var missing := {}
	var price := 0.0
	for r: String in cost:
		var short := float(cost[r]) - float(stock.get(r, 0.0))
		if short > 0.0:
			missing[r] = short
			price += short * float(Config.RESOURCES[r]["price"]) * Config.IMPORT_FACTOR
	return [missing, price]


## Baustoffbedarf fürs Wachsen auf Stufe lv (mit Forschung "Effiziente Bauweise" weniger).
func growth_materials(zn: int, lv: int) -> Dictionary:
	var cost: Dictionary = Config.MATERIAL_COST[zn][lv]
	if lv == 1:
		cost = Config.BUILD_LV1_COST[zn] if game_mode == "build" else {}
	return cost if build_factor() == 1.0 else scale_materials(cost, build_factor())


func build_factor() -> float:
	return Config.TECH_BUILD if tech("efficient_build") else 1.0


## Baustoffe beim Wachsen verbrauchen (fehlendes zukaufen). false = kein Geld für den Zukauf -> kein Wachstum.
func _use_materials(zn: int, lv: int) -> bool:
	if not materials_on() or not Config.MATERIAL_COST.has(zn):
		return true
	var need := material_need(zn, lv)
	if not (need[0] as Dictionary).is_empty() and not can_trade():
		return false                  # Aufbau-Start vor Rathaus-Stufe 2: kein Zukauf, nur eigenes Material
	if float(need[1]) > 0.0 and money - _import_pending - float(need[1]) < -Config.MATERIAL_DEBT:
		return false
	var cost := growth_materials(zn, lv)
	for r: String in cost:
		var take := minf(float(cost[r]), float(stock.get(r, 0.0)))
		stock[r] = float(stock.get(r, 0.0)) - take
		materials_used[r] = float(materials_used.get(r, 0.0)) + float(cost[r])
		if float(cost[r]) - take > 0.0:
			_buy(r, float(cost[r]) - take)
	return true


## Monatlich: deutlicher Abfall der Zufriedenheit -> Meldung mit dem Teil, der am stärksten gesunken ist.
func _check_happiness() -> void:
	_jam_warned = maxi(_jam_warned - 1, 0)
	for a: int in venue_jam:
		if float(venue_event.get(a, 0.0)) > 0.0 and float(venue_jam[a]) > 1.0 and _jam_warned == 0:
			_jam_warned = 12
			message.emit("%s: Besucherverkehr verstopft die Straßen - Bus/Bahn in der Nähe hilft" % Config.SPECIALS[map.special[a]]["name"])
	_happy_hist.push_front([city_happiness, happy_parts.duplicate()])
	if _happy_hist.size() > 4:
		_happy_hist.pop_back()
	_happy_alert_cool = maxi(_happy_alert_cool - 1, 0)
	if population < 100 or _happy_alert_cool > 0 or _happy_hist.size() < 2:
		return
	var old: Array = _happy_hist[-1]
	var drop: float = float(old[0]) - city_happiness
	var last_drop: float = float(_happy_hist[1][0]) - city_happiness
	if drop < Config.HAPPY_ALERT_DROP and last_drop < Config.HAPPY_ALERT_DROP * 0.6:
		return
	var ref: Array = old if drop >= Config.HAPPY_ALERT_DROP else _happy_hist[1]
	var old_parts: Dictionary = ref[1]
	var worst := ""
	var worst_d := 0.0
	for k: String in happy_parts:
		var d: float = float(old_parts.get(k, 0.0)) - float(happy_parts[k])
		if d > worst_d:
			worst_d = d
			worst = k
	_happy_alert_cool = 6
	var text := "Zufriedenheit sinkt: %d%% -> %d%%" % [roundi(float(ref[0]) * 100.0), roundi(city_happiness * 100.0)]
	if worst != "":
		text += " - Grund: %s (-%d)" % [worst, roundi(worst_d * 100.0)]
	if city_happiness < Config.HAPPY_LEAVE:
		text += ". Leute ziehen weg!"
	message.emit(text)


## Teile der Zufriedenheit mit Tipp, schlechteste zuerst: [Name, Punkte, Tipp].
func happiness_report() -> Array:
	var out := []
	var has_cat := {}
	for i in map.size * map.size:
		if map.anchor[i] == i and Config.SPECIALS[map.special[i]].has("service"):
			has_cat[Config.SPECIALS[map.special[i]]["service"]] = true
	for k: String in happy_parts:
		var v: float = happy_parts[k]
		var tip := ""
		if k == "Bodenwert" and v < 0.0:
			tip = "Parks, Wasser, Höhenlage; Abstand/Grüngürtel zu Industrie"
		elif k == "Parks" and v < Config.HAPPY_PARK_MAX * 0.5:
			tip = "Parks in Wohnnähe (3 Tiles) bauen"
		elif k == "Kriminalität" and v < -0.02:
			tip = "Polizei" + (", mehr Jobs (Arbeitslos %d%%)" % roundi(unemployment * 100.0) if unemployment > 0.05 else "")
		elif k == "Steuern" and v < 0.0:
			tip = "Wohnsteuer senken (neutral %d%%)" % roundi(Config.TAX_NEUTRAL[Config.Zone.RES] * 100.0)
		elif k == "Leerstand" and v < 0.0:
			tip = "Verfall im Viertel: Leerstand abreißen oder Ursache beheben (Info-Karte nennt den Grund)"
		elif k == "ÖPNV-Tarif" and v < 0.0:
			tip = "ÖPNV günstiger/kostenlos machen"
		else:
			for cat: String in Config.SERVICES:
				var spec: Array = Config.SERVICES[cat]
				if spec[0] != k or v >= 0.0:
					continue
				var cov := float(city_coverage.get(cat, 0.0))
				tip = ("%s bauen" % k) if not has_cat.has(cat) else \
					"erreicht nur %d%% - mehr bauen oder ausbauen" % roundi(cov * 100.0)
		out.append([k, v, tip])
	out.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) < float(b[1]))
	return out


## Fehlende Dienste an einem Wohn-Tile (nur solche, die die Stadtgröße schon verlangt).
## Tiles im Einzugskreis eines Dienstgebäudes (Radius je Ausbaustufe, ab Gebäudemitte).
## Reichweite/Kapazität eines Dienstbaus (Universität: radius_mul/capacity_mul, stadtweiter Einzugsbereich).
func service_radius(a: int) -> int:
	return service_radius_for(map.special[a], map.special_level(a))


static func service_radius_for(sp: int, lv: int) -> int:
	return roundi(Config.SERVICE_RADIUS[lv] * float(Config.SPECIALS[sp].get("radius_mul", 1.0)))


func service_capacity(a: int) -> float:
	var def: Dictionary = Config.SPECIALS[map.special[a]]
	return Config.SERVICE_CAPACITY[map.special_level(a)] * float(def.get("capacity_mul", 1.0))


func _service_tiles(a: int) -> PackedInt32Array:
	var size := map.size
	var r: int = service_radius(a)
	var half := (int(Config.SPECIALS[map.special[a]]["size"]) - 1) * 0.5
	var cx := a % size
	var cz := a / size
	var out := PackedInt32Array()
	for dz in range(-r, r + 1 + int(half * 2)):
		var nz := cz + dz
		if nz < 0 or nz >= size:
			continue
		for dx in range(-r, r + 1 + int(half * 2)):
			var nx := cx + dx
			if nx < 0 or nx >= size:
				continue
			if Vector2(dx - half, dz - half).length() <= r:
				out.append(nz * size + nx)
	return out


func missing_services(i: int) -> PackedStringArray:
	var out := PackedStringArray()
	for cat: String in Config.SERVICES:
		var spec: Array = Config.SERVICES[cat]
		if population >= int(spec[1]) and coverage.has(cat) and (coverage[cat] as PackedFloat32Array)[i] < 0.3:
			out.append(spec[0])
	return out


## Gewerbe/Industrie brauchen ausgebildete Arbeitskräfte, sobald die Stadt Schulen erwartet.
func _workforce_education() -> float:
	if population < int(Config.SERVICES["education"][1]):
		return 1.0
	return 0.6 + 0.4 * float(city_coverage.get("education", 0.0))


## Brände: Ausbruch je Gebäude, seltener mit Brandschutz. Verlauf, Löschzüge und
## Ausbreitung übernimmt FireDept (Echtzeit). Brandruinen zählen hier herunter.
func _fires() -> void:
	var n := map.size * map.size
	var burning := map.burning
	var ruin := map.ruin
	var zone := map.zone
	var level := map.level
	var rect := Rect2i()
	var started := 0
	var cov: PackedFloat32Array = coverage.get("fire", PackedFloat32Array())
	var town := population >= Config.FIRE_GRACE_POP      # Wohnen/Gewerbe brennen erst in größeren Orten
	var ignite := cov.size() == n
	for i in n:
		if ruin[i] > 0:
			# Abgerissen/umgezont -> Ruine weg, sonst Monat herunterzählen
			ruin[i] = 0 if zone[i] == Config.Zone.NONE else ruin[i] - 1
			if ruin[i] == 0:
				var r := Rect2i(i % map.size, i / map.size, 1, 1)
				rect = r if rect.size == Vector2i.ZERO else rect.merge(r)
			continue
		if not ignite or level[i] == 0 or zone[i] == Config.Zone.NONE or burning[i] > 0:
			continue
		var ind := zone[i] == Config.Zone.IND
		if not ind and not town:
			continue
		var unprotected := 1.0 - minf(cov[i], 1.0)
		var share := unprotected * unprotected
		if ind:
			share = maxf(share, Config.FIRE_IND_MIN_SHARE)     # Industrie brennt auch geschützt mal
		var risk := Config.FIRE_RISK * share * (Config.FIRE_IND_FACTOR if ind else 1.0)
		if _rng.randf() < risk:
			burning[i] = 1
			started += 1
			var r := Rect2i(i % map.size, i / map.size, 1, 1)
			rect = r if rect.size == Vector2i.ZERO else rect.merge(r)
	fires_total += started
	if rect.size != Vector2i.ZERO:
		map.notify_changed(rect, false)    # FireDept übernimmt neue Brände, Renderer zeigt Ruinen


func _budget() -> void:
	var jobs := jobs_com + jobs_ind
	var taxes_on := game_mode != "build" or hall_level >= 2
	income_parts = {
		"Wohnen": (population if taxes_on else 0) * Config.TAX_BASE_RES * float(tax[Config.Zone.RES]) * 12.0,
		"Gewerbe": (jobs_com if taxes_on else 0) * Config.TAX_BASE_JOB * float(tax[Config.Zone.COM]) * 12.0,
		"Industrie": ((jobs_ind - jobs_hightech) if taxes_on else 0) * Config.TAX_BASE_JOB * float(tax[Config.Zone.IND]) * 12.0,
		"Hightech": (jobs_hightech if taxes_on else 0) * Config.TAX_BASE_JOB * float(tax[Config.Zone.IND]) * 12.0 * Config.HIGHTECH_TAX,
		"ÖPNV": (bus_riders + rail_riders) * float(Config.FARE_PRICE[fare]),
		"Bodenabgabe": villa_count * Config.VILLA_LEVY,
		"Rohstoff-Export": export_income,
	}
	last_income = 0.0
	for k: String in income_parts:
		last_income += float(income_parts[k])
	admin_cost = admin_for(population)
	interest_cost = maxf(-money, 0.0) * Config.DEBT_INTEREST     # Schulden kosten Zinsen
	last_expense = admin_cost + interest_cost + research_spent + road_count * Config.UPKEEP_ROAD + park_count * Config.UPKEEP_PARK \
		+ line_count * Config.UPKEEP_POWERLINE + special_upkeep \
		+ rail_count * Config.UPKEEP_RAIL + bus_stop_count * Config.UPKEEP_BUS_STOP \
		+ station_count * Config.UPKEEP_STATION + _import_pending
	if game_mode == "build" and hall_level < 2:
		last_expense = 0.0            # Gründung: keine Steuern, aber auch kein Unterhalt (Material ist die Währung)
	import_cost = _import_pending
	_import_pending = 0.0
	last_materials = materials_used
	materials_used = {}
	money += last_income - last_expense
	if money < 0.0:
		message.emit("Stadtkasse im Minus! Steuern erhöhen oder Ausgaben senken.")
