class_name Simulation
extends Node
## Monatliche Stadtsimulation: Strom, Nachfrage (RCI), Wachstum, Budget.

signal stats_changed
signal power_changed
signal traffic_changed
signal message(text: String)

const SECONDS_PER_MONTH := [0.0, 3.0, 1.5, 0.5]
const MONTH_NAMES := ["Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"]
const NEUTRAL_TAX := 0.09

var map: CityMap
var money: float = Config.START_MONEY
var month := 0
var year := Config.START_YEAR
var tax_rate := NEUTRAL_TAX
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
var power_demand := 0
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
var fires_total := 0
var _needs_announced := {}
var _ipop := PackedFloat32Array()   # Integralbild Einwohner (aus _compute_environment)

# Öffentlicher Verkehr
var bus_served: PackedByteArray     # 1 = Straßen-Tile im Einzugsbereich einer Haltestelle
var rail_traffic: PackedFloat32Array  # Fahrgäste je Gleis-Tile
var station_use := {}               # Bahnhof-Tile -> Ein-/Aussteiger
var bus_riders := 0.0
var rail_riders := 0.0
var transit_share := 0.0            # Anteil Pendler mit Bus/Bahn
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
var _acc := 0.0
var _ticking := false               # Monat läuft gerade (über mehrere Frames)
var _rng := RandomNumberGenerator.new()
var _was_brownout := false

const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]


func setup(city_map: CityMap) -> void:
	map = city_map
	_rng.randomize()
	refresh()


func _process(delta: float) -> void:
	if speed == 0:
		return
	if _ticking:
		return
	_acc += delta
	if _acc >= SECONDS_PER_MONTH[speed]:
		_acc = 0.0
		_tick_spread()


func to_dict() -> Dictionary:
	return {"money": money, "month": month, "year": year, "tax_rate": tax_rate, "congestion": congestion}


func from_dict(d: Dictionary) -> void:
	money = d.get("money", Config.START_MONEY)
	month = d.get("month", 0)
	year = d.get("year", Config.START_YEAR)
	tax_rate = d.get("tax_rate", NEUTRAL_TAX)
	congestion = d.get("congestion", PackedFloat32Array())
	last_income = 0.0
	last_expense = 0.0
	_acc = 0.0
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
func refresh() -> void:
	var t := Perf.begin()
	_compute_road_distance()
	_compute_power()
	Perf.end("sim.strassen+strom", t)
	t = Perf.begin()
	_compute_commute()
	Perf.end("sim.pendler", t)
	t = Perf.begin()
	_compute_environment()
	_recount()
	_compute_services()
	_update_demand()
	Perf.end("sim.umwelt+dienste", t)
	t = Perf.begin()
	stats_changed.emit()
	Perf.end("sim.signal_stats", t)


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


## Etappen eines Monats. Pendler und Umwelt nur einmal pro Monat (teuer);
## nach dem Wachstum werden nur Strom, Zählung und Nachfrage aktualisiert.
const TICK_STAGES := ["netz", "pendler", "umwelt", "dienste", "wachstum"]


func _tick_stage(stage: String) -> void:
	var t := Perf.begin()
	match stage:
		"netz":
			_compute_road_distance()
			_compute_power()
		"pendler":
			_compute_commute()
		"umwelt":
			_compute_environment()
			_recount()
		"dienste":
			_compute_services()
			_update_demand()
		"wachstum":
			_fires()
			_grow()
			_compute_power()
			_recount()
			_update_demand()
			_budget()
			month += 1
			if month >= 12:
				month = 0
				year += 1
			stats_changed.emit()
	Perf.end("sim." + stage, t)


