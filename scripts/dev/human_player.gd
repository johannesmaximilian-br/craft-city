class_name HumanPlayer
extends RefCounted
## Balance-Messung (--humanrun=Jahre[,seed]): spielt einen Neustart "wie ein Mensch" statt optimal –
## schaut nur alle 3 Monate hin, lässt Dinge liegen (Zufall), baut nur mit Geld, reagiert auf Probleme
## (Strom, fehlende/überlastete Dienste, Unzufriedenheit, leere Kasse), forscht sobald möglich.
## Echter Start mit Rathaus (Gründung): Abbau/Werke nach Bedarf der nächsten Rathaus-Stufe (Rohstoff-Ketten), Rathaus
## ausbauen, sobald möglich, Lagerhäuser dort, wo Gebäude außerhalb jedes Lager-Kreises stehen.
## Stadt wächst dicht in kleinen Blöcken (Nutzer: Wohnen/Gewerbe max. 4x3, nah beieinander) ringförmig ums Rathaus,
## Industrie in eigenem Viertel abseits (Verschmutzung). Protokoll je Jahr + Meilensteine.

const CW := 5                          # Block-Raster: 4x3 Zone + Straße (Straßen werden mit dem Nachbarblock geteilt)
const CD := 4
const MAX_OWN := {"wood": 6, "bricks": 6, "clay": 6}   # Holz/Ziegel: Häuser + Instandhaltung verbrauchen am meisten
const BUFFER := 1                      # Blöcke Abstand zwischen Industrie und Wohnen/Gewerbe (Verschmutzung)
const T := ToolController.Tool

var game: Node
var map: CityMap
var sim: Simulation
var tools: ToolController
var rng := RandomNumberGenerator.new()
var c := 64
var cz := 64                           # Rasterursprung z (Rathaus-Mitte)
var cells: Array[Vector2i] = []        # Ausbau-Reihenfolge Wohnen/Gewerbe (nach Abstand)
var skipped := {}                      # Blöcke mit Wasser/Sonderbau (nie bebaubar)
var built_cells := {}                  # Vector2i -> Zone
var log_lines: Array[String] = []
var verbose := false
var milestones: Array[String] = []
var rail_lines := 0
var trade_answers := {}                # Verbraucher, für die gefragt wurde (Diagnose)
var saving := false                    # spart gerade für einen Betrieb
var gold_wait := 0                     # Monate, in denen ein Projekt auf Gold wartete
var gold_bought := 0.0
var gold_mined := 0.0
var producers := {}                   # Rohstoff -> Array[int] (Anker der eigenen Abbau-Betriebe/Werke)
var hall := Vector2i(-1, -1)
## Rohstoff -> [Werkzeug, Ort: "tree" | Config.Ore | Eingangs-Rohstoff (Werk)]
const CHAIN := {
	"wood": [T.LUMBER, "tree"], "stone": [T.QUARRY, Config.Ore.STONE], "clay": [T.PIT, Config.Ore.CLAY],
	"sand": [T.PIT, Config.Ore.SAND], "coal": [T.MINE, Config.Ore.COAL], "iron": [T.MINE, Config.Ore.IRON],
	"gold": [T.MINE, Config.Ore.GOLD], "planks": [T.SAWMILL, "wood"], "bricks": [T.BRICKWORKS, "clay"],
	"glass": [T.GLASSWORKS, "sand"], "steel": [T.STEELWORKS, "iron"],
}
var research_order := ["efficient_build", "traffic", "plant_filter", "solar", "concrete", "deep_mining", "battery",
	"highrise", "offices", "hightech", "blast_furnace", "hydro", "pumped", "salt"]


