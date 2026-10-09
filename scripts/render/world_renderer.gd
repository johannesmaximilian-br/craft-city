class_name WorldRenderer
extends Node3D
## Rendert Terrain, Straßen, Zonen und Gebäude chunkweise per MultiMesh.
## Nur geänderte Chunks werden neu gebaut. Windrad-Rotoren drehen sich separat.

const CHUNK := 16
const B := Config.TILE_BLOCKS
const REBUILD_BUDGET_USEC := 4000     # max. ~4 ms Chunk-Neubau pro Frame
const ROTOR_SPEED := 1.2

var map: CityMap
var lib: BlockLibrary
var sim_speed := 1              # Rotoren stehen bei Pause
var _chunks := {}               # Vector2i -> Node3D
var _dirty := {}                # Vector2i -> true
var _b: BlockBatch
var _rotors: MultiMeshInstance3D
var _hubs: Array[Vector3] = []
var _rotor_angle := 0.0
var _last_wide := PackedByteArray()


func setup(city_map: CityMap, library: BlockLibrary) -> void:
	map = city_map
	lib = library
	_b = BlockBatch.new(lib)
	_setup_rotors()
	map.infra_changed.connect(_on_infra_changed)
	map.tiles_changed.connect(_on_tiles_changed)
	_on_infra_changed()
	_on_tiles_changed(Rect2i(0, 0, map.size, map.size))


func _on_tiles_changed(rect: Rect2i) -> void:
	var t := Perf.begin()
	_mark_dirty(rect)
	Perf.end("render.aenderung_pruefen", t)


func _mark_dirty(rect: Rect2i) -> void:
	# +1 Rand: Nachbar-Seitenwände, Markierungen und Kabel hängen davon ab
	var r := rect.grow(1)
	var c0 := Vector2i(maxi(r.position.x, 0) / CHUNK, maxi(r.position.y, 0) / CHUNK)
	var c1 := Vector2i(mini(r.end.x - 1, map.size - 1) / CHUNK, mini(r.end.y - 1, map.size - 1) / CHUNK)
	for cz in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			_dirty[Vector2i(cx, cz)] = true


## Nur bei Netz-Änderungen (nicht beim Wachstum).
func _on_infra_changed() -> void:
	var t := Perf.begin()
	# Hauptstraßen-Paare können sich entlang ganzer Straßenzüge verschieben
	var wide := map.wide_snapshot()
	if _last_wide.size() == wide.size():
		for i in wide.size():
			if wide[i] != _last_wide[i]:
				_dirty[Vector2i((i % map.size) / CHUNK, (i / map.size) / CHUNK)] = true
	_last_wide = wide
	_collect_hubs()
	Perf.end("render.netz_aenderung", t)


func _process(delta: float) -> void:
	# Zeitbudget statt fester Anzahl: mindestens 1 Chunk, dann nur solange Budget reicht
	var start := Time.get_ticks_usec()
	for c in _dirty.keys():
		_rebuild_chunk(c)
		_dirty.erase(c)
		if Time.get_ticks_usec() - start > REBUILD_BUDGET_USEC:
			break
	if sim_speed > 0:
		_rotor_angle += delta * ROTOR_SPEED * (1.0 + sim_speed * 0.3)
	_update_rotors()


func _rebuild_chunk(c: Vector2i) -> void:
	var t := Perf.begin()
	_b.clear()
	for tz in range(c.y * CHUNK, mini((c.y + 1) * CHUNK, map.size)):
		for tx in range(c.x * CHUNK, mini((c.x + 1) * CHUNK, map.size)):
			_emit_tile(tx, tz)
	Perf.end("render.chunk_bloecke", t)
	t = Perf.begin()
	if _chunks.has(c):
		_chunks[c].queue_free()
	var node := _b.build("Chunk_%d_%d" % [c.x, c.y])
	Perf.end("render.chunk_multimesh", t)
	add_child(node)
	_chunks[c] = node
	_b.clear()


# ---------------------------------------------------------------- Windrad-Rotoren

func _setup_rotors() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = lib.meshes["concrete"]
	_rotors = MultiMeshInstance3D.new()
	_rotors.name = "WindRotors"
	_rotors.multimesh = mm
	_rotors.material_override = lib.materials["concrete"]
	add_child(_rotors)


