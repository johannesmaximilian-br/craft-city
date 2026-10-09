class_name Traffic
extends MultiMeshInstance3D
## Rein visueller Verkehr: Autos fahren zufällig über das Straßennetz (Rechtsverkehr).
## Anzahl skaliert mit der Bevölkerung. 1 Block Höhenunterschied wird als Rampe gefahren.

const B := Config.TILE_BLOCKS
const SPEED := 3.6              # Welteinheiten pro Sekunde
const LANE := 0.62              # Abstand Fahrspur zur Straßenmitte
const SIM_SPEED_FACTOR := [0.0, 1.0, 1.4, 1.8]
const COLORS := [Color("e0503c"), Color("4a90e2"), Color("ffcc33"), Color("f4f2ec"),
	Color("7cc242"), Color("e89a2c"), Color("8e6bbf"), Color("3b3f48")]

var map: CityMap
var sim: Simulation
var _road_tiles: Array[Vector2i] = []
var _spawn_cdf := PackedFloat32Array()     # kumulierte Spawn-Gewichte (nach Pendlern)
var _cars: Array[Car] = []
var _buses: Array[Car] = []
var _bus_mmi: MultiMeshInstance3D
var _stop_tiles: Array[Vector2i] = []
var _rng := RandomNumberGenerator.new()

const BUS_COLOR := Color("ffc21a")
const BUS_RIDERS_PER_BUS := 40.0
const MAX_BUSES := 40


class Car:
	var from: Vector2i
	var to: Vector2i
	var t := 0.0
	var pos := Vector3.ZERO
	var yaw := 0.0
	var color: Color
	var lane := 0           # Hauptstraße: 0 = innere (Mittellinie), 1 = äußere Spur
	var fresh := true
	var is_bus := false


func setup(city_map: CityMap, simulation: Simulation, lib: BlockLibrary) -> void:
	map = city_map
	sim = simulation
	_rng.randomize()
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = lib.car_mesh()
	_bus_mmi = MultiMeshInstance3D.new()
	_bus_mmi.name = "Buses"
	_bus_mmi.multimesh = MultiMesh.new()
	_bus_mmi.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_bus_mmi.multimesh.use_colors = true
	_bus_mmi.multimesh.mesh = lib.bus_mesh()
	add_child(_bus_mmi)
	map.infra_changed.connect(_on_map_changed.bind(Rect2i()))
	sim.traffic_changed.connect(_rebuild_weights)
	_on_map_changed(Rect2i())


func _on_map_changed(_rect: Rect2i) -> void:
	_road_tiles.clear()
	_stop_tiles.clear()
	for z in map.size:
		for x in map.size:
			var p := Vector2i(x, z)
			if map.is_road(x, z) and not _neighbors(p).is_empty():
				_road_tiles.append(p)
				if map.transit[map.idx(x, z)] == Config.Transit.BUS_STOP:
					_stop_tiles.append(p)
	_rebuild_weights()
	# Fahrzeuge auf entfernten Straßen neu setzen
	for car in _cars + _buses:
		if not map.roads_connected(car.from.x, car.from.y, car.to.x, car.to.y):
			_spawn(car)


## Viel befahrene Straßen bekommen mehr Autos.
func _rebuild_weights() -> void:
	_spawn_cdf.resize(_road_tiles.size())
	var acc := 0.0
	for k in _road_tiles.size():
		acc += 1.0 + _traffic_at(_road_tiles[k])
		_spawn_cdf[k] = acc


func _traffic_at(p: Vector2i) -> float:
	var i := map.idx(p.x, p.y)
	return sim.traffic[i] if sim.traffic.size() > i else 0.0


func _congestion_at(p: Vector2i) -> float:
	var i := map.idx(p.x, p.y)
	return sim.congestion[i] if sim.congestion.size() > i else 0.0


func target_count() -> int:
	var by_pop := sim.population / Config.CARS_PER_POP
	var by_road := int(_road_tiles.size() * Config.MAX_CARS_PER_ROAD_TILE)
	return mini(mini(by_pop, by_road), Config.MAX_CARS)