func run(g: Node, years: int, seed_value: int) -> void:
	game = g
	map = g.map
	sim = g.sim
	tools = g.tools
	rng.seed = seed_value
	# reproduzierbar: Zufall der Simulation (Wachstum, Brände, Erneuerung) und globaler Zufall fest
	seed(seed_value)
	sim._rng.seed = seed_value
	game.fire_dept._rng.seed = seed_value
	var loaded := DevTools.value("--loadfile") != ""      # mit --loadfile: auf dem geladenen Stand weiterspielen
	if loaded:
		for a in map.size * map.size:
			if map.anchor[a] == a and map.special[a] == Config.Special.CITYHALL:
				hall = Vector2i(a % map.size, a / map.size)
	else:
		DemoCity.generate_map(map)
		sim.reset()
		hall = CityStart.setup_build(map, sim)
	sim.trade_request.connect(_on_trade)
	c = hall.x + 1
	cz = hall.y + 1
	for j in range(-16, 17):
		for i in range(-14, 15):
			cells.append(Vector2i(i, j))
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return Vector2(a.x * CW, a.y * CD).length_squared() < Vector2(b.x * CW, b.y * CD).length_squared())
	# Gründung: Holzfäller + Steinbruch anschließen, ein Wohnblock
	if not loaded:
		_ensure("wood")
		_ensure("stone")
		_build_cell(Config.Zone.RES)
	print("humanrun Start %d: Kasse $%d, Holz %d, Stein %d nach Gründung, Betriebe %s" % [sim.year, int(sim.money),
		int(sim.stock["wood"]), int(sim.stock["stone"]), _special_counts()])
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
			seed(seed_value * 100000 + sim.year * 12 + m)    # globaler Zufall je Monat fest
			sim.tick_month()
			game.fire_dept.advance(12.0)           # Löschzüge fahren (im Spiel Echtzeit)
			inc += sim.last_income
			gold_mined += float(sim.production.get("gold", 0.0))
			exp += sim.last_expense
			if m % 3 == 2:
				_think()
		var res := "-"
		if sim.research_current != "":
			res = "%s %d%%" % [Config.RESEARCH[sim.research_current]["name"],
				roundi(100.0 * sim.research_progress / float(Config.RESEARCH[sim.research_current]["points"]))]
		var nx := sim.hall_next()
		print("humanrun %d: Kasse $%7d  Einw. %6d  Saldo/Jahr $%6d  Zufr. %2d%%  Strom %d/%d  Steuer W %d%%  Rathaus %d  fehlt %s  Lager-Lücke %d  erforscht %d  läuft: %s" % [
			sim.year, int(sim.money), sim.population, roundi(inc - exp), roundi(sim.city_happiness * 100.0),
			sim.power_demand, sim.power_supply, roundi(float(sim.tax[Config.Zone.RES]) * 100.0), sim.hall_level,
			"-" if nx.is_empty() else ",".join(nx["missing"]), CityMigrate.uncovered(map, sim), sim.research_done.size(), res])
		print(_diag())
		if verbose:
			var inc_s := PackedStringArray()
			for k: String in sim.income_parts:
				if float(sim.income_parts[k]) > 0.5:
					inc_s.append("%s %d" % [k, roundi(float(sim.income_parts[k]))])
			print("humanrun    Monat: Einnahmen %s | Ausgaben: Sonderbauten %d, Straßen %d, Parks %d, ÖPNV %d, Zukauf %d, Verwaltung %d | Bau-Zukauf gesamt %d | Gebäude %s" % [
				", ".join(inc_s), roundi(sim.special_upkeep), roundi(sim.road_count * Config.UPKEEP_ROAD),
				roundi(sim.park_count * Config.UPKEEP_PARK), roundi(sim.bus_stop_count * Config.UPKEEP_BUS_STOP),
				roundi(sim.import_cost), roundi(sim.admin_cost), roundi(sim.build_imports), _special_counts()])
			for r: String in producers:
				for pa: int in producers[r]:
					print("humanrun    Betrieb %s bei %d,%d: %s, Lager %s %d" % [r, pa % map.size, pa / map.size,
						sim.producer_info.get(pa, "keine Info"), r, int(sim.stock.get(r, 0.0))])
	for m in milestones:
		print("humanrun Meilenstein: %s" % m)
	print("humanrun Gebäude: %s" % _special_counts())
	print("humanrun Zukauf-Freigaben: %s, gefragt für %s" % [sim.trade_allow.keys(), trade_answers.keys()])
	var mines := 0
	for a in map.size * map.size:
		if map.anchor[a] == a and map.special[a] == Config.Special.MINE:
			mines += 1
	print("humanrun Gold: gefördert %d, für Forschung zugekauft %d, Wartezeit auf Gold %d Monate, Lager %d, Minen %d, erforscht %d/%d" % [
		int(gold_mined), int(gold_bought), gold_wait, int(sim.stock.get("gold", 0.0)), mines, sim.research_done.size(), Config.RESEARCH.size()])
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
	var res_comps := {}
	for i in map.size * map.size:
		if map.zone[i] == Config.Zone.RES:
			var acc := sim._access(i)
			for k in range(0, acc.size(), 2):
				var cc := sim.road_comp[int(acc[k])]
				res_comps[cc] = sim.comp_has_job.has(cc)
	print("humanrun Straßennetze an Wohnen (Netz: hat Jobs): %s, Netze mit Jobs %s" % [res_comps, sim.comp_has_job.keys()])
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
	# Rathaus ausbauen, sobald Einwohner + Material reichen
	var nx := sim.hall_next()
	if not nx.is_empty() and bool(nx["ok"]) and _chance(0.9):
		sim.upgrade_hall()
		milestones.append("%d: Rathaus Stufe %d (%s), Einw. %d" % [sim.year, sim.hall_level, nx["name"], sim.population])
		nx = sim.hall_next()
	# Sparmodus bei Schulden (ein Mensch zieht die Notbremse): überzählige Kraftwerke abreißen, Reserve aus, damit
	# Überschuss wieder verkauft wird
	var broke := sim.money < 0.0 and sim.last_income < sim.last_expense
	if broke:
		_austerity()
	# Rathaus-Reserve: sobald die Einwohner für die nächste Stufe fast reichen, Material zurücklegen
	sim.hall_reserve = not broke and not nx.is_empty() and sim.population >= int(nx["pop"]) * 0.9
	# Material: Ziel-Lagerstand je Rohstoff = Bedarf der nächsten Rathaus-Stufe + Vorrat fürs Wachsen der Häuser
	var want := {"wood": 150.0, "stone": 100.0}
	if sim.hall_level >= 2:
		want["planks"] = 150.0
		want["bricks"] = 200.0
	if sim.hall_level >= 3:
		want["glass"] = 80.0
		want["steel"] = 60.0
	if not nx.is_empty():
		for r: String in (nx["mats"] as Dictionary):
			want[r] = float(want.get(r, 0.0)) + float(nx["mats"][r])
	if sim.institute_levels() > 0:
		want["gold"] = 400.0                # Gold = Forschungswährung
	saving = broke
	for r: String in want:
		if broke and float(sim.stock.get(r, 0.0)) > 0.0:
			continue                        # in der Krise keine neuen Betriebe für Vorrat
		if _chance(0.8) and _ensure(r, float(want[r])):
			saving = true                   # Geld fehlt für einen Betrieb -> keine neuen Blöcke, erst sparen
	# Lager-Netz: Lagerhaus, wo die meisten Gebäude außerhalb jedes Lager-Kreises stehen
	if sim.population > 1000 and sim.money > 3000 and CityMigrate.uncovered(map, sim) > 25 and _chance(0.6):
		var p := _place_at(T.WAREHOUSE, CityMigrate._worst_gap(map, sim))
		if p.x >= 0:
			_link(p)
	# Steuer: knappe Kasse -> rauf (höchstens 11 %), unzufrieden + Geld da / viel Geld -> runter Richtung neutral
	var t_res := float(sim.tax[Config.Zone.RES])
	if sim.money < 1500 and t_res < 0.105:
		sim.tax[Config.Zone.RES] = t_res + 0.01
	elif (sim.money > 30000 or (sim.city_happiness < 0.6 and sim.money > 3000)) and t_res > Config.TAX_NEUTRAL[Config.Zone.RES]:
		sim.tax[Config.Zone.RES] = t_res - 0.01
	# Strom: Netze ohne Kraftwerk anschließen (Leitung), neues Kraftwerk nur bei echtem Leistungsmangel
	for net: Dictionary in sim.power_nets:
		if int(net["plants"]) == 0 and int(net["unserved"]) > 0 and int(net["dark"]) >= 0 and _chance(0.8):
			_connect(int(net["dark"]))
	# Netz mit Kraftwerk, aber unterversorgt: erst mit einem Netz mit Überschuss verbinden, nur bei echtem
	# Gesamtmangel neu bauen (vorher: neues Kraftwerk landete in einem anderen Netz -> 4x Überkapazität)
	var short := sim.power_demand > sim.power_supply * 0.9
	for ni in sim.power_nets.size():
		var net: Dictionary = sim.power_nets[ni]
		if int(net["plants"]) > 0 and int(net["unserved"]) > 0 and int(net["dark"]) >= 0:
			if not _link_to_surplus(int(net["dark"]), ni, float(net["demand"]) - float(net["capacity"])):
				short = true
			break                           # je Blick eine Verbindung (refresh nummeriert die Netze neu)
	if short and _chance(0.8) and not broke:     # in der Krise nicht neu bauen (sonst Abriss-Neubau-Schleife)
		if sim.tech("hydro") and sim.money > 12000:
			_power_plant(T.HYDRO)
		elif sim.money > 5000 and sim.population > 1500 and tools.locked_reason(T.COAL) == "":
			_power_plant(T.COAL)
		elif sim.money > 1800 and sim.population > 800 and tools.locked_reason(T.BIOMASS) == "" \
				and float(sim.stock["wood"]) > 400 and _count(Config.Special.BIOMASS) < 3:   # verheizt Holz -> nur bei Überschuss
			_power_plant(T.BIOMASS)
		else:
			_power_plant(T.WIND)
	# Dienste: erst vorhandene ausbauen (größerer Kreis, mehr Kapazität), neu nur wenn alle auf Stufe 3 sind
	for pair: Array in [[T.FIRE, "fire"], [T.POLICE, "police"], [T.SCHOOL, "education"], [T.HOSPITAL, "health"],
			[T.LIBRARY, "culture"]]:
		var cat: String = pair[1]
		if not sim.service_expected(cat) or not _chance(0.6) or tools.locked_reason(pair[0]) != "":
			continue
		var own: Array[int] = []
		var over := -1
		var low := -1
		for a in map.size * map.size:
			if map.anchor[a] != a or map.special[a] == Config.Special.NONE \
					or str(Config.SPECIALS[map.special[a]].get("service", "")) != cat:
				continue
			own.append(a)
			if map.special_level(a) < 3:
				if float(sim.service_load.get(a, 0.0)) > 1.0 and over < 0:
					over = a
				if low < 0 or map.special_level(a) < map.special_level(low):
					low = a
		var cov := float(sim.city_coverage.get(cat, 0.0))
		var pick := over if over >= 0 else (low if cov < 0.7 else -1)
		if pick >= 0:
			var sp: int = map.special[pick]
			if sim.money > float(Config.SPECIALS[sp]["upgrade"]) * map.special_level(pick) + 1000.0:
				tools.set_tool(pair[0])
				tools.hover = Vector2i(pick % map.size, pick / map.size)
				tools._apply(tools._affected_tiles())
				tools.set_tool(T.INSPECT)
			continue                        # lieber auf den Ausbau sparen als ein weiteres Gebäude
		if (own.is_empty() and cov < 0.7) or (cov < 0.6 and low < 0):
			if sim.money > float(Config.SPECIALS[ToolController.special_for(pair[0])]["cost"]) + 1000.0:
				_place(pair[0], _least_covered(cat))
	# Wohnen begutachten: wo bremst Bodenwert, wo Stau?
	var low_land: Array[int] = []
	var jammed: Array[int] = []
	for i in map.size * map.size:
		if map.zone[i] != Config.Zone.RES or map.level[i] == 0:
			continue
		for b: String in sim.growth_blockers(i):
			if b.begins_with("Bodenwert"):
				low_land.append(i)
			elif b.begins_with("Arbeitsweg"):
				jammed.append(i)
	# Unzufrieden oder Bodenwert bremst -> Parks mitten ins Wohngebiet (heben Bodenwert + Zufriedenheit)
	if tools.locked_reason(T.PARK) == "" and sim.money > 1500 and _chance(0.7) \
			and (sim.city_happiness < 0.55 or low_land.size() > 15):
		for k in mini(2, maxi(1, low_land.size() / 20)):
			var at := _least_covered("education") if low_land.is_empty() else _tile(low_land[rng.randi() % low_land.size()])
			_place(T.PARK, at)
	# Stau -> verstopfte Straßenstücke verbreitern (Parallelstraße = Hauptstraße)
	if sim.congestion.size() == map.size * map.size and sim.money > 2000 and _chance(0.7):
		var hot: Array[int] = []
		for i in map.size * map.size:
			if map.road[i] != 0 and sim.congestion[i] > 1.2 and map.wide_partner(i % map.size, i / map.size) == Vector2i.ZERO:
				hot.append(i)
		hot.sort_custom(func(a: int, b: int) -> bool: return sim.congestion[a] > sim.congestion[b])
		var extra: Array[Vector2i] = []
		for i: int in hot.slice(0, 12):
			var x := i % map.size
			var z := i / map.size
			var along_x := map.is_road(x - 1, z) or map.is_road(x + 1, z)
			for side: Vector2i in ([Vector2i(0, 1), Vector2i(0, -1)] if along_x else [Vector2i(1, 0), Vector2i(-1, 0)]):
				var q := Vector2i(x, z) + side
				if map.in_bounds(q.x, q.y) and _free(map.idx(q.x, q.y)):
					extra.append(q)
					break
		if not extra.is_empty():
			_tool(T.ROAD, extra)
	# Stau -> Bahn (ab Stadt): Linie vom verstopften Wohnviertel zur größten Arbeitsplatz-Ballung, Bahnhöfe unterwegs
	if tools.locked_reason(T.RAIL) == "" and jammed.size() > 40 and sim.money > 8000 and rail_lines < 3 and _chance(0.6):
		if _rail_line(jammed[rng.randi() % jammed.size()]):
			rail_lines += 1
			milestones.append("%d: Bahnlinie %d (Einw. %d, Stau-Tiles %d)" % [sim.year, rail_lines, sim.population, jammed.size()])
	# Viel Geld: wie ein Spieler investieren – Steuern senken, Dienste/Parks/Lager ausbauen
	if sim.money > 20000:
		_spend_rich()
	# Stau -> Bushaltestellen (ab Kleinstadt): an verstopften Wohnstraßen und im Industrie-Viertel
	if tools.locked_reason(T.BUS_STOP) == "" and jammed.size() > 20 and sim.money > 2500 and sim.bus_stop_count < 16 \
			and _chance(0.7):
		_place(T.BUS_STOP, _tile(jammed[rng.randi() % jammed.size()]))

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
	var tries := 4 if sim.money > 15000 else 2
	for k in tries:
		if sim.money < (300 if sim.hall_level < 2 else 800) or not _chance(0.75) or (saving and sim.money < 6000):
			break
		var d := {Config.Zone.RES: sim.demand_res, Config.Zone.COM: sim.demand_com, Config.Zone.IND: sim.demand_ind}
		var best := -1
		for z: int in d:
			var full := float(built.get(z, 0)) >= float(zoned.get(z, 0)) * 0.6
			var zt: int = {Config.Zone.RES: T.RES, Config.Zone.COM: T.COM, Config.Zone.IND: T.IND}[z]
			if tools.locked_reason(zt) != "":
				continue
			if float(d[z]) > 0.05 and full and (best < 0 or float(d[z]) > float(d[best])):
				best = z
		if best < 0:
			break
		_build_cell(best)
		zoned[best] = int(zoned.get(best, 0)) + (CW - 1) * (CD - 1)
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
				if sim.research_blocker(id) != "":
					continue
				var g := float(Config.RESEARCH[id]["gold"])
				var gshort := maxf(g - float(sim.stock.get("gold", 0.0)), 0.0)
				# ein Mensch wartet auf eigenes Gold, solange der Zukauf mehr als ein Viertel der Kasse kostet
				if gshort > 0.0 and gshort * float(Config.RESOURCES["gold"]["price"]) * Config.IMPORT_FACTOR > sim.money * 0.25:
					gold_wait += 3
					break
				if sim.start_research(id) == "":
					gold_bought += gshort
					milestones.append("%d: Forschung gestartet: %s (Gold %d, davon zugekauft %d, Kasse $%d)" % [sim.year,
						Config.RESEARCH[id]["name"], int(g), int(gshort), int(sim.money)])
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


