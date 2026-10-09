class_name Trains
extends MultiMeshInstance3D
## Rein visuelle Züge: fahren über das Gleisnetz, sobald es mindestens 2 Bahnhöfe gibt.
## Die Lok fährt Tile für Tile (wie Autos), die Waggons folgen ihrer Spur in festem Abstand.

const B := Config.TILE_BLOCKS
const SPEED := 7.0              # Welteinheiten pro Sekunde
const WAGONS := 3               # inkl. Lok
const GAP := 2.7                # Abstand der Waggons entlang der Spur
const SIM_SPEED_FACTOR := [0.0, 1.0, 1.4, 1.8]
const LOCO_COLOR := Color("c0392b")
const WAGON_COLOR := Color("f2e6c9")

var map: CityMap
var sim: Simulation
var _rail_tiles: Array[Vector2i] = []
var _station_tiles: Array[Vector2i] = []
var _trains: Array[Train] = []
var _rng := RandomNumberGenerator.new()


class Train:
	var from: Vector2i
	var to: Vector2i
	var t := 0.0
	var trail: Array[Vector3] = []   # zurückgelegte Kopf-Positionen (neueste zuerst)


func setup(city_map: CityMap, simulation: Simulation, lib: BlockLibrary) -> void:
	map = city_map
	sim = simulation
	_rng.randomize()
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = lib.wagon_mesh()
	map.infra_changed.connect(_on_map_changed.bind(Rect2i()))
	_on_map_changed(Rect2i())


func _on_map_changed(_rect: Rect2i) -> void:
	_rail_tiles.clear()
	_station_tiles.clear()
	for z in map.size:
		for x in map.size:
			var p := Vector2i(x, z)
			if map.is_rail(x, z) and not _neighbors(p).is_empty():
				_rail_tiles.append(p)
				if map.transit[map.idx(x, z)] == Config.Transit.STATION:
					_station_tiles.append(p)
	# Neue Karte/geladener Stand ohne Bahnhöfe: Züge entfernen
	if _station_tiles.size() < 2:
		_trains.clear()
		return
	for tr in _trains:
		if not map.rails_connected(tr.from.x, tr.from.y, tr.to.x, tr.to.y):
			_spawn(tr)


func target_count() -> int:
	if _station_tiles.size() < 2:
		return 0
	return mini(_station_tiles.size() - 1 + int(sim.rail_riders / 400.0), 8)


func _neighbors(p: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d: Vector2i in Simulation.DIRS:
		if map.rails_connected(p.x, p.y, p.x + d.x, p.y + d.y):
			out.append(p + d)
	return out


func _spawn(tr: Train) -> void:
	tr.from = _station_tiles[_rng.randi() % _station_tiles.size()]
	var nb := _neighbors(tr.from)
	tr.to = nb[_rng.randi() % nb.size()]
	tr.t = 0.0
	tr.trail.clear()


func _next(tr: Train) -> Vector2i:
	var opts := _neighbors(tr.to)
	if opts.size() > 1:
		opts.erase(tr.from)
	if opts.is_empty():
		return tr.from      # Endstation: zurückfahren
	var straight := tr.to + (tr.to - tr.from)
	if straight in opts and _rng.randf() < 0.7:
		return straight
	return opts[_rng.randi() % opts.size()]


func _process(delta: float) -> void:
	var want := target_count()
	while _trains.size() < want:
		var tr := Train.new()
		_spawn(tr)
		_trains.append(tr)
	while _trains.size() > want:
		_trains.pop_back()

	var step: float = SPEED * SIM_SPEED_FACTOR[sim.speed] * delta / B
	multimesh.instance_count = _trains.size() * WAGONS
	for k in _trains.size():
		var tr := _trains[k]
		tr.t += step
		while tr.t >= 1.0:
			tr.t -= 1.0
			var nxt := _next(tr)
			tr.from = tr.to
			tr.to = nxt
		var head := _track_pos(tr)
		if tr.trail.is_empty() or tr.trail[0].distance_to(head) > 0.05:
			tr.trail.push_front(head)
			if tr.trail.size() > 200:
				tr.trail.pop_back()
		for w in WAGONS:
			var pos_dir := _along_trail(tr.trail, w * GAP)
			var dir: Vector3 = pos_dir[1]
			var yaw := atan2(-dir.z, dir.x)
			multimesh.set_instance_transform(k * WAGONS + w, Transform3D(Basis(Vector3.UP, yaw), pos_dir[0]))
			multimesh.set_instance_color(k * WAGONS + w, LOCO_COLOR if w == 0 else WAGON_COLOR)


## Position + Fahrtrichtung in Abstand dist hinter dem Kopf.
func _along_trail(trail: Array[Vector3], dist: float) -> Array:
	var acc := 0.0
	for i in range(trail.size() - 1):
		var seg := trail[i].distance_to(trail[i + 1])
		if acc + seg >= dist and seg > 0.0:
			var p := trail[i].lerp(trail[i + 1], (dist - acc) / seg)
			return [p, trail[i] - trail[i + 1]]
		acc += seg
	var last := trail[trail.size() - 1]
	var d := trail[0] - last if trail.size() > 1 else Vector3.RIGHT
	return [last, d if d.length() > 0.001 else Vector3.RIGHT]


func _track_pos(tr: Train) -> Vector3:
	var a := Vector2(tr.from) * B + Vector2.ONE * (B * 0.5)
	var b := Vector2(tr.to) * B + Vector2.ONE * (B * 0.5)
	var p := a.lerp(b, tr.t)
	var ha := float(map.h(tr.from.x, tr.from.y))
	var hb := float(map.h(tr.to.x, tr.to.y))
	return Vector3(p.x, lerpf(ha, hb, smoothstep(0.35, 0.65, tr.t)) + 0.15, p.y)
