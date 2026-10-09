class_name StructureGenerator
extends RefCounted
## Sonderbauten und Infrastruktur aus Blöcken. base = untere Ecke des Ursprungs-Tiles.

const POLE_HEIGHT := 3.4


## Kohlekraftwerk, 6x6 Blöcke: Halle (x 0-3), Schornstein + Kohlehaufen (x 4-5).
static func coal(b: BlockBatch, base: Vector3) -> void:
	for y in 3:
		for z in 6:
			for x in 4:
				if not (x == 0 or x == 3 or z == 0 or z == 5):
					continue
				var key := "ice" if y == 1 and (z == 2 or z == 3) else "greybrick"
				b.put(key, base + Vector3(x, y, z))
	for z in 6:
		for x in 4:
			b.put("metal", base + Vector3(x, 3, z))
	for y in 8:
		var key := "brick" if y == 6 else "greybrick"
		for p: Vector2i in [Vector2i(4, 1), Vector2i(5, 1), Vector2i(4, 2), Vector2i(5, 2)]:
			b.put(key, base + Vector3(p.x, y, p.y))
	for z in range(3, 6):
		b.put("coal", base + Vector3(4, 0, z))
		b.put("coal", base + Vector3(5, 0, z))
	b.put("coal", base + Vector3(5, 1, 4))
	b.put("crate", base + Vector3(4, 0, 0))


## Windrad auf einem Tile (3x3 Blöcke). Rotor optional (für Animation separat).
static func wind_tower(b: BlockBatch, base: Vector3) -> void:
	var c := base + Vector3(1.5, 0, 1.5)
	b.put("concrete", base + Vector3(1, 0, 1))
	b.put_box("concrete", c + Vector3(0, 4.0, 0), Vector3(0.35, 7.0, 0.35))
	b.put_box("concrete", c + Vector3(0, 7.5, 0), Vector3(0.6, 0.6, 1.0))


static func wind_hub(base: Vector3) -> Vector3:
	return base + Vector3(1.5, 7.5, 2.05)


## Rotor um den Ursprung (für eigene, drehbare Instanz).
static func wind_rotor(b: BlockBatch, phase: float) -> void:
	for k in 3:
		var ang := phase + k * TAU / 3.0
		b.segment("concrete", Vector3.ZERO, Vector3(cos(ang), sin(ang), 0) * 2.8, 0.25)


## Gleisstück auf einem Tile (Kit-Gleise). conn: verbundene Richtungen (Vector2i).
## Gerade, Kurve (Kit-Kurve verbindet +X/+Z, wird gedreht) oder Kreuzung.
static func rail(b: BlockBatch, center: Vector3, conn: Array) -> void:
	var has := func(d: Vector2i) -> bool: return d in conn
	var x_axis: bool = has.call(Vector2i(1, 0)) or has.call(Vector2i(-1, 0))
	var z_axis: bool = has.call(Vector2i(0, 1)) or has.call(Vector2i(0, -1))
	if conn.size() == 2 and x_axis and z_axis:
		var dx := 1 if has.call(Vector2i(1, 0)) else -1
		var dz := 1 if has.call(Vector2i(0, 1)) else -1
		var rot := 0.0
		if dx == 1 and dz == -1: rot = PI * 0.5
		elif dx == -1 and dz == -1: rot = PI
		elif dx == -1 and dz == 1: rot = PI * 1.5
		b.put_prop("rail_corner", center, rot)
		return
	if x_axis or not z_axis:
		b.put_prop("rail_straight", center, 0.0)
	if z_axis:
		b.put_prop("rail_straight", center + Vector3(0, 0.005, 0), PI * 0.5)