func _compute_road_distance() -> void:
	# Multi-Source-BFS von allen Straßen-Tiles
	var n := map.size * map.size
	road_dist.resize(n)
	road_dist.fill(99)
	road_src.resize(n)
	road_src.fill(-1)
	var queue: Array[Vector2i] = []
	for z in map.size:
		for x in map.size:
			if map.road[map.idx(x, z)] != 0:
				road_dist[map.idx(x, z)] = 0
				road_src[map.idx(x, z)] = map.idx(x, z)
				queue.append(Vector2i(x, z))
	var head := 0
	while head < queue.size():
		var p: Vector2i = queue[head]
		head += 1
		var d := road_dist[map.idx(p.x, p.y)]
		if d >= Config.ROAD_ACCESS_RANGE:
			continue
		for dir: Vector2i in DIRS:
			var q := p + dir
			if map.in_bounds(q.x, q.y) and road_dist[map.idx(q.x, q.y)] > d + 1:
				road_dist[map.idx(q.x, q.y)] = d + 1
				road_src[map.idx(q.x, q.y)] = road_src[map.idx(p.x, p.y)]
				queue.append(q)


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
			cap[i] = Config.WIDE_CAPACITY if wide else Config.STREET_CAPACITY
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
			amount = Config.RES_CAPACITY[lv] * WORK_SHARE
		else:
			amount = Config.COM_CAPACITY[lv] if zn == Config.Zone.COM else Config.IND_CAPACITY[lv]
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
	station_use = {}
	bus_riders = 0.0
	_transit_trips = 0.0
	rail_riders = 0.0
	var sources: Array = workers.keys()
	var src_cost := {}
	var src_assigned := {}
	var run := 0
	var unreachable := 0.0
	for round_i in ASSIGN_ROUNDS:
		sources.shuffle()
		var last_round := round_i == ASSIGN_ROUNDS - 1
		for s: int in sources:
			run += 1
			var w: float = workers[s] / ASSIGN_ROUNDS
			var heap := MinHeap.new()
			_dist[s] = 0.0
			_visit[s] = run
			_parent[s] = -1
			_hops[s] = 0
			_via_rail[s] = 0
			heap.push(0.0, s)
			while not heap.is_empty() and w > 0.001:
				var d := heap.top_priority()
				var u := heap.pop()
				if d > _dist[u]:
					continue
				if u < n and jobs_left[u] > 0.0:
					var take := minf(w, jobs_left[u])
					jobs_left[u] -= take
					w -= take
					src_assigned[s] = src_assigned.get(s, 0.0) + take
					src_cost[s] = src_cost.get(s, 0.0) + take * d
					_record_trip(u, s, take)
				if _hops[u] >= MAX_HOPS:
					continue
				if u < n:
					for v in _road_neighbors(u):
						# Auslastung: aktueller Verkehr + etwas Erinnerung an den Vormonat
						var ratio := minf(traffic[v] / cap[v] + prev[v] * 0.3, 4.0)
						_relax(heap, u, v, d + inv_speed[v] * (1.0 + CONGESTION_COST * ratio * ratio), 1, run)
					if _road_station_links.has(u):
						for l: Array in _road_station_links[u]:
							_relax(heap, u, l[0], d + l[1], 0, run)
				else:
					var t := u - n
					for v in _rail_neighbors(t):
						var r := rail_traffic[v] / Config.RAIL_CAPACITY
						_relax(heap, u, n + v, d + Config.RAIL_COST * (1.0 + r * r), 0, run)
					if _station_links.has(t):
						for l: Array in _station_links[t]:
							_relax(heap, u, l[0], d + l[1], 0, run)
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


func _relax(heap: MinHeap, u: int, v: int, nd: float, hop_inc: int, run: int) -> void:
	if _visit[v] == run and nd >= _dist[v]:
		return
	_visit[v] = run
	_dist[v] = nd
	_parent[v] = u
	_hops[v] = _hops[u] + hop_inc
	_via_rail[v] = 1 if _via_rail[u] == 1 or v >= map.size * map.size else 0
	heap.push(nd, v)


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
		var bus := take * Config.BUS_SHARE
		bus_riders += bus
		_transit_trips += bus
		car = take - bus + bus * Config.BUS_TRAFFIC
	var v := u
	while v != -1:
		traffic[v] += car
		v = _parent[v]