func _collect_hubs() -> void:
	_hubs.clear()
	for i in map.size * map.size:
		if map.anchor[i] == i and map.special[i] == Config.Special.WIND:
			var tx := i % map.size
			var tz := i / map.size
			_hubs.append(StructureGenerator.wind_hub(Vector3(tx * B, map.height[i], tz * B)))
	_rotors.multimesh.instance_count = _hubs.size() * 3


func _update_rotors() -> void:
	var mm := _rotors.multimesh
	# Blatt: 2.8 lang, 0.25 dick, vom Nabenmittelpunkt nach außen
	var blade: Transform3D = Transform3D(Basis.from_scale(Vector3(2.8, 0.25, 0.12)), Vector3(1.4, 0, 0)) \
		* Transform3D(Basis(), Vector3(-0.5, -0.5, -0.5)) * lib.norm["concrete"]
	for h in _hubs.size():
		var phase := _rotor_angle + h * 0.7
		for k in 3:
			var rot := Basis(Vector3.BACK, phase + k * TAU / 3.0)
			mm.set_instance_transform(h * 3 + k, Transform3D(rot, _hubs[h]) * blade)


# ---------------------------------------------------------------- Tiles

func _emit_tile(tx: int, tz: int) -> void:
	var i := map.idx(tx, tz)
	var th := map.height[i]
	var water := th < Config.WATER_LEVEL
	var is_road := map.road[i] != 0
	var bx0 := tx * B
	var bz0 := tz * B
	var base := Vector3(bx0, th, bz0)

	var hl := map.h(tx - 1, tz)
	var hr := map.h(tx + 1, tz)
	var hb := map.h(tx, tz - 1)
	var hf := map.h(tx, tz + 1)

	# Hauptstraßen-Ende: Tile ohne Fortsetzung bekommt eine Rundung statt eckigem Asphalt
	var partner := map.wide_partner(tx, tz) if is_road and map.rail[i] == 0 else Vector2i.ZERO
	var taper := _taper_ends(tx, tz, partner) if partner != Vector2i.ZERO else []

	var top_key := "grass"
	if is_road and taper.is_empty():
		top_key = "asphalt"
	elif map.rail[i] != 0:
		top_key = "stone"       # Schotterbett
	elif water or th == Config.WATER_LEVEL:
		top_key = "dirt"
	elif th >= Config.SNOW_HEIGHT:
		top_key = "snow"

	# Terrain-Säulen: Oberseite + sichtbare Seiten bis Nachbarhöhe
	for sz in B:
		for sx in B:
			var bottom := th - 1
			if sx == 0: bottom = mini(bottom, hl)
			if sx == B - 1: bottom = mini(bottom, hr)
			if sz == 0: bottom = mini(bottom, hb)
			if sz == B - 1: bottom = mini(bottom, hf)
			bottom = maxi(bottom, 0)
			for y in range(bottom, th):
				var key := top_key
				if y < th - 1:
					key = "dirt" if y >= th - 3 else "stone"
				_b.put(key, Vector3(bx0 + sx, y, bz0 + sz))

	if water:
		return

	if map.power_line[i] == 1:
		_emit_power_line(tx, tz, base)

	if map.anchor[i] == i:
		match map.special[i]:
			Config.Special.COAL: StructureGenerator.coal(_b, base)
			Config.Special.WIND: StructureGenerator.wind_tower(_b, base)
			_: StructureGenerator.service(_b, base, map.special[i], map.special_level(i))
		return
	if map.special[i] != Config.Special.NONE:
		return

	if map.rail[i] != 0:
		var conn: Array = []
		for d: Vector2i in Simulation.DIRS:
			if map.rails_connected(tx, tz, tx + d.x, tz + d.y):
				conn.append(d)
		StructureGenerator.rail(_b, base + Vector3(1.5, 0.01, 1.5), conn)
		if map.transit[i] == Config.Transit.STATION:
			var along_x := Vector2i(1, 0) in conn or Vector2i(-1, 0) in conn or conn.is_empty()
			StructureGenerator.station(_b, base, along_x)

	if is_road:
		if map.rail[i] == 0:    # Bahnübergang: keine Fahrbahnmarkierung
			if not taper.is_empty():
				_emit_taper(partner, taper, base)
			elif partner != Vector2i.ZERO:
				_emit_wide(partner, base)
			else:
				_emit_road_markings(tx, tz, base)
		if map.transit[i] == Config.Transit.BUS_STOP:
			StructureGenerator.bus_stop(_b, base)
		return
	if map.rail[i] != 0:
		return

	var zn := map.zone[i]
	var lv := map.level[i]
	if zn != Config.Zone.NONE:
		if lv == 0 and map.ruin[i] > 0:
			_emit_ruin(tx, tz, base)
		elif lv == 0:
			var plate: String = ["", "zone_res", "zone_com", "zone_ind"][zn]
			for sz in B:
				for sx in B:
					_b.put(plate, base + Vector3(sx, 0, sz))
		else:
			_b.base = base
			BuildingGenerator.emit(zn, lv, hash(Vector3i(tx, tz, lv)), _b.put_local, _b.prop_local, map.villa[i] == 1)
		return

	var c := base + Vector3(1.5, 0, 1.5)
	match map.feature[i]:
		Config.Feature.TREE:
			var r := absi(hash(Vector2i(tx, tz)))
			var tree: String = ["tree1", "tree2", "tree3"][r % 3]
			var off := Vector3(((r >> 4) % 5 - 2) * 0.15, 0, ((r >> 8) % 5 - 2) * 0.15)
			_b.put_prop(tree, c + off, float(r % 360) * 0.0174)
		Config.Feature.PARK:
			_b.put_prop("tree2", c, 0.0)
			_b.put_prop("flowers1", base + Vector3(0.5, 0, 0.5), 0.0)
			_b.put_prop("flowers2", base + Vector3(2.5, 0, 2.5), 1.0)
			_b.put_prop("bush", base + Vector3(2.5, 0, 0.5), 2.0)
			_b.put_prop("bush", base + Vector3(0.5, 0, 2.5), 0.5)


