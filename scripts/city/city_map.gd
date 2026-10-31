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
var burning: PackedByteArray    # Brand: 0 = nein, 1..100 = Fortschritt in % (100 = abgebrannt)
var ruin: PackedByteArray       # Brandruine: Monate bis das Tile wieder bebaut werden kann
var villa: PackedByteArray      # 1 = Wohnen Stufe 3 ist eine Villa (statt Wohnblock)
var worn: PackedByteArray       # 1 = Gebäude verfällt (sinkt bald ab) -> abgenutzte Optik
var empty: PackedByteArray      # Leerstand 0..100 % (0 = voll belegt; Default -> alte Saves/Tests voll); 100 = aufgegeben
var vacant: PackedByteArray     # Monate im Leerstand (nach VACANT_MONTHS abgerissen)
var ore: PackedByteArray        # Bodenvorkommen (Config.Ore)
var ore_amt: PackedByteArray    # Restmenge des Vorkommens (0 = erschöpft)


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
	burning.resize(n)
	ruin.resize(n)
	villa.resize(n)
	worn.resize(n)
	empty.resize(n)
	vacant.resize(n)
	ore.resize(n)
	ore_amt.resize(n)


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


## Einwohner eines Wohn-Tiles (Villa: wenige, sonst je Stufe).
func res_capacity(i: int) -> int:
	return Config.VILLA_POP if villa[i] == 1 and level[i] == 3 else Config.RES_CAPACITY[level[i]]


## Tatsächliche Einwohner (Kapazität × Belegung).
func residents(i: int) -> float:
	return res_capacity(i) * (100 - empty[i]) * 0.01


## Belegung in % (100 - Leerstand).
func occupancy(i: int) -> int:
	return 100 - empty[i]


## Tatsächliche Arbeitsplätze eines Gewerbe-/Industrie-Tiles (Kapazität × Belegung).
func jobs_at(i: int) -> float:
	match zone[i]:
		Config.Zone.COM: return Config.COM_CAPACITY[level[i]] * (100 - empty[i]) * 0.01
		Config.Zone.IND: return Config.IND_CAPACITY[level[i]] * (100 - empty[i]) * 0.01
	return 0.0


## Aufgegeben: Gebäude steht, aber niemand wohnt/arbeitet mehr darin.
func is_vacant(i: int) -> bool:
	return level[i] > 0 and empty[i] >= 100 and zone[i] != Config.Zone.NONE


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
	var wide := PackedByteArray()
	wide.resize(n)
	var len_x := PackedInt32Array()
	len_x.resize(n)
	var off_x := PackedInt32Array()
	off_x.resize(n)
	var len_z := PackedInt32Array()
	len_z.resize(n)
	var off_z := PackedInt32Array()
	off_z.resize(n)
	var rd := road
	var hg := height
	# Läufe (zusammenhängende Straßenstücke) je Zeile und Spalte; verbunden = beide Straße, max. 1 Block Höhe
	for z in size:
		var row := z * size
		var x := 0
		while x < size:
			if rd[row + x] == 0:
				x += 1
				continue
			var start := x
			while x + 1 < size and rd[row + x + 1] != 0 and absi(hg[row + x + 1] - hg[row + x]) <= 1:
				x += 1
			for k in range(start, x + 1):
				len_x[row + k] = x - start + 1
				off_x[row + k] = k - start
			x += 1
	for x in size:
		var z := 0
		while z < size:
			if rd[z * size + x] == 0:
				z += 1
				continue
			var start := z
			while z + 1 < size and rd[(z + 1) * size + x] != 0 and absi(hg[(z + 1) * size + x] - hg[z * size + x]) <= 1:
				z += 1
			for k in range(start, z + 1):
				len_z[k * size + x] = z - start + 1
				off_z[k * size + x] = k - start
			z += 1
	for i in n:
		if rd[i] == 0:
			continue
		var lx := len_x[i]
		var lz := len_z[i]
		if lx >= 2 and lx >= lz and lz >= 2:
			var dz := 1 if off_z[i] % 2 == 0 else -1
			if off_z[i] + dz < lz:
				var j := i + dz * size
				if len_x[j] >= 2 and len_x[j] >= len_z[j]:
					wide[i] = 3 if dz == 1 else 4
		elif lz >= 2 and lz > lx and lx >= 2:
			var dx := 1 if off_x[i] % 2 == 0 else -1
			if off_x[i] + dx < lx:
				var j := i + dx
				if len_z[j] >= 2 and len_z[j] > len_x[j]:
					wide[i] = 1 if dx == 1 else 2
	_wide = wide


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


const SAVE_FIELDS := ["height", "zone", "road", "level", "feature", "power_line", "special", "anchor", "rail", "transit", "slevel", "burning", "ruin", "villa", "worn", "ore", "ore_amt", "empty", "vacant"]


const ORE_VERSION := 2          # 2 = mit Fels (Ore.STONE)


func to_dict() -> Dictionary:
	var d := {"size": size, "ore_version": ORE_VERSION}
	for f: String in SAVE_FIELDS:
		d[f] = get(f)
	return d


## Überschreibt die Daten in-place (Referenzen auf diese Map bleiben gültig).
func from_dict(d: Dictionary) -> bool:
	var old_size: int = d.get("size", -1)
	if old_size > 0 and old_size < size:
		_embed(d, old_size)
		return true
	if old_size != size:
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
	# Gespeichert vor Einführung von Fels: auf freiem Gelände nachträglich erzeugen
	if int(d.get("ore_version", 1)) < 2 and d.has("ore"):
		_add_stone(EMBED_SEED)
	notify_changed(Rect2i(0, 0, size, size))
	return true