## Bahn als zweites Netz: Knoten n+i = Gleis-Tile i. Bahnhöfe verbinden Gleis und Straßen
## im Fußweg-Umkreis. Straßen-Komponenten, die per Bahn verbunden sind, gelten als ein Netz.
## Haltestellen markieren Straßen-Tiles mit Busanschluss (bus_served).
func _build_transit_links(road_comps: int) -> void:
	var n := map.size * map.size
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
					best[map.idx(x + dx, z + dz)] = d * Config.WALK_COST + Config.STATION_TRANSFER
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
				var cost := Config.STATION_TRANSFER + Config.BUS_WAIT + d * Config.BUS_FEEDER_COST
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
func _compute_environment() -> void:
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
	for i in n:
		if zone[i] == Config.Zone.IND and level[i] > 0:
			_stamp(i, Config.POLLUTION_IND_PER_LEVEL[level[i]], Config.POLLUTION_IND_RANGE)
		elif anchor[i] == i and special[i] == Config.Special.COAL:
			_stamp(i, Config.POLLUTION_COAL, Config.POLLUTION_COAL_RANGE)
		elif road[i] != 0 and congestion[i] > 0.3:
			_stamp(i, Config.POLLUTION_TRAFFIC * minf(congestion[i], 2.0), Config.POLLUTION_TRAFFIC_RANGE)

	# Integralbilder (Präfixsummen) für Wasser, Bäume, Parks, Einwohner in einem Durchlauf
	var s := size + 1
	var iw := PackedFloat32Array()
	var it := PackedFloat32Array()
	var ip := PackedFloat32Array()
	var ipop := PackedFloat32Array()
	for a: PackedFloat32Array in [iw, it, ip, ipop]:
		a.resize(s * s)
	for z in size:
		var rw := 0.0
		var rt := 0.0
		var rp := 0.0
		var rpop := 0.0
		for x in size:
			var i := z * size + x
			if height[i] < Config.WATER_LEVEL: rw += 1.0
			var f := feature[i]
			if f == Config.Feature.TREE: rt += 1.0
			elif f == Config.Feature.PARK: rp += 1.0
			if zone[i] == Config.Zone.RES: rpop += Config.RES_CAPACITY[level[i]]
			var o := (z + 1) * s + x + 1
			var up := z * s + x + 1
			iw[o] = iw[up] + rw
			it[o] = it[up] + rt
			ip[o] = ip[up] + rp
			ipop[o] = ipop[up] + rpop
	_ipop = ipop

	land_value.resize(n)
	customers.resize(n)
	res_nearby.resize(n)
	var cr := Config.COM_CUSTOMER_RANGE
	var range_ok := Config.ROAD_ACCESS_RANGE
	for z in size:
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
			var v := Config.LAND_BASE
			if iw[z1 + x1] - iw[z0 + x1] - iw[z1 + x0] + iw[z0 + x0] > 0.0:
				v += Config.LAND_WATER
			v += minf((it[z1 + x1] - it[z0 + x1] - it[z1 + x0] + it[z0 + x0]) * Config.LAND_TREE, 0.15)
			v += minf((ip[z1 + x1] - ip[z0 + x1] - ip[z1 + x0] + ip[z0 + x0]) * Config.LAND_PARK, 0.24)
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
			return clampf(0.35 + customers[i] / Config.COM_CUSTOMERS_FULL * 0.65, 0.0, 1.0) * road_factor
		Config.Zone.IND:
			# gut: weg von Wohnen (Industrie verschmutzt Nachbarn)
			return clampf(1.0 - res_nearby[i] / 250.0, 0.25, 1.0) * road_factor
	return 0.0