func _neighbors(p: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d: Vector2i in Simulation.DIRS:
		if map.roads_connected(p.x, p.y, p.x + d.x, p.y + d.y):
			out.append(p + d)
	return out


func target_buses() -> int:
	# Linienbetrieb ab 2 Haltestellen, Fahrgäste verdichten den Takt
	if _stop_tiles.size() < 2:
		return 0
	return mini(maxi(1, _stop_tiles.size() / 2) + int(sim.bus_riders / BUS_RIDERS_PER_BUS), MAX_BUSES)


func _spawn(car: Car) -> void:
	if _road_tiles.is_empty():
		return
	if car.is_bus and not _stop_tiles.is_empty():
		car.from = _stop_tiles[_rng.randi() % _stop_tiles.size()]
	else:
		var k := _spawn_cdf.bsearch(_rng.randf() * _spawn_cdf[_spawn_cdf.size() - 1])
		car.from = _road_tiles[mini(k, _road_tiles.size() - 1)]
	var nb := _neighbors(car.from)
	car.to = nb[_rng.randi() % nb.size()]
	car.t = _rng.randf()
	car.fresh = true


func _next(car: Car) -> Vector2i:
	var opts := _neighbors(car.to)
	if opts.size() > 1:
		opts.erase(car.from)    # kein Wenden, außer Sackgasse
	# Hauptstraße: nicht quer auf die Partner-Spur wechseln, solange es weitergeht
	var partner := map.wide_partner(car.to.x, car.to.y)
	if partner != Vector2i.ZERO and opts.size() > 1:
		opts.erase(car.to + partner)
	if opts.is_empty():
		return car.from
	# Gewichtet nach Pendleraufkommen, geradeaus leicht bevorzugt
	var straight := car.to + (car.to - car.from)
	var weights: Array[float] = []
	var total := 0.0
	for o in opts:
		var w := 1.0 + _traffic_at(o) * 0.2
		if o == straight:
			w *= 1.5
		# Busse bleiben im Haltestellen-Einzugsbereich
		if car.is_bus and sim.bus_served.size() > 0 and sim.bus_served[map.idx(o.x, o.y)] == 1:
			w *= 6.0
		weights.append(w)
		total += w
	var r := _rng.randf() * total
	for k in opts.size():
		r -= weights[k]
		if r <= 0.0:
			return opts[k]
	return opts[opts.size() - 1]


func _process(delta: float) -> void:
	# Anzahl schrittweise anpassen
	var want := target_count() if not _road_tiles.is_empty() else 0
	_adjust(_cars, want, false)
	_adjust(_buses, target_buses(), true)

	var step: float = SPEED * SIM_SPEED_FACTOR[sim.speed] * delta / B
	_move_all(_cars, multimesh, step, delta)
	_move_all(_buses, _bus_mmi.multimesh, step * 0.85, delta)


func _adjust(list: Array[Car], want: int, bus: bool) -> void:
	for k in mini(4, absi(want - list.size())):
		if list.size() < want:
			var car := Car.new()
			car.is_bus = bus
			car.lane = 1 if bus else _rng.randi() % 2     # Busse rechts außen
			car.color = BUS_COLOR if bus else COLORS[_rng.randi() % COLORS.size()]
			_spawn(car)
			list.append(car)
		else:
			list.pop_back()


func _move_all(list: Array[Car], mm: MultiMesh, step: float, delta: float) -> void:
	mm.instance_count = list.size()
	for k in list.size():
		var car := list[k]
		# Stau bremst: bei Auslastung >1 deutlich langsamer
		var cong := maxf(_congestion_at(car.from), _congestion_at(car.to))
		var road_speed := Config.WIDE_SPEED if map.wide_partner(car.from.x, car.from.y) != Vector2i.ZERO else Config.STREET_SPEED
		car.t += step * road_speed * clampf(1.15 - cong * 0.6, 0.15, 1.0)
		while car.t >= 1.0:
			car.t -= 1.0
			var nxt := _next(car)
			car.from = car.to
			car.to = nxt
		var target := _lane_pos(car)
		var d := Vector2(car.to - car.from)
		var yaw := atan2(-d.y, d.x)
		if car.fresh:
			car.pos = target
			car.yaw = yaw
			car.fresh = false
		else:
			# Glätten kaschiert Spurwechsel in Kurven
			car.pos = car.pos.lerp(target, minf(1.0, delta * 12.0))
			car.yaw = lerp_angle(car.yaw, yaw, minf(1.0, delta * 10.0))
		mm.set_instance_transform(k, Transform3D(Basis(Vector3.UP, car.yaw), car.pos))
		mm.set_instance_color(k, car.color)


func _lane_pos(car: Car) -> Vector3:
	var a := Vector2(car.from) * B + Vector2.ONE * (B * 0.5)
	var b := Vector2(car.to) * B + Vector2.ONE * (B * 0.5)
	var dir := Vector2(car.to - car.from)
	var right := Vector2(-dir.y, dir.x)
	var p := a.lerp(b, car.t) + right * LANE
	# Hauptstraße: Richtung bestimmt die Hälfte des Paars (Rechtsverkehr),
	# egal auf welchem der beiden Tiles die Route gerade verläuft
	# Nur innerhalb des Paars; beim Ein-/Ausfädeln (Verjüngung) normale Spur über die Tile-Mitte
	var on := car.from if car.t < 0.5 else car.to
	var partner := map.wide_partner(on.x, on.y)
	var both_wide := map.wide_partner(car.from.x, car.from.y) != Vector2i.ZERO \
		and map.wide_partner(car.to.x, car.to.y) != Vector2i.ZERO
	if both_wide and absi(partner.x) != absi(dir.x as int):
		var lateral := absi(partner.y) == 1     # Paar liegt quer zur z-Achse -> Fahrt entlang x
		var seam: float
		if lateral:
			seam = (on.y + (1 if partner.y == 1 else 0)) * B
			p.y = seam + right.y * (0.75 if car.lane == 0 else 2.25)
		else:
			seam = (on.x + (1 if partner.x == 1 else 0)) * B
			p.x = seam + right.x * (0.75 if car.lane == 0 else 2.25)
	var ha := float(map.h(car.from.x, car.from.y))
	var hb := float(map.h(car.to.x, car.to.y))
	# Rampe über die Tile-Kante
	var y := lerpf(ha, hb, smoothstep(0.35, 0.65, car.t))
	return Vector3(p.x, y, p.y)