## Fels nach denselben Regeln wie _generate_ores, nur auf freien Tiles ohne Vorkommen.
func _add_stone(seed_value: int) -> void:
	var nz := FastNoiseLite.new()
	nz.seed = seed_value + 7000 + 131
	nz.frequency = 0.09
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var wl := Config.WATER_LEVEL
	for z in size:
		for x in size:
			var i := idx(x, z)
			if ore[i] != Config.Ore.NONE or height[i] < wl or zone[i] != Config.Zone.NONE or road[i] != 0 \
					or rail[i] != 0 or special[i] != Config.Special.NONE:
				continue
			var h := height[i]
			var steep := false
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if in_bounds(x + d.x, z + d.y) and absi(height[idx(x + d.x, z + d.y)] - h) >= 2:
					steep = true
			if (h >= wl + 6 or (steep and h >= wl + 3)) and nz.get_noise_2d(x * 0.6 + 50.0, z * 0.6) > -0.1:
				ore[i] = Config.Ore.STONE
				ore_amt[i] = rng.randi_range(Config.ORE_MIN, 255)


const EMBED_SEED := 4242     # Landschaft rund um eingebettete alte (kleinere) Spielstände
const EMBED_BLEND := 8       # Tiles, über die Höhen am Rand angeglichen werden


## Kleineren Spielstand (z.B. 64x64) mittig in eine neu erzeugte Landschaft dieser Größe setzen.
func _embed(d: Dictionary, old: int) -> void:
	generate(EMBED_SEED)
	var off := (size - old) / 2
	var remap := func(i: int) -> int:
		return (i / old + off) * size + i % old + off
	for f: String in SAVE_FIELDS:
		if not d.has(f):
			continue
		var src: Variant = d[f]
		var dst: Variant = get(f)
		for oz in old:
			for ox in old:
				var v: int = src[oz * old + ox]
				if f == "anchor" and v >= 0:
					v = remap.call(v)
				dst[(oz + off) * size + ox + off] = v
		set(f, dst)
	for i in road.size():
		if road[i] > 1:
			road[i] = 1
	# Höhen am Rand der alten Karte sanft in die neue Landschaft überführen (keine Klippen)
	var inner := Rect2i(off, off, old, old)
	for z in size:
		for x in size:
			if inner.has_point(Vector2i(x, z)):
				continue
			var nx := clampi(x, off, off + old - 1)
			var nz := clampi(z, off, off + old - 1)
			var dist := maxi(absi(x - nx), absi(z - nz))
			if dist > EMBED_BLEND:
				continue
			var i := idx(x, z)
			var t := float(dist) / float(EMBED_BLEND + 1)
			height[i] = roundi(lerpf(float(height[idx(nx, nz)]), float(height[i]), t))
	notify_changed(Rect2i(0, 0, size, size))


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
			burning[i] = 0
			ruin[i] = 0
			villa[i] = 0
			worn[i] = 0
			ore[i] = 0
			ore_amt[i] = 0
			if not is_water(x, z) and tree_noise.get_noise_2d(x, z) > 0.25 and rng.randf() < 0.6:
				feature[i] = Config.Feature.TREE
	_generate_ores(seed_value, rng)
	notify_changed(Rect2i(0, 0, size, size))


## Bodenvorkommen: Erzadern als Rauschen-Flecken im Hügelland (Kohle mittel, Eisen höher, Gold selten/hoch),
## Ton in feuchten Niederungen am Wasser, Sand an Stränden (Uferkante auf Wasserhöhe).
func _generate_ores(seed_value: int, rng: RandomNumberGenerator) -> void:
	var veins := []
	for k in 3:
		var nz := FastNoiseLite.new()
		nz.seed = seed_value + 7000 + k * 131
		nz.frequency = 0.09
		veins.append(nz)
	var wl := Config.WATER_LEVEL
	for z in size:
		for x in size:
			var i := idx(x, z)
			ore[i] = Config.Ore.NONE
			ore_amt[i] = 0
			var h := height[i]
			if h < wl:
				continue
			var near_water := false
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if in_bounds(x + d.x, z + d.y) and is_water(x + d.x, z + d.y):
					near_water = true
			var kind := Config.Ore.NONE
			if near_water and h == wl:
				kind = Config.Ore.SAND
			elif h <= wl + 1 and (veins[0] as FastNoiseLite).get_noise_2d(x * 1.7, z * 1.7) > 0.45:
				kind = Config.Ore.CLAY
			elif h >= wl + 5 and (veins[2] as FastNoiseLite).get_noise_2d(x, z) > 0.5:
				kind = Config.Ore.GOLD
			elif h >= wl + 4 and (veins[1] as FastNoiseLite).get_noise_2d(x, z) > 0.5:
				kind = Config.Ore.IRON
			elif h >= wl + 2 and (veins[0] as FastNoiseLite).get_noise_2d(x, z) > 0.5:
				kind = Config.Ore.COAL
			else:
				# Fels: Hochland oder steiler Hang (Nachbar 2+ Blöcke höher/tiefer)
				var steep := false
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if in_bounds(x + d.x, z + d.y) and absi(height[idx(x + d.x, z + d.y)] - h) >= 2:
						steep = true
				var rocky := (veins[1] as FastNoiseLite).get_noise_2d(x * 0.6 + 50.0, z * 0.6) > -0.1
				if (h >= wl + 6 or (steep and h >= wl + 3)) and rocky:
					kind = Config.Ore.STONE
			if kind != Config.Ore.NONE:
				ore[i] = kind
				ore_amt[i] = rng.randi_range(Config.ORE_MIN, 255)