## Brandruine: verkohlter Boden, Mauerreste in den Ecken.
func _emit_ruin(tx: int, tz: int, base: Vector3) -> void:
	var r := absi(hash(Vector2i(tx, tz)))
	for sz in B:
		for sx in B:
			var k := sz * B + sx
			if (r >> k) & 1 == 0 or (sx == 1 and sz == 1):
				_b.put("coal", base + Vector3(sx, -0.6, sz))
			if sx != 1 and sz != 1 and (r >> (k + 9)) % 3 != 0:
				_b.put("darkbrick", base + Vector3(sx, 0, sz))
				if (r >> (k + 17)) & 1 == 1:
					_b.put("darkbrick", base + Vector3(sx, 1, sz))


func _pole_top(tx: int, tz: int) -> Vector3:
	return Vector3(tx * B + 1.5, map.h(tx, tz) + StructureGenerator.POLE_HEIGHT, tz * B + 1.5)


func _emit_power_line(tx: int, tz: int, base: Vector3) -> void:
	# Querträger quer zur Hauptrichtung der Leitung
	var horiz := map.is_power_line(tx - 1, tz) or map.is_power_line(tx + 1, tz)
	var vert := map.is_power_line(tx, tz - 1) or map.is_power_line(tx, tz + 1)
	StructureGenerator.pole(_b, base + Vector3(1.5, 0, 1.5), PI * 0.5 if horiz and not vert else 0.0)
	var top := _pole_top(tx, tz)
	for d: Vector2i in Simulation.DIRS:
		var nx := tx + d.x
		var nz := tz + d.y
		if not map.in_bounds(nx, nz):
			continue
		if map.is_power_line(nx, nz):
			var mid := top.lerp(_pole_top(nx, nz), 0.5)
			mid.y -= 0.25    # leichter Durchhang
			_b.segment("coal", top, mid, 0.06)
		elif map.conducts(map.idx(nx, nz)):
			# Anschluss an Zone/Kraftwerk: Kabel schräg nach unten zur Kante
			var edge := top.lerp(_pole_top(nx, nz), 0.5)
			edge.y = map.h(nx, nz) + 1.2
			_b.segment("coal", top, edge, 0.06)