## Nächsten Block bebauen (Wohnen/Gewerbe nah am Rathaus, Industrie im eigenen Viertel): Straßenring, Stromleitung
## über die Straße, 4x3-Zone innen.
func _build_cell(zone: int) -> bool:
	var ind := zone == Config.Zone.IND
	var cell := _next_cell(ind)
	while cell.x != 9999:
		var x0 := c + cell.x * CW
		var z0 := cz + cell.y * CD
		var water := 0
		var blocked := false
		for z in range(z0, z0 + CD + 1):
			for x in range(x0, x0 + CW + 1):
				if not map.in_bounds(x, z) or map.is_water(x, z):
					water += 1
				elif map.special[map.idx(x, z)] != Config.Special.NONE:
					blocked = true          # Rathaus/Betriebe nicht überbauen
		if water > 3 or blocked:
			skipped[cell] = true
			cell = _next_cell(ind)
			continue
		# Gründung (kein Zukauf): Straßenring braucht Stein, Wohnhäuser Holz -> warten, bis das Lager reicht
		if not sim.can_trade() and (float(sim.stock["stone"]) < (CW + CD) * 4 + 10 or float(sim.stock["wood"]) < 25):
			return false
		var road: Array[Vector2i] = []
		for k in CW + 1:
			road.append(Vector2i(x0 + k, z0))
			road.append(Vector2i(x0 + k, z0 + CD))
		for k in CD + 1:
			road.append(Vector2i(x0, z0 + k))
			road.append(Vector2i(x0 + CW, z0 + k))
		_tool(T.ROAD, road)
		_tool(T.POWERLINE, [Vector2i(x0 + 2, z0), Vector2i(x0 + 2, z0 + CD), Vector2i(x0, z0 + 2),
			Vector2i(x0 + CW, z0 + 2)] as Array[Vector2i])
		var area: Array[Vector2i] = []
		for z in range(z0 + 1, z0 + CD):
			for x in range(x0 + 1, x0 + CW):
				area.append(Vector2i(x, z))
		var zt: int = {Config.Zone.RES: T.RES, Config.Zone.COM: T.COM, Config.Zone.IND: T.IND}[zone]
		_tool(zt, area)
		built_cells[cell] = zone
		_link_road(road)
		sim.refresh()
		if sim.powered.size() > map.idx(x0 + 1, z0 + 1) and sim.powered[map.idx(x0 + 1, z0 + 1)] == 0:
			_link_power(area)
		return true
	return false


