class_name FireDept
extends Node
## Brandverlauf in Echtzeit (skaliert mit dem Spieltempo, steht bei Pause):
## Ausbruch würfelt Simulation._fires() monatlich und setzt map.burning = 1.
## Hier: Fortschritt bis zum Abbrennen, Löschzüge von der Wache über Straßen,
## Löschen vor Ort, Ausbreitung auf Nachbarn (nur ohne Brandschutz), Meldungen mit Ort.
## Fahrzeuge/Flammen zeichnet FireFx (liest nur).

signal alert(text: String, tile: Vector2i)

const TIME_SCALE := [0.0, 1.0, 1.4, 1.8]     # wie Traffic.SIM_SPEED_FACTOR
const RETRY := 1.0                            # Sekunden bis zur nächsten Alarmierung ohne freien Zug
const MAX_PATH_FACTOR := 3                    # Fahrweg max. Reichweite x 3 Tiles

enum Status { WAITING, NO_STATION, BUSY, NO_ROAD, EN_ROUTE, FIGHTING }
const STATUS_TEXT := ["wird alarmiert", "keine Feuerwache in Reichweite", "alle Löschzüge im Einsatz",
	"keine Zufahrt", "Löschzug unterwegs", "wird gelöscht"]

enum Stage { OUT, WORK, BACK }


class Fire:
	var tile := 0
	var progress := 0.0         # 0..1, bei 1 abgebrannt
	var spread_done := false
	var retry := 0.0
	var status := Status.WAITING
	var truck: Truck = null


class Truck:
	var station := -1           # Anchor der Wache
	var path := PackedInt32Array()   # Straßen-Tiles, Wache -> Brand
	var t := 0.0                # Position entlang path in Tiles
	var stage := Stage.OUT
	var work := 0.0             # Löschfortschritt 0..1
	var fire: Fire = null


var map: CityMap
var sim: Simulation
var fires := {}                 # Tile -> Fire
var trucks: Array[Truck] = []
var burned_total := 0
var extinguished_total := 0
var _stations := {}             # Anchor -> PackedInt32Array Zufahrts-Straßen-Tiles
var _rng := RandomNumberGenerator.new()
var _parent := PackedInt32Array()


func setup(city_map: CityMap, simulation: Simulation) -> void:
	map = city_map
	sim = simulation
	_rng.randomize()
	map.infra_changed.connect(_collect_stations)
	map.tiles_changed.connect(_sync)
	_collect_stations()
	_sync(Rect2i(0, 0, map.size, map.size))


func _process(delta: float) -> void:
	advance(delta * TIME_SCALE[sim.speed])


## Brennende Tiles (für Kamera-Sprung), sortiert nach Index.
func burning_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var keys := fires.keys()
	keys.sort()
	for i: int in keys:
		out.append(Vector2i(i % map.size, i / map.size))
	return out


func status_text(i: int) -> String:
	var f: Fire = fires.get(i)
	return STATUS_TEXT[f.status] if f != null else ""


## Brandschutz-Erklärung für die Info-Karte (leer = voll geschützt).
func protection_note(i: int) -> String:
	var cov := _cov(i)
	if cov <= 0.0:
		return "keine Feuerwache in Reichweite"
	var x := i % map.size
	var z := i / map.size
	for a: int in _stations:
		if _in_range(a, x, z) and float(sim.service_load.get(a, 0.0)) > 1.0:
			return "Feuerwache überlastet"
	return "Rand der Reichweite" if cov < 0.8 else ""


# ---------------------------------------------------------------- Ablauf

func advance(dt: float) -> void:
	if dt <= 0.0:
		return
	for f: Fire in fires.values():
		_advance_fire(f, dt)
	for k in range(trucks.size() - 1, -1, -1):
		_advance_truck(trucks[k], dt)


func _advance_fire(f: Fire, dt: float) -> void:
	if f.truck != null and f.truck.stage == Stage.WORK:
		return      # Löschzug vor Ort: Feuer wächst nicht weiter
	if f.truck == null:
		f.retry -= dt
		if f.retry <= 0.0:
			f.retry = RETRY
			_dispatch(f)
	f.progress += dt / Config.FIRE_BURN_TIME
	map.burning[f.tile] = clampi(ceili(f.progress * 100.0), 1, 100)
	if f.progress >= 0.5 and not f.spread_done:
		f.spread_done = true
		_spread(f.tile)
	if f.progress >= 1.0:
		_burn_down(f)


