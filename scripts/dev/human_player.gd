class_name HumanPlayer
extends RefCounted
## Balance-Messung (--humanrun=Jahre[,seed]): spielt einen Neustart "wie ein Mensch" statt optimal –
## schaut nur alle 3 Monate hin, lässt Dinge liegen (Zufall), baut nur mit Geld, reagiert auf Probleme
## (Strom, fehlende/überlastete Dienste, Unzufriedenheit, leere Kasse), forscht sobald möglich.
## Stadt wächst in Blöcken (7x7: 6x6 Zone + Straßenring) ringförmig um die Mitte. Protokoll je Jahr + Meilensteine.

const CELL := 7
const T := ToolController.Tool

var game: Node
var map: CityMap
var sim: Simulation
var tools: ToolController
var rng := RandomNumberGenerator.new()
var c := 64
var cells: Array[Vector2i] = []        # Ausbau-Reihenfolge (Spirale)
var next_cell := 0
var built_cells := {}                  # Vector2i -> Zone
var log_lines: Array[String] = []
var verbose := false
var milestones: Array[String] = []
var research_order := ["efficient_build", "traffic", "plant_filter", "solar", "concrete", "deep_mining", "battery",
	"highrise", "offices", "hightech", "blast_furnace", "hydro", "pumped", "salt"]


func run(g: Node, years: int, seed_value: int) -> void:
	game = g
	map = g.map
	sim = g.sim
	tools = g.tools
	rng.seed = seed_value
	DemoCity.generate_map(map)
	sim.reset()
	sim.money = Config.START_MONEY
	map.notify_changed(Rect2i(0, 0, map.size, map.size))
	sim.refresh()
	c = map.size / 2
	for r in range(0, 9):
		for j in range(-r, r + 1):
			for i in range(-r, r + 1):
				if maxi(absi(i), absi(j)) == r:
					cells.append(Vector2i(i, j))
	# Start: zwei Wohnblöcke, ein Gewerbe, ein Industrie, ein Windrad
	_build_cell(Config.Zone.RES)
	_build_cell(Config.Zone.RES)
	_build_cell(Config.Zone.COM)
	_build_cell(Config.Zone.IND)
	_power_plant(T.WIND)
	_power_plant(T.WIND)
	print("humanrun Start %d: Kasse $%d nach Startviertel" % [sim.year, int(sim.money)])
	var zt := 0
	var rd := 0
	var why := {}
	sim.tick_month()
	for i in map.size * map.size:
		if map.zone[i] != Config.Zone.NONE:
			zt += 1
			for b: String in sim.growth_blockers(i):
				why[b.substr(0, 30)] = int(why.get(b.substr(0, 30), 0)) + 1
		if map.road[i] != 0:
			rd += 1
	print("humanrun Diagnose: Zonen-Tiles %d, Straßen %d, Blocker %s, Nachfrage W %.2f" % [zt, rd, why, sim.demand_res])
	for y in years:
		var inc := 0.0
		var exp := 0.0
		for m in 12:
			sim.tick_month()
			game.fire_dept.advance(12.0)           # Löschzüge fahren (im Spiel Echtzeit)
			inc += sim.last_income
			exp += sim.last_expense
			if m % 3 == 2:
				_think()
		var res := "-"
		if sim.research_current != "":
			res = "%s %d%%" % [Config.RESEARCH[sim.research_current]["name"],
				roundi(100.0 * sim.research_progress / float(Config.RESEARCH[sim.research_current]["points"]))]
		print("humanrun %d: Kasse $%7d  Einw. %6d  Saldo/Jahr $%6d  Zufr. %2d%%  Strom %d/%d  Steuer W %d%%  erforscht %d  läuft: %s  Budget $%d" % [
			sim.year, int(sim.money), sim.population, roundi(inc - exp), roundi(sim.city_happiness * 100.0),
			sim.power_demand, sim.power_supply, roundi(float(sim.tax[Config.Zone.RES]) * 100.0), sim.research_done.size(),
			res, int(sim.research_budget)])
		if verbose:
			var inc_s := PackedStringArray()
			for k: String in sim.income_parts:
				if float(sim.income_parts[k]) > 0.5:
					inc_s.append("%s %d" % [k, roundi(float(sim.income_parts[k]))])
			print("humanrun    Monat: Einnahmen %s | Ausgaben: Sonderbauten %d, Straßen %d, Parks %d, ÖPNV %d, Zukauf %d, Verwaltung %d | Bau-Zukauf gesamt %d | Gebäude %s" % [
				", ".join(inc_s), roundi(sim.special_upkeep), roundi(sim.road_count * Config.UPKEEP_ROAD),
				roundi(sim.park_count * Config.UPKEEP_PARK), roundi(sim.bus_stop_count * Config.UPKEEP_BUS_STOP),
				roundi(sim.import_cost), roundi(sim.admin_cost), roundi(sim.build_imports), _special_counts()])
	for m in milestones:
		print("humanrun Meilenstein: %s" % m)
	var blockers := {}
	var zones := {}
	for i in map.size * map.size:
		if map.zone[i] != Config.Zone.NONE:
			zones[map.zone[i]] = int(zones.get(map.zone[i], 0)) + 1
			for b: String in sim.growth_blockers(i):
				var k := b.substr(0, 34)
				blockers[k] = int(blockers.get(k, 0)) + 1
	print("humanrun Ende: Zonen-Tiles W/G/I %s, Nachfrage W %.2f G %.2f I %.2f, Arbeitslos %d%%, Leerstand %d, Zufr. %d%%" % [
		zones, sim.demand_res, sim.demand_com, sim.demand_ind, roundi(sim.unemployment * 100.0), sim.vacant_count(),
		roundi(sim.city_happiness * 100.0)])
	print("humanrun Blocker: %s" % blockers)
	print("humanrun Zufriedenheit: %s" % sim.happy_parts)