## Nächster freier Block: Wohnen/Gewerbe so nah am Rathaus wie möglich, Industrie als Ring außen herum –
## jeweils mit BUFFER Blöcken Abstand zur anderen Art (Verschmutzung). (9999, 0) = keiner.
func _next_cell(ind: bool) -> Vector2i:
	for cell in cells:
		if built_cells.has(cell) or skipped.has(cell):
			continue
		var ok := true
		var near_city := false
		for other: Vector2i in built_cells:
			var d := maxi(absi(other.x - cell.x), absi(other.y - cell.y))
			var other_ind: bool = built_cells[other] == Config.Zone.IND
			if d <= BUFFER and other_ind != ind:
				ok = false
				break
			if d <= BUFFER + 1 and not other_ind:
				near_city = true
		if not ok:
			continue
		if ind and built_cells.size() > 0 and not near_city:
			continue                      # Industrie nur direkt hinter dem Abstand zur Stadt (kurze Wege)
		return cell
	return Vector2i(9999, 0)


func _tool(t: int, tiles: Array[Vector2i]) -> void:
	tools.set_tool(t)
	tools._apply(tiles)
	tools.set_tool(T.INSPECT)


## Kraftwerk am Stadtrand, mit Leitung Richtung Mitte bis zum nächsten Leiter.
func _power_plant(t: int) -> void:
	var r := maxi(2, int(sqrt(float(built_cells.size())))) * CW / 2 + 8
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