## Bahnhof auf einem Gleis-Tile: Bahnsteige beidseitig, Pfeiler, Dächer, Schild.
static func station(b: BlockBatch, base: Vector3, along_x: bool) -> void:
	for side: float in [0.35, 2.65]:
		var plat := Vector3(1.5, 0.22, side) if along_x else Vector3(side, 0.22, 1.5)
		var plat_size := Vector3(3.0, 0.44, 0.7) if along_x else Vector3(0.7, 0.44, 3.0)
		b.put_box("square", base + plat, plat_size)
		var roof := Vector3(1.5, 2.5, side) if along_x else Vector3(side, 2.5, 1.5)
		var roof_size := Vector3(3.0, 0.2, 1.1) if along_x else Vector3(1.1, 0.2, 3.0)
		b.put_box("brick", base + roof, roof_size)
		for k: float in [0.4, 2.6]:
			var p := Vector3(k, 1.45, side) if along_x else Vector3(side, 1.45, k)
			b.put_box("log", base + p, Vector3(0.18, 2.0, 0.18))
	var sign := Vector3(1.5, 2.85, 0.35) if along_x else Vector3(0.35, 2.85, 1.5)
	b.put_box("vox_blue", base + sign, Vector3(0.9, 0.35, 0.1) if along_x else Vector3(0.1, 0.35, 0.9))


## Bushaltestelle an der Straßenecke: Pfosten mit Schild, Glasdach, Bank.
static func bus_stop(b: BlockBatch, base: Vector3) -> void:
	var c := base + Vector3(0.35, 0, 0.35)
	b.put_box("metal", c + Vector3(0, 0.8, 0), Vector3(0.08, 1.6, 0.08))
	b.put_box("vox_yellow", c + Vector3(0, 1.65, 0), Vector3(0.42, 0.42, 0.06))
	b.put_box("ice", c + Vector3(0.0, 1.3, 0.55), Vector3(0.7, 0.06, 0.5))
	b.put_box("metal", c + Vector3(-0.3, 0.65, 0.75), Vector3(0.06, 1.3, 0.06))
	b.put_box("wood", c + Vector3(0.0, 0.25, 0.65), Vector3(0.6, 0.1, 0.22))


## Quader-Hülle w x d Blöcke: Ecken corner, Fassade face; Fenster (window) jede 2. Fassadenzelle.
static func _hull(b: BlockBatch, base: Vector3, w: int, d: int, y0: int, floors: int,
		corner: String, face: String, window := "") -> void:
	for y in range(y0, y0 + floors):
		for z in d:
			for x in w:
				var edge_x := x == 0 or x == w - 1
				var edge_z := z == 0 or z == d - 1
				if not (edge_x or edge_z):
					continue
				var key := corner if edge_x and edge_z else face
				if window != "" and key == face and (x + z) % 2 == 1 and y > y0 - 1:
					key = window
				b.put(key, base + Vector3(x, y, z))


static func _roof(b: BlockBatch, base: Vector3, w: int, d: int, y: int, key: String) -> void:
	for z in d:
		for x in w:
			b.put(key, base + Vector3(x, y, z))