func _road_neighbors(i: int) -> Array[int]:
	var out: Array[int] = []
	var x := i % map.size
	var z := i / map.size
	for d: Vector2i in DIRS:
		if map.roads_connected(x, z, x + d.x, z + d.y):
			out.append(map.idx(x + d.x, z + d.y))
	return out


## Min-Heap für Dijkstra (Priorität float, Wert int).
class MinHeap:
	var _p := PackedFloat32Array()
	var _v := PackedInt32Array()

	func is_empty() -> bool:
		return _v.is_empty()

	func top_priority() -> float:
		return _p[0]

	func push(p: float, v: int) -> void:
		_p.append(p)
		_v.append(v)
		var i := _v.size() - 1
		while i > 0:
			var up := (i - 1) / 2
			if _p[up] <= _p[i]:
				break
			_swap(i, up)
			i = up

	func pop() -> int:
		var out := _v[0]
		var last := _v.size() - 1
		_swap(0, last)
		_p.resize(last)
		_v.resize(last)
		var i := 0
		while true:
			var l := i * 2 + 1
			var r := l + 1
			var m := i
			if l < last and _p[l] < _p[m]: m = l
			if r < last and _p[r] < _p[m]: m = r
			if m == i:
				break
			_swap(i, m)
			i = m
		return out

	func _swap(a: int, b: int) -> void:
		var tp := _p[a]
		_p[a] = _p[b]
		_p[b] = tp
		var tv := _v[a]
		_v[a] = _v[b]
		_v[b] = tv


func tile_power_use(i: int) -> int:
	var zn := map.zone[i]
	if zn == Config.Zone.NONE:
		return 0
	return Config.POWER_USE[zn][map.level[i]]


## Pro Stromnetz: BFS ab den Kraftwerken, versorgt bis Kapazität erschöpft.
func _compute_power() -> void:
	var n := map.size * map.size
	powered.resize(n)
	powered.fill(0)
	var seen := PackedByteArray()
	seen.resize(n)
	power_supply = 0
	power_demand = 0
	var brownout := false

	for start in n:
		if seen[start] == 1 or map.special[start] == Config.Special.NONE:
			continue
		# 1) Netz-Komponente sammeln
		var comp: Array[int] = [start]
		seen[start] = 1
		var head := 0
		var plants: Array[int] = []
		var capacity := 0
		while head < comp.size():
			var i: int = comp[head]
			head += 1
			if map.anchor[i] == i:
				capacity += Config.SPECIALS[map.special[i]]["power"]
			if map.special[i] != Config.Special.NONE:
				plants.append(i)
			power_demand += tile_power_use(i)
			var x := i % map.size
			var z := i / map.size
			for dir: Vector2i in DIRS:
				var nx: int = x + dir.x
				var nz: int = z + dir.y
				if not map.in_bounds(nx, nz):
					continue
				var j := map.idx(nx, nz)
				if seen[j] == 0 and map.conducts(j):
					seen[j] = 1
					comp.append(j)
		power_supply += capacity

		# 2) Versorgen in BFS-Reihenfolge ab den Kraftwerken
		var left := capacity
		var visited := {}
		var q: Array[int] = plants.duplicate()
		for p in plants:
			visited[p] = true
		head = 0
		while head < q.size():
			var i: int = q[head]
			head += 1
			var use := tile_power_use(i)
			if use > left:
				brownout = true
				continue
			left -= use
			powered[i] = 1
			var x := i % map.size
			var z := i / map.size
			for dir: Vector2i in DIRS:
				var nx: int = x + dir.x
				var nz: int = z + dir.y
				if not map.in_bounds(nx, nz):
					continue
				var j := map.idx(nx, nz)
				if not visited.has(j) and map.conducts(j):
					visited[j] = true
					q.append(j)

	if brownout and not _was_brownout:
		message.emit("Stromengpass! Mehr Kraftwerke bauen.")
	_was_brownout = brownout
	power_changed.emit()