func _special_counts() -> String:
	var cnt := {}
	for a in map.size * map.size:
		if map.anchor[a] == a and map.special[a] != Config.Special.NONE:
			var n: String = Config.SPECIALS[map.special[a]]["name"]
			cnt[n] = int(cnt.get(n, 0)) + 1
	return str(cnt)


## Ein "Blick" auf die Stadt alle 3 Monate. Jede Aufgabe wird mit gewisser Wahrscheinlichkeit erledigt.
func _think() -> void:
	# Steuer: knappe Kasse -> rauf (höchstens 11 %), unzufrieden + Geld da / viel Geld -> runter Richtung neutral
	var t_res := float(sim.tax[Config.Zone.RES])
	if sim.money < 1500 and t_res < 0.105:
		sim.tax[Config.Zone.RES] = t_res + 0.01
	elif (sim.money > 30000 or (sim.city_happiness < 0.4 and sim.money > 4000)) and t_res > Config.TAX_NEUTRAL[Config.Zone.RES]:
		sim.tax[Config.Zone.RES] = t_res - 0.01
	# Strom: Netze ohne Kraftwerk anschließen (Leitung), neues Kraftwerk nur bei echtem Leistungsmangel
	for net: Dictionary in sim.power_nets:
		if int(net["plants"]) == 0 and int(net["unserved"]) > 0 and int(net["dark"]) >= 0 and _chance(0.8):
			_connect(int(net["dark"]))
	var short := sim.power_demand > sim.power_supply * 0.85
	for net: Dictionary in sim.power_nets:
		if int(net["plants"]) > 0 and int(net["unserved"]) > 0:
			short = true
	if short and _chance(0.8):
		if sim.tech("hydro") and sim.money > 12000:
			_power_plant(T.HYDRO)
		elif sim.money > 5000 and sim.population > 1500:
			_power_plant(T.COAL)
		elif sim.money > 1800:
			_power_plant(T.BIOMASS if sim.population > 800 else T.WIND)
		else:
			_power_plant(T.WIND)
	# Dienste: fehlend -> bauen, überlastet -> ausbauen
	for pair: Array in [[T.FIRE, "fire"], [T.POLICE, "police"], [T.SCHOOL, "education"], [T.HOSPITAL, "health"],
			[T.LIBRARY, "culture"]]:
		var cat: String = pair[1]
		var spec: Array = Config.SERVICES[cat]
		if sim.population < int(spec[1]) or not _chance(0.6):
			continue
		var upgraded := false
		for a: int in sim.service_load:
			if map.anchor[a] == a and map.special[a] != Config.Special.NONE \
					and str(Config.SPECIALS[map.special[a]].get("service", "")) == cat \
					and float(sim.service_load[a]) > 1.0 and map.special_level(a) < 3 and sim.money > 4000:
				tools.set_tool(pair[0])
				tools.hover = Vector2i(a % map.size, a / map.size)
				tools._apply(tools._affected_tiles())
				tools.set_tool(T.INSPECT)
				upgraded = true
				break
		if not upgraded and float(sim.city_coverage.get(cat, 0.0)) < 0.7 and sim.money > 3000:
			_place(pair[0], _least_covered(cat))
	# Unzufrieden -> Park in Wohnnähe
	if sim.city_happiness < 0.55 and sim.money > 1000 and _chance(0.6):
		_place(T.PARK, _least_covered("education"))
	# Baustoffe selbst herstellen statt alles zukaufen (ein Mensch merkt die Zukaufkosten irgendwann)
	if sim.population > 600 and sim.money > 4000 and _chance(0.3):
		if not tools._special_present(Config.Special.LUMBER):
			_place(T.LUMBER, _near_feature(Config.Feature.TREE))
		elif not tools._special_present(Config.Special.SAWMILL):
			_place(T.SAWMILL, Vector2i(c, c))
		elif sim.population > 1000 and not tools._special_present(Config.Special.PIT):
			_place(T.PIT, _near_ore(Config.Ore.CLAY))
		elif sim.population > 1000 and not tools._special_present(Config.Special.BRICKWORKS):
			_place(T.BRICKWORKS, Vector2i(c, c))
	# Wachsen: Block nach Nachfrage – aber erst, wenn die vorhandenen Zonen größtenteils bebaut sind (ein Mensch sieht
	# leere Flächen und wartet)
	# je Zonenart prüfen (leeres Gewerbe soll neues Wohnen nicht blockieren)
	var zoned := {}
	var built := {}
	for i in map.size * map.size:
		var zn := map.zone[i]
		if zn != Config.Zone.NONE:
			zoned[zn] = int(zoned.get(zn, 0)) + 1
			if map.level[i] > 0:
				built[zn] = int(built.get(zn, 0)) + 1
	var tries := 2 if sim.money > 15000 else 1
	for k in tries:
		if sim.money < 1500 or not _chance(0.75):
			break
		var d := {Config.Zone.RES: sim.demand_res, Config.Zone.COM: sim.demand_com, Config.Zone.IND: sim.demand_ind}
		var best := -1
		for z: int in d:
			var full := float(built.get(z, 0)) >= float(zoned.get(z, 0)) * 0.6
			if float(d[z]) > 0.05 and full and (best < 0 or float(d[z]) > float(d[best])):
				best = z
		if best < 0:
			break
		_build_cell(best)
		zoned[best] = int(zoned.get(best, 0)) + 36
	# Forschung: Uni, Institut, Budget, Projekt
	if tools.locked_reason(T.UNIVERSITY) == "" and not tools._special_present(Config.Special.UNIVERSITY) \
			and sim.money > 25000 and _chance(0.5):
		if _place(T.UNIVERSITY, Vector2i(c, c)):
			milestones.append("%d: Universität (Einw. %d)" % [sim.year, sim.population])
	if tools.locked_reason(T.INSTITUTE) == "" and sim.institute_levels() == 0 and sim.money > 12000 and _chance(0.6):
		if _place(T.INSTITUTE, Vector2i(c, c)):
			milestones.append("%d: Forschungsinstitut" % sim.year)
	if sim.institute_levels() > 0:
		sim.research_budget = 5000.0 if sim.money > 150000 else (2000.0 if sim.money > 60000 else (1000.0 if sim.money > 20000
			else (500.0 if sim.money > 8000 else 0.0)))
		if sim.research_current == "":
			for id: String in research_order:
				if sim.research_blocker(id) == "" and sim.start_research(id) == "":
					milestones.append("%d: Forschung gestartet: %s (Kasse $%d)" % [sim.year, Config.RESEARCH[id]["name"], int(sim.money)])
					break
	for id: String in sim.research_done:
		var tag := "erforscht: " + str(Config.RESEARCH[id]["name"])
		var known := false
		for m in milestones:
			if m.ends_with(tag):
				known = true
		if not known:
			milestones.append("%d: %s" % [sim.year, tag])


