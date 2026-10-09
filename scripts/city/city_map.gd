class_name CityMap
extends RefCounted
## Reine Kartendaten. Kein Rendering, keine Simulation.

signal tiles_changed(rect: Rect2i)
signal infra_changed            # Straßen/Gleise/Haltestellen/Sonderbauten/Gelände geändert

var size: int
var height: PackedInt32Array
var zone: PackedByteArray
var road: PackedByteArray
var level: PackedByteArray      # Gebäudestufe 0..3 (nur auf Zonen)
var feature: PackedByteArray    # Config.Feature
var power_line: PackedByteArray
var special: PackedByteArray    # Config.Special
var anchor: PackedInt32Array    # Index des Ursprungs-Tiles eines Sonderbaus, -1 = keiner
var rail: PackedByteArray       # 1 = Gleis (darf Straße kreuzen)
var transit: PackedByteArray    # Config.Transit: Haltestelle (auf Straße) / Bahnhof (auf Gleis)
var slevel: PackedByteArray     # Ausbaustufe eines Sonderbaus (am Ursprungs-Tile), 0 = alt/1


func _init(map_size: int = Config.MAP_SIZE) -> void:
	size = map_size
	var n := size * size
	height.resize(n)
	zone.resize(n)
	road.resize(n)
	level.resize(n)
	feature.resize(n)
	power_line.resize(n)
	special.resize(n)
	anchor.resize(n)
	anchor.fill(-1)
	rail.resize(n)
	transit.resize(n)
	slevel.resize(n)


func idx(x: int, z: int) -> int:
	return z * size + x


func in_bounds(x: int, z: int) -> bool:
	return x >= 0 and z >= 0 and x < size and z < size


func h(x: int, z: int) -> int:
	return height[idx(x, z)] if in_bounds(x, z) else 0


func is_water(x: int, z: int) -> bool:
	return height[idx(x, z)] < Config.WATER_LEVEL


func is_road(x: int, z: int) -> bool:
	return in_bounds(x, z) and road[idx(x, z)] != 0


func has_building(x: int, z: int) -> bool:
	var i := idx(x, z)
	return zone[i] != Config.Zone.NONE and level[i] > 0


func is_special(x: int, z: int) -> bool:
	return in_bounds(x, z) and special[idx(x, z)] != Config.Special.NONE


func is_power_line(x: int, z: int) -> bool:
	return in_bounds(x, z) and power_line[idx(x, z)] == 1


## Gebäude oder Sonderbau steht drauf
func is_occupied(x: int, z: int) -> bool:
	return has_building(x, z) or special[idx(x, z)] != Config.Special.NONE


## Leitet Strom: Leitungen, Zonen (auch unbebaut), Sonderbauten
func conducts(i: int) -> bool:
	return power_line[i] == 1 or zone[i] != Config.Zone.NONE or special[i] != Config.Special.NONE


func is_rail(x: int, z: int) -> bool:
	return in_bounds(x, z) and rail[idx(x, z)] != 0


func rails_connected(x: int, z: int, nx: int, nz: int) -> bool:
	return is_rail(x, z) and is_rail(nx, nz) and absi(h(x, z) - h(nx, nz)) <= 1


## 4-spurige Hauptstraße: zwei parallele, benachbarte Straßenzüge.
## Rückgabe: Richtung zum Partner-Tile, ZERO = normale Straße. Vorberechnet je Kartenstand.
func wide_partner(x: int, z: int) -> Vector2i:
	if not in_bounds(x, z):
		return Vector2i.ZERO
	if _wide_dirty:
		_compute_wide()
	return WIDE_DIRS[_wide[idx(x, z)]]


## Kopie der Hauptstraßen-Zuordnung (für Vergleiche, z.B. Renderer).
func wide_snapshot() -> PackedByteArray:
	if _wide_dirty:
		_compute_wide()
	return _wide.duplicate()