func _recount() -> void:
	population = 0
	jobs_com = 0
	jobs_ind = 0
	road_count = 0
	park_count = 0
	line_count = 0
	rail_count = 0
	bus_stop_count = 0
	station_count = 0
	special_upkeep = 0.0
	for i in map.size * map.size:
		var lv := map.level[i]
		match map.zone[i]:
			Config.Zone.RES: population += Config.RES_CAPACITY[lv]
			Config.Zone.COM: jobs_com += Config.COM_CAPACITY[lv]
			Config.Zone.IND: jobs_ind += Config.IND_CAPACITY[lv]
		road_count += 1 if map.road[i] != 0 else 0
		line_count += map.power_line[i]
		rail_count += 1 if map.rail[i] != 0 else 0
		bus_stop_count += 1 if map.transit[i] == Config.Transit.BUS_STOP else 0
		station_count += 1 if map.transit[i] == Config.Transit.STATION else 0
		if map.feature[i] == Config.Feature.PARK:
			park_count += 1
		if map.anchor[i] == i:
			var lvl := map.special_level(i) if Config.SPECIALS[map.special[i]].has("service") else 1
			special_upkeep += Config.SPECIALS[map.special[i]]["upkeep"] * Config.UPKEEP_LEVEL[lvl]


func _update_demand() -> void:
	var pop := float(population)
	var workforce := pop * 0.55
	var jobs := float(jobs_com + jobs_ind)
	# Wohnen: Zuzug, wenn Jobs frei sind (+ Grundattraktivität)
	demand_res = (jobs - workforce + 60.0) / maxf(60.0, workforce * 0.4 + 40.0)
	# Industrie: Exportmarkt + wächst mit Bevölkerung
	var ind_target := 40.0 + pop * 0.30
	demand_ind = (ind_target - jobs_ind) / maxf(40.0, ind_target * 0.4)
	# Gewerbe: braucht Kundschaft (Einwohner) und etwas Industrie-Zulieferung
	var com_target := 15.0 + pop * 0.22 + jobs_ind * 0.1
	demand_com = (com_target - jobs_com) / maxf(30.0, com_target * 0.4)
	# Arbeitskräftemangel bremst Jobs
	if jobs > workforce + 80.0:
		demand_ind -= 0.3
		demand_com -= 0.3
	# Ruf der Stadt: zufriedene Bürger locken Zuzug an, unzufriedene schrecken ab
	if population > 0:
		demand_res += (city_happiness - 0.5) * 0.8
	# Steuern über Neutralwert dämpfen, darunter fördern
	var tax_effect := (tax_rate - NEUTRAL_TAX) * 5.0
	demand_res = clampf(demand_res - tax_effect, -1.0, 1.0)
	demand_com = clampf(demand_com - tax_effect, -1.0, 1.0)
	demand_ind = clampf(demand_ind - tax_effect, -1.0, 1.0)


func demand_for(z: int) -> float:
	match z:
		Config.Zone.RES: return demand_res
		Config.Zone.COM: return demand_com
		Config.Zone.IND: return demand_ind
	return 0.0


## Liste der Gründe, warum ein Zonen-Tile nicht wächst (leer = alles ok).
func growth_blockers(i: int) -> PackedStringArray:
	var out := PackedStringArray()
	if road_dist.size() > i and road_dist[i] > Config.ROAD_ACCESS_RANGE:
		out.append("Keine Straße in Reichweite")
	if powered.size() > i and powered[i] == 0:
		out.append("Kein Strom")
	if _src(i) >= 0:
		if map.zone[i] == Config.Zone.RES:
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
	if map.zone[i] == Config.Zone.RES and happiness.size() > i and lv > 0 and happiness[i] < Config.HAPPY_LEAVE:
		out.append("Unzufrieden - Leute ziehen weg")
	if demand_for(map.zone[i]) <= 0.0:
		out.append("Keine Nachfrage")
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
		return _reaches(i, true) and tile_commute(i) <= LONG_COMMUTE
	return _reaches(i, false)


