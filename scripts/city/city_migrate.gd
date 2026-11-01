class_name CityMigrate
extends RefCounted
## Spielstände aus der Zeit vor dem Aufbau-Start (früher „klassischer Modus“) beim Laden umrechnen:
## Rathaus-Stufe aus Einwohnern + bereits Gebautem, Rathaus auf eine freie Fläche, Lagerhäuser dort, wo Gebäude
## außerhalb jedes Lager-Kreises stehen (notfalls wird dafür abgerissen). Die Datei selbst bleibt unverändert,
## beim nächsten Speichern wird im neuen Format geschrieben.

const MAX_STORES := 40

static var last := {}                 # Ergebnis der letzten Umrechnung (Tests/Meldung)
static var disabled := false          # Dev: --nomigrate (Vergleich mit dem Stand vor der Umrechnung)


## Gehört der gespeicherte Sim-Zustand zu einem alten Spielstand?
static func needed(sim_data: Dictionary) -> bool:
	return not disabled and str(sim_data.get("game_mode", "classic")) != "build"


## Umrechnen. Gibt {level, hall, stores, demolished} zurück.
static func run(map: CityMap, sim: Simulation) -> Dictionary:
	var level := level_for(map, sim)
	sim.hall_level = level
	sim.allow_all_trade()                 # Altstände kauften automatisch zu – so bleibt es (änderbar im Rathaus-Fenster)
	map.construct.fill(0)                 # alles Gebaute ist fertig
	var demolished := 0
	var hall := -1
	for a in map.size * map.size:
		if map.anchor[a] == a and map.special[a] == Config.Special.CITYHALL:
			hall = a
	if hall < 0:
		var site := best_site(map, 3, _centroid(map))
		if site.x >= 0:
			demolished += place(map, Config.Special.CITYHALL, site, mini(level, 3))
			hall = map.idx(site.x, site.y)
	var stores := 0
	var left := -1
	for k in MAX_STORES:
		sim._compute_store_cover()
		var gap := uncovered(map, sim)
		if gap == 0 or gap == left:
			break                         # alles versorgt bzw. letztes Lager hat nichts gebracht
		left = gap
		var target := _worst_gap(map, sim)
		var site := best_site(map, 2, target)
		if site.x < 0:
			break
		demolished += place(map, Config.Special.WAREHOUSE, site, 3)
		stores += 1
	map.notify_changed(Rect2i(0, 0, map.size, map.size))
	sim.refresh()
	sim.message.emit("Spielstand umgestellt: Rathaus Stufe %d (%s), %s%d Lager gesetzt%s" % [level,
		Config.HALL_LEVELS[level]["name"], "Rathaus + " if hall >= 0 else "", stores,
		(", %d Gebäude dafür abgerissen" % demolished) if demolished > 0 else ""])
	last = {"level": level, "hall": hall, "stores": stores, "demolished": demolished}
	return last


## Gebäude außerhalb jedes Lager-Kreises.
static func uncovered(map: CityMap, sim: Simulation) -> int:
	var c := 0
	for i in map.size * map.size:
		if map.zone[i] != Config.Zone.NONE and map.level[i] > 0 and sim.store_cover[i] == 0:
			c += 1
	return c


## Höchste Stufe, deren Einwohnerzahl erreicht ist – mindestens so hoch, dass nichts Gebautes gesperrt wäre.
static func level_for(map: CityMap, sim: Simulation) -> int:
	var level := 1
	for lv in range(2, Config.HALL_LEVELS.size()):
		if sim.population >= int(Config.HALL_LEVELS[lv].get("pop", 0)):
			level = lv
	var need_sp := {}
	for t: int in ToolController.HALL_LEVEL:
		var sp := ToolController.special_for(t)
		if sp != Config.Special.NONE:
			need_sp[sp] = int(ToolController.HALL_LEVEL[t])
	var top := Config.HALL_LEVELS.size() - 1
	for i in map.size * map.size:
		if map.zone[i] == Config.Zone.COM or map.zone[i] == Config.Zone.IND:
			level = maxi(level, 2)
		if map.hightech[i] == 1:
			level = maxi(level, top)
		if map.rail[i] != 0:
			level = maxi(level, int(ToolController.HALL_LEVEL[ToolController.Tool.RAIL]))
		if map.special[i] != Config.Special.NONE and need_sp.has(map.special[i]):
			level = maxi(level, int(need_sp[map.special[i]]))
	if not sim.research_done.is_empty():
		level = top
	return level