## Rohstoff r selbst herstellen: fehlt ein eigener Betrieb (oder fördert keiner mehr, z. B. Wald abgeholzt), einen
## bauen und anschließen; liegt das Lager unter target, den kleinsten Betrieb ausbauen bzw. einen weiteren bauen.
## Werke ziehen ihren Eingangs-Rohstoff mit. Rückgabe true = fehlt nur das Geld (Bot spart dann).
func _ensure(r: String, target := 0.0) -> bool:
	if not CHAIN.has(r):
		return false
	var t: int = CHAIN[r][0]
	var src: Variant = CHAIN[r][1]
	var poor := false
	if src is String and src != "tree":
		poor = _ensure(str(src), target)
	var own: Array = []
	for a: int in producers.get(r, []):
		if map.anchor[a] == a and map.special[a] != Config.Special.NONE:
			own.append(a)
	producers[r] = own
	var producing := false
	for a: int in own:
		var info: Dictionary = sim.producer_info.get(a, {})
		var issue := str(info.get("issue", ""))
		if issue.contains("Strom") or issue.contains("Straße"):
			_link(Vector2i(a % map.size, a / map.size))
		if issue.contains("Kein Wald") and tools.locked_reason(T.NURSERY) == "" and not _nursery_near(a):
			var np := _place_at(T.NURSERY, Vector2i(a % map.size, a / map.size))   # nachpflanzen statt weiterziehen
			if np.x >= 0:
				_link(np)
		if not (info.get("out", {}) as Dictionary).is_empty() or info.is_empty() or map.construct[a] > 0:
			producing = true
	if tools.locked_reason(t) != "":
		return poor
	var sp := ToolController.special_for(t)
	var short := target > 0.0 and float(sim.stock.get(r, 0.0)) < target
	if not own.is_empty() and producing and short:
		# knapp: kleinsten Betrieb ausbauen (billiger als neu), sonst weiteren bauen
		var low := -1
		for a: int in own:
			if map.special_level(a) < 3 and (low < 0 or map.special_level(a) < map.special_level(low)):
				low = a
		if low >= 0:
			var up := float(Config.SPECIALS[sp]["upgrade"]) * map.special_level(low)
			if sim.money < up + 500.0:
				return true
			tools.set_tool(t)
			tools.hover = Vector2i(low % map.size, low / map.size)
			tools._apply(tools._affected_tiles())
			tools.set_tool(T.INSPECT)
			return poor
		if own.size() >= int(MAX_OWN.get(r, 4)) - 1:
			return poor
	elif not own.is_empty() and producing:
		return poor
	if own.size() >= int(MAX_OWN.get(r, 4)):
		return poor
	var price := float(Config.SPECIALS[sp]["cost"])
	if sim.hall_level < 2:
		price *= Config.BUILD_FOUNDING_COST
	elif sim.hall_level == 2:
		price *= Config.VILLAGE_WORKS_COST
	if sim.money < price + 300.0:
		return true
	var at := Vector2i(c, cz)
	if src is String and src == "tree":
		at = _near_feature(Config.Feature.TREE)
	elif src is int:
		at = _near_ore(int(src))
	else:
		for cell: Vector2i in built_cells:
			if built_cells[cell] == Config.Zone.IND:
				at = Vector2i(c + cell.x * CW, cz + cell.y * CD)        # Werke neben die Industrie
				break
	var p := _place_at(t, at)
	if p.x < 0:
		return poor
	own.append(map.idx(p.x, p.y))
	producers[r] = own
	_link(p)
	return poor