func _grow() -> void:
	var changed := Rect2i()
	var any := false
	for z in map.size:
		for x in map.size:
			var i := map.idx(x, z)
			var zn := map.zone[i]
			if zn == Config.Zone.NONE:
				continue
			var lv := map.level[i]
			var demand := demand_for(zn)
			var ok := _can_grow(i)
			var new_lv := lv
			if zn == Config.Zone.RES and lv > 0 and happiness[i] < Config.HAPPY_LEAVE and _rng.randf() < 0.08:
				new_lv = lv - 1       # Unzufriedenheit -> Wegzug
			elif not ok:
				# Ohne Straße/Strom/Erreichbarkeit verfällt Bebauung
				if lv > 0 and _rng.randf() < 0.06:
					new_lv = lv - 1
			elif demand > 0.0 and lv < _max_level(i):
				var chance := 0.3 * demand / (1.0 + lv) * _growth_factor(i, zn)
				if lv == 0:
					chance *= 1.5
				if _rng.randf() < chance:
					new_lv = lv + 1
			elif lv > _max_level(i) and _rng.randf() < 0.05:
				new_lv = lv - 1       # Bodenwert gesunken -> Abwanderung
			elif demand < -0.25 and lv > 0 and _rng.randf() < 0.04:
				new_lv = lv - 1
			if new_lv != lv:
				map.level[i] = new_lv
				var r := Rect2i(x, z, 1, 1)
				changed = r if not any else changed.merge(r)
				any = true
	if any:
		map.notify_changed(changed, false)    # nur Gebäudestufen


## Höchste erreichbare Stufe (Wohnen: begrenzt durch Bodenwert).
func _max_level(i: int) -> int:
	if map.zone[i] != Config.Zone.RES:
		return 3
	var lv := 1
	for k in range(2, 4):
		if land_value[i] >= Config.RES_MIN_LAND[k]:
			lv = k
	return lv


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
			return f * _workforce_education()
		Config.Zone.IND:
			return _workforce_education()
	return 1.0


## Versorgung je Dienst-Kategorie, Kriminalität, Zufriedenheit; Bürgerwünsche melden.
func _compute_services() -> void:
	var size := map.size
	var n := size * size
	var s := size + 1
	for cat: String in Config.SERVICES:
		var f := PackedFloat32Array()
		f.resize(n)
		coverage[cat] = f
	service_load = {}
	var has_cat := {}
	for i in n:
		if map.anchor[i] != i:
			continue
		var def: Dictionary = Config.SPECIALS[map.special[i]]
		if not def.has("service"):
			continue
		var cat: String = def["service"]
		has_cat[cat] = true
		var lv := map.special_level(i)
		var r: int = Config.SERVICE_RADIUS[lv]
		var half := (int(def["size"]) - 1) * 0.5
		var cx := i % size
		var cz := i / size
		# Einwohner im Einzugsquadrat -> Auslastung; Überlast schwächt die Wirkung
		var x0 := maxi(cx - r, 0)
		var z0 := maxi(cz - r, 0)
		var x1 := mini(cx + r + 1 + int(half * 2), size)
		var z1 := mini(cz + r + 1 + int(half * 2), size)
		var served := 0.0
		if _ipop.size() == s * s:
			served = _ipop[z1 * s + x1] - _ipop[z0 * s + x1] - _ipop[z1 * s + x0] + _ipop[z0 * s + x0]
		var load := served / float(Config.SERVICE_CAPACITY[lv])
		service_load[i] = load
		var strength := 1.0 if load <= 1.0 else 1.0 / load
		var field: PackedFloat32Array = coverage[cat]
		for dz in range(-r, r + 1):
			var nz := cz + dz
			if nz < 0 or nz >= size:
				continue
			for dx in range(-r, r + 1):
				var nx := cx + dx
				if nx < 0 or nx >= size:
					continue
				var d := Vector2(dx - half, dz - half).length()
				if d > r:
					continue
				var v := strength * (1.0 - 0.4 * d / r)
				var j := nz * size + nx
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
	for cat: String in Config.SERVICES:
		cov_sum[cat] = 0.0
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
		var h := Config.HAPPY_BASE + (land_value[i] - 0.45) * 0.5
		for cat: String in Config.SERVICES:
			var spec: Array = Config.SERVICES[cat]
			var cov: float = (coverage[cat] as PackedFloat32Array)[i]
			if population >= int(spec[1]):
				h += float(spec[2]) * (2.0 * cov - 1.0)     # versorgt +, unversorgt -
			else:
				h += float(spec[2]) * cov * 0.5             # schon vorher ein kleiner Bonus
		h -= crime[i] * 0.3
		h -= (tax_rate - NEUTRAL_TAX) * 2.0
		happiness[i] = clampf(h, 0.0, 1.0)
		var p: float = Config.RES_CAPACITY[lv]
		sum_h += happiness[i] * p
		sum_w += p
		for cat: String in Config.SERVICES:
			cov_sum[cat] += minf((coverage[cat] as PackedFloat32Array)[i], 1.0) * p
	city_happiness = sum_h / sum_w if sum_w > 0.0 else 0.6
	for cat: String in Config.SERVICES:
		city_coverage[cat] = cov_sum[cat] / sum_w if sum_w > 0.0 else 0.0

	# Bürgerwünsche: einmalige Meldung, wenn die Stadt eine Größe erreicht und der Dienst fehlt
	for cat: String in Config.SERVICES:
		var spec: Array = Config.SERVICES[cat]
		if population >= int(spec[1]) and not has_cat.has(cat) and not _needs_announced.has(cat):
			_needs_announced[cat] = true
			message.emit("Die Bürger verlangen nach: %s" % spec[0])