func _emit_road_markings(tx: int, tz: int, base: Vector3) -> void:
	_b.put("marking", base + Vector3(1, 0, 1))
	if map.roads_connected(tx, tz, tx - 1, tz): _b.put("marking", base + Vector3(0, 0, 1))
	if map.roads_connected(tx, tz, tx + 1, tz): _b.put("marking", base + Vector3(2, 0, 1))
	if map.roads_connected(tx, tz, tx, tz - 1): _b.put("marking", base + Vector3(1, 0, 0))
	if map.roads_connected(tx, tz, tx, tz + 1): _b.put("marking", base + Vector3(1, 0, 2))


## Richtungen entlang der Hauptstraße, in die dieses Tile nicht weitergeht.
## Leer, wenn eine Seitenstraße außen anschließt (dann bleibt das Tile eckig).
func _taper_ends(tx: int, tz: int, partner: Vector2i) -> Array:
	if map.roads_connected(tx, tz, tx - partner.x, tz - partner.y):
		return []
	var axis := Vector2i(1, 0) if partner.x == 0 else Vector2i(0, 1)
	var out := []
	for e: Vector2i in [axis, -axis]:
		if not map.roads_connected(tx, tz, tx + e.x, tz + e.y):
			out.append(e)
	return out


## Abgerundetes Hauptstraßen-Ende: Viertelkreis (Radius 1 Tile) um die Ecke an der
## Mittellinie, aus 24 Asphalt-Streifen. Verjüngt sich zur weiterführenden Spur.
## Beide Enden offen (Stummel) -> Halbkreis.
func _emit_taper(partner: Vector2i, ends: Array, base: Vector3) -> void:
	const SLICES := 24
	var along_x := partner.x == 0
	var w := float(B) / SLICES
	for k in SLICES:
		var u := (k + 0.5) * w           # Position entlang der Achse (0..3)
		var reach := float(B)            # Breite ab Mittellinie
		if ends.size() == 2:
			var x := (u - B * 0.5) / (B * 0.5)
			reach = B * sqrt(maxf(0.0, 1.0 - x * x))
		else:
			var e: Vector2i = ends[0]
			var dist := u if (e.x + e.y) > 0 else B - u   # Abstand von der geschlossenen Kante
			reach = sqrt(maxf(0.0, B * B - dist * dist))
		if reach < 0.05:
			continue
		var seam_side := (partner.x + partner.y) > 0     # Mittellinie an der +Seite des Tiles
		var v := (B - reach * 0.5) if seam_side else reach * 0.5
		var center := Vector3(u, 0.03, v) if along_x else Vector3(v, 0.03, u)
		var size := Vector3(w + 0.01, 0.06, reach) if along_x else Vector3(reach, 0.06, w + 0.01)
		_b.put_box("flat_asphalt", base + center, size)
	# Mittellinie läuft weiter (Rundung beginnt an ihr)
	if along_x and partner.y == 1:
		for z: float in [2.92, 3.08]:
			_b.put_box("paint_yellow", base + Vector3(1.5, 0.07, z), Vector3(3.0, 0.04, 0.08))
	elif not along_x and partner.x == 1:
		for x: float in [2.92, 3.08]:
			_b.put_box("paint_yellow", base + Vector3(x, 0.07, 1.5), Vector3(0.08, 0.04, 3.0))


## 4-spurige Hauptstraße: weiße Spurlinie in Tile-Mitte, gelbe Doppel-Mittellinie
## an der Naht zum Partner-Tile (zeichnet nur das Tile mit Partner in +Richtung).
func _emit_wide(partner: Vector2i, base: Vector3) -> void:
	var along_x := partner.x == 0
	# Weiße Spurlinie (gestrichelt) mittig im Tile
	for c: float in [0.75, 2.25]:
		if along_x:
			_b.put_box("paint_white", base + Vector3(c, 0.02, 1.5), Vector3(0.9, 0.04, 0.12))
		else:
			_b.put_box("paint_white", base + Vector3(1.5, 0.02, c), Vector3(0.12, 0.04, 0.9))
	# Gelbe Doppel-Mittellinie auf der Naht (nur vom Tile mit Partner in +Richtung)
	if along_x and partner.y == 1:
		for z: float in [2.92, 3.08]:
			_b.put_box("paint_yellow", base + Vector3(1.5, 0.02, z), Vector3(3.0, 0.04, 0.08))
	elif not along_x and partner.x == 1:
		for x: float in [2.92, 3.08]:
			_b.put_box("paint_yellow", base + Vector3(x, 0.02, 1.5), Vector3(0.08, 0.04, 3.0))