## Sonderbau bei p an Straßennetz (Rathaus) und Strom anschließen.
func _link(p: Vector2i) -> void:
	var a := map.idx(p.x, p.y)
	if map.special[a] == Config.Special.NONE:
		return
	var s: int = Config.SPECIALS[map.special[a]]["size"]
	var around: Array[Vector2i] = []
	for z in range(p.y - 1, p.y + s + 1):
		for x in range(p.x - 1, p.x + s + 1):
			var edge := (x == p.x - 1 or x == p.x + s) != (z == p.y - 1 or z == p.y + s)
			if edge and map.in_bounds(x, z):
				around.append(Vector2i(x, z))
	_link_road(around)
	sim.refresh()
	var pn := sim.power_net[a] if sim.power_net.size() > a else -1
	if pn < 0 or pn >= sim.power_nets.size() or int(sim.power_nets[pn]["plants"]) == 0:
		_link_power(around)             # (Baustelle zählt noch nicht als Kraftwerk -> Leitung schadet nicht)


## Straße von einem der Start-Tiles zum Straßennetz des Rathauses (kürzester Weg über freies Land).
func _link_road(starts: Array[Vector2i]) -> void:
	var main := _main_roads()
	var path := _bfs(starts, func(i: int) -> bool: return _free(i) or map.road[i] != 0,
		func(i: int) -> bool: return main.has(i))
	var build: Array[Vector2i] = []
	for q in path:
		if map.road[map.idx(q.x, q.y)] == 0:
			build.append(q)
	if not build.is_empty():
		_tool(T.ROAD, build)


## Stromleitung von einem der Start-Tiles bis zum nächsten Tile eines Netzes mit Kraftwerk (über Land und Straßen).
func _link_power(starts: Array[Vector2i]) -> void:
	var path := _bfs(starts, func(i: int) -> bool: return _free(i) or map.road[i] != 0,
		func(i: int) -> bool:
			var pn := sim.power_net[i] if sim.power_net.size() > i else -1
			return pn >= 0 and pn < sim.power_nets.size() and int(sim.power_nets[pn]["plants"]) > 0)
	if path.size() > 1:
		path.pop_back()                 # Ziel leitet schon
		var line: Array[Vector2i] = []
		for q in path:
			var qi := map.idx(q.x, q.y)
			if _free(qi) or map.road[qi] != 0:
				line.append(q)
		_tool(T.POWERLINE, line)
	if verbose:
		var hn := sim.power_net[map.idx(hall.x, hall.y)]
		print("humanrun Leitung: Weg %d Tiles %s, Rathaus-Netz %d (Kraftwerke %d)" % [path.size(), path.slice(0, 3), hn,
			int(sim.power_nets[hn]["plants"]) if hn >= 0 else -1])


func _free(i: int) -> bool:
	return map.special[i] == Config.Special.NONE and map.zone[i] == Config.Zone.NONE and map.rail[i] == 0 \
		and not map.is_water(i % map.size, i / map.size)


## Straßen-Tiles, die mit dem Rathaus verbunden sind.
func _main_roads() -> Dictionary:
	var seen := {}
	var queue: Array[int] = []
	for z in range(hall.y - 1, hall.y + 4):
		for x in range(hall.x - 1, hall.x + 4):
			if map.in_bounds(x, z) and map.road[map.idx(x, z)] != 0:
				seen[map.idx(x, z)] = true
				queue.append(map.idx(x, z))
	var head := 0
	while head < queue.size():
		var i := queue[head]
		head += 1
		for n in _neighbors(i):
			if map.road[n] != 0 and not seen.has(n):
				seen[n] = true
				queue.append(n)
	return seen


func _neighbors(i: int) -> Array[int]:
	var out: Array[int] = []
	var x := i % map.size
	var z := i / map.size
	if x > 0: out.append(i - 1)
	if x < map.size - 1: out.append(i + 1)
	if z > 0: out.append(i - map.size)
	if z < map.size - 1: out.append(i + map.size)
	return out