## Fläche size×size nahe center: flach (max. 1 Block Unterschied), kein Wasser/Straße/Gleis/Sonderbau, an einer Straße.
## Bevorzugt leere Flächen; Gebäude zählen als Abriss-Kosten. (-1, -1) = nichts gefunden.
static func best_site(map: CityMap, size: int, center: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_cost := INF
	for r in range(0, 30):
		if best.x >= 0 and best_cost <= r:
			break                         # weiter draußen kann es nicht mehr billiger werden (Kosten >= Abstand)
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue
				var o := center + Vector2i(dx, dz)
				var c := _site_cost(map, o, size)
				if c < 0.0:
					continue
				c += r * 1.0
				if c < best_cost:
					best_cost = c
					best = o
	return best


static func _site_cost(map: CityMap, o: Vector2i, size: int) -> float:
	var lo := 999
	var hi := -999
	var cost := 0.0
	for z in size:
		for x in size:
			var px := o.x + x
			var pz := o.y + z
			if not map.in_bounds(px, pz) or map.is_water(px, pz):
				return -1.0
			var i := map.idx(px, pz)
			if map.road[i] != 0 or map.rail[i] != 0 or map.special[i] != Config.Special.NONE:
				return -1.0
			var h := map.h(px, pz)
			lo = mini(lo, h)
			hi = maxi(hi, h)
			if map.zone[i] != Config.Zone.NONE and map.level[i] > 0:
				cost += 8.0 * map.level[i]      # Abriss nur, wenn es keine freie Fläche in der Nähe gibt
	if hi - lo > 1:
		return -1.0
	for k in size:      # Straßenanschluss an irgendeiner Seite
		if map.is_road(o.x + k, o.y - 1) or map.is_road(o.x + k, o.y + size) \
				or map.is_road(o.x - 1, o.y + k) or map.is_road(o.x + size, o.y + k):
			return cost
	return -1.0


## Sonderbau setzen (Gelände einebnen, Zone/Bäume weg). Gibt die Zahl abgerissener Gebäude-Tiles zurück.
static func place(map: CityMap, sp: int, o: Vector2i, slevel: int) -> int:
	var a := map.idx(o.x, o.y)
	var size: int = Config.SPECIALS[sp]["size"]
	var top := 0
	for z in size:
		for x in size:
			top = maxi(top, map.h(o.x + x, o.y + z))
	var gone := 0
	for z in size:
		for x in size:
			var i := map.idx(o.x + x, o.y + z)
			if map.zone[i] != Config.Zone.NONE and map.level[i] > 0:
				gone += 1
			map.height[i] = top
			map.zone[i] = Config.Zone.NONE
			map.level[i] = 0
			map.villa[i] = 0
			map.worn[i] = 0
			map.empty[i] = 0
			map.vacant[i] = 0
			map.hightech[i] = 0
			map.burning[i] = 0
			map.construct[i] = 0
			map.feature[i] = Config.Feature.NONE
			map.special[i] = sp
			map.anchor[i] = a
	map.slevel[a] = slevel
	return gone


## Mittelpunkt des Gebiets mit den meisten Gebäuden außerhalb jedes Lager-Kreises (Quadrat-Zählung per
## Integralbild, Seitenlänge ~ Lager-Kreis). (-1, -1) = alle Gebäude versorgt.
static func _worst_gap(map: CityMap, sim: Simulation) -> Vector2i:
	var n := map.size
	var sat := PackedInt32Array()
	sat.resize((n + 1) * (n + 1))
	var any := false
	for z in n:
		var row := 0
		for x in n:
			var i := z * n + x
			if map.zone[i] != Config.Zone.NONE and map.level[i] > 0 and sim.store_cover[i] == 0:
				row += 1
				any = true
			sat[(z + 1) * (n + 1) + x + 1] = sat[z * (n + 1) + x + 1] + row
	if not any:
		return Vector2i(-1, -1)
	var h := int(Config.STORE_RADIUS[3] * 0.7)
	var best := Vector2i(-1, -1)
	var best_n := 0
	for z in n:
		for x in n:
			var x0 := maxi(x - h, 0)
			var z0 := maxi(z - h, 0)
			var x1 := mini(x + h + 1, n)
			var z1 := mini(z + h + 1, n)
			var c := sat[z1 * (n + 1) + x1] - sat[z0 * (n + 1) + x1] - sat[z1 * (n + 1) + x0] + sat[z0 * (n + 1) + x0]
			if c > best_n:
				best_n = c
				best = Vector2i(x, z)
	return best


static func _centroid(map: CityMap) -> Vector2i:
	var sx := 0.0
	var sz := 0.0
	var w := 0.0
	for i in map.size * map.size:
		if map.zone[i] != Config.Zone.NONE and map.level[i] > 0:
			sx += i % map.size
			sz += i / map.size
			w += 1.0
	if w == 0.0:
		return Vector2i(map.size / 2, map.size / 2)
	return Vector2i(int(sx / w), int(sz / w))