## Fehlende Dienste an einem Wohn-Tile (nur solche, die die Stadtgröße schon verlangt).
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


## Brände: Gebäude ohne Feuerwehrschutz können abbrennen (Industrie häufiger).
func _fires() -> void:
	if population < Config.FIRE_GRACE_POP or not coverage.has("fire"):
		return
	var fire: PackedFloat32Array = coverage["fire"]
	var burned := 0
	var covered := 0
	var rect := Rect2i()
	for i in map.size * map.size:
		var lv := map.level[i]
		if lv == 0 or map.zone[i] == Config.Zone.NONE:
			continue
		var risk := Config.FIRE_RISK * (3.0 if map.zone[i] == Config.Zone.IND else 1.0) * (1.0 - 0.95 * fire[i])
		if _rng.randf() < risk:
			map.level[i] = 0
			if fire[i] >= 0.3:
				covered += 1
			var r := Rect2i(i % map.size, i / map.size, 1, 1)
			rect = r if burned == 0 else rect.merge(r)
			burned += 1
	if burned > 0:
		fires_total += burned
		map.notify_changed(rect, false)
		if covered == burned:
			message.emit("Brand! %d Gebäude abgebrannt - trotz Feuerwehr." % burned)
		else:
			message.emit("Brand! %d Gebäude abgebrannt - Feuerwehr fehlt in der Nähe." % burned)


func _budget() -> void:
	var jobs := jobs_com + jobs_ind
	last_income = (population * 0.12 + jobs * 0.1) * tax_rate * 12.0
	last_expense = road_count * Config.UPKEEP_ROAD + park_count * Config.UPKEEP_PARK \
		+ line_count * Config.UPKEEP_POWERLINE + special_upkeep \
		+ rail_count * Config.UPKEEP_RAIL + bus_stop_count * Config.UPKEEP_BUS_STOP \
		+ station_count * Config.UPKEEP_STATION
	money += last_income - last_expense
	if money < 0.0:
		message.emit("Stadtkasse im Minus! Steuern erhöhen oder Ausgaben senken.")