func _chance(p: float) -> bool:
	return rng.randf() < p


## Nächsten Block der Spirale bebauen: Straßenring, Stromleitung über die Straße, Zone innen.
func _build_cell(zone: int) -> bool:
	while next_cell < cells.size():
		var cell := cells[next_cell]
		next_cell += 1
		var x0 := c + cell.x * CELL
		var z0 := c + cell.y * CELL
		var water := 0
		for z in range(z0 + 1, z0 + CELL):
			for x in range(x0 + 1, x0 + CELL):
				if not map.in_bounds(x, z) or map.is_water(x, z):
					water += 1
		if water > 10:
			continue
		var road: Array[Vector2i] = []
		for k in CELL + 1:
			road.append(Vector2i(x0 + k, z0))
			road.append(Vector2i(x0 + k, z0 + CELL))
			road.append(Vector2i(x0, z0 + k))
			road.append(Vector2i(x0 + CELL, z0 + k))
		_tool(T.ROAD, road)
		_tool(T.POWERLINE, [Vector2i(x0 + 3, z0), Vector2i(x0 + 3, z0 + CELL), Vector2i(x0, z0 + 3),
			Vector2i(x0 + CELL, z0 + 3)] as Array[Vector2i])
		var area: Array[Vector2i] = []
		for z in range(z0 + 1, z0 + CELL):
			for x in range(x0 + 1, x0 + CELL):
				area.append(Vector2i(x, z))
		var zt: int = {Config.Zone.RES: T.RES, Config.Zone.COM: T.COM, Config.Zone.IND: T.IND}[zone]
		_tool(zt, area)
		built_cells[cell] = zone
		return true
	return false