const WIDE_DIRS := [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
var _wide := PackedByteArray()
var _wide_dirty := true


## Fahrtrichtung = Achse, entlang der die Straße länger durchläuft; gepaart wird quer dazu,
## von der Kante des Bandes aus zu zweit (Band mit 4 Reihen = 2 Hauptstraßen).
## Kreuzende Straßen bleiben normal (Partner muss dieselbe Fahrtrichtung haben).
func _compute_wide() -> void:
	_wide_dirty = false
	var n := size * size
	_wide.resize(n)
	_wide.fill(0)
	var len_x := PackedInt32Array()
	var off_x := PackedInt32Array()
	var len_z := PackedInt32Array()
	var off_z := PackedInt32Array()
	for a: PackedInt32Array in [len_x, off_x, len_z, off_z]:
		a.resize(n)
	# Läufe (zusammenhängende Straßenstücke) je Zeile und Spalte
	for z in size:
		var x := 0
		while x < size:
			if not is_road(x, z):
				x += 1
				continue
			var start := x
			while roads_connected(x, z, x + 1, z):
				x += 1
			for k in range(start, x + 1):
				len_x[idx(k, z)] = x - start + 1
				off_x[idx(k, z)] = k - start
			x += 1
	for x in size:
		var z := 0
		while z < size:
			if not is_road(x, z):
				z += 1
				continue
			var start := z
			while roads_connected(x, z, x, z + 1):
				z += 1
			for k in range(start, z + 1):
				len_z[idx(x, k)] = z - start + 1
				off_z[idx(x, k)] = k - start
			z += 1
	for z in size:
		for x in size:
			var i := idx(x, z)
			if road[i] == 0:
				continue
			var travel_x := len_x[i] >= 2 and len_x[i] >= len_z[i]
			var travel_z := len_z[i] >= 2 and len_z[i] > len_x[i]
			if travel_x and len_z[i] >= 2:
				var dz := 1 if off_z[i] % 2 == 0 else -1
				if off_z[i] + dz < len_z[i]:
					var j := idx(x, z + dz)
					if len_x[j] >= 2 and len_x[j] >= len_z[j]:
						_wide[i] = 3 if dz == 1 else 4
			elif travel_z and len_x[i] >= 2:
				var dx := 1 if off_x[i] % 2 == 0 else -1
				if off_x[i] + dx < len_x[i]:
					var j := idx(x + dx, z)
					if len_z[j] >= 2 and len_z[j] > len_x[j]:
						_wide[i] = 1 if dx == 1 else 2


## Ausbaustufe 1..3 des Sonderbaus, zu dem Tile i gehört.
func special_level(i: int) -> int:
	var a := anchor[i]
	return clampi(slevel[a], 1, 3) if a >= 0 else 0


## Straßen verbinden sich nur bei max. 1 Block Höhenunterschied.
func roads_connected(x: int, z: int, nx: int, nz: int) -> bool:
	return is_road(x, z) and is_road(nx, nz) and absi(h(x, z) - h(nx, nz)) <= 1


## infra = false: nur Gebäudestufen geändert (Wachstum) -> Netz-Abhängige müssen nichts tun.
func notify_changed(rect: Rect2i, infra := true) -> void:
	if infra:
		_wide_dirty = true
		infra_changed.emit()
	tiles_changed.emit(rect)


const SAVE_FIELDS := ["height", "zone", "road", "level", "feature", "power_line", "special", "anchor", "rail", "transit", "slevel"]


func to_dict() -> Dictionary:
	var d := {"size": size}
	for f: String in SAVE_FIELDS:
		d[f] = get(f)
	return d


## Überschreibt die Daten in-place (Referenzen auf diese Map bleiben gültig).
func from_dict(d: Dictionary) -> bool:
	if d.get("size", -1) != size:
		return false
	for f: String in SAVE_FIELDS:
		if d.has(f):
			set(f, d[f])
		else:
			# Ältere Spielstände: neues Feld leeren
			var a: Variant = get(f)
			a.fill(-1 if f == "anchor" else 0)
			set(f, a)
	# Alte Spielstände: früherer Typ "Hauptstraße" (2) -> normale Straße
	for i in road.size():
		if road[i] > 1:
			road[i] = 1
	notify_changed(Rect2i(0, 0, size, size))
	return true


func generate(seed_value: int) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.03
	noise.fractal_octaves = 4

	var tree_noise := FastNoiseLite.new()
	tree_noise.seed = seed_value + 1337
	tree_noise.frequency = 0.08

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	for z in size:
		for x in size:
			var i := idx(x, z)
			var n := noise.get_noise_2d(x, z)
			# Mitte etwas anheben, damit Wasser eher am Rand liegt
			var center := Vector2(x, z).distance_to(Vector2(size, size) * 0.5) / (size * 0.5)
			var v := 5.5 + n * 10.0 - center * 2.0
			height[i] = clampi(roundi(v), 1, Config.MAX_HEIGHT)
			zone[i] = Config.Zone.NONE
			road[i] = 0
			level[i] = 0
			feature[i] = Config.Feature.NONE
			power_line[i] = 0
			special[i] = Config.Special.NONE
			anchor[i] = -1
			rail[i] = 0
			transit[i] = 0
			slevel[i] = 0
			if not is_water(x, z) and tree_noise.get_noise_2d(x, z) > 0.25 and rng.randf() < 0.6:
				feature[i] = Config.Feature.TREE

	notify_changed(Rect2i(0, 0, size, size))