func _advance_truck(tr: Truck, dt: float) -> void:
	match tr.stage:
		Stage.OUT, Stage.BACK:
			var before := int(tr.t)
			tr.t += dt * Config.FIRE_TRUCK_SPEED
			# Straße unterwegs abgerissen -> Zug fällt aus (Brand wird neu alarmiert)
			for k in range(before + 1, mini(int(tr.t), tr.path.size() - 1) + 1):
				if map.road[tr.path[k]] == 0:
					_remove_truck(tr)
					return
			if tr.t >= tr.path.size() - 1:
				tr.t = tr.path.size() - 1
				if tr.stage == Stage.BACK:
					_remove_truck(tr)
				else:
					tr.stage = Stage.WORK
					tr.fire.status = Status.FIGHTING
		Stage.WORK:
			tr.work += dt / Config.FIRE_EXTINGUISH_TIME
			if tr.work >= 1.0:
				_extinguish(tr.fire)


func _extinguish(f: Fire) -> void:
	var i := f.tile
	var damaged := f.progress >= Config.FIRE_DAMAGE_AT and map.level[i] > 1
	if damaged:
		map.level[i] -= 1
	_end_fire(f)
	extinguished_total += 1
	if damaged:
		map.notify_changed(Rect2i(i % map.size, i / map.size, 1, 1), false)
	# Gelöschte Brände ohne Meldung (Routine); sichtbar bleiben sie über die Brand-Anzeige/Info-Karte


func _burn_down(f: Fire) -> void:
	var i := f.tile
	var why: String = STATUS_TEXT[f.status] if f.status != Status.EN_ROUTE else "Löschzug zu spät"
	_end_fire(f)
	map.level[i] = 0
	map.ruin[i] = Config.FIRE_RUIN_MONTHS
	burned_total += 1
	map.notify_changed(Rect2i(i % map.size, i / map.size, 1, 1), false)
	alert.emit("Abgebrannt: %s - %s" % [_where(i), why], _tile(i))


## Feuer aus der Liste nehmen, Löschzug fährt zurück.
func _end_fire(f: Fire) -> void:
	fires.erase(f.tile)
	map.burning[f.tile] = 0
	var tr := f.truck
	if tr != null:
		tr.fire = null
		f.truck = null
		_send_back(tr)


func _send_back(tr: Truck) -> void:
	var p := tr.path.slice(0, int(tr.t) + 1)
	p.reverse()
	tr.path = p
	tr.t = 0.0
	tr.stage = Stage.BACK
	if p.size() < 2:
		_remove_truck(tr)


func _remove_truck(tr: Truck) -> void:
	trucks.erase(tr)
	if tr.fire != null:
		tr.fire.truck = null
		tr.fire.status = Status.WAITING
		tr.fire.retry = 0.0
		tr.fire = null


## Funkenflug: Nachbarn fangen Feuer, je weniger Brandschutz desto eher.
func _spread(i: int) -> void:
	var x := i % map.size
	var z := i / map.size
	var started: Array[int] = []
	for d: Vector2i in Simulation.DIRS:
		if not map.in_bounds(x + d.x, z + d.y):
			continue
		var j := map.idx(x + d.x, z + d.y)
		if map.level[j] == 0 or map.zone[j] == Config.Zone.NONE or map.burning[j] > 0:
			continue
		var u := 1.0 - minf(_cov(j), 1.0)
		if _rng.randf() < Config.FIRE_SPREAD * u * u:
			map.burning[j] = 1
			started.append(j)
	for j in started:
		_start(j, true)


# ---------------------------------------------------------------- Kartenabgleich

## Neue Brände übernehmen (Simulation, Laden), weggefallene beenden (Abriss).
func _sync(rect: Rect2i) -> void:
	var r := rect.intersection(Rect2i(0, 0, map.size, map.size))
	if r.size == Vector2i(map.size, map.size):
		# Laden / neue Stadt: Einsätze der alten Karte verwerfen
		trucks.clear()
		for f: Fire in fires.values():
			f.truck = null
		fires.clear()
	for z in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var i := z * map.size + x
			var has := fires.has(i)
			var valid := map.level[i] > 0 and map.zone[i] != Config.Zone.NONE
			if map.burning[i] > 0 and not has:
				if valid:
					_start(i, false)
				else:
					map.burning[i] = 0
			elif has and (map.burning[i] == 0 or not valid):
				_end_fire(fires[i])