func _tool(t: int, tiles: Array[Vector2i]) -> void:
	tools.set_tool(t)
	tools._apply(tiles)
	tools.set_tool(T.INSPECT)


## Kraftwerk am Stadtrand, mit Leitung Richtung Mitte bis zum nächsten Leiter.
func _power_plant(t: int) -> void:
	var r := maxi(2, int(sqrt(float(next_cell)))) * CELL / 2 + 6
	var dir := Vector2(1, 0).rotated(rng.randf() * TAU)
	var target := Vector2i(c + int(dir.x * r), c + int(dir.y * r))
	var p := _place_at(t, target)
	if p.x < 0:
		return
	var x := p.x
	var z := p.y
	var line: Array[Vector2i] = []
	for k in 60:
		if x != c:
			x += signi(c - x)              # je Schritt nur eine Achse: diagonale Felder leiten nicht
		else:
			z += signi(c - z)
		if not map.in_bounds(x, z):
			break
		var i := map.idx(x, z)
		if map.zone[i] != Config.Zone.NONE or map.power_line[i] == 1 or map.special[i] != Config.Special.NONE:
			break
		line.append(Vector2i(x, z))
	_tool(T.POWERLINE, line)


func _place(t: int, target: Vector2i) -> bool:
	return _place_at(t, target).x >= 0


## Spiral-Suche um target nach einem gültigen Platz; baut dort. Rückgabe: Ursprung oder (-1,-1).
func _place_at(t: int, target: Vector2i) -> Vector2i:
	tools.set_tool(t)
	for r in range(0, 25):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var p := target + Vector2i(dx, dz)
				if not map.in_bounds(p.x, p.y):
					continue
				tools.hover = p
				var ok := true
				for q in tools._affected_tiles():
					if map.in_bounds(q.x, q.y) and map.power_line[map.idx(q.x, q.y)] == 1 and t != T.PARK:
						ok = false        # nicht auf Leitungen bauen (würde sie durchtrennen)
				var cost := 0
				for q in tools._affected_tiles():
					var k := tools.tile_cost(q)
					if k < 0:
						ok = false
						break
					cost += k
				if ok and cost > 0 and cost < sim.money:
					var m0 := sim.money
					tools._apply(tools._affected_tiles())
					tools.set_tool(T.INSPECT)
					return p if sim.money < m0 else Vector2i(-1, -1)
	tools.set_tool(T.INSPECT)
	return Vector2i(-1, -1)


## Netz ohne Kraftwerk: Leitung vom dunklen Tile Richtung Mitte, bis ein versorgtes Netz erreicht ist.
func _connect(dark: int) -> void:
	var x := dark % map.size
	var z := dark / map.size
	var line: Array[Vector2i] = []
	for k in 40:
		if x != c:
			x += signi(c - x)
		elif z != c:
			z += signi(c - z)
		else:
			break
		var i := map.idx(x, z)
		var pn := sim.power_net[i] if sim.power_net.size() > i else -1
		if pn >= 0 and pn < sim.power_nets.size() and int(sim.power_nets[pn]["plants"]) > 0:
			break
		if map.special[i] == Config.Special.NONE and map.zone[i] == Config.Zone.NONE:
			line.append(Vector2i(x, z))
	_tool(T.POWERLINE, line)


func _near_feature(f: int) -> Vector2i:
	var best := Vector2i(c, c)
	var bd := 1 << 30
	for i in map.size * map.size:
		if map.feature[i] == f:
			var d := absi(i % map.size - c) + absi(i / map.size - c)
			if d < bd and d > 12:
				bd = d
				best = Vector2i(i % map.size, i / map.size)
	return best


func _near_ore(o: int) -> Vector2i:
	var best := Vector2i(c, c)
	var bd := 1 << 30
	for i in map.size * map.size:
		if map.ore[i] == o and map.ore_amt[i] > 0:
			var d := absi(i % map.size - c) + absi(i / map.size - c)
			if d < bd:
				bd = d
				best = Vector2i(i % map.size, i / map.size)
	return best


## Wohn-Tile mit der schlechtesten Versorgung in dieser Kategorie (dort baut ein Mensch den Dienst).
func _least_covered(cat: String) -> Vector2i:
	var cov: PackedFloat32Array = sim.coverage.get(cat, PackedFloat32Array())
	var best := Vector2i(c, c)
	var low := 2.0
	for i in map.size * map.size:
		if map.zone[i] == Config.Zone.RES and map.level[i] > 0 and cov.size() > i and cov[i] < low:
			low = cov[i]
			best = Vector2i(i % map.size, i / map.size)
	return best