## Dienst-/Kulturgebäude. base = untere Ecke des Ursprungs-Tiles, lv = Ausbaustufe 1..3.
static func service(b: BlockBatch, base: Vector3, sp: int, lv: int) -> void:
	match sp:
		Config.Special.POLICE:
			var f := lv + 1
			_hull(b, base, 3, 3, 0, f, "greybrick", "greybrick", "ice")
			_roof(b, base, 3, 3, f, "darkbrick")
			b.put_box("vox_blue", base + Vector3(1.2, f + 1.2, 1.5), Vector3(0.35, 0.3, 0.35))   # Blaulicht
			b.put_box("vox_red", base + Vector3(1.8, f + 1.2, 1.5), Vector3(0.35, 0.3, 0.35))
			b.put_box("vox_blue", base + Vector3(1.5, 1.6, -0.03), Vector3(1.6, 0.4, 0.08))       # Schild
		Config.Special.FIRE:
			var f := lv + 1
			_hull(b, base, 3, 3, 0, f, "brick", "brick", "ice")
			b.put_box("vox_dark", base + Vector3(1.5, 0.6, -0.02), Vector3(1.6, 1.2, 0.06))       # Tor
			_roof(b, base, 3, 3, f, "metal")
			for y in range(f + 1, f + 2 + lv):                                                   # Schlauchturm
				b.put("brick", base + Vector3(2, y, 2))
			b.put("vox_red", base + Vector3(2, f + 2 + lv, 2))
		Config.Special.SCHOOL:
			var f := lv
			_hull(b, base, 3, 3, 0, f, "yellowbrick", "yellowbrick", "ice")
			_roof(b, base, 3, 3, f, "wood")
			b.put("wood", base + Vector3(1, f + 1, 1))
			b.put_box("metal", base + Vector3(0.2, f + 1.6, 0.2), Vector3(0.08, 3.2, 0.08))      # Fahnenmast
			b.put_box("vox_red", base + Vector3(0.55, f + 2.9, 0.2), Vector3(0.6, 0.4, 0.05))
		Config.Special.HOSPITAL:
			var f := lv + 2
			_hull(b, base, 6, 6, 0, f, "stone", "square", "ice")
			_roof(b, base, 6, 6, f, "square")
			# Rotes Kreuz auf dem Dach
			b.put_box("vox_red", base + Vector3(3, f + 1.05, 3), Vector3(3.0, 0.12, 1.0))
			b.put_box("vox_red", base + Vector3(3, f + 1.05, 3), Vector3(1.0, 0.12, 3.0))
			b.put_box("ice", base + Vector3(3, 0.8, -0.03), Vector3(2.0, 1.6, 0.08))             # Eingang
			if lv >= 3:
				b.put_box("vox_dark", base + Vector3(4.8, f + 1.05, 4.8), Vector3(1.6, 0.1, 1.6))   # Landeplatz
		Config.Special.LIBRARY:
			var f := lv
			_hull(b, base, 3, 3, 0, f, "brick", "brick", "ice")
			for x: float in [0.3, 1.5, 2.7]:                                                     # Säulen
				b.put_box("log", base + Vector3(x, f * 0.5, -0.25), Vector3(0.25, f, 0.25))
			b.put_box("stone", base + Vector3(1.5, f + 0.1, 1.3), Vector3(3.3, 0.2, 3.3))
			_roof(b, base, 3, 3, f, "darkbrick")
			b.put("darkbrick", base + Vector3(1, f + 1, 1))
		Config.Special.CINEMA:
			var f := lv + 1
			_hull(b, base, 3, 3, 0, f, "darkbrick", "darkbrick")
			b.put_box("cheese", base + Vector3(1.5, 1.4, -0.15), Vector3(3.2, 0.5, 0.3))          # Leuchtreklame
			b.put_box("vox_dark", base + Vector3(1.5, 0.5, -0.02), Vector3(1.2, 1.0, 0.06))
			_roof(b, base, 3, 3, f, "darkbrick")
			b.put_box("vox_red", base + Vector3(1.5, f + 1.5, 0.5), Vector3(1.8, 1.0, 0.15))      # Schild
		Config.Special.TOWNHALL:
			var f := lv + 1
			_hull(b, base, 6, 6, 0, f, "stone", "greybrick", "ice")
			_roof(b, base, 6, 6, f, "darkbrick")
			for x: float in [0.6, 2.0, 4.0, 5.4]:                                                # Säulen
				b.put_box("log", base + Vector3(x, f * 0.5, -0.25), Vector3(0.3, f, 0.3))
			var tower := 2 + lv                                                                  # Uhrturm
			for y in range(f + 1, f + 1 + tower):
				b.put("wood", base + Vector3(2.5, y, 2.5))
				b.put("wood", base + Vector3(2.5, y, 3.5) - Vector3(0, 0, 1))
			b.put_box("vox_white", base + Vector3(3.0, f + tower - 0.5, 1.95), Vector3(0.8, 0.8, 0.08))
			b.put("brick", base + Vector3(2.5, f + 1 + tower, 2.5))


## Holzmast mit Querträger, Fuß bei foot (Tile-Mitte).
static func pole(b: BlockBatch, foot: Vector3, rot: float) -> void:
	b.put_box("wood", foot + Vector3(0, POLE_HEIGHT * 0.5, 0), Vector3(0.25, POLE_HEIGHT, 0.25))
	b.put_box("wood", foot + Vector3(0, POLE_HEIGHT - 0.15, 0), Vector3(1.6, 0.18, 0.18), rot)