func _start(i: int, spread: bool) -> void:
	var f := Fire.new()
	f.tile = i
	f.progress = (map.burning[i] - 1) / 100.0
	f.spread_done = f.progress >= 0.5
	fires[i] = f
	_dispatch(f)
	f.retry = RETRY
	# Nur melden, wenn die Feuerwehr nicht einfach ausrücken kann oder das Feuer übergreift
	if spread or f.status != Status.EN_ROUTE:
		alert.emit("Feuer%s! %s - %s" % [" greift über" if spread else "", _where(i), STATUS_TEXT[f.status]], _tile(i))


# ---------------------------------------------------------------- Alarmierung

func _collect_stations() -> void:
	_stations.clear()
	for a in map.size * map.size:
		if map.anchor[a] != a or map.special[a] != Config.Special.FIRE:
			continue
		var s: int = Config.SPECIALS[Config.Special.FIRE]["size"]
		var access := PackedInt32Array()
		var ax := a % map.size
		var az := a / map.size
		for z in range(az - 1, az + s + 1):
			for x in range(ax - 1, ax + s + 1):
				var edge := (x == ax - 1 or x == ax + s) != (z == az - 1 or z == az + s)   # ohne Ecken
				if edge and map.is_road(x, z):
					access.append(map.idx(x, z))
		_stations[a] = access


func _in_range(a: int, x: int, z: int) -> bool:
	var half := (int(Config.SPECIALS[Config.Special.FIRE]["size"]) - 1) * 0.5
	var r: int = Config.SERVICE_RADIUS[map.special_level(a)]
	return Vector2(x - (a % map.size) - half, z - (a / map.size) - half).length() <= r


func _free_trucks(a: int) -> int:
	var busy := 0
	for tr in trucks:
		if tr.station == a:
			busy += 1
	return map.special_level(a) - busy


## Nächste Wache mit freiem Löschzug per Breitensuche vom Brand aus über Straßen.
func _dispatch(f: Fire) -> void:
	var x := f.tile % map.size
	var z := f.tile / map.size
	var free := {}      # Zufahrts-Tile -> Wache
	var max_r := 0
	var any := false
	for a: int in _stations:
		if not _in_range(a, x, z):
			continue
		any = true
		if _free_trucks(a) <= 0:
			continue
		max_r = maxi(max_r, Config.SERVICE_RADIUS[map.special_level(a)])
		for t in (_stations[a] as PackedInt32Array):
			free[t] = a
	if not any:
		f.status = Status.NO_STATION
		return
	if free.is_empty():
		f.status = Status.BUSY
		return
	var src := sim._src(f.tile)
	if src < 0:
		f.status = Status.NO_ROAD
		return
	var n := map.size * map.size
	if _parent.size() != n:
		_parent.resize(n)
	_parent.fill(-2)
	_parent[src] = -1
	var queue := PackedInt32Array([src])
	var depth := PackedInt32Array([0])
	var head := 0
	var found := -1
	while head < queue.size():
		var u := queue[head]
		var du := depth[head]
		head += 1
		if free.has(u):
			found = u
			break
		if du >= max_r * MAX_PATH_FACTOR:
			continue
		var ux := u % map.size
		var uz := u / map.size
		for d: Vector2i in Simulation.DIRS:
			if not map.roads_connected(ux, uz, ux + d.x, uz + d.y):
				continue
			var v := map.idx(ux + d.x, uz + d.y)
			if _parent[v] != -2:
				continue
			_parent[v] = u
			queue.append(v)
			depth.append(du + 1)
	if found < 0:
		f.status = Status.NO_ROAD
		return
	var tr := Truck.new()
	tr.station = free[found]
	tr.fire = f
	var p := PackedInt32Array()
	var c := found
	while c != -1:
		p.append(c)
		c = _parent[c]
	if p.size() == 1:
		p.append(p[0])      # Wache direkt an der Brandstraße
	tr.path = p
	trucks.append(tr)
	f.truck = tr
	f.status = Status.EN_ROUTE


# ---------------------------------------------------------------- Hilfen

func _cov(i: int) -> float:
	var c: PackedFloat32Array = sim.coverage.get("fire", PackedFloat32Array())
	return c[i] if c.size() > i else 0.0


func _tile(i: int) -> Vector2i:
	return Vector2i(i % map.size, i / map.size)


func _where(i: int) -> String:
	var kind: String = ["Gebäude", "Wohnhaus", "Gewerbe", "Industrie"][map.zone[i]]
	return "%s bei %d,%d" % [kind, i % map.size, i / map.size]