## Breitensuche von starts über passable-Tiles bis zum ersten goal-Tile; Weg inkl. Start und Ziel, [] = keiner.
func _bfs(starts: Array[Vector2i], passable: Callable, goal: Callable, limit := 50) -> Array[Vector2i]:
	var prev := {}
	var dist := {}
	var queue: Array[int] = []
	for q in starts:
		if not map.in_bounds(q.x, q.y):
			continue
		var i := map.idx(q.x, q.y)
		if goal.call(i):
			return [q] as Array[Vector2i]
		if not prev.has(i):              # Start-Tiles dürfen selbst unpassierbar sein (z. B. Zone)
			prev[i] = -1
			dist[i] = 0
			queue.append(i)
	var head := 0
	while head < queue.size():
		var i := queue[head]
		head += 1
		if int(dist[i]) >= limit:
			continue
		for n in _neighbors(i):
			if prev.has(n):
				continue
			if goal.call(n):
				var path: Array[Vector2i] = [Vector2i(n % map.size, n / map.size)]
				var k := i
				while k != -1:
					path.push_front(Vector2i(k % map.size, k / map.size))
					k = prev[k]
				return path
			if passable.call(n):
				prev[n] = i
				dist[n] = int(dist[i]) + 1
				queue.append(n)
	return [] as Array[Vector2i]


func _nursery_near(a: int) -> bool:
	var ax := a % map.size
	var az := a / map.size
	for z in range(az - Config.LUMBER_RANGE, az + Config.LUMBER_RANGE + 1):
		for x in range(ax - Config.LUMBER_RANGE, ax + Config.LUMBER_RANGE + 1):
			if map.in_bounds(x, z) and map.special[map.idx(x, z)] == Config.Special.NURSERY:
				return true
	return false


## Jahres-Diagnose: je Zone Tiles/bebaut/Stufen, häufigste Blocker, Baustoff-Lager.
func _diag() -> String:
	var zn_names := {Config.Zone.RES: "W", Config.Zone.COM: "G", Config.Zone.IND: "I"}
	var tiles := {}
	var lv := {}
	var why := {}
	for i in map.size * map.size:
		var z := map.zone[i]
		if z == Config.Zone.NONE:
			continue
		tiles[z] = int(tiles.get(z, 0)) + 1
		var key := "%s%d" % [zn_names[z], map.level[i]]
		lv[key] = int(lv.get(key, 0)) + 1
		for b: String in sim.growth_blockers(i):
			var k := b.substr(0, 28)
			why[k] = int(why.get(k, 0)) + 1
	var top := why.keys()
	top.sort_custom(func(a, b): return int(why[a]) > int(why[b]))
	var tb := PackedStringArray()
	for k in top.slice(0, 4):
		tb.append("%s %d" % [k, why[k]])
	var levels := PackedStringArray()
	for z in [Config.Zone.RES, Config.Zone.COM, Config.Zone.IND]:
		var parts := PackedStringArray()
		for l in 5:
			var n := int(lv.get("%s%d" % [zn_names[z], l], 0))
			if n > 0:
				parts.append("%d:%d" % [l, n])
		levels.append("%s[%s]" % [zn_names[z], " ".join(parts)])
	var st := PackedStringArray()
	for r in ["wood", "stone", "planks", "bricks", "glass", "steel", "gold"]:
		st.append("%s %d" % [r.substr(0, 3), int(sim.stock.get(r, 0.0))])
	return "humanrun    Zonen %s | Blocker: %s | Lager: %s" % [" ".join(levels), ", ".join(tb), " ".join(st)]


func _tile(i: int) -> Vector2i:
	return Vector2i(i % map.size, i / map.size)


## Unterversorgtes Netz (Tile dark, Index ni) per Leitung mit einem anderen Netz verbinden, das deficit MW übrig hat.
func _link_to_surplus(dark: int, ni: int, deficit: float) -> bool:
	var ok_nets := {}
	for k in sim.power_nets.size():
		var n: Dictionary = sim.power_nets[k]
		if k != ni and float(n["capacity"]) - float(n["demand"]) > maxf(deficit, 5.0):
			ok_nets[k] = true
	if ok_nets.is_empty():
		return false
	var start: Array[Vector2i] = [_tile(dark)]
	var path := _bfs(start, func(i: int) -> bool: return _free(i) or map.road[i] != 0 or sim.power_net[i] == ni,
		func(i: int) -> bool: return sim.power_net.size() > i and ok_nets.has(sim.power_net[i]), 60)
	if path.size() < 2:
		return false
	var line: Array[Vector2i] = []
	for q in path:
		var qi := map.idx(q.x, q.y)
		if _free(qi) or map.road[qi] != 0:
			line.append(q)
	_tool(T.POWERLINE, line)
	sim.refresh()
	return true


## Bahnlinie: von einem Stau-Wohntile zum Schwerpunkt der Arbeitsplätze (Gewerbe + Industrie), Gleise über freies Land
## und Straßen (kreuzen erlaubt), Bahnhöfe auf Gleis-Tiles ohne Straße alle >= 8 Tiles (Anfang, Mitte, Ende).
func _rail_line(from: int) -> bool:
	var sx := 0.0
	var sz := 0.0
	var w := 0.0
	for i in map.size * map.size:
		if (map.zone[i] == Config.Zone.IND or map.zone[i] == Config.Zone.COM) and map.level[i] > 0:
			var f := float(map.jobs_at(i))
			sx += (i % map.size) * f
			sz += (i / map.size) * f
			w += f
	if w <= 0.0:
		return false
	var goal := Vector2i(int(sx / w), int(sz / w))
	if _tile(from).distance_to(goal) < 10.0:
		return false                      # zu kurz: Bahn lohnt nicht
	var path := _bfs([_tile(from)] as Array[Vector2i],
		func(i: int) -> bool: return _free(i) or map.road[i] != 0 or map.rail[i] != 0,
		func(i: int) -> bool: return _tile(i).distance_to(goal) <= 2.0 and (_free(i) or map.rail[i] != 0), 90)
	if path.size() < 10:
		return false
	path.pop_front()                      # Start ist ein Wohntile
	var track: Array[Vector2i] = []
	for q in path:
		if _free(map.idx(q.x, q.y)) or map.road[map.idx(q.x, q.y)] != 0 or map.rail[map.idx(q.x, q.y)] != 0:
			track.append(q)
	var m0 := sim.money
	_tool(T.RAIL, track)
	if sim.money >= m0:
		return false                      # nichts gebaut (Material/Geld)
	var last := -100
	var stations := 0
	for k in track.size():
		var q := track[k]
		var qi := map.idx(q.x, q.y)
		if map.rail[qi] == 0 or map.road[qi] != 0:
			continue
		if k - last >= 8 or k == track.size() - 1 or stations == 0:
			_tool(T.STATION, [q] as Array[Vector2i])
			if map.transit[qi] == Config.Transit.STATION:
				last = k
				stations += 1
	sim.refresh()
	return stations >= 2


## Reiche Stadt: Steuern zurück auf neutral, Dienste bis 90 % Versorgung ausbauen, Parks bis die
## Leute zufrieden sind, Lagerhäuser ausbauen.
func _spend_rich() -> void:
	for zn in [Config.Zone.RES, Config.Zone.COM, Config.Zone.IND]:
		if float(sim.tax[zn]) > float(Config.TAX_NEUTRAL[zn]) + 0.001:
			sim.tax[zn] = float(Config.TAX_NEUTRAL[zn])   # nur zurück auf neutral (Nutzer: Zufriedenheit über Planung, nicht Steuer)
	for pair: Array in [[T.FIRE, "fire"], [T.POLICE, "police"], [T.SCHOOL, "education"], [T.HOSPITAL, "health"],
			[T.LIBRARY, "culture"]]:
		var cat: String = pair[1]
		if not sim.service_expected(cat) or tools.locked_reason(pair[0]) != "" \
				or float(sim.city_coverage.get(cat, 0.0)) >= 0.9 or sim.money < 15000:
			continue
		var low := -1
		for a in map.size * map.size:
			if map.anchor[a] == a and map.special[a] != Config.Special.NONE \
					and str(Config.SPECIALS[map.special[a]].get("service", "")) == cat and map.special_level(a) < 3 \
					and (low < 0 or map.special_level(a) < map.special_level(low)):
				low = a
		if low >= 0:
			tools.set_tool(pair[0])
			tools.hover = _tile(low)
			tools._apply(tools._affected_tiles())
			tools.set_tool(T.INSPECT)
		else:
			_place(pair[0], _least_covered(cat))
	if sim.city_happiness < 0.8 and tools.locked_reason(T.PARK) == "" and sim.money > 15000:
		for k in 3:
			_place(T.PARK, _least_covered("education"))
	for a in map.size * map.size:
		if map.anchor[a] == a and map.special[a] == Config.Special.WAREHOUSE and map.special_level(a) < 3 \
				and sim.money > 15000:
			tools.set_tool(T.WAREHOUSE)
			tools.hover = _tile(a)
			tools._apply(tools._affected_tiles())
			tools.set_tool(T.INSPECT)


## Zukauf-Nachfrage des Bürgermeisters: Brennstoff bei genug Geld dauerhaft, Baustoffe nur, wenn der Preis klein gegen
## die Kasse ist (einmalig), sonst ablehnen.
func _on_trade(req: Dictionary) -> void:
	for r: String in req:
		var cost := float(req[r]["cost"])
		if (r == "coal" or r == "wood") and sim.money > 5000.0:
			sim.answer_trade(r, "always")
		elif sim.money > cost * 3.0 + 3000.0:
			sim.answer_trade(r, "once")
		else:
			sim.answer_trade(r, "no")
		trade_answers[str(req[r].get("uses", ""))] = true


func _count(sp: int) -> int:
	var n := 0
	for a in map.size * map.size:
		if map.anchor[a] == a and map.special[a] == sp:
			n += 1
	return n


## Sparmodus: solange die Leistung > 130 % des Bedarfs ist, je Blick ein Kraftwerk abreißen (Biomasse vor Wind vor Kohle).
func _austerity() -> void:
	if sim.power_supply <= sim.power_demand * 1.3:
		return
	for sp in [Config.Special.BIOMASS, Config.Special.WIND, Config.Special.COAL]:
		for a in map.size * map.size:
			if map.anchor[a] != a or map.special[a] != sp:
				continue
			var p := float(Config.SPECIALS[sp]["power"])
			if sim.power_supply - p < sim.power_demand * 1.15:
				return
			tools.set_tool(T.BULLDOZE)
			tools.hover = _tile(a)
			tools._apply(tools._affected_tiles())
			tools.set_tool(T.INSPECT)
			sim.refresh()
			var gone: bool = map.special[a] != sp
			milestones.append("%d: Sparmodus - %s %s (Kasse $%d)" % [sim.year, Config.SPECIALS[sp]["name"],
				"abgerissen" if gone else "Abriss fehlgeschlagen", int(sim.money)])
			return
